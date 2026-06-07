// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  /// Call this from the top‑level widget (e.g. inside MyApp.build) to set up listeners.
  static void init(BuildContext context, WidgetRef ref) {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessage(context, message);
    });

    // When the app is opened from a terminated state via a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(context, message);
    });
  }

  static void _handleMessage(BuildContext context, RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      final callId = data['callId'] ?? '';
      final callMode = data['callMode'] ?? 'video'; // 'audio' or 'video'
      // Show accept/decline dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Incoming Call'),
          content: Text('You have an incoming ${callMode == 'audio' ? 'voice' : 'video'} call'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss dialog
                // Decline – simply do nothing (could send decline payload)
              },
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to CallScreen with args
                Navigator.pushNamed(
                  context,
                  '/call',
                  arguments: {'callId': callId, 'type': callMode},
                );
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    }
  }
}
