import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../di/app_module.dart';
import '../data/http_client_factory.dart';
import '../data/sqlite_audit_log_service.dart';
import '../domain/paired_system_registry.dart';
import '../domain/secure_storage_service.dart';
import 'auth_2fa_ws_handler.dart';
import 'otp_gateway_ws_handler.dart';
import 'payment_observation_ws_handler.dart';
import 'ws_message_router.dart';

// ---------------------------------------------------------------------------
// Storage keys (must match PairingRepositoryImpl)
// ---------------------------------------------------------------------------

const _kReverbHost = 'reverb_host';
const _kReverbPort = 'reverb_port';
const _kReverbAppKey = 'reverb_app_key';

// ---------------------------------------------------------------------------
// AgentWebSocketService
// ---------------------------------------------------------------------------

/// Maintains a persistent, authenticated WebSocket connection to the Reverb
/// server on behalf of the paired agent.
///
/// Architecture:
///   1. Reads Reverb connection parameters from secure storage (written at pairing).
///   2. Connects to Reverb using the Pusher WebSocket protocol.
///   3. Authenticates the private channel (private-agent.{systemId}) by calling
///      POST /api/v1/broadcasting/auth using the authenticated [HttpClientFactory].
///      The signing interceptor automatically adds all required ECDSA headers.
///   4. Routes all incoming AgentCommandDispatched events to [WsMessageRouter].
///   5. Auto-reconnects with exponential back-off on any disconnect or error.
///
/// Background operation:
///   Android Doze mode kills background network connections. To prevent this,
///   this service is wrapped by [AgentForegroundService], which runs as an
///   Android Foreground Service displaying a persistent "Agent is running"
///   notification. The foreground service keeps the process alive indefinitely,
///   ensuring the WebSocket remains open for incoming server commands.
///
/// Security invariants:
///   - Private channel subscription requires ECDSA-signed authentication.
///   - No command payload is stored beyond the routing call.
///   - All reconnection attempts respect the nonce uniqueness requirement —
///     a fresh nonce is generated per auth request (via the signing interceptor).
class AgentWebSocketService {
  final WsMessageRouter _router;
  final PairedSystemRegistry _registry;
  final SecureStorageService _secureStorage;
  final HttpClientFactory _clientFactory;
  final _log = Logger();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  String? _socketId;
  int _reconnectDelaySecs = 2;

  static const int _maxReconnectDelaySecs = 60;
  static const String _pusherProtocol = '7';
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  AgentWebSocketService({
    required WsMessageRouter router,
    required PairedSystemRegistry registry,
    required SecureStorageService secureStorage,
    required HttpClientFactory clientFactory,
  })  : _router = router,
        _registry = registry,
        _secureStorage = secureStorage,
        _clientFactory = clientFactory;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Connects to the Reverb WebSocket server for all paired systems.
  ///
  /// Call once from [main()] after DI is wired and registry is loaded.
  Future<void> connect() async {
    final systems = _registry.all;
    if (systems.isEmpty) {
      _log.i('[WS] No paired systems — skipping WebSocket connection.');
      return;
    }

    // Use the first system's connection parameters.
    // Multi-system support: iterate and open one connection per system.
    final system = systems.first;
    await _connectToSystem(system.systemId);
  }

