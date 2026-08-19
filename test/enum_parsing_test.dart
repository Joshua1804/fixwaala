import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';

void main() {
  group('byNameOrDefault', () {
    test('resolves a matching name', () {
      expect(
        ServiceCategory.values.byNameOrDefault('plumber', ServiceCategory.unknown),
        ServiceCategory.plumber,
      );
    });

    test('falls back on a value no case matches, instead of throwing', () {
      expect(
        ServiceCategory.values.byNameOrDefault('gasFitter', ServiceCategory.unknown),
        ServiceCategory.unknown,
      );
    });

    test('falls back on null instead of throwing', () {
      expect(
        UserRole.values.byNameOrDefault(null, UserRole.customer),
        UserRole.customer,
      );
    });
  });
}
