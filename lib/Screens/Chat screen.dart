import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Firebase/Auth provider.dart';
import '../Service_Providers/chat provider.dart';
import '../Model/Message model.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final chat = context.read<ChatProvider>();
    await chat.sendMessage(
      roomId: widget.roomId,
      recipientId: widget.otherUserId,
      text: text,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Row(
              children: [
                Icon(Icons.lock_rounded, size: 10, color: Colors.green),
                const SizedBox(width: 4),
                Text('End-to-end encrypted',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.green, fontSize: 10)),
              ],
            ),
          ],
        ),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Encryption notice banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: scheme.primaryContainer.withOpacity(0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded,
                    size: 12, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Messages are secured with RSA-2048 + AES-256',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.primary),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chat.getMessages(widget.roomId, widget.otherUserId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text('Send your first encrypted message!',
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe =
                        msg.senderId == auth.currentUserId;
                    return _MessageBubble(
                        message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  chat.isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                        )
                      : IconButton.filled(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send_rounded),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = message.type == 'error';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isError
              ? scheme.errorContainer
              : isMe
                  ? scheme.primary
                  : scheme.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isError
                    ? scheme.onErrorContainer
                    : isMe
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded,
                    size: 8,
                    color: isMe
                        ? scheme.onPrimary.withOpacity(0.6)
                        : scheme.outline),
                const SizedBox(width: 4),
                Text(
                  DateFormat.Hm().format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? scheme.onPrimary.withOpacity(0.6)
                        : scheme.outline,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 12,
                    color: scheme.onPrimary.withOpacity(0.6),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}