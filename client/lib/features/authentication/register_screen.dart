import 'package:flutter/material.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.title});

  final String title;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _name = '';
  String _password = '';
  String _errorMessage = '';

  bool _loggingIn = false;

  Future<void> handleRegister() async {
    setState(() {
      _loggingIn = true;
      _errorMessage = '';
    });

    if (_name.trim() == '' || _password.trim() == '') {
      setState(() {
        _errorMessage = 'Please fill in all fields';
        _loggingIn = false;
      });

      return;
    }

    final registerResult =
        await Provider.of<AuthProvider>(context, listen: false)
            .register(_name, _password);

    switch (registerResult) {
      case AuthenticationTimeoutError():
        setState(() => _errorMessage =
            'The request timed out (server could not be reached)');
      case AuthenticationSuccess():
        break;
      default:
        setState(() => _errorMessage = 'An unexpected error occurred');
        break;
    }

    setState(() => _loggingIn = false);
  }

  void displayErrorSnackBar(String message) {
    final errorSnackBar = SnackBar(
        content: Text('Login failed: $message'),
        action: SnackBarAction(
            label: 'Dismiss',
            onPressed: ScaffoldMessenger.of(context).hideCurrentSnackBar));
    ScaffoldMessenger.of(context).showSnackBar(errorSnackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        bottom: _loggingIn
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4.0),
                child: LinearProgressIndicator())
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 80.0, right: 80.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (value) => _name = value),
              TextField(
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onChanged: (value) => _password = value,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  child: const Text('Register'),
                  onPressed: () async {
                    await handleRegister();
                    if (_errorMessage.isNotEmpty) {
                      displayErrorSnackBar(_errorMessage);
                    }
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
