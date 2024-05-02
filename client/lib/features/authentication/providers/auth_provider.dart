import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/common/http.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:missive/features/authentication/models/user.dart';
import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:missive/features/encryption/secure_storage_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides everything related to the user, such as:
/// -  authentication (login, logout, token management)
/// - profile
class AuthProvider extends ChangeNotifier {
  User? _user;
  final Dio _httpClient;
  final FlutterSecureStorage _secureStorage;

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
      } on DioException catch (e) {
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

  /// The user is logged in if the refresh token is available.
  Future<bool> get isLoggedIn async {
    return await refreshToken != null;
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
        'identityKey': base64Encode(identityKeyPair.getPublicKey().serialize())
      });

      final response = await _httpClient
          .post('/users', data: requestBody)
          .timeout(const Duration(seconds: 5));

      // we need a namespace to store user related data
      final storageManager =
          SecureStorageManager(secureStorage: _secureStorage, namespace: name);

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

      SecureStorageManager storageManager =
          SecureStorageManager(secureStorage: _secureStorage, namespace: name);

      // If user didn't log in yet, we need to install the app
      final firstLogin =
          await storageManager.read(key: 'identityKeyPair') == null;
      print('first time logged in: $firstLogin');
      if (firstLogin) {
        (await SharedPreferences.getInstance()).setBool('installed', false);
      }
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
}

// This function adds padding to a base64 string if needed so it can be decoded properly.
String _normalizeBase64(String base64Url) {
  String normalized = base64Url
      .replaceAll('-', '+') // Replace - with +
      .replaceAll('_', '/'); // Replace _ with /
  return normalized.padRight((normalized.length + 3) ~/ 4 * 4,
      '='); // Pad with = to make the length a multiple of 4
}

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

class AuthenticationTimeoutError extends AuthenticationError {
  AuthenticationTimeoutError();
}

class InvalidCredentialsError extends AuthenticationError {
  InvalidCredentialsError();
}

class TOTPRequiredError extends AuthenticationError {
  TOTPRequiredError();
}

class TOTPInvalidError extends AuthenticationError {
  TOTPInvalidError();
}
