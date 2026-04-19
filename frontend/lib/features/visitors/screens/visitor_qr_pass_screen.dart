import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';

class VisitorQrPassScreen extends StatelessWidget {
  final Map<String, dynamic> visitor;

  const VisitorQrPassScreen({super.key, required this.visitor});

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ampm';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    final qrToken    = visitor['qrToken'] as String? ?? '';
    final name       = visitor['visitorName'] as String? ?? '-';
    final unit       = visitor['unit'] is Map ? visitor['unit']['fullCode'] : (visitor['unit'] ?? '-');
    final expires    = _fmt(visitor['qrExpiresAt'] as String?);
    final inviter    = visitor['inviter'] is Map ? visitor['inviter']['name'] : null;
    final desc       = visitor['description'] as String?;
    final societyName = visitor['society'] is Map
        ? (visitor['society']['name'] as String? ?? 'Society')
        : 'Society';

    final qrImage = await QrPainter(
      data: qrToken,
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
            // Header
            pw.Container(
              color: const PdfColor.fromInt(0xFF1B3A6B),
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(societyName,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Visitor Entry Pass',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Show this QR code at the gate',
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                ],
              ),
            ),
            // Body
            pw.Expanded(
              child: pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(28),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Hello, $name!',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF1A1A2E))),
                    pw.SizedBox(height: 4),
                    pw.Text('You have been invited to visit the society. Please present this pass at the gate.',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 16),
                    _pdfRow('Visiting Unit', 'Unit $unit'),
                    if (inviter != null) _pdfRow('Invited by', inviter),
                    if (desc != null && desc.isNotEmpty) _pdfRow('Vehicle / Note', desc),
                    _pdfRow('Valid Until', expires),
                    pw.SizedBox(height: 20),
                    // QR
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
                            child: pw.Text(qrToken,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                    color: const PdfColor.fromInt(0xFF1B3A6B))),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Single-use pass · do not share',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
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
      filename: 'visitor_pass_${name.replaceAll(' ', '_')}.pdf',
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
    final qrToken    = visitor['qrToken'] as String? ?? '';
    final name       = visitor['visitorName'] as String? ?? '-';
    final unit       = visitor['unit'] is Map ? visitor['unit']['fullCode'] : (visitor['unit'] ?? '-');
    final expires    = _fmt(visitor['qrExpiresAt'] as String?);
    final inviter    = visitor['inviter'] is Map ? (visitor['inviter']['name'] as String?) : null;
    final desc       = visitor['description'] as String?;
    final phone      = visitor['visitorPhone'] as String?;
    final societyName = visitor['society'] is Map
        ? (visitor['society']['name'] as String? ?? '')
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Visitor Pass', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
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
                        const Icon(Icons.apartment_rounded,
                            color: AppColors.textOnPrimary, size: 32),
                        const SizedBox(height: 8),
                        if (societyName.isNotEmpty) ...[
                          Text(societyName,
                              style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textOnPrimary.withValues(alpha: 0.85))),
                          const SizedBox(height: 4),
                        ],
                        Text('Visitor Entry Pass',
                            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
                        const SizedBox(height: 4),
                        Text('Show this QR code at the gate',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textOnPrimary.withValues(alpha: 0.75))),
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
                        Text('Hello, $name!',
                            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'You have been invited to visit the society.\nPresent this QR code to the security guard.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 20),

                        _infoRow('Visiting Unit', 'Unit $unit'),
                        if (inviter != null) _infoRow('Invited by', inviter),
                        if (phone != null && phone.isNotEmpty) _infoRow('Phone', phone),
                        if (desc != null && desc.isNotEmpty) _infoRow('Vehicle / Note', desc),
                        _infoRow('Valid Until', expires),

                        const SizedBox(height: 24),

                        // ── QR Code ──────────────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(
                                      color: AppColors.border, width: 6),
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusLg),
                                ),
                                child: QrImageView(
                                  data: qrToken,
                                  version: QrVersions.auto,
                                  size: 200,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: Text(
                                  qrToken,
                                  style: AppTextStyles.unitCode.copyWith(
                                      color: AppColors.primary, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Single-use pass · Do not share with others',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textMuted),
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
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      );
}
