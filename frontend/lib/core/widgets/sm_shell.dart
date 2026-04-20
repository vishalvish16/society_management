import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../../shared/widgets/confirm_logout.dart';

class SMShell extends ConsumerStatefulWidget {
  final Widget child;
  const SMShell({super.key, required this.child});

  @override
  ConsumerState<SMShell> createState() => _SMShellState();
}

class _SMShellState extends ConsumerState<SMShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Full nav for Chairman / Secretary / Manager.
  // featureKey: must match a key in plan.features (null = always visible regardless of plan).
  static const _allNavItems = [
    _NavItem(icon: Icons.dashboard_rounded,              label: 'Dashboard',      path: '/dashboard',        group: 'Main'),
    _NavItem(icon: Icons.apartment_rounded,              label: 'Units',          path: '/units',            group: 'Main'),
    _NavItem(icon: Icons.people_rounded,                 label: 'Members',        path: '/members',          group: 'Main'),
    _NavItem(icon: Icons.receipt_long_rounded,           label: 'Bills',          path: '/bills',            group: 'Finance'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Expenses',       path: '/expenses',         group: 'Finance',  featureKey: 'expenses'),
    _NavItem(icon: Icons.volunteer_activism_rounded,     label: 'Donations',      path: '/donations',        group: 'Finance',  featureKey: 'donations'),
    _NavItem(icon: Icons.balance_rounded,                label: 'Balance Report', path: '/reports/balance',  group: 'Finance',  featureKey: 'financial_reports'),
    _NavItem(icon: Icons.person_pin_circle_rounded,      label: 'Visitors',       path: '/visitors',         group: 'Security', featureKey: 'visitors'),
    _NavItem(icon: Icons.badge_rounded,                  label: 'Gate Passes',    path: '/gatepasses',       group: 'Security', featureKey: 'gate_passes'),
    _NavItem(icon: Icons.directions_car_rounded,         label: 'Vehicles',       path: '/vehicles',         group: 'Security'),
    _NavItem(icon: Icons.report_problem_rounded,         label: 'Complaints',     path: '/complaints',       group: 'Society'),
    _NavItem(icon: Icons.campaign_rounded,               label: 'Notices',        path: '/notices',          group: 'Society'),
    _NavItem(icon: Icons.sports_basketball_rounded,      label: 'Amenities',      path: '/amenities',        group: 'Society',  featureKey: 'amenities'),
    _NavItem(icon: Icons.support_agent_rounded,          label: 'Staff',          path: '/staff',            group: 'Society'),
    _NavItem(icon: Icons.local_shipping_rounded,         label: 'Deliveries',     path: '/deliveries',       group: 'Society',  featureKey: 'delivery_tracking'),
    _NavItem(icon: Icons.cleaning_services_rounded,      label: 'Domestic Help',  path: '/domestichelp',     group: 'Society',  featureKey: 'domestic_help'),
    _NavItem(icon: Icons.notifications_rounded,          label: 'Notifications',  path: '/notifications',    group: 'More'),
    _NavItem(icon: Icons.settings_rounded,               label: 'Settings',       path: '/settings',         group: 'More'),
  ];

  // Paths hidden for member/resident roles — they see their unit in sidebar instead
  static const _memberHiddenPaths = {'/units', '/reports/balance'};

  // Watchman sees only gate-related screens
  static const _watchmanNavItems = [
    _NavItem(icon: Icons.grid_view_rounded,          label: 'Dashboard',     path: '/dashboard',    group: 'Main'),
    _NavItem(icon: Icons.person_pin_circle_rounded,  label: 'Visitors',      path: '/visitors',     group: 'Gate', featureKey: 'visitors'),
    _NavItem(icon: Icons.badge_rounded,              label: 'Gate Passes',   path: '/gatepasses',   group: 'Gate', featureKey: 'gate_passes'),
    _NavItem(icon: Icons.local_shipping_rounded,     label: 'Deliveries',    path: '/deliveries',   group: 'Gate', featureKey: 'delivery_tracking'),
    _NavItem(icon: Icons.cleaning_services_rounded,  label: 'Domestic Help', path: '/domestichelp', group: 'Gate', featureKey: 'domestic_help'),
    _NavItem(icon: Icons.notifications_rounded,      label: 'Notifications', path: '/notifications',group: 'More'),
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
    _NavItem(icon: Icons.dashboard_rounded,      label: 'Home',    path: '/dashboard'),
    _NavItem(icon: Icons.people_rounded,         label: 'Members', path: '/members'),
    _NavItem(icon: Icons.receipt_long_rounded,   label: 'Bills',   path: '/bills'),
    _NavItem(icon: Icons.report_problem_rounded, label: 'Issues',  path: '/complaints'),
    _NavItem(icon: Icons.menu_rounded,           label: 'More',    path: '__menu__'),
  ];

  List<_NavItem> _visibleNavItems(String role, bool isUnitLocked, UserModel? user) {
    if (role.toUpperCase() == 'WATCHMAN') return _watchmanNavItems;
    return _allNavItems.where((n) {
      if (isUnitLocked && _memberHiddenPaths.contains(n.path)) return false;
      if (n.featureKey != null && !(user?.hasFeature(n.featureKey!) ?? false)) return false;
      return true;
    }).toList();
  }

  List<_NavItem> _bottomItems(String role) {
    if (role.toUpperCase() == 'WATCHMAN') return _watchmanBottomItems;
    return _mobileBottomItems;
  }

  void _onNavTap(int index, List<_NavItem> navItems) {
    final path = navItems[index].path;
    setState(() => _selectedIndex = index);
    context.go(path);
  }

  void _onMobileBottomTap(int index, List<_NavItem> navItems, [List<_NavItem>? bottomItems]) {
    final items = bottomItems ?? _mobileBottomItems;
    if (index >= items.length) return;
    final item = items[index];
    if (item.path == '__menu__') {
      _scaffoldKey.currentState?.openDrawer();
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
    final navItems = _visibleNavItems(role, isUnitLocked, authState.user);
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
    final navItems = _visibleNavItems(role, isUnitLocked, authState.user);
    final bottomItems = _bottomItems(role);
    final safeIndex = _selectedIndex.clamp(0, navItems.length - 1);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide ? null : _buildDrawer(authState, navItems, isUnitLocked),
      // Mobile top app bar with hamburger
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Row(
                children: [
                  Text(
                    navItems[safeIndex].label,
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
                          const Icon(Icons.apartment_rounded, size: 11, color: AppColors.primaryLight),
                          const SizedBox(width: 4),
                          Text(
                            authState.user!.unitCode!,
                            style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (authState.user?.name ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(authState, navItems, isUnitLocked),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _mobileBottomIndex(navItems, bottomItems),
              onDestinationSelected: (i) => _onMobileBottomTap(i, navItems, bottomItems),
              height: 64,
              destinations: bottomItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }

  // ── Desktop sidebar ──────────────────────────────────────────────

  Widget _buildSidebar(AuthState authState, List<_NavItem> navItems, bool isUnitLocked) {
    final groups = <String, List<int>>{};
    for (int i = 0; i < navItems.length; i++) {
      groups.putIfAbsent(navItems[i].group ?? '', () => []).add(i);
    }

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
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
                  child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Society Manager',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        authState.user?.role ?? '',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                    child: const Icon(Icons.apartment_rounded, color: AppColors.primaryLight, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Unit',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                        Text(
                          authState.user!.unitCode!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: Color(0xFF1E293B), height: 1),

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
                            style: const TextStyle(
                              color: Color(0xFF475569),
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
          const Divider(color: Color(0xFF1E293B), height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (authState.user?.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authState.user?.name ?? 'User',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(authState.user?.phone ?? '',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 18),
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
                    color: isSelected ? AppColors.primaryLight : const Color(0xFF94A3B8)),
                const SizedBox(width: 12),
                Text(item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
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
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
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
                    child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Society Manager',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                        Text(authState.user?.name ?? '',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
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
                      child: const Icon(Icons.apartment_rounded, color: AppColors.primaryLight, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Unit',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            authState.user!.unitCode!,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: Color(0xFF1E293B), height: 1),

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
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        leading: Icon(item.icon,
                            size: 20,
                            color: isSelected ? AppColors.primaryLight : const Color(0xFF94A3B8)),
                        title: Text(item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            )),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          _onNavTap(i, navItems);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Logout
            const Divider(color: Color(0xFF1E293B), height: 1),
            ColoredBox(
              color: const Color(0xFF0F172A),
              child: SafeArea(
                top: false,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 20),
                  title: const Text('Logout', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
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

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  final String? group;
  /// If set, this nav item is only shown when the society plan includes this feature.
  /// null means always visible.
  final String? featureKey;
  const _NavItem({required this.icon, required this.label, required this.path, this.group, this.featureKey});
}
