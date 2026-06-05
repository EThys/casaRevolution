import '../enums/call_status.dart';
import '../enums/call_type.dart';

class CallSession {
  final String id;
  final String conversationId;
  final String peerName;
  final CallType type;
  final bool isOutgoing;
  CallStatus status;
  DateTime startedAt;
  DateTime? connectedAt;

  CallSession({
    required this.id,
    required this.conversationId,
    required this.peerName,
    required this.type,
    required this.isOutgoing,
    this.status = CallStatus.ringing,
    DateTime? startedAt,
    this.connectedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  Duration get duration {
    final end = connectedAt ?? DateTime.now();
    if (status != CallStatus.connected && connectedAt == null) {
      return Duration.zero;
    }
    return end.difference(connectedAt ?? startedAt);
  }
}
