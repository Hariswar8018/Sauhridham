// lib/screens/call_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/call_log_service.dart';

// Zego credentials fallback
const int zegoAppId = 1234567890; 

class CallDiagnosticException implements Exception {
  final String message;
  final String? diagnostic;
  final String url;
  final int? statusCode;

  CallDiagnosticException({
    required this.message,
    this.diagnostic,
    required this.url,
    this.statusCode,
  });

  @override
  String toString() {
    return 'CallDiagnosticException: $message';
  }
}

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
  bool _isCaller = false;
  StreamSubscription<DocumentSnapshot>? _callDocSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)!.settings.arguments as Map?;
      _callId = args?['callId'] ?? 'test_call_room';
      _callMode = args?['type'] ?? 'video';
      _isCaller = args?['isCaller'] ?? false;
      
      final participantsList = args?['participants'] as List?;
      if (participantsList != null) {
        _participants = participantsList.map((e) => e.toString()).toList();
      } else {
        _participants = [FirebaseAuth.instance.currentUser?.uid ?? 'guest'];
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      _callInfoFuture = _fetchZegoTokenAndAppId(currentUserId);
      
      _listenToCallStatus();
      _isInit = false;
    }
  }

  void _listenToCallStatus() {
    _callDocSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(_callId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final status = data['status'];
          if (status == 'rejected' && _isCaller) {
            _callDocSubscription?.cancel();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call declined by recipient')),
              );
              Navigator.pop(context);
            }
          } else if (status == 'ended') {
            _callDocSubscription?.cancel();
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }
      }
    });
  }

  Future<Map<String, dynamic>> _fetchZegoTokenAndAppId(String userId) async {
    final url = 'https://sauhridham-production.up.railway.app/api/token?userID=$userId';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'token': data['token'] as String,
          'appId': data['appId'] ?? data['appID'],
        };
      } else {
        String errMsg = 'HTTP Error ${response.statusCode}';
        String? diagMsg;
        try {
          final errData = jsonDecode(response.body);
          errMsg = errData['error'] ?? errMsg;
          diagMsg = errData['diagnostic'];
        } catch (_) {}
        
        throw CallDiagnosticException(
          message: errMsg,
          diagnostic: diagMsg ?? 'The server returned an unsuccessful status code.',
          url: url,
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw CallDiagnosticException(
        message: 'Connection Timeout',
        diagnostic: 'The request to your token server timed out. Please check if your backend server is waking up or under high load.',
        url: url,
      );
    } on SocketException {
      throw CallDiagnosticException(
        message: 'No Network Access',
        diagnostic: 'Could not connect to token server. Please check your internet connection or verify the server host is online.',
        url: url,
      );
    } catch (e) {
      if (e is CallDiagnosticException) rethrow;
      throw CallDiagnosticException(
        message: e.toString(),
        diagnostic: 'An unexpected client-side error occurred when fetching Zego token.',
        url: url,
      );
    }
  }

  @override
  void dispose() {
    _callDocSubscription?.cancel();
    
    // Update call status to ended in Firestore
    FirebaseFirestore.instance
        .collection('calls')
        .doc(_callId)
        .update({'status': 'ended'}).catchError((_) {});

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
                color: Colors.teal.shade800.withValues(alpha: 0.2), 
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
    String title = 'Connection Failed';
    String message = 'We couldn\'t start the call because the server returned an error.';
    String diagnostic = 'Please make sure your server is online and the environment variables are correctly configured.';
    String urlChecked = 'https://sauhridham-production.up.railway.app/api/token';
    String code = 'Unknown';

    if (error is CallDiagnosticException) {
      title = error.message;
      diagnostic = error.diagnostic ?? diagnostic;
      urlChecked = error.url;
      code = error.statusCode != null ? '${error.statusCode}' : 'N/A';
    } else {
      message = error.toString().replaceAll('Exception: ', '');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Beautiful glowing warning icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                diagnostic,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              
              // Diagnostic details box (premium visual card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Slate 800
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIAGNOSTIC LOGS',
                      style: GoogleFonts.outfit(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLogDetail('URL Checked', urlChecked),
                    _buildLogDetail('Status Code', code),
                    _buildLogDetail('Original Error', message),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.grey, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Suggested Actions:',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildSuggestedAction('1. Ensure backend is deployed and active on Railway.'),
                    _buildSuggestedAction('2. Double check ZEGO_APP_ID & ZEGO_SERVER_SECRET environment vars.'),
                    _buildSuggestedAction('3. Test if you have network connectivity to the internet.'),
                  ],
                ),
              ),
              const Spacer(),
              
              // Return button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[800]!, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Go Back to Chat',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedAction(String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        action,
        style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
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
