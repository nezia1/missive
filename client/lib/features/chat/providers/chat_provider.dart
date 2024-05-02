import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:realm/realm.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:missive/common/http.dart';
import 'package:uuid/uuid.dart' as uuid_generator;

part 'chat_provider.realm.dart';

class ChatProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  String? _url;
  AuthProvider? _authProvider;
  SignalProvider? _signalProvider;
  List<User> _conversations = [];
  List<User> get conversations => _conversations;
  Realm? _userRealm;
  StreamSubscription? _messagesSubscription;

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

    final ws = await WebSocket.connect(
      _url!,
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer ${await _authProvider!.accessToken}'
      },
    );

    _channel = IOWebSocketChannel(ws);
    print('Connected to $_url');
    _channel!.stream.listen((message) async {
      print('Received message: $message');
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

      // store message in Realm
      final realm = await _getUserRealm();
      realm.write(() {
        var user = realm.find<User>(messageJson['sender']);

        user ??= realm.add(User(messageJson['sender']));

        user.messages.add(PlaintextMessage(messageJson['id'], plainText, false,
            sentAt: DateTime.now()));
      });
    });
  }

  // TODO: add id to message so that we can update the status
  Future<void> sendMessage(
      {required String plainText, required String receiver}) async {
    final uuid = const uuid_generator.Uuid().v6();
    if (_signalProvider == null) {
      throw Exception('SignalProvider is not initialized');
    }
    final message =
        await _signalProvider!.encrypt(name: receiver, message: plainText);

    final messageJson = jsonEncode({
      'id': uuid,
      'content': base64Encode(message.serialize()),
      'receiver': receiver,
    });

    // send message over WebSocket
    _channel?.sink.add(messageJson);

    // store with Realm
    final realm = await _getUserRealm();
    final name = (await _authProvider?.user)?.name;

    if (name == null) {
      throw Exception('User is not logged in');
    }

    realm.write(() {
      var user = realm.find<User>(receiver);

      user ??= realm.add(User(receiver));

      user.messages.add(PlaintextMessage(
        uuid,
        plainText,
        true,
        sentAt: DateTime.now(),
      ));
    });
  }

  /// Setup the user's Realm database and listen for changes
  void setupUserRealm() async {
    _userRealm = await _getUserRealm();
    if (_userRealm == null) {
      throw Exception('User Realm is not initialized');
    }
    // initialize messages
    final conversations = _userRealm!.all<User>();
    _conversations = conversations.toList();

    notifyListeners(); // update UI with initial data load

    // listen for new messages
    var messages = _userRealm!.all<PlaintextMessage>();
    _messagesSubscription = messages.changes.listen((_) {
      _conversations = conversations.toList();
      notifyListeners(); // update UI on new messages
    });
  }

  void ensureConversationExists(String name) {
    _userRealm?.write(() {
      if (_userRealm?.find<User>(name) == null) _userRealm?.add(User(name));
    });
  }

  void fetchPendingMessages() async {
    // get pending messages from server
    final name = (await _authProvider?.user)?.name;
    final accessToken = await _authProvider?.accessToken;
    if (name == null || accessToken == null) {
      throw Exception('User is not logged in');
    }

    // get messages from server
    final response = await dio.get('/users/$name/messages',
        options: Options(
            headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'}));

    final messages = response.data['data']['messages'];

    // decrypt and store messages
    for (final message in messages) {
      CiphertextMessage cipherMessage;
      final sender = message['sender']['name'];
      try {
        // TODO: when switching accounts, it says (no session for sender). Is it because the session is not changed after logout? I think it has something to do with the ProxyProvider not updating the SignalProvider after logout.
        await _signalProvider?.buildSession(
            name: sender, accessToken: accessToken);
        cipherMessage =
            SignalMessage.fromSerialized(base64Decode(message['content']));
      } catch (_) {
        cipherMessage = PreKeySignalMessage(base64Decode(message['content']));
      }
      final plainText = await _signalProvider!
          .decrypt(cipherMessage, SignalProtocolAddress(sender, 1));
      _userRealm?.write(() {
        var user = _userRealm?.find<User>(sender);

        user ??= _userRealm?.add(User(sender));

        user?.messages.add(PlaintextMessage(
          message['id'],
          plainText,
          false,
          sentAt: DateTime.parse(message['sentAt']),
        ));
      });
    }
  }

  /// Gets the user's Realm database
  Future<Realm> _getUserRealm() async {
    if (_authProvider == null) {
      throw Exception('AuthProvider is not initialized');
    }

    const secureStorage = FlutterSecureStorage();
    final name = (await _authProvider!.user)!.name;

    // Generate a random encryption key if it doesn't exist, otherwise use the stored one
    var realmEncryptionKeyString =
        await secureStorage.read(key: '${name}_realmEncryptionKey');
    if (realmEncryptionKeyString == null) {
      final rng = Random.secure();
      final keyString = base64Encode(
          Uint8List.fromList(List<int>.generate(64, (i) => rng.nextInt(256))));
      realmEncryptionKeyString = keyString;
      await secureStorage.write(
          key: '${name}_realmEncryptionKey', value: keyString);
    }

    final realmKey = base64Decode(realmEncryptionKeyString);

    final directory = (await getApplicationSupportDirectory()).path;

    final realmConfig = Configuration.local(
      [User.schema, PlaintextMessage.schema],
      path: '$directory/${name}_realm.realm',
      encryptionKey: realmKey,
    );
    return await Realm.open(realmConfig);
  }

  /// Deletes all messages and the user's Realm database.
  // THIS IS ONLY FOR DEBUGGING PURPOSES WHEN VALUES COULD NOT BE STORED CORRECTLY (WHEN DELETING USERS FROM THE SERVER FOR INSTANCE), DO NOT USE IN PRODUCTION
  void deleteAll() async {
    _userRealm?.write(() {
      _userRealm?.deleteAll<User>();
    });
    _userRealm?.close();
    Realm.deleteRealm(_userRealm!.config.path);
  }

  @override
  void dispose() {
    if (_channel != null) {
      _channel?.sink.close();
    }
    _messagesSubscription?.cancel();
    _userRealm?.close();
    super.dispose();
  }
}

@RealmModel()
class _PlaintextMessage {
  @PrimaryKey()
  late String id;
  late String content;
  late bool own;
  late String? receiver;
  late DateTime? sentAt;
}

@RealmModel()
class _User {
  @PrimaryKey()
  late String name;

  late List<_PlaintextMessage> messages;
}
