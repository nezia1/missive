import 'dart:convert';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';

class SecureStorageSignedPreKeyStore implements SignedPreKeyStore {
  final SecureStorage _secureStorage;

  SecureStorageSignedPreKeyStore(SecureStorage secureStorage)
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
    if (signedPreKeys == null ||
        signedPreKeys[signedPreKeyId.toString()] == null) {
      throw InvalidKeyIdException('No such signed pre key id: $signedPreKeyId');
    }
    return SignedPreKeyRecord.fromSerialized(
        base64Decode(signedPreKeys[signedPreKeyId.toString()]!));
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return [];

    // each element is serialized
    return signedPreKeys.values
        .map((value) => SignedPreKeyRecord.fromSerialized(base64Decode(value)))
        .toList();
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return;

    signedPreKeys.remove(signedPreKeyId.toString());

    await _secureStorage.write(
        key: 'signedPreKeys', value: jsonEncode(signedPreKeys));
  }

  @override
  Future<void> storeSignedPreKey(
      int signedPreKeyId, SignedPreKeyRecord record) async {
    var signedPreKeys = await _loadKeys();

    signedPreKeys ??= <String, String>{};

    signedPreKeys[signedPreKeyId.toString()] = base64Encode(record.serialize());

    await _secureStorage.write(
        key: 'signedPreKeys', value: jsonEncode(signedPreKeys));
  }

  /// Load signed pre-keys from secure storage as base 64 encoded [SignedPreKeyRecord]s.
  Future<Map<String, dynamic>?> _loadKeys() async {
    final preKeysString =
        await _secureStorage.read(key: 'signedPreKeys').catchError((_) => null);
    if (preKeysString == null) return null;

    return jsonDecode(preKeysString);
  }
}
