import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/call_session.dart';
import '../../domain/enums/call_status.dart';
import '../../domain/services/call_service.dart';

class CallSessionController extends ChangeNotifier {
  CallSessionController(this._callService, this.session);

  final CallService _callService;
  CallSession session;

  StreamSubscription<CallSession?>? _sub;
  bool muted = false;
  bool cameraEnabled = true;
  Duration elapsed = Duration.zero;
  Timer? _ticker;

  Future<void> init() async {
    _sub = _callService.watchActiveCall().listen((s) {
      if (s == null || s.id != session.id) return;
      session = s;
      if (s.status == CallStatus.connected && _ticker == null) {
        _startTicker();
      }
      notifyListeners();
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (session.connectedAt != null) {
        elapsed = DateTime.now().difference(session.connectedAt!);
        notifyListeners();
      }
    });
  }

  Future<void> endCall() => _callService.endCall(session.id);

  Future<void> toggleMute() async {
    muted = !muted;
    await _callService.toggleMute(session.id, muted);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    cameraEnabled = !cameraEnabled;
    await _callService.toggleCamera(session.id, cameraEnabled);
    notifyListeners();
  }

  String get statusLabel {
    switch (session.status) {
      case CallStatus.ringing:
        return session.isOutgoing ? 'Appel en cours…' : 'Appel entrant…';
      case CallStatus.connecting:
        return 'Connexion…';
      case CallStatus.connected:
        return _formatDuration(elapsed);
      case CallStatus.ended:
        return 'Appel terminé';
      case CallStatus.declined:
        return 'Appel refusé';
      case CallStatus.missed:
        return 'Appel manqué';
    }
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
