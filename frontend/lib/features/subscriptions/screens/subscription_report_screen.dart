import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_date_picker.dart';

class SubscriptionReportScreen extends StatefulWidget {
  const SubscriptionReportScreen({super.key});

  @override
  State<SubscriptionReportScreen> createState() => _SubscriptionReportScreenState();
}

class _SubscriptionReportScreenState extends State<SubscriptionReportScreen> {
  final _client = DioClient();
  final _searchC = TextEditingController();

  DateTimeRange? _range;
  String _plan = '';
  String _paymentMethod = '';

  String _orderBy = 'createdAt';
  bool _asc = false;

  int _page = 1;
  final int _limit = 50;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  int _total = 0;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _date = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _page = page;
    });
    try {
      final qp = <String, dynamic>{
        'page': _page,
        'limit': _limit,
        'orderBy': _orderBy,
        'orderDir': _asc ? 'asc' : 'desc',
      };
      if (_range != null) {
        qp['from'] = DateTime(_range!.start.year, _range!.start.month, _range!.start.day)
            .toIso8601String();
        qp['to'] = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59)
            .toIso8601String();
      }
      if (_plan.isNotEmpty) qp['planName'] = _plan;
      if (_paymentMethod.isNotEmpty) qp['paymentMethod'] = _paymentMethod;
      final s = _searchC.text.trim();
      if (s.isNotEmpty) qp['search'] = s;

      final res = await _client.dio.get('/subscriptions/report', queryParameters: qp);
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data['rows'] ?? const []);
        _total = (data['total'] ?? 0) as int;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load report';
        _loading = false;
      });
    }
  }

  void _toggleSort(String key) {
    setState(() {
      if (_orderBy == key) {
        _asc = !_asc;
      } else {
        _orderBy = key;
        _asc = false;
      }
    });
    _load(page: 1);
  }

  Future<void> _downloadPdf() async {
    final doc = pw.Document();
    
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Subscription Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            if (_range != null)
              pw.Text('Date Range: ${_date.format(_range!.start)} to ${_date.format(_range!.end)}'),
            if (_plan.isNotEmpty) pw.Text('Plan: $_plan'),
            if (_paymentMethod.isNotEmpty) pw.Text('Payment Method: $_paymentMethod'),
            if (_searchC.text.isNotEmpty) pw.Text('Search: ${_searchC.text}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Society', 'Plan', 'Period', 'Amount', 'Payment', 'Txn ID'],
              data: [
                for (final r in _rows)
                  [
                    _date.format(r['createdAt'] is String ? DateTime.tryParse(r['createdAt']) ?? DateTime.now() : DateTime.now()),
                    (r['society']?['name'] ?? '-').toString(),
                    (r['plan']?['displayName'] ?? r['plan']?['name'] ?? '-').toString(),
                    '${_date.format(r['periodStart'] is String ? DateTime.tryParse(r['periodStart']) ?? DateTime.now() : DateTime.now())} to ${_date.format(r['periodEnd'] is String ? DateTime.tryParse(r['periodEnd']) ?? DateTime.now() : DateTime.now())}',
                    'Rs. ${num.tryParse(r['amount']?.toString() ?? '0') ?? 0}',
                    (r['paymentMethod'] ?? '-').toString(),
                    (r['reference'] ?? '-').toString(),
                  ],
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'subscription_report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subscription Report', style: AppTextStyles.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Date-wise payments with filters and sorting',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _rows.isEmpty ? null : _downloadPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Download PDF'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => _load(page: _page),
                    icon: const Icon(Icons.refresh_rounded),
                  )
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Filters
            if (isMobile)
              _buildMobileFilters()
            else
              _buildDesktopFilters(),

            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger)))
                      : _rows.isEmpty
                          ? const AppEmptyState(
                              emoji: '📄',
                              title: 'No data',
                              subtitle: 'Try adjusting filters.',
                            )
                          : isMobile 
                              ? _buildMobileList()
                              : _buildDesktopTable(),
            ),
            if (_total > _limit)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                      child: const Text('Previous'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Page $_page', style: AppTextStyles.labelLarge),
                    ),
                    TextButton(
                      onPressed: _page * _limit < _total ? () => _load(page: _page + 1) : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFilters() {
    final hasFilters =
        _range != null || _plan.isNotEmpty || _paymentMethod.isNotEmpty || _searchC.text.trim().isNotEmpty;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    decoration: const InputDecoration(
                      hintText: 'Search society',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(page: 1),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Download PDF',
                  onPressed: _rows.isEmpty ? null : _downloadPdf,
                  icon: const Icon(Icons.download_rounded),
                  color: AppColors.primary,
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _load(page: _page),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final isTwoCol = w >= 440;
                final gap = 12.0;
                final itemW = isTwoCol ? (w - gap) / 2 : w;

                return Wrap(
                  runSpacing: 12,
                  spacing: gap,
                  children: [
                    SizedBox(
                      width: itemW,
                      child: AppDateRangeField(
                        label: 'Date Range',
                        from: _range?.start,
                        to: _range?.end,
                        clearable: true,
                        onClear: () {
                          setState(() => _range = null);
                          _load(page: 1);
                        },
                        onTap: () async {
                          final picked = await pickDateRange(
                            context,
                            initialFrom: _range?.start,
                            initialTo: _range?.end,
                          );
                          if (picked != null) {
                            setState(() => _range = picked);
                            _load(page: 1);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemW,
                      child: DropdownButtonFormField<String>(
                        value: _plan,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Plan',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All Plans')),
                          DropdownMenuItem(value: 'basic', child: Text('Basic')),
                          DropdownMenuItem(value: 'standard', child: Text('Standard')),
                          DropdownMenuItem(value: 'premium', child: Text('Premium')),
                        ],
                        onChanged: (v) {
                          setState(() => _plan = v ?? '');
                          _load(page: 1);
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemW,
                      child: DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment type',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All Payment Types')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                          DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(value: 'RAZORPAY', child: Text('Razorpay')),
                        ],
                        onChanged: (v) {
                          setState(() => _paymentMethod = v ?? '');
                          _load(page: 1);
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemW,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$_total rows',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (hasFilters)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _range = null;
                          _plan = '';
                          _paymentMethod = '';
                          _searchC.clear();
                        });
                        _load(page: 1);
                      },
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('Clear filters'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopFilters() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          runSpacing: 10,
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchC,
                decoration: const InputDecoration(
                  labelText: 'Search society',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _load(page: 1),
              ),
            ),
            AppDateRangeField(
              label: 'Date Range',
              from: _range?.start,
              to: _range?.end,
              clearable: true,
              onClear: () { setState(() => _range = null); _load(page: 1); },
              onTap: () async {
                final picked = await pickDateRange(
                  context,
                  initialFrom: _range?.start,
                  initialTo: _range?.end,
                );
                if (picked != null) {
                  setState(() => _range = picked);
                  _load(page: 1);
                }
              },
            ),
            DropdownButton<String>(
              value: _plan,
              items: const [
                DropdownMenuItem(value: '', child: Text('All Plans')),
                DropdownMenuItem(value: 'basic', child: Text('Basic')),
                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                DropdownMenuItem(value: 'premium', child: Text('Premium')),
              ],
              onChanged: (v) {
                setState(() => _plan = v ?? '');
                _load(page: 1);
              },
            ),
            DropdownButton<String>(
              value: _paymentMethod,
              items: const [
                DropdownMenuItem(value: '', child: Text('All Payment Types')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'RAZORPAY', child: Text('Razorpay')),
              ],
              onChanged: (v) {
                setState(() => _paymentMethod = v ?? '');
                _load(page: 1);
              },
            ),
            if (_range != null || _plan.isNotEmpty || _paymentMethod.isNotEmpty || _searchC.text.trim().isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _range = null;
                    _plan = '';
                    _paymentMethod = '';
                    _searchC.clear();
                  });
                  _load(page: 1);
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear'),
              ),
            const SizedBox(width: 8),
            Text('$_total rows', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SortChip(
                          label: 'Date',
                          active: _orderBy == 'createdAt',
                          asc: _asc,
                          onTap: () => _toggleSort('createdAt'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Society',
                          active: _orderBy == 'societyName',
                          asc: _asc,
                          onTap: () => _toggleSort('societyName'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Plan',
                          active: _orderBy == 'planName',
                          asc: _asc,
                          onTap: () => _toggleSort('planName'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Amount',
                          active: _orderBy == 'amount',
                          asc: _asc,
                          onTap: () => _toggleSort('amount'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final r = _rows[index];
                final society = r['society'] as Map? ?? {};
                final plan = r['plan'] as Map? ?? {};
                final createdAt = r['createdAt'] is String
                    ? DateTime.tryParse(r['createdAt']) ?? DateTime.now()
                    : DateTime.now();
                final ps = r['periodStart'] is String ? DateTime.tryParse(r['periodStart']) ?? createdAt : createdAt;
                final pe = r['periodEnd'] is String ? DateTime.tryParse(r['periodEnd']) ?? createdAt : createdAt;
                final amt = num.tryParse(r['amount']?.toString() ?? '0') ?? 0;
                final payment = (r['paymentMethod'] ?? '-').toString();
                final txn = (r['reference'] ?? '-').toString();
                final notes = (r['notes'] ?? '').toString().trim();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (society['name'] ?? '-').toString(),
                              style: AppTextStyles.h3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currency.format(amt),
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.infoSurface,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Text(
                              (plan['displayName'] ?? plan['name'] ?? '-').toString(),
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.info),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            payment,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_date.format(createdAt)}  •  ${_date.format(ps)} → ${_date.format(pe)}',
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              txn.isEmpty ? '-' : txn,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1200),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              sortAscending: _asc,
              sortColumnIndex: _sortIndex(),
              columns: [
                DataColumn(
                  label: const Text('Date'),
                  onSort: (_, __) => _toggleSort('createdAt'),
                ),
                DataColumn(
                  label: const Text('Society'),
                  onSort: (_, __) => _toggleSort('societyName'),
                ),
                DataColumn(
                  label: const Text('Plan'),
                  onSort: (_, __) => _toggleSort('planName'),
                ),
                DataColumn(
                  label: const Text('Period'),
                  onSort: (_, __) => _toggleSort('periodEnd'),
                ),
                DataColumn(
                  numeric: true,
                  label: const Text('Amount'),
                  onSort: (_, __) => _toggleSort('amount'),
                ),
                const DataColumn(label: Text('Payment')),
                const DataColumn(label: Text('Txn ID')),
                const DataColumn(label: Text('Notes')),
              ],
              rows: _rows.map((r) {
                final society = r['society'] as Map? ?? {};
                final plan = r['plan'] as Map? ?? {};
                final createdAt = r['createdAt'] is String
                    ? DateTime.tryParse(r['createdAt']) ?? DateTime.now()
                    : DateTime.now();
                final ps = r['periodStart'] is String
                    ? DateTime.tryParse(r['periodStart']) ?? createdAt
                    : createdAt;
                final pe = r['periodEnd'] is String
                    ? DateTime.tryParse(r['periodEnd']) ?? createdAt
                    : createdAt;
                final amt = num.tryParse(r['amount']?.toString() ?? '0') ?? 0;
                return DataRow(cells: [
                  DataCell(Text(_date.format(createdAt))),
                  DataCell(Text((society['name'] ?? '-').toString())),
                  DataCell(Text((plan['displayName'] ?? plan['name'] ?? '-').toString())),
                  DataCell(Text('${_date.format(ps)} → ${_date.format(pe)}')),
                  DataCell(Text(_currency.format(amt))),
                  DataCell(Text((r['paymentMethod'] ?? '-').toString())),
                  DataCell(Text((r['reference'] ?? '-').toString())),
                  DataCell(Text((r['notes'] ?? '').toString(), overflow: TextOverflow.ellipsis)),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  int? _sortIndex() {
    switch (_orderBy) {
      case 'createdAt':
        return 0;
      case 'societyName':
        return 1;
      case 'planName':
        return 2;
      case 'periodEnd':
        return 3;
      case 'amount':
        return 4;
      default:
        return null;
    }
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool asc;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.active,
    required this.asc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySurface : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.35) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: fg)),
            if (active) ...[
              const SizedBox(width: 6),
              Icon(asc ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

