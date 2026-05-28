import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../domain/pairing/entities/linked_system.dart';
import '../../../domain/pairing/entities/paired_system.dart';
import '../../../domain/pairing/entities/pairing_token.dart';
import '../../../domain/pairing/repositories/pairing_repository.dart';
import '../../../shared/data/http_client_factory.dart';
import '../../../shared/domain/secure_storage_service.dart';
import '../dtos/pairing_dtos.dart';

// Secure storage keys for Reverb WebSocket connection parameters.
// Must match the constants in AgentWebSocketService.
const _kReverbHost = 'reverb_host';
const _kReverbPort = 'reverb_port';
const _kReverbAppKey = 'reverb_app_key';

/// Concrete implementation of [PairingRepository].
///
/// Uses a plain unauthenticated [Dio] instance — the only acceptable
/// use of raw [Dio()] in this codebase. At pairing time, there is no
/// agent identity to sign with. Authentication is the one-time token
/// in the request body. (Spec §4 justification)
///
/// All URLs come from the QR token — never hardcoded (Constraint 2.2 / Axiom 9).
///
/// After a successful server registration, the Reverb WebSocket connection
/// parameters (reverb_host, reverb_port, reverb_app_key) returned in the
/// pairing response are stored in secure storage so that [AgentWebSocketService]
/// can connect to Reverb at startup without re-fetching them.
class PairingRepositoryImpl implements PairingRepository {
  static const String _storageKey = 'paired_systems_json_list';

  final SecureStorageService _secureStorage;

  // Plain unauthenticated Dio — intentional, see class doc.
  final Dio _dio;

