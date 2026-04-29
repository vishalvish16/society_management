import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_page_header.dart';

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

  Map<String, dynamic> _opening = const {'cash': 0, 'bank': 0, 'total': 0};
  Map<String, dynamic> _closing = const {'cash': 0, 'bank': 0, 'total': 0};
  List<Map<String, dynamic>> _txns = const [];

  String _view = 'ALL'; // ALL | CASH | BANK

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  String _displayDescription(Map<String, dynamic> t) {
    final raw = (t['description'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;

    final transferGroupId = t['transferGroupId'];
    if (transferGroupId == null) return '—';

    final dc = (t['deltaCash'] as num?)?.toDouble() ?? 0;
    final db = (t['deltaBank'] as num?)?.toDouble() ?? 0;

    // When backend sends transfers as 2 separate rows:
    // - CASH OUT or BANK IN => Deposit Cash → Bank
    // - BANK OUT or CASH IN => Withdraw Bank → Cash
    final isDeposit = dc < 0 || db > 0;
    final isWithdraw = db < 0 || dc > 0;

    if (isDeposit && !isWithdraw) return 'Deposit Cash → Bank';
    if (isWithdraw && !isDeposit) return 'Withdraw Bank → Cash';
    if (isDeposit) return 'Deposit Cash → Bank';
    if (isWithdraw) return 'Withdraw Bank → Cash';
    return 'Transfer';
  }

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
      final res = await _client.dio.get('/reports/ledger', queryParameters: {
        'fromDate': _from.toIso8601String(),
        'toDate': DateTime(_to.year, _to.month, _to.day, 23, 59, 59).toIso8601String(),
      });
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _opening = Map<String, dynamic>.from(data['opening'] ?? const {'cash': 0, 'bank': 0, 'total': 0});
        _closing = Map<String, dynamic>.from(data['closing'] ?? const {'cash': 0, 'bank': 0, 'total': 0});
        _txns = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
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
            'Opening Total: ${currencyFormat.format((_opening['total'] ?? 0) as num)}',
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
            ..._filteredTxns().map((t) {
              final isIncome = (t['deltaCash'] as num? ?? 0) + (t['deltaBank'] as num? ?? 0) > 0;
              final amt = (t['amount'] as num).toDouble();
              final bal = _view == 'CASH'
                  ? (t['balanceCash'] as num?)?.toDouble() ?? 0
                  : _view == 'BANK'
                      ? (t['balanceBank'] as num?)?.toDouble() ?? 0
                      : (t['balanceTotal'] as num?)?.toDouble() ?? 0;
              return pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(dateFormat.format(DateTime.parse(t['date'].toString())), style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Text(_displayDescription(t), style: const pw.TextStyle(fontSize: 9)),
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
              pw.Text('Closing Cash:  ${currencyFormat.format((_closing['cash'] ?? 0) as num)}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Closing Bank:  ${currencyFormat.format((_closing['bank'] ?? 0) as num)}', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 4),
              pw.Text('Closing Total: ${currencyFormat.format((_closing['total'] ?? 0) as num)}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ]),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _openLedgerActions() async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      enableDrag: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ledger Actions', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add Entry (Cash/Bank IN/OUT)',
                  subtitle: 'Record received/paid money in cash or bank',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openAddEntryDialog();
                  },
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Transfer (Deposit/Withdraw)',
                  subtitle: 'Move money between cash and bank',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openTransferDialog();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: Deposit = CASH → BANK, Withdraw = BANK → CASH.',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddEntryDialog() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String account = 'CASH';
    String direction = 'IN';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final amt = double.tryParse(amountCtrl.text.trim().replaceAll(',', ''));
              if (amt == null || amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid amount')),
                );
                return;
              }
              setLocal(() => saving = true);
              try {
                await _client.dio.post('/reports/ledger/entry', data: {
                  'account': account,
                  'direction': direction,
                  'amount': amt,
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'occurredAt': DateTime.now().toIso8601String(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                await _load();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              } finally {
                if (ctx.mounted) setLocal(() => saving = false);
              }
            }

            return AlertDialog(
              title: const Text('Add Ledger Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: account,
                            decoration: const InputDecoration(labelText: 'Account'),
                            items: const [
                              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                              DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                            ],
                            onChanged: saving ? null : (v) => setLocal(() => account = v ?? 'CASH'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: direction,
                            decoration: const InputDecoration(labelText: 'Type'),
                            items: const [
                              DropdownMenuItem(value: 'IN', child: Text('In (Received)')),
                              DropdownMenuItem(value: 'OUT', child: Text('Out (Paid)')),
                            ],
                            onChanged: saving ? null : (v) => setLocal(() => direction = v ?? 'IN'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      enabled: !saving,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                      enabled: !saving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openTransferDialog() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String fromAccount = 'CASH';
    String toAccount = 'BANK';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final amt = double.tryParse(amountCtrl.text.trim().replaceAll(',', ''));
              if (amt == null || amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid amount')),
                );
                return;
              }
              if (fromAccount == toAccount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Choose different accounts')),
                );
                return;
              }
              setLocal(() => saving = true);
              try {
                await _client.dio.post('/reports/ledger/transfer', data: {
                  'fromAccount': fromAccount,
                  'toAccount': toAccount,
                  'amount': amt,
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'occurredAt': DateTime.now().toIso8601String(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                await _load();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              } finally {
                if (ctx.mounted) setLocal(() => saving = false);
              }
            }

            return AlertDialog(
              title: const Text('Transfer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fromAccount,
                            decoration: const InputDecoration(labelText: 'From'),
                            items: const [
                              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                              DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                            ],
                            onChanged: saving ? null : (v) => setLocal(() {
                              fromAccount = v ?? 'CASH';
                              if (fromAccount == toAccount) toAccount = fromAccount == 'CASH' ? 'BANK' : 'CASH';
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: toAccount,
                            decoration: const InputDecoration(labelText: 'To'),
                            items: const [
                              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                              DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                            ],
                            onChanged: saving ? null : (v) => setLocal(() {
                              toAccount = v ?? 'BANK';
                              if (fromAccount == toAccount) fromAccount = toAccount == 'CASH' ? 'BANK' : 'CASH';
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      enabled: !saving,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                      enabled: !saving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              title: Text(
                'Balance Report',
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Ledger actions',
                  onPressed: _openLedgerActions,
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Export PDF',
                  onPressed: _filteredTxns().isEmpty ? null : _exportPdf,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Balance Report',
            icon: Icons.account_balance_wallet_rounded,
            actions: [
              IconButton(
                tooltip: 'Ledger actions',
                icon: const Icon(Icons.add_rounded),
                onPressed: _openLedgerActions,
              ),
              IconButton(
                tooltip: 'Export PDF',
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: _filteredTxns().isEmpty ? null : _exportPdf,
              ),
            ],
          ),
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

          // ── View selector (All / Cash / Bank) ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _ViewChip(label: 'All', value: 'ALL', selected: _view, onSelected: (v) => setState(() => _view = v)),
                const SizedBox(width: 8),
                _ViewChip(label: 'Cash', value: 'CASH', selected: _view, onSelected: (v) => setState(() => _view = v)),
                const SizedBox(width: 8),
                _ViewChip(label: 'Bank', value: 'BANK', selected: _view, onSelected: (v) => setState(() => _view = v)),
              ],
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
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Opening Cash',
                          sublabel: 'As of ${_dateFmt.format(_from)}',
                          amount: ((_opening['cash'] as num?)?.toDouble() ?? 0),
                          icon: Icons.payments_rounded,
                          color: AppColors.success,
                          surface: AppColors.successSurface,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Opening Bank',
                          sublabel: 'As of ${_dateFmt.format(_from)}',
                          amount: ((_opening['bank'] as num?)?.toDouble() ?? 0),
                          icon: Icons.account_balance_rounded,
                          color: AppColors.primary,
                          surface: AppColors.primarySurface,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SummaryCard(
                    label: 'Opening Total',
                    sublabel: 'As of ${_dateFmt.format(_from)}',
                    amount: ((_opening['total'] as num?)?.toDouble() ?? 0),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    surface: AppColors.primarySurface,
                  ),
                  const SizedBox(height: 12),

                  // ── Transactions list ──────────────────────────────
                  if (_filteredTxns().isEmpty)
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
                          ..._filteredTxns().asMap().entries.map((entry) {
                            final i = entry.key;
                            final t = entry.value;
                            final selectedBalance = _view == 'CASH'
                                ? ((t['balanceCash'] as num?)?.toDouble() ?? 0)
                                : _view == 'BANK'
                                    ? ((t['balanceBank'] as num?)?.toDouble() ?? 0)
                                    : ((t['balanceTotal'] as num?)?.toDouble() ?? 0);
                            final isIncome = ((t['deltaCash'] as num? ?? 0) + (t['deltaBank'] as num? ?? 0)) > 0;
                            final amt = (t['amount'] as num).toDouble();
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
                                            Text(_displayDescription(t),
                                                style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurface),
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
                                          _currency.format(selectedBalance),
                                          textAlign: TextAlign.right,
                                          style: AppTextStyles.bodySmall.copyWith(
                                              color: selectedBalance >= 0 ? Theme.of(context).colorScheme.onSurface : AppColors.danger,
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
                        Text('Closing Balances', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'Cash',
                                amount: ((_closing['cash'] as num?)?.toDouble() ?? 0),
                                icon: Icons.payments_rounded,
                                color: AppColors.success,
                                surface: AppColors.successSurface,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Bank',
                                amount: ((_closing['bank'] as num?)?.toDouble() ?? 0),
                                icon: Icons.account_balance_rounded,
                                color: AppColors.primary,
                                surface: AppColors.primarySurface,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _SummaryCard(
                          label: 'Total',
                          sublabel: 'As of ${_dateFmt.format(_to)}',
                          amount: ((_closing['total'] as num?)?.toDouble() ?? 0),
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

  List<Map<String, dynamic>> _filteredTxns() {
    if (_view == 'CASH') {
      return _txns.where((t) => (t['deltaCash'] as num? ?? 0) != 0).toList(growable: false);
    }
    if (_view == 'BANK') {
      return _txns.where((t) => (t['deltaBank'] as num? ?? 0) != 0).toList(growable: false);
    }
    return _txns;
  }
}

class _ViewChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ViewChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
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
