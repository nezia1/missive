import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStoragePreKeyStore implements PreKeyStore {
  FlutterSecureStorage _secureStorage;
  SecureStoragePreKeyStore(FlutterSecureStorage secureStorage)
      : _secureStorage = secureStorage;

  @override
  Future<bool> containsPreKey(int preKeyId) {
    // TODO: implement containsPreKey
    throw UnimplementedError();
  }

  @override

  /// Loads a serialized [PreKeyRecord] from [FlutterSecureStorage] and returns it as a [PreKeyRecord].
  /// Throws a n [Exception] if the pre key is not found.
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final preKeysJson = await _secureStorage.read(key: 'preKeys');

    if (preKeysJson == null) throw Exception('PreKeys not found');

    Map<String, dynamic> preKeys = jsonDecode(preKeysJson);

    if (!preKeys.containsKey(preKeyId.toString())) {
      throw Exception('PreKey not found');
    }

    // Decode the base64 string and deserialize it as a PreKeyRecord
    return PreKeyRecord.fromBuffer(base64Decode(preKeys[preKeyId.toString()]));
  }

  @override
  Future<void> removePreKey(int preKeyId) {
    // TODO: implement removePreKey
    throw UnimplementedError();
  }

  @override

  /// Store a [PreKeyRecord] in the device's secure storage
  /// The pre key is stored as a base64 encoded [String]
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    final preKeysJson = await _secureStorage.read(key: 'preKeys');
    Map<String, dynamic> preKeys =
        preKeysJson != null ? jsonDecode(preKeysJson) : {};

    // Serialize the record as a UInt8List and encode it as a base64 string (SecureStorage expects strings. This will need to be decoded when retrieved)
    preKeys[preKeyId.toString()] = base64Encode(record.serialize());
    await _secureStorage.write(key: 'preKeys', value: jsonEncode(preKeys));
  }
}
