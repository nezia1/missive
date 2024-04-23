import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Handles storing and retrieving data from secure storage under a given namespace.
class SecureStorageManager {
  final FlutterSecureStorage _secureStorage;
  final String _namespace;

  SecureStorageManager(
      {required FlutterSecureStorage secureStorage, String namespace = ''})
      : _secureStorage = secureStorage,
        _namespace = namespace;

  // Returns the value associated with the given key.
  Future<String?> read({required String key}) async {
    return await _secureStorage.read(key: '${_namespace}_$key');
  }

  // Writes the given value to the given key.
  Future<void> write({required String key, required String? value}) async {
    await _secureStorage.write(key: '${_namespace}_$key', value: value);
  }

  Future<void> delete({required String key}) async {
    await _secureStorage.delete(key: '${_namespace}_$key');
  }

  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
  }
}
