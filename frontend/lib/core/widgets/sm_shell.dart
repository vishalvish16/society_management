import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/global_search_provider.dart';
import '../models/search_result_model.dart';
import '../theme/app_colors.dart';
import '../../shared/widgets/confirm_logout.dart';
import '../../shared/widgets/app_pull_to_refresh.dart';
import '../../features/settings/providers/permissions_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../features/settings/screens/profile_screen.dart';

class SMShell extends ConsumerStatefulWidget {
  final Widget child;
  const SMShell({super.key, required this.child});

  @override
  ConsumerState<SMShell> createState() => _SMShellState();
}

class _SMShellState extends ConsumerState<SMShell> {
  int _selectedIndex = 0;

  // Backend configurable roles: only these should be affected by Settings -> Permissions toggles.
  // Matches backend `CONFIGURABLE_ROLES` list in `settings.controller.js`.
  static const _permissionControlledRoles = {
    'PRAMUKH',
    'CHAIRMAN',
    'SECRETARY',
    'MANAGER',
    'VICE_CHAIRMAN',
    'ASSISTANT_SECRETARY',
    'TREASURER',
    'ASSISTANT_TREASURER',
    'MEMBER',
    'RESIDENT',
    'WATCHMAN',
  };

  // Full nav for Chairman / Secretary / Manager.
  // featureKey: must match a key in plan.features (null = always visible regardless of plan).
  static const _allNavItems = [
    _NavItem(icon: Icons.dashboard_rounded,              label: 'Dashboard',      path: '/dashboard',        group: 'Main',    permissionKey: 'dashboard'),
    _NavItem(icon: Icons.apartment_rounded,              label: 'Units',          path: '/units',            group: 'Main',    permissionKey: 'units'),
    _NavItem(icon: Icons.key_rounded,                    label: 'Rentals',        path: '/rentals',          group: 'Main'),
    _NavItem(icon: Icons.people_rounded,                 label: 'Members',        path: '/members',          group: 'Main',    permissionKey: 'members'),
    _NavItem(icon: Icons.receipt_long_rounded,           label: 'Bills',          path: '/bills',            group: 'Finance', permissionKey: 'bills'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Expenses',       path: '/expenses',         group: 'Finance', permissionKey: 'expenses', featureKey: 'expenses'),
    _NavItem(icon: Icons.volunteer_activism_rounded,     label: 'Donations',      path: '/donations',        group: 'Finance', permissionKey: 'donations', featureKey: 'donations'),
    _NavItem(icon: Icons.balance_rounded,                label: 'Balance Report', path: '/reports/balance',  group: 'Finance', permissionKey: 'balance_report', featureKey: 'financial_reports'),
    _NavItem(icon: Icons.assignment_late_rounded,         label: 'Pending Dues',   path: '/reports/dues',     group: 'Finance', permissionKey: 'pending_dues'),
    _NavItem(icon: Icons.person_pin_circle_rounded,      label: 'Visitors',       path: '/visitors',         group: 'Security', permissionKey: 'visitors', featureKey: 'visitors'),
    _NavItem(icon: Icons.badge_rounded,                  label: 'Gate Passes',    path: '/gatepasses',       group: 'Security', permissionKey: 'gate_passes', featureKey: 'gate_passes'),
    _NavItem(icon: Icons.directions_car_rounded,         label: 'Vehicles',       path: '/vehicles',         group: 'Security', permissionKey: 'vehicles'),
    _NavItem(icon: Icons.local_parking_rounded,          label: 'Parking',        path: '/parking',          group: 'Security', permissionKey: 'parking', featureKey: 'parking_management'),
    _NavItem(icon: Icons.report_problem_rounded,         label: 'Complaints',     path: '/complaints',       group: 'Society', permissionKey: 'complaints'),
    _NavItem(icon: Icons.lightbulb_rounded,              label: 'Suggestions',   path: '/suggestions',      group: 'Society', permissionKey: 'suggestions'),
    _NavItem(icon: Icons.campaign_rounded,               label: 'Notices',        path: '/notices',          group: 'Society', permissionKey: 'notices'),
    _NavItem(icon: Icons.how_to_vote_rounded,            label: 'Polls',          path: '/polls',            group: 'Society', permissionKey: 'polls'),
    _NavItem(icon: Icons.event_rounded,                   label: 'Events',         path: '/events',           group: 'Society', permissionKey: 'events'),
    _NavItem(icon: Icons.task_alt_rounded,                 label: 'Tasks',          path: '/tasks',            group: 'Society'),
    _NavItem(icon: Icons.gavel_rounded,                   label: 'Rules',          path: '/rules',            group: 'Society'),
    _NavItem(icon: Icons.inventory_2_rounded,              label: 'Assets',         path: '/assets',           group: 'Society', featureKey: 'asset_management'),
    _NavItem(icon: Icons.sports_basketball_rounded,      label: 'Amenities',      path: '/amenities',        group: 'Society', permissionKey: 'amenities', featureKey: 'amenities'),
    _NavItem(icon: Icons.support_agent_rounded,          label: 'Staff',          path: '/staff',            group: 'Society', permissionKey: 'staff'),
    _NavItem(icon: Icons.local_shipping_rounded,         label: 'Deliveries',     path: '/deliveries',       group: 'Society', permissionKey: 'deliveries', featureKey: 'delivery_tracking'),
    _NavItem(icon: Icons.cleaning_services_rounded,      label: 'Domestic Help',  path: '/domestichelp',     group: 'Society', permissionKey: 'domestic_help', featureKey: 'domestic_help'),
    _NavItem(icon: Icons.dynamic_feed_rounded,            label: 'Wall',           path: '/wall',             group: 'Society'),
    _NavItem(icon: Icons.chat_rounded,                   label: 'Messages',       path: '/chat',             group: 'More',    permissionKey: 'chat'),
    _NavItem(icon: Icons.notifications_rounded,          label: 'Notifications',  path: '/notifications',    group: 'More',    permissionKey: 'notifications'),
    _NavItem(icon: Icons.settings_rounded,               label: 'Settings',       path: '/settings',         group: 'More'),
  ];

  // Paths hidden for member/resident roles — they see their unit in sidebar instead
  static const _memberHiddenPaths = {'/units', '/rentals', '/reports/balance'};

  // Titles for sub-pages that don't match a nav item label.
  static const _subPageTitles = {
    '/bills/audit-logs': 'Bill Audit Logs',
    '/visitors/pending-approvals': 'Gate Approvals',
    '/donations/receipt': 'Donation Receipt',
    '/settings/permissions': 'Role Permissions',
    '/chat/members': 'New Message',
    '/reports/balance': 'Balance Report',
    '/reports/dues': 'Pending Dues',
  };

  String _shellTitle(String location, List<_NavItem> navItems, int safeIndex) {
    for (final e in _subPageTitles.entries) {
      if (location == e.key || location.startsWith('${e.key}/')) return e.value;
    }
    if (location.startsWith('/chat/room/')) return 'Messages';
    if (navItems.isEmpty) return '';
    return navItems[safeIndex].label;
  }

  // Watchman sees only gate-related screens
  static const _watchmanNavItems = [
    _NavItem(icon: Icons.grid_view_rounded,          label: 'Dashboard',     path: '/dashboard',    group: 'Main', permissionKey: 'dashboard'),
    _NavItem(icon: Icons.person_pin_circle_rounded,  label: 'Visitors',      path: '/visitors',     group: 'Gate', permissionKey: 'visitors', featureKey: 'visitors'),
    _NavItem(icon: Icons.badge_rounded,              label: 'Gate Passes',   path: '/gatepasses',   group: 'Gate', permissionKey: 'gate_passes', featureKey: 'gate_passes'),
    _NavItem(icon: Icons.local_parking_rounded,      label: 'Parking',       path: '/parking',      group: 'Gate', permissionKey: 'parking', featureKey: 'parking_management'),
    _NavItem(icon: Icons.local_shipping_rounded,     label: 'Deliveries',    path: '/deliveries',   group: 'Gate', permissionKey: 'deliveries', featureKey: 'delivery_tracking'),
    _NavItem(icon: Icons.cleaning_services_rounded,  label: 'Domestic Help', path: '/domestichelp', group: 'Gate', permissionKey: 'domestic_help', featureKey: 'domestic_help'),
    _NavItem(icon: Icons.notifications_rounded,      label: 'Notifications', path: '/notifications',group: 'More', permissionKey: 'notifications'),
  ];

  static const _watchmanBottomItems = [
    _NavItem(icon: Icons.grid_view_rounded,         label: 'Home',       path: '/dashboard'),
    _NavItem(icon: Icons.person_pin_circle_rounded, label: 'Visitors',   path: '/visitors'),
    _NavItem(icon: Icons.badge_rounded,             label: 'Gate Pass',  path: '/gatepasses'),
    _NavItem(icon: Icons.local_shipping_rounded,    label: 'Deliveries', path: '/deliveries'),
    _NavItem(icon: Icons.menu_rounded,              label: 'More',       path: '__menu__'),
  ];

  // Bottom nav shows the most-used 5 items on mobile
  static const _mobileBottomItems = [
    _NavItem(icon: Icons.dashboard_rounded,      label: 'Home',     path: '/dashboard'),
    _NavItem(icon: Icons.receipt_long_rounded,   label: 'Bills',    path: '/bills'),
    _NavItem(icon: Icons.chat_rounded,           label: 'Messages', path: '/chat'),
    _NavItem(icon: Icons.report_problem_rounded, label: 'Issues',   path: '/complaints'),
    _NavItem(icon: Icons.menu_rounded,           label: 'More',     path: '__menu__'),
  ];

  bool _allowed(
    _NavItem n,
    UserModel? user,
    Map<String, bool>? rolePerms,
  ) {
    // Role permissions (Admin toggles).
    if (n.permissionKey != null) {
      if (user?.isSuperAdmin == true) return true;
      final roleKey = (user?.role ?? '').toUpperCase();
      // Only enforce for roles that are actually configurable in the backend.
      if (!_permissionControlledRoles.contains(roleKey)) return true;
      // For permission-controlled roles, keep Dashboard accessible even while permissions are loading.
      if (n.permissionKey == 'dashboard') return true;
      // Deny-by-default until loaded to avoid flashing restricted items.
      if (rolePerms == null) return false;
      if (rolePerms[n.permissionKey!] != true) return false;
    }

    // Plan features (subscription plan).
    if (n.featureKey == null) return true;
    return user?.hasFeature(n.featureKey!) ?? false;
  }

  List<_NavItem> _visibleNavItems(
    String role,
    bool isUnitLocked,
    UserModel? user,
    Map<String, bool>? rolePerms,
  ) {
    if (role.toUpperCase() == 'WATCHMAN') {
      return _watchmanNavItems.where((n) => _allowed(n, user, rolePerms)).toList();
    }
    return _allNavItems.where((n) {
      if (isUnitLocked && _memberHiddenPaths.contains(n.path)) return false;
      return _allowed(n, user, rolePerms);
    }).toList();
  }

  List<_NavItem> _bottomItems(String role, UserModel? user, Map<String, bool>? rolePerms) {
    if (role.toUpperCase() == 'WATCHMAN') {
      return _watchmanBottomItems.where((n) => _allowed(n, user, rolePerms)).toList();
    }
    return _mobileBottomItems.where((n) => _allowed(n, user, rolePerms)).toList();
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      enableDrag: true,
      builder: (_) => const _SearchModal(),
    );
  }

