import 'package:dartz/dartz.dart';

// ---------------------------------------------------------------------------
// Failures
// ---------------------------------------------------------------------------

abstract class StorageFailure {
  const StorageFailure();
}

class StorageWriteFailure extends StorageFailure {
  final Object? cause;
  const StorageWriteFailure({this.cause});
}

class StorageReadFailure extends StorageFailure {
  final Object? cause;
  const StorageReadFailure({this.cause});
}

class StorageDeleteFailure extends StorageFailure {
  final Object? cause;
  const StorageDeleteFailure({this.cause});
}

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/// The sole secret storage path in the system (Constraint 2.3).
///
/// Secrets include: private key material, agent ID, system IDs, base URLs,
/// capability lists, and session tokens.
///
/// Implementations must use Android EncryptedSharedPreferences.
/// SharedPreferences, plain SQLite, and files are FORBIDDEN for any secret.
abstract class SecureStorageService {
  /// Writes [value] under [key]. Overwrites if key already exists.
  Future<Either<StorageFailure, void>> write({
    required String key,
    required String value,
  });

  /// Reads the value stored at [key].
  /// Returns [Right(null)] when the key is not found (not a failure).
  Future<Either<StorageFailure, String?>> read({required String key});

  /// Deletes the entry at [key].
  Future<Either<StorageFailure, void>> delete({required String key});

  /// Deletes all entries in this storage.
  /// Called only during full unpair. Use with caution.
  Future<Either<StorageFailure, void>> deleteAll();

  /// Returns all key-value pairs currently stored.
  Future<Either<StorageFailure, Map<String, String>>> readAll();
}
