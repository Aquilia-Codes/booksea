// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booksea_app/services/api_client.dart';
import 'package:booksea_app/services/realtime_client.dart';

enum Status {
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated,
  Registering,
  NoCode,
  NoAccess
}

// The Web OAuth client (not the Android one) - passed as serverClientId so
// Google addresses the idToken to this client specifically. The backend
// verifies the token's audience against this same id (GOOGLE_OAUTH_CLIENT_IDS
// in backend/.env), which is what lets it trust the token actually came from
// this app's sign-in flow. From a Google Cloud project created fresh for
// this migration - fully separate from the old, now-inaccessible Firebase
// project (see docs/migration-notes.md).
const _googleServerClientId =
    '865744272369-atobvfr5mo0s5prs63v99rg5872ehgp2.apps.googleusercontent.com';

final _emptyUser = UserModel(
  uid: '',
  email: '',
  nickname: '',
  provision: 0,
  hasAccess: false,
  isAdmin: false,
  isOwner: false,
  companyId: '',
  boatIds: [],
);

const _refreshTokenPrefsKey = 'booksea_refresh_token';

class AuthProvider extends ChangeNotifier {
  final ApiClient _client = ApiClient.instance;
  final _userController = StreamController<UserModel>.broadcast();

  Status _status = Status.Uninitialized;
  String? _companyId;
  List<String> _boatIds = [];
  UserModel _currentUser = _emptyUser;

  String? get userId => _currentUser.uid.isEmpty ? null : _currentUser.uid;
  Status get status => _status;
  List<String> get boatIds => _boatIds;
  String? get companyId => _companyId;
  // Sourced from the backend (originally Google's `picture` claim, captured
  // during POST /auth/google - see backend/src/routes/auth.ts), not from
  // the Google Sign-In SDK directly, so it's still there after a session
  // restore, not just right after an interactive sign-in.
  String? get photoUrl => _currentUser.photoUrl;
  // A plain broadcast stream never replays its last value to a late
  // subscriber (unlike Firebase's old authStateChanges(), which this
  // replaced) - settings_screen.dart's StreamBuilder only starts listening
  // when the user actually navigates to that tab, well after this stream's
  // one emission for the current session already happened, so it would
  // otherwise see no data at all. Exposed so that screen can seed its
  // StreamBuilder with `initialData: currentUser` instead.
  UserModel get currentUser => _currentUser;
  Stream<UserModel> get user => _userController.stream;

  AuthProvider() {
    _userController.add(_emptyUser);
    _tryRestoreSession();
  }

  // Restores a session from a previously stored refresh token, so signing
  // in with Google isn't required on every cold start. Silently falls back
  // to Unauthenticated if there's no stored token or it's no longer valid.
  Future<void> _tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshTokenPrefsKey);
    if (refreshToken == null) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return;
    }

    final refreshed = await _client.refreshWithToken(refreshToken);
    if (!refreshed) {
      await prefs.remove(_refreshTokenPrefsKey);
      _status = Status.Unauthenticated;
      notifyListeners();
      return;
    }
    await _persistRefreshToken(prefs);
    await _refreshUserAndStatus();
  }

  Future<void> _persistRefreshToken([SharedPreferences? prefsIn]) async {
    final prefs = prefsIn ?? await SharedPreferences.getInstance();
    final token = _client.refreshToken;
    if (token != null) {
      await prefs.setString(_refreshTokenPrefsKey, token);
    }
  }

  // Re-fetches /me and recomputes Status from it. Public because
  // no_code_home.dart needs to re-check status right after submitting a
  // company code (equivalent to the old onAuthStateChanged re-trigger).
  Future<void> refreshUser() => _refreshUserAndStatus();

  Future<void> _refreshUserAndStatus() async {
    final data = await _client.get('/me') as Map<String, dynamic>;
    final userModel = UserModel.fromMap(data, data['uid'] as String);

    _currentUser = userModel;
    _companyId = userModel.companyId;
    _boatIds = List<String>.from(userModel.boatIds.map((e) => e.toString()));

    if (_companyId!.isEmpty) {
      _status = Status.NoCode;
    } else if (!userModel.hasAccess || _boatIds.isEmpty) {
      _status = Status.NoAccess;
    } else {
      _status = Status.Authenticated;
    }
    _userController.add(userModel);
    notifyListeners();
  }

  // Returns the signed-in user on success, or null if the user cancelled
  // the Google account picker. Any other failure (network, backend down,
  // rejected idToken) throws, so the try/catch in google_login_screen.dart
  // can show it to the user - matches that screen's existing expectations.
  Future<UserModel?> signInWithGoogle() async {
    final googleUser =
        await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in did not return an idToken');
    }

    final tokens =
        await _client.post('/auth/google', {'idToken': idToken}) as Map<String, dynamic>;
    _client.setTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
    await _persistRefreshToken();
    await _refreshUserAndStatus();
    return _currentUser;
  }

  Future<void> signOut() async {
    final refreshToken = _client.refreshToken;
    _client.clearTokens();
    RealtimeClient.instance.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenPrefsKey);
    if (refreshToken != null) {
      // Best-effort server-side revoke; sign-out proceeds either way.
      try {
        await _client.post('/auth/logout', {'refreshToken': refreshToken});
      } catch (_) {}
    }
    _currentUser = _emptyUser;
    _companyId = null;
    _boatIds = [];
    _status = Status.Unauthenticated;
    _userController.add(_emptyUser);
    notifyListeners();
  }
}
