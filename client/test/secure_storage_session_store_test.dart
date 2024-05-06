import 'dart:convert';
import 'package:test/test.dart';
import 'package:missive/features/encryption/secure_storage_session_store.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'secure_storage_session_store_test.mocks.dart';

@GenerateMocks([SecureStorage])
void main() {
  group('SecureStorageSessionStore', () {
    test('containsSession should return false if there are no sessions',
        () async {
      final secureStorage = MockSecureStorage();
      final sessionStore = SecureStorageSessionStore(secureStorage);

      when(secureStorage.read(key: 'sessions'))
          .thenAnswer((_) => Future.value(null));

      expect(
          await sessionStore
              .containsSession(const SignalProtocolAddress('test', 1)),
          isFalse);
    });
  });
}
