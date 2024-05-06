import 'package:test/test.dart';
import 'package:missive/features/encryption/secure_storage_pre_key_store.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'secure_storage_pre_key_store_test.mocks.dart';

@GenerateMocks([SecureStorage])
void main() {
  group('SecureStoragePreKeyStore', () {
    test('containsPreKey should return false if there are no preKeys',
        () async {
      final secureStorage = MockSecureStorage();
      final preKeyStore = SecureStoragePreKeyStore(secureStorage);

      when(secureStorage.read(key: 'preKeys'))
          .thenAnswer((_) => Future.value(null));

      expect(await preKeyStore.containsPreKey(0), isFalse);
    });

    test(
        'loadPreKey should throw an InvalidKeyIdException if there are no preKeys',
        () async {
      final secureStorage = MockSecureStorage();
      final preKeyStore = SecureStoragePreKeyStore(secureStorage);

      when(secureStorage.read(key: 'preKeys'))
          .thenAnswer((_) => Future.value(null));

      expect(() async => await preKeyStore.loadPreKey(0),
          throwsA(isA<InvalidKeyIdException>()));
    });

    test(
        'loadPreKey should throw an InvalidKeyIdException if the preKey is not found',
        () async {
      final secureStorage = MockSecureStorage();
      final preKeyStore = SecureStoragePreKeyStore(secureStorage);

      when(secureStorage.read(key: 'preKeys'))
          .thenAnswer((_) => Future.value('{"1": "non-existent-key"}'));

      expect(() async => await preKeyStore.loadPreKey(0),
          throwsA(isA<InvalidKeyIdException>()));
    });

    test('removePreKey should do nothing if there are no preKeys', () async {
      final secureStorage = MockSecureStorage();
      final preKeyStore = SecureStoragePreKeyStore(secureStorage);

      when(secureStorage.read(key: 'preKeys'))
          .thenAnswer((_) => Future.value(null));

      await preKeyStore.removePreKey(0);
      verifyNever(
          secureStorage.write(key: 'preKeys', value: anyNamed('value')));
    });

    test('storePreKey should store a preKey in the secure storage', () async {
      final secureStorage = MockSecureStorage();
      final preKeyStore = SecureStoragePreKeyStore(secureStorage);
      final preKeyRecord = generatePreKeys(0, 1)[0];

      when(secureStorage.read(key: 'preKeys'))
          .thenAnswer((_) => Future.value(null));

      await preKeyStore.storePreKey(0, preKeyRecord);

      verify(secureStorage.write(key: 'preKeys', value: anyNamed('value')));
    });
  });
}
