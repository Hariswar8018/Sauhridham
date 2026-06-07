// lib/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_user_service.dart';

final chatListProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

final lastMessageProvider = StreamProvider.family.autoDispose<QueryDocumentSnapshot?, String>((ref, chatId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChats = ref.watch(chatListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: asyncChats.when(
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(child: Text('No chats yet'));
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final String chatId = chatDoc.id;
              final List participants = data['participants'] as List;
              final currentUid = FirebaseAuth.instance.currentUser!.uid;
              final otherId = participants.firstWhere(
                (id) => id != currentUid,
                orElse: () => '',
              );

              if (otherId.isEmpty) return const SizedBox();

              return ChatListTile(chatId: chatId, otherId: otherId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.search),
        onPressed: () {
          Navigator.pushNamed(context, '/search');
        },
      ),
    );
  }
}

class ChatListTile extends ConsumerWidget {
  final String chatId;
  final String otherId;

  const ChatListTile({
    super.key,
    required this.chatId,
    required this.otherId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserAsync = ref.watch(userProfileProvider(otherId));
    final lastMessageAsync = ref.watch(lastMessageProvider(chatId));

    return otherUserAsync.when(
      data: (user) {
        final name = user?.name ?? otherId;
        final email = user?.email ?? '';
        final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          title: Text(name),
          subtitle: lastMessageAsync.when(
            data: (msgDoc) {
              if (msgDoc == null) {
                return Text(
                  email.isNotEmpty ? email : 'No messages yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                );
              }
              final data = msgDoc.data() as Map<String, dynamic>;
              final text = data['text'] ?? '';
              final senderId = data['senderId'] ?? '';
              final prefix = senderId == FirebaseAuth.instance.currentUser?.uid ? 'You: ' : '';
              return Text(
                '$prefix$text',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              );
            },
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
          trailing: lastMessageAsync.when(
            data: (msgDoc) {
              if (msgDoc == null) return null;
              final data = msgDoc.data() as Map<String, dynamic>;
              final timestamp = data['timestamp'] as Timestamp?;
              if (timestamp == null) return null;
              final date = timestamp.toDate();
              return Text(
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              );
            },
            loading: () => null,
            error: (_, _) => null,
          ),
          onTap: () => Navigator.pushNamed(context, '/chat', arguments: chatId),
        );
      },
      loading: () => ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.grey),
        title: Text('Loading user $otherId...'),
        onTap: () => Navigator.pushNamed(context, '/chat', arguments: chatId),
      ),
      error: (e, _) => ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.red),
        title: Text('User $otherId'),
        onTap: () => Navigator.pushNamed(context, '/chat', arguments: chatId),
      ),
    );
  }
}

