import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_date_picker.dart';

class BalanceReportScreen extends StatefulWidget {
  const BalanceReportScreen({super.key});

  @override
  State<BalanceReportScreen> createState() => _BalanceReportScreenState();
}

class _BalanceReportScreenState extends State<BalanceReportScreen> {
  final _client = DioClient();

  // Default: first day of current month → today
  late DateTime _from;
  late DateTime _to;

  bool _loading = false;
  String? _error;

  double _openingBalance = 0;
  List<Map<String, dynamic>> _txns = const [];
  Map<String, dynamic> _summary = const {};

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0); // last day of month
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _client.dio.get('/reports/balance', queryParameters: {
        'fromDate': _from.toIso8601String(),
        'toDate': DateTime(_to.year, _to.month, _to.day, 23, 59, 59).toIso8601String(),
      });
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _openingBalance = (data['openingBalance'] as num).toDouble();
        _txns = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        _summary = Map<String, dynamic>.from(data['summary'] ?? {});
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await pickDateRange(
      context,
      initialFrom: _from,
      initialTo: _to,
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _load();
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    // PDF default fonts don't support ₹ — use Rs. prefix instead
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('Balance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Period: ${dateFormat.format(_from)} – ${dateFormat.format(_to)}',
            style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            'Opening Balance: ${currencyFormat.format(_openingBalance)}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: ['Date', 'Description', 'Income', 'Expense', 'Balance']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ))
                  .toList(),
            ),
            ..._txns.map((t) {
              final isIncome = t['type'] == 'income';
              final amt = (t['amount'] as num).toDouble();
              final bal = (t['runningBalance'] as num).toDouble();
              return pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(dateFormat.format(DateTime.parse(t['date'].toString())), style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(t['description'] ?? '', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(isIncome ? currencyFormat.format(amt) : '', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(!isIncome ? currencyFormat.format(amt) : '', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(currencyFormat.format(bal), style: const pw.TextStyle(fontSize: 9)),
                ),
              ]);
            }),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Total Income:  ${currencyFormat.format(_summary['periodIncome'] ?? 0)}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Total Expense: ${currencyFormat.format(_summary['periodExpense'] ?? 0)}', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 4),
              pw.Text('Closing Balance: ${currencyFormat.format(_summary['closingBalance'] ?? 0)}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ]),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        title: Text('Balance Report', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF',
            onPressed: _txns.isEmpty ? null : _exportPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Date range filter ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppDateRangeField(
              label: 'Period',
              from: _from,
              to: _to,
              onTap: _pickDateRange,
            ),
          ),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                    const SizedBox(height: 8),
                    Text('Failed to load report', style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Opening balance card ──────────────────────────
                  _SummaryCard(
                    label: 'Opening Balance',
                    sublabel: 'As of ${_dateFmt.format(_from)}',
                    amount: _openingBalance,
                    icon: Icons.account_balance_rounded,
                    color: AppColors.primary,
                    surface: AppColors.primarySurface,
                  ),
                  const SizedBox(height: 12),

                  // ── Transactions list ──────────────────────────────
                  if (_txns.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Text('No transactions in this period',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  else ...[
                    Text('Transactions', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // Header row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text('Date / Description',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary))),
                                Expanded(flex: 2, child: Text('Income',
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.success))),
                                Expanded(flex: 2, child: Text('Expense',
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.danger))),
                                Expanded(flex: 2, child: Text('Balance',
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary))),
                              ],
                            ),
                          ),
                          ..._txns.asMap().entries.map((entry) {
                            final i = entry.key;
                            final t = entry.value;
                            final isIncome = t['type'] == 'income';
                            final amt = (t['amount'] as num).toDouble();
                            final bal = (t['runningBalance'] as num).toDouble();
                            final date = DateTime.tryParse(t['date'].toString());
                            return Column(
                              children: [
                                if (i > 0) const Divider(height: 1, indent: 16, color: AppColors.border),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(date != null ? _dateFmt.format(date) : '—',
                                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                                            const SizedBox(height: 2),
                                            Text(t['description'] ?? '—',
                                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                                                maxLines: 2, overflow: TextOverflow.ellipsis),
                                            if (t['unit'] != null)
                                              Text(t['unit'].toString(),
                                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          isIncome ? _currency.format(amt) : '',
                                          textAlign: TextAlign.right,
                                          style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.success, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          !isIncome ? _currency.format(amt) : '',
                                          textAlign: TextAlign.right,
                                          style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.danger, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _currency.format(bal),
                                          textAlign: TextAlign.right,
                                          style: AppTextStyles.bodySmall.copyWith(
                                              color: bal >= 0 ? AppColors.textPrimary : AppColors.danger,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Summary footer ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text('Period Summary', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Income',
                                amount: (_summary['periodIncome'] as num?)?.toDouble() ?? 0,
                                icon: Icons.arrow_downward_rounded,
                                color: AppColors.success,
                                surface: AppColors.successSurface,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Expense',
                                amount: (_summary['periodExpense'] as num?)?.toDouble() ?? 0,
                                icon: Icons.arrow_upward_rounded,
                                color: AppColors.danger,
                                surface: AppColors.dangerSurface,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _SummaryCard(
                          label: 'Closing Balance',
                          sublabel: 'As of ${_dateFmt.format(_to)}',
                          amount: (_summary['closingBalance'] as num?)?.toDouble() ?? 0,
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          surface: AppColors.primarySurface,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String? sublabel;
  final double amount;
  final IconData icon;
  final Color color;
  final Color surface;
  final bool compact;

  const _SummaryCard({
    required this.label,
    this.sublabel,
    required this.amount,
    required this.icon,
    required this.color,
    required this.surface,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: compact ? 18 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600)),
                if (sublabel != null)
                  Text(sublabel!, style: AppTextStyles.labelSmall.copyWith(color: color.withValues(alpha: 0.7))),
                const SizedBox(height: 2),
                Text(currency.format(amount),
                    style: TextStyle(
                      fontSize: compact ? 15 : 18,
                      fontWeight: FontWeight.bold,
                      color: amount < 0 ? AppColors.danger : color,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
