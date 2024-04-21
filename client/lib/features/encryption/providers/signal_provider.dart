import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
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
      {bool installing = false, String? name, String? accessToken}) async {
    const secureStorage = FlutterSecureStorage();
    _preKeyStore = SecureStoragePreKeyStore(secureStorage);
    _signedPreKeyStore = SecureStorageSignedPreKeyStore(secureStorage);
    _sessionStore = SecureStorageSessionStore(secureStorage);

    if (installing) {
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);
      final signedPreKey = generateSignedPreKey(identityKeyPair, 0);

      await _signedPreKeyStore.storeSignedPreKey(signedPreKey.id, signedPreKey);
      _identityKeyStore = SecureStorageIdentityKeyStore.fromIdentityKeyPair(
          secureStorage, identityKeyPair, registrationId);

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
      return;
    }

    _identityKeyStore = SecureStorageIdentityKeyStore(secureStorage);
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

  void buildSession(
      {required String name,
      required String accessToken,
      required String message}) async {
    final remotePreKeyBundle = await fetchPreKeyBundle(name, accessToken);

    if (remotePreKeyBundle == null) return;

    final remoteAddress = SignalProtocolAddress(name, 1);
    final sessionBuilder = SessionBuilder(_sessionStore, _preKeyStore,
        _signedPreKeyStore, _identityKeyStore, remoteAddress);

    await sessionBuilder.processPreKeyBundle(remotePreKeyBundle);

    final sessionCipher = SessionCipher(_sessionStore, _preKeyStore,
        _signedPreKeyStore, _identityKeyStore, remoteAddress);

    final cipherText = await sessionCipher.encrypt(utf8.encode(message));

    // ITS WORKING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    print(String.fromCharCodes(cipherText.serialize()));
  }
}
