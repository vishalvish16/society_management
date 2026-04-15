import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _load(page: _page),
                  icon: const Icon(Icons.refresh_rounded),
                )
              ],
            ),
            const SizedBox(height: 16),
            Card(
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
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDateRange: _range,
                        );
                        if (picked != null) {
                          setState(() => _range = picked);
                          _load(page: 1);
                        }
                      },
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        _range == null
                            ? 'Date range'
                            : '${_date.format(_range!.start)} → ${_date.format(_range!.end)}',
                      ),
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
            ),
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
                          : SingleChildScrollView(
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
                            ),
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

