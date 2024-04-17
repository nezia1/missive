import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AuthProvider _userProvider;
  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<AuthProvider>(context, listen: false);
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
              const SizedBox(height: 20),
              Text(
                  'This is an example of a home screen. This is a proof of concept to showcase the authentication and navigation capabilities of Flutter.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.justify),
              const SizedBox(height: 10),
              Text(
                  'You can find a side bar on the left with a settings and logout button. The settings button will take you to a settings screen, allowing you to change your account settings, and the logout button will send you back to the login screen. The app is built using the following technologies: Flutter, GoRouter and Provider.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.justify),
            ])));
  }
}
