import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';
import 'package:missive/features/encryption/secure_storage_session_store.dart';
import 'package:missive/features/encryption/secure_storage_pre_key_store.dart';
import 'package:missive/features/encryption/secure_storage_signed_pre_key_store.dart';

import 'package:missive/common/http.dart';

/// Provides higher-level functions for Missive's Signal protocol implementation. Allows to access stores, generate keys, and initialize the application, among server communication to keep the keys up to date.
class SignalProvider extends ChangeNotifier {
  late SecureStorageIdentityKeyStore _identityKeyStore;
  late SecureStoragePreKeyStore _preKeyStore;
  late SecureStorageSignedPreKeyStore _signedPreKeyStore;
  late SecureStorageSessionStore _sessionStore;
  final _logger = Logger('SignalProvider');

  /// Initializes the Signal protocol stores. If [installing] is true, generates a new identity key pair, registration ID, signed pre key, and pre keys.
  ///
  /// This method sets up the necessary stores and, if installing for the first time, generates the necessary keys and uploads them to the server.
  ///
  /// ## Parameters
  /// - [installing]: Whether the protocol is being installed for the first time.
  /// - [name]: The name of the user.
  /// - [accessToken]: The access token of the user, required if installing.
  ///
  /// ## Throws
  /// - [MissingTokenError] if [accessToken] is not provided when installing.

  /// ## Usage
  /// ```dart
  /// await provider.initialize(installing: true, name: 'username', accessToken: 'access-token');
  /// ```
  Future<void> initialize(
      {required bool installing,
      required String name,
      String? accessToken}) async {
    const secureStorage = FlutterSecureStorage();
    final storageManager =
        NamespacedSecureStorage(secureStorage: secureStorage, namespace: name);

    _preKeyStore = SecureStoragePreKeyStore(storageManager);
    _signedPreKeyStore = SecureStorageSignedPreKeyStore(storageManager);
    _sessionStore = SecureStorageSessionStore(storageManager);

    if (installing) {
      if (accessToken == null) {
        throw MissingTokenError(
            'Access token is required when installing the protocol');
      }
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);
      final signedPreKey = generateSignedPreKey(identityKeyPair, 0);

      await _signedPreKeyStore.storeSignedPreKey(signedPreKey.id, signedPreKey);
      _identityKeyStore = SecureStorageIdentityKeyStore.fromIdentityKeyPair(
          storageManager, identityKeyPair, registrationId);

      final preKeys = generatePreKeys(0, 110);
      for (var p in preKeys) {
        await _preKeyStore.storePreKey(p.id, p);
      }

      await dio.post('/users/$name/keys',
          data: {
            'identityKey':
                base64Encode(identityKeyPair.getPublicKey().serialize()),
            'registrationId': registrationId,
            'signedPreKey': {
              'key': base64Encode(signedPreKey.serialize()),
              'signature': base64Encode(signedPreKey.signature)
            },
            'preKeys': preKeys
                .map((p) => {'key': base64Encode(p.serialize())})
                .toList()
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      _logger.log(Level.INFO, 'Protocol successfully installed');
      return;
    }

    _identityKeyStore = SecureStorageIdentityKeyStore(storageManager);
  }

  /// Fetches a pre-key bundle from the server. This is used when a user wants to start a conversation with another user.
  ///
  /// Returns a [PreKeyBundle] if the user exists and has keys, otherwise returns null.
  ///
  /// ## Parameters
  /// - [name]: The name of the user to fetch the keys from.
  /// - [accessToken]: The access token of the user fetching the keys.
  ///
  /// ## Returns
  /// - A [PreKeyBundle] if the user exists and has keys.
  /// - `null` if the keys cannot be fetched.
  ///
  /// ## Usage
  /// ```dart
  /// PreKeyBundle? bundle = await provider.fetchPreKeyBundle('username', 'access-token');
  /// ```
  Future<PreKeyBundle?> fetchPreKeyBundle(
      String name, String accessToken) async {
    final response = await dio.get('/users/$name/keys',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}));

    final data = response.data['data'];

    final registrationId = data['registrationId'];

