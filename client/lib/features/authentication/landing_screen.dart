import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:missive/constants/app_colors.dart';

class LandingScreen extends StatelessWidget {
  final String title;
  const LandingScreen({super.key, required this.title});
  final String logoName = 'assets/missive_logo.svg';

  @override
  Widget build(BuildContext context) {
    final Widget logo = SvgPicture.asset(
      logoName,
      width: 200.0,
      height: 200.0,
      colorFilter:
          const ColorFilter.mode(AppColors.contrastWhite, BlendMode.srcIn),
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
