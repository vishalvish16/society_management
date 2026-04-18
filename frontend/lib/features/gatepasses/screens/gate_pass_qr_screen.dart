import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';

class GatePassQrScreen extends StatelessWidget {
  final Map<String, dynamic> pass;

  const GatePassQrScreen({super.key, required this.pass});

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

  Future<void> _downloadPdf(BuildContext context) async {
    final passCode = pass['passCode'] as String? ?? '';
    final desc     = pass['itemDescription'] as String? ?? '-';
    final unit     = pass['unit'] is Map ? pass['unit']['fullCode'] : (pass['unit'] ?? '-');
    final reason   = pass['reason'] as String?;
    final from     = _fmt(pass['validFrom'] as String?);
    final to       = _fmt(pass['validTo'] as String?);

    final qrImage = await QrPainter(
      data: passCode,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    ).toImageData(300);

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
    final passCode = pass['passCode'] as String? ?? '';
    final desc     = pass['itemDescription'] as String? ?? '-';
    final unit     = pass['unit'] is Map ? pass['unit']['fullCode'] : (pass['unit'] ?? '-');
    final reason   = pass['reason'] as String?;
    final from     = _fmt(pass['validFrom'] as String?);
    final to       = _fmt(pass['validTo'] as String?);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary)),
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
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      );
}
