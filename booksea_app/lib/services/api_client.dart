import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin REST client for the Express/Postgres backend that replaces
/// Firestore. Holds the JWT access/refresh pair in memory only - wiring
/// this up to real persistence and to the Google idToken -> JWT exchange is
/// phase 6 ("swap auth", see docs/migration-notes.md); until then, tokens
/// are set manually for testing (see AuthProvider.kBypassFirebaseAuth).
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  /// Override for local dev against a different host/port, or once deployed,
  /// point this at the Render URL.
  ///
  /// TEMP: pointed at the dev machine's LAN IP (not "localhost") because
  /// testing happens on a physical device, which can't reach "localhost"
  /// on the PC at all. Both devices must be on the same network, and this
  /// IP will change if the PC reconnects to Wi-Fi or switches networks -
  /// check it with `ipconfig` (Windows) if requests start failing again.
  /// Switch back to 'http://localhost:4000' for desktop/emulator testing,
  /// or to the Render URL once deployed.
  static String baseUrl = 'http://192.168.31.17:4000';

  String? _accessToken;
  String? _refreshToken;

  String? get refreshToken => _refreshToken;

  void setTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Exchanges a previously stored refresh token for a fresh pair, e.g. to
  /// restore a session on app start. Returns whether it succeeded.
  Future<bool> refreshWithToken(String refreshToken) async {
    _refreshToken = refreshToken;
    return _tryRefresh();
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  bool get isAuthenticated => _accessToken != null;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
    final encodedBody = body != null ? jsonEncode(body) : null;

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
      case 'POST':
        response = await http.post(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    if (response.statusCode == 401 && !isRetry && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, query: query, body: body, isRetry: true);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {
      // Body wasn't JSON - use it as-is.
    }
    throw ApiException(response.statusCode, message);
  }

  Future<bool> _tryRefresh() async {
    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (response.statusCode != 200) {
        clearTokens();
        return false;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      setTokens(
        accessToken: decoded['accessToken'] as String,
        refreshToken: decoded['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      clearTokens();
      return false;
    }
  }
}
