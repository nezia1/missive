import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/chat/providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:missive/features/home/message_bubble.dart';

class ConversationScreen extends StatefulWidget {
  final String name;

  const ConversationScreen({super.key, required this.name});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late ChatProvider _chatProvider;
  late AuthProvider _authProvider;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Future<void> _initialization;
  bool _enableAutoScroll = true;

  void jumpToBottom({animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          return;
        }
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _initialization = initialization();
  }

  Future<void> initialization() async {
    final accessToken = await _authProvider.accessToken;
    if (accessToken == null) {
      throw Exception('User is not logged in');
    }

    _chatProvider.ensureConversationExists(widget
        .name); // it could be the first time somebody is accessing this conversation, so we need to ensure it exists
    jumpToBottom();

    // only allow scrolling on new messages when the user is close to the bottom
    _scrollController.addListener(() {
      double currentScrollPosition = _scrollController.offset;
      double maxScrollPosition = _scrollController.position.maxScrollExtent;

      // Check if close to the bottom, then allow auto-scroll
      if (maxScrollPosition - currentScrollPosition < 100) {
        _enableAutoScroll = true;
      } else {
        _enableAutoScroll = false;
      }
    });
  }

  void handleMessageSent() async {
    await _chatProvider.sendMessage(
        plainText: _controller.text.trim(), receiver: widget.name);
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
      body: FutureBuilder(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
              child: Column(
                children: [
                  Expanded(
                    child: Consumer<ChatProvider>(
                        builder: (context, chatProvider, child) {
                      User conversation;
                      if (_enableAutoScroll) jumpToBottom(animate: true);
                      // This is an absolutely abhorrent way of handling the conversation missing: we should have a better way of handling this, but for now, this will do. I just couldn't figure out why the race condition was happening when the conversation was missing. The issue is that ensureConversationExists doesn't seem to create the conversation properly, so we need to wait for it to be created before we can access it.
                      try {
                        conversation = chatProvider.conversations.firstWhere(
                            (element) => element.name == widget.name);
                      } on StateError catch (_) {
                        return const Center(
                          child: Text('No messages yet'),
                        );
                      }

                      return ListView.builder(
                          controller: _scrollController,
                          itemCount: conversation.messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                conversation.messages[index].content;
                            final isOwnMessage =
                                conversation.messages[index].own;
                            final isTail = index ==
                                    conversation.messages.length - 1 ||
                                conversation.messages[index + 1].own !=
                                    isOwnMessage; // display tail if the next message is from a different sender or if it's the last message
                            final previousTimestamp = index == 0
                                ? null
                                : conversation.messages[index - 1].sentAt;
                            final timestamp =
                                conversation.messages[index].sentAt;
                            final showTimestamp = previousTimestamp == null ||
                                (timestamp != null &&
                                    timestamp
                                            .difference(previousTimestamp)
                                            .inMinutes >
                                        5 // show timestamp if it's the first message or if the previous message was sent more than 5 minutes ago
                                );

                            final showDate = previousTimestamp == null ||
                                (timestamp != null &&
                                    timestamp
                                            .difference(previousTimestamp)
                                            .inDays >
                                        0 // show date if it's the first message or if the previous message was sent more than 1 day ago
                                );
                            return Column(
                              children: [
                                if (timestamp != null && showDate)
                                  Text(DateFormat('dd MMM yyyy HH:mm')
                                      .format(timestamp))
                                else if (timestamp != null && showTimestamp)
                                  Text(DateFormat('HH:mm').format(timestamp)),
                                MessageBubble(
                                    text: message,
                                    isOwnMessage: isOwnMessage,
                                    tail: isTail),
                              ],
                            );
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
            );
          }),
    );
  }
}
