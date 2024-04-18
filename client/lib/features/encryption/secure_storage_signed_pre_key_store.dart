import 'dart:convert';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageSignedPreKeyStore implements SignedPreKeyStore {
  final FlutterSecureStorage _secureStorage;

  SecureStorageSignedPreKeyStore(FlutterSecureStorage secureStorage)
      : _secureStorage = secureStorage;

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return false;

    return signedPreKeys.containsKey(signedPreKeyId.toString());
  }

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final signedPreKeys = await _loadKeys();
    if (signedPreKeys == null) {
      throw InvalidKeyIdException('No such signed pre key id: $signedPreKeyId');
    }
    return SignedPreKeyRecord.fromSerialized(
        signedPreKeys[signedPreKeyId.toString()]);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return [];

    // each element is serialized
    return signedPreKeys.values
        .map((value) => SignedPreKeyRecord.fromSerialized(value))
        .toList();
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return;

    signedPreKeys.remove(signedPreKeyId.toString());
  }

  @override
  Future<void> storeSignedPreKey(
      int signedPreKeyId, SignedPreKeyRecord record) async {
    var signedPreKeys = await _loadKeys();

    signedPreKeys ??= <String, dynamic>{};

    signedPreKeys[signedPreKeyId.toString()] = record.serialize();
    await _secureStorage.write(
        key: 'signedPreKeys', value: jsonEncode(signedPreKeys));
  }

  Future<Map<String, dynamic>?> _loadKeys() async {
    final preKeysString = await _secureStorage.read(key: 'signedPreKeys');
    if (preKeysString == null) return null;
    return jsonDecode(preKeysString) as Map<String, dynamic>;
  }
}
