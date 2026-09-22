import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sar_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getRoles returns persisted roles without any network call', () async {
    SharedPreferences.setMockInitialValues({
      'user_roles': jsonEncode(['SALES_MOBILE', 'ADMIN']),
    });
    expect(await AuthService.getRoles(), ['SALES_MOBILE', 'ADMIN']);
  });

  test('canAddCustomer is true for a persisted allowed role', () async {
    SharedPreferences.setMockInitialValues({
      'user_roles': jsonEncode(['RECEPTION']),
    });
    expect(await AuthService.canAddCustomer(), isTrue);
  });

  test('canAddCustomer is false for a persisted disallowed role', () async {
    SharedPreferences.setMockInitialValues({
      'user_roles': jsonEncode(['ADMIN']),
    });
    expect(await AuthService.canAddCustomer(), isFalse);
  });

  test('getRoles returns an empty list for a corrupted stored value', () async {
    SharedPreferences.setMockInitialValues({'user_roles': 'not-json'});
    expect(await AuthService.getRoles(), isEmpty);
  });
}
