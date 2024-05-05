import 'package:flutter/material.dart';

/// This widget is used to display a message bubble in the chat screen. It can be used to display messages from the sender or from the receiver.
/// ## Parameters
/// - [text] (required): The text to display in the message bubble.
/// - [isOwnMessage] (optional): Whether the message is from the sender or the receiver. Defaults to `false`.
/// note: [isOwnMessage] is used to determine the color and alignment of the message bubble.
/// - [alignment] (optional): The alignment of the message bubble. Defaults to `CrossAxisAlignment.start`.
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
