import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/call_session.dart';
import '../../domain/enums/call_status.dart';
import '../../domain/services/call_service.dart';
import '../controllers/call_session_controller.dart';
import '../widgets/call_control_panel.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({super.key, required this.session});

  final CallSession session;

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  late final CallSessionController _ctrl;
  CameraController? _camera;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _ctrl = CallSessionController(
      context.read<CallService>(),
      widget.session,
    );
    _ctrl.init();
    _ctrl.addListener(_onSessionUpdate);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
    } catch (_) {
      // Caméra indisponible : l’UI d’appel reste utilisable.
    }
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
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && _camera != null && _ctrl.cameraEnabled)
            CameraPreview(_camera!)
          else
            Container(
              color: const Color(0xFF1A1D26),
              alignment: Alignment.center,
              child: Icon(
                Icons.videocam_off_rounded,
                size: 80,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      _ctrl.session.peerName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _ctrl.statusLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    CallControlPanel(
                      muted: _ctrl.muted,
                      cameraEnabled: _ctrl.cameraEnabled,
                      showCameraToggle: true,
                      onToggleMute: _ctrl.toggleMute,
                      onToggleCamera: () async {
                        await _ctrl.toggleCamera();
                        setState(() {});
                      },
                      onEnd: _end,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