  void _onNavTap(int index, List<_NavItem> navItems) {
    final path = navItems[index].path;
    setState(() => _selectedIndex = index);
    context.go(path);
  }

  void _onMobileBottomTap(
    BuildContext ctx,
    int index,
    List<_NavItem> navItems, [
    List<_NavItem>? bottomItems,
  ]) {
    final items = bottomItems ?? _mobileBottomItems;
    if (index >= items.length) return;
    final item = items[index];
    if (item.path == '__menu__') {
      Scaffold.of(ctx).openDrawer();
      return;
    }
    final mainIndex = navItems.indexWhere((n) => n.path == item.path);
    if (mainIndex >= 0) setState(() => _selectedIndex = mainIndex);
    context.go(item.path);
  }

  int _mobileBottomIndex(List<_NavItem> navItems, List<_NavItem> bottomItems) {
    if (_selectedIndex >= navItems.length) return bottomItems.length - 1;
    final currentPath = navItems[_selectedIndex].path;
    final idx = bottomItems.indexWhere((i) => i.path == currentPath);
    return idx >= 0 ? idx : bottomItems.length - 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = ref.read(authProvider);
    final role = authState.user?.role ?? '';
    final isUnitLocked = authState.user?.isUnitLocked ?? false;
    final permsAsync = ref.read(rolePermissionsProvider);
    final roleKey = role.toUpperCase();
    final rolePerms = permsAsync.valueOrNull?.rolePermissions[roleKey];
    final navItems = _visibleNavItems(role, isUnitLocked, authState.user, rolePerms);
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < navItems.length; i++) {
      if (location == navItems[i].path ||
          (location.startsWith(navItems[i].path) && navItems[i].path != '/')) {
        if (_selectedIndex != i) setState(() => _selectedIndex = i);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.user?.role ?? '';
    final isUnitLocked = authState.user?.isUnitLocked ?? false;
    final location = GoRouterState.of(context).uri.toString();

    final permsAsync = ref.watch(rolePermissionsProvider);
    final roleKey = role.toUpperCase();
    final rolePerms = permsAsync.valueOrNull?.rolePermissions[roleKey];

    final navItems = _visibleNavItems(role, isUnitLocked, authState.user, rolePerms);
    final bottomItems = _bottomItems(role, authState.user, rolePerms);
    final safeIndex = navItems.isEmpty ? 0 : _selectedIndex.clamp(0, navItems.length - 1);
    final isWide = MediaQuery.of(context).size.width >= 900;

    _NavItem? currentModuleItem() {
      if (navItems.isEmpty) return null;
      final current = navItems[safeIndex];
      // Keep "More" fallback resilient if selection lags route updates.
      final byPrefix = navItems.firstWhere(
        (n) =>
            location == n.path ||
            (location.startsWith(n.path) && n.path != '/'),
        orElse: () => current,
      );
      return byPrefix;
    }

    final moduleItem = currentModuleItem();
    final moduleRoot = moduleItem?.path;
    final isSubPage = moduleRoot != null &&
        moduleRoot != '/' &&
        location != moduleRoot &&
        location.startsWith(moduleRoot);


    Future<void> doRefresh() async {
      // Replacing the current location rebuilds the screen, which is the closest
      // "refresh" behavior that works consistently for all pages.
      context.replace(location);
      // Let the navigation rebuild occur before finishing the indicator.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (navItems.isEmpty) {
      // This should only happen briefly while role permissions are loading.
      // Still render the current route content.
      return Scaffold(
        body: Row(
          children: [
            if (isWide) const SizedBox.shrink(),
            Expanded(
              child: AppPullToRefresh(
                onRefresh: doRefresh,
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: isWide ? null : _buildDrawer(authState, navItems, isUnitLocked),
      // Mobile top app bar with hamburger
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              actionsIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              elevation: 0,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(
                    isSubPage ? Icons.arrow_back_rounded : Icons.menu_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () {
                    if (isSubPage) {
                      context.go(moduleRoot);
                      return;
                    }
                    Scaffold.of(ctx).openDrawer();
                  },
                ),
              ),
              title: Row(
                children: [
                  Text(
                    _shellTitle(location, navItems, safeIndex),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  // Unit chip for member/resident in the AppBar
                  if (isUnitLocked && authState.user?.unitCode != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apartment_rounded, size: 11, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            authState.user!.unitCode!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  tooltip: 'Search',
                  onPressed: () => _openSearch(context),
                ),
                IconButton(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    backgroundImage: () {
                      final u = authState.user;
                      final url = AppConstants.uploadUrlFromPath(u?.profilePhotoUrl);
                      if (url == null) return null;
                      return NetworkImage('$url?v=${authState.avatarRevision}');
                    }(),
                    child: AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl) == null
                        ? Text(
                            (authState.user?.name ?? 'U').substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  tooltip: 'My profile',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(authState, navItems, isUnitLocked),
          Expanded(
            child: AppPullToRefresh(
              onRefresh: doRefresh,
              child: widget.child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : Builder(
              builder: (ctx) => NavigationBar(
                selectedIndex: _mobileBottomIndex(navItems, bottomItems),
                onDestinationSelected: (i) => _onMobileBottomTap(ctx, i, navItems, bottomItems),
                height: 64,
                destinations: bottomItems
                    .map((item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ))
                    .toList(),
              ),
            ),
    );
  }

  // ── Desktop sidebar ──────────────────────────────────────────────

  Widget _buildSidebar(AuthState authState, List<_NavItem> navItems, bool isUnitLocked) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.7);
    final groupHeader = cs.onSurface.withValues(alpha: 0.45);
    final groups = <String, List<int>>{};
    for (int i = 0; i < navItems.length; i++) {
      groups.putIfAbsent(navItems[i].group ?? '', () => []).add(i);
    }

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.apartment_rounded, color: cs.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Society Manager',
                          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        authState.user?.role ?? '',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Unit badge for member/resident users
          if (isUnitLocked && authState.user?.unitCode != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.apartment_rounded, color: cs.primary, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Unit',
                            style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text(
                          authState.user!.unitCode!,
                          style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: theme.dividerColor, height: 1),

          // Nav groups
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groups.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.key.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: TextStyle(
                              color: groupHeader,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ...entry.value.map((i) => _sidebarItem(i, navItems)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // User footer
          Divider(color: theme.dividerColor, height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  backgroundImage: () {
                    final u = authState.user;
                    final url = AppConstants.uploadUrlFromPath(u?.profilePhotoUrl);
                    if (url == null) return null;
                    return NetworkImage('$url?v=${authState.avatarRevision}');
                  }(),
                  child: AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl) == null
                      ? Text(
                          (authState.user?.name ?? 'U').substring(0, 1).toUpperCase(),
                          style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authState.user?.name ?? 'User',
                          style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(authState.user?.phone ?? '',
                          style: TextStyle(color: muted, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout_rounded, color: muted, size: 18),
                  tooltip: 'Logout',
                  onPressed: () async {
                    final confirm = await showLogoutConfirmSheet(context);
                    if (!confirm) return;
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) context.go('/');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int i, List<_NavItem> navItems) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = navItems[i];
    final isSelected = _selectedIndex == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onNavTap(i, navItems),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 18,
                    color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Text(item.label,
                    style: TextStyle(
                      color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.7),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile drawer (full nav) ─────────────────────────────────────

  Widget _buildDrawer(AuthState authState, List<_NavItem> navItems, bool isUnitLocked) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.7);
    final groupHeader = cs.onSurface.withValues(alpha: 0.45);
    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.apartment_rounded, color: cs.onPrimary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Society Manager',
                            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                        Text(authState.user?.name ?? '',
                            style: TextStyle(color: muted, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: muted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Unit badge in drawer for member/resident
            if (isUnitLocked && authState.user?.unitCode != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.apartment_rounded, color: cs.primary, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Unit',
                              style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            authState.user!.unitCode!,
                            style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Divider(color: theme.dividerColor, height: 1),

            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: navItems.length,
                itemBuilder: (ctx, i) {
                  final item = navItems[i];
                  final isSelected = _selectedIndex == i;

                  // Group header
                  final showGroupHeader = i == 0 ||
                      navItems[i].group != navItems[i - 1].group;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showGroupHeader && (item.group ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            (item.group ?? '').toUpperCase(),
                            style: TextStyle(
                              color: groupHeader,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                        child: Material(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context); // close drawer
                              _onNavTap(i, navItems);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: isSelected ? cs.primary : muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isSelected ? cs.onSurface : muted,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Logout
            Divider(color: theme.dividerColor, height: 1),
            ColoredBox(
              color: cs.surface,
              child: SafeArea(
                top: false,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Icon(Icons.logout_rounded, color: muted, size: 20),
                  title: Text('Logout', style: TextStyle(color: muted, fontSize: 14)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showLogoutConfirmSheet(context);
                    if (!confirm) return;
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) context.go('/');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Master Search Modal ──────────────────────────────────────────────────────

class _SearchModal extends ConsumerStatefulWidget {
  const _SearchModal();

  @override
  ConsumerState<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends ConsumerState<_SearchModal> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _typeIcons = <String, IconData>{
    'member':       Icons.person_rounded,
    'unit':         Icons.apartment_rounded,
    'vehicle':      Icons.directions_car_rounded,
    'visitor':      Icons.person_pin_circle_rounded,
    'delivery':     Icons.local_shipping_rounded,
    'domestic_help': Icons.cleaning_services_rounded,
    'staff':        Icons.support_agent_rounded,
    'asset':        Icons.inventory_2_rounded,
    'complaint':    Icons.report_problem_rounded,
    'suggestion':   Icons.lightbulb_rounded,
    'bill':         Icons.receipt_long_rounded,
    'donation':     Icons.volunteer_activism_rounded,
    'donation_campaign': Icons.volunteer_activism_rounded,
    'menu':         Icons.menu_rounded,
  };

  static const _typeColors = <String, Color>{
    'member':       Color(0xFF2563EB),
    'unit':         Color(0xFF7C3AED),
    'vehicle':      Color(0xFF059669),
    'visitor':      Color(0xFF0891B2),
    'delivery':     Color(0xFFD97706),
    'domestic_help': Color(0xFFDB2777),
    'staff':        Color(0xFF65A30D),
    'asset':        Color(0xFF9333EA),
    'complaint':    Color(0xFFDC2626),
    'suggestion':   Color(0xFFF59E0B),
    'bill':         Color(0xFF0284C7),
    'donation':     Color(0xFF16A34A),
    'donation_campaign': Color(0xFF16A34A),
    'menu':         Color(0xFF475569),
  };

  static const _typeLabels = <String, String>{
    'member':       'Member',
    'unit':         'Unit',
    'vehicle':      'Vehicle',
    'visitor':      'Visitor',
    'delivery':     'Delivery',
    'domestic_help': 'Domestic Help',
    'staff':        'Staff',
    'asset':        'Asset',
    'complaint':    'Complaint',
    'suggestion':   'Suggestion',
    'bill':         'Bill',
    'donation':     'Donation',
    'donation_campaign': 'Campaign',
    'menu':         'Menu',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    ref.read(globalSearchProvider.notifier).clear();
    super.dispose();
  }

  void _onResultTap(GlobalSearchResult result) {
    Navigator.of(context).pop();
    ref.read(globalSearchProvider.notifier).clear();
    final route = result.route;
    if (route.isNotEmpty) context.go(route);
  }

  bool _allowedNavItem(
    _NavItem n,
    UserModel? user,
    Map<String, bool>? rolePerms,
  ) {
    // Role permissions (Admin toggles).
    if (n.permissionKey != null) {
      if (user?.isSuperAdmin == true) return true;
      final roleKey = (user?.role ?? '').toUpperCase();
      // Only enforce for roles that are actually configurable in the backend.
      if (!_SMShellState._permissionControlledRoles.contains(roleKey)) return true;
      // For permission-controlled roles, keep Dashboard accessible even while permissions are loading.
      if (n.permissionKey == 'dashboard') return true;
      // Deny-by-default until loaded to avoid flashing restricted items.
      if (rolePerms == null) return false;
      if (rolePerms[n.permissionKey!] != true) return false;
    }

    // Plan features (subscription plan).
    if (n.featureKey == null) return true;
    return user?.hasFeature(n.featureKey!) ?? false;
  }

  List<_NavItem> _visibleMenuItemsForUser() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final role = (user?.role ?? '').toUpperCase();
    final isUnitLocked = user?.isUnitLocked ?? false;
    final permsAsync = ref.read(rolePermissionsProvider);
    final rolePerms = permsAsync.valueOrNull?.rolePermissions[role];

    final source = role == 'WATCHMAN' ? _SMShellState._watchmanNavItems : _SMShellState._allNavItems;
    return source.where((n) {
      if (role != 'WATCHMAN' && isUnitLocked && _SMShellState._memberHiddenPaths.contains(n.path)) {
        return false;
      }
      return _allowedNavItem(n, user, rolePerms);
    }).toList();
  }

  List<GlobalSearchResult> _menuResults(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];

    final menuItems = _visibleMenuItemsForUser();
    final matches = <GlobalSearchResult>[];
    for (final m in menuItems) {
      final label = m.label.trim();
      if (label.isEmpty) continue;
      if (!label.toLowerCase().contains(q)) continue;
      matches.add(
        GlobalSearchResult(
          type: 'menu',
          id: m.path,
          title: label,
          subtitle: (m.group ?? '').isNotEmpty ? (m.group ?? '') : 'Navigate',
          route: m.path,
        ),
      );
    }

    // Keep a consistent order: exact prefix matches first, then alphabetic.
    matches.sort((a, b) {
      final ap = a.title.toLowerCase().startsWith(q) ? 0 : 1;
      final bp = b.title.toLowerCase().startsWith(q) ? 0 : 1;
      if (ap != bp) return ap - bp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return matches.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(globalSearchProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inputTheme = theme.inputDecorationTheme;
    final fillColor = inputTheme.fillColor ?? cs.surface;
    final enabledBorder = (inputTheme.enabledBorder is OutlineInputBorder)
        ? (inputTheme.enabledBorder! as OutlineInputBorder)
        : null;
    final borderColor = enabledBorder?.borderSide.color ?? theme.dividerColor;
    final hintColor = inputTheme.hintStyle?.color ?? theme.hintColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? cs.onSurface;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(color: textColor, fontSize: 15),
                          cursorColor: cs.primary,
                          decoration: InputDecoration(
                            hintText: 'Search menu, members, bills, donations…',
                            hintStyle: TextStyle(color: hintColor, fontSize: 15),
                            prefixIcon: search.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : Icon(Icons.search_rounded, color: hintColor, size: 20),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded, color: hintColor, size: 18),
                                    onPressed: () {
                                      _controller.clear();
                                      ref.read(globalSearchProvider.notifier).clear();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                          ),
                          onChanged: (v) {
                            setState(() {});
                            ref.read(globalSearchProvider.notifier).setQuery(v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: cs.primary, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: theme.dividerColor, height: 1),

              // Results
              Expanded(
                child: _buildResults(search, scrollController, bottom),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults(GlobalSearchState search, ScrollController scrollController, double bottom) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final headerFallback = cs.primary;
    final surfaceBox = theme.inputDecorationTheme.fillColor ?? cs.surface;
    final borderColor = theme.dividerColor;

    // Idle / empty query
    if (search.query.isEmpty) {
      return _emptyHint(
        Icons.search_rounded,
        'Search across your society',
        'Members, bills, complaints, deliveries and more',
      );
    }

    // Minimum chars
    if (search.query.length < 2) {
      return _emptyHint(Icons.keyboard_rounded, 'Keep typing…', 'Enter at least 2 characters');
    }

    // Error
    if (search.error != null && !search.isLoading) {
      return _emptyHint(Icons.error_outline_rounded, 'Search failed', search.error!);
    }

    // No results
    final menuResults = _menuResults(search.query);
    final combined = <GlobalSearchResult>[
      ...menuResults,
      ...search.results,
    ];

    if (!search.isLoading && combined.isEmpty) {
      return _emptyHint(Icons.search_off_rounded, 'No results', 'Try a different keyword');
    }

    // Group results by type
    final grouped = <String, List<GlobalSearchResult>>{};
    for (final r in combined) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      children: [
        for (final entry in grouped.entries) ...[
          // Group header
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: (_typeColors[entry.key] ?? AppColors.primary).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    _typeIcons[entry.key] ?? Icons.category_rounded,
                    size: 12,
                    color: _typeColors[entry.key] ?? headerFallback,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (_typeLabels[entry.key] ?? entry.key).toUpperCase(),
                  style: TextStyle(
                    color: _typeColors[entry.key] ?? headerFallback,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 1,
                    color: borderColor,
                  ),
                ),
              ],
            ),
          ),
          // Result tiles
          Container(
            decoration: BoxDecoration(
              color: surfaceBox,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++) ...[
                  _resultTile(entry.value[i], entry.key),
                  if (i < entry.value.length - 1)
                    Divider(color: borderColor, height: 1, indent: 52),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultTile(GlobalSearchResult result, String type) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _typeColors[type] ?? AppColors.primary;
    final icon = _typeIcons[type] ?? Icons.category_rounded;

    return InkWell(
      onTap: () => _onResultTap(result),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color ?? cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.45), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final boxColor = theme.inputDecorationTheme.fillColor ?? cs.surface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: cs.onSurface.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color ?? cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65), fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  final String? group;
  /// If set, this nav item is only shown when the society plan includes this feature.
  /// null means always visible.
  final String? featureKey;

  /// If set, this nav item is only shown when the Admin has enabled this feature for the user's role.
  /// Keys match backend `settings/permissions` feature keys.
  final String? permissionKey;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    this.group,
    this.featureKey,
    this.permissionKey,
  });
}