  /// Cleanly closes the WebSocket connection.
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _socketId = null;
  }

  // ---------------------------------------------------------------------------
  // Heartbeat — keep last_seen_at fresh on the server
  // ---------------------------------------------------------------------------

  /// Starts a periodic HTTP heartbeat so the server's last_seen_at column
  /// stays within the online window even when the WebSocket stays alive
  /// without a channel re-auth (which is the only other event that updates it).
  void _startHeartbeat(String systemId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat(systemId);
    });
    // Send one immediately so the hub shows online right away.
    _sendHeartbeat(systemId);
  }

  Future<void> _sendHeartbeat(String systemId) async {
    final system = _registry.findBySystemId(systemId);
    if (system == null) return;

    try {
      final dio = _clientFactory.forSystem(systemId);
      await dio.post<Map<String, dynamic>>(
        '${system.baseUrl}/api/v1/agent/heartbeat',
        data: <String, dynamic>{},
      );
      _log.d('[WS] Heartbeat sent for system $systemId');
    } catch (e) {
      _log.w('[WS] Heartbeat failed (non-fatal): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — connection lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _connectToSystem(String systemId) async {
    String host = (await _secureStorage.read(key: _kReverbHost))
        .fold((_) => 'localhost', (v) => v ?? 'localhost');
    final portStr = (await _secureStorage.read(key: _kReverbPort))
        .fold((_) => '8080', (v) => v ?? '8080');
    final appKey = (await _secureStorage.read(key: _kReverbAppKey))
        .fold((_) => '', (v) => v ?? '');

    String scheme = 'ws';
    final system = _registry.findBySystemId(systemId);
    if (system != null) {
      final parsedBaseUri = Uri.tryParse(system.baseUrl);
      if (parsedBaseUri != null) {
        if (parsedBaseUri.scheme == 'https') {
          scheme = 'wss';
        }
        if (host == 'localhost' || host == '127.0.0.1') {
          final parentHost = parsedBaseUri.host;
          if (parentHost.isNotEmpty) {
            _log.i('[WS] Overriding loopback reverb_host "$host" with parent server host "$parentHost"');
            host = parentHost;
          }
        }
      }
    }

    if (host == 'localhost' || host == '127.0.0.1') {
      _log.i('[WS] Host is still loopback — falling back to 10.0.2.2 for Android emulator compatibility.');
      host = '10.0.2.2';
    }

    final wsUri = Uri.parse(
      '$scheme://$host:$portStr/app/$appKey'
      '?protocol=$_pusherProtocol&client=flutter-agent&version=1.0',
    );

    _log.i('[WS] Connecting to $wsUri');

    try {
      // Cancel any stale listener from the previous connection before creating
      // a new channel. Without this, the old stream's onDone fires when the
      // old channel eventually closes and triggers a second reconnect loop.
      await _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
      _socketId = null;

      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        (raw) => _handleRawMessage(systemId, raw as String),
        onDone: () {
          _log.w('[WS] Connection closed by server');
          _scheduleReconnect(systemId);
        },
        onError: (e) {
          _log.e('[WS] Stream error: $e');
          _updateNotification(
            'Agent disconnected',
            'Connection lost — retrying…',
          );
          _scheduleReconnect(systemId);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _log.e('[WS] Connection failed: $e');
      _updateNotification(
        'Agent disconnected',
        'Could not connect to server — retrying…',
      );
      _scheduleReconnect(systemId);
    }
  }

  // ---------------------------------------------------------------------------
  // Pusher protocol — message handling
  // ---------------------------------------------------------------------------

  Future<void> _handleRawMessage(String systemId, String raw) async {
    try {
      final Map<String, dynamic> msg = json.decode(raw) as Map<String, dynamic>;
      final event = msg['event'] as String?;
      final data = msg['data'];

      _log.d('[WS] Received event: $event');

      switch (event) {
        case 'pusher:connection_established':
          await _onConnectionEstablished(systemId, data as String);
        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
        case 'pusher_internal:subscription_succeeded':
          _log.i('[WS] Subscribed to private-agent.$systemId');
          _reconnectDelaySecs = 2; // reset back-off on confirmed subscription
          _updateNotification(
            'Super Admin Agent',
            'Agent is running — listening for commands',
          );
          _startHeartbeat(systemId);
        case 'pusher_internal:subscription_error':
          _log.e('[WS] Subscription error — scheduling reconnect');
          _updateNotification(
            'Channel auth rejected',
            'Server rejected the channel subscription — reconnecting…',
          );
          _scheduleReconnect(systemId);
        case 'App\\Events\\AgentCommandDispatched':
        case 'agent.command':
          await _onAgentCommand(data);
        default:
          _log.d('[WS] Unhandled event: $event');
      }
    } catch (e) {
      _log.e('[WS] Failed to parse message: $e\nRaw: $raw');
    }
  }

  Future<void> _onConnectionEstablished(
      String systemId, String dataJson) async {
    final Map<String, dynamic> parsed =
        json.decode(dataJson) as Map<String, dynamic>;
    _socketId = parsed['socket_id'] as String?;
    _log.i('[WS] Connection established. socket_id=$_socketId');
    await _subscribeToPrivateChannel(systemId);
  }

  Future<void> _subscribeToPrivateChannel(String systemId) async {
    if (_socketId == null) return;

    final channelName = 'private-agent.$systemId';

    try {
      final authToken = await _fetchChannelAuth(
        systemId: systemId,
        socketId: _socketId!,
        channelName: channelName,
      );

      _send({
        'event': 'pusher:subscribe',
        'data': {
          'auth': authToken,
          'channel': channelName,
        },
      });
    } catch (e) {
      // Network error or server rejection — don't wait 30 s for Reverb's
      // activity_timeout to close the socket. Reconnect immediately so the
      // user sees the "Reconnecting" notification without a long freeze.
      _log.e('[WS] Channel auth failed: $e');
      _updateNotification(
        'Connection error',
        'Could not reach server — reconnecting…',
      );
      _scheduleReconnect(systemId);
    }
  }

  /// Authenticates the private Reverb channel by calling
  /// POST /api/v1/broadcasting/auth with ECDSA-signed headers.
  ///
  /// Uses [HttpClientFactory.forSystem] to obtain an authenticated [Dio]
  /// instance. The [_AgentSigningInterceptor] attached to that client
  /// automatically adds X-Agent-Public-Key-Id, X-Agent-Nonce,
  /// X-Agent-Timestamp, and X-Agent-Signature headers — one fresh
  /// nonce per request (replay protection).
  ///
  /// The auth endpoint is derived from the system's baseUrl at runtime
  /// so it is always consistent with the paired server's address.
  Future<String> _fetchChannelAuth({
    required String systemId,
    required String socketId,
    required String channelName,
  }) async {
    final system = _registry.findBySystemId(systemId);
    if (system == null) {
      throw StateError(
        'CF-03: Cannot authenticate channel for unknown system "$systemId".',
      );
    }

    final authEndpoint = '${system.baseUrl}/api/v1/broadcasting/auth';
    final dio = _clientFactory.forSystem(systemId);

    final response = await dio.post<Map<String, dynamic>>(
      authEndpoint,
      data: {
        'socket_id': socketId,
        'channel_name': channelName,
      },
    );

    final auth = response.data?['auth'] as String?;
    if (auth == null || auth.isEmpty) {
      throw StateError('Broadcasting auth endpoint returned empty auth token.');
    }
    return auth;
  }

  Future<void> _onAgentCommand(dynamic rawData) async {
    final Map<String, dynamic> data = rawData is String
        ? json.decode(rawData) as Map<String, dynamic>
        : rawData as Map<String, dynamic>;

    _log.d(
        '[WS] Routing command: ${data['capability']} / ${data['command_id']}');
    await _router.route(data);
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(json.encode(payload));
  }

  void _scheduleReconnect(String systemId) {
    _log.w('[WS] Scheduling reconnect in ${_reconnectDelaySecs}s');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();

    _updateNotification(
      'Agent disconnected',
      'No internet connection — retrying in ${_reconnectDelaySecs}s…',
    );

    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySecs), () {
      _reconnectDelaySecs =
          (_reconnectDelaySecs * 2).clamp(2, _maxReconnectDelaySecs);
      _updateNotification(
        'Agent reconnecting',
        'Attempting to reach the server…',
      );
      _connectToSystem(systemId);
    });
  }

  // ---------------------------------------------------------------------------
  // Foreground notification updates
  // ---------------------------------------------------------------------------

  /// Updates the persistent foreground-service notification so the user always
  /// sees the current connection state without opening the app.
  ///
  /// Works only when the background service is active; silently ignored
  /// in the main UI isolate (where [AgentForegroundService.instance] is null).
  void _updateNotification(String title, String content) {
    try {
      final svc = AgentForegroundService.instance;
      if (svc is AndroidServiceInstance) {
        svc.setForegroundNotificationInfo(title: title, content: content);
      }
    } catch (_) {
      // Non-fatal — notification update is best-effort.
    }
  }
}

