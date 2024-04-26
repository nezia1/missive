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
    final encryptedBox = await _getMessagesBox(name);

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
      final messages =
          encryptedBox.get(messageJson['sender'])?.cast<PlainTextMessage>() ??
              <PlainTextMessage>[];
      messages.add(plainTextMessage);
      await encryptedBox.put(messageJson['sender'], messages);

      notifyListeners();
    });
  }

  // TODO: add id to message so that we can update the status
  Future<void> sendMessage(
      {required String plainText,
      required String receiver,
      required String name}) async {
    final message =
        await _signalProvider.encrypt(name: receiver, message: plainText);

    final messageJson = jsonEncode({
      'content': base64Encode(message.serialize()),
      'receiver': receiver,
    });
    // send message over WebSocket
    _channel?.sink.add(messageJson);

    // store sent message
    final encryptedBox = await _getMessagesBox(name);
    final messages = encryptedBox.get(receiver)?.cast<PlainTextMessage>() ??
        <PlainTextMessage>[];

    messages.add(PlainTextMessage(content: plainText, own: true));

    await encryptedBox.put(receiver, messages);
  }

  /// Get the messages box for a specific user
  Future<Box<List>> _getMessagesBox(String name) async {
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

    return await Hive.openBox<List>('messages', encryptionCipher: hiveCipher);
  }

  @override
  void dispose() {
    if (_channel != null) {
      _channel?.sink.close();
    }
    super.dispose();
  }
}
