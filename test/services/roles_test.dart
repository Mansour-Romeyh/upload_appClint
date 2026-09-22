import 'package:flutter_test/flutter_test.dart';
import 'package:sar_app/services/roles.dart';

void main() {
  group('extractRoles', () {
    test('reads the roles list', () {
      expect(extractRoles({'roles': ['RECEPTION', 'ADMIN']}),
          ['RECEPTION', 'ADMIN']);
    });
    test('falls back to a single role', () {
      expect(extractRoles({'role': 'SALES_MOBILE'}), ['SALES_MOBILE']);
    });
    test('returns empty when neither field is present', () {
      expect(extractRoles({'name': 'x'}), isEmpty);
    });
    test('returns empty for null', () {
      expect(extractRoles(null), isEmpty);
    });
    test('stringifies non-string entries in the roles list', () {
      expect(extractRoles({'roles': [1, null]}), ['1', 'null']);
    });
  });

  group('canAddCustomerFromRoles', () {
    test('true for RECEPTION', () {
      expect(canAddCustomerFromRoles(['RECEPTION']), isTrue);
    });
    test('true when RECEPTION is among several roles', () {
      expect(canAddCustomerFromRoles(['ADMIN', 'RECEPTION']), isTrue);
    });
    test('is case-insensitive', () {
      expect(canAddCustomerFromRoles(['reception']), isTrue);
    });
    test('false for SALES_MOBILE (read-only for customers)', () {
      expect(canAddCustomerFromRoles(['SALES_MOBILE']), isFalse);
    });
    test('false for unrelated roles', () {
      expect(canAddCustomerFromRoles(['ADMIN', 'HR']), isFalse);
    });
    test('false for an empty list', () {
      expect(canAddCustomerFromRoles([]), isFalse);
    });
  });
}
