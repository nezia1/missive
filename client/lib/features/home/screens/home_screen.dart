import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// TODO: wrap in FutureBuilder so we can wait for everything to be initialized properly
class _HomeScreenState extends State<HomeScreen> {
  // late is needed here because AuthProvider requires context and IdentityKeyStore is initialized in initState (the constructor needs to be different whether or not the user just created their account)
  late AuthProvider _userProvider;
  late SignalProvider _signalProvider;
  late SecureStorageIdentityKeyStore identityKeyStore;
  late ChatProvider _chatProvider;
  String _message = '';
  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<AuthProvider>(context, listen: false);
    _signalProvider = Provider.of<SignalProvider>(context, listen: false);
    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getBool('installed') == false) {
        install();
        prefs.setBool('installed', true);
        return;
      }
      // buildSessionTest and encryptAndSendMessage are called here to test the Signal protocol
      _signalProvider.initialize(installing: false);

      _chatProvider = Provider.of<ChatProvider>(context, listen: false);
      connectWebSocket();
    });
  }

  void connectWebSocket() async {
    _chatProvider.connect((await _userProvider.accessToken)!);
  }

  void install() async {
    // TODO: when changing accounts, this should also trigger. But not on log out, in case the user logs back and in again and it's the same account.
    await _signalProvider.initialize(
      installing: true,
      name: (await _userProvider.user)?.name,
      accessToken: await _userProvider.accessToken,
    );
  }

  void handleMessageSent() async {
    await _signalProvider.buildSession(
        name: 'alice', accessToken: (await _userProvider.accessToken)!);
    final cipherText =
        await _signalProvider.encrypt(message: _message, name: 'alice');
    _chatProvider.sendMessage(cipherText, 'alice');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        drawer: Drawer(
          backgroundColor: Theme.of(context).canvasColor,
          child: ListView(
            children: [
              SizedBox(
                height: 70,
                child: DrawerHeader(
                    child: TextButton.icon(
                  label: const Text('Settings'),
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    context.push('/settings');
                  },
                )),
              ),
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
            ],
          ),
        ),
        body: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 80.0, vertical: 20.0),
            child: Column(children: [
              FutureBuilder(
                future: _userProvider.user,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final user = snapshot.data;
                    if (user == null) {
                      return const Text('An unexpected error occurred');
                    }

                    TextStyle? style =
                        Theme.of(context).textTheme.headlineLarge;
                    return Text('Welcome, ${user.name}', style: style);
                  }

                  return const Text('Welcome, user');
                },
              ),
              TextField(
                  decoration: const InputDecoration(
                    labelText: 'Message',
                  ),
                  onChanged: (value) => _message = value),
              ElevatedButton(
                  child: Text('Send message to Alice'),
                  onPressed: handleMessageSent),
              const SizedBox(height: 20),
              StreamBuilder(
                  stream: _chatProvider.channel?.stream,
                  builder: (context, snapshot) {
                    return Text(
                        snapshot.hasData ? snapshot.data : 'No messages yet');
                  })
            ])));
  }
}
