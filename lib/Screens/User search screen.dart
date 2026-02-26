import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Firebase/Auth provider.dart';
import '../Service_Providers/chat provider.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startChat(
      BuildContext context, String userId, String userName) async {
    final chat = context.read<ChatProvider>();
    final roomId = await chat.getOrCreateRoom(userId);
    if (context.mounted) {
      context.go(
          '/chat/$roomId/$userId/${Uri.encodeComponent(userName)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search by email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (_query.length >= 3)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isGreaterThanOrEqualTo: _query)
                    .where('email', isLessThan: '${_query}z')
                    .limit(10)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  final filtered = docs
                      .where((d) => d['uid'] != auth.currentUserId)
                      .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('No users found',
                          style: Theme.of(context).textTheme.bodySmall),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final data =
                          filtered[i].data() as Map<String, dynamic>;
                      final name = data['displayName'] ?? '';
                      final email = data['email'] ?? '';
                      final uid = data['uid'];
                      final initial =
                          name.isNotEmpty ? name[0].toUpperCase() : '?';

                      return ListTile(
                        leading: CircleAvatar(child: Text(initial)),
                        title: Text(name),
                        subtitle: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            const Text('Encrypted',
                                style: TextStyle(fontSize: 11,
                                    color: Colors.green)),
                          ],
                        ),
                        onTap: () => _startChat(context, uid, name),
                      );
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text('Type at least 3 characters to search',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}