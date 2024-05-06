import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A wrapper around [FlutterSecureStorage] that allows for namespacing keys.
/// This is used when we want to store multiple keys, but want to avoid key collisions.
class NamespacedSecureStorage implements SecureStorage {
  final FlutterSecureStorage _secureStorage;
  final String? _namespace;

  NamespacedSecureStorage(
      {required FlutterSecureStorage secureStorage, String? namespace})
      : _secureStorage = secureStorage,
        _namespace = namespace;

  // Returns the value associated with the given key.
  @override
  Future<String?> read({required String key}) async {
    return await _secureStorage.read(key: _getNamespacedKey(key));
  }

  // Writes the given value to the given key.
  @override
  Future<void> write({required String key, required String? value}) async {
    await _secureStorage.write(key: _getNamespacedKey(key), value: value);
  }

  @override
  Future<void> delete({required String key}) async {
    await _secureStorage.delete(key: _getNamespacedKey(key));
  }

  @override
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
  }

  /// Returns the key with the namespace prepended.
  /// If no namespace is set, the key is returned as is.
  String _getNamespacedKey(String key) {
    return '${_namespace != null ? '${_namespace}_' : ''}$key';
  }
}

abstract class SecureStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String? value});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}
