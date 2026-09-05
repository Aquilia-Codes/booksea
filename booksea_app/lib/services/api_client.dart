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

  /// Deployed backend on Render - reachable from any network, no LAN/
  /// firewall dance needed. Swap to 'http://localhost:4000' for
  /// desktop/emulator testing against a local backend instead, or to
  /// `http://<lan-ip>:4000` for a physical device testing against a local
  /// backend on the same Wi-Fi (check the IP with `ipconfig`).
  ///
  /// Note: Render's free tier sleeps after inactivity - the first request
  /// after a while can take 30-60s to respond while it wakes back up.
  static String baseUrl = 'https://booksea.onrender.com';

  String? _accessToken;
  String? _refreshToken;

  // Several screens poll independently (tours, summary, groups - each on
  // its own timer, see ApiDatabase._pollStream), all sharing this one
  // client. They all hold the same access token, so it expires for all of
  // them at once - and since refresh tokens rotate on use (old one revoked,
  // see backend/src/routes/auth.ts), if two pollers both hit 401 around the
  // same moment and each independently call /auth/refresh, the first one's
  // rotation invalidates the refresh token before the second one's request
  // lands, so the second one "fails" and wipes out the good tokens the
  // first one just got - logging the session out even though it was fine.
  // This makes concurrent callers share one in-flight refresh instead of
  // racing separate ones.
  Future<bool>? _refreshInFlight;

  String? get refreshToken => _refreshToken;

  void setTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Exchanges a previously stored refresh token for a fresh pair, e.g. to
  /// restore a session on app start. Returns whether it succeeded.
  Future<bool> refreshWithToken(String refreshToken) async {
    _refreshToken = refreshToken;
    return _refreshOnce();
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
      final refreshed = await _refreshOnce();
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

  // Ensures only one /auth/refresh call is ever in flight at a time -
  // concurrent callers (see the comment on _refreshInFlight) all await the
  // same attempt instead of racing separate ones.
  Future<bool> _refreshOnce() {
    return _refreshInFlight ??= _tryRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
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
