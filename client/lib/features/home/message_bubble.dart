import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isOwnMessage;
  final CrossAxisAlignment alignment;
  final bool tail;

  const MessageBubble(
      {super.key,
      required this.text,
      this.isOwnMessage = false,
      this.tail = false,
      this.alignment = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isOwnMessage ? Colors.blue : Colors.grey[300],
          borderRadius: isOwnMessage
              ? BorderRadius.only(
                  topLeft: const Radius.circular(16.0),
                  topRight: const Radius.circular(16.0),
                  bottomLeft: const Radius.circular(16.0),
                  bottomRight: tail
                      ? const Radius.circular(0.0)
                      : const Radius.circular(16.0))
              : BorderRadius.only(
                  topLeft: const Radius.circular(16.0),
                  topRight: const Radius.circular(16.0),
                  bottomRight: const Radius.circular(16.0),
                  bottomLeft: tail
                      ? const Radius.circular(0.0)
                      : const Radius.circular(16.0)),
        ),
        child: Text(text,
            style:
                TextStyle(color: isOwnMessage ? Colors.white : Colors.black)),
      ),
    );
  }
}
