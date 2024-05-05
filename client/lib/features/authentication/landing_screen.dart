import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The landing screen for the application. Allows users to register or login, and provides a nice entry point to the application.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  final String logoName = 'assets/missive_logo.svg';

  @override
  Widget build(BuildContext context) {
    final Widget logo = SvgPicture.asset(
      logoName,
      width: 200.0,
      height: 200.0,
      colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onPrimary, BlendMode.srcIn),
    );
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(child: logo),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Register'),
                ),
                const SizedBox(height: 10.0),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Login'),
                )
              ],
            )),
          ],
        ),
      ),
    );
  }
}
