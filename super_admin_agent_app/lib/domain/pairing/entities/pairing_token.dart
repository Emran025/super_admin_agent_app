import 'package:equatable/equatable.dart';

/// A scanned QR pairing token — in-memory ONLY.
///
/// This object is NEVER written to any storage medium (Constraint 2.1).
/// It is parsed from the camera scan, shown to the owner for confirmation,
/// used in the registration call, and then garbage collected.
///
/// The optional [reverbHost], [reverbPort], and [reverbAppKey] fields carry
/// the public WebSocket connection parameters embedded directly in the QR by
/// the server. When present, these values are the authoritative source for
/// Reverb connectivity (the QR is generated with the correct external host/port,
/// not internal bind addresses). The repository prefers these over the values
/// returned in the pairing API response.
class PairingToken extends Equatable {
  final String version;
  final String systemId;
  final String systemLabel;
  final String pairingEndpoint;
  final String token;
  final DateTime expiresAt;
  final List<String> capabilities;

  // Optional Reverb WebSocket connection parameters embedded in the QR.
  final String? reverbHost;
  final int? reverbPort;
  final String? reverbAppKey;

  const PairingToken({
    required this.version,
    required this.systemId,
    required this.systemLabel,
    required this.pairingEndpoint,
    required this.token,
    required this.expiresAt,
    required this.capabilities,
    this.reverbHost,
    this.reverbPort,
    this.reverbAppKey,
  });

  /// True when the token has passed its expiry time (UTC).
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  @override
  List<Object?> get props => [systemId, token];
}
