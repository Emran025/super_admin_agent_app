import '../../domain/pairing/entities/paired_system.dart';
import '../../domain/pairing/repositories/pairing_repository.dart';
import '../domain/paired_system_registry.dart';

/// In-memory [PairedSystemRegistry] backed by a [Map].
///
/// Registered as a singleton in DI — never reconstructed after app start.
/// [reload()] must be called once in [main()] before any capability handler runs.
class PairedSystemRegistryImpl implements PairedSystemRegistry {
  final PairingRepository _pairingRepository;
  final Map<String, PairedSystem> _registry = {};

  PairedSystemRegistryImpl({required PairingRepository pairingRepository})
      : _pairingRepository = pairingRepository;

  @override
  PairedSystem? findBySystemId(String systemId) => _registry[systemId];

  @override
  List<PairedSystem> get all => List.unmodifiable(_registry.values);

  @override
  Future<void> reload() async {
    final result = await _pairingRepository.loadPairedSystems();
    result.fold(
      (_) => _registry.clear(), // On failure: clear — do not use stale data.
      (systems) {
        _registry.clear();
        for (final system in systems) {
          _registry[system.systemId] = system;
        }
      },
    );
  }

  @override
  void register(PairedSystem system) {
    _registry[system.systemId] = system;
  }

  @override
  void unregister(String systemId) {
    _registry.remove(systemId);
  }
}
