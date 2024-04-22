import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  final String _url;

  ChatProvider(this._url);

  void connect(String accessToken) async {
    final ws = await WebSocket.connect(
      _url,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
    );

    _channel = IOWebSocketChannel(ws);

    _channel!.stream.listen((message) {
      print('Received: $message');
    });
  }

  void sendMessage(String message) {
    _channel?.sink.add(message);
  }

  void disconnect() {
    _channel?.sink.close();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
