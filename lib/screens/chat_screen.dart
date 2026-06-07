// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_user_service.dart';

// Provider for message stream based on chatId
final chatMessagesProvider = StreamProvider.family<List<QueryDocumentSnapshot>, String>((ref, chatId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// Provider for streaming a single chat document
final chatDocProvider = StreamProvider.family.autoDispose<DocumentSnapshot, String>((ref, chatId) {
  return FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots();
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  late String chatId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Expect chatId passed via arguments
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is String) {
      chatId = args;
    } else {
      // Fallback: use a dummy chatId (should never happen)
      chatId = 'unknown_chat';
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': uid,
          'text': text,
          'type': 'text',
          'timestamp': FieldValue.serverTimestamp(),
        });
    _messageController.clear();
  }

  void _initiateCall(String currentUid, String otherUid, String type) {
    final callId = 'call_${currentUid.substring(0, 5)}_${otherUid.substring(0, 5)}_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pushNamed(
      context,
      '/call',
      arguments: {
        'callId': callId,
        'type': type,
        'participants': [currentUid, otherUid],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(chatId));
    final chatDocAsync = ref.watch(chatDocProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        title: chatDocAsync.when(
          data: (chatDoc) {
            final data = chatDoc.data() as Map<String, dynamic>?;
            final participants = data?['participants'] as List?;
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final otherId = participants?.firstWhere(
              (p) => p != currentUid,
              orElse: () => '',
            ) as String?;

            if (otherId == null || otherId.isEmpty) return const Text('Chat');

            final otherUserAsync = ref.watch(userProfileProvider(otherId));
            return otherUserAsync.when(
              data: (user) => Text(user?.name ?? otherId),
              loading: () => const Text('Loading name...'),
              error: (_, _) => const Text('Chat'),
            );
          },
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Chat'),
        ),
        actions: [
          chatDocAsync.when(
            data: (chatDoc) {
              final data = chatDoc.data() as Map<String, dynamic>?;
              final participants = data?['participants'] as List?;
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final otherId = participants?.firstWhere(
                (p) => p != currentUid,
                orElse: () => '',
              ) as String?;

              if (otherId == null || otherId.isEmpty || currentUid == null) {
                return const SizedBox();
              }

              final otherUserAsync = ref.watch(userProfileProvider(otherId));
              return otherUserAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox();
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone),
                        onPressed: () => _initiateCall(currentUid, user.id, 'audio'),
                        tooltip: 'Voice Call',
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam),
                        onPressed: () => _initiateCall(currentUid, user.id, 'video'),
                        tooltip: 'Video Call',
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              );
            },
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.greenAccent.shade200 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.black : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF25D366)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

