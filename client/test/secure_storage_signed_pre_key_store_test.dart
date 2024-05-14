import 'dart:convert';
import 'package:test/test.dart';
import 'package:missive/features/encryption/secure_storage_signed_pre_key_store.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'secure_storage_signed_pre_key_store_test.mocks.dart';

@GenerateMocks([SecureStorage])
void main() {
  group('SecureStorageSignedPreKeyStore', () {
    late SecureStorageSignedPreKeyStore store;
    late SecureStorage secureStorage;
    late SignedPreKeyRecord signedPreKeyRecord;

    setUp(() {
      final identityKeyPair = generateIdentityKeyPair();
      secureStorage = MockSecureStorage();
      store = SecureStorageSignedPreKeyStore(secureStorage);
      signedPreKeyRecord = generateSignedPreKey(identityKeyPair, 0);
    });

    test('containsSignedPreKey', () async {
      when(secureStorage.read(key: 'signedPreKeys'))
          .thenAnswer((_) async => Future<String>.value(jsonEncode(
                {'0': base64Encode(signedPreKeyRecord.serialize())},
              )));

      final result = await store.containsSignedPreKey(0);

      expect(result, isTrue);
    });

    test('loadSignedPreKey', () async {
      when(secureStorage.read(key: 'signedPreKeys'))
          .thenAnswer((_) async => Future<String>.value(jsonEncode(
                {'0': base64Encode(signedPreKeyRecord.serialize())},
              )));

      final result = await store.loadSignedPreKey(0);

      expect(result.serialize(), signedPreKeyRecord.serialize());
    });

    test('loadSignedPreKeys', () async {
      when(secureStorage.read(key: 'signedPreKeys'))
          .thenAnswer((_) async => Future<String>.value(jsonEncode(
                {'0': base64Encode(signedPreKeyRecord.serialize())},
              )));

      final result = await store.loadSignedPreKeys();

      expect(result.first.serialize(), signedPreKeyRecord.serialize());
    });

    test('removeSignedPreKey', () async {
      when(secureStorage.read(key: 'signedPreKeys'))
          .thenAnswer((_) async => Future<String>.value(jsonEncode(
                {'0': base64Encode(signedPreKeyRecord.serialize())},
              )));
      when(secureStorage.write(
        key: 'signedPreKeys',
        value: jsonEncode(<String, String>{}),
      )).thenAnswer((_) async => Future<void>.value());

      await store.removeSignedPreKey(0);

      verify(secureStorage.write(
        key: 'signedPreKeys',
        value: jsonEncode(<String, String>{}),
      ));
    });

    test('storeSignedPreKey', () async {
      when(secureStorage.read(key: 'signedPreKeys')).thenAnswer(
          (_) async => Future<String>.value(jsonEncode(<String, String>{})));
      when(secureStorage.write(
        key: 'signedPreKeys',
        value: jsonEncode({'0': base64Encode(signedPreKeyRecord.serialize())}),
      )).thenAnswer((_) async => Future<void>.value());

      await store.storeSignedPreKey(0, signedPreKeyRecord);

      verify(secureStorage.write(
          key: 'signedPreKeys',
          value: jsonEncode(
            {'0': base64Encode(signedPreKeyRecord.serialize())},
          )));
    });
  });
}
