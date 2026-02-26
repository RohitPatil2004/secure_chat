import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../Firebase/Auth provider.dart';
import '../Service_Providers/chat provider.dart';
import '../Model/chat room model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.read<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            const Text('SecureChat'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _showProfile(context, auth),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: chat.getChatRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No conversations yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap + to start a secure chat',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, i) =>
                _RoomTile(room: rooms[i], currentUserId: auth.currentUserId!),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/search'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showProfile(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              child: Text(
                auth.userProfile?.displayName[0].toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(auth.userProfile?.displayName ?? '',
                style: Theme.of(context).textTheme.titleLarge),
            Text(auth.userProfile?.email ?? '',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.lock_rounded, size: 14),
              label: const Text('E2E Encrypted'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoomModel room;
  final String currentUserId;

  const _RoomTile({required this.room, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final otherId = room.otherUserId(currentUserId);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherId).get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name = data?['displayName'] ?? 'Unknown';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final lastMsg = room.lastMessage ?? '';
        final lastAt = room.lastMessageAt;

        return ListTile(
          leading: CircleAvatar(child: Text(initial)),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 10, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(lastMsg,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          trailing: lastAt != null
              ? Text(
                  _formatTime(lastAt),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          onTap: () {
            context.push(
              '/chat/${room.id}/$otherId/${Uri.encodeComponent(name)}',
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return DateFormat.Hm().format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat.E().format(dt);
    } else {
      return DateFormat.MMMd().format(dt);
    }
  }
}