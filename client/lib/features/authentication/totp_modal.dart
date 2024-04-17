import 'package:flutter/material.dart';

/// A widget made to handle TOTP authentication. It will display a modal with a text field for the user to input their TOTP, and a submit button. If the TOTP is invalid, it will display an error message.
///
/// [onHandleTotp] is a callback that will be called when the user submits the TOTP. It should return a boolean representing whether the TOTP is valid or not.
class TOTPModal extends StatefulWidget {
  /// Function that will be called when the user submits the TOTP. It should handle the login process,
  /// and return a boolean representing whether the TOTP is valid or not.
  final Future<bool> Function(String) onHandleTotp;

  const TOTPModal({super.key, required this.onHandleTotp});

  @override
  State<TOTPModal> createState() => _TOTPModalState();
}

class _TOTPModalState extends State<TOTPModal> {
  String _totp = '';
  bool _totpInvalid = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
              decoration: const InputDecoration(labelText: 'TOTP'),
              onChanged: (value) => _totp = value),
          ElevatedButton(
              child: const Text('Submit'),
              onPressed: () async {
                // reversing boolean logic to check if it's invalid (because we want to show the error message if it's invalid, not if it's valid)
                final totpInvalid = !await widget.onHandleTotp(_totp);

                setState(() => _totpInvalid = totpInvalid);

                if (!context.mounted) return;

                if (!_totpInvalid) {
                  Navigator.pop(context);
                }
              }),
          if (_totpInvalid) const Text('Invalid TOTP'),
        ],
      ),
    );
  }
}
