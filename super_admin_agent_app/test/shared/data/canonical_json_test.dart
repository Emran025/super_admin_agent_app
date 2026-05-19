import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin_agent/shared/data/canonical_json.dart';

void main() {
  group('CanonicalJson', () {
    test('unsorted keys are sorted alphabetically in output', () {
      final input = <String, dynamic>{
        'zebra': 1,
        'apple': 2,
        'mango': 3,
      };
      final result = CanonicalJson.encode(input);
      expect(result, equals('{"apple":2,"mango":3,"zebra":1}'));
    });

    test('nested maps have their keys sorted independently', () {
      final input = <String, dynamic>{
        'outer_z': <String, dynamic>{
          'inner_b': 'two',
          'inner_a': 'one',
        },
        'outer_a': 'top',
      };
      final result = CanonicalJson.encode(input);
      // outer keys sorted: outer_a, outer_z
      // inner keys sorted: inner_a, inner_b
      expect(
        result,
        equals('{"outer_a":"top","outer_z":{"inner_a":"one","inner_b":"two"}}'),
      );
    });

    test('output is identical across two calls with the same input', () {
      final input = <String, dynamic>{
        'c': 3,
        'a': 1,
        'b': 2,
      };
      final first = CanonicalJson.encode(input);
      final second = CanonicalJson.encode(input);
      expect(first, equals(second));
    });

    test('lists preserve element order but map elements inside are sorted', () {
      final input = <String, dynamic>{
        'items': [
          <String, dynamic>{'z': 1, 'a': 2},
          <String, dynamic>{'y': 3, 'b': 4},
        ],
      };
      final result = CanonicalJson.encode(input);
      expect(
        result,
        equals('{"items":[{"a":2,"z":1},{"b":4,"y":3}]}'),
      );
    });
  });
}
