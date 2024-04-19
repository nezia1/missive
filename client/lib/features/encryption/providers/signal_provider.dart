import 'package:flutter/material.dart';

import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:missive/features/encryption/secure_storage_session_store.dart';
import 'package:missive/features/encryption/secure_storage_pre_key_store.dart';
import 'package:missive/features/encryption/secure_storage_signed_pre_key_store.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:missive/common/http.dart';

class SignalProvider extends ChangeNotifier {
  late SecureStorageIdentityKeyStore _identityKeyStore;
  late SecureStoragePreKeyStore _preKeyStore;
  late SecureStorageSignedPreKeyStore _signedPreKeyStore;
  late SecureStorageSessionStore _sessionStore;

  /// Initializes the Signal protocol stores. If [installing] is true, generates a new identity key pair, registration ID, signed pre key, and pre keys.
  Future<void> initialize(bool installing) async {
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

      // TODO: upload keys to server
      return;
    }

    _identityKeyStore = SecureStorageIdentityKeyStore(secureStorage);

    const remoteAddress = SignalProtocolAddress('+1234567890', 1);

    final SessionBuilder sessionBuilder = SessionBuilder(_sessionStore,
        _preKeyStore, _signedPreKeyStore, _identityKeyStore, remoteAddress);
  }
}
