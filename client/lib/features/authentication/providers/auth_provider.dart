import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:missive/common/http.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:missive/features/authentication/models/user.dart';
import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides everything related to authentication and user management.
///
/// This provider is responsible for:
/// - Registering new users
/// - Logging in users
/// - Logging out users
/// - Loading the currently authenticated user
/// - Managing access and refresh tokens
/// - Handling errors during authentication
/// Relies on a [Dio] client for making HTTP requests, a [FlutterSecureStorage] for storing tokens, and a [NamespacedSecureStorage] for storing user-related data at its own namespace.
class AuthProvider extends ChangeNotifier {
  User? _user;
  final Dio _httpClient;
  final FlutterSecureStorage _secureStorage;
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  /// Returns the access token as [String], or null if it's not available.
  Future<String?> get accessToken async {
    var token = await _secureStorage.read(key: 'accessToken');

    if (token == null) return null;

    // decode the token to check if it's expired
    final payload = jsonDecode(String.fromCharCodes(
        base64Decode(_normalizeBase64(token.split('.')[1]))));

    if (payload['exp'] < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      try {
        final request = await dio.put('/tokens',
            data: {},
            options: Options(
                headers: {'Cookie': 'refreshToken=${await refreshToken}'}));

        final newToken = request.data['data']['accessToken'];
        token = newToken;

        await _secureStorage.write(key: 'accessToken', value: token);
      } on DioException {
        // TODO: handle error better (e.g. log out user, show error message, etc.)
      }
    }
    return token;
  }

  /// Returns the refresh token as [String], or null if it's not available.
  Future<String?> get refreshToken async {
    // TODO: logout on refresh token expiration
    return await _secureStorage.read(key: 'refreshToken');
  }

  /// Returns the currently authenticated [User], or null if it's not available.
  Future<User?> get user async {
    if (_user == null) await loadProfile();
    return _user;
  }

  /// Creates a new [AuthProvider] with a [Dio] client and [FlutterSecureStorage].
  AuthProvider(
      {required Dio httpClient, required FlutterSecureStorage secureStorage})
      : _httpClient = httpClient,
        _secureStorage = secureStorage;