  PairingRepositoryImpl({
    required SecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ?? Dio();

  @override
  Either<PairingFailure, PairingToken> parsePairingToken(String rawQrValue) {
    try {
      final dto = PairingTokenDto.fromJson(rawQrValue);
      final entity = dto.toEntity();

      // Surface expired tokens as a distinct failure type.
      if (entity.isExpired) {
        return const Left(TokenExpiredFailure());
      }

      return Right(entity);
    } on FormatException catch (e) {
      return Left(TokenInvalidFailure(e.message));
    } catch (_) {
      return const Left(TokenInvalidFailure('Missing or invalid required field'));
    }
  }

  @override
  Future<Either<PairingFailure, PairedSystem>> registerWithServer({
    required PairingToken token,
    required String publicKeyBase64,
    required String publicKeyId,
  }) async {
    try {
      // URL comes from the QR token — never hardcoded (Axiom 9 / CF-03).
      final response = await _dio.post<Map<String, dynamic>>(
        '${token.pairingEndpoint}/v1/pair',
        data: {
          'pairing_token': token.token,
          'public_key_base64': publicKeyBase64,
          'public_key_id': publicKeyId,
        },
      );

      final body = response.data;
      if (body == null) {
        return const Left(RegistrationFailure('Empty server response'));
      }

      var dto = PairedSystemDto.fromJson(body);

      // Rewrite loopback addresses dynamically using the pairingEndpoint host/port that successfully responded
      final parsedBaseUrl = Uri.tryParse(dto.baseUrl);
      final parsedEndpoint = Uri.tryParse(token.pairingEndpoint);
      if (parsedBaseUrl != null && parsedEndpoint != null) {
        final baseHost = parsedBaseUrl.host;
        if (baseHost == 'localhost' || baseHost == '127.0.0.1') {
          final scheme = parsedEndpoint.scheme;
          final host = parsedEndpoint.host;
          final port = parsedEndpoint.hasPort ? ':${parsedEndpoint.port}' : '';
          
          final newBaseUrl = '$scheme://$host$port';
          
          String? newReverbHost = dto.reverbHost;
          if (newReverbHost == 'localhost' || newReverbHost == '127.0.0.1') {
            newReverbHost = host;
          }

          dto = PairedSystemDto(
            agentId: dto.agentId,
            systemId: dto.systemId,
            systemLabel: dto.systemLabel,
            baseUrl: newBaseUrl,
            grantedCapabilities: dto.grantedCapabilities,
            pairedAt: dto.pairedAt,
            reverbHost: newReverbHost,
            reverbPort: dto.reverbPort,
            reverbAppKey: dto.reverbAppKey,
          );
        } else {
          var updatedBaseUrl = dto.baseUrl;
          if (parsedBaseUrl.scheme == 'http' && parsedEndpoint.scheme == 'https') {
            updatedBaseUrl = parsedBaseUrl.replace(scheme: 'https').toString();
          }

          String? resolvedHost = dto.reverbHost;
          if (resolvedHost == 'localhost' || resolvedHost == '127.0.0.1') {
            resolvedHost = parsedBaseUrl.host;
          }

          dto = PairedSystemDto(
            agentId: dto.agentId,
            systemId: dto.systemId,
            systemLabel: dto.systemLabel,
            baseUrl: updatedBaseUrl,
            grantedCapabilities: dto.grantedCapabilities,
            pairedAt: dto.pairedAt,
            reverbHost: resolvedHost,
            reverbPort: dto.reverbPort,
            reverbAppKey: dto.reverbAppKey,
          );
        }
      }

      // Prefer Reverb connection parameters embedded directly in the QR code
      // over values returned by the pairing API response. The QR is generated
      // by the server using the public-facing hostname and port (derived from
      // the HTTP request), so it is always correct for external clients.
      // The API response values may contain internal bind addresses
      // (e.g. 0.0.0.0, 127.0.0.1) when the server env is not tuned for
      // external access.
      final resolvedReverbHost = token.reverbHost ?? dto.reverbHost;
      final resolvedReverbPort = token.reverbPort ?? dto.reverbPort;
      final resolvedReverbAppKey = token.reverbAppKey ?? dto.reverbAppKey;

      if (resolvedReverbHost != null || resolvedReverbPort != null || resolvedReverbAppKey != null) {
        dto = PairedSystemDto(
          agentId: dto.agentId,
          systemId: dto.systemId,
          systemLabel: dto.systemLabel,
          baseUrl: dto.baseUrl,
          grantedCapabilities: dto.grantedCapabilities,
          pairedAt: dto.pairedAt,
          reverbHost: resolvedReverbHost,
          reverbPort: resolvedReverbPort,
          reverbAppKey: resolvedReverbAppKey,
        );
      }

      // Persist Reverb WebSocket connection parameters to secure storage so
      // that AgentWebSocketService can connect to Reverb after pairing.
      // These are NOT part of the PairedSystem entity itself.
      await _saveReverbParams(dto);

      return Right(dto.toEntity());
    } catch (e) {
      return Left(_handleNetworkException(e));
    }
  }

  @override
  Future<Either<PairingFailure, void>> savePairedSystem(
    PairedSystem system,
  ) async {
    final loadResult = await _loadAll();
    final systems = loadResult.getOrElse(() => []);

    // Replace existing entry if systemId already present, else append.
    final updated = [
      ...systems.where((s) => s.systemId != system.systemId),
      system,
    ];

    return _persistAll(updated);
  }

  @override
  Future<Either<PairingFailure, List<PairedSystem>>> loadPairedSystems() async {
    return _loadAll();
  }

  @override
  Future<Either<PairingFailure, void>> removePairedSystem(
    String systemId,
  ) async {
    final loadResult = await _loadAll();
    final systems = loadResult.getOrElse(() => []);
    final updated = systems.where((s) => s.systemId != systemId).toList();
    return _persistAll(updated);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Saves Reverb WebSocket connection parameters from the server pairing
  /// response to secure storage. Silently skips fields that are absent
  /// (e.g. during unit tests with partial mocks).
  Future<void> _saveReverbParams(PairedSystemDto dto) async {
    if (dto.reverbHost != null) {
      await _secureStorage.write(key: _kReverbHost, value: dto.reverbHost!);
    }
    if (dto.reverbPort != null) {
      await _secureStorage.write(
        key: _kReverbPort,
        value: dto.reverbPort!.toString(),
      );
    }
    if (dto.reverbAppKey != null) {
      await _secureStorage.write(
        key: _kReverbAppKey,
        value: dto.reverbAppKey!,
      );
    }
  }

  Future<Either<PairingFailure, List<PairedSystem>>> _loadAll() async {
    final readResult = await _secureStorage.read(key: _storageKey);
    return readResult.fold(
      (_) => const Left(StorePairedSystemFailure(cause: 'Read failed')),
      (raw) {
        if (raw == null || raw.isEmpty) return const Right([]);
        try {
          final list = jsonDecode(raw) as List;
          final systems = list
              .map((e) => PairedSystemDto.fromJson(e as Map<String, dynamic>).toEntity())
              .toList();
          return Right(systems);
        } catch (e) {
          return Left(StorePairedSystemFailure(cause: e));
        }
      },
    );
  }

  Future<Either<PairingFailure, void>> _persistAll(
    List<PairedSystem> systems,
  ) async {
    try {
      final json = jsonEncode(
        systems.map((s) => PairedSystemDto.fromEntity(s).toJson()).toList(),
      );
      final writeResult = await _secureStorage.write(
        key: _storageKey,
        value: json,
      );
      return writeResult.fold(
        (e) => Left(StorePairedSystemFailure(cause: e)),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(StorePairedSystemFailure(cause: e));
    }
  }

  @override
  Future<Either<PairingFailure, LinkedSystem>> linkExternalSystem({
    required String gatewaySystemId,
    required String systemId,
  }) async {
    try {
      final clientFactory = GetIt.I<HttpClientFactory>();
      final dio = clientFactory.forSystem(gatewaySystemId);

      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/agent/link-system',
        data: {'system_id': systemId},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        return const Left(RegistrationFailure('Failed to link system'));
      }

      final systemJson = body['system'] as Map<String, dynamic>;
      return Right(LinkedSystem.fromJson(systemJson));
    } catch (e) {
      return Left(_handleNetworkException(e, 'Failed to link system'));
    }
  }

  @override
  Future<Either<PairingFailure, void>> unlinkExternalSystem({
    required String gatewaySystemId,
    required String systemId,
  }) async {
    try {
      final clientFactory = GetIt.I<HttpClientFactory>();
      final dio = clientFactory.forSystem(gatewaySystemId);

      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/agent/unlink-system',
        data: {'system_id': systemId},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        return const Left(RegistrationFailure('Failed to unlink system'));
      }

      return const Right(null);
    } catch (e) {
      return Left(_handleNetworkException(e, 'Failed to unlink system'));
    }
  }

  @override
  Future<Either<PairingFailure, List<LinkedSystem>>> getLinkedSystems({
    required String gatewaySystemId,
  }) async {
    try {
      final clientFactory = GetIt.I<HttpClientFactory>();
      final dio = clientFactory.forSystem(gatewaySystemId);

      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/agent/linked-systems',
      );

      final body = response.data;
      if (body == null) {
        return const Left(RegistrationFailure('Empty response from server'));
      }

      final rawSystems = body['systems'];
      if (rawSystems == null) {
        return const Left(RegistrationFailure('Server response missing "systems" field'));
      }
      if (rawSystems is! List) {
        return const Left(RegistrationFailure('Server returned unexpected type for "systems" field'));
      }

      final systems = rawSystems
          .whereType<Map<String, dynamic>>()
          .map(LinkedSystem.fromJson)
          .toList();
      return Right(systems);
    } catch (e) {
      return Left(_handleNetworkException(e, 'Failed to fetch linked systems'));
    }
  }

  // Helper to translate Dio and other exceptions into friendly errors
  PairingFailure _handleNetworkException(Object e, [String defaultMsg = 'Network error']) {
    if (e is DioException) {
      final error = e.error;
      
      // Check for timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const RegistrationFailure(
          'انتهت مهلة الاتصال بالخادم. يرجى التحقق من جودة اتصال الإنترنت والمحاولة مرة أخرى (Connection Timeout).',
        );
      }
      
      // Check for SocketException
      if (error != null && error.toString().contains('SocketException')) {
        final errStr = error.toString();
        if (errStr.contains('Failed host lookup') || errStr.contains('errno = 7') || errStr.contains('No address associated with hostname')) {
          return const RegistrationFailure(
            'فشل الاتصال: لم يتم العثور على عنوان السيرفر (خطأ في DNS). تأكد من صحة الرابط/الدومين، ومن أن الهاتف متصل بإنترنت فعال وبإمكانه الوصول للموقع.',
          );
        } else if (errStr.contains('Connection refused') || errStr.contains('errno = 111')) {
          return const RegistrationFailure(
            'فشل الاتصال: رفض السيرفر الاتصال بالمنفذ المطلوب. تأكد من أن السيرفر يعمل وأن بورت الويب وسيرفر WebSockets مفتوحين.',
          );
        } else {
          return RegistrationFailure(
            'خطأ في الشبكة (SocketException): ${e.message ?? errStr}',
          );
        }
      }
      
      // Handle bad response status codes
      if (e.type == DioExceptionType.badResponse) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        String? serverError;
        if (responseData is Map && responseData.containsKey('error')) {
          serverError = responseData['error']?.toString();
        } else if (responseData is Map && responseData.containsKey('message')) {
          serverError = responseData['message']?.toString();
        }
        
        if (serverError != null && serverError.isNotEmpty) {
          return RegistrationFailure('خطأ من السيرفر: $serverError');
        }
        
        switch (statusCode) {
          case 401:
            return const RegistrationFailure('غير مصرح: رمز الربط (Token) غير صالح أو انتهت صلاحيته.');
          case 403:
            return const RegistrationFailure('مرفوض: التوقيع الرقمي غير صالح أو تم رفض الطلب من السيرفر.');
          case 404:
            return const RegistrationFailure('فشل الاتصال: الرابط المطلوب غير موجود على السيرفر (404).');
          case 500:
            return const RegistrationFailure('خطأ داخلي في السيرفر (500). يرجى مراجعة سجلات السيرفر.');
          default:
            return RegistrationFailure('استجابة غير صالحة من السيرفر ($statusCode).');
        }
      }
      
      return RegistrationFailure(e.message ?? defaultMsg);
    }
    
    return RegistrationFailure(e.toString());
  }
}
