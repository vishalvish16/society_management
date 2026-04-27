import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ── Scan result model ──────────────────────────────────────────────────────────

class QrScanResult {
  final bool isValid;
  final String type;       // 'visitor' | 'gatepass' | 'delivery' | 'domestic'
  final String title;
  final String subtitle;
  final Map<String, String> details;
  final String? rawCode;
  final bool canDecide; // watchman can approve/reject (gatepass only)

  const QrScanResult({
    required this.isValid,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.details,
    this.rawCode,
    this.canDecide = false,
  });
}

// ── Full-screen QR scanner ─────────────────────────────────────────────────────

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  QrScanResult? _result;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _result != null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _processing = true);
    _controller.stop();
    HapticFeedback.mediumImpact();

    final result = await _verifyCode(code);
    if (mounted) {
      setState(() {
        _processing = false;
        _result = result;
      });
      HapticFeedback.heavyImpact();
    }
  }

  /// Strips deep-link prefixes so a QR containing `https://host/.../uuid` still validates.
  String _normalizeScannedPayload(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    if (t.contains('/')) {
      final parts = t.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        try {
          return Uri.decodeComponent(parts.last);
        } catch (_) {
          return parts.last;
        }
      }
    }
    return t;
  }

  bool _looksLikeGatePassCode(String s) {
    final t = s.trim();
    return RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(t);
  }

  Future<QrScanResult> _verifyCode(String code) async {
    try {
      final dio = ref.read(dioProvider);
      final normalized = _normalizeScannedPayload(code);

      // Gate passes encode an 8-character hex passCode (not visitor UUIDs).
      if (_looksLikeGatePassCode(normalized)) {
        try {
          final res = await dio.get(
            'gatepasses/verify/${normalized.toUpperCase()}',
          );
          if (res.data['success'] == true) {
            final d = res.data['data'] as Map<String, dynamic>;
            final pass = d['pass'] as Map<String, dynamic>? ?? d;
            final unit = pass['unit'] is Map
                ? pass['unit']['fullCode']
                : (pass['unit'] ?? '-');
            final creator = pass['createdBy'] is Map ? pass['createdBy']['name'] : null;
            final scannedBy = pass['scannedBy'] is Map ? pass['scannedBy']['name'] : null;
            final scannedAtStr = pass['scannedAt'] as String?;
            final decision = pass['decision'] as String?;
            final validToStr = pass['validTo'] as String?;
            final validFromStr = pass['validFrom'] as String?;
            final validTo = _fmtDate(validToStr);
            final status = (pass['status'] as String? ?? '').toLowerCase();
            final now = DateTime.now();
            DateTime? vf;
            DateTime? vt;
            try {
              if (validFromStr != null) vf = DateTime.parse(validFromStr);
              if (validToStr != null) vt = DateTime.parse(validToStr);
            } catch (_) {}
            final inWindow = vf != null &&
                vt != null &&
                !now.isBefore(vf) &&
                !now.isAfter(vt);
            final isValid = status == 'active' && inWindow;
            String title;
            String subtitle;
            if (isValid) {
              title = 'Gate Pass Valid';
              subtitle = pass['itemDescription'] as String? ?? 'Gate Pass';
            } else if (status == 'active' && vt != null && now.isAfter(vt)) {
              title = 'Gate Pass Expired';
              subtitle = 'This pass is past its valid until time.';
            } else if (status == 'active' && vf != null && now.isBefore(vf)) {
              title = 'Gate Pass Not Yet Valid';
              subtitle = 'This pass is not active yet.';
            } else if (status == 'used') {
              title = 'Gate Pass Already Used';
              subtitle = 'This pass has already been scanned.';
            } else {
              title = 'Gate Pass Invalid';
              subtitle = pass['itemDescription'] as String? ?? 'Gate Pass';
            }
            return QrScanResult(
              isValid: isValid,
              type: 'gatepass',
              title: title,
              subtitle: subtitle,
              details: {
                'Unit': 'Unit $unit',
                'Valid Until': validTo,
                'Status': (pass['status'] as String? ?? '-').toUpperCase(),
                if (creator != null) 'Created by': creator.toString(),
                if (decision != null) 'Decision': decision.toString(),
                if (scannedAtStr != null) 'Scanned at': _fmtDateTime(scannedAtStr),
                if (scannedBy != null) 'Scanned by': scannedBy.toString(),
                if (pass['reason'] != null) 'Reason': pass['reason'] as String,
              },
              rawCode: normalized,
              canDecide: isValid,
            );
          }
        } on DioException catch (_) {
          // fall through to visitor
        }
      }

      // Visitor invitation QR — backend: POST /api/visitors/validate
      try {
        final res = await dio.post(
          'visitors/validate',
          data: {'qrToken': normalized},
        );
        if (res.data['success'] == true) {
          final visitor = res.data['data'] as Map<String, dynamic>?;
          final name = visitor?['name'] as String? ?? 'Visitor';
          final unitCode = visitor?['unit'] as String? ?? '-';
          return QrScanResult(
            isValid: true,
            type: 'visitor',
            title: 'Visitor Pass Valid',
            subtitle: name,
            details: {
              'Unit': 'Unit $unitCode',
              'Status': 'CHECKED IN',
            },
            rawCode: normalized,
          );
        }
      } on DioException catch (e) {
        final body = e.response?.data;
        if (body is Map) {
          final msg = body['message'] as String? ?? 'Validation failed';
          final data = body['data'];
          String? result;
          if (data is Map) {
            result = data['result'] as String?;
          }
          final r = result?.toLowerCase();
          if (r == 'expired') {
            return QrScanResult(
              isValid: false,
              type: 'visitor',
              title: 'Visitor Pass Expired',
              subtitle: msg,
              details: const {},
              rawCode: normalized,
            );
          }
          if (r == 'used') {
            String? when;
            String? by;
            if (data is Map) {
              when = data['scannedAt'] as String?;
              by = data['scannedBy'] as String?;
            }
            return QrScanResult(
              isValid: false,
              type: 'visitor',
              title: 'Pass Already Used',
              subtitle: msg,
              details: {
                if (when != null) 'Scanned at': _fmtDateTime(when),
                if (by != null && by.isNotEmpty) 'Scanned by': by,
              },
              rawCode: normalized,
            );
          }
        }
      }

      return QrScanResult(
        isValid: false,
        type: 'unknown',
        title: 'Invalid QR Code',
        subtitle: 'This code is not recognised by the system.',
        details: const {},
        rawCode: normalized,
      );
    } catch (e) {
      return QrScanResult(
        isValid: false,
        type: 'error',
        title: 'Verification Failed',
        subtitle: 'Could not verify the QR code. Check your connection.',
        details: const {},
        rawCode: code,
      );
    }
  }

  String _fmtDateTime(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}, $h:$min';
    } catch (_) {
      return iso;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _processing = true);
    _controller.stop();

    final captured = await _controller.analyzeImage(file.path);
    final code = captured?.barcodes.firstOrNull?.rawValue;

    if (code == null || code.isEmpty) {
      if (mounted) {
        setState(() => _processing = false);
        _controller.start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in the selected image')),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final result = await _verifyCode(code);
    if (mounted) {
      setState(() {
        _processing = false;
        _result = result;
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _rescan() {
    setState(() => _result = null);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          if (_result == null)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

          // Full-screen result overlay
          if (_result != null)
            _ResultOverlay(result: _result!, onRescan: _rescan),

          // Scanner UI overlay (only when scanning)
          if (_result == null) ...[
            _ScannerOverlay(pulseAnim: _pulseAnim),
            if (_processing) const _ProcessingOverlay(),
          ],

          // Close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_result == null)
                    Text(
                      'Scan QR Code',
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                  const Spacer(),
                  // Gallery pick
                  if (_result == null)
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_library_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Torch toggle
                  if (_result == null)
                    GestureDetector(
                      onTap: () => _controller.toggleTorch(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flashlight_on_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scanner viewfinder overlay ─────────────────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _ScannerOverlay({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = size.width * 0.72;
    final top = (size.height - boxSize) / 2 - 40;

    return Stack(
      children: [
        // Dim background around the viewfinder
        CustomPaint(
          size: size,
          painter: _DimOverlayPainter(
            boxSize: boxSize,
            boxTop: top,
            boxLeft: (size.width - boxSize) / 2,
          ),
        ),

        // Animated corner brackets
        Positioned(
          top: top,
          left: (size.width - boxSize) / 2,
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: pulseAnim.value,
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: CustomPaint(painter: _CornerPainter()),
              ),
            ),
          ),
        ),

        // Scan line
        Positioned(
          top: top + boxSize / 2 - 1,
          left: (size.width - boxSize) / 2 + 16,
          right: (size.width - boxSize) / 2 + 16,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primaryLight,
                  AppColors.primary.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Hint text
        Positioned(
          top: top + boxSize + 28,
          left: 0, right: 0,
          child: Column(
            children: [
              Text(
                'Point camera at QR code',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Gate passes · Visitors · Deliveries · Domestic Help',
                style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Or use  🖼  to scan from gallery',
                style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.45)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DimOverlayPainter extends CustomPainter {
  final double boxSize;
  final double boxTop;
  final double boxLeft;
  _DimOverlayPainter(
      {required this.boxSize, required this.boxTop, required this.boxLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final hole = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop, boxSize, boxSize),
      const Radius.circular(16),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(hole),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 14.0;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(r + len, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, r + len), paint);
    canvas.drawArc(
        Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14159, 1.5708, false, paint);

    // Top-right
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2),
        -1.5708, 1.5708, false, paint);

    // Bottom-left
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height - r), Offset(0, size.height - r - len), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2),
        1.5708, 1.5708, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - r - len, size.height),
        Offset(size.width - r, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r),
        Offset(size.width, size.height - r - len), paint);
    canvas.drawArc(
        Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2),
        0, 1.5708, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Processing overlay ─────────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.primaryLight,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text('Verifying…',
                  style: AppTextStyles.h3.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text('Checking with server',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full-screen result overlay ─────────────────────────────────────────────────

class _ResultOverlay extends ConsumerStatefulWidget {
  final QrScanResult result;
  final VoidCallback onRescan;
  const _ResultOverlay({required this.result, required this.onRescan});

  @override
  ConsumerState<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends ConsumerState<_ResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _submittingDecision = false;
  QrScanResult? _overrideResult;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _overrideResult ?? widget.result;
    final isValid = r.isValid;
    final color = isValid ? AppColors.success : AppColors.danger;
    final bgColor = isValid ? const Color(0xFF052E16) : const Color(0xFF450A0A);
    final icon = isValid ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final typeIcon = _typeIcon(r.type);
    final isGatePass = r.type == 'gatepass';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(typeIcon, size: 13, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            _typeLabel(r.type),
                            style: AppTextStyles.labelSmall
                                .copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main result icon
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color.withValues(alpha: 0.5), width: 3),
                        ),
                        child: Icon(icon, color: color, size: 60),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      r.title,
                      style: AppTextStyles.displayMedium
                          .copyWith(color: Colors.white, fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        r.subtitle,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Details card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    ...r.details.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(e.key,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: Colors.white54)),
                              const Spacer(),
                              Text(e.value,
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: Colors.white)),
                            ],
                          ),
                        )),
                    if (r.rawCode != null) ...[
                      const Divider(color: Colors.white12, height: 20),
                      Row(
                        children: [
                          Text('Code',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.white38)),
                          const Spacer(),
                          Text(
                            r.rawCode!,
                            style: AppTextStyles.labelMedium
                                .copyWith(
                                    color: Colors.white54,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _submittingDecision ? null : widget.onRescan,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('Scan Again',
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _submittingDecision
                            ? null
                            : () async {
                                if (isGatePass && r.canDecide && r.rawCode != null) {
                                  // Default action: approve (quick tap).
                                  await _submitDecision(r.rawCode!, 'APPROVED');
                                  return;
                                }
                                if (context.mounted) Navigator.of(context).pop();
                              },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_submittingDecision)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else ...[
                                Icon(
                                  isGatePass && r.canDecide
                                      ? Icons.verified_rounded
                                      : (isValid
                                          ? Icons.done_all_rounded
                                          : Icons.arrow_back_rounded),
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isGatePass && r.canDecide
                                      ? 'Approve'
                                      : (isValid ? 'Allow Entry' : 'Back'),
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Gate pass reject button (only when valid + undecided)
              if (isGatePass && r.canDecide && r.rawCode != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _submittingDecision
                          ? null
                          : () => _submitDecision(r.rawCode!, 'REJECTED'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35)),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitDecision(String passCode, String decision) async {
    setState(() => _submittingDecision = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('gatepasses/scan', data: {
        'passCode': passCode,
        'decision': decision,
      });
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final scannedAt = data['scannedAt'] as String?;
      final scannedBy = data['scannedBy'] is Map ? data['scannedBy']['name'] : null;
      final unit = data['unit'] is Map ? data['unit']['fullCode'] : null;
      final creator = data['createdBy'] is Map ? data['createdBy']['name'] : null;
      final desc = data['itemDescription'] as String? ?? 'Gate Pass';

      final approved = decision.toUpperCase() == 'APPROVED';
      setState(() {
        _overrideResult = QrScanResult(
          isValid: approved,
          type: 'gatepass',
          title: approved ? 'Gate Pass Approved' : 'Gate Pass Rejected',
          subtitle: desc,
          details: {
            if (unit != null) 'Unit': 'Unit $unit',
            if (creator != null) 'Created by': creator.toString(),
            'Decision': decision.toUpperCase(),
            if (scannedAt != null) 'Scanned at': _fmtDateTime(scannedAt),
            if (scannedBy != null) 'Scanned by': scannedBy.toString(),
          },
          rawCode: passCode,
          canDecide: false,
        );
        _submittingDecision = false;
      });
      HapticFeedback.heavyImpact();
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Could not submit decision';
      Map<String, String> details = {};
      if (body is Map) {
        msg = body['message']?.toString() ?? msg;
        final d = body['data'];
        if (d is Map) {
          final when = d['scannedAt']?.toString();
          final by = d['scannedBy']?.toString();
          final dec = d['decision']?.toString();
          details = {
            if (dec != null) 'Decision': dec,
            if (when != null) 'Scanned at': _fmtDateTime(when),
            if (by != null) 'Scanned by': by,
          };
        }
      }
      setState(() {
        _overrideResult = QrScanResult(
          isValid: false,
          type: 'gatepass',
          title: 'Gate Pass Not Allowed',
          subtitle: msg,
          details: details,
          rawCode: passCode,
          canDecide: false,
        );
        _submittingDecision = false;
      });
    } catch (_) {
      setState(() => _submittingDecision = false);
    }
  }

  String _fmtDateTime(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}, $h:$min';
    } catch (_) {
      return iso;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'gatepass': return Icons.badge_rounded;
      case 'visitor': return Icons.person_pin_circle_rounded;
      case 'delivery': return Icons.local_shipping_rounded;
      case 'domestic': return Icons.cleaning_services_rounded;
      default: return Icons.qr_code_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'gatepass': return 'Gate Pass';
      case 'visitor': return 'Visitor';
      case 'delivery': return 'Delivery';
      case 'domestic': return 'Domestic Help';
      default: return 'Unknown';
    }
  }
}
