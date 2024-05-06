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

    test('containsSession should return true if there is a session', () async {
      final secureStorage = MockSecureStorage();
      final sessionStore = SecureStorageSessionStore(secureStorage);

      when(secureStorage.read(key: 'sessions'))
          .thenAnswer((_) => Future.value(jsonEncode({
                'test': {
                  '1': {
                    'session': 'session',
                    'created_at': DateTime.now().toIso8601String()
                  }
                }
              })));

      expect(
          await sessionStore
              .containsSession(const SignalProtocolAddress('test', 1)),
          isTrue);
    });

    test('loadSession should return an empty session if it does not exist',
        () async {
      final secureStorage = MockSecureStorage();
      final sessionStore = SecureStorageSessionStore(secureStorage);

      when(secureStorage.read(key: 'sessions'))
          .thenAnswer((_) => Future.value(null));

      expect(
          (await sessionStore
                  .loadSession(const SignalProtocolAddress('test', 1)))
              .isFresh(),
          isTrue);
    });

    test('loadSession should return a session if there is one', () async {
      final secureStorage = MockSecureStorage();
      final sessionStore = SecureStorageSessionStore(secureStorage);

      when(secureStorage.read(key: 'sessions'))
          .thenAnswer((_) => Future.value(jsonEncode({
                'test': {
                  '1': {
                    'session': 'session',
                    'created_at': DateTime.now().toIso8601String()
                  }
                }
              })));

      final session = await sessionStore
          .loadSession(const SignalProtocolAddress('test', 1));

      expect(session, isNotNull);
      expect(session, isA<SessionRecord>());
      expect(session, isNot(session.isFresh()));
    });
  });

  test('storeSession should store a session', () async {
    final secureStorage = MockSecureStorage();
    final sessionstore = SecureStorageSessionStore(secureStorage);

    when(secureStorage.read(key: 'sessions'))
        .thenAnswer((_) => Future.value(null));

    await sessionstore.storeSession(
        const SignalProtocolAddress('test', 1), SessionRecord());

    verify(
      secureStorage.write(
          key: 'sessions',
          // checks that the value is a json string with the correct key
          value: argThat(predicate<String>((jsonString) {
            final decoded = jsonDecode(jsonString);
            return decoded['test:1'] != null && decoded['test:1'] is String;
          }), named: 'value')),
    ).called(1);
  });
}
