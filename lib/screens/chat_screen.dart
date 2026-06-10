// lib/screens/chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _isUploading = false;
  bool _isDeletingChat = false;

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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    
    // Clear controller immediately for WhatsApp feel
    _messageController.clear();

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
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await ref.putFile(file);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'senderId': uid,
            'text': '',
            'imageUrl': imageUrl,
            'type': 'image',
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete entire chat?'),
        content: const Text('This will delete all messages and remove the chat from your app. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeletingChat = true;
    });

    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages');

      final messagesSnapshot = await messagesRef.get();
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete main chat document
      await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();

      if (mounted) {
        Navigator.pop(context); // Go back to ChatListScreen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingChat = false;
        });
      }
    }
  }

  Future<void> _initiateCall(String currentUid, String otherUid, String type) async {
    final callId = 'call_${currentUid.substring(0, 5)}_${otherUid.substring(0, 5)}_${DateTime.now().millisecondsSinceEpoch}';

    String callerName = 'Guest';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      if (userDoc.exists) {
        callerName = userDoc.data()?['name'] ?? userDoc.data()?['username'] ?? 'User';
      }
    } catch (_) {}

    // Create call signaling document
    await FirebaseFirestore.instance.collection('calls').doc(callId).set({
      'id': callId,
      'callerId': currentUid,
      'callerName': callerName,
      'receiverId': otherUid,
      'type': type,
      'status': 'ringing',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pushNamed(
        context,
        '/call',
        arguments: {
          'callId': callId,
          'type': type,
          'participants': [currentUid, otherUid],
          'isCaller': true,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(chatId));
    final chatDocAsync = ref.watch(chatDocProvider(chatId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5), // WhatsApp styles
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
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
              data: (user) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? otherId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
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
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') {
                _deleteChat();
              }
            },
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Chat'),
              ),
            ],
          ),
        ],
      ),
      body: _isDeletingChat
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)))
          : Column(
              children: [
                Expanded(
                  child: messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900]?.withOpacity(0.8) : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('No messages yet. Send a photo or text!'),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data = messages[index].data() as Map<String, dynamic>;
                          final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                          final type = data['type'] ?? 'text';
                          final text = data['text'] ?? '';
                          final imageUrl = data['imageUrl'] as String?;

                          // Bubble colors matching WhatsApp dark/light theme
                          final bubbleColor = isMe
                              ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
                              : (isDark ? const Color(0xFF202C33) : Colors.white);
                          final textColor = isDark ? Colors.white : Colors.black87;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Delete Message?'),
                                    content: const Text('This will delete this message from the chat history.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogCtx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(dialogCtx);
                                          await FirebaseFirestore.instance
                                              .collection('chats')
                                              .doc(chatId)
                                              .collection('messages')
                                              .doc(messages[index].id)
                                              .delete();
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: type == 'image'
                                    ? const EdgeInsets.all(4)
                                    : const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                                    bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: type == 'image' && imageUrl != null
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: 210,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const SizedBox(
                                                width: 210,
                                                height: 180,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF25D366),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => const SizedBox(
                                                width: 210,
                                                height: 180,
                                                child: Icon(Icons.broken_image, size: 50),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        text,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 15.5,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF25D366))),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
                
                // Uploading loading state
                if (_isUploading)
                  Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)),
                        ),
                        SizedBox(width: 10),
                        Text('Sending photo...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                // Redesigned WhatsApp Style Input container
                Padding(
                  padding: EdgeInsets.only(
                    left: 8.0,
                    right: 8.0,
                    top: 6.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 8.0,
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    keyboardType: TextInputType.multiline,
                                    maxLines: 5,
                                    minLines: 1,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: 'Message',
                                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.photo_library, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  onPressed: _isUploading ? null : _pickAndSendImage,
                                  tooltip: 'Send Photo',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
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
