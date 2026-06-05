import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/enums/chat_message_type.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  static const _primary = Color(0xFF1976D2);
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final path = widget.message.mediaPath;
    if (path == null) return;
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    await _player.play(DeviceFileSource(path));
    setState(() => _playing = true);
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.message.isMine;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = mine ? _primary : Colors.grey.shade200;
    final fg = mine ? Colors.white : Colors.black87;
    final time = DateFormat('HH:mm').format(widget.message.createdAt);

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: _content(fg),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: mine ? 0 : 16,
            right: mine ? 16 : 0,
            bottom: 4,
          ),
          child: Text(
            time,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _content(Color fg) {
    switch (widget.message.type) {
      case ChatMessageType.text:
      case ChatMessageType.system:
        return Text(
          widget.message.text ?? '',
          style: TextStyle(color: fg, fontSize: 15, height: 1.35),
        );
      case ChatMessageType.image:
        final path = widget.message.mediaPath;
        if (path == null) {
          return Icon(Icons.broken_image, color: fg);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            width: 220,
            fit: BoxFit.cover,
          ),
        );
      case ChatMessageType.audio:
        final ms = widget.message.audioDurationMs ?? 0;
        final sec = (ms / 1000).ceil();
        return InkWell(
          onTap: _toggleAudio,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: fg,
                size: 36,
              ),
              const SizedBox(width: 8),
              Text(
                '${sec}s',
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
    }
  }
}
