import '../entities/call_session.dart';
import '../enums/call_type.dart';

/// Appels audio / vidéo (mock → WebRTC + tokens API plus tard).
abstract class CallService {
  Stream<CallSession?> watchActiveCall();

  Future<CallSession> startOutgoingCall({
    required String conversationId,
    required String peerName,
    required CallType type,
  });

  Future<void> acceptCall(String sessionId);

  Future<void> declineCall(String sessionId);

  Future<void> endCall(String sessionId);

  Future<void> toggleMute(String sessionId, bool muted);

  Future<void> toggleCamera(String sessionId, bool enabled);
}
