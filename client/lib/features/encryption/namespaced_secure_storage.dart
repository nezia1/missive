import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A wrapper around [FlutterSecureStorage] that allows for namespacing keys.
/// This is used when we want to store multiple keys, but want to avoid key collisions.
///
/// ## Usage
/// ```dart
/// final namespacedSecureStorage = NamespacedSecureStorage(
///   secureStorage: FlutterSecureStorage(),
///   namespace: 'myNamespace',
/// );
/// await namespacedSecureStorage.write(key: 'myKey', value: 'myValue');
/// ```
class NamespacedSecureStorage implements SecureStorage {
  final FlutterSecureStorage _secureStorage;
  final String? _namespace;

  NamespacedSecureStorage(
      {required FlutterSecureStorage secureStorage, String? namespace})
      : _secureStorage = secureStorage,
        _namespace = namespace;

  @override

  /// Returns the value associated with the given key.
  ///
  /// ## Parameters
  /// - `key`: The key whose associated value is to be returned.
  ///
  /// ## Returns
  /// - The value associated with the given key, or `null` if the key does not exist.
  Future<String?> read({required String key}) async {
    return await _secureStorage.read(key: _getNamespacedKey(key));
  }

  @override

  /// Writes the given value to the given key.
  ///
  /// ## Parameters
  /// - `key`: The key to write the value to.
  /// - `value`: The value to be written.
  Future<void> write({required String key, required String? value}) async {
    await _secureStorage.write(key: _getNamespacedKey(key), value: value);
  }

  @override

  /// Deletes the value associated with the given key.
  ///
  /// ## Parameters
  /// - `key`: The key whose value is to be deleted.
  Future<void> delete({required String key}) async {
    await _secureStorage.delete(key: _getNamespacedKey(key));
  }

  @override

  /// Deletes all keys and values from the secure storage.
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
  }

  /// Returns the key with the namespace prepended.
  /// If no namespace is set, the key is returned as is.
  ///
  /// ## Parameters
  /// - `key`: The key to be namespaced.
  ///
  /// ## Returns
  /// - The namespaced key.
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
