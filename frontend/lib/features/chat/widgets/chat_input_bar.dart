import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../shared/widgets/mention_text_field.dart';

/// Platform-agnostic file wrapper — holds bytes so it works on web & mobile.
class ChatFile {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  const ChatFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
}

typedef OnSendText = void Function(String text);
typedef OnSendFiles = void Function(List<ChatFile> files, String type);
typedef OnSendVoice = void Function(ChatFile audio, int durationSeconds);

class ChatInputBar extends ConsumerStatefulWidget {
  final OnSendText onSendText;
  final OnSendFiles onSendFiles;
  final OnSendVoice onSendVoice;
  final ValueChanged<bool>? onTyping;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendFiles,
    required this.onSendVoice,
    this.onTyping,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
      widget.onTyping?.call(has);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _focus.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _sendText() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _hasText = false);
    widget.onTyping?.call(false);
    widget.onSendText(text);
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    Navigator.pop(context);
    if (kIsWeb) {
      // On web, camera via image_picker opens the browser file/camera dialog
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final mime = _mimeFromName(xfile.name);
      widget.onSendFiles([ChatFile(name: xfile.name, mimeType: mime, bytes: bytes)], 'IMAGE');
    } else {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      widget.onSendFiles(
          [ChatFile(name: xfile.name, mimeType: 'image/jpeg', bytes: bytes)], 'IMAGE');
    }
  }

  // ── Gallery ───────────────────────────────────────────────────────────────

  Future<void> _pickGallery() async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final xfiles = await picker.pickMultiImage(imageQuality: 85);
    if (xfiles.isEmpty) return;
    final files = await Future.wait(xfiles.map((x) async {
      final bytes = await x.readAsBytes();
      return ChatFile(name: x.name, mimeType: _mimeFromName(x.name), bytes: bytes);
    }));
    widget.onSendFiles(files, 'IMAGE');
  }

  // ── Document ──────────────────────────────────────────────────────────────

  Future<void> _pickDocument() async {
    Navigator.pop(context);
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      withData: true, // ensures bytes are loaded on web too
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.map((f) {
      final bytes = f.bytes ?? Uint8List(0);
      final name = f.name;
      return ChatFile(name: name, mimeType: _mimeFromName(name), bytes: bytes);
    }).where((f) => f.bytes.isNotEmpty).toList();

    if (files.isNotEmpty) widget.onSendFiles(files, 'DOCUMENT');
  }

  // ── Video ─────────────────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final name = xfile.name.isNotEmpty ? xfile.name : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    widget.onSendFiles(
        [ChatFile(name: name, mimeType: 'video/mp4', bytes: bytes)], 'DOCUMENT');
  }

  // ── Attach sheet ──────────────────────────────────────────────────────────

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      enableDrag: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: const Color(0xFF3B82F6),
                onTap: _pickCamera,
              ),
              _AttachOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: const Color(0xFF8B5CF6),
                onTap: _pickGallery,
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_rounded,
                label: 'Document',
                color: const Color(0xFFF59E0B),
                onTap: _pickDocument,
              ),
              _AttachOption(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: const Color(0xFF10B981),
                onTap: _pickVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Voice recording (mobile only) ─────────────────────────────────────────

  Future<void> _startRecording() async {
    if (kIsWeb) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        sampleRate: 44100,
      ),
      path: _recordPath!,
    );
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (cancel || path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return;
      final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      widget.onSendVoice(
        ChatFile(name: name, mimeType: 'audio/m4a', bytes: bytes),
        _recordSeconds,
      );
    } catch (_) {}
  }

  String _fmtSec(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── MIME helper ───────────────────────────────────────────────────────────

  String _mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'm4a': 'audio/m4a',
      'mp3': 'audio/mpeg',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _stopRecording(cancel: true),
            ),
            const Icon(Icons.mic, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Text(
              'Recording ${_fmtSec(_recordSeconds)}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
              onPressed: () => _stopRecording(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B)),
              onPressed: _showAttachSheet,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: MentionTextField(
                  controller: _ctrl,
                  hintText: 'Type a message… use @ to mention',
                  maxLines: 6,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message… use @ to mention',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _hasText
                ? IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
                    onPressed: _sendText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  )
                : kIsWeb
                    ? const SizedBox(width: 36)
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _startRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}
