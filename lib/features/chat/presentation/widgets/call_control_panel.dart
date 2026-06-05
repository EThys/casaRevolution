import 'package:flutter/material.dart';

class CallControlPanel extends StatelessWidget {
  const CallControlPanel({
    super.key,
    required this.onEnd,
    this.onToggleMute,
    this.onToggleCamera,
    this.muted = false,
    this.cameraEnabled = true,
    this.showCameraToggle = false,
  });

  final VoidCallback onEnd;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleCamera;
  final bool muted;
  final bool cameraEnabled;
  final bool showCameraToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _round(
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: muted ? 'Réactiver' : 'Muet',
            onTap: onToggleMute,
          ),
          if (showCameraToggle)
            _round(
              icon: cameraEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: 'Caméra',
              onTap: onToggleCamera,
            ),
          _round(
            icon: Icons.call_end_rounded,
            label: 'Raccrocher',
            color: Colors.red,
            onTap: onEnd,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _round({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color color = Colors.white24,
    bool large = false,
  }) {
    final size = large ? 64.0 : 52.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: large ? 32 : 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
