import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';

class ChatProvider with ChangeNotifier {
  WebSocketChannel? channel;
  final String _url;
  final SignalProvider _signalProvider;

  ChatProvider(this._url, this._signalProvider);

  void connect(String accessToken) async {
    final ws = await WebSocket.connect(
      _url,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
    );

    channel = IOWebSocketChannel(ws);

    channel!.stream.listen((message) async {
      final messageJson = jsonDecode(message);
      if (messageJson['status'] != null) {
        print(
            'This is a status update, update corresponding message status accordingly. $messageJson');
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

      // TODO: send received message to SignalProvider for decryption and session handling
      await _signalProvider.handleReceivedMessage(
          cipherMessage, SignalProtocolAddress(messageJson['sender'], 1));
    });
  }

  void sendMessage(CiphertextMessage message, String receiver) {
    final messageJson = jsonEncode({
      'content': base64Encode(message.serialize()),
      'receiver': receiver,
    });
    channel?.sink.add(messageJson);
  }

  void disconnect() {
    channel?.sink.close();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
