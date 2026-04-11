import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/super_admin_dashboard.dart';
import '../../features/superadmin/screens/sa_dashboard_screen.dart';
import '../../features/members/screens/members_screen.dart';
import '../../features/bills/screens/bills_screen.dart';
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
import '../../features/settings/screens/settings_screen.dart';
import '../widgets/sa_shell.dart';
import '../widgets/sm_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
        GoRoute(path: '/sa/settings',      builder: (c, s) => SettingsScreen()),
        GoRoute(path: '/superadmin',       builder: (c, s) => SuperAdminDashboard()),
      ],
    ),

    // ── Pramukh / Secretary / Society routes (SMShell sidebar) ────
    ShellRoute(
      builder: (context, state, child) => SMShell(child: child),
      routes: [
        GoRoute(path: '/dashboard',     builder: (c, s) => DashboardScreen()),
        GoRoute(path: '/members',       builder: (c, s) => MembersScreen()),
        GoRoute(path: '/bills',         builder: (c, s) => BillsScreen()),
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
        GoRoute(path: '/settings',      builder: (c, s) => SettingsScreen()),
      ],
    ),
  ],
);
