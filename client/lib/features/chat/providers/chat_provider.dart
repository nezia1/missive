import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:hive/hive.dart';

import 'plain_text_message.dart';

class ChatProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  final String _url;
  final SignalProvider _signalProvider;
  final List<String> messages = [];

  ChatProvider(this._url, this._signalProvider);

  Future<void> connect(
      {required String accessToken, required String name}) async {
    final ws = await WebSocket.connect(
      _url,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
    );

    _channel = IOWebSocketChannel(ws);

    print('Connected to $_url');
    // Initialize Hive box for storing messages
    const secureStorage = FlutterSecureStorage();
    var hiveEncryptionKeyString =
        await secureStorage.read(key: '${name}_hiveEncryptionKey');

    if (hiveEncryptionKeyString == null) {
      hiveEncryptionKeyString = base64Encode(Hive.generateSecureKey());
      await secureStorage.write(
        key: '${name}_hiveEncryptionKey',
        value: hiveEncryptionKeyString,
      );
    }

    final hiveCipher = HiveAesCipher(base64Decode(hiveEncryptionKeyString));

    final encryptedBox = await Hive.openBox<List<PlainTextMessage>>('messages',
        encryptionCipher: hiveCipher);

    _channel!.stream.listen((message) async {
      final messageJson = jsonDecode(message);
      if (messageJson['status'] != null) {
        print(
            'This is a status update, update corresponding message status accordingly. $message');
        return;
      }

      CiphertextMessage cipherMessage;

      final serializedContent = base64Decode(messageJson['content']);

      // Try parsing it as a SignalMessage, if it fails, it's a PreKeySignalMessage
      try {
        cipherMessage = SignalMessage.fromSerialized(serializedContent);
      } catch (_) {
        cipherMessage = PreKeySignalMessage(serializedContent);
      }

      final plainText = await _signalProvider.decrypt(
          cipherMessage, SignalProtocolAddress(messageJson['sender'], 1));

      final plainTextMessage = PlainTextMessage(
        content: plainText,
        own: false,
      );

      // store message in Hive
      // TODO: fix typing issues
      final messages =
          encryptedBox.get(messageJson['sender']) ?? <PlainTextMessage>[];
      messages.add(plainTextMessage);

      await encryptedBox.put(messageJson['sender'], messages);

      notifyListeners();
    });
  }

  void sendMessage(CiphertextMessage message, String receiver) {
    final messageJson = jsonEncode({
      'content': base64Encode(message.serialize()),
      'receiver': receiver,
    });
    _channel?.sink.add(messageJson);
  }

  @override
  void dispose() {
    if (_channel != null) {
      _channel?.sink.close();
    }
    super.dispose();
  }
}
