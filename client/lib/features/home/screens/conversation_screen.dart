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

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
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
                final conversation = chatProvider.conversations
                    .firstWhere((element) => element.name == widget.name);
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
