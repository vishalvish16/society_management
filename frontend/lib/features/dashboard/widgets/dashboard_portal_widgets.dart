import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/search_result_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/global_search_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/settings/providers/permissions_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

String dashboardGreetingForNow() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Readable subtitle for dashboard headers (society roles + residents + gate).
String dashboardRoleSubtitle(String role) {
  final r = role.toUpperCase();
  return switch (r) {
    'PRAMUKH' || 'CHAIRMAN' => 'Chairman',
    'VICE_CHAIRMAN' => 'Vice Chairman',
    'SECRETARY' => 'Secretary',
    'ASSISTANT_SECRETARY' => 'Asst. Secretary',
    'TREASURER' => 'Treasurer',
    'ASSISTANT_TREASURER' => 'Asst. Treasurer',
    'MEMBER' => 'Member',
    'RESIDENT' => 'Resident',
    'WATCHMAN' => 'Watchman',
    'MANAGER' => 'Manager',
    'SUPER_ADMIN' => 'Super Admin',
    _ => r.replaceAll('_', ' '),
  };
}

bool dashboardStatsHasTrends(Map<String, dynamic> stats) {
  final t = stats['trends'];
  if (t is! Map) return false;
  final c = t['collections'];
  return c is Map && c['values'] is List;
}

List<double> trendValuesFromDashboardStats(Map<String, dynamic> stats, {required String key}) {
  final trends = stats['trends'];
  if (trends is Map) {
    final t = trends[key];
    if (t is Map) {
      final rawValues = t['values'];
      if (rawValues is List) {
        final vals = rawValues
            .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()))
            .whereType<double>()
            .toList();
        if (vals.length >= 6) return vals.take(6).toList();
        if (vals.isNotEmpty) {
          final pad = List<double>.filled(6 - vals.length, vals.last);
          return [...vals, ...pad];
        }
      }
    }
  }
  return const [20, 32, 28, 44, 40, 56];
}

// ── Section header ─────────────────────────────────────────────────────────

class DashboardSectionHeaderRow extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const DashboardSectionHeaderRow({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.h2)),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ── Greeting + optional global search ───────────────────────────────────────

class DashboardGreetingHeader extends ConsumerWidget {
  final String title;
  final String greeting;
  final String name;
  final String subtitle;
  final VoidCallback onNotifications;
  final bool compact;
  final bool enableSearch;
  const DashboardGreetingHeader({
    super.key,
    required this.title,
    required this.greeting,
    required this.name,
    required this.subtitle,
    required this.onNotifications,
    this.compact = false,
    this.enableSearch = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(dashboardSearchLayerLinkProvider);
    final pad = compact
        ? const EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.md, AppDimensions.md, AppDimensions.md)
        : const EdgeInsets.symmetric(
            horizontal: AppDimensions.xl,
            vertical: AppDimensions.lg,
          );

    final greetingStyle = compact ? AppTextStyles.h1 : AppTextStyles.displayMedium;

    final greetingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          '$greeting, $name',
          style: greetingStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTextStyles.bodySmallMuted),
      ],
    );

    return AppCard(
      padding: pad,
      child: !enableSearch
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: greetingBlock),
                DashboardIconCircleButton(
                  icon: Icons.notifications_outlined,
                  onPressed: onNotifications,
                  tooltip: 'Notifications',
                ),
              ],
            )
          : compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: greetingBlock),
                        DashboardIconCircleButton(
                          icon: Icons.notifications_outlined,
                          onPressed: onNotifications,
                          tooltip: 'Notifications',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    DashboardGlobalSearchField(link: link, dense: true),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: greetingBlock),
                    const SizedBox(width: AppDimensions.lg),
                    Flexible(
                      flex: 2,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: DashboardGlobalSearchField(link: link),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    DashboardIconCircleButton(
                      icon: Icons.notifications_outlined,
                      onPressed: onNotifications,
                      tooltip: 'Notifications',
                    ),
                    const SizedBox(width: AppDimensions.sm),
                  ],
                ),
    );
  }
}

class DashboardIconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  const DashboardIconCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textSecondary),
        tooltip: tooltip,
      ),
    );
  }
}

class DashboardGlobalSearchField extends ConsumerStatefulWidget {
  final LayerLink link;
  final bool dense;
  const DashboardGlobalSearchField({super.key, required this.link, this.dense = false});

  @override
  ConsumerState<DashboardGlobalSearchField> createState() => _DashboardGlobalSearchFieldState();
}

