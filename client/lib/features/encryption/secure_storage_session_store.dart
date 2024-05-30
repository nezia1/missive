import 'dart:convert';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/features/encryption/namespaced_secure_storage.dart';

/// A class that implements [SessionStore] to store, retrieve, and manage sessions using [SecureStorage].
///
/// This class interacts with the device's secure storage to handle sessions,
/// which are essential for the Signal Protocol. It provides methods to check the existence,
/// load, store, and delete sessions, as well as a private method to load all sessions.
///
/// ## Usage
/// ```dart
/// final secureStorageSessionStore = SecureStorageSessionStore(secureStorage);
/// await secureStorageSessionStore.storeSession(address, sessionRecord);
/// ```
class SecureStorageSessionStore implements SessionStore {
  final SecureStorage _secureStorage;

  SecureStorageSessionStore(SecureStorage secureStorage)
      : _secureStorage = secureStorage;

  @override

  /// Checks if a session with the given [address] exists in the secure storage.
  ///
  /// ## Parameters
  /// - `address`: The [SignalProtocolAddress] of the session to check.
  ///
  /// ## Returns
  /// - `true` if the session exists, `false` otherwise.
  Future<bool> containsSession(SignalProtocolAddress address) async {
    var sessions = await _getSessions();

    if (sessions == null) return false;

    return sessions[address.toString()] != null;
  }

  @override

  /// Deletes all sessions associated with the given [name].
  ///
  /// ## Parameters
  /// - `name`: The name associated with the sessions to delete.
  ///
  /// ## Throws
  /// - `UnimplementedError` as this method is not yet implemented.
  Future<void> deleteAllSessions(String name) {
    // TODO: implement deleteAllSessions
    throw UnimplementedError();
  }

  @override

  /// Deletes the session associated with the given [address].
  ///
  /// ## Parameters
  /// - `address`: The [SignalProtocolAddress] of the session to delete.
  ///
  /// ## Throws
  /// - `UnimplementedError` as this method is not yet implemented.
  Future<void> deleteSession(SignalProtocolAddress address) {
    // TODO: implement deleteSession
    throw UnimplementedError();
  }

  @override

  /// Retrieves sub-device sessions associated with the given [name].
  ///
  /// ## Parameters
  /// - `name`: The name associated with the sub-device sessions to retrieve.
  ///
  /// ## Throws
  /// - `UnimplementedError` as this method is not yet implemented.
  Future<List<int>> getSubDeviceSessions(String name) {
    // TODO: implement getSubDeviceSessions
    throw UnimplementedError();
  }

  @override

  /// Loads a serialized [SessionRecord] from [SecureStorage] and returns it as a [SessionRecord].
  ///
  /// ## Parameters
  /// - `address`: The [SignalProtocolAddress] of the session to load.
  ///
  /// ## Returns
  /// - A [SessionRecord] if found, otherwise an empty [SessionRecord].
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    var session = (await _getSessions())?[address.toString()];

    if (session == null) return SessionRecord();

    return SessionRecord.fromSerialized(base64Decode(session));
  }

  @override

  /// Stores a [SessionRecord] in the device's secure storage.
  ///
  /// The session is stored as a base64 encoded [String].
  ///
  /// ## Parameters
  /// - `address`: The [SignalProtocolAddress] of the session to store.
  /// - `record`: The [SessionRecord] to store.
  Future<void> storeSession(
      SignalProtocolAddress address, SessionRecord record) async {
    var sessions = await _getSessions();

    sessions ??= {};

    sessions[address.toString()] = base64Encode(record.serialize());

    await _secureStorage.write(key: 'sessions', value: jsonEncode(sessions));
  }

  /// Loads all sessions from the secure storage.
  ///
  /// ## Returns
  /// - A [Map] of sessions if found, `null` otherwise.
  Future<Map<String, dynamic>?> _getSessions() async {
    final serializedSessions =
        await _secureStorage.read(key: 'sessions').catchError((_) => null);

    if (serializedSessions == null) return null;

    return jsonDecode(serializedSessions);
  }
}
