import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  static const String _baseUrlKey = 'base_url';
  static const String _tokenKey = 'auth_token';
  static const String _defaultBaseUrl = 'https://joebill.onrender.com';

  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  String? _token;
  String? _baseUrl;

  Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    return _baseUrl!;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    return _token;
  }

  Future<void> setToken(String? t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, t);
    }
  }

  Future<Map<String, String>> _headers() async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<dynamic> get(String path) async {
    final url = Uri.parse('${await baseUrl}$path');
    final res = await http.get(url, headers: await _headers());
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${await baseUrl}$path');
    final res = await http.post(url, headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${await baseUrl}$path');
    final res = await http.patch(url, headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final url = Uri.parse('${await baseUrl}$path');
    final res = await http.delete(url, headers: await _headers());
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      if (res.statusCode == 404) {
        throw ApiException(
          'API not found — update the server or check app version',
          res.statusCode,
        );
      }
      throw ApiException(
        'Server error (${res.statusCode}). Try again in a moment.',
        res.statusCode,
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body is Map ? (body['error'] ?? 'Request failed (${res.statusCode})') : 'Request failed (${res.statusCode})';
    throw ApiException(msg.toString(), res.statusCode);
  }
}
