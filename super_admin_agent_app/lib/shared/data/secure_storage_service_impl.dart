import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/secure_storage_service.dart';

/// [SecureStorageService] backed by [FlutterSecureStorage] with
/// Android EncryptedSharedPreferences.
///
/// This is the sole permitted path for writing secrets (Constraint 2.3).
/// SharedPreferences, plain SQLite, and files are forbidden for secrets.
class SecureStorageServiceImpl implements SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageServiceImpl()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  @override
  Future<Either<StorageFailure, void>> write({
    required String key,
    required String value,
  }) async {
    try {
      await _storage.write(key: key, value: value);
      return const Right(null);
    } catch (e) {
      return Left(StorageWriteFailure(cause: e));
    }
  }

  @override
  Future<Either<StorageFailure, String?>> read({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      return Right(value);
    } catch (e) {
      return Left(StorageReadFailure(cause: e));
    }
  }

  @override
  Future<Either<StorageFailure, void>> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
      return const Right(null);
    } catch (e) {
      return Left(StorageDeleteFailure(cause: e));
    }
  }

  @override
  Future<Either<StorageFailure, void>> deleteAll() async {
    try {
      await _storage.deleteAll();
      return const Right(null);
    } catch (e) {
      return Left(StorageDeleteFailure(cause: e));
    }
  }

  @override
  Future<Either<StorageFailure, Map<String, String>>> readAll() async {
    try {
      final all = await _storage.readAll();
      return Right(all);
    } catch (e) {
      return Left(StorageReadFailure(cause: e));
    }
  }
}
