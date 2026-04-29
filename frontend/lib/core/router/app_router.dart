import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../features/settings/providers/permissions_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/super_admin_dashboard.dart';
import '../../features/superadmin/screens/sa_dashboard_screen.dart';
import '../../features/superadmin/screens/sa_platform_settings_screen.dart';
import '../../features/superadmin/screens/sa_app_info_screen.dart';
import '../../features/members/screens/members_screen.dart';
import '../../features/bills/screens/bills_screen.dart';
import '../../features/bills/screens/bill_audit_logs_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/complaints/screens/complaints_screen.dart';
import '../../features/suggestions/screens/suggestions_screen.dart';
import '../../features/visitors/screens/visitors_screen.dart';
import '../../features/visitors/screens/pending_approvals_screen.dart';
import '../../features/notices/screens/notices_screen.dart';
import '../../features/amenities/screens/amenities_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/gatepasses/screens/gate_pass_screen.dart';
import '../../features/domestichelp/screens/domestic_help_screen.dart';
import '../../features/deliveries/screens/delivery_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';
import '../../features/parking/screens/parking_screen.dart';
import '../../features/plans/screens/plans_screen.dart';
import '../../features/societies/screens/societies_screen.dart';
import '../../features/units/screens/units_screen.dart';
import '../../features/subscriptions/screens/subscriptions_screen.dart';
import '../../features/subscriptions/screens/subscription_report_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/permissions_screen.dart';
import '../../features/donations/screens/donations_screen.dart';
import '../../features/donations/screens/donation_receipt_screen.dart';
import '../../features/reports/screens/balance_report_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/chat/screens/chat_member_list_screen.dart';
import '../../features/chat/models/chat_models.dart';
import '../../features/polls/screens/polls_screen.dart';
import '../../features/polls/screens/poll_detail_screen.dart';
import '../../features/events/screens/events_screen.dart';
import '../../features/rentals/screens/rentals_screen.dart';
import '../../features/rules/screens/rules_screen.dart';
import '../../features/assets/screens/assets_screen.dart';
import '../../features/reports/screens/dues_report_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/sos/screens/sos_alert_screen.dart';
import '../../features/wall/screens/wall_screen.dart';
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
        '/parking': 'parking_management',
        '/assets': 'asset_management',
      };

      // These sub-routes are resident actions (approve gate visitors, etc.) — not feature-gated
      const bypassRoutes = ['/visitors/pending-approvals'];
      if (bypassRoutes.contains(loc)) return null;

      for (final e in rules.entries) {
        if (_matches(loc, e.key) && !user.hasFeature(e.value)) {
          return '/dashboard';
        }
      }
    }

    // Role permission gating (Admin toggles) — hide & block screens not enabled for the user's role.
    if (user != null && user.role != 'SUPER_ADMIN') {
      final permsData = _ref.read(rolePermissionsProvider).valueOrNull;
      final roleKey = user.role.toUpperCase();
      final rolePerms = permsData?.rolePermissions[roleKey];

      // If not loaded yet, don't redirect (avoid loops). The sidebar itself is deny-by-default until loaded.
      if (rolePerms != null) {
        final loc = state.matchedLocation;

        // Sub-routes that are action/detail screens may be needed even when the list is hidden.
        // Keep existing exceptions + chat room/members.
        const bypassRoutes = [
          '/visitors/pending-approvals',
          '/chat/members',
        ];
        if (!bypassRoutes.contains(loc)) {
          final roleRules = <String, String>{
            '/dashboard': 'dashboard',
            '/units': 'units',
            '/members': 'members',
            '/bills': 'bills',
            '/expenses': 'expenses',
            '/donations': 'donations',
            '/reports/balance': 'balance_report',
            '/reports/dues': 'pending_dues',
            '/visitors': 'visitors',
            '/gatepasses': 'gate_passes',
            '/vehicles': 'vehicles',
            '/parking': 'parking',
            '/complaints': 'complaints',
            '/suggestions': 'suggestions',
            '/notices': 'notices',
            '/polls': 'polls',
            '/events': 'events',
            '/amenities': 'amenities',
            '/staff': 'staff',
            '/deliveries': 'deliveries',
            '/domestichelp': 'domestic_help',
            '/chat': 'chat',
            '/notifications': 'notifications',
          };

          for (final e in roleRules.entries) {
            if (_matches(loc, e.key) && rolePerms[e.value] != true) {
              return '/dashboard';
            }
          }
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
          GoRoute(path: '/sa/app-info',          builder: (c, s) => const SaAppInfoScreen()),
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
          GoRoute(path: '/suggestions',   builder: (c, s) => const SuggestionsScreen()),
          GoRoute(path: '/visitors',                 builder: (c, s) => VisitorsScreen()),
          GoRoute(path: '/visitors/pending-approvals', builder: (c, s) => const PendingApprovalsScreen()),
          GoRoute(path: '/notices',       builder: (c, s) => NoticesScreen()),
          GoRoute(path: '/amenities',     builder: (c, s) => AmenitiesScreen()),
          GoRoute(path: '/notifications', builder: (c, s) => NotificationsScreen()),
          GoRoute(path: '/staff',         builder: (c, s) => StaffScreen()),
          GoRoute(path: '/gatepasses',    builder: (c, s) => GatePassScreen()),
          GoRoute(path: '/domestichelp',  builder: (c, s) => DomesticHelpScreen()),
          GoRoute(path: '/deliveries',    builder: (c, s) => DeliveryScreen()),
          GoRoute(path: '/vehicles',      builder: (c, s) => VehiclesScreen()),
          GoRoute(path: '/parking',       builder: (c, s) => const ParkingScreen()),
          GoRoute(path: '/plans',         builder: (c, s) => PlansScreen()),
          GoRoute(path: '/societies',     builder: (c, s) => SocietiesScreen()),
          GoRoute(path: '/units',         builder: (c, s) => UnitsScreen()),
          GoRoute(path: '/rentals',       builder: (c, s) => const RentalsScreen()),
          GoRoute(path: '/subscriptions', builder: (c, s) => SubscriptionsScreen()),
          GoRoute(path: '/donations',        builder: (c, s) => DonationsScreen()),
          GoRoute(
            path: '/donations/receipt',
            builder: (c, s) => DonationReceiptScreen(
              donation: (s.extra as Map?)?.cast<String, dynamic>() ?? const {},
            ),
          ),
          GoRoute(path: '/reports/balance', builder: (c, s) => const BalanceReportScreen()),
          GoRoute(path: '/reports/dues',    builder: (c, s) => const DuesReportScreen()),
          GoRoute(path: '/settings',        builder: (c, s) => SettingsScreen()),
          GoRoute(path: '/settings/permissions', builder: (c, s) => const PermissionsScreen()),
          GoRoute(path: '/chat',            builder: (c, s) => const ChatListScreen()),
          GoRoute(path: '/polls',           builder: (c, s) => const PollsScreen()),
          GoRoute(
            path: '/polls/:pollId',
            builder: (c, s) {
              final pollId = s.pathParameters['pollId']!;
              final tab = s.uri.queryParameters['tab']?.toLowerCase();
              return PollDetailScreen(
                pollId: pollId,
                openResults: tab == 'results',
              );
            },
          ),
          GoRoute(path: '/events',          builder: (c, s) => const EventsScreen()),
          GoRoute(path: '/tasks',           builder: (c, s) => const TasksScreen()),
          GoRoute(path: '/rules',           builder: (c, s) => const RulesScreen()),
          GoRoute(path: '/assets',          builder: (c, s) => const AssetsScreen()),
          GoRoute(
            path: '/sos',
            builder: (c, s) => SosAlertScreen(
              unitId: s.uri.queryParameters['unitId'],
              unitCode: s.uri.queryParameters['unitCode'],
              actorName: s.uri.queryParameters['actorName'],
              actorRole: s.uri.queryParameters['actorRole'],
              message: s.uri.queryParameters['message'],
              notificationId: s.uri.queryParameters['notificationId'],
            ),
          ),
          GoRoute(path: '/wall',            builder: (c, s) => const WallScreen()),
          GoRoute(path: '/chat/members',    builder: (c, s) => const ChatMemberListScreen()),
          GoRoute(
            path: '/chat/room/:roomId',
            builder: (c, s) {
              final extra = s.extra as Map<String, dynamic>? ?? {};
              return ChatRoomScreen(
                roomId: s.pathParameters['roomId']!,
                title: extra['title'] as String? ?? 'Chat',
                roomType: extra['roomType'] as String? ?? 'GROUP',
                otherUser: extra['otherUser'] as ChatUser?,
              );
            },
          ),
        ],
      ),
    ],
  );
});
