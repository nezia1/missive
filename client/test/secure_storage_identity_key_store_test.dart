import 'dart:convert';
import 'package:test/test.dart';
import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'secure_storage_identity_key_store_test.mocks.dart';

@GenerateMocks([SecureStorage])
void main() {
  test(
      'SecureStorageIdentityKeyStore should store IdentityKeyPair and registrationId',
      () async {
    final secureStorage = MockSecureStorage();
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    SecureStorageIdentityKeyStore.fromIdentityKeyPair(
        secureStorage, identityKeyPair, registrationId);

    when(secureStorage.read(key: 'identityKeyPair')).thenAnswer(
        (_) => Future.value(base64Encode(identityKeyPair.serialize())));
    when(secureStorage.read(key: 'registrationId'))
        .thenAnswer((_) => Future.value(registrationId.toString()));

    expect(await secureStorage.read(key: 'identityKeyPair'), isNotNull);
    expect(await secureStorage.read(key: 'identityKeyPair'),
        base64Encode(identityKeyPair.serialize()));
    expect(await secureStorage.read(key: 'registrationId'), isNotNull);
    expect(await secureStorage.read(key: 'registrationId'),
        registrationId.toString());
  });

  test('getIdentity should return the correct identity', () async {
    final secureStorage = MockSecureStorage();
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final identityKeyStore = SecureStorageIdentityKeyStore.fromIdentityKeyPair(
        secureStorage, identityKeyPair, registrationId);

    const address = SignalProtocolAddress('test', 1);
    final identityKey = identityKeyPair.getPublicKey();
    final identityKeyString = base64Encode(identityKey.serialize());

    when(secureStorage.read(key: address.toString()))
        .thenAnswer((_) => Future.value(identityKeyString));

    expect(await identityKeyStore.getIdentity(address), isNotNull);
    expect(await identityKeyStore.getIdentity(address), identityKey);
  });

  test('getIdentityKeyPair should return the correct identity key pair',
      () async {
    final secureStorage = MockSecureStorage();
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final identityKeyStore = SecureStorageIdentityKeyStore.fromIdentityKeyPair(
        secureStorage, identityKeyPair, registrationId);

    final identityKeyPairString = base64Encode(identityKeyPair.serialize());

    when(secureStorage.read(key: 'identityKeyPair'))
        .thenAnswer((_) => Future.value(identityKeyPairString));

    expect(await identityKeyStore.getIdentityKeyPair(), isNotNull);
    expect(await identityKeyStore.getIdentityKeyPair(), identityKeyPair);
  });

  test('getLocalRegistrationId should return the correct registration ID',
      () async {
    final secureStorage = MockSecureStorage();
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final identityKeyStore = SecureStorageIdentityKeyStore.fromIdentityKeyPair(
        secureStorage, identityKeyPair, registrationId);

    when(secureStorage.read(key: 'registrationId'))
        .thenAnswer((_) => Future.value(registrationId.toString()));

    expect(await identityKeyStore.getLocalRegistrationId(), isNotNull);
    expect(await identityKeyStore.getLocalRegistrationId(), registrationId);
  });

  test('isTrustedIdentity should return true if identity is trusted', () async {
    final secureStorage = MockSecureStorage();
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final identityKeyStore = SecureStorageIdentityKeyStore.fromIdentityKeyPair(
        secureStorage, identityKeyPair, registrationId);

    const address = SignalProtocolAddress('test', 1);
    final identityKey = identityKeyPair.getPublicKey();
    final identityKeyString = base64Encode(identityKey.serialize());

    when(secureStorage.read(key: address.toString()))
        .thenAnswer((_) => Future.value(identityKeyString));

    expect(
        await identityKeyStore.isTrustedIdentity(
            address, identityKey, Direction.receiving),
        isTrue);
  });
}
