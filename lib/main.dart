import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monsys_mobile/core/theme/app_theme.dart';
import 'package:monsys_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:monsys_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:monsys_mobile/features/stock/presentation/screens/stock_screen.dart';
import 'package:monsys_mobile/features/delivery_order/presentation/screens/delivery_order_screen.dart';
import 'package:monsys_mobile/features/reports/presentation/screens/reports_screen.dart';
import 'package:monsys_mobile/core/auth/auth_storage.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStorage = ref.watch(authStorageProvider);

    return MaterialApp.router(
      title: 'Monitoring System',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/stock',
            name: 'stock',
            builder: (context, state) => const StockScreen(),
          ),
          GoRoute(
            path: '/delivery-orders',
            name: 'delivery-orders',
            builder: (context, state) => const DeliveryOrderScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
        redirect: (context, state) async {
          // Check if user is authenticated
          final token = await authStorage.getToken();
          final isLoggedIn = token != null;
          
          final isLoggingIn = state.matchedLocation == '/login';
          
          if (!isLoggedIn && !isLoggingIn) {
            return '/login';
          }
          
          if (isLoggedIn && isLoggingIn) {
            return '/dashboard';
          }
          
          return null;
        },
      ),
    );
  }
}