import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class SMShell extends ConsumerStatefulWidget {
  final Widget child;
  const SMShell({super.key, required this.child});

  @override
  ConsumerState<SMShell> createState() => _SMShellState();
}

class _SMShellState extends ConsumerState<SMShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Full nav for Pramukh / Secretary
  static const _allNavItems = [
    _NavItem(icon: Icons.dashboard_rounded,              label: 'Dashboard',     path: '/dashboard',     group: 'Main'),
    _NavItem(icon: Icons.apartment_rounded,              label: 'Units',         path: '/units',         group: 'Main'),
    _NavItem(icon: Icons.people_rounded,                 label: 'Members',       path: '/members',       group: 'Main'),
    _NavItem(icon: Icons.receipt_long_rounded,           label: 'Bills',         path: '/bills',         group: 'Finance'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Expenses',      path: '/expenses',      group: 'Finance'),
    _NavItem(icon: Icons.person_pin_circle_rounded,      label: 'Visitors',      path: '/visitors',      group: 'Security'),
    _NavItem(icon: Icons.badge_rounded,                  label: 'Gate Passes',   path: '/gatepasses',    group: 'Security'),
    _NavItem(icon: Icons.directions_car_rounded,         label: 'Vehicles',      path: '/vehicles',      group: 'Security'),
    _NavItem(icon: Icons.report_problem_rounded,         label: 'Complaints',    path: '/complaints',    group: 'Society'),
    _NavItem(icon: Icons.campaign_rounded,               label: 'Notices',       path: '/notices',       group: 'Society'),
    _NavItem(icon: Icons.sports_basketball_rounded,      label: 'Amenities',     path: '/amenities',     group: 'Society'),
    _NavItem(icon: Icons.support_agent_rounded,          label: 'Staff',         path: '/staff',         group: 'Society'),
    _NavItem(icon: Icons.local_shipping_rounded,         label: 'Deliveries',    path: '/deliveries',    group: 'Society'),
    _NavItem(icon: Icons.cleaning_services_rounded,      label: 'Domestic Help', path: '/domestichelp',  group: 'Society'),
    _NavItem(icon: Icons.notifications_rounded,          label: 'Notifications', path: '/notifications', group: 'More'),
    _NavItem(icon: Icons.settings_rounded,               label: 'Settings',      path: '/settings',      group: 'More'),
  ];

  // Bottom nav shows the most-used 5 items on mobile
  static const _mobileBottomItems = [
    _NavItem(icon: Icons.dashboard_rounded,    label: 'Home',      path: '/dashboard'),
    _NavItem(icon: Icons.people_rounded,       label: 'Members',   path: '/members'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Bills',     path: '/bills'),
    _NavItem(icon: Icons.report_problem_rounded, label: 'Issues',  path: '/complaints'),
    _NavItem(icon: Icons.menu_rounded,         label: 'More',      path: '__menu__'),
  ];

  void _onNavTap(int index) {
    final path = _allNavItems[index].path;
    setState(() => _selectedIndex = index);
    context.go(path);
  }

  void _onMobileBottomTap(int index) {
    final item = _mobileBottomItems[index];
    if (item.path == '__menu__') {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    final mainIndex = _allNavItems.indexWhere((n) => n.path == item.path);
    if (mainIndex >= 0) setState(() => _selectedIndex = mainIndex);
    context.go(item.path);
  }

  int get _mobileBottomIndex {
    final currentPath = _allNavItems[_selectedIndex].path;
    final idx = _mobileBottomItems.indexWhere((i) => i.path == currentPath);
    return idx >= 0 ? idx : 4; // fallback to "More"
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _allNavItems.length; i++) {
      if (location == _allNavItems[i].path ||
          (location.startsWith(_allNavItems[i].path) && _allNavItems[i].path != '/')) {
        if (_selectedIndex != i) setState(() => _selectedIndex = i);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide ? null : _buildDrawer(authState),
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
              title: Text(
                _allNavItems[_selectedIndex].label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          if (isWide) _buildSidebar(authState),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _mobileBottomIndex,
              onDestinationSelected: _onMobileBottomTap,
              height: 64,
              destinations: _mobileBottomItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }

  // ── Desktop sidebar ──────────────────────────────────────────────

  Widget _buildSidebar(AuthState authState) {
    final groups = <String, List<int>>{};
    for (int i = 0; i < _allNavItems.length; i++) {
      groups.putIfAbsent(_allNavItems[i].group ?? '', () => []).add(i);
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
                      ...entry.value.map((i) => _sidebarItem(i)),
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

  Widget _sidebarItem(int i) {
    final item = _allNavItems[i];
    final isSelected = _selectedIndex == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onNavTap(i),
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

  Widget _buildDrawer(AuthState authState) {
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
            const Divider(color: Color(0xFF1E293B), height: 1),

            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _allNavItems.length,
                itemBuilder: (ctx, i) {
                  final item = _allNavItems[i];
                  final isSelected = _selectedIndex == i;

                  // Group header
                  final showGroupHeader = i == 0 ||
                      _allNavItems[i].group != _allNavItems[i - 1].group;

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
                          _onNavTap(i);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Logout
            const Divider(color: Color(0xFF1E293B), height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 20),
              title: const Text('Logout', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (mounted) context.go('/');
              },
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
  const _NavItem({required this.icon, required this.label, required this.path, this.group});
}
