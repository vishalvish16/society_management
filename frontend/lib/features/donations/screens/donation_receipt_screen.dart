import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DonationReceiptScreen extends ConsumerWidget {
  final Map<String, dynamic> donation;

  const DonationReceiptScreen({super.key, required this.donation});

  String _receiptNo(String id) {
    final cleaned = id.replaceAll('-', '').toUpperCase();
    return cleaned.length >= 10 ? 'DON-${cleaned.substring(0, 10)}' : 'DON-$cleaned';
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '—';
    final s = iso.toString();
    if (s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  double _amt(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;

  Future<Uint8List> _buildPdfBytes({
    required String societyName,
    required Map<String, dynamic> d,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

    final id = (d['id'] ?? '').toString();
    final donor = d['donor'] as Map<String, dynamic>?;
    final campaign = d['campaign'] as Map<String, dynamic>?;
    final method = (d['paymentMethod'] ?? '').toString();
    final note = (d['note'] ?? '').toString().trim();
    final paidAt = d['paidAt'];
    final amount = _amt(d['amount']);

    pw.Widget row(String label, String value) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Text(
                    value,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(color: const PdfColor.fromInt(0xFFE8EAF6), thickness: 0.5),
          ],
        );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
                  pw.Text(
                    societyName.isNotEmpty ? societyName : 'Society',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Donation Receipt',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Thank you for your contribution',
                    style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11),
                  ),
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
                    pw.Container(
                      padding: const pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF5F7FA),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Receipt No.',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                              pw.SizedBox(height: 2),
                              pw.Text(_receiptNo(id),
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: const PdfColor.fromInt(0xFF1A1A2E),
                                  )),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Amount',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                              pw.SizedBox(height: 2),
                              pw.Text(currency.format(amount),
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    color: const PdfColor.fromInt(0xFF2E7D32),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    row('Donor', (donor?['name'] ?? '—').toString()),
                    if ((donor?['phone'] ?? '').toString().trim().isNotEmpty)
                      row('Phone', (donor?['phone'] ?? '—').toString()),
                    if (campaign != null && (campaign['title'] ?? '').toString().trim().isNotEmpty)
                      row('Campaign', (campaign['title'] ?? '—').toString()),
                    row('Paid At', _fmtDate(paidAt)),
                    row('Payment Method', method.isNotEmpty ? method.replaceAll('_', ' ') : '—'),
                    if (note.isNotEmpty) row('Note', note),
                    pw.SizedBox(height: 18),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8EAF6)),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 34,
                            height: 34,
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFE8F5E9),
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text('✓',
                                  style: pw.TextStyle(
                                    color: const PdfColor.fromInt(0xFF2E7D32),
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                  )),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Text(
                              'This is a computer-generated receipt.',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                          ),
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
                child: pw.Text(
                  'Powered by Society Management System',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> _sharePdf(BuildContext context, String societyName) async {
    final bytes = await _buildPdfBytes(societyName: societyName, d: donation);
    final donor = donation['donor'] as Map<String, dynamic>?;
    final donorName = (donor?['name'] ?? 'donor').toString().replaceAll(' ', '_');
    await Printing.sharePdf(bytes: bytes, filename: 'donation_receipt_$donorName.pdf');
  }

  Future<void> _printPdf(BuildContext context, String societyName) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildPdfBytes(societyName: societyName, d: donation),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final societyName = (user?.societyName ?? '').trim();

    final donor = donation['donor'] as Map<String, dynamic>?;
    final campaign = donation['campaign'] as Map<String, dynamic>?;
    final id = (donation['id'] ?? '').toString();
    final amount = _amt(donation['amount']);
    final currencyUi = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final paidAt = donation['paidAt'];
    final method = (donation['paymentMethod'] ?? '').toString();
    final note = (donation['note'] ?? '').toString().trim();

    Widget infoRow(String label, String value) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
          ],
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, AppDimensions.sm, AppDimensions.sm, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Share PDF',
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => _sharePdf(context, societyName),
                  ),
                  IconButton(
                    tooltip: 'Print',
                    icon: const Icon(Icons.print_rounded),
                    onPressed: () => _printPdf(context, societyName),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.textOnPrimary, size: 32),
                        const SizedBox(height: 8),
                        if (societyName.isNotEmpty) ...[
                          Text(
                            societyName,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          'Donation Receipt',
                          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thank you for your contribution',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textOnPrimary.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Receipt No.', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _receiptNo(id),
                                      style: AppTextStyles.labelLarge.copyWith(color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Amount', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyUi.format(amount),
                                    style: AppTextStyles.h3.copyWith(color: AppColors.success),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        infoRow('Donor', (donor?['name'] ?? '—').toString()),
                        if ((donor?['phone'] ?? '').toString().trim().isNotEmpty)
                          infoRow('Phone', (donor?['phone'] ?? '—').toString()),
                        if (campaign != null && (campaign['title'] ?? '').toString().trim().isNotEmpty)
                          infoRow('Campaign', (campaign['title'] ?? '—').toString()),
                        infoRow('Paid At', _fmtDate(paidAt)),
                        infoRow('Payment Method', method.isNotEmpty ? method.replaceAll('_', ' ') : '—'),
                        if (note.isNotEmpty) infoRow('Note', note),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _sharePdf(context, societyName),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Download / Share PDF'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () => _printPdf(context, societyName),
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text('Print'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
          ),
        ],
      ),
    );
  }
}

