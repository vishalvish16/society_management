import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/donation_provider.dart';
import 'donate_sheet.dart';

class DonationsScreen extends ConsumerStatefulWidget {
  const DonationsScreen({super.key});

  @override
  ConsumerState<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends ConsumerState<DonationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _selectedCampaignId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final role = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    const adminRoles = {
      'PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY',
      'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER'
    };
    return adminRoles.contains(role);
  }

  String _fmt(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donations'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Campaigns'), Tab(text: 'All Donations')],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateCampaignSheet,
              tooltip: 'New Campaign',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDonateSheet(context),
        icon: const Icon(Icons.volunteer_activism),
        label: const Text('Donate'),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CampaignsList(
            onDonate: ({campaignId, campaignTitle}) => 
              showDonateSheet(context, campaignId: campaignId, campaignTitle: campaignTitle), 
            fmt: _fmt
          ),
          _DonationsList(campaignId: _selectedCampaignId, fmt: _fmt)
        ],
      ),
    );
  }

  void _showCreateCampaignSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Campaign', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Campaign Title *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'Target Amount (optional)', border: OutlineInputBorder(), prefixText: '₹'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              AppDateRangeField(
                label: 'Campaign Duration',
                from: startDate,
                to: endDate,
                clearable: endDate != null,
                onClear: () => setState(() => endDate = null),
                onTap: () async {
                  final picked = await pickDateRange(
                    ctx,
                    initialFrom: startDate,
                    initialTo: endDate,
                    firstDate: DateTime(2020),
                  );
                  if (picked != null) {
                    setState(() {
                      startDate = picked.start;
                      endDate = picked.end;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final err = await ref.read(donationsProvider.notifier).createCampaign({
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      'targetAmount': targetCtrl.text.isEmpty ? null : double.tryParse(targetCtrl.text),
                      'startDate': startDate.toIso8601String(),
                      'endDate': endDate?.toIso8601String(),
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  child: const Text('Create Campaign'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CampaignsList extends ConsumerWidget {
  final void Function({String? campaignId, String? campaignTitle}) onDonate;
  final String Function(dynamic) fmt;
  const _CampaignsList({required this.onDonate, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(donationCampaignsProvider);
    return async.when(
      loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 100),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (campaigns) {
        if (campaigns.isEmpty) {
          return const AppEmptyState(
            emoji: '🎗️',
            title: 'No Campaigns Yet',
            subtitle: 'Admins can create donation campaigns for festivals or events.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(donationCampaignsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            itemCount: campaigns.length,
            separatorBuilder: (_, i) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = campaigns[i] as Map<String, dynamic>;
              final total = (c['donations'] as List? ?? [])
                  .fold<double>(0, (s, d) => s + (double.tryParse(d['amount'].toString()) ?? 0));
              final target = c['targetAmount'] != null ? double.tryParse(c['targetAmount'].toString()) : null;
              final pct = (target != null && target > 0) ? (total / target).clamp(0.0, 1.0) : null;
              final count = c['_count']?['donations'] ?? 0;
              final isActive = c['isActive'] == true;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(c['title'] ?? '', style: AppTextStyles.labelLarge)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.successSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(isActive ? 'Active' : 'Closed',
                            style: AppTextStyles.caption.copyWith(
                                color: isActive ? AppColors.successText : AppColors.textSecondary)),
                      ),
                    ]),
                    if (c['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(c['description'], style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('$count donors', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(fmt(total), style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                      if (target != null) Text(' / ${fmt(target)}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ]),
                    if (pct != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: pct, minHeight: 6,
                            backgroundColor: AppColors.surface,
                            valueColor: AlwaysStoppedAnimation(AppColors.success)),
                      ),
                    ],
                    if (isActive) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.volunteer_activism, size: 16),
                          label: const Text('Donate to this campaign'),
                          onPressed: () => onDonate(campaignId: c['id'], campaignTitle: c['title']),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DonationsList extends ConsumerWidget {
  final String? campaignId;
  final String Function(dynamic) fmt;
  const _DonationsList({this.campaignId, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(donationsProvider);
    return async.when(
      loading: () => const AppLoadingShimmer(itemCount: 6, itemHeight: 70),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        final list = data['donations'] as List? ?? [];
        if (list.isEmpty) {
          return const AppEmptyState(
            emoji: '💝',
            title: 'No Donations Yet',
            subtitle: 'Be the first to donate to a campaign.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(donationsProvider.notifier).fetchDonations(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = list[i] as Map<String, dynamic>;
              final donor = d['donor'];
              final campaign = d['campaign'];
              final date = d['paidAt'] != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(d['paidAt']))
                  : '';
              return AppCard(
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Icon(Icons.volunteer_activism, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(donor?['name'] ?? 'Unknown', style: AppTextStyles.labelMedium),
                    if (campaign != null)
                      Text(campaign['title'], style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ])),
                  Text(fmt(d['amount']), style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
                ]),
              );
            },
          ),
        );
      },
    );
  }
}
