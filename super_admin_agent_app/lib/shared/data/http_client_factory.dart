import 'package:dio/dio.dart';

import '../domain/nonce_generator.dart';
import '../domain/paired_system_registry.dart';
import '../domain/signing_service.dart';
import 'canonical_json.dart';

/// Produces authenticated [Dio] instances bound to a specific paired system.
///
/// This factory is the ONLY permitted place to create authenticated Dio
/// instances in the entire codebase (Constraint 2.2).
///
/// Every [Dio] returned has exactly one [_AgentSigningInterceptor] attached.
/// Auth headers are NEVER added manually in repositories.
class HttpClientFactory {
  final SigningService _signingService;
  final NonceGenerator _nonceGenerator;
  final PairedSystemRegistry _registry;

  const HttpClientFactory({
    required SigningService signingService,
    required NonceGenerator nonceGenerator,
    required PairedSystemRegistry registry,
  })  : _signingService = signingService,
        _nonceGenerator = nonceGenerator,
        _registry = registry;

  /// Returns an authenticated [Dio] configured for [systemId].
  ///
  /// Throws [ArgumentError] (CF-03) if [systemId] is not in the registry.
  /// This is a hard failure — a client for an unknown system must never
  /// be constructed.
  Dio forSystem(String systemId) {
    final system = _registry.findBySystemId(systemId);
    if (system == null) {
      throw ArgumentError(
        'CF-03: Cannot create HTTP client for unknown system "$systemId". '
        'System must be paired before any network call is attempted.',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: system.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Hard timeouts so every call fails fast on network loss instead of
        // hanging indefinitely and freezing the async chain.
        connectTimeout: const Duration(seconds: 10),
        sendTimeout:    const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(
      _AgentSigningInterceptor(
        agentId: system.agentId,
        signingService: _signingService,
        nonceGenerator: _nonceGenerator,
      ),
    );

    return dio;
  }
}

// ---------------------------------------------------------------------------
// Signing interceptor — the only signing path in the network layer
// ---------------------------------------------------------------------------

/// Attaches agent authentication headers to every outgoing request.
///
/// Header set (Constraint 2.2):
/// - [X-Agent-Id]           — the agent's UUID from the paired system record
/// - [X-Agent-Public-Key-Id] — the signing key alias
/// - [X-Agent-Nonce]        — a fresh 256-bit random value (one-use)
/// - [X-Agent-Timestamp]    — current UTC ISO 8601 timestamp
/// - [X-Agent-Signature]    — ECDSA-SHA256 over canonical body + nonce + timestamp
///
/// If signing fails, the request is rejected via [handler.reject()] —
/// it is NEVER sent unsigned (CF-02 prevention).
class _AgentSigningInterceptor extends Interceptor {
  final String _agentId;
  final SigningService _signingService;
  final NonceGenerator _nonceGenerator;

  _AgentSigningInterceptor({
    required String agentId,
    required SigningService signingService,
    required NonceGenerator nonceGenerator,
  })  : _agentId = agentId,
        _signingService = signingService,
        _nonceGenerator = nonceGenerator;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Build canonical body from the request data map.
    final body = options.data is Map<String, dynamic>
        ? CanonicalJson.encode(options.data as Map<String, dynamic>)
        : '';

    final nonce = _nonceGenerator.generate();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // Signing input: canonical body + nonce + timestamp, newline-separated.
    final signingInput = '$body\n$nonce\n$timestamp';

    final signResult = await _signingService.sign(signingInput);

    signResult.fold(
      (failure) {
        handler.reject(
          DioException(
            requestOptions: options,
            message: 'CF-02: Signing failed — request not sent. '
                'Failure: ${failure.runtimeType}',
            type: DioExceptionType.unknown,
          ),
        );
      },
      (signature) {
        options.headers['X-Agent-Id'] = _agentId;
        options.headers['X-Agent-Public-Key-Id'] =
            _signingService.publicKeyId;
        options.headers['X-Agent-Nonce'] = nonce;
        options.headers['X-Agent-Timestamp'] = timestamp;
        options.headers['X-Agent-Signature'] = signature;
        handler.next(options);
      },
    );
  }
}
