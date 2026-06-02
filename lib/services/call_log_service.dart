// lib/services/call_log_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CallLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stores a call log document under `call_logs/{callId}`.
  ///
  /// Parameters:
  /// - `callId`: Unique identifier for the call (same as Zego room ID).
  /// - `participants`: List of user UIDs involved in the call.
  /// - `type`: "audio" or "video".
  /// - `startedAt` / `endedAt`: Timestamps for the call.
  /// - `duration`: Call length in seconds.
  Future<void> createCallLog({
    required String callId,
    required List<String> participants,
    required String type,
    required DateTime startedAt,
    required DateTime endedAt,
    required int duration,
  }) async {
    await _db.collection('call_logs').doc(callId).set({
      'participants': participants,
      'type': type,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'duration': duration,
    });
  }
}
