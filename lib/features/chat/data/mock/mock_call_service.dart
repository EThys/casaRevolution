import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/entities/call_session.dart';
import '../../domain/enums/call_status.dart';
import '../../domain/enums/call_type.dart';
import '../../domain/services/call_service.dart';

/// Simule la signalisation d’appel (sonnerie → connecté) sans WebRTC.
class MockCallService implements CallService {
  MockCallService._();
  static final MockCallService instance = MockCallService._();

  final _uuid = const Uuid();
  final _activeCtrl = StreamController<CallSession?>.broadcast();
  CallSession? _active;
  Timer? _connectTimer;

  @override
  Stream<CallSession?> watchActiveCall() => _activeCtrl.stream;

  void _emit() {
    if (!_activeCtrl.isClosed) _activeCtrl.add(_active);
  }

  @override
  Future<CallSession> startOutgoingCall({
    required String conversationId,
    required String peerName,
    required CallType type,
  }) async {
    _connectTimer?.cancel();
    _active = CallSession(
      id: _uuid.v4(),
      conversationId: conversationId,
      peerName: peerName,
      type: type,
      isOutgoing: true,
      status: CallStatus.ringing,
    );
    _emit();

    _connectTimer = Timer(const Duration(seconds: 2), () {
      if (_active == null) return;
      _active!.status = CallStatus.connecting;
      _emit();
      Timer(const Duration(milliseconds: 800), () {
        if (_active == null) return;
        _active!.status = CallStatus.connected;
        _active!.connectedAt = DateTime.now();
        _emit();
      });
    });

    return _active!;
  }

  @override
  Future<void> acceptCall(String sessionId) async {
    if (_active?.id != sessionId) return;
    _active!.status = CallStatus.connected;
    _active!.connectedAt = DateTime.now();
    _emit();
  }

  @override
  Future<void> declineCall(String sessionId) async {
    if (_active?.id != sessionId) return;
    _active!.status = CallStatus.declined;
    _emit();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _active = null;
    _emit();
  }

  @override
  Future<void> endCall(String sessionId) async {
    if (_active?.id != sessionId) return;
    _connectTimer?.cancel();
    _active!.status = CallStatus.ended;
    _emit();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _active = null;
    _emit();
  }

  @override
  Future<void> toggleMute(String sessionId, bool muted) async {
    // Réservé WebRTC
  }

  @override
  Future<void> toggleCamera(String sessionId, bool enabled) async {
    // Réservé WebRTC
  }

  void dispose() {
    _connectTimer?.cancel();
    _activeCtrl.close();
  }
}
