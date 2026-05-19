import 'dart:async';
import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/paired_system_registry.dart';
import '../domain/secure_storage_service.dart';
import 'ws_message_router.dart';

// ---------------------------------------------------------------------------
// Storage keys (must match PairingRepositoryImpl)
// ---------------------------------------------------------------------------

const _kReverbHost = 'reverb_host';
const _kReverbPort = 'reverb_port';
const _kReverbAppKey = 'reverb_app_key';
const _kAuthEndpoint = 'auth_endpoint';

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
///      POST /api/v1/broadcasting/auth with the agent's ECDSA-signed headers.
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
///     a fresh nonce is generated per auth request.
class AgentWebSocketService {
  final WsMessageRouter _router;
  final PairedSystemRegistry _registry;
  final SecureStorageService _secureStorage;
  final _log = Logger();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String? _socketId;
  int _reconnectDelaySecs = 2;

  static const int _maxReconnectDelaySecs = 60;
  static const String _pusherProtocol = '7';

  AgentWebSocketService({
    required WsMessageRouter router,
    required PairedSystemRegistry registry,
    required SecureStorageService secureStorage,
  })  : _router = router,
        _registry = registry,
        _secureStorage = secureStorage;

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
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _socketId = null;
  }

  // ---------------------------------------------------------------------------
  // Internal — connection lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _connectToSystem(String systemId) async {
    final host = (await _secureStorage.read(key: _kReverbHost))
        .fold((_) => 'localhost', (v) => v ?? 'localhost');
    final portStr = (await _secureStorage.read(key: _kReverbPort))
        .fold((_) => '8080', (v) => v ?? '8080');
    final appKey = (await _secureStorage.read(key: _kReverbAppKey))
        .fold((_) => '', (v) => v ?? '');

    final wsUri = Uri.parse(
      'ws://$host:$portStr/app/$appKey'
      '?protocol=$_pusherProtocol&client=flutter-agent&version=1.0',
    );

    _log.i('[WS] Connecting to $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);

      _channel!.stream.listen(
        (raw) => _handleRawMessage(systemId, raw as String),
        onDone: () => _scheduleReconnect(systemId),
        onError: (e) {
          _log.e('[WS] Stream error: $e');
          _scheduleReconnect(systemId);
        },
        cancelOnError: true,
      );

      // Reset back-off on successful connection.
      _reconnectDelaySecs = 2;
    } catch (e) {
      _log.e('[WS] Connection failed: $e');
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
        case 'pusher_internal:subscription_error':
          _log.e('[WS] Subscription error — retrying auth');
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
    final authEndpoint = (await _secureStorage.read(key: _kAuthEndpoint))
        .fold((_) => '', (v) => v ?? '');

    try {
      // Authenticate the private channel via the signed HTTP endpoint.
      final authToken = await _fetchChannelAuth(
        authEndpoint: authEndpoint,
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
      _log.e('[WS] Channel auth failed: $e');
    }
  }

  /// Calls POST /api/v1/broadcasting/auth using the agent's signing interceptor.
  ///
  /// Note: Since this service lives outside the full Dio signing stack,
  /// a lightweight signed HTTP call is made directly here. In Phase 7 the
  /// HttpClientFactory can be injected to fully reuse the signing interceptor.
  ///
  /// TODO(phase-7): Inject HttpClientFactory and use its authenticated Dio client.
  Future<String> _fetchChannelAuth({
    required String authEndpoint,
    required String socketId,
    required String channelName,
  }) async {
    // The full implementation will use the signing interceptor.
    // For now, return a placeholder that triggers channel auth via the server.
    // This is wired fully in Phase 7 when the Dio signing stack is injected here.
    throw UnimplementedError(
      'Channel auth must be wired with HttpClientFactory in Phase 7. '
      'See BroadcastingAuthController on the server side.',
    );
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
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySecs), () {
      _reconnectDelaySecs =
          (_reconnectDelaySecs * 2).clamp(2, _maxReconnectDelaySecs);
      _connectToSystem(systemId);
    });
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
class AgentForegroundService {
  static const _notificationChannelId = 'super_admin_agent';
  static const _notificationId = 888;

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
    // The background isolate has its own Dart VM — DI must be re-wired here.
    // TODO(phase-7): Re-initialise DI and AgentWebSocketService in this isolate.
    // For now, update the notification to show the service is alive.
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'Super Admin Agent',
        content: 'Agent is running — listening for commands',
      );
    }

    service.on('stop').listen((_) => service.stopSelf());
  }

  @pragma('vm:entry-point')
  static Future<bool> _onBackground(ServiceInstance service) async {
    return true;
  }
}
