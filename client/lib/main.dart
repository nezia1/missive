// external packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// screens
import 'package:missive/features/home/screens/settings_screen.dart';
import 'package:missive/features/authentication/login_screen.dart';
import 'package:missive/features/home/screens/home_screen.dart';

// providers
import 'package:missive/features/authentication/providers/auth_provider.dart';

void main() => runApp(FlutterPOC());

class FlutterPOC extends StatelessWidget {
  FlutterPOC({super.key});

  final AuthProvider _userProvider = AuthProvider();
  static const title = 'Flutter Auth';

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => _userProvider),
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
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(title: FlutterPOC.title),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(title: FlutterPOC.title),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      )
    ],
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';

      if (!_userProvider.isLoggedIn) return loggingIn ? null : '/login';

      if (loggingIn) {
        if (_router.canPop()) _router.pop();
        return '/';
      }
      return null;
    },
    refreshListenable: _userProvider,
  );
}
