import 'dart:convert';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';

/// A class that implements [SignedPreKeyStore] to store, retrieve, and manage signed pre keys using [SecureStorage].
///
/// This class interacts with the device's secure storage to handle signed pre keys,
/// which are essential for the Signal Protocol. It provides methods to check the existence,
/// load, store, and remove signed pre keys, as well as a private method to load all keys.
///
/// ## Usage
/// ```dart
/// final secureStorageSignedPreKeyStore = SecureStorageSignedPreKeyStore(secureStorage);
/// await secureStorageSignedPreKeyStore.storeSignedPreKey(signedPreKeyId, signedPreKeyRecord);
/// ```
class SecureStorageSignedPreKeyStore implements SignedPreKeyStore {
  final SecureStorage _secureStorage;

  SecureStorageSignedPreKeyStore(SecureStorage secureStorage)
      : _secureStorage = secureStorage;

  @override

  /// Checks if a signed pre key with the given [signedPreKeyId] exists in the secure storage.
  ///
  /// ## Parameters
  /// - `signedPreKeyId`: The ID of the signed pre key to check.
  ///
  /// ## Returns
  /// - `true` if the signed pre key exists, `false` otherwise.
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return false;

    return signedPreKeys.containsKey(signedPreKeyId.toString());
  }

  @override

  /// Loads a serialized [SignedPreKeyRecord] from [SecureStorage] and returns it as a [SignedPreKeyRecord].
  ///
  /// ## Parameters
  /// - `signedPreKeyId`: The ID of the signed pre key to load.
  ///
  /// ## Returns
  /// - A [SignedPreKeyRecord] if found.
  ///
  /// ## Throws
  /// - `InvalidKeyIdException` if the signed pre key is not found.
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

  /// Loads all serialized [SignedPreKeyRecord]s from [SecureStorage] and returns them as a list of [SignedPreKeyRecord]s.
  ///
  /// ## Returns
  /// - A list of [SignedPreKeyRecord]s if found, an empty list otherwise.
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return [];

    // Each element is serialized
    return signedPreKeys.values
        .map((value) => SignedPreKeyRecord.fromSerialized(base64Decode(value)))
        .toList();
  }

  @override

  /// Removes a signed pre key with the given [signedPreKeyId] from the secure storage.
  ///
  /// ## Parameters
  /// - `signedPreKeyId`: The ID of the signed pre key to remove.
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    final signedPreKeys = await _loadKeys();

    if (signedPreKeys == null) return;

    signedPreKeys.remove(signedPreKeyId.toString());

    await _secureStorage.write(
        key: 'signedPreKeys', value: jsonEncode(signedPreKeys));
  }

  @override

  /// Stores a [SignedPreKeyRecord] in the device's secure storage.
  ///
  /// The signed pre key is stored as a base64 encoded [String].
  ///
  /// ## Parameters
  /// - `signedPreKeyId`: The ID of the signed pre key to store.
  /// - `record`: The [SignedPreKeyRecord] to store.
  Future<void> storeSignedPreKey(
      int signedPreKeyId, SignedPreKeyRecord record) async {
    var signedPreKeys = await _loadKeys();

    signedPreKeys ??= <String, String>{};

    signedPreKeys[signedPreKeyId.toString()] = base64Encode(record.serialize());

    await _secureStorage.write(
        key: 'signedPreKeys', value: jsonEncode(signedPreKeys));
  }

  /// Loads signed pre keys from secure storage as base64 encoded [SignedPreKeyRecord]s.
  ///
  /// ## Returns
  /// - A [Map] of signed pre keys if found, `null` otherwise.
  Future<Map<String, dynamic>?> _loadKeys() async {
    final preKeysString =
        await _secureStorage.read(key: 'signedPreKeys').catchError((_) => null);
    if (preKeysString == null) return null;

    return jsonDecode(preKeysString);
  }
}
