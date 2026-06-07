// lib/screens/call_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_user_service.dart';

// Provider that streams call logs for the current user
final callHistoryProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('call_logs')
      .where('participants', arrayContains: uid)
      .orderBy('startedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs);
});

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCalls = ref.watch(callHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: asyncCalls.when(
        data: (calls) {
          if (calls.isEmpty) {
            return const Center(child: Text('No call history'));
          }
          return ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) {
              final callDoc = calls[index];
              final data = callDoc.data() as Map<String, dynamic>;
              final isVideo = data['type'] == 'video';
              final timestamp = (data['startedAt'] as Timestamp?)?.toDate();
              final durationSec = data['duration'] ?? 0;
              final participants = (data['participants'] as List?) ?? [];
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final otherParticipant = participants.firstWhere(
                (p) => p != currentUid,
                orElse: () => 'Unknown',
              );

              return CallHistoryTile(
                callDoc: callDoc,
                otherParticipant: otherParticipant,
                isVideo: isVideo,
                timestamp: timestamp,
                durationSec: durationSec,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class CallHistoryTile extends ConsumerWidget {
  final QueryDocumentSnapshot callDoc;
  final String otherParticipant;
  final bool isVideo;
  final DateTime? timestamp;
  final int durationSec;

  const CallHistoryTile({
    super.key,
    required this.callDoc,
    required this.otherParticipant,
    required this.isVideo,
    required this.timestamp,
    required this.durationSec,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserAsync = ref.watch(userProfileProvider(otherParticipant));

    return otherUserAsync.when(
      data: (user) {
        final name = user?.name ?? otherParticipant;
        final timeString = timestamp != null
            ? '${timestamp!.day.toString().padLeft(2, '0')}/${timestamp!.month.toString().padLeft(2, '0')}/${timestamp!.year} ${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}'
            : '...';
        return ListTile(
          leading: Icon(
            isVideo ? Icons.videocam : Icons.phone,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text('Call with $name'),
          subtitle: Text(
            '$timeString • ${durationSec}s',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.call),
            color: const Color(0xFF25D366), // WhatsApp green
            onPressed: () {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              Navigator.pushNamed(
                context,
                '/call',
                arguments: {
                  'callId': callDoc.id,
                  'type': isVideo ? 'video' : 'audio',
                  'participants': currentUid != null ? [currentUid, otherParticipant] : [otherParticipant],
                },
              );
            },
          ),
        );
      },
      loading: () => ListTile(
        leading: Icon(isVideo ? Icons.videocam : Icons.phone, color: Colors.grey),
        title: Text('Call with $otherParticipant (Loading...)'),
        subtitle: Text(
          '${timestamp?.toLocal().toString().substring(0, 16) ?? '...'} • ${durationSec}s',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      error: (_, _) => ListTile(
        leading: Icon(isVideo ? Icons.videocam : Icons.phone, color: Colors.red),
        title: Text('Call with $otherParticipant'),
        subtitle: Text(
          '${timestamp?.toLocal().toString().substring(0, 16) ?? '...'} • ${durationSec}s',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

