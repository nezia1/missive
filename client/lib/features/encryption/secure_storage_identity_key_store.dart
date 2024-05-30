import 'package:collection/collection.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'dart:convert';

import 'package:missive/features/encryption/namespaced_secure_storage.dart';

/// A secure storage-based implementation of the IdentityKeyStore interface from the Signal protocol.
///
/// This class is responsible for:
/// - Storing identity keys and registration IDs securely using [SecureStorage].
/// - Providing methods to retrieve and verify the identity keys.
/// - Ensuring secure storage and management of identity-related information.
class SecureStorageIdentityKeyStore implements IdentityKeyStore {
  final SecureStorage _secureStorage;

  /// Constructs an instance of [SecureStorageIdentityKeyStore] with a secure storage manager.
  ///
  /// ## Parameters
  /// - [secureStorage]: An instance of [SecureStorage] for managing secure storage operations.
  SecureStorageIdentityKeyStore(SecureStorage secureStorage)
      : _secureStorage = secureStorage;

  /// Constructs an instance of [SecureStorageIdentityKeyStore] and stores the [IdentityKeyPair] and registrationId.
  ///
  /// This constructor is meant to be used when the user first creates their account.
  ///
  /// ## Parameters
  /// - [storageManager]: An instance of [SecureStorage] for managing secure storage operations.
  /// - [identityKeyPair]: The user's [IdentityKeyPair] that will be securely stored.
  /// - [registrationId]: The user's registration ID that will be securely stored.
  SecureStorageIdentityKeyStore.fromIdentityKeyPair(
      SecureStorage storageManager,
      IdentityKeyPair identityKeyPair,
      int registrationId)
      : _secureStorage = storageManager {
    // We cannot use async here, so we need to use Future.wait since fromIdentityKeyPair is a constructor
    List<Future> futures = [
      _secureStorage.write(
          key: 'identityKeyPair',
          value: base64Encode(identityKeyPair.serialize())),
      _secureStorage.write(
          key: 'registrationId', value: registrationId.toString())
    ];
    Future.wait(futures);
  }

  /// Retrieves the stored identity key for a given address.
  ///
  /// ## Parameters
  /// - [address]: The [SignalProtocolAddress] for which the identity key is to be retrieved.
  ///
  /// ## Returns
  /// - A [Future] containing the [IdentityKey] if found, else null.
  ///
  /// ## Usage
  /// ```dart
  /// IdentityKey? key = await keyStore.getIdentity(address);
  /// ```
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final identityKeyString = await _secureStorage
        .read(key: address.toString())
        .catchError((_) => null);
    if (identityKeyString == null) return null;
    return IdentityKey.fromBytes(base64Decode(identityKeyString), 0);
  }

  /// Retrieves the user's identity key pair from secure storage.
  ///
  /// ## Returns
  /// - A [Future] containing the [IdentityKeyPair].
  ///
  /// ## Throws
  /// - `Exception` if the identity key pair is not found.
  ///
  /// ## Usage
  /// ```dart
  /// IdentityKeyPair keyPair = await keyStore.getIdentityKeyPair();
  /// ```
  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final identityKeyPairString = await _secureStorage
        .read(key: 'identityKeyPair')
        .catchError((_) => null);

    if (identityKeyPairString == null) {
      throw Exception('Identity key pair not found');
    }

    return IdentityKeyPair.fromSerialized(base64Decode(identityKeyPairString));
  }

  /// Retrieves the local registration ID from secure storage.
  ///
  /// ## Returns
  /// - A [Future] containing the registration ID.
  ///
  /// ## Throws
  /// - `Exception` if the registration ID is not found.
  ///
  /// ## Usage
  /// ```dart
  /// int registrationId = await keyStore.getLocalRegistrationId();
  /// ```
  @override
  Future<int> getLocalRegistrationId() async {
    final registrationId = await _secureStorage
        .read(key: 'registrationId')
        .catchError((_) => null);

    if (registrationId == null) throw Exception('Registration ID not found');

    return int.parse(registrationId);
  }

  /// Checks if the identity key is trusted by comparing it with stored data.
  ///
  /// ## Parameters
  /// - [address]: The [SignalProtocolAddress] to check.
  /// - [identityKey]: The [IdentityKey] to verify.
  /// - [direction]: The [Direction] of the communication, indicating the direction of message (sending or receiving).
  ///
  /// ## Returns
  /// - A [Future] containing a boolean value indicating whether the identity is trusted.
  ///
  /// ## Usage
  /// ```dart
  /// bool isTrusted = await keyStore.isTrustedIdentity(address, identityKey, Direction.SENDING);
  /// ```
  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address,
      IdentityKey? identityKey, Direction direction) async {
    final trusted = await getIdentity(address);

    if (identityKey == null) return false;

    return trusted == null ||
        const ListEquality()
            .equals(trusted.serialize(), identityKey.serialize());
  }

  /// Saves the identity key for a given address in secure storage.
  ///
  /// ## Parameters
  /// - [address]: The [SignalProtocolAddress] associated with the identity key.
  /// - [identityKey]: The [IdentityKey] to be saved.
  ///
  /// ## Returns
  /// - A [Future] containing a boolean value indicating whether the save operation was successful.
  ///
  /// ## Usage
  /// ```dart
  /// bool success = await keyStore.saveIdentity(address, identityKey);
  /// ```
  @override
  Future<bool> saveIdentity(
      SignalProtocolAddress address, IdentityKey? identityKey) async {
    if (identityKey == null) return false;
    String serializedIdentityKey = base64Encode(identityKey.serialize());
    final existing = await getIdentity(address);
    if (identityKey == existing) return false;
    await _secureStorage.write(
        key: address.toString(), value: serializedIdentityKey);
    return true;
  }
}
  ///
