import 'dart:convert';

/// Produces canonical JSON for use as signing input.
///
/// Canonical form (Constraint 2.4):
/// - All map keys sorted alphabetically at every nesting level
/// - UTF-8 encoded (jsonEncode default)
/// - No trailing whitespace
/// - No pretty-printing
///
/// This utility is the single source of canonical serialization across
/// all capability signing paths. A different serialization in any one
/// capability will produce signatures that fail server verification.
class CanonicalJson {
  const CanonicalJson._();

  /// Encodes [data] as canonical JSON with all keys sorted alphabetically
  /// at every nesting level, recursively.
  static String encode(Map<String, dynamic> data) {
    return jsonEncode(_sortDeep(data));
  }

  /// Recursively sorts all map keys. Lists have their elements processed
  /// but their order preserved (list order is semantic).
  static dynamic _sortDeep(dynamic value) {
    if (value is Map<String, dynamic>) {
      final sorted = <String, dynamic>{};
      final keys = value.keys.toList()..sort();
      for (final key in keys) {
        sorted[key] = _sortDeep(value[key]);
      }
      return sorted;
    } else if (value is List) {
      return value.map(_sortDeep).toList();
    }
    return value;
  }
}