    final identityKey =
        IdentityKey.fromBytes(base64Decode(data['identityKey']), 0);
    final signedPreKey = SignedPreKeyRecord.fromSerialized(
        base64Decode(data['signedPreKey']['key']));
    final preKey =
        PreKeyRecord.fromBuffer(base64Decode(data['oneTimePreKey']['key']));

    return PreKeyBundle(
        registrationId,
        1,
        preKey.id,
        preKey.getKeyPair().publicKey,
        signedPreKey.id,
        signedPreKey.getKeyPair().publicKey,
        signedPreKey.signature,
        identityKey);
  }

  /// Builds a Signal session with a given user. This session is used for subsequent message encryption and decryption.
  ///
  /// If a session with the user already exists, this method does nothing. Otherwise, it fetches the user's pre-key bundle and processes it to establish a new session.
  ///
  /// ## Parameters
  /// - [name]: The name of the user to build a session with.
  /// - [accessToken]: The access token to authenticate the request.
  ///
  /// ## Usage
  /// ```dart
  /// await provider.buildSession(name: 'username', accessToken: 'access-token');
  /// ```
  Future<void> buildSession({
    required String name,
    required String accessToken,
  }) async {
    final remoteAddress = SignalProtocolAddress(name, 1);
    if (await _sessionStore.containsSession(remoteAddress)) return;
    final remotePreKeyBundle = await fetchPreKeyBundle(name, accessToken);

    if (remotePreKeyBundle == null) return;

    final sessionBuilder = SessionBuilder(_sessionStore, _preKeyStore,
        _signedPreKeyStore, _identityKeyStore, remoteAddress);

    await sessionBuilder.processPreKeyBundle(remotePreKeyBundle);
  }

  /// Encrypts a plaintext message for a given user and returns a [CiphertextMessage].
  ///
  /// This method uses the existing session with the user to encrypt the message. If no session exists, an exception is thrown.
  ///
  /// ## Parameters
  /// - [name]: The name of the user to encrypt the message for.
  /// - [message]: The plaintext message to encrypt.
  ///
  /// ## Returns
  /// - A [CiphertextMessage] which can be sent securely.
  ///
  /// ## Usage
  /// ```dart
  /// CiphertextMessage cipherText = await provider.encrypt(name: 'username', message: 'Hello, World!');
  /// ```
  Future<CiphertextMessage> encrypt(
      {required String name, required String message}) async {
    final remoteAddress = SignalProtocolAddress(name, 1);
    final sessionCipher = SessionCipher(_sessionStore, _preKeyStore,
        _signedPreKeyStore, _identityKeyStore, remoteAddress);

    final cipherText = await sessionCipher.encrypt(utf8.encode(message));
    return cipherText;
  }

  /// Decrypts a [CiphertextMessage] received from a given [SignalProtocolAddress].
  ///
  /// This method uses the existing session with the sender to decrypt the message. If no session exists, or the message type is not recognized, an exception is thrown.
  ///
  /// ## Parameters
  /// - [message]: The [CiphertextMessage] to decrypt.
  /// - [senderAddress]: The [SignalProtocolAddress] the message has been sent from.
  ///
  /// ## Returns
  /// - A [String] representing the decrypted plaintext message.
  ///
  /// ## Usage
  /// ```dart
  /// String message = await provider.decrypt(cipherMessage, senderAddress);
  /// ```
  Future<String> decrypt(
      CiphertextMessage message, SignalProtocolAddress senderAddress) async {
    final sessionCipher = SessionCipher(_sessionStore, _preKeyStore,
        _signedPreKeyStore, _identityKeyStore, senderAddress);
    Uint8List plainText = Uint8List(0);

    if (message is PreKeySignalMessage) {
      plainText = await sessionCipher.decrypt(message);
    }
    if (message is SignalMessage) {
      plainText = await sessionCipher.decryptFromSignal(message);
    }
    return utf8.decode(plainText);
  }
}

/// Error thrown when an access token is missing.
class MissingTokenError extends Error {
  final String message;

  MissingTokenError(this.message);
}
