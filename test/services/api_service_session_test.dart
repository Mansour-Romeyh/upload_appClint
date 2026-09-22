import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sar_app/services/api_service.dart';
import 'package:sar_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ApiService.onSessionExpired = null);

  test('401 on an authenticated request fires onSessionExpired', () {
    var fired = false;
    ApiService.onSessionExpired = () => fired = true;

    expect(
      () => ApiService.parseBody(
        http.Response('{"error":"Invalid or expired token"}', 401),
        authenticated: true,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(fired, isTrue);
  });

  test('session-expired error message is user-facing Arabic, not raw English',
      () {
    ApiService.onSessionExpired = () {};
    try {
      ApiService.parseBody(
        http.Response('{"error":"Invalid or expired token"}', 401),
        authenticated: true,
      );
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.message, isNot(contains('Invalid or expired token')));
      expect(e.message, contains('الجلسة'));
    }
  });

  test('401 on an unauthenticated request (login) does not fire', () {
    var fired = false;
    ApiService.onSessionExpired = () => fired = true;

    expect(
      () => ApiService.parseBody(
        http.Response('{"error":"Invalid credentials"}', 401),
        authenticated: false,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(fired, isFalse);
  });

  test('403 permission error does not fire onSessionExpired', () {
    var fired = false;
    ApiService.onSessionExpired = () => fired = true;

    expect(
      () => ApiService.parseBody(
        http.Response('{"error":"Missing permission: customers.create"}', 403),
        authenticated: true,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(fired, isFalse);
  });

  test('clearSession removes all persisted session keys', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'stale-token',
      'user_id': 'u1',
      'user_email': 'a@b.c',
      'full_name': 'Test',
      'employee_id': 'EMP-1',
      'user_roles': '["ADMIN"]',
    });

    await AuthService.clearSession();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('user_id'), isNull);
    expect(prefs.getString('user_roles'), isNull);
    expect(await AuthService.isLoggedIn(), isFalse);
  });

  test('logout clears the local session even when the server is unreachable',
      () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'stale-token'});

    await AuthService.logout();

    expect(await AuthService.isLoggedIn(), isFalse);
  });
}
