// external packages
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// screens
import 'package:missive/features/authentication/landing_screen.dart';
import 'package:missive/features/authentication/login_screen.dart';
import 'package:missive/features/authentication/register_screen.dart';
import 'package:missive/features/chat/screens/conversation_screen.dart';
import 'package:missive/features/chat/screens/user_search_screen.dart';

import 'package:missive/features/chat/screens/conversations_screen.dart';

// providers
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';

// common
import 'package:missive/common/http.dart';
import 'package:missive/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  final AuthProvider authProvider =
      AuthProvider(httpClient: dio, secureStorage: secureStorage);
  await authProvider.initializeLoginState();
  if (kDebugMode) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
          '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
    });
  }
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) await messaging.getAPNSToken();
    await messaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );
  }

  runApp(Missive(
    authProvider: authProvider,
  ));
}

class Missive extends StatelessWidget {
  final AuthProvider authProvider;
  Missive({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => authProvider),
          ChangeNotifierProvider(create: (_) => SignalProvider()),
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

                if (!authProvider.isLoggedIn) {
                  return ChatProvider(
                      url: const String.fromEnvironment('WEBSOCKET_URL',
                          defaultValue: 'ws://localhost:8080'),
                      authProvider: authProvider,
                      signalProvider: signalProvider);
                }

                return chatProvider;
              }),
        ],
        child: MaterialApp.router(
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
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
          path: '/userSearch',
          builder: (context, state) => const UserSearchScreen()),
      GoRoute(
          path: '/conversations/:name',
          pageBuilder: (context, state) {
            final name = state.pathParameters['name']!;
            return CustomTransitionPage(
              child: ConversationScreen(name: name),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 150),
              reverseTransitionDuration: const Duration(milliseconds: 150),
            );
          }),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
    ],
    // Redirect to the appropriate page based on the user's authentication state
    redirect: (context, state) async {
      // Determine if the user is in the onboarding flow (trying to login or register)
      bool onboarding = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/landing';
      if (!authProvider.isLoggedIn) {
        return onboarding ? null : '/landing';
      }

      return onboarding ? '/' : null;
    },
    refreshListenable: authProvider,
  );
}

ThemeData _buildAppTheme({bool dark = true}) {
  final palette = PurpleDream();
  final ThemeData base = dark ? ThemeData.dark() : ThemeData.light();

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
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all<Color>(palette.textPrimary),
        iconColor: MaterialStateProperty.all<Color>(palette.textPrimary),
      ), // Icon color
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
    ),
  );
}
