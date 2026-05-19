import 'package:dartz/dartz.dart';
import 'package:super_admin_agent/shared/domain/secure_storage_service.dart';

/// In-memory [SecureStorageService] for unit tests.
///
/// No platform dependencies — safe to run with [dart test].
class FakeSecureStorage implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<Either<StorageFailure, void>> write({
    required String key,
    required String value,
  }) async {
    _store[key] = value;
    return const Right(null);
  }

  @override
  Future<Either<StorageFailure, String?>> read({required String key}) async {
    return Right(_store[key]);
  }

  @override
  Future<Either<StorageFailure, void>> delete({required String key}) async {
    _store.remove(key);
    return const Right(null);
  }

  @override
  Future<Either<StorageFailure, void>> deleteAll() async {
    _store.clear();
    return const Right(null);
  }

  @override
  Future<Either<StorageFailure, Map<String, String>>> readAll() async {
    return Right(Map.unmodifiable(_store));
  }
}
