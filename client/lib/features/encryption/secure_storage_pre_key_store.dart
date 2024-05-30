import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'dart:convert';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';

/// A class that implements [PreKeyStore] to store, retrieve, and manage pre keys using [SecureStorage].
///
/// This class interacts with the device's secure storage to handle pre keys,
/// which are essential for the Signal Protocol. It provides methods to check the existence,
/// load, store, and remove pre keys, as well as a private method to load all keys.
///
/// ## Usage
/// ```dart
/// final secureStoragePreKeyStore = SecureStoragePreKeyStore(secureStorage);
/// await secureStoragePreKeyStore.storePreKey(preKeyId, preKeyRecord);
/// ```
///
class SecureStoragePreKeyStore implements PreKeyStore {
  final SecureStorage _secureStorage;

  SecureStoragePreKeyStore(SecureStorage secureStorage)
      : _secureStorage = secureStorage;

  @override

  /// Checks if a pre key with the given [preKeyId] exists in the secure storage.
  ///
  /// ## Returns
  /// - `true` if the pre key exists, `false` otherwise.
  Future<bool> containsPreKey(int preKeyId) async {
    final preKeys = await _loadKeys();
    if (preKeys == null) return false;
    return preKeys.containsKey(preKeyId.toString());
  }

  @override

  /// Loads a serialized [PreKeyRecord] from [SecureStorage] and returns it as a [PreKeyRecord].
  ///
  /// ## Parameters
  /// - `preKeyId`: The ID of the pre key to load.
  ///
  /// ## Returns
  /// - A [PreKeyRecord] if found.
  ///
  /// ## Throws
  /// - `InvalidKeyIdException` if the pre key is not found or if no pre keys are stored.
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final preKeys = await _loadKeys();

    if (preKeys == null) {
      throw InvalidKeyIdException('There are no preKeys stored');
    }

    final preKey = preKeys[preKeyId.toString()];
    if (preKey == null) {
      throw InvalidKeyIdException('PreKey with id $preKeyId not found');
    }

    // Decode the base64 string and deserialize it as a PreKeyRecord
    return PreKeyRecord.fromBuffer(base64Decode(preKey));
  }

  @override

  /// Removes a pre key with the given [preKeyId] from the secure storage.
  ///
  /// ## Parameters
  /// - `preKeyId`: The ID of the pre key to remove.
  Future<void> removePreKey(int preKeyId) async {
    final preKeys = await _loadKeys();
    if (preKeys == null) return;
    preKeys.remove(preKeyId.toString());
    await _secureStorage.write(key: 'preKeys', value: jsonEncode(preKeys));
  }

  @override

  /// Stores a [PreKeyRecord] in the device's secure storage.
  ///
  /// The pre key is stored as a base64 encoded [String].
  ///
  /// ## Parameters
  /// - `preKeyId`: The ID of the pre key to store.
  /// - `record`: The [PreKeyRecord] to store.
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    var preKeys = await _loadKeys();

    // If there are no preKeys, create an empty map
    preKeys ??= <String, dynamic>{};

    // Serialize the record as a UInt8List and encode it as a base64 string (SecureStorage expects strings. This will need to be decoded when retrieved)
    preKeys[preKeyId.toString()] = base64Encode(record.serialize());

    await _secureStorage.write(key: 'preKeys', value: jsonEncode(preKeys));
  }

  /// Loads all pre keys from the secure storage.
  ///
  /// ## Returns
  /// - A [Map] of [PreKeyRecord]s if found, `null` otherwise.
  Future<Map<String, dynamic>?> _loadKeys() async {
    final preKeysJson =
        await _secureStorage.read(key: 'preKeys').catchError((_) => null);
    if (preKeysJson == null) return null;
    final preKeys = jsonDecode(preKeysJson);

    return preKeys;
  }
}
