import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/navigation/app_shell.dart';
import 'package:monsys_mobile/core/theme/app_theme.dart';
import 'package:monsys_mobile/features/account/presentation/screens/account_screen.dart';
import 'package:monsys_mobile/features/account/presentation/screens/change_password_screen.dart';
import 'package:monsys_mobile/features/account/presentation/screens/profile_screen.dart';
import 'package:monsys_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:monsys_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:monsys_mobile/features/finance/presentation/screens/finance_screen.dart';
import 'package:monsys_mobile/features/master_data/presentation/screens/master_data_screen.dart';
import 'package:monsys_mobile/features/orders/presentation/screens/orders_screen.dart';
import 'package:monsys_mobile/features/reports/presentation/screens/reports_screen.dart';
import 'package:monsys_mobile/features/stock/presentation/screens/cylinder_circulation_screen.dart';
import 'package:monsys_mobile/features/stock/presentation/screens/stock_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Router is created once per app lifetime (previously rebuilt inside
/// `build()`, which reset navigation on every provider change).
final routerProvider = Provider<GoRouter>((ref) {
  final authStorage = ref.read(authStorageProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Root-level (full-screen) routes pushed above the tab shell.
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => ChangePasswordScreen(
          forced: state.uri.queryParameters['forced'] == '1',
        ),
      ),
      GoRoute(
        path: '/finance',
        name: 'finance',
        builder: (context, state) => const FinanceScreen(),
      ),
      GoRoute(
        path: '/master-data',
        name: 'master-data',
        builder: (context, state) => const MasterDataScreen(),
      ),
      GoRoute(
        path: '/cylinder-circulations',
        name: 'cylinder-circulations',
        builder: (context, state) => const CylinderCirculationScreen(),
      ),
      // Persistent 5-tab marketplace shell.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                name: 'orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stock',
                name: 'stock',
                builder: (context, state) => const StockScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                name: 'account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) async {
      final token = await authStorage.getToken();
      final isLoggedIn = token != null;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }
      if (isLoggingIn) {
        return '/dashboard';
      }

      // Forced rotation: panelx allows the mobile token but the app must show
      // the change-password screen until must_change_password clears.
      final user =
          UserAccount.fromJsonString(await authStorage.getUser() ?? '');
      if (user.hasPendingPasswordRotation &&
          !location.startsWith('/change-password')) {
        return '/change-password?forced=1';
      }

      return null;
    },
  );
});

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Monitoring System',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
