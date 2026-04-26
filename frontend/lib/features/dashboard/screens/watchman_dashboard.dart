import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_portal_widgets.dart';
import 'qr_scan_screen.dart';

/// Dashboard for WATCHMAN role
class WatchmanDashboard extends ConsumerWidget {
  const WatchmanDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(watchmanDashboardProvider);
    final user = ref.watch(authProvider).user;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 3, itemHeight: 120),
      error: (e, _) => _ErrorCard(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(watchmanDashboardProvider),
      ),
      data: (stats) => DashboardRefreshWithSearchStack(
        onRefresh: () async => ref.refresh(watchmanDashboardProvider.future),
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        scrollChild: _WatchmanLayout(stats: stats, user: user),
      ),
    );
  }
}

// ── Main layout ────────────────────────────────────────────────────────────────

class _WatchmanLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final dynamic user;
  const _WatchmanLayout({required this.stats, required this.user});

  @override
  Widget build(BuildContext context) {
    final scans = stats['todayVisitorScans'] ?? 0;
    final deliveries = stats['pendingDeliveries'] ?? 0;
    final gatePasses = stats['activeGatePasses'] ?? 0;
    final parkingActive = stats['parking']?['activeSessions'] ?? 0;
    final parkingOverstayed = stats['parking']?['overstayed'] ?? 0;
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Watchman';
    final unitCode = user?.unitCode?.toString().trim();
    final subtitle = (unitCode != null && unitCode.isNotEmpty)
        ? 'Gate · Unit $unitCode'
        : dashboardRoleSubtitle('WATCHMAN');

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final statCards = [
          _StatCard(
            icon: Icons.person_pin_circle_rounded,
            label: 'Visitor Scans',
            value: '$scans',
            subtitle: 'Today',
            gradient: AppColors.gradientBlue,
          ),
          _StatCard(
            icon: Icons.local_shipping_rounded,
            label: 'Deliveries',
            value: '$deliveries',
            subtitle: 'Pending',
            gradient: AppColors.gradientGreen,
          ),
          _StatCard(
            icon: Icons.badge_rounded,
            label: 'Gate Passes',
            value: '$gatePasses',
            subtitle: 'Active',
            gradient: AppColors.gradientPurple,
          ),
          _StatCard(
            icon: Icons.local_parking_rounded,
            label: 'Parking',
            value: '$parkingActive',
            subtitle: parkingOverstayed > 0 ? '$parkingOverstayed overstayed' : 'Active',
            gradient: parkingOverstayed > 0 ? AppColors.gradientOrange : AppColors.gradientBlue,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardGreetingHeader(
              title: 'Gate',
              greeting: dashboardGreetingForNow(),
              name: name,
              subtitle: subtitle,
              compact: narrow,
              onNotifications: () => context.go('/notifications'),
            ),
            const SizedBox(height: AppDimensions.md),
            _ScanQrButton(),
            const SizedBox(height: AppDimensions.lg),

            if (narrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < statCards.length; i++) ...[
                    statCards[i],
                    if (i < statCards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              )
            else
              Row(
                children: statCards
                    .expand((c) => [Expanded(child: c), const SizedBox(width: 12)])
                    .toList()
                  ..removeLast(),
              ),
            const SizedBox(height: AppDimensions.xl),

            DashboardSectionHeaderRow(
              title: 'Quick access',
              actionLabel: 'Visitors',
              onAction: () => context.go('/visitors'),
            ),
            const SizedBox(height: AppDimensions.md),
            _QuickAccessGrid(crossAxisCount: narrow ? 2 : 4),
            const SizedBox(height: AppDimensions.xl),

            _ActivityCard(stats: stats),
          ],
        );
      },
    );
  }
}

// ── Big QR scan button ─────────────────────────────────────────────────────────

class _ScanQrButton extends StatefulWidget {
  @override
  State<_ScanQrButton> createState() => _ScanQrButtonState();
}

class _ScanQrButtonState extends State<_ScanQrButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openScanner(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pulsing icon container
            AnimatedBuilder(
              animation: _scale,
              builder: (_, child) => Transform.scale(
                scale: _scale.value,
                child: child,
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan QR Code',
                    style: AppTextStyles.h1.copyWith(
                        color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verify gate passes, visitors,\ndeliveries & domestic help',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Open Camera',
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final LinearGradient gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: AppTextStyles.amountLarge.copyWith(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white.withValues(alpha: 0.65))),
        ],
      ),
    );
  }
}

// ── Quick access grid ──────────────────────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  final int crossAxisCount;
  const _QuickAccessGrid({this.crossAxisCount = 4});

  static const _items = [
    _AccessItem(Icons.person_pin_circle_rounded, 'Visitors',
        '/visitors', AppColors.primary),
    _AccessItem(Icons.badge_rounded, 'Gate Passes',
        '/gatepasses', AppColors.info),
    _AccessItem(Icons.local_shipping_rounded, 'Deliveries',
        '/deliveries', AppColors.success),
    _AccessItem(Icons.cleaning_services_rounded, 'Domestic Help',
        '/domestichelp', AppColors.teal),
    _AccessItem(Icons.local_parking_rounded, 'Parking',
        '/parking', AppColors.warning),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: crossAxisCount <= 2 ? 1.35 : 0.88,
      children: _items
          .map((item) => _AccessTile(item: item))
          .toList(),
    );
  }
}

class _AccessItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _AccessItem(this.icon, this.label, this.route, this.color);
}

class _AccessTile extends StatelessWidget {
  final _AccessItem item;
  const _AccessTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today's activity card ──────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ActivityCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final overstayed = stats['parking']?['overstayed'] ?? 0;
    final rows = [
      _Row(Icons.person_pin_circle_rounded, AppColors.primary,
          'Visitor Scans Today', '${stats['todayVisitorScans'] ?? 0}'),
      _Row(Icons.local_shipping_rounded, AppColors.success,
          'Pending Deliveries', '${stats['pendingDeliveries'] ?? 0}'),
      _Row(Icons.badge_rounded, AppColors.info,
          'Active Gate Passes', '${stats['activeGatePasses'] ?? 0}'),
      _Row(Icons.directions_car_rounded, AppColors.primary,
          'Active Parking Sessions', '${stats['parking']?['activeSessions'] ?? 0}'),
      if (overstayed > 0)
        _Row(Icons.warning_rounded, AppColors.danger,
            'Overstayed Vehicles', '$overstayed'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.timeline_rounded,
                      size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text("Today's Gate Activity", style: AppTextStyles.h2),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.asMap().entries.map((e) {
            final row = e.value;
            return Column(
              children: [
                if (e.key > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: row.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(row.icon, color: row.color, size: 17),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(row.label,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: row.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          row.value,
                          style: AppTextStyles.labelLarge.copyWith(
                              color: row.color, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _Row {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Row(this.icon, this.color, this.label, this.value);
}

// ── Error card ─────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 26),
            ),
            const SizedBox(height: 14),
            Text('Failed to load', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
