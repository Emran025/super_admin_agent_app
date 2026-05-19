import 'dart:convert';
import 'package:super_admin_agent/domain/pairing/entities/paired_system.dart';
import 'package:super_admin_agent/domain/pairing/entities/pairing_token.dart';

/// Maps JSON ↔ [PairingToken] for the pairing ceremony.
///
/// Used ONLY inside [PairingRepositoryImpl.parsePairingToken].
/// The raw QR JSON keys are snake_case per the server contract.
class PairingTokenDto {
  final String version;
  final String systemId;
  final String systemLabel;
  final String pairingEndpoint;
  final String token;
  final String expiresAt;
  final List<String> capabilities;

  const PairingTokenDto({
    required this.version,
    required this.systemId,
    required this.systemLabel,
    required this.pairingEndpoint,
    required this.token,
    required this.expiresAt,
    required this.capabilities,
  });

  /// Parses the raw JSON string from the QR camera scan.
  ///
  /// Throws [FormatException] or [TypeError] on missing/invalid fields —
  /// callers must catch these and return [TokenInvalidFailure].
  factory PairingTokenDto.fromJson(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;

    return PairingTokenDto(
      version: map['version'] as String,
      systemId: map['system_id'] as String,
      systemLabel: map['system_label'] as String,
      pairingEndpoint: map['pairing_endpoint'] as String,
      token: map['token'] as String,
      expiresAt: map['expires_at'] as String,
      capabilities: List<String>.from(map['capabilities'] as List),
    );
  }

  /// Converts this DTO to the in-memory [PairingToken] entity.
  PairingToken toEntity() {
    return PairingToken(
      version: version,
      systemId: systemId,
      systemLabel: systemLabel,
      pairingEndpoint: pairingEndpoint,
      token: token,
      expiresAt: DateTime.parse(expiresAt).toUtc(),
      capabilities: List<String>.unmodifiable(capabilities),
    );
  }
}

/// Maps JSON ↔ [PairedSystem] for persistence and server response parsing.
///
/// The server pairing response includes Reverb WebSocket connection parameters
/// (reverb_host, reverb_port, reverb_app_key) in addition to the agent identity
/// fields. These are parsed here and stored separately in secure storage by
/// [PairingRepositoryImpl.registerWithServer] so that [AgentWebSocketService]
/// can read them at startup.
class PairedSystemDto {
  final String agentId;
  final String systemId;
  final String systemLabel;
  final String baseUrl;
  final List<String> grantedCapabilities;
  final String pairedAt;

  // Reverb WebSocket connection parameters — present only in server response,
  // not persisted as part of the PairedSystem entity (stored separately in
  // secure storage by PairingRepositoryImpl).
  final String? reverbHost;
  final int? reverbPort;
  final String? reverbAppKey;

  const PairedSystemDto({
    required this.agentId,
    required this.systemId,
    required this.systemLabel,
    required this.baseUrl,
    required this.grantedCapabilities,
    required this.pairedAt,
    this.reverbHost,
    this.reverbPort,
    this.reverbAppKey,
  });

  factory PairedSystemDto.fromJson(Map<String, dynamic> map) {
    return PairedSystemDto(
      agentId: map['agent_id'] as String,
      systemId: map['system_id'] as String,
      systemLabel: map['system_label'] as String,
      baseUrl: map['base_url'] as String,
      grantedCapabilities:
          List<String>.from(map['granted_capabilities'] as List),
      pairedAt: map['paired_at'] as String,
      reverbHost: map['reverb_host'] as String?,
      reverbPort: map['reverb_port'] as int?,
      reverbAppKey: map['reverb_app_key'] as String?,
    );
  }

  static PairedSystemDto fromEntity(PairedSystem system) {
    return PairedSystemDto(
      agentId: system.agentId,
      systemId: system.systemId,
      systemLabel: system.systemLabel,
      baseUrl: system.baseUrl,
      grantedCapabilities: system.grantedCapabilities,
      pairedAt: system.pairedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'agent_id': agentId,
        'system_id': systemId,
        'system_label': systemLabel,
        'base_url': baseUrl,
        'granted_capabilities': grantedCapabilities,
        'paired_at': pairedAt,
      };

  PairedSystem toEntity() {
    return PairedSystem(
      agentId: agentId,
      systemId: systemId,
      systemLabel: systemLabel,
      baseUrl: baseUrl,
      grantedCapabilities: List<String>.unmodifiable(grantedCapabilities),
      pairedAt: DateTime.parse(pairedAt).toUtc(),
    );
  }
}
