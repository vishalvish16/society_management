import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class SAShell extends ConsumerStatefulWidget {
  final Widget child;
  const SAShell({super.key, required this.child});

  @override
  ConsumerState<SAShell> createState() => _SAShellState();
}

class _SAShellState extends ConsumerState<SAShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/sa/dashboard'),
    _NavItem(icon: Icons.apartment_rounded, label: 'Societies', path: '/sa/societies'),
    _NavItem(icon: Icons.card_membership_rounded, label: 'Plans', path: '/sa/plans'),
    _NavItem(icon: Icons.subscriptions_rounded, label: 'Subscriptions', path: '/sa/subscriptions'),
    _NavItem(icon: Icons.settings_rounded,       label: 'Settings',      path: '/sa/settings'),
    _NavItem(icon: Icons.tune_rounded,           label: 'Platform',      path: '/sa/platform-settings'),
  ];

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    context.go(_navItems[index].path);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path)) {
        if (_selectedIndex != i) setState(() => _selectedIndex = i);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide ? null : _buildDrawer(authState),
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
                _navItems[_selectedIndex].label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/');
                  },
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
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onNavTap,
              destinations: _navItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildDrawer(AuthState authState) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Society Manager',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Super Admin Portal',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  final item = _navItems[i];
                  final isSelected = _selectedIndex == i;
                  return ListTile(
                    leading: Icon(item.icon,
                        color: isSelected ? AppColors.primaryLight : const Color(0xFF94A3B8)),
                    title: Text(item.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      Navigator.pop(context);
                      _onNavTap(i);
                    },
                  );
                },
              ),
            ),

            // Footer / Logout
            const Divider(color: Color(0xFF1E293B), height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8)),
              title: const Text('Logout', style: TextStyle(color: Color(0xFF94A3B8))),
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

  Widget _buildSidebar(AuthState authState) {
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Society Manager',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Super Admin',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 8),

          // Nav items
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final isSelected = _selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Material(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _onNavTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(item.icon,
                            size: 20,
                            color: isSelected ? AppColors.primaryLight : const Color(0xFF94A3B8)),
                        const SizedBox(width: 12),
                        Text(item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // User info + logout
          const Divider(color: Color(0xFF1E293B), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (authState.user?.name ?? 'SA').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authState.user?.name ?? 'Super Admin',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(authState.user?.phone ?? '',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) context.go('/');
                  },
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}
