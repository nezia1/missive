import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorageIdentityKeyStore implements IdentityKeyStore {
  final FlutterSecureStorage _secureStorage;

  SecureStorageIdentityKeyStore(FlutterSecureStorage secureStorage)
      : _secureStorage = secureStorage;

  /// Instanciate a new [SecureStorageIdentityKeyStore], and store the [IdentityKeyPair] and registrationId using [FlutterSecureStorage]. This is meant to be used when the user first creates their account.
  SecureStorageIdentityKeyStore.fromIdentityKeyPair(
      FlutterSecureStorage secureStorage,
      IdentityKeyPair identityKeyPair,
      int registrationId)
      : _secureStorage = secureStorage {
    // we cannot use async here, so we need to use Future.wait since fromIdentityKeyPair a constructor
    List<Future> futures = [
      _secureStorage.write(
          key: 'identityKeyPair',
          value: base64Encode(identityKeyPair.serialize())),
      _secureStorage.write(
          key: 'registrationId', value: registrationId.toString())
    ];
    Future.wait(futures);
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final identityKeyString =
        await _secureStorage.read(key: address.toString());
    if (identityKeyString == null) return null;
    return IdentityKey.fromBytes(base64Decode(identityKeyString), 0);
  }

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final identityKeyPairString =
        await _secureStorage.read(key: 'identityKeyPair');

    if (identityKeyPairString == null) {
      throw Exception('Identity key pair not found');
    }

    return IdentityKeyPair.fromSerialized(base64Decode(identityKeyPairString));
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final registrationId = await _secureStorage.read(key: 'registrationId');

    if (registrationId == null) throw Exception('Registration ID not found');

    return int.parse(registrationId);
  }

  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address,
      IdentityKey? identityKey, Direction direction) {
    // TODO: implement isTrustedIdentity
    throw UnimplementedError();
  }

  @override
  Future<bool> saveIdentity(
      SignalProtocolAddress address, IdentityKey? identityKey) async {
    if (identityKey == null) return false;
    String serializedIdentityKey = base64Encode(identityKey.serialize());
    await _secureStorage.write(
        key: address.toString(), value: serializedIdentityKey);
    return true;
  }
}
