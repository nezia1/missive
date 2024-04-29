import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:uuid/uuid.dart';

import 'plain_text_message.dart';

class ChatProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  String? _url;
  String? _name;
  AuthProvider? _authProvider;
  SignalProvider? _signalProvider;
  ValueListenable<Box> get messagesListenable => _name != null
      ? Hive.box<List>('${_name}_messages').listenable()
      : throw Exception('ChatProvider is not fully initialized');

  ChatProvider(
      {String? url, AuthProvider? authProvider, SignalProvider? signalProvider})
      : _url = url,
        _authProvider = authProvider,
        _signalProvider = signalProvider;

  // Empty constructor for ChangeNotifierProxyProvider's create method
  ChatProvider.empty() : this();

  void update(
      {required String url,
      required AuthProvider authProvider,
      required SignalProvider signalProvider}) {
    _url = url;
    _authProvider = authProvider;
    _signalProvider = signalProvider;
  }

  bool needsUpdate() =>
      _url == null || _authProvider == null || _signalProvider == null;

  Future<void> connect() async {
    if (_url == null || _authProvider == null || _signalProvider == null) {
      throw Exception('ChatProvider is not fully initialized');
    }

    print(await _authProvider!.accessToken);
    final ws = await WebSocket.connect(
      _url!,
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer ${await _authProvider!.accessToken}'
      },
    );

    _channel = IOWebSocketChannel(ws);
    print('Connected to $_url');
    _name = (await _authProvider?.user)?.name;
    // Initialize Hive box for storing messages
    final encryptedBox = await _getMessagesBox();

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

      final plainText = await _signalProvider!.decrypt(
          cipherMessage, SignalProtocolAddress(messageJson['sender'], 1));

      final plainTextMessage = PlainTextMessage(
        id: messageJson['id'],
        content: plainText,
        own: false,
      );

      // store message in Hive
      final messages =
          encryptedBox.get(messageJson['sender'])?.cast<PlainTextMessage>() ??
              <PlainTextMessage>[];
      messages.add(plainTextMessage);
      for (var m in messages) {
        print(m.content);
      }
      await encryptedBox.put(messageJson['sender'], messages);

      notifyListeners();
    });
  }

  // TODO: add id to message so that we can update the status
  Future<void> sendMessage(
      {required String plainText, required String receiver}) async {
    final uuid = const Uuid().v6();
    if (_signalProvider == null) {
      throw Exception('SignalProvider is not initialized');
    }
    final message =
        await _signalProvider!.encrypt(name: receiver, message: plainText);

    print(uuid);

    final messageJson = jsonEncode({
      'id': uuid,
      'content': base64Encode(message.serialize()),
      'receiver': receiver,
    });

    // send message over WebSocket
    _channel?.sink.add(messageJson);

    // store sent message
    final encryptedBox = await _getMessagesBox();
    final messages = encryptedBox.get(receiver)?.cast<PlainTextMessage>() ??
        <PlainTextMessage>[];

    messages.add(PlainTextMessage(id: uuid, content: plainText, own: true));

    await encryptedBox.put(receiver, messages);

    notifyListeners();
  }

  /// Get the messages box for the current authenticated user
  Future<Box<List>> _getMessagesBox() async {
    if (_authProvider == null) {
      throw Exception('AuthProvider is not initialized');
    }

    final name = (await _authProvider!.user)!.name;
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

    return await Hive.openBox<List>('${_name}_messages',
        encryptionCipher: hiveCipher);
  }

  /// Get a list of all conversations for the current authenticated user. Returns a list of usernames, alongside the latest message.
  Future<List<Map<String, String>>> getConversations() async {
    if (_authProvider == null) {
      throw Exception('AuthProvider is not initialized');
    }

    final encryptedBox = await _getMessagesBox();

    final conversations = <Map<String, String>>[];

    for (var key in encryptedBox.keys) {
      final messages = encryptedBox.get(key)?.cast<PlainTextMessage>() ?? [];
      final latestMessage = messages.last;
      conversations.add({
        'username': key,
        'latestMessage': latestMessage.content,
      });
    }

    return conversations;
  }

  @override
  void dispose() {
    if (_channel != null) {
      _channel?.sink.close();
    }
    super.dispose();
  }
}
