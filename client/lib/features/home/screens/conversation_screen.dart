import 'package:flutter/material.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:provider/provider.dart';
import 'package:missive/features/home/message_bubble.dart';

class ConversationScreen extends StatefulWidget {
  final String name;

  ConversationScreen({required this.name});

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late ChatProvider _chatProvider;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProvider.ensureConversationExists(widget
        .name); // it could be the first time somebody is accessing this conversation, so we need to ensure it exists
  }

  void handleMessageSent() async {
    await _chatProvider.sendMessage(
        plainText: _controller.text, receiver: widget.name);
    setState(() {
      _controller.clear();
    });
    // TODO: scroll to bottom after message sent (and after the ListView gets updated, doesn't work if it's done right after the message is sent since the ListView hasn't updated yet)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                User conversation;
                // This is an absolutely abhorrent way of handling the conversation missing: we should have a better way of handling this, but for now, this will do. I just couldn't figure out why the race condition was happening when the conversation was missing. The issue is that ensureConversationExists doesn't seem to create the conversation properly, so we need to wait for it to be created before we can access it.
                try {
                  conversation = chatProvider.conversations
                      .firstWhere((element) => element.name == widget.name);
                } on StateError catch (_) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                return ListView.builder(
                    controller: _scrollController,
                    itemCount: conversation.messages.length,
                    itemBuilder: (context, index) {
                      final message = conversation.messages[index].content;
                      final isOwnMessage = conversation.messages[index].own;
                      final isTail = index ==
                              conversation.messages.length - 1 ||
                          conversation.messages[index + 1].own !=
                              isOwnMessage; // display tail if the next message is from a different sender or if it's the last message
                      return MessageBubble(
                          text: message,
                          isOwnMessage: isOwnMessage,
                          tail: isTail);
                    });
              }),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    maxLines: 6,
                    minLines: 1,
                    controller: _controller,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    handleMessageSent();
                  },
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
