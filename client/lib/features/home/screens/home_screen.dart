import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/encryption/secure_storage_identity_key_store.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // late is needed here because AuthProvider requires context and IdentityKeyStore is initialized in initState (the constructor needs to be different whether or not the user just created their account)
  late AuthProvider _userProvider;
  late SignalProvider _signalProvider;
  late SecureStorageIdentityKeyStore identityKeyStore;
  late ChatProvider _chatProvider;
  late Future _initialization;
  String _message = '';
  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<AuthProvider>(context, listen: false);
    _signalProvider = Provider.of<SignalProvider>(context, listen: false);
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _initialization = initialize();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final name = (await _userProvider.user)?.name;

    print('installed state: ${prefs.getBool('installed')}');
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

    await _chatProvider.connect();
  }

  void handleMessageSent() async {
    await _signalProvider.buildSession(
        name: 'carol', accessToken: (await _userProvider.accessToken)!);
    await _chatProvider.sendMessage(plainText: _message, receiver: 'carol');
  }

  Widget _buildBody() {
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
              Expanded(
                  //TODO: this probably needs its own widget, it's getting too big
                  //TODO: the logic behind that needs to change, it is extremely inefficient to parse every single message every time a new message is sent or received
                  child: ValueListenableBuilder(
                      valueListenable: _chatProvider.messagesListenable,
                      builder: (context, box, _) {
                        return FutureBuilder(
                            future: _chatProvider.getConversations(),
                            builder: (context,
                                AsyncSnapshot<List<Map<String, String>>>
                                    snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (snapshot.hasData) {
                                return ListView.builder(
                                  itemCount: snapshot.data!.length,
                                  itemBuilder: (context, index) {
                                    final conversation = snapshot.data![index];
                                    return ListTile(
                                      title: Text(conversation['username']!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall),
                                      subtitle:
                                          Text(conversation['latestMessage']!),
                                    );
                                  },
                                );
                              }

                              return Text('No conversations yet');
                            });
                      })),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Message',
                ),
                onChanged: (value) => _message = value,
              ),
              ElevatedButton(
                child: Text('Send message to carol'),
                onPressed: handleMessageSent,
              ),
            ])));
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

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }
}
