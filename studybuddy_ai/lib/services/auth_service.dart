import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/auth_user.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _kAccessToken = 'studybuddy_access_token';
  static const String _kRefreshToken = 'studybuddy_refresh_token';
  static const String _kUserProfile = 'studybuddy_user_profile';

  String? _accessToken;
  String? _refreshToken;
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  String? get accessToken => _accessToken;

  /// Restores session on app startup:
  /// 1. Reads stored tokens from secure storage.
  /// 2. Verifies session by querying GET /api/auth/me.
  /// 3. If access token is expired, attempts token refresh via POST /api/auth/refresh.
  /// 4. Returns AuthUser on success, or null if unauthenticated.
  Future<AuthUser?> tryRestoreSession() async {
    try {
      _accessToken = await _storage.read(key: _kAccessToken);
      _refreshToken = await _storage.read(key: _kRefreshToken);

      if (_accessToken == null && _refreshToken == null) {
        return null;
      }

      // If we have an access token, probe /api/auth/me
      if (_accessToken != null) {
        try {
          final user = await getMe();
          _currentUser = user;
          await _cacheUserProfile(user);
          return user;
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          // If token expired or unauthorized, try refresh token rotation
          if (errStr.contains('401') || errStr.contains('expired') || errStr.contains('unauthorized')) {
            final refreshed = await refreshToken();
            if (refreshed) {
              final user = await getMe();
              _currentUser = user;
              await _cacheUserProfile(user);
              return user;
            }
          } else {
            // Network failure or backend offline: load cached profile if available
            final cached = await _getCachedUserProfile();
            if (cached != null) {
              _currentUser = cached;
              return cached;
            }
          }
        }
      } else if (_refreshToken != null) {
        // Only refresh token present: rotate to get a fresh access token
        final refreshed = await refreshToken();
        if (refreshed) {
          final user = await getMe();
          _currentUser = user;
          await _cacheUserProfile(user);
          return user;
        }
      }

      await _clearSession();
      return null;
    } catch (_) {
      await _clearSession();
      return null;
    }
  }

  /// Registers a new student account
  Future<AuthUser> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/auth/register');
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
    };
    if (fullName != null && fullName.trim().isNotEmpty) {
      payload['full_name'] = fullName.trim();
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(ApiService.requestTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return await _saveSessionFromTokenResponse(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Registration failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(ApiService.cleanErrorMessage(e, 'Registration'));
    }
  }

  /// Logs in with email and password
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/auth/login');
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(ApiService.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return await _saveSessionFromTokenResponse(data);
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Login failed (${response.statusCode})');
      }
    } catch (e) {
      throw Exception(ApiService.cleanErrorMessage(e, 'Login'));
    }
  }

  /// Rotates refresh token and obtains a fresh access token
  Future<bool> refreshToken() async {
    final currentRefresh = _refreshToken ?? await _storage.read(key: _kRefreshToken);
    if (currentRefresh == null || currentRefresh.isEmpty) {
      return false;
    }

    final uri = Uri.parse('${ApiService.baseUrl}/api/auth/refresh');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refresh_token': currentRefresh}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        await _saveSessionFromTokenResponse(data);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the profile of the authenticated user
  Future<AuthUser> getMe() async {
    if (_accessToken == null) {
      _accessToken = await _storage.read(key: _kAccessToken);
      if (_accessToken == null) {
        throw Exception('Not authenticated (no access token).');
      }
    }

    final uri = Uri.parse('${ApiService.baseUrl}/api/auth/me');
    final response = await http
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final user = AuthUser.fromJson(data);
      _currentUser = user;
      await _cacheUserProfile(user);
      return user;
    } else {
      final err = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(err['detail'] ?? 'Failed to load user profile (${response.statusCode})');
    }
  }

  /// Logs out by revoking refresh token on server and clearing local secure storage
  Future<void> logout() async {
    final currentRefresh = _refreshToken ?? await _storage.read(key: _kRefreshToken);

    if (currentRefresh != null && currentRefresh.isNotEmpty) {
      try {
        final uri = Uri.parse('${ApiService.baseUrl}/api/auth/logout');
        await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
              },
              body: json.encode({'refresh_token': currentRefresh}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ensure local credentials are cleared even if server is unreachable
      }
    }

    await _clearSession();
  }

  /// Saves tokens and user profile to secure storage
  Future<AuthUser> _saveSessionFromTokenResponse(Map<String, dynamic> data) async {
    _accessToken = data['access_token']?.toString();
    _refreshToken = data['refresh_token']?.toString();

    if (_accessToken != null) {
      await _storage.write(key: _kAccessToken, value: _accessToken);
    }
    if (_refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: _refreshToken);
    }

    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson != null) {
      _currentUser = AuthUser.fromJson(userJson);
      await _cacheUserProfile(_currentUser!);
    }

    return _currentUser ??
        const AuthUser(
          id: '',
          email: '',
          fullName: null,
          isActive: true,
        );
  }

  Future<void> _cacheUserProfile(AuthUser user) async {
    await _storage.write(
      key: _kUserProfile,
      value: json.encode(user.toJson()),
    );
  }

  Future<AuthUser?> _getCachedUserProfile() async {
    try {
      final raw = await _storage.read(key: _kUserProfile);
      if (raw != null && raw.isNotEmpty) {
        return AuthUser.fromJson(json.decode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    try {
      await _storage.delete(key: _kAccessToken);
      await _storage.delete(key: _kRefreshToken);
      await _storage.delete(key: _kUserProfile);
    } catch (_) {}
  }
}

