import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatelessWidget {
  final String title;
  const LandingScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 80.0, right: 80.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Welcome to Missive',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 50.0),
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
          ),
        ),
      ),
    );
  }
}
