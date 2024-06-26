import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:logging/logging.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:realm/realm.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:missive/common/http.dart';
import 'package:uuid/uuid.dart' as uuid_generator;

import 'package:missive/features/chat/models/conversation.dart';
import 'package:missive/features/chat/models/pending_messages.dart';

/// Provides chat-related functionalities, handling messaging operations, WebSocket connections,
/// and encrypted local storage in a Realm database.
///
/// This provider is responsible for:
/// - Managing WebSocket connections to receive and send messages.
/// - When receiving and sending messages, takes care of encrypting and decrypting messages using the [SignalProvider].
/// - Storing messages locally in a Realm database for persistent storage.
///
/// It relies on [AuthProvider] for authentication details and [SignalProvider] for encryption.
class ChatProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  String? _url;
  AuthProvider? _authProvider;
  SignalProvider? _signalProvider;
  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;
  Realm? _userRealm;
  StreamSubscription? _messagesSubscription;
  final Logger _logger = Logger('ChatProvider');
  bool _disposed = false;

  Timer? _reconnectionTimer;
  bool _connected = false;
  bool _isConnecting = false;
  int _reconnectionAttempts = 0;

  /// Whether or not the provider is connected to the WebSocket server. Used to update the UI based on the connection status.
  get connected => _connected;

  ChatProvider(
      {String? url, AuthProvider? authProvider, SignalProvider? signalProvider})
      : _url = url,
        _authProvider = authProvider,
        _signalProvider = signalProvider;

  // Empty constructor for ChangeNotifierProxyProvider's create method
  ChatProvider.empty() : this();

  /// Resets the provider to its initial state. This method is used when the user logs out.
  ///
  /// It clears the WebSocket connection, the URL, and the providers. It also notifies the listeners to update the UI.
  ///
  /// ## Usage
  /// ```dart
  /// provider.reset();
  /// ```
  void reset() {
    _url = null;
    _authProvider = null;
    _signalProvider = null;
    notifyListeners();
  }

  /// Updates the provider with new values. This method is used when the user logs in, as we cannot initialize a provider in ProxyProvider with the user's data, and have to do it after the user logs in.
  ///
  /// ## Parameters
  /// - [url]: The WebSocket server URL.
  /// - [authProvider]: The authentication provider.
  /// - [signalProvider]: The encryption (Signal protocol) provider.
  ///
  /// ## Usage
  /// ```dart
  /// provider.update(url: 'ws://example.com', authProvider: authProvider, signalProvider: signalProvider);
  /// ```
  void update(
      {required String url,
      required AuthProvider authProvider,
      required SignalProvider signalProvider}) {
    _url = url;
    _authProvider = authProvider;
    _signalProvider = signalProvider;
  }

  /// Checks if the provider needs to be updated. This method is used to determine if the provider is fully initialized, so we don't update it multiple times.
  ///
  /// ## Returns
  /// - `true` if the provider is not fully initialized.
  /// - `false` if all required properties (`_url`, `_authProvider`, `_signalProvider`) are set.
  ///
  /// ## Usage
  /// ```dart
  /// bool updateNeeded = provider.needsUpdate();
  /// ```
  bool needsUpdate() =>
      _url == null || _authProvider == null || _signalProvider == null;

  /// Connects to the WebSocket server and listens for incoming messages.
  ///
  /// When the WebSocket connection is established, the provider listens for incoming messages. If the message is a status update, it updates the corresponding message status accordingly. If the message is a new message, it decrypts the message using [SignalProvider] and stores it locally in the user's Realm database as a [PlaintextMessage].
  ///
  /// ## Throws
  /// - [InitializationError] if the provider is not fully initialized (`_url`, `_authProvider`, `_signalProvider`).
  ///
  /// ## Usage
  /// ```dart
  /// await provider.connect();
  /// ```
  Future<void> connect() async {
    if (_url == null || _authProvider == null || _signalProvider == null) {
      throw InitializationError('ChatProvider is not fully initialized');
    }

    if (_isConnecting) return;

    _isConnecting = true;

    try {
      final ws = await WebSocket.connect(
        _url!,
        headers: {
          HttpHeaders.authorizationHeader:
              'Bearer ${await _authProvider!.accessToken}'
        },
      );

      _channel = IOWebSocketChannel(ws);
      _logger.log(Level.FINE, 'Connected to $_url');
      _connected = true;
      _sendPendingMessages();

      // If reconnection attempts have been made, fetch pending messages as there could have been messages sent while disconnected, and reset the attempts
      if (_reconnectionAttempts > 0) {
        fetchPendingMessages();
        fetchMessageStatuses();
        _reconnectionAttempts = 0;
        notifyListeners();
      }

      _channel!.stream.listen(
        (message) async {
          await _handleMessage(message);
        },
        onDone: _handleConnectionClosed,
        onError: (error) =>
            _logger.log(Level.SEVERE, 'WebSocket Error: $error'),
      );
    } catch (e) {
      _logger.log(Level.SEVERE, 'Failed to connect: $e');
      _connected = false;
      _scheduleReconnection();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleConnectionClosed() {
    _logger.log(Level.WARNING, 'WebSocket connection closed.');
    _channel = null;
    _scheduleReconnection();
  }

  void _scheduleReconnection() {
    if (_disposed) return;
    if (_reconnectionTimer != null && _reconnectionTimer!.isActive) return;

    _reconnectionAttempts++;
    final delay = min(_reconnectionAttempts * 2,
        30); // take more and more time to reconnect after each failed attempt (max 30s)
    _reconnectionTimer = Timer(Duration(seconds: delay), () {
      _logger.log(Level.INFO,
          'Attempting to reconnect... (Attempt $_reconnectionAttempts)');
      connect();
    });
  }

  Future<void> _handleMessage(String message) async {
    final messageJson = jsonDecode(message);
    // check if message is a status update
    if (messageJson['state'] != null) {
      Status messageStatus;
      switch (messageJson['state'].toString().toLowerCase()) {
        case 'sent':
          messageStatus = Status.sent;
          break;
        case 'received':
          messageStatus = Status.received;
          break;
        case 'read':
          messageStatus = Status.read;
          break;
        default:
          messageStatus = Status.error;
          break;
      }
      _logger.log(Level.FINE, 'Updating message status: $message');
      _updateMessageStatus(messageJson['messageId'], messageStatus);
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
      var user = realm.find<Conversation>(messageJson['sender']);

      user ??= realm.add(Conversation(messageJson['sender']));

      user.messages.add(PlaintextMessage(
          messageJson['id'], plainText, false, DateTime.now()));
    });
  }

  /// Sends an encrypted message to the server and stores it locally in the user's Realm database.
  ///
  /// This method takes a plaintext message and a receiver's identifier, encrypts the message using
  /// the [SignalProvider], and then performs two main actions:
  /// 1. Sends the encrypted message to the server.
  /// 2. Stores the encrypted message locally in the Realm database for persistence.
  ///
  /// ## Parameters
  /// - [plainText]: The text of the message that needs to be sent. This should not be empty.
  /// - [receiver]: The identifier of the recipient who will receive the message.
  ///
  /// ## Throws
  /// - [InitializationError] if the [SignalProvider] has not been initialized prior to calling this method,
  ///
  /// ## Usage
  /// ```dart
  ///   await sendMessage(plainText: 'Hello, World!', receiver: 'alice');
  /// ```
  ///
  /// Ensure that [SignalProvider] is properly initialized before invoking this method.
  Future<void> sendMessage(
      {required String plainText, required String receiver}) async {
    final uuid = const uuid_generator.Uuid().v6();
    if (_signalProvider == null) {
      throw InitializationError('SignalProvider is not initialized');
    }
    final message =
        await _signalProvider!.encrypt(name: receiver, message: plainText);

    final messageJson = jsonEncode({
      'id': uuid,
      'content': base64Encode(message.serialize()),
      'receiver': receiver,
    });

    // store with Realm
    final realm = await _getUserRealm();
    final name = (await _authProvider?.user)?.name;

    if (name == null) {
      throw InitializationError('User is not logged in');
    }

    realm.write(() {
      var user = realm.find<Conversation>(receiver);

      user ??= realm.add(Conversation(receiver));

      user.messages.add(PlaintextMessage(
        uuid,
        plainText,
        true,
        DateTime.now(),
        statusString: Status.pending.toShortString(),
      ));
    });

    if (!_connected) {
      _storePendingMessage(uuid, message, receiver);
      return;
    }
    // send message over WebSocket
    _channel?.sink.add(messageJson);
  }

  /// Stores a message in the user's Realm database as a pending message.
  /// This method is used when the WebSocket connection is not established, and the message cannot be sent immediately.
  /// The message is stored locally in the Realm database and will be sent when the connection is re-established.
  /// ## Parameters
  /// - [uuid]: The unique identifier of the message.
  /// - [message]: The encrypted message to be sent.
  /// - [receiver]: The name of the recipient of the message.
  /// ## Usage
  /// ```dart
  /// _storePendingMessage('12345', message, 'alice');
  /// ```
  /// This method is used internally by the provider and should not be called directly.
  void _storePendingMessage(
      String uuid, CiphertextMessage message, String receiver) {
    final realm = _userRealm;
    if (realm == null) {
      throw InitializationError('User Realm is not initialized');
    }

    realm.write(() {
      final pendingMessages = realm.find<PendingMessages>('pending_messages');
      if (pendingMessages == null) {
        realm.add(PendingMessages('pending_messages', messages: [
          PendingMessage(uuid, base64Encode(message.serialize()), receiver)
        ]));
        return;
      }
      pendingMessages.messages.add(
          PendingMessage(uuid, base64Encode(message.serialize()), receiver));
    });
  }

  /// Send all pending messages stored in the user's Realm database.
  /// This method is used when the WebSocket connection is re-established, and all pending messages are sent to the server.
  /// The messages are removed from the local Realm database after they are sent.
  /// ## Usage
  /// ```dart
  /// await _sendPendingMessages();
  /// ```
  void _sendPendingMessages() {
    final realm = _userRealm;
    if (realm == null) {
      throw InitializationError('User Realm is not initialized');
    }

    final pendingMessages = realm.find<PendingMessages>('pending_messages');
    if (pendingMessages == null) return;

    for (final message in pendingMessages.messages) {
      final messageJson = jsonEncode({
        'id': message.id,
        'content': message.ciphertextMessage,
        'receiver': message.receiver,
      });
      _channel?.sink.add(messageJson);
      _logger.log(Level.FINE, 'Sent pending message: $messageJson');
    }

    realm.write(() {
      realm.delete(pendingMessages);
    });
  }

  /// Notifies the server that a message has been read, and updates the local Realm database accordingly.
  ///
  /// ## Parameters
  /// - [messageId]: The unique identifier of the message that has been read.
  /// - [receiver]: The user we want to notify.
  ///
  /// ## Usage
  /// ```dart
  /// provider.notifyRead(messageId: '12345', receiver: 'bob');
  /// ```
  void notifyRead(String messageId, String receiver) {
    _logger.log(
        Level.FINE, 'Notifying server that message $messageId was read');
    _updateMessageStatus(messageId, Status.read);
    _channel?.sink.add(
        jsonEncode({'id': messageId, 'state': 'read', 'receiver': receiver}));
  }

  /// Updates the status of a message in the local Realm database.
  ///
  /// ## Parameters
  /// - [messageId]: The unique identifier of the message that needs to be updated.
  /// - [status]: The new status of the message.
  ///
  /// ## Usage
  /// ```dart
  /// _updateMessageStatus('12345', Status.sent);
  /// ```
  void _updateMessageStatus(String messageId, Status status) {
    final realm = _userRealm;
    if (realm == null) {
      throw InitializationError('User Realm is not initialized');
    }

    realm.write(() {
      final message = realm.find<PlaintextMessage>(messageId);
      message?.status = status;
    });
  }

  /// Sets up the user's Realm database and listens for changes.
  ///
  /// This method initializes the Realm database for storing conversations and messages. It also sets up a listener to update the UI when new messages arrive.
  ///
  /// ## Throws
  /// - [InitializationError] if the Realm database is not initialized properly.
  ///
  /// ## Usage
  /// ```dart
  /// provider.setupUserRealm();
  /// ```
  Future<void> setupUserRealm() async {
    _logger.log(Level.FINE, 'Setting up user Realm...');
    _userRealm = await _getUserRealm();
    if (_userRealm == null) {
      throw InitializationError('User Realm is not initialized');
    }
    // initialize messages
    final conversations = _userRealm!.all<Conversation>();
    _conversations = conversations.toList();
    _conversations.sort(
        (b, a) => a.messages.last.sentAt.compareTo(b.messages.last.sentAt));

    notifyListeners(); // update UI with initial data load

    // listen for new messages
    var messages = _userRealm!.all<PlaintextMessage>();
    _messagesSubscription = messages.changes.listen((_) {
      _conversations = conversations.toList();
      _conversations.sort(
          (b, a) => a.messages.last.sentAt.compareTo(b.messages.last.sentAt));
      notifyListeners(); // update UI on new messages
    });
  }

  void ensureConversationExists(String name) {
    _userRealm?.write(() {
      if (_userRealm?.find<Conversation>(name) == null) {
        _userRealm?.add(Conversation(name));
      }
    });
  }

  /// Fetches pending messages from the server and stores them locally in the user's Realm database.
  ///
  /// This method retrieves any messages that have been sent to the user but not yet fetched, decrypts them, and stores them locally.
  ///
  /// ## Throws
  /// - `Exception` if the user is not logged in or the [AuthProvider] is not initialized.
  ///
  /// ## Usage
  /// ```dart
  /// await provider.fetchPendingMessages();
  /// ```
  void fetchPendingMessages() async {
    // get pending messages from server
    final name = (await _authProvider?.user)?.name;
    final accessToken = await _authProvider?.accessToken;

    if (name == null || accessToken == null) {
      throw Exception('User is not logged in');
    }

    Response response;
    try {
      // get messages from server
      response = await dio.get('/users/$name/messages',
          options: Options(headers: {
            HttpHeaders.authorizationHeader: 'Bearer $accessToken'
          }));
    } on DioException catch (e) {
      _logger.log(Level.WARNING, 'Error fetching pending messages: $e');
      _connected = false;
      notifyListeners();
      return;
    }

    final messages = response.data['data']['messages'];

    // decrypt and store messages
    for (final message in messages) {
      CiphertextMessage cipherMessage;
      final sender = message['sender']['name'];
      try {
        await _signalProvider?.buildSession(
            name: name, accessToken: accessToken);
        cipherMessage =
            SignalMessage.fromSerialized(base64Decode(message['content']));
      } catch (_) {
        cipherMessage = PreKeySignalMessage(base64Decode(message['content']));
      }
      final plainText = await _signalProvider!
          .decrypt(cipherMessage, SignalProtocolAddress(sender, 1));
      _userRealm?.write(() {
        var user = _userRealm?.find<Conversation>(sender);

        user ??= _userRealm?.add(Conversation(sender));

        user?.messages.add(PlaintextMessage(
          message['id'],
          plainText,
          false,
          DateTime.parse(message['sentAt']),
        ));
      });
    }
  }

  /// Fetches the latest message statuses from the server and updates the local Realm database accordingly.
  ///
  /// This method queries the server for the latest statuses of messages (like 'read', 'received') and updates these statuses in the local database.
  ///
  /// ## Throws
  /// - `Exception` if the user is not logged in or the [AuthProvider] is not initialized.
  ///
  /// ## Usage
  /// ```dart
  /// await provider.fetchMessageStatuses();
  /// ```
  Future<void> fetchMessageStatuses() async {
    final name = (await _authProvider?.user)?.name;
    final accessToken = await _authProvider?.accessToken;
    if (name == null || accessToken == null) {
      throw Exception('User is not logged in');
    }
    Response response;
    dynamic statuses;
    try {
      response = await dio.get('/users/$name/messages/status',
          options: Options(headers: {
            HttpHeaders.authorizationHeader: 'Bearer $accessToken'
          }));
      statuses = response.data['data']['statuses'];
    } on DioException catch (e) {
      _logger.log(Level.WARNING, 'Error fetching message statuses: $e');
      _connected = false;
      notifyListeners();
      return;
    }

    for (final status in statuses) {
      _logger.log(Level.FINE, 'Updating message status: $status');
      final message = _userRealm?.find<PlaintextMessage>(status['messageId']);
      if (message != null) {
        _updateMessageStatus(
            status['messageId'],
            Status.values.firstWhere((element) =>
                element.toShortString() ==
                status['state'].toString().toLowerCase()));
      }
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
    var realmEncryptionKeyString = await secureStorage
        .read(key: '${name}_realmEncryptionKey')
        .catchError((e) {
      _logger.log(Level.WARNING, 'Realm error: $e');
      return null;
    });
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

    final realmConfig = Configuration.local([
      Conversation.schema,
      PlaintextMessage.schema,
      PendingMessages.schema,
      PendingMessage.schema
    ],
        path: '$directory/${name}_realm.realm',
        encryptionKey: realmKey,
        schemaVersion: 2);
    return await Realm.open(realmConfig);
  }

  /// Deletes all messages and the user's Realm database.
  ///
  /// This method is primarily for debugging purposes when values could not be stored correctly (e.g., when deleting users from the server), and should not be used in production.
  ///
  /// ## Usage
  /// ```dart
  /// provider.deleteAll();
  /// ```
  void deleteAll() async {
    _userRealm?.write(() {
      _userRealm?.deleteAll<Conversation>();
    });
    _userRealm?.close();
    Realm.deleteRealm(_userRealm!.config.path);
    final name = (await _authProvider?.user)?.name;
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: '${name}_realmEncryptionKey');
  }

  /// Disposes the provider and closes the WebSocket connection.
  /// This method is called when the user logs out, as we need to clean up the resources to avoid sessions getting mixed up.
  ///
  /// ## Usage
  /// ```dart
  /// provider.dispose();
  /// ```
  @override
  void dispose() {
    _disposed = true;
    _logger.log(Level.FINE, 'Disposing... (this should happen after log out)');
    if (_channel != null) {
      _channel?.sink.close();
    }
    _messagesSubscription?.cancel();
    _userRealm?.close();
    super.dispose();
  }
}

/// Represents an initialization error. Used when the [ChatProvider] is not fully initialized, and an operation is attempted.
class InitializationError extends Error {
  final String message;

  InitializationError(this.message);

  @override
  String toString() => 'InitializationError: $message';
}
