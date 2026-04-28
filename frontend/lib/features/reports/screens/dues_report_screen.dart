import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../bills/screens/upi_pay_sheet.dart';

class DuesReportScreen extends ConsumerStatefulWidget {
  const DuesReportScreen({super.key});

  @override
  ConsumerState<DuesReportScreen> createState() => _DuesReportScreenState();
}

class _DuesReportScreenState extends ConsumerState<DuesReportScreen> {
  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'SUPER_ADMIN'};

  bool get _isAdmin => _adminRoles.contains((ref.read(authProvider).user?.role ?? '').toUpperCase());

  final _client = DioClient();
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _allDues = [];
  String _filterStatus = 'ALL';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _client.dio.get('reports/dues');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _allDues = List<Map<String, dynamic>>.from(data['dues'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filteredDues {
    Iterable<Map<String, dynamic>> dues = _allDues;

    if (_filterStatus != 'ALL') {
      dues = dues.where((d) => (d['status'] ?? '').toString().toUpperCase() == _filterStatus);
    }

    if (_searchQuery.trim().isEmpty) return dues.toList();
    final q = _searchQuery.trim().toLowerCase();
    return dues.where((d) {
      final unit = (d['unitCode'] ?? '').toString().toLowerCase();
      final residents = (d['residents'] as List?) ?? [];
      final nameMatch = residents.any((r) => (r['name'] ?? '').toString().toLowerCase().contains(q));
      final phoneMatch = residents.any((r) => (r['phone'] ?? '').toString().contains(q));
      return unit.contains(q) || nameMatch || phoneMatch;
    }).toList();
  }

  Map<String, dynamic> get _computedSummary {
    final dues = _filteredDues;
    final totalRemaining = dues.fold<double>(0, (s, d) => s + ((d['remaining'] as num?)?.toDouble() ?? 0));
    final statusCounts = <String, int>{};
    for (final d in dues) {
      final s = (d['status'] ?? '').toString().toUpperCase();
      if (s.isEmpty) continue;
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }
    return {
      'totalRemaining': totalRemaining,
      'totalBills': dues.length,
      'statusCounts': statusCounts,
    };
  }

  Future<void> _sendReminder(Map<String, dynamic> due) async {
    try {
      await _client.dio.post('reports/dues/remind', data: {'billId': due['billId']});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder sent to Unit ${due['unitCode']}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reminder: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _sendRemindAll() async {
    final duesCount = _filteredDues.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminders to All?'),
        content: Text('This will send payment reminders to all $duesCount units with pending dues.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Send All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await _client.dio.post('reports/dues/remind-all');
      final sent = res.data['data']?['sent'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminders sent to $sent units'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy');
    final dues = _filteredDues;

    final totalRemaining = dues.fold<double>(0, (s, d) => s + ((d['remaining'] as num?)?.toDouble() ?? 0));
    final totalPaid = dues.fold<double>(0, (s, d) => s + ((d['paidAmount'] as num?)?.toDouble() ?? 0));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Pending Dues Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated: ${dateFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Total Pending: ${currFmt.format(totalRemaining)}  |  Bills: ${dues.length}  |  Collected: ${currFmt.format(totalPaid)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
        ],
      ),
      build: (ctx) => [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.3),
            5: const pw.FlexColumnWidth(1.3),
            6: const pw.FlexColumnWidth(1.3),
            7: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: ['Unit', 'Member', 'Phone', 'Month', 'Due', 'Paid', 'Pending', 'Status']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ))
                  .toList(),
            ),
            ...dues.map((d) {
              final residents = (d['residents'] as List?) ?? [];
              final primaryName = residents.isNotEmpty ? (residents[0]['name'] ?? '-') : '-';
              final primaryPhone = residents.isNotEmpty ? (residents[0]['phone'] ?? '-') : '-';
              final month = d['billingMonth'] != null
                  ? DateFormat('MMM yy').format(DateTime.parse(d['billingMonth'].toString()))
                  : '-';
              return pw.TableRow(children: [
                _pdfCell(d['unitCode'] ?? '-'),
                _pdfCell(primaryName.toString()),
                _pdfCell(primaryPhone.toString()),
                _pdfCell(month),
                _pdfCell(currFmt.format((d['amount'] as num?) ?? 0)),
                _pdfCell(currFmt.format((d['paidAmount'] as num?) ?? 0)),
                _pdfCell(currFmt.format((d['remaining'] as num?) ?? 0)),
                _pdfCell(d['status'] ?? '-'),
              ]);
            }),
          ],
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final dues = _filteredDues;

    final summary = _computedSummary;
    final totalRemaining = summary['totalRemaining'] ?? 0;
    final totalBills = summary['totalBills'] ?? 0;
    final statusCounts = summary['statusCounts'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(_isAdmin ? 'Pending Dues' : 'My Pending Bills', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Download PDF',
            onPressed: _allDues.isEmpty ? null : _exportPdf,
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.notifications_active_rounded, color: Colors.white),
              tooltip: 'Remind All',
              onPressed: _allDues.isEmpty ? null : _sendRemindAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load: $_error', style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary cards
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(AppDimensions.screenPadding),
                      child: Column(
                        children: [
                          // KPI row
                          Row(
                            children: [
                              _KpiPill(label: 'Total Pending', value: _currency.format(totalRemaining), color: AppColors.danger),
                              const SizedBox(width: AppDimensions.sm),
                              _KpiPill(label: 'Bills', value: '$totalBills', color: AppColors.warning),
                              const SizedBox(width: AppDimensions.sm),
                              _KpiPill(label: 'Overdue', value: '${statusCounts['OVERDUE'] ?? 0}', color: AppColors.danger),
                              if (isWide) ...[
                                const SizedBox(width: AppDimensions.sm),
                                _KpiPill(label: 'Partial', value: '${statusCounts['PARTIAL'] ?? 0}', color: AppColors.info),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppDimensions.md),

                          // Filter & search row
                          Builder(builder: (context) {
                            Widget chips() {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ['ALL', 'OVERDUE', 'PENDING', 'PARTIAL'].map((s) {
                                    final isActive = _filterStatus == s;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: FilterChip(
                                        label: Text(s == 'ALL' ? 'All' : s[0] + s.substring(1).toLowerCase()),
                                        selected: isActive,
                                        onSelected: (_) => setState(() => _filterStatus = s),
                                        selectedColor: AppColors.primarySurface,
                                        checkmarkColor: AppColors.primary,
                                        labelStyle: AppTextStyles.labelMedium.copyWith(
                                          color: isActive ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }

                            Widget search({double? width}) {
                              return SizedBox(
                                width: width,
                                height: 36,
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  style: AppTextStyles.bodySmall,
                                  decoration: InputDecoration(
                                    hintText: 'Search unit, name...',
                                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              );
                            }

                            if (isWide) {
                              return Row(
                                children: [
                                  Expanded(child: chips()),
                                  const SizedBox(width: AppDimensions.sm),
                                  search(width: 220),
                                ],
                              );
                            }

                            // Mobile: stack vertically to avoid overlap/overflow.
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                chips(),
                                const SizedBox(height: AppDimensions.sm),
                                search(),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: dues.isEmpty
                          ? const AppEmptyState(
                              emoji: '🎉',
                              title: 'All clear!',
                              subtitle: 'No pending dues found. Everyone has paid.',
                            )
                          : isWide
                              ? _DuesTable(dues: dues, currency: _currency, dateFmt: _dateFmt, onRemind: _sendReminder, isAdmin: _isAdmin, myUnitId: ref.read(authProvider).user?.unitId)
                              : _DuesList(dues: dues, currency: _currency, dateFmt: _dateFmt, onRemind: _sendReminder, isAdmin: _isAdmin, myUnitId: ref.read(authProvider).user?.unitId),
                    ),
                  ],
                ),
    );
  }
}

// ─── KPI Pill ────────────────────────────────────────────────────────────────

class _KpiPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md, horizontal: AppDimensions.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.h2.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ─── Helper: convert dues-report row to the bill map showPaySheet expects ───

Map<String, dynamic> _dueToBillMap(Map<String, dynamic> d) => {
      'id': d['billId'],
      'totalDue': d['amount'],
      'paidAmount': d['paidAmount'],
      'billingMonth': d['billingMonth'],
      'unit': {'fullCode': d['unitCode'] ?? '-'},
    };

// ─── Desktop Table ───────────────────────────────────────────────────────────

class _DuesTable extends StatelessWidget {
  final List<Map<String, dynamic>> dues;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final Future<void> Function(Map<String, dynamic>) onRemind;
  final bool isAdmin;
  final String? myUnitId;

  const _DuesTable({required this.dues, required this.currency, required this.dateFmt, required this.onRemind, required this.isAdmin, this.myUnitId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      child: AppCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
              child: Row(
                children: [
                  _thCell(context, 'Unit', flex: 2),
                  _thCell(context, 'Member', flex: 3),
                  _thCell(context, 'Phone', flex: 2),
                  _thCell(context, 'Month', flex: 2),
                  _thCell(context, 'Amount', flex: 2),
                  _thCell(context, 'Paid', flex: 2),
                  _thCell(context, 'Pending', flex: 2),
                  _thCell(context, 'Status', flex: 2),
                  _thCell(context, 'Action', flex: 2),
                ],
              ),
            ),
            // Rows
            ...dues.asMap().entries.map((entry) {
              final d = entry.value;
              final residents = (d['residents'] as List?) ?? [];
              final primary = residents.isNotEmpty ? residents[0] : null;
              final month = d['billingMonth'] != null
                  ? DateFormat('MMM yyyy').format(DateTime.parse(d['billingMonth'].toString()))
                  : '-';
              final status = d['status'] ?? 'PENDING';

              return Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
                  color: status == 'OVERDUE' ? AppColors.dangerSurface : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
                child: Row(
                  children: [
                    _tdCell(context, d['unitCode'] ?? '-', flex: 2, bold: true),
                    _tdCell(context, primary?['name'] ?? '-', flex: 3),
                    _tdCell(context, primary?['phone'] ?? '-', flex: 2),
                    _tdCell(context, month, flex: 2),
                    _tdCell(context, currency.format((d['amount'] as num?) ?? 0), flex: 2),
                    _tdCell(context, currency.format((d['paidAmount'] as num?) ?? 0), flex: 2, color: AppColors.success),
                    _tdCell(context, currency.format((d['remaining'] as num?) ?? 0), flex: 2, color: AppColors.danger, bold: true),
                    Expanded(flex: 2, child: _StatusBadge(status: status)),
                    Expanded(
                      flex: 2,
                      child: myUnitId != null && d['unitId'] == myUnitId
                          ? SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: () => showPaySheet(context, bill: _dueToBillMap(d)),
                                icon: const Icon(Icons.payment_rounded, size: 16),
                                label: const Text('Pay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  textStyle: AppTextStyles.labelSmall,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
                                ),
                              ),
                            )
                          : isAdmin
                              ? Row(
                                  children: [
                                    Tooltip(
                                      message: 'Send payment reminder',
                                      child: IconButton(
                                        icon: const Icon(Icons.notifications_active_rounded, size: 18),
                                        color: AppColors.warning,
                                        onPressed: () => onRemind(d),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _thCell(BuildContext context, String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted)),
    );
  }

  Widget _tdCell(BuildContext context, String text, {int flex = 1, bool bold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Mobile List ─────────────────────────────────────────────────────────────

class _DuesList extends StatelessWidget {
  final List<Map<String, dynamic>> dues;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final Future<void> Function(Map<String, dynamic>) onRemind;
  final bool isAdmin;
  final String? myUnitId;

  const _DuesList({required this.dues, required this.currency, required this.dateFmt, required this.onRemind, required this.isAdmin, this.myUnitId});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      itemCount: dues.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (ctx, i) {
        final d = dues[i];
        final residents = (d['residents'] as List?) ?? [];
        final primary = residents.isNotEmpty ? residents[0] : null;
        final status = (d['status'] ?? 'PENDING').toString().toUpperCase();
        final month = d['billingMonth'] != null
            ? DateFormat('MMM yyyy').format(DateTime.parse(d['billingMonth'].toString()))
            : '-';
        final remaining = (d['remaining'] as num?)?.toDouble() ?? 0;

        return AppCard(
          backgroundColor: status == 'OVERDUE' ? AppColors.dangerSurface : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: unit + status + remind button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Text(
                      d['unitCode'] ?? '-',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  _StatusBadge(status: status),
                  const Spacer(),
                  if (isAdmin && !(myUnitId != null && d['unitId'] == myUnitId))
                    SizedBox(
                      height: 30,
                      child: OutlinedButton.icon(
                        onPressed: () => onRemind(d),
                        icon: const Icon(Icons.notifications_active_rounded, size: 14),
                        label: const Text('Remind'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: AppTextStyles.labelSmall,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              // Member info
              if (primary != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primarySurface,
                      child: Text(
                        (primary['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(primary['name'] ?? '-', style: AppTextStyles.h3),
                          Text(primary['phone'] ?? '-', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppDimensions.md),

              // Amount details
              Row(
                children: [
                  _AmountCell(label: 'Month', value: month, color: Theme.of(context).colorScheme.onSurface),
                  _AmountCell(label: 'Due', value: currency.format((d['amount'] as num?) ?? 0), color: Theme.of(context).colorScheme.onSurface),
                  _AmountCell(label: 'Paid', value: currency.format((d['paidAmount'] as num?) ?? 0), color: AppColors.success),
                  _AmountCell(label: 'Pending', value: currency.format(remaining), color: AppColors.danger, bold: true),
                ],
              ),

              // Pay button for own unit
              if (!isAdmin || (myUnitId != null && d['unitId'] == myUnitId)) ...[
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => showPaySheet(context, bill: _dueToBillMap(d)),
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: AppTextStyles.labelMedium,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
                    ),
                  ),
                ),
              ],

              // Additional residents
              if (residents.length > 1) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(
                  '+${residents.length - 1} more resident(s)',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AmountCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _AmountCell({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.labelMedium.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toUpperCase()) {
      case 'OVERDUE':
        bg = AppColors.dangerSurface; fg = AppColors.danger;
        break;
      case 'PARTIAL':
        bg = AppColors.infoSurface; fg = AppColors.info;
        break;
      default:
        bg = AppColors.warningSurface; fg = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        status[0] + status.substring(1).toLowerCase(),
        style: AppTextStyles.labelSmall.copyWith(color: fg),
      ),
    );
  }
}
