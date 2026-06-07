



// lib/screens/call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/call_log_service.dart';

// Zego credentials – replace with your real AppID and AppSign.
const int zegoAppId = 1234567890; // TODO: set actual AppID
const String zegoAppSign = 'YOUR_ZEGO_APP_SIGN';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  late final String _callId;
  late final String _callMode;
  late final List<String> _participants;
  final CallLogService _logService = CallLogService();
  final DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    _callId = args?['callId'] ?? 'test_call_room';
    _callMode = args?['type'] ?? 'video';
    
    final participantsList = args?['participants'] as List?;
    if (participantsList != null) {
      _participants = participantsList.map((e) => e.toString()).toList();
    } else {
      _participants = [FirebaseAuth.instance.currentUser?.uid ?? 'guest'];
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


  @override
  Widget build(BuildContext context) {
    // Determine call configuration based on selected mode
    final callConfig = _callMode == 'audio'
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    return ZegoUIKitPrebuiltCall(
      appID: zegoAppId,
      appSign: zegoAppSign,
      userID: FirebaseAuth.instance.currentUser?.uid ?? '1234565',
      userName: FirebaseAuth.instance.currentUser?.email ?? 'Guest',
      callID: _callId,
      config: callConfig,
    );
  }
}
