import 'package:flutter/material.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:missive/features/home/message_bubble.dart';

class ConversationScreen extends StatefulWidget {
  final String name;

  ConversationScreen({required this.name});

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<ChatProvider>(builder: (context, chatProvider, child) {
        final conversation = chatProvider.conversations
            .firstWhere((element) => element.name == widget.name);
        return ListView.builder(
            itemCount: conversation.messages.length,
            itemBuilder: (context, index) {
              final message = conversation.messages[index].content;
              final isOwnMessage = conversation.messages[index].own;
              final isTail = index == conversation.messages.length - 1 ||
                  conversation.messages[index + 1].own !=
                      isOwnMessage; // display tail if the next message is from a different sender or if it's the last message
              return MessageBubble(
                  text: message, isOwnMessage: isOwnMessage, tail: isTail);
            });
      }),
    );
  }
}
