import 'package:equatable/equatable.dart';

/// A successfully paired server system — persisted to [SecureStorageService].
///
/// Serialized as JSON, stored under a fixed key.
/// Never stored with key material — only the agent's public identity and
/// the system's metadata.
class PairedSystem extends Equatable {
  final String agentId;
  final String systemId;
  final String systemLabel;
  final String baseUrl;
  final List<String> grantedCapabilities;
  final DateTime pairedAt;

  const PairedSystem({
    required this.agentId,
    required this.systemId,
    required this.systemLabel,
    required this.baseUrl,
    required this.grantedCapabilities,
    required this.pairedAt,
  });

  /// Returns true if [capability] is in the granted capabilities list.
  bool hasCapability(String capability) =>
      grantedCapabilities.contains(capability);

  @override
  List<Object?> get props => [agentId, systemId];
}
