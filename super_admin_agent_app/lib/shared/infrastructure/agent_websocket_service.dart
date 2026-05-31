import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:super_admin_agent/shared/domain/signing_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../di/app_module.dart';
import '../../domain/pairing/entities/paired_system.dart';
import '../../domain/pairing/repositories/pairing_repository.dart';
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
/// Connectivity awareness:
///   When the device loses internet, the service detects this via
///   [Connectivity] and stops all reconnection timers and heartbeats. It shows
///   a single "No internet" notification and waits passively for connectivity
///   to restore before resuming — eliminating the freeze loops caused by
///   repeated failed connection attempts on the main thread.
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
  final PairingRepository _pairingRepository;
  final _log = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 3,
      lineLength: 80,
      noBoxingByDefault: true,
    ),
  );

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _wsPingTimer;
  String? _socketId;
  int _reconnectDelaySecs = 2;

  /// The systemId we are currently connected (or trying to connect) to.
  String? _currentSystemId;

  /// Whether we believe the device currently has internet connectivity.
  bool _isOnline = true;

  /// Subscription to [Connectivity.onConnectivityChanged].
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Whether we are currently in the middle of a connect attempt.
  /// Prevents overlapping connect calls.
  bool _isConnecting = false;

  /// Counts consecutive authentication failures (401). Used to detect
  /// persistent auth problems (empty publicKeyId, revoked agent) and
  /// stop the reconnect loop instead of hammering the server forever.
  int _consecutiveAuthFailures = 0;
  static const int _maxConsecutiveAuthFailures = 3;

  static const int _maxReconnectDelaySecs = 60;
  static const String _pusherProtocol = '7';
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// How often the client sends a WebSocket-level pusher:ping to Reverb.
  /// Must be strictly less than the server's activity_timeout (120 s) so
  /// Reverb never sees the connection as idle long enough to close it.
  static const Duration _wsPingInterval = Duration(seconds: 30);

  AgentWebSocketService({
    required WsMessageRouter router,
    required PairedSystemRegistry registry,
    required SecureStorageService secureStorage,
    required HttpClientFactory clientFactory,
    required PairingRepository pairingRepository,
  })  : _router = router,
        _registry = registry,
        _secureStorage = secureStorage,
        _clientFactory = clientFactory,
        _pairingRepository = pairingRepository;

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
    _currentSystemId = system.systemId;

    // Start listening for connectivity changes.
    _startConnectivityMonitoring();

    // Check current connectivity before attempting connection.
    final hasInternet = await _checkConnectivity();
    if (!hasInternet) {
      _log.i('[WS] Device is offline — waiting for connectivity…');
      _updateNotification(
        'Agent waiting',
        'No internet connection — will connect when online',
      );
      return;
    }

    await _connectToSystem(system.systemId);
  }

  /// Cleanly closes the WebSocket connection.
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _wsPingTimer?.cancel();
    _wsPingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _channel?.sink.close();
    _channel = null;
    _socketId = null;
    _isConnecting = false;
    _currentSystemId = null;
  }

  // ---------------------------------------------------------------------------
  // Connectivity monitoring
  // ---------------------------------------------------------------------------

  /// Subscribes to device connectivity changes. When the device goes offline,
  /// all retry loops and heartbeats are cancelled and a single notification is
  /// shown. When connectivity is restored, reconnection is initiated.
  void _startConnectivityMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);

      if (online && !_isOnline) {
        // Connectivity restored — reconnect.
        _isOnline = true;
        _log.i('[WS] Connectivity restored — initiating reconnection');
        _reconnectDelaySecs = 2; // reset back-off
        _updateNotification(
          'Agent reconnecting',
          'Internet restored — connecting to server…',
        );
        if (_currentSystemId != null && !_isConnecting) {
          _connectToSystem(_currentSystemId!);
        }
      } else if (!online && _isOnline) {
        // Lost connectivity — stop everything.
        _isOnline = false;
        _log.w('[WS] Device went offline — pausing all network activity');

        // Cancel any pending reconnection timer.
        _reconnectTimer?.cancel();
        _reconnectTimer = null;

        // Cancel heartbeat timer.
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;

        // Close the current channel gracefully.
        _subscription?.cancel();
        _subscription = null;
        _channel?.sink.close();
        _channel = null;
        _socketId = null;
        _isConnecting = false;

        _updateNotification(
          'Agent offline',
          'No internet connection — will reconnect automatically',
        );
      }
    });
  }

  /// Returns true if the device currently has a network connection.
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      return _isOnline;
    } catch (e) {
      _log.w('[WS] Connectivity check failed (assuming online): $e');
      _isOnline = true;
      return true;
    }
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
      if (_isOnline) {
        _sendHeartbeat(systemId);
      }
    });
    // Send one immediately so the hub shows online right away.
    _sendHeartbeat(systemId);
  }

  Future<void> _sendHeartbeat(String systemId) async {
    final system = _registry.findBySystemId(systemId);
    if (system == null) return;

    try {
      final dio = _clientFactory.forSystem(systemId);
      final response = await dio.post<Map<String, dynamic>>(
        '${system.baseUrl}/api/v1/agent/heartbeat',
        data: <String, dynamic>{},
      );
      _log.d('[WS] Heartbeat sent for system $systemId');

      // Refresh capabilities if the server reports a different set than what
      // is currently stored on-device. This self-heals stale pairing data —
      // e.g. a device paired before two_fa was added to the server's capability
      // list — without requiring a full re-pair.
      final data = response.data;
      if (data != null) {
        final rawCaps = data['capabilities'];
        if (rawCaps is List) {
          final serverCaps = List<String>.from(rawCaps.whereType<String>());
          final storedCaps = List<String>.from(system.grantedCapabilities)..sort();
          final serverCapsSorted = List<String>.from(serverCaps)..sort();

          if (!_capabilitiesEqual(storedCaps, serverCapsSorted)) {
            _log.i(
              '[WS] Capability refresh: stored=$storedCaps server=$serverCapsSorted '
              '— updating stored PairedSystem for $systemId',
            );
            final updated = PairedSystem(
              agentId: system.agentId,
              systemId: system.systemId,
              systemLabel: system.systemLabel,
              baseUrl: system.baseUrl,
              grantedCapabilities: serverCaps,
              pairedAt: system.pairedAt,
            );
            _registry.register(updated);
            await _pairingRepository.savePairedSystem(updated);
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        // Downgrade timeout logs to debug to avoid console flooding on poor networks
        _log.d('[WS] Heartbeat timeout (non-fatal, device likely offline)');
      } else {
        _log.w('[WS] Heartbeat failed (non-fatal): $e');
      }
    }
  }

  bool _capabilitiesEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Internal — connection lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _connectToSystem(String systemId) async {
    // Guard against overlapping connection attempts.
    if (_isConnecting) {
      _log.d('[WS] Connection already in progress — skipping');
      return;
    }

    // Don't attempt connection if offline.
    if (!_isOnline) {
      _log.d('[WS] Device is offline — skipping connection attempt');
      return;
    }

    _isConnecting = true;

    try {
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

      // Cancel any stale listener from the previous connection before creating
      // a new channel. Without this, the old stream's onDone fires when the
      // old channel eventually closes and triggers a second reconnect loop.
      await _subscription?.cancel();
      _subscription = null;
      _wsPingTimer?.cancel();
      _wsPingTimer = null;
      _channel?.sink.close();
      _channel = null;
      _socketId = null;

      // Use dart:io WebSocket.connect directly with a custom HttpClient.
      //
      // ROOT CAUSE of "Null check operator used on a null value":
      //   dart:io's HttpClient internally calls the Android system proxy
      //   resolver (HttpClient.findProxy). Inside a background isolate
      //   (AgentForegroundService._onStart) the proxy resolver returns null
      //   on many Android versions, causing a null-check crash deep inside
      //   _HttpClient._openUrl() before the connection even attempts TLS.
      //
      // FIX: Set findProxy = (uri) => 'DIRECT' to bypass the system proxy
      //   resolver entirely. badCertificateCallback is kept as a safety net
      //   for servers with self-signed or chain-incomplete certificates.
      final httpClient = HttpClient()
        ..findProxy = ((uri) => 'DIRECT')
        ..badCertificateCallback = (cert, host, port) {
          _log.w('[WS] TLS cert issue for $host:$port — '
              'subject=${cert.subject}, issuer=${cert.issuer}');
          return true;
        };

      final dartWebSocket = await WebSocket.connect(
        wsUri.toString(),
        customClient: httpClient,
      );

      _channel = IOWebSocketChannel(dartWebSocket);
      _log.d('[WS] Connection successfully established (ready completed)');

      _subscription = _channel!.stream.listen(
        (raw) => _handleRawMessage(systemId, raw as String),
        onDone: () {
          _log.w('[WS] Connection closed by server');
          _isConnecting = false;
          _scheduleReconnect(systemId);
        },
        onError: (e) {
          _log.e('[WS] Stream error: $e');
          _isConnecting = false;
          _scheduleReconnect(systemId);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _log.e('[WS] Connection failed: $e');
      _isConnecting = false;
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
          _log.d('[WS] Responding to server-initiated pusher:ping with pusher:pong');
          _send({'event': 'pusher:pong'});
        case 'pusher_internal:subscription_succeeded':
          _log.i('[WS] Subscribed to private-agent.$systemId');
          _reconnectDelaySecs = 2; // reset back-off on confirmed subscription
          _consecutiveAuthFailures = 0; // reset auth failure counter
          _isConnecting = false; // connection fully established
          _updateNotification(
            'Super Admin Agent',
            'Agent is running — listening for commands',
          );
          _startHeartbeat(systemId);
          _startWsPing();
        case 'pusher_internal:subscription_error':
          _log.e('[WS] Subscription error (data: $data) — scheduling reconnect');
          _isConnecting = false;
          _wsPingTimer?.cancel();
          _wsPingTimer = null;
          _updateNotification(
            'Channel auth rejected',
            'Server rejected the channel subscription — reconnecting…',
          );
          _scheduleReconnect(systemId);
        case 'pusher:error':
          _log.e('[WS] Pusher error event received: data=$data');
        case 'App\\Events\\AgentCommandDispatched':
        case 'agent.command':
          await _onAgentCommand(data);
        default:
          _log.d('[WS] Unhandled event: $event, data: $data');
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

    // Lazy key-loading fallback: if the signing key wasn't loaded at startup
    // (e.g. SecureStorage was slow or failed), attempt to load it now before
    // the first authenticated request. Without this, publicKeyId is empty
    // and the server returns 401 "Unknown agent".
    final signingService = getIt<SigningService>();
    if (signingService.publicKeyId.isEmpty) {
      _log.w('[WS] publicKeyId is empty — attempting lazy key load');
      try {
        await signingService.loadExistingKeyPair();
      } catch (e) {
        _log.e('[WS] Lazy key load failed: $e');
      }
    }

    // If publicKeyId is still empty after the lazy load, don't bother sending
    // the auth request — it will always fail with 401.
    if (signingService.publicKeyId.isEmpty) {
      _log.e('[WS] Cannot authenticate — no signing key available. '
          'The agent may not be properly paired.');
      _isConnecting = false;
      _updateNotification(
        'Authentication error',
        'No signing key — please re-pair the device',
      );
      return; // Do NOT schedule reconnect — this is a permanent failure.
    }

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

      // Auth succeeded — reset the failure counter.
      _consecutiveAuthFailures = 0;
    } catch (e) {
      _isConnecting = false;

      // Detect persistent auth failures (401) vs transient network errors.
      final is401 = e.toString().contains('status code of 401');
      if (is401) {
        _consecutiveAuthFailures++;
        _log.e('[WS] Channel auth rejected (401) — '
            'attempt $_consecutiveAuthFailures/$_maxConsecutiveAuthFailures');

        if (_consecutiveAuthFailures >= _maxConsecutiveAuthFailures) {
          _log.e('[WS] Persistent auth failure — stopping reconnection. '
              'The agent\'s key may have been revoked on the server.');
          _updateNotification(
            'Authentication failed',
            'Server rejected agent credentials — please re-pair the device',
          );
          return; // Stop reconnecting — this won't fix itself.
        }
      } else {
        _log.e('[WS] Channel auth failed (network): $e');
      }

      _updateNotification(
        'Connection error',
        'Could not authenticate — reconnecting…',
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

  // ---------------------------------------------------------------------------
  // WebSocket-level keep-alive ping
  // ---------------------------------------------------------------------------

  /// Starts a periodic WebSocket-level ping that sends pusher:ping directly
  /// over the socket every [_wsPingInterval].
  ///
  /// This is the **primary** keep-alive mechanism — it proves liveness to the
  /// Reverb server over the WebSocket transport itself, unlike the HTTP
  /// heartbeat which only updates last_seen_at in the database.
  ///
  /// Reverb's activity_timeout (120 s) is the grace window after the last
  /// WebSocket message. By pinging every 30 s we stay well inside that window
  /// and prevent the server from closing what it considers an idle connection.
  void _startWsPing() {
    _wsPingTimer?.cancel();
    _wsPingTimer = Timer.periodic(_wsPingInterval, (_) {
      if (_isOnline && _channel != null) {
        _log.d('[WS] Sending client-initiated pusher:ping');
        _send({'event': 'pusher:ping', 'data': {}});
      }
    });
  }

  void _scheduleReconnect(String systemId) {
    // If the device is offline, don't schedule any reconnection timer.
    // The connectivity listener will trigger reconnection when the device
    // comes back online. This prevents freeze loops.
    if (!_isOnline) {
      _log.i('[WS] Device is offline — skipping reconnect timer');
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _updateNotification(
        'Agent offline',
        'No internet connection — will reconnect automatically',
      );
      return;
    }

    _log.w('[WS] Scheduling reconnect in ${_reconnectDelaySecs}s');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _wsPingTimer?.cancel();
    _wsPingTimer = null;
    _reconnectTimer?.cancel();

    _updateNotification(
      'Agent disconnected',
      'Reconnecting in ${_reconnectDelaySecs}s…',
    );

    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySecs), () async {
      _reconnectDelaySecs =
          (_reconnectDelaySecs * 2).clamp(2, _maxReconnectDelaySecs);

      // Re-check connectivity right before the attempt to avoid wasted work.
      final hasInternet = await _checkConnectivity();
      if (!hasInternet) {
        _log.i('[WS] Still offline at reconnect time — waiting for connectivity');
        _updateNotification(
          'Agent offline',
          'No internet connection — will reconnect automatically',
        );
        return;
      }

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

    // Load the signing key pair into the background isolate's SigningService.
    // This MUST happen before any authenticated HTTP call (broadcasting/auth,
    // heartbeat) — the signing interceptor reads publicKeyId from the cached
    // field, which is empty until loadExistingKeyPair() populates it.
    // Without this, X-Agent-Public-Key-Id is sent as empty → server 401.
    try {
      await getIt<SigningService>().loadExistingKeyPair();
    } catch (_) {
      // Non-fatal — the key will be loaded on the first sign() call.
    }

    await getIt<PairedSystemRegistry>().reload();

    // 2. Register all capability WebSocket handlers inside this isolate
    final router = getIt<WsMessageRouter>();
    router.registerHandler(
      CapabilityId.twoFa,
      const Auth2faWsHandler(),
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

    // Restore the default "Agent is running" notification after a 2FA
    // approval dialog is dismissed. The dialog sends this event on dispose()
    // via FlutterBackgroundService().invoke('restore_notification') (main→bg).
    service.on('restore_notification').listen((_) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Super Admin Agent',
          content: 'Agent is running — listening for commands',
        );
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onBackground(ServiceInstance service) async {
    return true;
  }
}
