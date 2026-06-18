// lib/screens/call_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_user_service.dart';

// Provider that streams call logs for the current user
final callHistoryProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('call_logs')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snap) {
        final docs = List<QueryDocumentSnapshot>.from(snap.docs);
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>?)?['startedAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>?)?['startedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending order
        });
        return docs;
      });
});


class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedCallIds = {};

  Future<void> _deleteSelectedCalls() async {
    if (_selectedCallIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Call Logs'),
        content: Text('Are you sure you want to delete ${_selectedCallIds.length} call log(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedCallIds) {
        batch.delete(FirebaseFirestore.instance.collection('call_logs').doc(id));
      }
      await batch.commit();
      setState(() {
        _selectedCallIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected call logs deleted')),
        );
      }
    }
  }

  Future<void> _deleteCall(String callId) async {
    await FirebaseFirestore.instance.collection('call_logs').doc(callId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call log deleted')),
      );
    }
  }

  void _toggleSelection(String callId) {
    setState(() {
      if (_selectedCallIds.contains(callId)) {
        _selectedCallIds.remove(callId);
        if (_selectedCallIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedCallIds.add(callId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncCalls = ref.watch(callHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedCallIds.length} selected')
            : const Text('Call History'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedCallIds.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () {
                    asyncCalls.whenData((calls) {
                      setState(() {
                        for (final doc in calls) {
                          _selectedCallIds.add(doc.id);
                        }
                      });
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Selected',
                  onPressed: _deleteSelectedCalls,
                ),
              ]
            : null,
      ),
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

              final isSelected = _selectedCallIds.contains(callDoc.id);

              return Dismissible(
                key: Key(callDoc.id),
                direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteCall(callDoc.id);
                },
                child: InkWell(
                  onLongPress: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedCallIds.add(callDoc.id);
                    });
                  },
                  onTap: _isSelectionMode
                      ? () => _toggleSelection(callDoc.id)
                      : null,
                  child: CallHistoryTile(
                    callDoc: callDoc,
                    otherParticipant: otherParticipant,
                    isVideo: isVideo,
                    timestamp: timestamp,
                    durationSec: durationSec,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected,
                    onToggleSelection: () => _toggleSelection(callDoc.id),
                  ),
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

class CallHistoryTile extends ConsumerWidget {
  final QueryDocumentSnapshot callDoc;
  final String otherParticipant;
  final bool isVideo;
  final DateTime? timestamp;
  final int durationSec;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const CallHistoryTile({
    super.key,
    required this.callDoc,
    required this.otherParticipant,
    required this.isVideo,
    required this.timestamp,
    required this.durationSec,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
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
          leading: isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    onToggleSelection();
                  },
                )
              : Icon(
                  isVideo ? Icons.videocam : Icons.phone,
                  color: Theme.of(context).colorScheme.primary,
                ),
          title: Text('Call with $name'),
          subtitle: Text(
            '$timeString • ${durationSec}s',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: isSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(Icons.call),
                  color: const Color(0xFF25D366), // WhatsApp green
                  onPressed: () async {
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    if (currentUid == null) return;

                    final callId = 'call_${currentUid.substring(0, 5)}_${otherParticipant.substring(0, 5)}_${DateTime.now().millisecondsSinceEpoch}';

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
                      'receiverId': otherParticipant,
                      'type': isVideo ? 'video' : 'audio',
                      'status': 'ringing',
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      Navigator.pushNamed(
                        context,
                        '/call',
                        arguments: {
                          'callId': callId,
                          'type': isVideo ? 'video' : 'audio',
                          'participants': [currentUid, otherParticipant],
                          'isCaller': true,
                        },
                      );
                    }
                  },
                ),
        );
      },
      loading: () => ListTile(
        leading: isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (val) {
                  onToggleSelection();
                },
              )
            : Icon(isVideo ? Icons.videocam : Icons.phone, color: Colors.grey),
        title: Text('Call with $otherParticipant (Loading...)'),
        subtitle: Text(
          '${timestamp?.toLocal().toString().substring(0, 16) ?? '...'} • ${durationSec}s',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      error: (_, _) => ListTile(
        leading: isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (val) {
                  onToggleSelection();
                },
              )
            : Icon(isVideo ? Icons.videocam : Icons.phone, color: Colors.red),
        title: Text('Call with $otherParticipant'),
        subtitle: Text(
          '${timestamp?.toLocal().toString().substring(0, 16) ?? '...'} • ${durationSec}s',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

