import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/societies_provider.dart';

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
    Future.microtask(() => ref.read(societiesProvider.notifier).loadSocieties());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(societiesProvider.notifier).loadSocieties(
          search: _searchController.text.trim(),
          status: _statusFilter.isNotEmpty ? _statusFilter : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(societiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Societies',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      SizedBox(height: 4),
                      Text('Manage all registered societies',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Society'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search & Filter Bar
            Row(
              children: [
                Expanded(
                  flex: 3,
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
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
            Text('${state.total} societies found',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),

            // Table
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? Center(child: Text(state.error!, style: const TextStyle(color: AppColors.error)))
                      : state.societies.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.apartment_outlined, size: 64, color: AppColors.textMuted),
                                  SizedBox(height: 12),
                                  Text('No societies found', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                                ],
                              ),
                            )
                          : Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  columns: const [
                                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Units', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Users', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                  ],
                                  rows: state.societies.map<DataRow>((s) {
                                    final planName = s['plan']?['displayName'] ?? s['plan']?['name'] ?? 'No Plan';
                                    final isActive = s['status'] == 'active';

                                    return DataRow(cells: [
                                      DataCell(Text(s['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w500))),
                                      DataCell(Text(s['contactPhone'] ?? s['contactEmail'] ?? '-',
                                          style: const TextStyle(fontSize: 13))),
                                      DataCell(_badge(planName, const Color(0xFF3B82F6))),
                                      DataCell(Text('${s['unitCount'] ?? 0}')),
                                      DataCell(Text('${s['userCount'] ?? 0}')),
                                      DataCell(_statusToggle(s['id'], isActive)),
                                      DataCell(Text(
                                        s['createdAt'] != null
                                            ? DateFormat('dd MMM yy').format(DateTime.parse(s['createdAt']))
                                            : '-',
                                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                      )),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                            tooltip: 'Edit Society',
                                            onPressed: () => _showCreateDialog(context, society: s),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.lock_reset, size: 18, color: AppColors.textMuted),
                                            tooltip: 'Reset Pramukh Password',
                                            onPressed: () => _showResetPasswordDialog(s['id'], s['name']),
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
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
                          ? () => ref.read(societiesProvider.notifier).loadSocieties(
                                page: state.page - 1,
                                search: _searchController.text,
                                status: _statusFilter.isNotEmpty ? _statusFilter : null,
                              )
                          : null,
                      child: const Text('Previous'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Page ${state.page}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    TextButton(
                      onPressed: state.page * 20 < state.total
                          ? () => ref.read(societiesProvider.notifier).loadSocieties(
                                page: state.page + 1,
                                search: _searchController.text,
                                status: _statusFilter.isNotEmpty ? _statusFilter : null,
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

  /// Clickable status chip that toggles active ↔ suspended
  Widget _statusToggle(String id, bool isActive) {
    return GestureDetector(
      onTap: () => _confirmToggleStatus(id, isActive),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.secondary : AppColors.error).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isActive ? AppColors.secondary : AppColors.error).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 12,
              color: isActive ? AppColors.secondary : AppColors.error,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'Active' : 'Suspended',
              style: TextStyle(
                color: isActive ? AppColors.secondary : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  void _confirmToggleStatus(String id, bool isCurrentlyActive) {
    final action = isCurrentlyActive ? 'suspend' : 'activate';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isCurrentlyActive ? 'Suspend' : 'Activate'} Society'),
        content: Text(
          isCurrentlyActive
              ? 'This will suspend the society and deactivate all its users. Continue?'
              : 'This will reactivate the society and all its users. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isCurrentlyActive ? AppColors.error : AppColors.secondary,
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

  void _showResetPasswordDialog(String id, String? name) {
    final passCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Reset Pramukh Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset password for Pramukh of "${name ?? ''}".',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Minimum 8 characters',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (passCtrl.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 8 characters')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final ok = await ref.read(societiesProvider.notifier).resetPassword(id, passCtrl.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Password reset successfully' : 'Failed to reset password'),
                      backgroundColor: ok ? AppColors.secondary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, {Map<String, dynamic>? society}) {
    final isEdit = society != null;
    final nameC = TextEditingController(text: society?['name'] ?? '');
    final addressC = TextEditingController(text: society?['address'] ?? '');
    final cityC = TextEditingController(text: society?['city'] ?? '');
    final phoneC = TextEditingController(text: society?['contactPhone'] ?? '');
    final emailC = TextEditingController(text: society?['contactEmail'] ?? '');
    final planName = society?['plan']?['name'] as String?;
    String selectedPlan = planName ?? 'BASIC';

    // Controllers for Pramukh (only for create)
    final pNameC = TextEditingController();
    final pPhoneC = TextEditingController();
    final pEmailC = TextEditingController();
    final pPassC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Society' : 'Create New Society'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Society Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Society Name *')),
                const SizedBox(height: 10),
                TextField(controller: addressC, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 10),
                TextField(controller: cityC, decoration: const InputDecoration(labelText: 'City')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email'))),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlan.toUpperCase(),
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [
                    DropdownMenuItem(value: 'BASIC', child: Text('Basic')),
                    DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                    DropdownMenuItem(value: 'PREMIUM', child: Text('Premium')),
                  ],
                  onChanged: (v) => selectedPlan = v ?? 'BASIC',
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 20),
                  const Text('Pramukh (Admin) Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: pNameC, decoration: const InputDecoration(labelText: 'Name *'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(controller: pPhoneC, decoration: const InputDecoration(labelText: 'Phone *'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextField(controller: pEmailC, decoration: const InputDecoration(labelText: 'Email'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pPassC,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password *'),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              final data = <String, dynamic>{
                'name': nameC.text.trim(),
                'address': addressC.text.trim(),
                'city': cityC.text.trim(),
                'contactPhone': phoneC.text.trim(),
                'contactEmail': emailC.text.trim(),
                'planName': selectedPlan.toLowerCase(),
              };

              if (!isEdit && pNameC.text.isNotEmpty && pPhoneC.text.isNotEmpty && pPassC.text.isNotEmpty) {
                data['pramukh'] = {
                  'name': pNameC.text.trim(),
                  'phone': pPhoneC.text.trim(),
                  'email': pEmailC.text.trim().isNotEmpty ? pEmailC.text.trim() : null,
                  'password': pPassC.text,
                };
              }

              Navigator.pop(ctx);
              if (isEdit) {
                await ref.read(societiesProvider.notifier).updateSociety(society['id'], data);
              } else {
                await ref.read(societiesProvider.notifier).createSociety(data);
              }
            },
            child: Text(isEdit ? 'Update Society' : 'Create Society'),
          ),
        ],
      ),
    );
  }
}
