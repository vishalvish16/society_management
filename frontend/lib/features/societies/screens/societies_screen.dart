import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/societies_provider.dart';
import '../../visitors/providers/visitor_config_provider.dart';
import '../../plans/providers/plans_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/show_app_dialog.dart';
import '../../estimates/providers/estimates_provider.dart';

class SocietiesScreen extends ConsumerStatefulWidget {
  const SocietiesScreen({super.key});

  @override
  ConsumerState<SocietiesScreen> createState() => _SocietiesScreenState();
}

class _SocietiesScreenState extends ConsumerState<SocietiesScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(societiesProvider.notifier).loadSocieties();
      ref.read(plansProvider.notifier).loadPlans();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    ref
        .read(societiesProvider.notifier)
        .loadSocieties(
          search: _searchController.text.trim(),
          status: _statusFilter.isNotEmpty ? _statusFilter : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(societiesProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;
    final activeCount = state.societies
        .where((s) => s['status'] == 'ACTIVE')
        .length;
    final suspendedCount = state.societies
        .where((s) => s['status'] == 'SUSPENDED')
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showRegisterStepper(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - desktop only
            if (!isMobile)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Societies',
                          style: AppTextStyles.displayMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage all registered societies',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showRegisterStepper(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Register Society'),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            _StatsRow(
              isMobile: isMobile,
              total: state.total,
              active: activeCount,
              suspended: suspendedCount,
            ),
            const SizedBox(height: 20),

            // Search & Filter Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _search();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,

                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Status')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'SUSPENDED',
                        child: Text('Suspended'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _statusFilter = val ?? '');
                      _search();
                    },
                  ),
                ),

              ],
                  ),
            const SizedBox(height: 16),

            // Total count
            Text(
              '${state.total} societies found',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? Center(
                      child: Text(
                        state.error!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    )
                  : state.societies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.apartment_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No societies found',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : isMobile
                  ? ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: state.societies.length,
                      itemBuilder: (context, index) {
                        final s = state.societies[index];
                        return _SocietyCard(
                          society: s,
                          onView: () => _showDetailDialog(s['id']),
                          onEdit: () => _showCreateDialog(context, society: s),
                          onResetPassword: () => _showResetPasswordDialog(
                            s['id'],
                            s['name'],
                            s['chairman']?['name'],
                          ),
                          onToggleStatus: () => _confirmToggleStatus(
                            s['id'],
                            s['status'] == 'ACTIVE',
                          ),
                          onSettings: () => _showSocietySettingsDialog(
                            s['id'],
                            s['name'],
                            s['settings'],
                          ),
                        );
                      },
                    )
                  : _buildDesktopTable(state),
            ),

            // Pagination
            if (state.total > 20)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: state.page > 1
                          ? () => ref
                                .read(societiesProvider.notifier)
                                .loadSocieties(
                                  page: state.page - 1,
                                  search: _searchController.text,
                                  status: _statusFilter.isNotEmpty
                                      ? _statusFilter
                                      : null,
                                )
                          : null,
                      child: const Text('Previous'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Page ${state.page}',
                        style: AppTextStyles.labelLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: state.page * 20 < state.total
                          ? () => ref
                                .read(societiesProvider.notifier)
                                .loadSocieties(
                                  page: state.page + 1,
                                  search: _searchController.text,
                                  status: _statusFilter.isNotEmpty
                                      ? _statusFilter
                                      : null,
                                )
                          : null,
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

  Widget _buildDesktopTable(SocietiesState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 1000,
        ), // Force minimum width for horizontal scroll
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Card(
            margin: const EdgeInsets.only(bottom: 24),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 12,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: 150,
                    child: Text('Name', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 120,
                    child: Text('Contact', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: Text('Plan', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 60,
                    child: Text('Units', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 60,
                    child: Text('Users', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 110,
                    child: Text('Status', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 90,
                    child: Text('Created', style: AppTextStyles.labelLarge),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: Text('Actions', style: AppTextStyles.labelLarge),
                  ),
                ),
              ],
              rows: state.societies.map<DataRow>((s) {
                final planName =
                    s['plan']?['displayName'] ??
                    s['plan']?['name'] ??
                    'No Plan';
                final isActive = s['status'] == 'ACTIVE';

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        s['name'] ?? '',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        s['contactPhone'] ?? s['contactEmail'] ?? '-',
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(_badge(planName, const Color(0xFF3B82F6))),
                    DataCell(Text('${s['unitCount'] ?? 0}')),
                    DataCell(Text('${s['userCount'] ?? 0}')),
                    DataCell(_statusToggle(s['id'], isActive)),
                    DataCell(
                      Text(
                        s['createdAt'] != null
                            ? DateFormat(
                                'dd MMM yy',
                              ).format(DateTime.parse(s['createdAt']))
                            : '-',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            tooltip: 'View',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showDetailDialog(s['id']),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Edit Society',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _showCreateDialog(context, society: s),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.lock_reset,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            tooltip: 'Reset Chairman Password',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showResetPasswordDialog(
                              s['id'],
                              s['name'],
                              s['chairman']?['name'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            tooltip: 'Society Settings',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showSocietySettingsDialog(
                              s['id'],
                              s['name'],
                              s['settings'],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// Clickable status chip that toggles active ↔ suspended
  Widget _statusToggle(String id, bool isActive) {
    return GestureDetector(
      onTap: () => _confirmToggleStatus(id, isActive),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.danger).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isActive ? AppColors.success : AppColors.danger).withValues(
              alpha: 0.4,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 12,
              color: isActive ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'Active' : 'Suspended',
              style: AppTextStyles.labelMedium.copyWith(
                color: isActive ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _confirmToggleStatus(String id, bool isCurrentlyActive) {
    final action = isCurrentlyActive ? 'suspend' : 'activate';
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isCurrentlyActive ? 'Suspend' : 'Activate'} Society'),
        content: Text(
          isCurrentlyActive
              ? 'This will suspend the society and deactivate all its users. Continue?'
              : 'This will reactivate the society and all its users. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isCurrentlyActive
                  ? AppColors.danger
                  : AppColors.success,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(societiesProvider.notifier).toggleStatus(id);
            },
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(
    String id,
    String? societyName,
    String? currentChairmanName,
  ) {
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: currentChairmanName);
    String mode = 'auto'; // auto | manual
    bool obscure = true;
    String? errorMsg;
    bool saving = false;
    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Reset Admin Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update credentials for "${currentChairmanName ?? 'Chairman'}" of "${societyName ?? ''}".',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setDialogState(() => mode = 'auto'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: mode == 'auto'
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          'Auto-generate',
                          style: TextStyle(
                            color: mode == 'auto'
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setDialogState(() => mode = 'manual'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: mode == 'manual'
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          'Set manually',
                          style: TextStyle(
                            color: mode == 'manual'
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Chairman Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (mode == 'manual')
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Minimum 8 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'A new password will be auto-generated and applied.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    errorMsg ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (mode == 'manual' &&
                      passCtrl.text.isNotEmpty &&
                      passCtrl.text.length < 8) {
                    setDialogState(
                      () => errorMsg = 'Password must be at least 8 characters',
                    );
                    return;
                  }
                  if (mode == 'manual' &&
                      passCtrl.text.isEmpty &&
                      nameCtrl.text.trim().isEmpty) {
                    setDialogState(
                      () => errorMsg = 'Provide either a new name or password',
                    );
                    return;
                  }
                  setDialogState(() {
                    saving = true;
                    errorMsg = null;
                  });

                  final error = await ref
                      .read(societiesProvider.notifier)
                      .resetPassword(
                        id,
                        passCtrl.text,
                        name: nameCtrl.text.trim(),
                        mode: mode,
                      );

                  if (ctx.mounted) {
                    if (error == null) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Credentials updated successfully'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      setDialogState(() {
                        saving = false;
                        errorMsg = error;
                      });
                    }
                  }
                },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context, {
    Map<String, dynamic>? society,
  }) {
    final isEdit = society != null;
    final nameC = TextEditingController(text: society?['name'] ?? '');
    final addressC = TextEditingController(text: society?['address'] ?? '');
    final cityC = TextEditingController(text: society?['city'] ?? '');
    final phoneC = TextEditingController(text: society?['contactPhone'] ?? '');
    final emailC = TextEditingController(text: society?['contactEmail'] ?? '');
    final maxUnitsC = TextEditingController(text: society?['maxUnits']?.toString() ?? '');
    final maxUsersC = TextEditingController(text: society?['maxUsers']?.toString() ?? '');
    final existingPlanName = society?['plan']?['name'] as String?;
    String selectedPlan = (existingPlanName ?? 'basic').toLowerCase();
    String selectedDuration = society?['planDuration'] ?? 'MONTHLY';
    bool planChanged = false;

    // Controllers for Chairman (only for create)
    final pNameC = TextEditingController();
    final pPhoneC = TextEditingController();
    final pEmailC = TextEditingController();
    final pPassC = TextEditingController();
    String? errorMsg;
    bool saving = false;

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Society' : 'Create New Society'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Society Details', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'Society Name *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressC,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cityC,
                      decoration: const InputDecoration(labelText: 'City *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneC,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: emailC,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Consumer(
                      builder: (context, ref, child) {
                        final plansState = ref.watch(plansProvider);
                        final plans = plansState.plans;
                        
                        if (plans.isEmpty && plansState.isLoading) {
                          return const LinearProgressIndicator();
                        }
                        
                        final currentPlan = plans.firstWhere(
                          (p) => p['name'].toString().toLowerCase() == selectedPlan.toLowerCase(),
                          orElse: () => {},
                        );
                        final currentUnits = (society?['unitCount'] ?? 0) as int;
                        final planMax = currentPlan['maxUnits'];
                        final overrideUnits = int.tryParse(maxUnitsC.text.trim());
                        final overrideUsers = int.tryParse(maxUsersC.text.trim());
                        final effectiveMax = overrideUnits ?? planMax;
                        final effectiveMaxUsers = overrideUsers ?? currentPlan['maxUsers'];
                        final atLimit = effectiveMax != null &&
                            effectiveMax != -1 &&
                            currentUnits >= (effectiveMax as num).toInt();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSearchableDropdown<String>(
                              label: 'Plan',
                              value: selectedPlan,
                              items: plans.map((p) => AppDropdownItem(
                                value: p['name'].toString().toLowerCase(),
                                label: p['displayName'] ?? p['name'],
                              )).toList(),
                              onChanged: (v) {
                                setS(() {
                                  selectedPlan = v ?? 'basic';
                                  planChanged = true;
                                });
                              },
                            ),
                            if (currentPlan.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _planInfoItem('Max Units', effectiveMax == -1 ? 'Unlimited' : '$effectiveMax'),
                                        if (isEdit) _planInfoItem('Current', '$currentUnits'),
                                        _planInfoItem('Max Users', effectiveMaxUsers == -1 ? 'Unlimited' : '$effectiveMaxUsers'),
                                        _planInfoItem('Rate', '₹${currentPlan['pricePerUnit']}/unit'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: maxUnitsC,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Max Units override',
                                              hintText: 'Blank = use plan',
                                              isDense: true,
                                            ),
                                            onChanged: (_) => setS(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextField(
                                            controller: maxUsersC,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Max Users override',
                                              hintText: 'Blank = use plan',
                                              isDense: true,
                                            ),
                                            onChanged: (_) => setS(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isEdit && effectiveMax != -1) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          atLimit
                                              ? 'Unit limit reached. You can’t create more units unless you upgrade/raise Max Units.'
                                              : 'Remaining units: ${(effectiveMax as num).toInt() - currentUnits}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: atLimit ? AppColors.danger : AppColors.textMuted,
                                            fontWeight: atLimit ? FontWeight.w600 : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _durationButton(
                                            'Monthly',
                                            'MONTHLY',
                                            selectedDuration == 'MONTHLY',
                                            () => setS(() => selectedDuration = 'MONTHLY'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _durationButton(
                                            'Yearly',
                                            'YEARLY',
                                            selectedDuration == 'YEARLY',
                                            () => setS(() => selectedDuration = 'YEARLY'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: 20),
                      Text('Chairman (Admin) Account', style: AppTextStyles.h3),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pNameC,
                              decoration: const InputDecoration(
                                labelText: 'Name *',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: pPhoneC,
                              decoration: const InputDecoration(
                                labelText: 'Phone *',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pEmailC,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: pPassC,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password *',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          errorMsg ?? '',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameC.text.isEmpty) {
                          setS(() => errorMsg = 'Society name is required');
                          return;
                        }
                        if (cityC.text.isEmpty) {
                          setS(() => errorMsg = 'City is required');
                          return;
                        }
                        if (!isEdit &&
                            (pNameC.text.isEmpty ||
                                pPhoneC.text.isEmpty ||
                                pPassC.text.isEmpty)) {
                          setS(() => errorMsg = 'Admin details are required');
                          return;
                        }

                        setS(() {
                          saving = true;
                          errorMsg = null;
                        });

                        final data = <String, dynamic>{
                          'name': nameC.text.trim(),
                          'address': addressC.text.trim(),
                          'city': cityC.text.trim(),
                          'contactPhone': phoneC.text.trim(),
                          'contactEmail': emailC.text.trim(),
                        };

                        if (!isEdit || planChanged) {
                          data['planName'] = selectedPlan;
                          data['planDuration'] = selectedDuration;
                        }

                        // Super Admin overrides (blank => null => use plan limit)
                        data['maxUnits'] = maxUnitsC.text.trim().isEmpty ? null : int.tryParse(maxUnitsC.text.trim());
                        data['maxUsers'] = maxUsersC.text.trim().isEmpty ? null : int.tryParse(maxUsersC.text.trim());

                        if (!isEdit) {
                          data['chairman'] = {
                            'name': pNameC.text.trim(),
                            'phone': pPhoneC.text.trim(),
                            'email': pEmailC.text.trim().isNotEmpty
                                ? pEmailC.text.trim()
                                : null,
                            'password': pPassC.text,
                          };
                        }

                        final error = isEdit
                            ? await ref
                                  .read(societiesProvider.notifier)
                                  .updateSociety(society['id'], data)
                            : await ref
                                  .read(societiesProvider.notifier)
                                  .createSociety(data);

                        if (ctx.mounted) {
                          if (error == null) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Society updated successfully'
                                      : 'Society created successfully',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else {
                            setS(() {
                              saving = false;
                              errorMsg = error;
                            });
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Update Society' : 'Create Society'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDetailDialog(String id) async {
    showAppDialog(
      context: context,
      builder: (ctx) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final data = await ref.read(societiesProvider.notifier).getSociety(id);
    if (!mounted) return;
    // Close the loader dialog (pop only the dialog route, not the page route).
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) rootNav.pop();

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load society details')),
      );
      return;
    }

    final chairman = data['chairman'] as Map<String, dynamic>?;
    final planName =
        data['plan']?['displayName'] ?? data['plan']?['name'] ?? 'No Plan';
    final isActive = data['status'] == 'ACTIVE';

    showAppDialog(
      context: context,
      maxWidth: 620,
      builder: (ctx) => AlertDialog(
        title: Text(data['name'] ?? 'Society'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _badge(planName, const Color(0xFF3B82F6)),
                    const SizedBox(width: 10),
                    _statusToggle(id, isActive),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Society Info', style: AppTextStyles.h3),
                const SizedBox(height: 10),
                _kv('City', data['city'] ?? '-'),
                _kv('Address', data['address'] ?? '-'),
                _kv('Phone', data['contactPhone'] ?? '-'),
                _kv('Email', data['contactEmail'] ?? '-'),
                _kv('Units', '${data['unitCount'] ?? 0}'),
                _kv('Users', '${data['userCount'] ?? 0}'),
                const SizedBox(height: 16),
                Text('Admin (Chairman/Pramukh)', style: AppTextStyles.h3),
                const SizedBox(height: 10),
                _kv('Name', chairman?['name'] ?? '-'),
                _kv('Phone', chairman?['phone'] ?? '-'),
                _kv('Email', chairman?['email'] ?? '-'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showResetPasswordDialog(id, data['name'], chairman?['name']);
            },
            icon: const Icon(Icons.lock_reset_rounded, size: 18),
            label: const Text('Reset Password'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateDialog(context, society: data);
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(v, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  void _showSocietySettingsDialog(
    String societyId,
    String societyName,
    dynamic currentSettings,
  ) {
    final settings = (currentSettings is Map)
        ? Map<String, dynamic>.from(currentSettings)
        : <String, dynamic>{};
    final qrCtrl = TextEditingController(
      text: settings['visitor_qr_max_hrs']?.toString() ?? '',
    );
    String? errorText;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Society Settings', style: AppTextStyles.h2),
              Text(
                societyName,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Visitor QR Max Expiry',
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final config = ref.watch(visitorConfigProvider);
                    final platformMax = config.when(
                      data: (d) =>
                          (d['visitorQrMaxHrs'] as num?)?.toString() ?? '...',
                      loading: () => '...',
                      error: (_, __) => '...',
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Override the platform default ($platformMax hrs) for this society. Leave blank to use the platform default.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: qrCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText:
                                'Max hours (Platform Limit: $platformMax hrs)',
                            suffixText: 'hrs',
                            errorText: errorText,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final raw = qrCtrl.text.trim();
                      if (raw.isNotEmpty) {
                        final n = int.tryParse(raw);
                        if (n == null || n < 1) {
                          setS(() => errorText = 'Must be a positive integer');
                          return;
                        }
                        
                        // Validation: Cannot exceed platform limit
                        final platConfig = ref.read(visitorConfigProvider).asData?.value;
                        final platMax = platConfig?['visitorQrMaxHrs'] as num?;
                        if (platMax != null && n > platMax) {
                          setS(() => errorText = 'Cannot exceed platform limit of $platMax hrs');
                          return;
                        }
                      }
                      setS(() {
                        saving = true;
                        errorText = null;
                      });

                      final body = <String, dynamic>{};
                      if (raw.isNotEmpty)
                        body['visitor_qr_max_hrs'] = int.parse(raw);
                      else
                        body['visitor_qr_max_hrs'] = null; // Reset to default

                      final error = await ref
                          .read(societiesProvider.notifier)
                          .updateSettings(societyId, body);

                      if (ctx.mounted) {
                        if (error == null) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Society settings saved'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else {
                          setS(() {
                            saving = false;
                            errorText = error;
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegisterStepper(BuildContext context) {
    // Bottom-sheet step-by-step registration (mobile-friendly), saving each step before moving on.
    final nameC = TextEditingController();
    final addressC = TextEditingController();
    final cityC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final wingsC = TextEditingController();
    final unitsC = TextEditingController();

    String selectedPlan = 'standard';
    String selectedDuration = 'MONTHLY';
    bool enableTrial = true;
    final trialDaysC = TextEditingController(text: '30');

    final adminNameC = TextEditingController();
    final adminPhoneC = TextEditingController();
    final adminEmailC = TextEditingController();
    final adminPassC = TextEditingController();

    final nameErr = ValueNotifier<String?>(null);
    final cityErr = ValueNotifier<String?>(null);
    final adminNameErr = ValueNotifier<String?>(null);
    final adminPhoneErr = ValueNotifier<String?>(null);
    final adminPassErr = ValueNotifier<String?>(null);
    final trialDaysErr = ValueNotifier<String?>(null);

    // Estimate linkage — set when user imports from an accepted estimate
    String? linkedEstimateId;
    String? linkedEstimateNumber;

    int step = 0;
    bool saving = false;
    String? societyId;
    String? errorMsg;

    void clearErrors() {
      nameErr.value = null;
      cityErr.value = null;
      adminNameErr.value = null;
      adminPhoneErr.value = null;
      adminPassErr.value = null;
      trialDaysErr.value = null;
    }

    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final maxH = MediaQuery.of(ctx).size.height * 0.88;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Register New Society', style: AppTextStyles.h2),
                  const SizedBox(height: 10),
                  _SheetStepHeader(
                    step: step,
                    labels: const ['Details', 'Plan', 'Admin', 'Review'],
                    onTap: (i) {
                      if (i <= step) setSheetState(() => step = i);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (step == 0) ...[
                            // ── Estimate picker ───────────────────────────
                            if (linkedEstimateNumber != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.successSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_rounded, size: 16, color: AppColors.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Linked to estimate $linkedEstimateNumber',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.successText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setSheetState(() {
                                        linkedEstimateId = null;
                                        linkedEstimateNumber = null;
                                      }),
                                      child: const Icon(Icons.close, size: 16, color: AppColors.success),
                                    ),
                                  ],
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final result = await ref
                                    .read(estimatesProvider.notifier)
                                    .fetchAcceptedUnlinked();
                                if (!context.mounted) return;
                                if (result.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result.error!)),
                                  );
                                  return;
                                }
                                final estimates = result.estimates;
                                if (estimates.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No accepted estimates available')),
                                  );
                                  return;
                                }
                                // Show picker dialog
                                final picked = await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text('Select Estimate', style: AppTextStyles.h2),
                                    content: SizedBox(
                                      width: 380,
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: estimates.length,
                                        separatorBuilder: (_, _) => const Divider(height: 1),
                                        itemBuilder: (_, i) {
                                          final e = estimates[i];
                                          final planLabel = e['plan']?['displayName'] ?? e['plan']?['name'] ?? '';
                                          return ListTile(
                                            title: Text(e['societyName'] ?? '', style: AppTextStyles.bodyMedium),
                                            subtitle: Text(
                                              '${e['estimateNumber']} • ${e['unitCount']} units • $planLabel',
                                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                            ),
                                            trailing: Text(
                                              '₹${e['totalAmount']}',
                                              style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                                            ),
                                            onTap: () => Navigator.pop(dCtx, e),
                                          );
                                        },
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                );
                                if (picked == null) return;
                                // Auto-fill form from estimate
                                setSheetState(() {
                                  linkedEstimateId = picked['id'] as String?;
                                  linkedEstimateNumber = picked['estimateNumber'] as String?;
                                  nameC.text = picked['societyName'] ?? '';
                                  cityC.text = picked['city'] ?? '';
                                  phoneC.text = picked['contactPhone'] ?? '';
                                  emailC.text = picked['contactEmail'] ?? '';
                                  unitsC.text = (picked['unitCount'] ?? '').toString();
                                  // Pre-select plan from estimate
                                  final planName = picked['plan']?['name']?.toString().toLowerCase() ?? 'standard';
                                  if (['basic', 'standard', 'premium'].contains(planName)) {
                                    selectedPlan = planName;
                                  }
                                  final dur = picked['duration']?.toString() ?? 'MONTHLY';
                                  selectedDuration = dur;
                                });
                              },
                              icon: const Icon(Icons.description_outlined, size: 16),
                              label: const Text('Import from Estimate'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                minimumSize: const Size(double.infinity, 42),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<String?>(
                              valueListenable: nameErr,
                              builder: (_, err, __) => TextField(
                                controller: nameC,
                                decoration: InputDecoration(
                                  labelText: 'Society Name *',
                                  errorText: err,
                                ),
                                onChanged: (_) => nameErr.value = null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: addressC,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                              ),
                            ),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<String?>(
                              valueListenable: cityErr,
                              builder: (_, err, __) => TextField(
                                controller: cityC,
                                decoration: InputDecoration(
                                  labelText: 'City *',
                                  errorText: err,
                                ),
                                onChanged: (_) => cityErr.value = null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: wingsC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'No. of Wings',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: unitsC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Expected Units',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: phoneC,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Phone',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: emailC,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Email',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (step == 1) ...[
                            Consumer(
                              builder: (context, ref, child) {
                                final plansState = ref.watch(plansProvider);
                                final plans = plansState.plans;
                                
                                if (plans.isEmpty && plansState.isLoading) {
                                  return const LinearProgressIndicator();
                                }
                                
                                final currentPlan = plans.firstWhere(
                                  (p) => p['name'].toString().toLowerCase() == selectedPlan.toLowerCase(),
                                  orElse: () => {},
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppSearchableDropdown<String>(
                                      label: 'Plan *',
                                      value: selectedPlan,
                                      items: plans.map((p) => AppDropdownItem(
                                        value: p['name'].toString().toLowerCase(),
                                        label: p['displayName'] ?? p['name'],
                                      )).toList(),
                                      onChanged: (v) => setSheetState(
                                        () => selectedPlan = v ?? 'standard',
                                      ),
                                    ),
                                    if (currentPlan.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySurface,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _planInfoItem('Units', currentPlan['maxUnits'] == -1 ? 'Unlimited' : '${currentPlan['maxUnits']}'),
                                            _planInfoItem('Users', currentPlan['maxUsers'] == -1 ? 'Unlimited' : '${currentPlan['maxUsers']}'),
                                            _planInfoItem('Rate', '₹${currentPlan['pricePerUnit']}/unit'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _durationButton(
                                              'Monthly',
                                              'MONTHLY',
                                              selectedDuration == 'MONTHLY',
                                              () => setSheetState(() => selectedDuration = 'MONTHLY'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _durationButton(
                                              'Yearly',
                                              'YEARLY',
                                              selectedDuration == 'YEARLY',
                                              () => setSheetState(() => selectedDuration = 'YEARLY'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              value: enableTrial,
                              onChanged: (v) =>
                                  setSheetState(() => enableTrial = v ?? true),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable free trial period'),
                            ),
                            if (enableTrial)
                              ValueListenableBuilder<String?>(
                                valueListenable: trialDaysErr,
                                builder: (_, err, __) => TextField(
                                  controller: trialDaysC,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Trial Days *',
                                    errorText: err,
                                  ),
                                  onChanged: (_) => trialDaysErr.value = null,
                                ),
                              ),
                          ],
                          if (step == 2) ...[
                            ValueListenableBuilder<String?>(
                              valueListenable: adminNameErr,
                              builder: (_, err, __) => TextField(
                                controller: adminNameC,
                                decoration: InputDecoration(
                                  labelText: 'Admin Full Name *',
                                  errorText: err,
                                ),
                                onChanged: (_) => adminNameErr.value = null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<String?>(
                              valueListenable: adminPhoneErr,
                              builder: (_, err, __) => TextField(
                                controller: adminPhoneC,
                                decoration: InputDecoration(
                                  labelText: 'Mobile Number *',
                                  errorText: err,
                                ),
                                onChanged: (_) => adminPhoneErr.value = null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: adminEmailC,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                              ),
                            ),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<String?>(
                              valueListenable: adminPassErr,
                              builder: (_, err, __) => TextField(
                                controller: adminPassC,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Password *',
                                  hintText: 'Min 8 characters',
                                  errorText: err,
                                ),
                                onChanged: (_) => adminPassErr.value = null,
                              ),
                            ),
                          ],
                          if (step == 3) ...[
                            _kv(
                              'Society',
                              nameC.text.trim().isEmpty
                                  ? '—'
                                  : nameC.text.trim(),
                            ),
                            _kv(
                              'City',
                              cityC.text.trim().isEmpty
                                  ? '—'
                                  : cityC.text.trim(),
                            ),
                            _kv('Plan', selectedPlan),
                            _kv(
                              'Trial',
                              enableTrial
                                  ? '${trialDaysC.text.trim().isEmpty ? '—' : trialDaysC.text.trim()} days'
                                  : 'No',
                            ),
                            _kv(
                              'Admin',
                              adminNameC.text.trim().isEmpty
                                  ? '—'
                                  : adminNameC.text.trim(),
                            ),
                            _kv(
                              'Admin Phone',
                              adminPhoneC.text.trim().isEmpty
                                  ? '—'
                                  : adminPhoneC.text.trim(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        errorMsg!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving
                              ? null
                              : () {
                                  if (step == 0) {
                                    Navigator.pop(ctx);
                                  } else {
                                    setSheetState(() => step -= 1);
                                  }
                                },
                          child: Text(step == 0 ? 'Cancel' : 'Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  clearErrors();
                                  final notifier = ref.read(
                                    societiesProvider.notifier,
                                  );

                                  // STEP 0: create society draft (upload details)
                                  if (step == 0) {
                                    final name = nameC.text.trim();
                                    final city = cityC.text.trim();
                                    bool ok = true;
                                    if (name.isEmpty) {
                                      nameErr.value = 'Required';
                                      ok = false;
                                    }
                                    if (city.isEmpty) {
                                      cityErr.value = 'Required';
                                      ok = false;
                                    }
                                    if (!ok) return;

                                    setSheetState(() {
                                      saving = true;
                                      errorMsg = null;
                                    });
                                    final results = await notifier
                                        .createSocietyWithId({
                                          'name': name,
                                          'address': addressC.text.trim(),
                                          'city': city,
                                          'contactPhone': phoneC.text.trim(),
                                          'contactEmail': emailC.text.trim(),
                                          if (linkedEstimateId case final eid?) 'estimateId': eid,
                                          'settings': {
                                            if (wingsC.text.trim().isNotEmpty)
                                              'wings':
                                                  int.tryParse(
                                                    wingsC.text.trim(),
                                                  ) ??
                                                  wingsC.text.trim(),
                                            if (unitsC.text.trim().isNotEmpty)
                                              'expectedUnits':
                                                  int.tryParse(
                                                    unitsC.text.trim(),
                                                  ) ??
                                                  unitsC.text.trim(),
                                          },
                                        });
                                    final id = results.$1;
                                    final error = results.$2;

                                    setSheetState(() => saving = false);

                                    if (error != null) {
                                      setSheetState(() => errorMsg = error);
                                      return;
                                    }
                                    societyId = id;
                                    setSheetState(() => step = 1);
                                    return;
                                  }

                                  // STEP 1: update plan/trial (upload step data)
                                  if (step == 1) {
                                    if (societyId == null) return;
                                    if (enableTrial) {
                                      final td = int.tryParse(
                                        trialDaysC.text.trim(),
                                      );
                                      if (td == null || td <= 0) {
                                        trialDaysErr.value = 'Enter valid days';
                                        return;
                                      }
                                    }

                                    setSheetState(() {
                                      saving = true;
                                      errorMsg = null;
                                    });
                                    final error = await notifier.updateSociety(
                                      societyId!,
                                      {
                                        'planName': selectedPlan,
                                        'planDuration': selectedDuration,
                                        'settings': {
                                          if (wingsC.text.trim().isNotEmpty)
                                            'wings':
                                                int.tryParse(
                                                  wingsC.text.trim(),
                                                ) ??
                                                wingsC.text.trim(),
                                          if (unitsC.text.trim().isNotEmpty)
                                            'expectedUnits':
                                                int.tryParse(
                                                  unitsC.text.trim(),
                                                ) ??
                                                unitsC.text.trim(),
                                          'trialEnabled': enableTrial,
                                        },
                                      },
                                    );
                                    setSheetState(() => saving = false);

                                    if (error != null) {
                                      setSheetState(() => errorMsg = error);
                                      return;
                                    }
                                    setSheetState(() => step = 2);
                                    return;
                                  }

                                  // STEP 2: create/update chairman (upload step data)
                                  if (step == 2) {
                                    if (societyId == null) return;
                                    final n = adminNameC.text.trim();
                                    final p = adminPhoneC.text.trim();
                                    final pass = adminPassC.text;
                                    bool ok = true;
                                    if (n.isEmpty) {
                                      adminNameErr.value = 'Required';
                                      ok = false;
                                    }
                                    if (p.isEmpty) {
                                      adminPhoneErr.value = 'Required';
                                      ok = false;
                                    }
                                    if (pass.isEmpty) {
                                      adminPassErr.value = 'Required';
                                      ok = false;
                                    } else if (pass.length < 8) {
                                      adminPassErr.value = 'Min 8 characters';
                                      ok = false;
                                    }
                                    if (!ok) return;

                                    setSheetState(() {
                                      saving = true;
                                      errorMsg = null;
                                    });
                                    final error = await notifier
                                        .upsertChairman(societyId!, {
                                          'name': n,
                                          'phone': p,
                                          'email':
                                              adminEmailC.text.trim().isNotEmpty
                                              ? adminEmailC.text.trim()
                                              : null,
                                          'password': pass,
                                        });
                                    setSheetState(() => saving = false);

                                    if (error != null) {
                                      setSheetState(() => errorMsg = error);
                                      return;
                                    }
                                    setSheetState(() => step = 3);
                                    return;
                                  }

                                  // STEP 3: finish
                                  Navigator.pop(ctx);
                                  await notifier.loadSocieties(page: 1);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Society registered successfully',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                },
                          child: Text(
                            saving
                                ? 'Saving...'
                                : (step == 3 ? 'Finish' : 'Next'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SocietyCard extends StatelessWidget {
  final Map<String, dynamic> society;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onSettings;

  const _SocietyCard({
    required this.society,
    required this.onView,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final name = society['name'] ?? '';
    final planName =
        society['plan']?['displayName'] ??
        society['plan']?['name'] ??
        'No Plan';
    final isActive = society['status'] == 'ACTIVE';
    final contact = society['contactPhone'] ?? society['contactEmail'] ?? '-';
    final units = society['unitCount'] ?? 0;
    final users = society['userCount'] ?? 0;
    final createdAt = society['createdAt'] != null
        ? DateFormat('dd MMM yy').format(DateTime.parse(society['createdAt']))
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.h2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _badge(planName, const Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contact,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoIcon(Icons.apartment_outlined, '$units'),
                const SizedBox(width: 12),
                _infoIcon(Icons.people_outline, '$users'),
                const Spacer(),
                _statusToggle(isActive),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Created: $createdAt', style: AppTextStyles.caption),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onPressed: onView,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.lock_reset,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      onPressed: onResetPassword,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      tooltip: 'Society Settings',
                      onPressed: onSettings,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoIcon(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelMedium),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _statusToggle(bool isActive) {
    return GestureDetector(
      onTap: onToggleStatus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.danger).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isActive ? AppColors.success : AppColors.danger).withValues(
              alpha: 0.4,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 12,
              color: isActive ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'Active' : 'Suspended',
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

  Widget _planInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _durationButton(String label, String value, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? AppColors.textOnPrimary : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

class _StatsRow extends StatelessWidget {
  final bool isMobile;
  final int total;
  final int active;
  final int suspended;

  const _StatsRow({
    required this.isMobile,
    required this.total,
    required this.active,
    required this.suspended,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        label: 'Total Societies',
        value: total.toString(),
        icon: Icons.location_city_rounded,
        color: AppColors.primary,
      ),
      _StatItem(
        label: 'Active',
        value: active.toString(),
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
      ),
      _StatItem(
        label: 'Suspended',
        value: suspended.toString(),
        icon: Icons.block_rounded,
        color: AppColors.danger,
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              SizedBox(
                width: 180,
                child: _StatCard(item: items[i]),
              ),
              if (i != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: _StatCard(item: items[i])),
          if (i != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 20, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.value, style: AppTextStyles.h2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetStepHeader extends StatelessWidget {
  final int step;
  final List<String> labels;
  final void Function(int index)? onTap;
  const _SheetStepHeader({
    required this.step,
    required this.labels,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap == null ? null : () => onTap!(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0
                                ? Colors.transparent
                                : (i <= step
                                      ? AppColors.primary
                                      : AppColors.border),
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: i <= step
                                ? AppColors.primary
                                : AppColors.border,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: i <= step
                                    ? AppColors.textOnPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == labels.length - 1
                                ? Colors.transparent
                                : (i < step
                                      ? AppColors.primary
                                      : AppColors.border),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: AppTextStyles.labelSmall.copyWith(
                        color: i == step
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontWeight: i == step
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
