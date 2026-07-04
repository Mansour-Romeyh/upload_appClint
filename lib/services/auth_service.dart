import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await ApiService.login(email, password);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token'] ?? '');

    final user = data['user'] as Map?;
    final employee = data['employee'] as Map?;
    await prefs.setString('user_id', user?['id'] ?? '');
    await prefs.setString('user_email', user?['email'] ?? '');
    await prefs.setString('full_name', user?['name'] ?? '');
    await prefs.setString('employee_id', employee?['employeeCode'] ?? '');

    return data;
  }

  static Future<void> deleteAccount() async {
    await ApiService.deleteJson('/api/mobile/me');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('full_name');
    await prefs.remove('employee_id');
  }

  static Future<void> logout() async {
    try {
      await ApiService.postJson('/api/mobile/auth/logout');
    } catch (_) {
      /* server-side is a no-op; ignore errors so logout always succeeds */
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('full_name');
    await prefs.remove('employee_id');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return token.isNotEmpty;
  }

  static Future<String> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('full_name') ?? '';
  }

  static Future<String> getEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('employee_id') ?? '';
  }
}
