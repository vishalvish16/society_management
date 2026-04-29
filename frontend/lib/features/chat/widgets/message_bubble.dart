import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Padding(
        padding: EdgeInsets.only(
          left: isMine ? 80 : 12,
          right: isMine ? 12 : 80,
          bottom: 4,
        ),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            '🚫 Message deleted',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: isMine && onDelete != null
          ? () => _showDeleteMenu(context)
          : null,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 60 : 12,
          right: isMine ? 12 : 60,
          bottom: 4,
        ),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF3B82F6),
                backgroundImage: message.sender.profilePhotoUrl != null
                    ? NetworkImage(
                        AppConstants.uploadUrlFromPath(
                                message.sender.profilePhotoUrl) ??
                            '')
                    : null,
                child: message.sender.profilePhotoUrl == null
                    ? Text(
                        message.sender.name.isNotEmpty
                            ? message.sender.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.sender.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  _buildBubble(context),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Text(
                      DateFormat('h:mm a').format(message.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final bg = isMine ? const Color(0xFF3B82F6) : const Color(0xFFF1F5F9);
    final fg = isMine ? Colors.white : const Color(0xFF1E293B);

    Widget content;

    if (message.type == 'VOICE' && message.attachments.isNotEmpty) {
      content = _VoiceBubble(
        attachment: message.attachments.first,
        duration: message.duration,
        isMine: isMine,
      );
    } else if (message.attachments.isNotEmpty) {
      final att = message.attachments.first;
      if (att.isImage) {
        content = _ImageBubble(attachment: att);
      } else {
        content = _DocBubble(attachment: att, isMine: isMine, fg: fg);
      }
    } else {
      content = Text(
        message.body ?? '',
        style: TextStyle(color: fg, fontSize: 14),
      );
    }

    return Container(
      padding: message.type == 'IMAGE'
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: message.type == 'IMAGE' ? Colors.transparent : bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: content,
    );
  }

  void _showDeleteMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      enableDrag: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete message',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image bubble ────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final ChatAttachment attachment;
  const _ImageBubble({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final url = AppConstants.uploadUrlFromPath(attachment.url) ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _showFullImage(context, url),
        child: Image.network(
          url,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 220,
            height: 120,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ── Document bubble ─────────────────────────────────────────────────────────

class _DocBubble extends StatefulWidget {
  final ChatAttachment attachment;
  final bool isMine;
  final Color fg;
  const _DocBubble(
      {required this.attachment, required this.isMine, required this.fg});

  @override
  State<_DocBubble> createState() => _DocBubbleState();
}

class _DocBubbleState extends State<_DocBubble> {
  bool _downloading = false;

  Future<void> _open() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final url = AppConstants.uploadUrlFromPath(widget.attachment.url) ?? '';
      if (kIsWeb) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.attachment.filename}');
        await Dio().download(url, file.path);
        await OpenFilex.open(file.path);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined,
              color: widget.fg, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.attachment.filename,
              style: TextStyle(color: widget.fg, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          _downloading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: widget.fg),
                )
              : Icon(Icons.download_rounded, color: widget.fg, size: 18),
        ],
      ),
    );
  }
}

// ── Voice bubble ────────────────────────────────────────────────────────────

class _VoiceBubble extends StatefulWidget {
  final ChatAttachment attachment;
  final int? duration;
  final bool isMine;
  const _VoiceBubble(
      {required this.attachment, this.duration, required this.isMine});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_player.duration == null) {
        final url = AppConstants.uploadUrlFromPath(widget.attachment.url) ?? '';
        await _player.setUrl(url);
      }
      await _player.play();
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? Colors.white : const Color(0xFF1E293B);
    final total = _total ??
        (widget.duration != null
            ? Duration(seconds: widget.duration!)
            : const Duration(seconds: 0));
    final progress = total.inSeconds > 0
        ? (_pos.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
                color: fg, size: 32),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.toDouble(),
                  backgroundColor: fg.withValues(alpha: 0.2),
                  color: fg,
                  minHeight: 3,
                ),
                const SizedBox(height: 4),
                Text(
                  _playing ? _fmt(_pos) : _fmt(total),
                  style: TextStyle(fontSize: 11, color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
