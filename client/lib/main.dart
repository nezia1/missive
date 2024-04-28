// external packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'package:missive/constants/app_colors.dart';

void main() => runApp(Missive());

class Missive extends StatelessWidget {
  Missive({super.key});

  final AuthProvider _authProvider = AuthProvider(
      httpClient: dio, secureStorage: const FlutterSecureStorage());
  final SignalProvider _signalProvider = SignalProvider();
  static const title = 'Missive';

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => _authProvider),
          ChangeNotifierProvider(create: (_) => _signalProvider),
          ChangeNotifierProxyProvider2<AuthProvider, SignalProvider,
                  ChatProvider>(
              create: (BuildContext context) => ChatProvider
                  .empty(), // Empty constructor for ChangeNotifierProxyProvider's create method (since we depend on the other providers to be initialized first, and create requires a pure function that doesn't depend on other providers)
              update: (BuildContext context, authProvider, signalProvider,
                  chatProvider) {
                if (chatProvider == null) {
                  throw Exception(
                      'ChatProvider should never be null in update');
                }

                if (chatProvider.needsUpdate()) {
                  chatProvider.update(
                      url: const String.fromEnvironment('WEBSOCKET_URL',
                          defaultValue: 'ws://localhost:8080'),
                      authProvider: authProvider,
                      signalProvider: signalProvider);
                }

                return chatProvider;
              }),
        ],
        child: MaterialApp.router(
          title: title,
          theme: _buildAppTheme(),
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

ThemeData _buildAppTheme() {
  final palette = PurpleDream();
  final ThemeData base = ThemeData.dark();

  return base.copyWith(
    brightness: Brightness.dark,
    textTheme: GoogleFonts.rubikTextTheme(base.textTheme).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    scaffoldBackgroundColor: palette.background,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.primary,
      onPrimary: palette.textPrimary,
      secondary: palette.secondary,
      onSecondary: palette.textSecondary,
      error: palette.error,
      background: palette.background,
      onBackground: palette.textSecondary,
      surface: palette.secondary,
      onSurface: palette.textPrimary,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ), // Lighter border),
        ),
        padding: MaterialStateProperty.all<EdgeInsets>(
            const EdgeInsets.symmetric(vertical: 25.0)),
        backgroundColor: MaterialStateProperty.all<Color>(palette.accent),
        foregroundColor: MaterialStateProperty.all<Color>(palette.textPrimary),
        elevation:
            MaterialStateProperty.all(8.0), // Raised elevation for a 3D effect
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.secondary, // Background color for the text field
      contentPadding: const EdgeInsets.symmetric(
          vertical: 15.0, horizontal: 20.0), // Padding inside the text field
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0), // Fully rounded corners
        borderSide: BorderSide.none, // No border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(
            color: palette.accent.withOpacity(0.5),
            width: 1.0), // Slightly visible border when enabled
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(
            color: palette.accent,
            width: 2.0), // More visible border when focused
      ),
      hintStyle:
          TextStyle(color: palette.textSecondary), // Style for the hint text
      labelStyle: TextStyle(
          color: palette
              .textPrimary), // Style for the label when the focus is in the text field
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide:
            BorderSide(color: palette.error, width: 1.0), // Error state border
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(
            color: palette.error, width: 2.0), // Focused error state border
      ),
      // You can also add errorStyle, prefixStyle, suffixStyle as needed.
    ),
  );
}
