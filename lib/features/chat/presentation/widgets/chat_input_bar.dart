import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

typedef SendTextCallback = Future<void> Function(String text);
typedef SendImageCallback = Future<void> Function(String path);
typedef SendAudioCallback = Future<void> Function(String path, int durationMs);

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendAudio,
    this.enabled = true,
  });

  final SendTextCallback onSendText;
  final SendImageCallback onSendImage;
  final SendAudioCallback onSendAudio;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  static const _primary = Color(0xFF1976D2);
  final _textCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recordStart;

  @override
  void dispose() {
    _textCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!widget.enabled) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) await widget.onSendImage(file.path);
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _recording) return;
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/chat_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
    });
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    final path = await _recorder.stop();
    final start = _recordStart;
    setState(() {
      _recording = false;
      _recordStart = null;
    });
    if (path != null && start != null) {
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (ms > 400) {
        await widget.onSendAudio(path, ms);
      } else if (File(path).existsSync()) {
        await File(path).delete();
      }
    }
  }

  Future<void> _sendText() async {
    final t = _textCtrl.text;
    if (t.trim().isEmpty || !widget.enabled) return;
    _textCtrl.clear();
    await widget.onSendText(t);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.enabled ? _pickImage : null,
                icon: const Icon(Icons.image_outlined, color: _primary),
              ),
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _recording ? Colors.red.shade100 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _recording ? Icons.mic : Icons.mic_none_rounded,
                    color: _recording ? Colors.red : _primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  enabled: widget.enabled && !_recording,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _recording
                        ? 'Relâchez pour envoyer…'
                        : 'Écrire un message…',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendText(),
                ),
              ),
              IconButton(
                onPressed: widget.enabled ? _sendText : null,
                icon: const Icon(Icons.send_rounded, color: _primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
