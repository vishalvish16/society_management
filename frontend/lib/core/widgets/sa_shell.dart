import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../../shared/widgets/confirm_logout.dart';

class SAShell extends ConsumerStatefulWidget {
  final Widget child;
  const SAShell({super.key, required this.child});

  @override
  ConsumerState<SAShell> createState() => _SAShellState();
}

class _SAShellState extends ConsumerState<SAShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded,       label: 'Dashboard',     path: '/sa/dashboard'),
    _NavItem(icon: Icons.apartment_rounded,       label: 'Societies',     path: '/sa/societies'),
    _NavItem(icon: Icons.card_membership_rounded, label: 'Plans',         path: '/sa/plans'),
    _NavItem(icon: Icons.subscriptions_rounded,   label: 'Subscriptions', path: '/sa/subscriptions'),
    _NavItem(icon: Icons.description_outlined,    label: 'Estimates',     path: '/sa/estimates'),
    _NavItem(icon: Icons.settings_rounded,        label: 'Settings',      path: '/sa/settings'),
    _NavItem(icon: Icons.tune_rounded,            label: 'Platform',      path: '/sa/platform-settings'),
    _NavItem(icon: Icons.info_outline_rounded,    label: 'App Info',      path: '/sa/app-info'),
  ];

  // Bottom nav: 4 primary + More
  static const _bottomItems = [
    _NavItem(icon: Icons.dashboard_rounded,    label: 'Dashboard',  path: '/sa/dashboard'),
    _NavItem(icon: Icons.apartment_rounded,    label: 'Societies',  path: '/sa/societies'),
    _NavItem(icon: Icons.subscriptions_rounded,label: 'Subs',       path: '/sa/subscriptions'),
    _NavItem(icon: Icons.card_membership_rounded, label: 'Plans',   path: '/sa/plans'),
    _NavItem(icon: Icons.menu_rounded,         label: 'More',       path: '__menu__'),
  ];

  static const _subPageTitles = {
    '/sa/subscriptions/report': 'Subscription Report',
  };

  String _shellTitle(String location) {
    for (final e in _subPageTitles.entries) {
      if (location.startsWith(e.key)) return e.value;
    }
    for (final item in _navItems) {
      if (location.startsWith(item.path)) return item.label;
    }
    return 'Super Admin';
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    context.go(_navItems[index].path);
  }

  void _onBottomTap(BuildContext ctx, int index) {
    final item = _bottomItems[index];
    if (item.path == '__menu__') {
      Scaffold.of(ctx).openDrawer();
      return;
    }
    final mainIndex = _navItems.indexWhere((n) => n.path == item.path);
    if (mainIndex >= 0) setState(() => _selectedIndex = mainIndex);
    context.go(item.path);
  }

  int _bottomBarIndex(String location) {
    for (int i = 0; i < _bottomItems.length - 1; i++) {
      if (location.startsWith(_bottomItems[i].path)) return i;
    }
    // Check if current location is any nav item not in bottom bar → highlight More
    for (final item in _navItems) {
      if (location.startsWith(item.path)) {
        final inBottom = _bottomItems.any((b) => b.path == item.path);
        if (!inBottom) return _bottomItems.length - 1;
      }
    }
    return _bottomItems.length - 1;
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
    final location = GoRouterState.of(context).uri.toString();

    // Detect sub-page for back button
    final moduleItem = _navItems.firstWhere(
      (n) => location.startsWith(n.path),
      orElse: () => _navItems.first,
    );
    final isSubPage = location != moduleItem.path &&
        location.startsWith(moduleItem.path) &&
        moduleItem.path != '/sa/dashboard';

    return Scaffold(
      drawer: isWide ? null : _buildDrawer(authState),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(isSubPage ? Icons.arrow_back_rounded : Icons.menu_rounded),
                  onPressed: () {
                    if (isSubPage) {
                      context.go(moduleItem.path);
                      return;
                    }
                    Scaffold.of(ctx).openDrawer();
                  },
                ),
              ),
              title: Text(
                _shellTitle(location),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              actions: [
                IconButton(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    backgroundImage: () {
                      final url = AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl);
                      if (url == null) return null;
                      return NetworkImage('$url?v=${authState.avatarRevision}');
                    }(),
                    child: AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl) == null
                        ? Text(
                            (authState.user?.name ?? 'SA').substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  onPressed: () {},
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
          : Builder(
              builder: (ctx) => NavigationBar(
                selectedIndex: _bottomBarIndex(location),
                onDestinationSelected: (i) => _onBottomTap(ctx, i),
                height: 64,
                destinations: _bottomItems
                    .map((item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ))
                    .toList(),
              ),
            ),
    );
  }

  Widget _buildDrawer(AuthState authState) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.apartment_rounded, color: cs.onPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Society Manager',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                        Text('Super Admin Portal',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),

            // Nav items grouped
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                children: [
                  _drawerGroupHeader('Main'),
                  ..._navItems.take(4).map((item) =>
                      _drawerItem(_navItems.indexOf(item), item)),
                  const SizedBox(height: 8),
                  _drawerGroupHeader('Manage'),
                  ..._navItems.skip(4).map((item) =>
                      _drawerItem(_navItems.indexOf(item), item)),
                ],
              ),
            ),

            // Footer
            Divider(color: theme.dividerColor, height: 1),
            _DrawerUserTile(authState: authState, onLogout: () async {
              Navigator.pop(context);
              final confirm = await showLogoutConfirmSheet(context);
              if (!confirm) return;
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/');
            }),
          ],
        ),
      ),
    );
  }

  Widget _drawerGroupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            letterSpacing: 0.6,
          )),
    );
  }

  Widget _drawerItem(int navIdx, _NavItem item) {
    final isSelected = _selectedIndex == navIdx;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.pop(context);
            _onNavTap(navIdx);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.75),
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
    );
  }

  Widget _buildSidebar(AuthState authState) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final groups = {
      'Main': _navItems.take(4).toList(),
      'Manage': _navItems.skip(4).toList(),
    };

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
                  width: 38,
                  height: 38,
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
                      Text('Super Admin',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final item in entry.value)
                    _SidebarItem(
                      item: item,
                      isSelected: _selectedIndex == _navItems.indexOf(item),
                      onTap: () => _onNavTap(_navItems.indexOf(item)),
                    ),
                ],
              ],
            ),
          ),

          // User footer
          Divider(color: theme.dividerColor, height: 1),
          _SidebarUserTile(authState: authState, onLogout: () async {
            final confirm = await showLogoutConfirmSheet(context);
            if (!confirm) return;
            await ref.read(authProvider.notifier).logout();
            if (mounted) context.go('/');
          }),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  const _SidebarItem({required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: isSelected ? AppColors.primary : cs.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarUserTile extends StatelessWidget {
  final AuthState authState;
  final VoidCallback onLogout;
  const _SidebarUserTile({required this.authState, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primary,
            backgroundImage: () {
              final url = AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl);
              if (url == null) return null;
              return NetworkImage('$url?v=${authState.avatarRevision}');
            }(),
            child: AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl) == null
                ? Text(
                    (authState.user?.name ?? 'SA').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authState.user?.name ?? 'Super Admin',
                    style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(authState.user?.phone ?? '',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: cs.onSurface.withValues(alpha: 0.5), size: 18),
            onPressed: onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

class _DrawerUserTile extends StatelessWidget {
  final AuthState authState;
  final VoidCallback onLogout;
  const _DrawerUserTile({required this.authState, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: AppColors.primary,
        backgroundImage: () {
          final url = AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl);
          if (url == null) return null;
          return NetworkImage('$url?v=${authState.avatarRevision}');
        }(),
        child: AppConstants.uploadUrlFromPath(authState.user?.profilePhotoUrl) == null
            ? Text(
                (authState.user?.name ?? 'SA').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              )
            : null,
      ),
      title: Text(authState.user?.name ?? 'Super Admin',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
          overflow: TextOverflow.ellipsis),
      subtitle: Text('Super Admin',
          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
      trailing: IconButton(
        icon: Icon(Icons.logout_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
        onPressed: onLogout,
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
