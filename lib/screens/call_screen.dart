



// lib/screens/call_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/call_log_service.dart';

// Zego credentials
const int zegoAppId = 1234567890; // TODO: set actual AppID

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  late final String _callId;
  late final String _callMode;
  late final List<String> _participants;
  late final Future<Map<String, dynamic>> _callInfoFuture;
  final CallLogService _logService = CallLogService();
  final DateTime _startTime = DateTime.now();

  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)!.settings.arguments as Map?;
      _callId = args?['callId'] ?? 'test_call_room';
      _callMode = args?['type'] ?? 'video';
      
      final participantsList = args?['participants'] as List?;
      if (participantsList != null) {
        _participants = participantsList.map((e) => e.toString()).toList();
      } else {
        _participants = [FirebaseAuth.instance.currentUser?.uid ?? 'guest'];
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      _callInfoFuture = _fetchZegoTokenAndAppId(currentUserId);
      _isInit = false;
    }
  }

  Future<Map<String, dynamic>> _fetchZegoTokenAndAppId(String userId) async {
    final url = Uri.parse('https://sauhridham-production.up.railway.app/api/token?userID=$userId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'token': data['token'] as String,
        'appId': data['appId'] ?? data['appID'],
      };
    } else {
      String errMsg = 'Status ${response.statusCode}';
      try {
        final errData = jsonDecode(response.body);
        if (errData['error'] != null) {
          errMsg = errData['error'];
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  @override
  void dispose() {
    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime).inSeconds;
    _logService.createCallLog(
      callId: _callId,
      participants: _participants,
      type: _callMode,
      startedAt: _startTime,
      endedAt: endTime,
      duration: duration,
    );
    super.dispose();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A), // WhatsApp dark background
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'End-to-end encrypted',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              _callMode == 'audio' ? 'Voice Call' : 'Video Call',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Room ID: $_callId',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade800.withAlpha(51), // 20% opacity
                border: Border.all(color: Colors.teal.shade600, width: 2),
              ),
              child: Center(
                child: Icon(
                  _callMode == 'audio' ? Icons.person : Icons.videocam,
                  size: 64,
                  color: Colors.teal.shade300,
                ),
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: FloatingActionButton(
                backgroundColor: Colors.redAccent,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Icon(Icons.call_end, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(Object error) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                Icons.error_outline,
                color: Colors.redAccent.shade200,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connection Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We couldn\'t start the call because the server returned an error:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Text(
                  error.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callConfig = _callMode == 'audio'
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    return FutureBuilder<Map<String, dynamic>>(
      future: _callInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error!);
        }

        final data = snapshot.data!;
        final token = data['token'] as String;
        final appId = data['appId'] as int? ?? zegoAppId;

        return ZegoUIKitPrebuiltCall(
          appID: appId,
          token: token,
          userID: FirebaseAuth.instance.currentUser?.uid ?? '1234565',
          userName: FirebaseAuth.instance.currentUser?.email ?? 'Guest',
          callID: _callId,
          config: callConfig,
        );
      },
    );
  }
}
