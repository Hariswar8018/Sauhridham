// lib/screens/call_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  const CallHistoryScreen({Key? key}) : super(key: key);

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
              final data = calls[index].data() as Map<String, dynamic>;
              final isVideo = data['type'] == 'video';
              final timestamp = (data['startedAt'] as Timestamp?)?.toDate();
              final durationSec = data['duration'] ?? 0;
              final participants = (data['participants'] as List?) ?? [];
              final otherParticipant = participants.firstWhere(
                (p) => p != FirebaseAuth.instance.currentUser?.uid,
                orElse: () => 'Unknown',
              );
              return ListTile(
                leading: Icon(isVideo ? Icons.videocam : Icons.phone),
                title: Text('Call with $otherParticipant'),
                subtitle: Text(
                  '${timestamp?.toLocal().toString() ?? '...'} • ${durationSec}s',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () {
                    // Re‑initiate call – navigate to CallScreen with same callId
                    Navigator.pushNamed(
                      context,
                      '/call',
                      arguments: {'callId': calls[index].id, 'type': data['type']},
                    );
                  },
                ),
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
