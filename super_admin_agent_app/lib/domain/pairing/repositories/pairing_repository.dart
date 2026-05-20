import 'package:dartz/dartz.dart';
import '../entities/linked_system.dart';
import '../entities/paired_system.dart';
import '../entities/pairing_token.dart';

// ---------------------------------------------------------------------------
// Failures
// ---------------------------------------------------------------------------

abstract class PairingFailure {
  const PairingFailure();
}

class TokenExpiredFailure extends PairingFailure {
  const TokenExpiredFailure();
}

class TokenInvalidFailure extends PairingFailure {
  final String reason;
  const TokenInvalidFailure([this.reason = '']);
}

class RegistrationFailure extends PairingFailure {
  final String reason;
  const RegistrationFailure([this.reason = '']);
}

class StorePairedSystemFailure extends PairingFailure {
  final Object? cause;
  const StorePairedSystemFailure({this.cause});
}

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/// Repository contract for the pairing domain.
///
/// The implementation lives in [lib/data/pairing/] — never in this layer.
/// All methods return [Either] — never throw.
abstract class PairingRepository {
  /// Parse a raw QR payload string into a [PairingToken].
  ///
  /// Synchronous — does no I/O, parses JSON already in memory.
  /// Returns [TokenInvalidFailure] on any JSON parse error or missing field.
  Either<PairingFailure, PairingToken> parsePairingToken(String rawQrValue);

  /// POST the agent's public key to the server and receive a [PairedSystem].
  ///
  /// Uses a plain unauthenticated [Dio] — at pairing time there is no agent
  /// identity yet. Authentication is the one-time pairing [token] in the body.
  Future<Either<PairingFailure, PairedSystem>> registerWithServer({
    required PairingToken token,
    required String publicKeyBase64,
    required String publicKeyId,
  });

  /// Persist the [PairedSystem] record to [SecureStorageService].
  Future<Either<PairingFailure, void>> savePairedSystem(PairedSystem system);

  /// Load all persisted [PairedSystem] records from [SecureStorageService].
  Future<Either<PairingFailure, List<PairedSystem>>> loadPairedSystems();

  /// Remove the [PairedSystem] with [systemId] from storage.
  Future<Either<PairingFailure, void>> removePairedSystem(String systemId);

  /// Link an external system via the gateway.
  Future<Either<PairingFailure, LinkedSystem>> linkExternalSystem({
    required String gatewaySystemId,
    required String systemId,
  });

  /// Unlink an external system via the gateway.
  Future<Either<PairingFailure, void>> unlinkExternalSystem({
    required String gatewaySystemId,
    required String systemId,
  });

  /// Get all external systems linked via the gateway.
  Future<Either<PairingFailure, List<LinkedSystem>>> getLinkedSystems({
    required String gatewaySystemId,
  });
}
