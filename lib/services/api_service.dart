import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL for the Next.js backend (real-estate-app).
  // Default targets production. Override at build time for local dev:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sar-iq.com',
  );

  static Future<Map<String, String>> _getHeaders({bool json = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final headers = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final qs = query?.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    return Uri.parse('$baseUrl$cleanPath').replace(
      queryParameters: qs?.isEmpty == true ? null : qs,
    );
  }

  static dynamic _parseBody(http.Response response) {
    final code = response.statusCode;
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }
    if (code >= 200 && code < 300) {
      return body is Map && body.containsKey('data') ? body['data'] : body;
    }
    if (code == 401 || code == 403) {
      final msg = (body is Map ? body['error'] as String? : null) ?? 'غير مصرح';
      throw ApiException(msg, code);
    }
    final msg =
        (body is Map ? body['error'] as String? : null) ?? 'حدث خطأ في الاتصال';
    throw ApiException(msg, code);
  }

  static Future<dynamic> getJson(String path,
      {Map<String, dynamic>? query}) async {
    final headers = await _getHeaders();
    final response = await http.get(_uri(path, query), headers: headers);
    return _parseBody(response);
  }

  static Future<dynamic> postJson(String path,
      {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri(path),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseBody(response);
  }

  static Future<dynamic> deleteJson(String path) async {
    final headers = await _getHeaders();
    final response = await http.delete(_uri(path), headers: headers);
    return _parseBody(response);
  }

  static Future<dynamic> patchJson(String path,
      {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      _uri(path),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseBody(response);
  }

  /// Uploads a file to /api/mobile/upload. Returns the public URL.
  static Future<String> uploadFile(File file) async {
    final headers = await _getHeaders(json: false);

    final request = http.MultipartRequest('POST', _uri('/api/mobile/upload'))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = _parseBody(response);
    final url = (data is Map ? data['url'] as String? : null);
    if (url == null || url.isEmpty) {
      throw ApiException('فشل رفع الملف', response.statusCode);
    }
    return url;
  }

  /// Login — returns {token, user, employee}.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      _uri('/api/mobile/auth/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _parseBody(response);
    return Map<String, dynamic>.from(data as Map);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
