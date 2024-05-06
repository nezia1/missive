import 'dart:convert';
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
  });
}
