import 'dart:convert';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageSessionStore implements SessionStore {
  final FlutterSecureStorage _secureStorage;

  SecureStorageSessionStore(FlutterSecureStorage secureStorage)
      : _secureStorage = secureStorage;

  @override
  Future<bool> containsSession(SignalProtocolAddress address) {
    // TODO: implement containsSession
    throw UnimplementedError();
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
    final sessions = await _getSessions();

    if (sessions == null) {
      throw Exception('No session with address $address found');
    }
    final session = sessions[address.toString()];

    if (session == null) {
      throw Exception('No session with address $address found');
    }

    return session;
  }

  @override
  Future<void> storeSession(
      SignalProtocolAddress address, SessionRecord record) async {
    final sessions = await _getSessions();

    if (sessions == null) return;

    sessions[address.toString()] = base64Encode(record.serialize());

    await _secureStorage.write(key: 'sessions', value: jsonEncode(sessions));
  }

  Future<Map<String, dynamic>?> _getSessions() async {
    final serializedSessions = await _secureStorage.read(key: 'sessions');

    if (serializedSessions == null) return null;

    return jsonDecode(serializedSessions);
  }
}