  /// Registers a new user and returns a [AuthenticationResult], that can either be [AuthenticationSuccess] or [AuthenticationError].
  Future<AuthenticationResult> register(String name, String password) async {
    try {
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);

      final requestBody = jsonEncode({
        'name': name,
        'password': password,
        'registrationId': registrationId,
        'identityKey': base64Encode(
          identityKeyPair.getPublicKey().serialize(),
        ),
        'oneSignalId': await OneSignal.User.getOnesignalId(),
      });

      final response = await _httpClient
          .post('/users', data: requestBody)
          .timeout(const Duration(seconds: 5));

      // we need a namespace to store user related data
      final storageManager = NamespacedSecureStorage(
          secureStorage: _secureStorage, namespace: name);

      SecureStorageIdentityKeyStore.fromIdentityKeyPair(
          storageManager, identityKeyPair, registrationId);

      final accessToken = response.data['data']['accessToken'];

      // the set-cookie header is not accessible from the http package, so we have to parse it manually
      final refreshToken = response.headers
          .value('set-cookie')
          ?.split(';')
          .firstWhere((cookie) => cookie.contains('refreshToken'))
          .split('=')
          .last;

      (await SharedPreferences.getInstance()).setBool('installed', false);

      await _secureStorage.write(key: 'refreshToken', value: refreshToken);
      await _secureStorage.write(key: 'accessToken', value: accessToken);

      await _secureStorage.write(key: 'isLoggedIn', value: 'true');
      _isLoggedIn = true;
      notifyListeners();

      return AuthenticationSuccess();
    } on DioException catch (e) {
      return AuthenticationError(e.message);
    }
  }

  /// Logs in a user and returns a [AuthenticationResult], that can either be [AuthenticationSuccess] or [AuthenticationError].
  Future<AuthenticationResult> login(String name, String password,
      [String? totp]) async {
    try {
      final requestBody = jsonEncode(
          {'name': name, 'password': password, if (totp != null) 'totp': totp});

      final response = await _httpClient
          .post('/tokens', data: requestBody)
          .timeout(const Duration(seconds: 5));

      // 200 represents a successful login attempt, but the user needs to provide a TOTP
      if (response.statusCode == 200 &&
          response.data['data']['status'] == 'totp_required') {
        return TOTPRequiredError();
      }

      final accessToken = response.data['data']['accessToken'];

      // the set-cookie header is not accessible from the http package, so we have to parse it manually
      final refreshToken = response.headers
          .value('set-cookie')
          ?.split(';')
          .firstWhere((cookie) => cookie.contains('refreshToken'))
          .split('=')
          .last;

      await _secureStorage.write(key: 'refreshToken', value: refreshToken);
      await _secureStorage.write(key: 'accessToken', value: accessToken);

      NamespacedSecureStorage storageManager = NamespacedSecureStorage(
          secureStorage: _secureStorage, namespace: name);

      // If user didn't log in yet, we need to install the app
      final firstLogin =
          await storageManager.read(key: 'identityKeyPair') == null;
      print('first time logged in: $firstLogin');
      if (firstLogin) {
        (await SharedPreferences.getInstance()).setBool('installed', false);
      }

      await _secureStorage.write(key: 'isLoggedIn', value: 'true');
      _isLoggedIn = true;
      notifyListeners();
      return AuthenticationSuccess();
    } on DioException catch (e) {
      switch (e.response?.statusCode) {
        case 401:
          if (e.response?.data?['data']?['status'] == 'totp_invalid') {
            return TOTPInvalidError();
          }
          return InvalidCredentialsError();
        default:
          return AuthenticationError(e.message);
      }
    }
  }

  /// Logs out a user and clears the stored tokens.
  void logout() async {
    // TODO revoke the refresh token from the server, not only client-side
    await _secureStorage.delete(key: 'refreshToken');
    await _secureStorage.delete(key: 'accessToken');

    _user = null;

    await _secureStorage.write(key: 'isLoggedIn', value: 'false');
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    if (await accessToken == null) {
      // TODO handle/log error (this should never happen)
      return;
    }

    try {
      final userId = _getSubFromToken((await accessToken)!);
      final response = await _httpClient.get('/users/$userId',
          options: Options(headers: {
            'Authorization': 'Bearer ${await accessToken}',
          }));

      User user = User.fromJson(response.data);
      _user = user;
    } catch (e) {
      // TODO handle/log error
      _user = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> initializeLoginState() async {
    final isLoggedIn = await _secureStorage.read(key: 'isLoggedIn');
    _isLoggedIn = isLoggedIn == 'true';
    notifyListeners();
  }
}

/// Adds padding to a base64 string if needed so it can be decoded properly. Base64 strings need to have a length that is a multiple of 4 to be decoded, and some JWT tokens might not have correct padding.
String _normalizeBase64(String base64Url) {
  String normalized = base64Url
      .replaceAll('-', '+') // Replace - with +
      .replaceAll('_', '/'); // Replace _ with /
  return normalized.padRight((normalized.length + 3) ~/ 4 * 4,
      '='); // Pad with = to make the length a multiple of 4
}

/// Extracts the 'sub' claim from a JWT token. Allows us to get the user ID.
String _getSubFromToken(String token) {
  final normalizedPayload = _normalizeBase64(token.split('.')[1]);
  final payload =
      jsonDecode(String.fromCharCodes(base64Decode(normalizedPayload)));
  return payload['sub'];
}

// Represents the result of an authentication attempt.
// It allows us to represent a generic result of an authentication attempt, and then have specific subtypes for different types of successes/errors so we can parse them accordingly and build our UI logic around it.
/// Generic result of an authentication attempt.
sealed class AuthenticationResult {}

/// Represents a successful authentication attempt.
class AuthenticationSuccess extends AuthenticationResult {
  AuthenticationSuccess();
}

/// Represents a generic error during an authentication attempt.
class AuthenticationError extends AuthenticationResult implements Error {
  @override
  StackTrace get stackTrace => StackTrace.current;

  final String? message;

  AuthenticationError([this.message]);
}

/// Represents an error during an authentication attempt due to a timeout.
class AuthenticationTimeoutError extends AuthenticationError {
  AuthenticationTimeoutError();
}

/// Represents an error during an authentication attempt due to invalid credentials.
class InvalidCredentialsError extends AuthenticationError {
  InvalidCredentialsError();
}

/// Represents an error during an authentication attempt due to a required TOTP. This is not exactly an error, but still a special case that requires different handling.
class TOTPRequiredError extends AuthenticationError {
  TOTPRequiredError();
}

/// Represents an error during an authentication attempt due to an invalid TOTP.
class TOTPInvalidError extends AuthenticationError {
  TOTPInvalidError();
}
