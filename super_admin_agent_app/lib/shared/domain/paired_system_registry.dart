import '../../domain/pairing/entities/paired_system.dart';

/// In-memory registry of all paired systems.
///
/// This is a SHARED infrastructure concept — not domain-specific.
/// The FCM router, HTTP client factory, and all capability handlers
/// depend on this interface (Constraint 2.5).
///
/// Lifecycle:
/// - [reload()] is called once at app startup
/// - [register()] is called when a new pairing succeeds
/// - [unregister()] is called on unpair
/// - Never reconstructed — lives as a singleton for the app lifetime
abstract class PairedSystemRegistry {
  /// Returns the [PairedSystem] with [systemId], or null if not found.
  PairedSystem? findBySystemId(String systemId);

  /// All currently registered paired systems.
  List<PairedSystem> get all;

  /// Reloads the registry from persistent storage.
  /// Must be called once at app startup before any capability handler runs.
  Future<void> reload();

  /// Registers a newly paired [system] into the in-memory registry.
  void register(PairedSystem system);

  /// Removes the system with [systemId] from the in-memory registry.
  void unregister(String systemId);
}
