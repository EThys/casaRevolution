import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/call_session.dart';
import '../../domain/enums/call_status.dart';
import '../../domain/services/call_service.dart';
import '../controllers/call_session_controller.dart';
import '../widgets/call_control_panel.dart';

class AudioCallPage extends StatefulWidget {
  const AudioCallPage({super.key, required this.session});

  final CallSession session;

  @override
  State<AudioCallPage> createState() => _AudioCallPageState();
}

class _AudioCallPageState extends State<AudioCallPage> {
  late final CallSessionController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = CallSessionController(
      context.read<CallService>(),
      widget.session,
    );
    _ctrl.init();
    _ctrl.addListener(_onSessionUpdate);
  }

  void _onSessionUpdate() {
    if (_ctrl.session.status == CallStatus.ended ||
        _ctrl.session.status == CallStatus.declined) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _end() async {
    await _ctrl.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onSessionUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D26),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              children: [
                const SizedBox(height: 48),
                CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFF1976D2).withOpacity(0.3),
                  child: Text(
                    _ctrl.session.peerName.isNotEmpty
                        ? _ctrl.session.peerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _ctrl.session.peerName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _ctrl.statusLabel,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(),
                CallControlPanel(
                  muted: _ctrl.muted,
                  onToggleMute: _ctrl.toggleMute,
                  onEnd: _end,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
