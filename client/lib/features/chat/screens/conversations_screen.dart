import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';

import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// This screen is used to display the list of conversations the user has.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  // late is needed here because AuthProvider requires context and IdentityKeyStore is initialized in initState (the constructor needs to be different whether or not the user just created their account)
  late AuthProvider _userProvider;
  late SignalProvider _signalProvider;
  late SecureStorageIdentityKeyStore identityKeyStore;
  late ChatProvider _chatProvider;
  late Future _initialization;
  final Logger _logger = Logger('ConversationsScreen');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<
      ScaffoldState>(); // needed to show the snackbar above the drawer
  String _version = '';

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<AuthProvider>(context, listen: false);
    _signalProvider = Provider.of<SignalProvider>(context, listen: false);
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _initialization = initialize();
  }

  /// Initializes stores, providers, and fetches pending data. It also installs the app (generates all required keys and upload them) in case it's the first time the user opens the appa.
  Future<void> initialize() async {
    await _initializeSignalAsNeeded();
    await _chatProvider.setupUserRealm();
    try {
      _chatProvider.fetchPendingMessages();
      _chatProvider.fetchMessageStatuses();
    } catch (e) {
      _logger.log(Level.WARNING,
          'Error fetching pending messages: $e (error of type ${e.runtimeType})');
    }
    if (!mounted) return;
    await _chatProvider.connect();
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  Widget _buildBody() {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: double.infinity,
            leading: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(builder: (context) {
                  // this is needed to pass in the context to Scaffold.of(context).openDrawer()
                  return IconButton(
                    icon: const Icon(Icons.menu, size: 25),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                }),
                IconButton(
                    icon: const Icon(Icons.chat, size: 25),
                    onPressed: () {
                      context.push(
                          '/userSearch'); // search for a user and start a conversation
                    }),
              ],
            )),
        drawer: Drawer(
          backgroundColor: Theme.of(context).canvasColor,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                SizedBox(
                  height: 60,
                  child: Center(
                    child:
                        Consumer<AuthProvider>(builder: (context, provider, _) {
                      return FutureBuilder(
                          future: provider.user,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            return GestureDetector(
                                onLongPress: () {
                                  Clipboard.setData(
                                      ClipboardData(text: snapshot.data!.name));
                                  Fluttertoast.showToast(
                                    msg: 'Username copied to clipboard',
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                  );
                                },
                                child: Text(
                                  snapshot.data!.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ));
                          });
                    }),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 70,
                        child: DrawerHeader(
                            child: TextButton.icon(
                                label: const Text('Logout'),
                                icon: const Icon(Icons.logout),
                                onPressed: () {
                                  _userProvider.logout();
                                })),
                      ),
                      if (kDebugMode)
                        SizedBox(
                          height: 70,
                          child: DrawerHeader(
                              child: TextButton.icon(
                                  label:
                                      const Text('Delete all data and logout'),
                                  icon: const Icon(Icons.logout),
                                  onPressed: () {
                                    FlutterSecureStorage storage =
                                        const FlutterSecureStorage();
                                    storage.deleteAll().then(
                                          (value) => _userProvider.logout(),
                                        );
                                  })),
                        ),
                    ],
                  ),
                ),
                Text('Version: $_version')
              ]),
            ),
          ),
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 20),
            child: Text('Conversations',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          Expanded(child: Consumer<ChatProvider>(
            builder: (context, provider, child) {
              return ListView.separated(
                itemCount: provider.conversations.length,
                itemBuilder: (context, index) {
                  final conversation = provider.conversations[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 20),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(conversation.username,
                            style: Theme.of(context).textTheme.headlineSmall),
                        _getTimestampText(conversation.messages.last.sentAt),
                      ],
                    ),
                    subtitle: Text(
                        conversation.messages.isNotEmpty
                            ? conversation.messages.last.content
                            : '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    onTap: () =>
                        context.push('/conversations/${conversation.username}'),
                  );
                },
                separatorBuilder: (context, index) => const Divider(),
              );
            },
          )),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    const String logoName = 'assets/missive_logo.svg';
    final logo = SvgPicture.asset(
      logoName,
      width: 200.0,
      height: 200.0,
      colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onPrimary, BlendMode.srcIn),
    );
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildBody();
          }
          return Container(
            color: Theme.of(context).colorScheme.background,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                logo,
                CircularProgressIndicator(
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary),
                ),
              ],
            ),
          );
        });
  }

  /// Get the right timestamp text widget based on the date difference between the current date and the message's date. This is used to display the timestamp in the conversation list.
  ///
  /// - if the message was sent today, show the time'
  /// - if the message was sent yesterday, show 'Yesterday'
  /// - if the message was sent this week, show the day of the week
  /// - if the message was sent before this week, show the date
  Text _getTimestampText(DateTime sentAt) {
    final Text timestampText;
    final textStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onBackground);
    final differenceInDays = sentAt.difference(DateTime.now()).inDays;

    if (differenceInDays == 0) {
      timestampText = Text(
          DateFormat('HH:mm').format(sentAt.toLocal()).toString(),
          style: textStyle);
    } else if (differenceInDays == 1) {
      timestampText = Text('Yesterday', style: textStyle);
    } else if (differenceInDays <= 7) {
      timestampText = Text(
          DateFormat('EEEE').format(sentAt.toLocal()).toString(),
          style: textStyle);
    } else {
      timestampText = Text(
          DateFormat('dd/MM/yyyy').format(sentAt.toLocal()).toString(),
          style: textStyle);
    }

    return timestampText;
  }

  /// This function initializes the Signal protocol, and installs it if it's the first time the user opens the app.
  Future<void> _initializeSignalAsNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final name = (await _userProvider.user)?.name;

    _logger.log(Level.INFO, 'installed state: ${prefs.getBool('installed')}');
    if (prefs.getBool('installed') == false) {
      await _signalProvider.initialize(
        installing: true,
        name: name!,
        accessToken: await _userProvider.accessToken,
      );
      prefs.setBool('installed', true);
    } else {
      await _signalProvider.initialize(installing: false, name: name!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
