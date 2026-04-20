import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/super_admin_dashboard.dart';
import '../../features/superadmin/screens/sa_dashboard_screen.dart';
import '../../features/superadmin/screens/sa_platform_settings_screen.dart';
import '../../features/members/screens/members_screen.dart';
import '../../features/bills/screens/bills_screen.dart';
import '../../features/bills/screens/bill_audit_logs_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/complaints/screens/complaints_screen.dart';
import '../../features/visitors/screens/visitors_screen.dart';
import '../../features/notices/screens/notices_screen.dart';
import '../../features/amenities/screens/amenities_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/gatepasses/screens/gate_pass_screen.dart';
import '../../features/domestichelp/screens/domestic_help_screen.dart';
import '../../features/deliveries/screens/delivery_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';
import '../../features/plans/screens/plans_screen.dart';
import '../../features/societies/screens/societies_screen.dart';
import '../../features/units/screens/units_screen.dart';
import '../../features/subscriptions/screens/subscriptions_screen.dart';
import '../../features/subscriptions/screens/subscription_report_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/donations/screens/donations_screen.dart';
import '../../features/reports/screens/balance_report_screen.dart';
import '../widgets/sa_shell.dart';
import '../widgets/sm_shell.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) => notifyListeners());
  }

  bool _matches(String location, String pathPrefix) {
    if (location == pathPrefix) return true;
    if (pathPrefix == '/') return location == '/';
    return location.startsWith('$pathPrefix/');
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    if (authState.isLoading) return null;

    final isAuth = authState.isAuthenticated;
    final isLoggingIn = state.matchedLocation == '/' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/forgot';

    if (!isAuth) return isLoggingIn ? null : '/';

    if (isLoggingIn) {
      if (authState.user?.role == 'SUPER_ADMIN') return '/sa/dashboard';
      return '/dashboard';
    }

    // Plan feature gating (UI guard) — backend is the source of truth.
    // If a feature is not in the plan, also block navigation to that screen.
    final user = authState.user;
    if (user != null && user.role != 'SUPER_ADMIN') {
      final loc = state.matchedLocation;
      final rules = <String, String>{
        '/expenses': 'expenses',
        '/donations': 'donations',
        '/reports/balance': 'financial_reports',
        '/visitors': 'visitors',
        '/gatepasses': 'gate_passes',
        '/amenities': 'amenities',
        '/deliveries': 'delivery_tracking',
        '/domestichelp': 'domestic_help',
      };

      for (final e in rules.entries) {
        if (_matches(loc, e.key) && !user.hasFeature(e.value)) {
          return '/dashboard';
        }
      }
    }

    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Public routes ─────────────────────────────────────────────
      GoRoute(path: '/',         builder: (c, s) => LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => RegisterScreen()),
      GoRoute(path: '/forgot',   builder: (c, s) => ForgotPasswordScreen()),

      // ── Super Admin routes (SAShell sidebar) ──────────────────────
      ShellRoute(
        builder: (context, state, child) => SAShell(child: child),
        routes: [
          GoRoute(path: '/sa-dashboard',     builder: (c, s) => SADashboardScreen()),
          GoRoute(path: '/sa/dashboard',     builder: (c, s) => SADashboardScreen()),
          GoRoute(path: '/sa/societies',     builder: (c, s) => SocietiesScreen()),
          GoRoute(path: '/sa/plans',         builder: (c, s) => PlansScreen()),
          GoRoute(path: '/sa/subscriptions', builder: (c, s) => SubscriptionsScreen()),
          GoRoute(path: '/sa/subscriptions/report', builder: (c, s) => SubscriptionReportScreen()),
          GoRoute(path: '/sa/settings',          builder: (c, s) => SettingsScreen()),
          GoRoute(path: '/sa/platform-settings', builder: (c, s) => const SaPlatformSettingsScreen()),
          GoRoute(path: '/superadmin',           builder: (c, s) => SuperAdminDashboard()),
        ],
      ),

      // ── Chairman / Secretary / Society routes (SMShell sidebar) ────
      ShellRoute(
        builder: (context, state, child) => SMShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',     builder: (c, s) => DashboardScreen()),
          GoRoute(path: '/members',       builder: (c, s) => MembersScreen()),
          GoRoute(path: '/bills',         builder: (c, s) => BillsScreen()),
          GoRoute(
            path: '/bills/audit-logs',
            builder: (c, s) => BillAuditLogsScreen(
              initialBillId: s.uri.queryParameters['billId'],
            ),
          ),
          GoRoute(path: '/expenses',      builder: (c, s) => ExpensesScreen()),
          GoRoute(path: '/complaints',    builder: (c, s) => ComplaintsScreen()),
          GoRoute(path: '/visitors',      builder: (c, s) => VisitorsScreen()),
          GoRoute(path: '/notices',       builder: (c, s) => NoticesScreen()),
          GoRoute(path: '/amenities',     builder: (c, s) => AmenitiesScreen()),
          GoRoute(path: '/notifications', builder: (c, s) => NotificationsScreen()),
          GoRoute(path: '/staff',         builder: (c, s) => StaffScreen()),
          GoRoute(path: '/gatepasses',    builder: (c, s) => GatePassScreen()),
          GoRoute(path: '/domestichelp',  builder: (c, s) => DomesticHelpScreen()),
          GoRoute(path: '/deliveries',    builder: (c, s) => DeliveryScreen()),
          GoRoute(path: '/vehicles',      builder: (c, s) => VehiclesScreen()),
          GoRoute(path: '/plans',         builder: (c, s) => PlansScreen()),
          GoRoute(path: '/societies',     builder: (c, s) => SocietiesScreen()),
          GoRoute(path: '/units',         builder: (c, s) => UnitsScreen()),
          GoRoute(path: '/subscriptions', builder: (c, s) => SubscriptionsScreen()),
          GoRoute(path: '/donations',        builder: (c, s) => DonationsScreen()),
          GoRoute(path: '/reports/balance', builder: (c, s) => const BalanceReportScreen()),
          GoRoute(path: '/settings',        builder: (c, s) => SettingsScreen()),
        ],
      ),
    ],
  );
});
