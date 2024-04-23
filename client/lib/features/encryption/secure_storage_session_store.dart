import 'dart:convert';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/features/encryption/secure_storage_manager.dart';

class SecureStorageSessionStore implements SessionStore {
  final SecureStorageManager _storageManager;

  SecureStorageSessionStore(SecureStorageManager storageManager)
      : _storageManager = storageManager;

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    var sessions = await _getSessions();

    if (sessions == null) return false;

    return sessions[address.toString()] != null;
  }

  @override
  Future<void> deleteAllSessions(String name) {
    // TODO: implement deleteAllSessions
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) {
    // TODO: implement deleteSession
    throw UnimplementedError();
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) {
    // TODO: implement getSubDeviceSessions
    throw UnimplementedError();
  }

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    var session = (await _getSessions())?[address.toString()];

    if (session == null) return SessionRecord();

    return SessionRecord.fromSerialized(base64Decode(session));
  }

  @override
  Future<void> storeSession(
      SignalProtocolAddress address, SessionRecord record) async {
    var sessions = await _getSessions();

    sessions ??= {};

    sessions[address.toString()] = base64Encode(record.serialize());

    await _storageManager.write(key: 'sessions', value: jsonEncode(sessions));
  }

  Future<Map<String, dynamic>?> _getSessions() async {
    final serializedSessions = await _storageManager.read(key: 'sessions');

    if (serializedSessions == null) return null;

    return jsonDecode(serializedSessions);
  }
}
