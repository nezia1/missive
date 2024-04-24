import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:missive/features/encryption/secure_storage_manager.dart';
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

  /// Initializes the Signal protocol stores. If [installing] is true, generates a new identity key pair, registration ID, signed pre key, and pre keys.
  /// [name] and [accessToken] are required when [installing] is true, and is used to upload the keys to the server.
  Future<void> initialize(
      {required bool installing,
      required String name,
      String? accessToken}) async {
    const secureStorage = FlutterSecureStorage();
    final storageManager =
        SecureStorageManager(secureStorage: secureStorage, namespace: name);

    _preKeyStore = SecureStoragePreKeyStore(storageManager);
    _signedPreKeyStore = SecureStorageSignedPreKeyStore(storageManager);
    _sessionStore = SecureStorageSessionStore(storageManager);

    if (installing) {
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
      print('Protocol successfully installed');
      return;
    }

    _identityKeyStore = SecureStorageIdentityKeyStore(storageManager);
  }

  // TODO: this needs error handling in case user doesn't exist, server is down, or user has no keys
  /// Fetch a pre-key bundle from the server. This is used when a user wants to start a conversation with another user.
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

  /// Encrypts a message for a given user. Returns a [CiphertextMessage].
  Future<CiphertextMessage> encrypt(
      {required String name, required String message}) async {
    final remoteAddress = SignalProtocolAddress(name, 1);
    final sessionCipher = SessionCipher(_sessionStore, _preKeyStore,
        _signedPreKeyStore, _identityKeyStore, remoteAddress);

    final cipherText = await sessionCipher.encrypt(utf8.encode(message));
    return cipherText;
  }

  // TODO: handle case where the session might have changed (e.g. user logs out and logs back in, user logs back out, to another account, and in again, or user deletes their account and creates a new one with the same name). The signed key needs to be updated. Perhaps we should store all the accounts the user has logged on separately?
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
