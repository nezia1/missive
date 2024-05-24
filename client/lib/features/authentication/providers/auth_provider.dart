import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:logging/logging.dart';
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
  final Logger _logger = Logger('AuthProvider');

  bool get isLoggedIn => _isLoggedIn;

  /// Returns the access token as a [String], or null if it's not available.
  ///
  /// This method checks if the current access token is expired. If it is,
  /// it tries to refresh it using the refresh token. If the refresh token is
  /// also expired or not available, it returns null.
  ///
  /// ## Returns
  /// - The current access token as a [String] if available and valid.
  /// - `null` if the token is not available or cannot be refreshed.
  ///
  /// ## Usage
  /// ```dart
  /// String? token = await provider.accessToken;
  /// ```
  Future<String?> get accessToken async {
    var token =
        await _secureStorage.read(key: 'accessToken').catchError((_) => null);

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
        if (e.error is SocketException) {
          _logger.log(
              Level.WARNING, 'Error refreshing token: No internet connection');
        } else {
          if (e.response?.statusCode == 400) {
            // bad request, log out the user
            logout();
          }
          if (e.response?.statusCode == 401) {
            // refresh token is expired, log out the user
            logout();
          }
          if (e.response?.statusCode == 403) {
            // refresh token is invalid, log out the user
            logout();
          }
          if (e.response?.statusCode == 404) {
            // user not found, log out the user
            logout();
          }
          _logger.log(Level.SEVERE, 'Error refreshing token: $e');
        }
      }
    }
    return token;
  }

  /// Returns the refresh token as a [String], or null if it's not available.
  ///
  /// This method retrieves the refresh token from secure storage.
  ///
  /// ## Returns
  /// - The refresh token as a [String] if available.
  /// - `null` if the token is not available.
  ///
  /// ## Usage
  /// ```dart
  /// String? token = await provider.refreshToken;
  /// ```
  Future<String?> get refreshToken async {
    return await _secureStorage
        .read(key: 'refreshToken')
        .catchError((_) => null);
  }

  /// Returns the currently authenticated [User], or null if it's not available.
  ///
  /// This method checks if the user is already loaded and cached. If not, it attempts to load the user's profile.
  ///
  /// ## Returns
  /// - The currently authenticated [User] if available.
  /// - `null` if the user is not available or not loaded.
  ///
  /// ## Usage
  /// ```dart
  /// User? currentUser = await provider.user;
  /// ```
  Future<User?> get user async {
    // If user is not in memory yet, try to load it from storage. Otherwise, get it from the network.
    if (_user == null) await loadProfile();
    return _user;
  }

  /// Creates a new [AuthProvider] with a [Dio] client and [FlutterSecureStorage].
  AuthProvider(
      {required Dio httpClient, required FlutterSecureStorage secureStorage})
      : _httpClient = httpClient,
        _secureStorage = secureStorage;

  /// Registers a new user and returns an [AuthenticationResult], that can either be [AuthenticationSuccess] or [AuthenticationError].
  ///
  /// This method attempts to register a new user using their name and password. It generates a new identity key pair and registration ID for the user, sends these along with the registration request, and stores the necessary tokens and user data in secure storage.
  ///
  /// ## Parameters
  /// - [name]: The name of the user trying to register.
  /// - [password]: The password of the user trying to register.
  ///
  /// ## Returns
  /// - [AuthenticationSuccess] if the registration is successful.
  /// - [AuthenticationError] if an error occurs during the registration process.
  ///
  /// ## Usage
  /// ```dart
  /// AuthenticationResult result = await provider.register('username', 'password');
  /// ```
  Future<AuthenticationResult> register(String name, String password) async {
    try {
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);
      final String? notificationId;

      if (Platform.isAndroid || Platform.isIOS) {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        notificationId = await messaging.getToken();
      } else {
        notificationId = null;
      }

      final requestBody = jsonEncode({
        'name': name,
        'password': password,
        'registrationId': registrationId,
        'identityKey': base64Encode(
          identityKeyPair.getPublicKey().serialize(),
        ),
        'notificationID': notificationId
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
      // TODO: update currently logged in user with OneSignal ID
      notifyListeners();

      return AuthenticationSuccess();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return DuplicateUserError('User already exists');
      }
      return AuthenticationError(e.message);
    }
  }

  /// Logs in a user and returns an [AuthenticationResult], that can either be [AuthenticationSuccess] or [AuthenticationError].
  ///
  /// This method attempts to log in a user using their name and password. If a TOTP is required or provided, it includes this in the request. It then stores the necessary tokens and updates the user's login state.
  ///
  /// ## Parameters
  /// - [name]: The name of the user trying to log in.
  /// - [password]: The password of the user trying to log in.
  /// - [totp]: The Time-based One-Time Password (TOTP), if required or available.
  ///
  /// ## Returns
  /// - [AuthenticationSuccess] if the login is successful.
  /// - [AuthenticationError] if an error occurs during the login process.
  ///
  /// ## Usage
  /// ```dart
  /// AuthenticationResult result = await provider.login('username', 'password');
  /// ```
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

      if (Platform.isAndroid || Platform.isIOS) {
        final payload = jsonDecode(utf8.decode(
            base64Decode(base64Url.normalize(accessToken.split('.')[1]))));
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        await _setNotificationID(payload['sub'], await messaging.getToken());
      }

      // If user didn't log in yet, we need to install the app
      final firstLogin = await storageManager
              .read(key: 'identityKeyPair')
              .catchError((_) => null) ==
          null;
      _logger.log(Level.INFO, 'first time logged in: $firstLogin');
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
  ///
  /// This method clears the access and refresh tokens from secure storage, resets the user's profile, and updates the login state.
  ///
  /// ## Usage
  /// ```dart
  /// provider.logout();
  /// ```
  void logout() async {
    // TODO: handle offline login
    // await _setNotificationID(_user!.id, null);
    _user = null;
    // TODO revoke the refresh token from the server, not only client-side
    await _secureStorage.delete(key: 'refreshToken').catchError((e) {
      _logger.log(Level.WARNING, e.toString());
    });
    await _secureStorage.delete(key: 'accessToken').catchError((e) {
      _logger.log(Level.WARNING, e.toString());
    });
    await _secureStorage.delete(key: 'user').catchError((e) {
      _logger.log(Level.WARNING, e.toString());
    });

    await _secureStorage.write(key: 'isLoggedIn', value: 'false');
    _isLoggedIn = false;
    notifyListeners();
  }

  /// Sets the OneSignal ID for the currently logged in user, and uploads it to the server.
  ///
  /// This method sets the OneSignal ID for the currently logged in user, and uploads it to the server. This is used to send push notifications to the user.
  ///
  /// ## Parameters
  /// - [oneSignalId]: The OneSignal ID to set for the user.
  ///
  /// ## Usage
  /// ```dart
  /// await _setOneSignalId('onesignal-id');
  /// ```
  Future<void> _setNotificationID(String userID, String? oneSignalID) async {
    print(await accessToken);
    await _httpClient.patch('/users/$userID',
        data: {'notificationID': oneSignalID},
        options: Options(headers: {
          'Authorization': 'Bearer ${await accessToken}',
        }));

    _logger.log(Level.FINE, 'OneSignal ID set for user: $oneSignalID');
  }

  /// Loads the user's profile from the server and updates the locally cached user.
  ///
  /// This method fetches the user's profile using the current access token and updates the locally stored user data.
  ///
  /// ## Usage
  /// ```dart
  /// await provider.loadProfile();
  /// ```
  Future<void> loadProfile() async {
    if (await accessToken == null) {
      _logger.log(Level.SEVERE,
          'No access token found when loading profile, this should never happen.');
      return;
    }

    final storedUser =
        await _secureStorage.read(key: 'user').catchError((_) => null);

    if (storedUser != null) {
      _user = User.fromJson(jsonDecode(storedUser));
      _logger.log(Level.FINE, 'User loaded from storage: $_user');
      notifyListeners();
      return;
    }

    try {
      final userId = _getSubFromToken((await accessToken)!);
      final response = await _httpClient.get('/users/$userId',
          options: Options(headers: {
            'Authorization': 'Bearer ${await accessToken}',
          }));

      User user = User.fromJson(response.data['data']);
      _user = user;
      _secureStorage.write(key: 'user', value: jsonEncode(user.toJson()));
    } catch (e) {
      _logger.log(Level.SEVERE, e.toString());
      _user = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> initializeLoginState() async {
    final String? isLoggedIn;
    try {
      isLoggedIn =
          await _secureStorage.read(key: 'isLoggedIn').catchError((_) => null);
    } catch (e) {
      _logger.log(Level.WARNING, e.toString());
      return;
    }
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

/// Represents an error during a register attempt due to a duplicate username.
class DuplicateUserError extends AuthenticationError {
  DuplicateUserError([super.message]);
}
