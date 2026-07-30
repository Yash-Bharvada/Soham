import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/owner/owner_shell.dart';
import 'screens/owner/dashboard_screen.dart';
import 'screens/owner/tenants_screen.dart';
import 'screens/owner/verify_tenant_screen.dart';
import 'screens/owner/owner_profile_screen.dart';
import 'screens/tenant/tenant_shell.dart';
import 'screens/tenant/home_screen.dart';
import 'screens/tenant/payment_screen.dart';
import 'screens/tenant/documents_screen.dart';
import 'screens/tenant/tenant_profile_screen.dart';
import 'screens/profile/personal_details_screen.dart';
import 'screens/profile/notification_preferences_screen.dart';
import 'screens/profile/payment_methods_screen.dart';
import 'screens/profile/help_support_screen.dart';

// ── Auth state stream ────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ── Router notifier (re-evaluates redirect on auth change) ───────────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final path = state.uri.toString();
    final isAuthPath = path == '/login' || path == '/signup';

    if (!isLoggedIn && !isAuthPath) return '/login';
    if (isLoggedIn && isAuthPath) {
      final role =
          session.user.userMetadata?['role'] as String? ?? 'tenant';
      return role == 'owner' ? '/owner/dashboard' : '/tenant/home';
    }
    return null;
  }
}

// ── Router provider ──────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),

      // ── Owner shell ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => OwnerShell(child: child),
        routes: [
          GoRoute(
            path: '/owner/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/owner/tenants',
            builder: (_, __) => const TenantsScreen(),
          ),
          GoRoute(
            path: '/owner/tenants/:tenantId',
            builder: (_, state) => VerifyTenantScreen(
              tenantId: state.pathParameters['tenantId']!,
            ),
          ),
          GoRoute(
            path: '/owner/profile',
            builder: (_, __) => const OwnerProfileScreen(),
          ),
        ],
      ),

      // ── Tenant shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => TenantShell(child: child),
        routes: [
          GoRoute(
            path: '/tenant/home',
            builder: (_, __) => const TenantHomeScreen(),
          ),
          GoRoute(
            path: '/tenant/payment',
            builder: (_, __) => const PaymentScreen(),
          ),
          GoRoute(
            path: '/tenant/documents',
            builder: (_, __) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/tenant/profile',
            builder: (_, __) => const TenantProfileScreen(),
          ),
        ],
      ),

      // ── Profile sub-screens ──────────────────────────────────────────────
      GoRoute(
        path: '/profile/personal-details',
        builder: (_, __) => const PersonalDetailsScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (_, __) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/profile/payment-methods',
        builder: (_, __) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: '/profile/help-support',
        builder: (_, __) => const HelpSupportScreen(),
      ),
    ],
  );
});

// ── Root app ─────────────────────────────────────────────────────────────────
class SohamApp extends ConsumerWidget {
  const SohamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Soham',
      theme: AppTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
