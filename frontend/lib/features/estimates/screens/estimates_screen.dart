import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/estimates_provider.dart';
import '../../plans/providers/plans_provider.dart';
import '../../../shared/widgets/show_app_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';

class EstimatesScreen extends ConsumerStatefulWidget {
  const EstimatesScreen({super.key});

  @override
  ConsumerState<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends ConsumerState<EstimatesScreen> {
  String _statusFilter = '';
  final _searchC = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  static const _statusColors = {
    'DRAFT':    Color(0xFF6B7280),
    'SENT':     Color(0xFF2563EB),
    'ACCEPTED': Color(0xFF10B981),
    'REJECTED': Color(0xFFEF4444),
    'CLOSED':   Color(0xFF94A3B8),
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(estimatesProvider.notifier).loadEstimates();
      ref.read(plansProvider.notifier).loadPlans();
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _refresh() => ref.read(estimatesProvider.notifier).loadEstimates(
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        search: _searchC.text.trim().isNotEmpty ? _searchC.text.trim() : null,
      );

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? fallback;
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '—';
    final s = iso.toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  String _estimateNo(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isNotEmpty ? s : 'ESTIMATE';
  }

  Future<Uint8List> _buildEstimatePdfBytes({
    required String societyName,
    required Map<String, dynamic> e,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

    final status = (e['status'] ?? 'DRAFT').toString();
    final estimateNo = _estimateNo(e['estimateNumber']);
    final createdAt = _fmtDate(e['createdAt']);
    final planName = e['plan']?['displayName'] ?? e['plan']?['name'] ?? '—';
    final duration = (e['duration'] ?? 'MONTHLY').toString().replaceAll('_', ' ');
    final units = _asNum(e['unitCount']).toInt();
    final disc = _asNum(e['discountPercent']);
    final total = _asNum(e['totalAmount']);

    final contactPerson = (e['contactPerson'] ?? '').toString().trim();
    final phone = (e['contactPhone'] ?? '').toString().trim();
    final email = (e['contactEmail'] ?? '').toString().trim();
    final city = (e['city'] ?? '').toString().trim();
    final notes = (e['notes'] ?? '').toString().trim();

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
        build: (_) => pw.Column(
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
                    'Estimate',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Quotation / pricing summary',
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
                              pw.Text('Estimate No.',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                estimateNo,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: const PdfColor.fromInt(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Total',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                currency.format(total),
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: const PdfColor.fromInt(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    row('Status', status),
                    row('Created', createdAt),
                    row('Society', (e['societyName'] ?? '—').toString()),
                    row('Plan', planName.toString()),
                    row('Duration', duration),
                    row('Units', units.toString()),
                    if (disc > 0) row('Discount', '${disc.toString()}%'),
                    row('Total Amount', currency.format(total)),
                    if (contactPerson.isNotEmpty) row('Contact Person', contactPerson),
                    if (phone.isNotEmpty) row('Phone', phone),
                    if (email.isNotEmpty) row('Email', email),
                    if (city.isNotEmpty) row('City', city),
                    if (notes.isNotEmpty) row('Notes', notes),
                    pw.SizedBox(height: 18),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8EAF6)),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Text(
                        'This is a computer-generated estimate.',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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

  Future<void> _printEstimate(Map<String, dynamic> estimate) async {
    final user = ref.read(authProvider).user;
    final societyName = (user?.societyName ?? '').trim();
    await Printing.layoutPdf(
      onLayout: (_) => _buildEstimatePdfBytes(societyName: societyName, e: estimate),
    );
  }

  Future<void> _downloadEstimatePdf(Map<String, dynamic> estimate) async {
    final user = ref.read(authProvider).user;
    final societyName = (user?.societyName ?? '').trim();
    final bytes = await _buildEstimatePdfBytes(societyName: societyName, e: estimate);
    final no = _estimateNo(estimate['estimateNumber']).replaceAll(' ', '_');
    await Printing.sharePdf(bytes: bytes, filename: 'estimate_$no.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(estimatesProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showCreateEditSheet(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (!isMobile)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimates', style: AppTextStyles.displayMedium),
                        const SizedBox(height: 4),
                        Text('Pre-sales CRM — create, send and track estimates', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showCreateEditSheet(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Estimate'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Search + filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    decoration: const InputDecoration(
                      hintText: 'Search society, contact, EST-…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in const {
                    '': 'All',
                    'DRAFT': 'Draft',
                    'SENT': 'Sent',
                    'ACCEPTED': 'Accepted',
                    'REJECTED': 'Rejected',
                    'CLOSED': 'Closed',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _statusFilter == entry.key,
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: _statusFilter == entry.key ? AppColors.primary : AppColors.textMuted,
                        ),
                        onSelected: (_) {
                          setState(() => _statusFilter = entry.key);
                          _refresh();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // List
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.estimates.isEmpty
                      ? const AppEmptyState(
                          emoji: '📝',
                          title: 'No Estimates',
                          subtitle: 'Create your first estimate to get started.',
                        )
                      : ListView.separated(
                          itemCount: state.estimates.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _EstimateCard(
                            estimate: state.estimates[i],
                            currencyFormat: currencyFormat,
                            dateFormat: dateFormat,
                            statusColors: _statusColors,
                            onEdit: () => _showCreateEditSheet(estimate: state.estimates[i]),
                            onPrint: () => _printEstimate(state.estimates[i]),
                            onDownload: () => _downloadEstimatePdf(state.estimates[i]),
                            onSend: () => _confirmAction(
                              state.estimates[i]['id'],
                              'Send Estimate',
                              'Mark "${state.estimates[i]['estimateNumber']}" as Sent?',
                              () => ref.read(estimatesProvider.notifier).sendEstimate(state.estimates[i]['id']),
                            ),
                            onAccept: () => _confirmAction(
                              state.estimates[i]['id'],
                              'Accept Estimate',
                              'Mark "${state.estimates[i]['estimateNumber']}" as Accepted?',
                              () => ref.read(estimatesProvider.notifier).acceptEstimate(state.estimates[i]['id']),
                            ),
                            onClose: () => _showCloseDialog(state.estimates[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAction(String id, String title, String message, Future<bool> Function() action) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTextStyles.h1),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await action();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? '$title successful' : 'Action failed')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(Map<String, dynamic> estimate) {
    final reasonC = TextEditingController();
    String targetStatus = 'CLOSED';
    final estStatus = (estimate['status'] ?? '').toString();

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Close Estimate', style: AppTextStyles.h1),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${estimate['estimateNumber']} — ${estimate['societyName']}'),
              const SizedBox(height: 14),
              if (estStatus == 'SENT') ...[
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'REJECTED', label: Text('Rejected')),
                    ButtonSegment(value: 'CLOSED', label: Text('Closed')),
                  ],
                  selected: {targetStatus},
                  onSelectionChanged: (s) => setS(() => targetStatus = s.first),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: reasonC,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'e.g. Client chose a competitor / Budget not approved',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                if (reasonC.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final err = await ref.read(estimatesProvider.notifier)
                    .closeEstimate(estimate['id'], reasonC.text.trim(), status: targetStatus);
                if (!mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                }
              },
              child: Text(targetStatus == 'REJECTED' ? 'Reject' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateEditSheet({Map<String, dynamic>? estimate}) {
    final isEdit = estimate != null;
    final plans = ref.read(plansProvider).plans;

    final nameC = TextEditingController(text: estimate?['societyName'] ?? '');
    final personC = TextEditingController(text: estimate?['contactPerson'] ?? '');
    final phoneC = TextEditingController(text: estimate?['contactPhone'] ?? '');
    final emailC = TextEditingController(text: estimate?['contactEmail'] ?? '');
    final cityC = TextEditingController(text: estimate?['city'] ?? '');
    final unitsC = TextEditingController(text: estimate?['unitCount']?.toString() ?? '');
    final discC = TextEditingController(text: estimate?['discountPercent']?.toString() ?? '0');
    final notesC = TextEditingController(text: estimate?['notes'] ?? '');

    String planId = estimate?['plan']?['id'] ?? (plans.isNotEmpty ? plans.first['id'] : '');
    String duration = estimate?['duration'] ?? 'MONTHLY';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final planItems = plans.map((p) =>
            AppDropdownItem<String>(value: p['id'] as String, label: p['displayName'] ?? p['name'] ?? ''),
          ).toList();

          num _asNum(dynamic v, {num fallback = 0}) {
            if (v == null) return fallback;
            if (v is num) return v;
            return num.tryParse(v.toString()) ?? fallback;
          }

          List<Map<String, dynamic>> _tiersForPlan(Map<String, dynamic>? plan) {
            final raw = plan?['pricingTiers'];
            if (raw is! List) return const [];
            final tiers = raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            tiers.sort((a, b) => _asNum(a['minUnits']).compareTo(_asNum(b['minUnits'])));
            return tiers;
          }

          num _unitPriceFor({required Map<String, dynamic>? plan, required int units}) {
            if (plan == null) return 0;
            final tiers = _tiersForPlan(plan);
            for (final t in tiers) {
              final min = _asNum(t['minUnits']).toInt();
              final max = _asNum(t['maxUnits']).toInt();
              final inRange = units >= min && (max == -1 || units <= max);
              if (inRange) return _asNum(t['pricePerUnit']);
            }
            return _asNum(plan['pricePerUnit']);
          }

          ({int months, num durationDiscountPct, String label}) _durationMeta(String d) {
            switch (d) {
              case 'THREE_MONTHS':
                return (months: 3, durationDiscountPct: 5, label: '3 Months');
              case 'SIX_MONTHS':
                return (months: 6, durationDiscountPct: 10, label: '6 Months');
              case 'YEARLY':
                return (months: 12, durationDiscountPct: 20, label: 'Yearly');
              default:
                return (months: 1, durationDiscountPct: 0, label: 'Monthly');
            }
          }

          final units = int.tryParse(unitsC.text.trim()) ?? 0;
          final extraDiscPct = (double.tryParse(discC.text.trim()) ?? 0).clamp(0, 100);
          final selectedPlan = plans.cast<Map<String, dynamic>?>().firstWhere(
                (p) => (p?['id']?.toString() ?? '') == planId,
                orElse: () => null,
              );
          final meta = _durationMeta(duration);
          final unitPrice = _unitPriceFor(plan: selectedPlan, units: units);
          final subtotal = units * unitPrice * meta.months;
          final afterDuration = subtotal * (1 - (meta.durationDiscountPct / 100));
          final total = afterDuration * (1 - (extraDiscPct / 100));

          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.97,
            expand: false,
            builder: (_, scrollC) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(isEdit ? 'Edit Estimate' : 'New Estimate', style: AppTextStyles.h2),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollC,
                      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                      children: [
                        _field(nameC, 'Society Name *'),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(personC, 'Contact Person')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(phoneC, 'Phone', inputType: TextInputType.phone)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(emailC, 'Email', inputType: TextInputType.emailAddress)),
                          const SizedBox(width: 12),
                          Expanded(child: _field(cityC, 'City')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: _field(
                              unitsC,
                              'Unit Count *',
                              inputType: TextInputType.number,
                              onChanged: (_) => setS(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              discC,
                              'Discount %',
                              inputType: TextInputType.number,
                              onChanged: (_) => setS(() {}),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        if (planItems.isNotEmpty)
                          AppSearchableDropdown<String>(
                            label: 'Plan *',
                            value: planId.isNotEmpty ? planId : null,
                            items: planItems,
                            onChanged: (v) => setS(() => planId = v ?? planId),
                          ),
                        const SizedBox(height: 12),
                        AppSearchableDropdown<String>(
                          label: 'Duration',
                          value: duration,
                          items: const [
                            AppDropdownItem(value: 'MONTHLY', label: 'Monthly'),
                            AppDropdownItem(value: 'THREE_MONTHS', label: '3 Months (5% off)'),
                            AppDropdownItem(value: 'SIX_MONTHS', label: '6 Months (10% off)'),
                            AppDropdownItem(value: 'YEARLY', label: 'Yearly (20% off)'),
                          ],
                          onChanged: (v) => setS(() => duration = v ?? duration),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total (live)', style: AppTextStyles.labelLarge),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      units > 0
                                          ? '₹${unitPrice.toStringAsFixed(unitPrice % 1 == 0 ? 0 : 2)}/unit/mo'
                                          : 'Enter Unit Count to preview',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(total),
                                    style: AppTextStyles.amountLarge.copyWith(
                                      fontSize: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _pill('Units', units > 0 ? '$units' : '—'),
                                  _pill('Duration', '${meta.label} (${meta.months} mo)'),
                                  _pill('Duration off', meta.durationDiscountPct > 0 ? '${meta.durationDiscountPct}%' : '—'),
                                  _pill('Extra off', extraDiscPct > 0 ? '${extraDiscPct.toStringAsFixed(extraDiscPct % 1 == 0 ? 0 : 1)}%' : '—'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field(notesC, 'Notes', maxLines: 3),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () async {
                            if (nameC.text.trim().isEmpty || unitsC.text.trim().isEmpty || planId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Society Name, Unit Count and Plan are required')),
                              );
                              return;
                            }
                            final data = {
                              'societyName': nameC.text.trim(),
                              'contactPerson': personC.text.trim().isEmpty ? null : personC.text.trim(),
                              'contactPhone': phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                              'contactEmail': emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                              'city': cityC.text.trim().isEmpty ? null : cityC.text.trim(),
                              'unitCount': int.tryParse(unitsC.text.trim()) ?? 0,
                              'planId': planId,
                              'duration': duration,
                              'discountPercent': double.tryParse(discC.text.trim()) ?? 0,
                              'notes': notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                            };
                            Navigator.pop(ctx);
                            if (isEdit) {
                              await ref.read(estimatesProvider.notifier).updateEstimate(estimate['id'] as String, data);
                            } else {
                              final created = await ref.read(estimatesProvider.notifier).createEstimate(data);
                              if (created == null && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to create estimate')),
                                );
                              }
                            }
                          },
                          child: Text(isEdit ? 'Update Estimate' : 'Create Estimate'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? inputType, int maxLines = 1, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        keyboardType: inputType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
        ),
        onChanged: onChanged,
      );

  Widget _pill(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          '$k: $v',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      );
}

// ── Estimate card ─────────────────────────────────────────────────────

class _EstimateCard extends StatelessWidget {
  final Map<String, dynamic> estimate;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final Map<String, Color> statusColors;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDownload;
  final VoidCallback onSend;
  final VoidCallback onAccept;
  final VoidCallback onClose;

  const _EstimateCard({
    required this.estimate,
    required this.currencyFormat,
    required this.dateFormat,
    required this.statusColors,
    required this.onEdit,
    required this.onPrint,
    required this.onDownload,
    required this.onSend,
    required this.onAccept,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final status = (estimate['status'] ?? 'DRAFT').toString();
    final sColor = statusColors[status] ?? AppColors.textMuted;
    num _asNum(dynamic v, {num fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? fallback;
    }

    String _fmtNum(num n) => (n % 1 == 0) ? n.toInt().toString() : n.toString();

    final amount = _asNum(estimate['totalAmount']);
    final units = _asNum(estimate['unitCount']);
    final disc = _asNum(estimate['discountPercent']);
    final planName = estimate['plan']?['displayName'] ?? estimate['plan']?['name'] ?? '-';
    final createdAt = estimate['createdAt'] != null
        ? dateFormat.format(DateTime.parse(estimate['createdAt'] as String))
        : '-';
    final closeReason = estimate['closeReason'] as String?;
    final isLinked = estimate['linkedSocietyId'] != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: sColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(estimate['estimateNumber'] ?? '', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status, style: AppTextStyles.labelSmall.copyWith(color: sColor)),
                ),
                if (isLinked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, size: 11, color: AppColors.success),
                        SizedBox(width: 3),
                        Text('Linked', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: onPrint,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.print_outlined, size: 16, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onDownload,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.download_outlined, size: 16, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 6),
                if (['DRAFT', 'SENT'].contains(status))
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Society name
            Text(estimate['societyName'] ?? '-', style: AppTextStyles.h3),
            if (estimate['contactPerson'] != null || estimate['city'] != null)
              Text(
                [estimate['contactPerson'], estimate['city']].where((e) => e != null).join(' • '),
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            const SizedBox(height: 8),

            // Details row
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _detail(Icons.apartment_outlined, '${_fmtNum(units)} units'),
                _detail(Icons.credit_card_outlined, planName),
                _detail(Icons.calendar_month_outlined, estimate['duration']?.toString().replaceAll('_', ' ') ?? 'MONTHLY'),
                if (disc > 0) _detail(Icons.discount_outlined, '${_fmtNum(disc)}% off'),
              ],
            ),
            const SizedBox(height: 8),

            // Amount + date
            Row(
              children: [
                Text(currencyFormat.format(amount),
                    style: AppTextStyles.amountLarge.copyWith(fontSize: 18, color: sColor)),
                const Spacer(),
                Text('Created $createdAt', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),

            // Close reason
            if (closeReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 13, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(closeReason, style: const TextStyle(fontSize: 12, color: AppColors.danger))),
                  ],
                ),
              ),
            ],

            // Actions
            if (!['CLOSED', 'REJECTED'].contains(status)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (status == 'DRAFT')
                    _actionBtn('Send', Icons.send_outlined, AppColors.primary, onSend),
                  if (status == 'SENT')
                    _actionBtn('Accept', Icons.check_circle_outline, AppColors.success, onAccept),
                  if (['DRAFT', 'SENT'].contains(status))
                    _actionBtn('Close', Icons.close_rounded, AppColors.danger, onClose),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
    ],
  );

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}
