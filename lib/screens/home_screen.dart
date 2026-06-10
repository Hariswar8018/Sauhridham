// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_list_screen.dart';
import 'call_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot>? _callSubscription;
  String? _activeIncomingCallId;

  static const List<Widget> _pages = <Widget>[
    ChatListScreen(),
    CallHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _saveFcmToken();
    _listenToIncomingCalls();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> _saveFcmToken() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      // Request permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _listenToIncomingCalls() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final callId = data['id'] ?? doc.id;
        final type = data['type'] ?? 'video';
        final callerName = data['callerName'] ?? 'Someone';
        final callerId = data['callerId'];

        if (_activeIncomingCallId == callId) return;
        _activeIncomingCallId = callId;

        _showIncomingCallDialog(callId, type, callerName, callerId);
      }
    });
  }

  void _showIncomingCallDialog(String callId, String type, String callerName, String callerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('calls').doc(callId).snapshots(),
          builder: (context, snapshot) {
            // If the document changes status or is deleted, auto-dismiss
            if (snapshot.hasData && snapshot.data != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data == null || data['status'] != 'ringing') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(dialogCtx)) {
                    Navigator.pop(dialogCtx);
                  }
                  _activeIncomingCallId = null;
                });
                return const SizedBox();
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0B141A), // Dark elegant background
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF25D366).withOpacity(0.15),
                    ),
                    child: Icon(
                      type == 'audio' ? Icons.phone : Icons.videocam,
                      color: const Color(0xFF25D366),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Incoming Call',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    callerName,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Incoming ${type == 'audio' ? 'Voice' : 'Video'} Call...',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call_end),
                      label: Text('Decline', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (Navigator.canPop(dialogCtx)) {
                          Navigator.pop(dialogCtx);
                        }
                        _activeIncomingCallId = null;
                        await FirebaseFirestore.instance
                            .collection('calls')
                            .doc(callId)
                            .update({'status': 'rejected'});
                      },
                    ),
                    const SizedBox(width: 12),
                    // Accept Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call),
                      label: Text('Accept', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (Navigator.canPop(dialogCtx)) {
                          Navigator.pop(dialogCtx);
                        }
                        _activeIncomingCallId = null;

                        // Accept call signaling in Firestore
                        await FirebaseFirestore.instance
                            .collection('calls')
                            .doc(callId)
                            .update({'status': 'accepted'});

                        // Navigate recipient to CallScreen
                        if (context.mounted) {
                          Navigator.pushNamed(
                            context,
                            '/call',
                            arguments: {
                              'callId': callId,
                              'type': type,
                              'participants': [callerId, FirebaseAuth.instance.currentUser?.uid],
                              'isCaller': false,
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[400],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