class _DashboardGlobalSearchFieldState extends ConsumerState<DashboardGlobalSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) ref.read(globalSearchProvider.notifier).clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: widget.link,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: (v) => ref.read(globalSearchProvider.notifier).setQuery(v),
        style: widget.dense ? AppTextStyles.bodyMedium : null,
        decoration: InputDecoration(
          hintText: widget.dense ? 'Search society…' : 'Search members, units, bills, complaints...',
          isDense: widget.dense,
          contentPadding: widget.dense
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : null,
          prefixIcon: Icon(Icons.search_rounded, size: widget.dense ? 20 : 24),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Maps a search result route prefix to the role-permission feature key and optional plan feature key.
/// Used to filter out results the user cannot navigate to.
const _routeFeatureMap = <String, ({String roleKey, String? planKey})>{
  '/members':      (roleKey: 'members',      planKey: null),
  '/units':        (roleKey: 'units',        planKey: null),
  '/bills':        (roleKey: 'bills',        planKey: null),
  '/expenses':     (roleKey: 'expenses',     planKey: 'expenses'),
  '/complaints':   (roleKey: 'complaints',   planKey: null),
  '/suggestions':  (roleKey: 'suggestions',  planKey: null),
  '/visitors':     (roleKey: 'visitors',     planKey: 'visitors'),
  '/vehicles':     (roleKey: 'vehicles',     planKey: null),
  '/deliveries':   (roleKey: 'deliveries',   planKey: 'delivery_tracking'),
  '/domestichelp': (roleKey: 'domestic_help', planKey: 'domestic_help'),
  '/staff':        (roleKey: 'staff',        planKey: null),
  '/assets':       (roleKey: 'assets',       planKey: 'asset_management'),
};

class DashboardGlobalSearchOverlay extends ConsumerWidget {
  final LayerLink link;
  const DashboardGlobalSearchOverlay({super.key, required this.link});

  bool _canNavigate(GlobalSearchResult result, UserModel? user, Map<String, bool>? rolePerms) {
    if (user == null) return false;
    if (user.role == 'SUPER_ADMIN') return true;
    if (result.route.isEmpty) return false;

    for (final entry in _routeFeatureMap.entries) {
      final prefix = entry.key;
      if (!result.route.startsWith(prefix)) continue;

      // Plan gate
      final planKey = entry.value.planKey;
      if (planKey != null && !user.hasFeature(planKey)) return false;

      // Role permission gate
      final roleKey = entry.value.roleKey;
      if (rolePerms != null && rolePerms[roleKey] != true) return false;

      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(globalSearchProvider);
    if (st.query.length < 2) return const SizedBox.shrink();

    final user = ref.watch(authProvider).user;
    final rolePerms = ref.watch(rolePermissionsProvider).valueOrNull
        ?.rolePermissions[user?.role.toUpperCase() ?? ''];

    final results = st.results.where((r) => _canNavigate(r, user, rolePerms)).toList();
    final screenW = MediaQuery.sizeOf(context).width;
    final dropdownW = (screenW - AppDimensions.screenPadding * 2).clamp(260.0, 420.0);

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      offset: const Offset(0, 52),
      child: Material(
        color: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: SizedBox(
          width: dropdownW,
          child: AppCard(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: st.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(AppDimensions.md),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          child: Text('No results', style: AppTextStyles.bodySmallMuted),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => DashboardSearchResultTile(
                            result: results[i],
                            onTap: () {
                              ref.read(globalSearchProvider.notifier).clear();
                              context.go(results[i].route);
                            },
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardSearchResultTile extends StatelessWidget {
  final GlobalSearchResult result;
  final VoidCallback onTap;
  const DashboardSearchResultTile({super.key, required this.result, required this.onTap});

  IconData _iconForType(String type) {
    switch (type) {
      case 'member':
        return Icons.person_rounded;
      case 'unit':
        return Icons.apartment_rounded;
      case 'bill':
        return Icons.receipt_long_rounded;
      case 'complaint':
        return Icons.report_problem_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'visitor':
        return Icons.badge_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'domestic_help':
        return Icons.cleaning_services_rounded;
      case 'staff':
        return Icons.security_rounded;
      case 'asset':
        return Icons.inventory_2_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(result.type);
    return ListTile(
      dense: true,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(result.title, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: result.subtitle.isEmpty
          ? null
          : Text(result.subtitle, style: AppTextStyles.bodySmallMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
    );
  }
}

// ── Trend chart (shared) ─────────────────────────────────────────────────────

class DashboardTrendPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<double> data;
  const DashboardTrendPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h2),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmallMuted),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Live', style: AppTextStyles.labelMedium.copyWith(color: color)),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _MiniLineChartPainter(color: color, data: data),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              _LegendDot(color: color, label: 'This period'),
              const SizedBox(width: AppDimensions.md),
              _LegendDot(color: AppColors.border, label: 'Target'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmallMuted),
      ],
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  final Color color;
  final List<double> data;
  const _MiniLineChartPainter({required this.color, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.fill;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    canvas.drawRRect(r, bg);

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final vals = data.isEmpty ? const [1.0, 1.0, 1.0, 1.0, 1.0, 1.0] : data;
    final minV = vals.reduce(math.min);
    final maxV = vals.reduce(math.max);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final stepX = size.width / math.max(1, vals.length - 1);

    Offset pt(int i) {
      final x = stepX * i;
      final t = (vals[i] - minV) / range;
      final y = size.height - (t * (size.height * 0.75) + size.height * 0.12);
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < vals.length; i++) {
      final p = pt(i);
      path.lineTo(p.dx, p.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(pt(vals.length - 1).dx, size.height)
      ..lineTo(pt(0).dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dot = Paint()..color = color;
    for (int i = 0; i < vals.length; i++) {
      final p = pt(i);
      canvas.drawCircle(p, 3, dot);
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white.withValues(alpha: 0.9));
      canvas.drawCircle(p, 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.data != data;
  }
}

/// Standard [RefreshIndicator] > [Stack] > scroll + search overlay (society users).
class DashboardRefreshWithSearchStack extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  final Widget scrollChild;
  final EdgeInsetsGeometry padding;
  /// When false, only pull-to-refresh + scroll (e.g. platform super-admin).
  final bool showSearchOverlay;
  const DashboardRefreshWithSearchStack({
    super.key,
    required this.onRefresh,
    required this.scrollChild,
    this.padding = const EdgeInsets.all(AppDimensions.screenPadding),
    this.showSearchOverlay = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: scrollChild,
          ),
          if (showSearchOverlay)
            DashboardGlobalSearchOverlay(link: ref.watch(dashboardSearchLayerLinkProvider)),
        ],
      ),
    );
  }
}