// ---------------------------------------------------------------------------
// AgentForegroundService
// ---------------------------------------------------------------------------

/// Wraps [AgentWebSocketService] in an Android Foreground Service.
///
/// Android Doze mode (API 23+) aggressively kills background processes and
/// suspends network connections. A Foreground Service bypasses Doze mode
/// by displaying a persistent notification that signals to the OS that
/// this process is actively serving the user — preventing it from being killed.
///
/// This is the only compliant, self-hosted solution for maintaining persistent
/// WebSocket connections on Android without Google's push infrastructure.
///
/// Implementation uses flutter_background_service which generates a Kotlin
/// ForegroundService under the hood with a FOREGROUND_SERVICE_TYPE_DATA_SYNC
/// or FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE notification type.
///
/// Usage:
///   Call [AgentForegroundService.init()] from main() before [runApp()].
///   The service auto-starts on device boot (requires RECEIVE_BOOT_COMPLETED).
@pragma('vm:entry-point')
class AgentForegroundService {
  static const _notificationChannelId = 'super_admin_agent';
  static const _notificationId = 888;

  static ServiceInstance? _instance;
  static ServiceInstance? get instance => _instance;

  /// Initialise and start the foreground service.
  ///
  /// The service entry point [_onStart] runs in a separate Dart isolate.
  /// DI and WebSocket are re-initialised inside that isolate.
  static Future<void> init() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Super Admin Agent',
        initialNotificationContent: 'Agent is running — listening for commands',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onBackground,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    _instance = service;

    // 1. Initialise dependencies in this background isolate's heap context
    await SqliteAuditLogService.init();
    await setupDependencies();
    await getIt<PairedSystemRegistry>().reload();

    // 2. Register all capability WebSocket handlers inside this isolate
    final router = getIt<WsMessageRouter>();
    router.registerHandler(
      CapabilityId.twoFa,
      Auth2faWsHandler(navigatorKey: GlobalKey<NavigatorState>()),
    );
    router.registerHandler(
      CapabilityId.otpGateway,
      OtpGatewayWsHandler(),
    );
    router.registerHandler(
      CapabilityId.paymentObservation,
      PaymentObservationWsHandler(),
    );

    // 3. Connect the AgentWebSocketService to the Reverb server
    final websocketService = getIt<AgentWebSocketService>();
    await websocketService.connect();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'Super Admin Agent',
        content: 'Agent is running — listening for commands',
      );
    }

    // 4. Register event channels to listen for state changes from the main isolate
    service.on('connect_websocket').listen((_) async {
      await getIt<PairedSystemRegistry>().reload();
      await websocketService.connect();
    });

    service.on('disconnect_websocket').listen((_) async {
      websocketService.disconnect();
      await getIt<PairedSystemRegistry>().reload();
    });

    service.on('stop').listen((_) {
      websocketService.disconnect();
      service.stopSelf();
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onBackground(ServiceInstance service) async {
    return true;
  }
}
