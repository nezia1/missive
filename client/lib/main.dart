// external packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// screens
import 'package:missive/features/authentication/landing_screen.dart';
import 'package:missive/features/home/screens/settings_screen.dart';
import 'package:missive/features/authentication/login_screen.dart';
import 'package:missive/features/authentication/register_screen.dart';

import 'package:missive/features/home/screens/home_screen.dart';

// providers
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';

// common
import 'package:missive/common/http.dart';

void main() => runApp(Missive());

class Missive extends StatelessWidget {
  Missive({super.key});

  final AuthProvider _authProvider = AuthProvider(httpClient: dio);
  final SignalProvider _signalProvider = SignalProvider();
  static const title = 'Missive';

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => _authProvider),
          ChangeNotifierProvider(create: (_) => _signalProvider),
          // TODO: change this to a non hard coded value
          ChangeNotifierProvider(
              create: (_) =>
                  ChatProvider('wss://missive.nezia.dev', _signalProvider))
        ],
        child: MaterialApp.router(
          title: title,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
            useMaterial3: true,
          ),
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      );

  late final GoRouter _router = GoRouter(
    initialLocation: '/landing',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(title: Missive.title),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(title: Missive.title),
      ),
      GoRoute(
          path: '/register',
          builder: (context, state) =>
              const RegisterScreen(title: Missive.title)),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(title: Missive.title),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      )
    ],
    redirect: (context, state) async {
      final onboarding = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/landing';

      if (!(await _authProvider.isLoggedIn)) {
        // this means we just logged out
        if (!onboarding) return '/landing';
        return onboarding ? null : '/';
      }

      if (onboarding) return '/';

      return null;
    },
    refreshListenable: _authProvider,
  );
}
