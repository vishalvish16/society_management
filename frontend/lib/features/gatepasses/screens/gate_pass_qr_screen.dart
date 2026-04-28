import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';

class GatePassQrScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> pass;

  const GatePassQrScreen({super.key, required this.pass});

  @override
  ConsumerState<GatePassQrScreen> createState() => _GatePassQrScreenState();
}

class _GatePassQrScreenState extends ConsumerState<GatePassQrScreen> {
  bool _loadingLogs = false;
  String? _logsError;
  List<Map<String, dynamic>> _logs = const [];

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day.toString().padLeft(2, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.year} $h:$m';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _loadLogs() async {
    final id = (widget.pass['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return;

    setState(() {
      _loadingLogs = true;
      _logsError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('gatepasses/$id/logs');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final logs = data['logs'] as List<dynamic>? ?? [];
      setState(() {
        _logs = logs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingLogs = false;
      });
    } on DioException catch (e) {
      setState(() {
        _logsError = e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? e.message)
            : e.message;
        _loadingLogs = false;
      });
    } catch (e) {
      setState(() {
        _logsError = e.toString();
        _loadingLogs = false;
      });
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    final passCode = widget.pass['passCode'] as String? ?? '';
    final desc     = widget.pass['itemDescription'] as String? ?? '-';
    final unit     = widget.pass['unit'] is Map ? widget.pass['unit']['fullCode'] : (widget.pass['unit'] ?? '-');
    final reason   = widget.pass['reason'] as String?;
    final from     = _fmt(widget.pass['validFrom'] as String?);
    final to       = _fmt(widget.pass['validTo'] as String?);

    final qrImage = await QrPainter(
      data: passCode,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    ).toImageData(
      300,
      format: ui.ImageByteFormat.png,
    );

    final pdf = pw.Document();
    final pdfQrImage = qrImage != null
        ? pw.MemoryImage(qrImage.buffer.asUint8List())
        : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: const PdfColor.fromInt(0xFF1B3A6B),
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Gate Pass',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('For watchman verification',
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(28),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(desc,
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF1A1A2E))),
                    pw.SizedBox(height: 4),
                    pw.Text('Please show this QR to the security guard at the gate.',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 16),
                    _pdfRow('Unit', 'Unit $unit'),
                    if (reason != null && reason.isNotEmpty) _pdfRow('Reason', reason),
                    _pdfRow('Valid From', from),
                    _pdfRow('Valid To', to),
                    pw.SizedBox(height: 20),
                    pw.Center(
                      child: pw.Column(
                        children: [
                          if (pdfQrImage != null)
                            pw.Container(
                              width: 160,
                              height: 160,
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                    color: const PdfColor.fromInt(0xFFE8EAF6), width: 4),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                              ),
                              child: pw.Image(pdfQrImage),
                            ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFF5F7FA),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.Text(passCode,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 14,
                                    color: const PdfColor.fromInt(0xFF1B3A6B),
                                    letterSpacing: 2)),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Society members authorised pass',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.Container(
              color: const PdfColor.fromInt(0xFFF5F7FA),
              padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: pw.Center(
                child: pw.Text('Powered by Society Management System',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'gate_pass_$passCode.pdf',
    );
  }

  pw.Widget _pdfRow(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1A1A2E))),
            ],
          ),
          pw.Divider(color: const PdfColor.fromInt(0xFFE8EAF6), thickness: 0.5),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final passCode = widget.pass['passCode'] as String? ?? '';
    final desc     = widget.pass['itemDescription'] as String? ?? '-';
    final unit     = widget.pass['unit'] is Map ? widget.pass['unit']['fullCode'] : (widget.pass['unit'] ?? '-');
    final reason   = widget.pass['reason'] as String?;
    final from     = _fmt(widget.pass['validFrom'] as String?);
    final to       = _fmt(widget.pass['validTo'] as String?);
    final decision = (widget.pass['decision'] as String?)?.toUpperCase();
    final scannedAt = widget.pass['scannedAt'] as String?;
    final scannedBy = (widget.pass['scannedBy'] is Map)
        ? (widget.pass['scannedBy']['name']?.toString())
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Gate Pass', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
        actions: [
          IconButton(
            tooltip: 'Download / Share PDF',
            icon: const Icon(Icons.download_rounded, color: AppColors.textOnPrimary),
            onPressed: () => _downloadPdf(context),
          ),
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Container(
                    color: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: AppColors.textOnPrimary, size: 32),
                        const SizedBox(height: 8),
                        Text('Gate Pass',
                            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
                        const SizedBox(height: 4),
                        Text('For watchman verification',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textOnPrimary.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),

                  // ── Body ────────────────────────────────────────────────
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc,
                            style: AppTextStyles.h2.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          'Show this QR code to the security guard at the gate.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 20),

                        _infoRow('Unit', 'Unit $unit'),
                        if (reason != null && reason.isNotEmpty)
                          _infoRow('Reason', reason),
                        _infoRow('Valid From', from),
                        _infoRow('Valid To', to),
                        if (decision != null) ...[
                          _infoRow('Decision', decision),
                          if (scannedAt != null) _infoRow('Scanned at', _fmtDateTime(scannedAt)),
                          if (scannedBy != null && scannedBy.isNotEmpty)
                            _infoRow('Scanned by', scannedBy),
                        ],

                        const SizedBox(height: 24),

                        // ── QR Code ──────────────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border, width: 6),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                                ),
                                child: QrImageView(
                                  data: passCode,
                                  version: QrVersions.auto,
                                  size: 200,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Pass code badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: Text(
                                  passCode,
                                  style: AppTextStyles.unitCode.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 20,
                                      letterSpacing: 4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Society-authorised pass · watchman scans to approve',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Download button ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadPdf(context),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download / Share Pass'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Scan History ─────────────────────────────────
                        Row(
                          children: [
                            Text('Scan History', style: AppTextStyles.h3),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Refresh',
                              onPressed: _loadingLogs ? null : _loadLogs,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        if (_logsError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _logsError ?? 'Failed to load logs',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.dangerText),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_loadingLogs)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Text('Loading logs…',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          )
                        else if (_logs.isEmpty)
                          Text(
                            'No scan logs yet.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          )
                        else
                          Column(
                            children: _logs.map((l) {
                              final decision = (l['decision'] as String?)?.toUpperCase();
                              final result = (l['result'] as String?)?.toUpperCase() ?? '-';
                              final scannedAt = l['scannedAt'] as String?;
                              final by = (l['scannedBy'] is Map)
                                  ? (l['scannedBy']['name']?.toString())
                                  : null;
                              final note = l['note']?.toString();
                              final isOk = decision == 'APPROVED';
                              final icon = decision == null
                                  ? Icons.info_outline_rounded
                                  : (isOk
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded);
                              final iconColor = decision == null
                                  ? AppColors.textMuted
                                  : (isOk ? AppColors.success : AppColors.danger);

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon, color: iconColor, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            decision != null
                                                ? 'Decision: $decision'
                                                : 'Result: $result',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_fmtDateTime(scannedAt)}'
                                            '${by != null ? ' · by $by' : ''}',
                                            style: AppTextStyles.bodySmall.copyWith(
                                                color: AppColors.textMuted),
                                          ),
                                          if (note != null && note.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(note,
                                                style: AppTextStyles.bodySmall),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  // ── Footer ──────────────────────────────────────────────
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    child: Text(
                      'Powered by Society Management System',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                Flexible(
                  child: Text(value,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      );
}
