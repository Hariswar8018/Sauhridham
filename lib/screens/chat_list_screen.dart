// lib/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({Key? key}) : super(key: key);

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
              // Show the other participant's name (simple placeholder)
              final otherId = participants.firstWhere((id) => id != FirebaseAuth.instance.currentUser!.uid);
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.greenAccent),
                title: Text('Chat with $otherId'),
                onTap: () => Navigator.pushNamed(context, '/chat', arguments: chatId),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.search),
        onPressed: () {
          // TODO: Implement user search by phone/email/username and create new chat
        },
      ),
    );
  }
}
