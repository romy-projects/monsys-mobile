import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDashboardData();
  }

  Future<void> _loadUserName() async {
    final authStorage = ref.read(authStorageProvider);
    final userJson = await authStorage.getUser();
    if (userJson != null) {
      try {
        final user = jsonDecode(userJson);
        setState(() {
          _userName = user['name'] ?? user['email'] ?? '';
        });
      } catch (_) {}
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(ApiConstants.dashboardMain);

      if (response.statusCode == 200) {
        setState(() {
          final responseData = response.data;
          _dashboardData = responseData['data'] ?? responseData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load dashboard data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while loading data';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final authStorage = ref.read(authStorageProvider);

        await apiService.post(ApiConstants.logout);
        await authStorage.clearAll();

        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        final authStorage = ref.read(authStorageProvider);
        await authStorage.clearAll();
        if (mounted) {
          context.go('/login');
        }
      }
    }
  }

  void _onItemTapped(int index) {
    // Navigate to the corresponding screen
    switch (index) {
      case 0:
        setState(() {
          _selectedIndex = 0;
        });
        break;
      case 1:
        context.push('/stock');
        break;
      case 2:
        context.push('/delivery-orders');
        break;
      case 3:
        context.push('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_outlined),
            activeIcon: Icon(Icons.inventory),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Delivery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadDashboardData,
      );
    }

    if (_dashboardData == null) {
      return const AppEmptyState(message: 'No data available');
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card with personalized greeting
            _buildWelcomeCard(),
            const SizedBox(height: 20),

            // Stats grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                StatCard(
                  title: 'Total Sales',
                  value: 'Rp ${_formatNumber(_dashboardData?['total_sales'])}',
                  icon: Icons.shopping_cart,
                  color: Colors.green,
                  trend: '+12% vs last month',
                  isPositive: true,
                ),
                StatCard(
                  title: 'Orders',
                  value: '${_dashboardData?['total_orders'] ?? '0'}',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                  trend: '+5% vs last month',
                  isPositive: true,
                ),
                StatCard(
                  title: 'Stock Items',
                  value: '${_dashboardData?['stock_items'] ?? '0'}',
                  icon: Icons.inventory_2,
                  color: Colors.orange,
                ),
                StatCard(
                  title: 'Pending',
                  value: '${_dashboardData?['pending_orders'] ?? '0'}',
                  icon: Icons.pending_actions,
                  color: Colors.red,
                  trend: _dashboardData?['pending_orders'] != null && _dashboardData!['pending_orders'] > 0
                      ? 'Needs attention'
                      : null,
                  isPositive: (_dashboardData?['pending_orders'] ?? 0) == 0,
                ),
              ],
            ),

            const SizedBox(height: 24),
            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.inventory,
                    label: 'Stock',
                    color: Colors.blue,
                    onTap: () => context.push('/stock'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.local_shipping,
                    label: 'Delivery',
                    color: Colors.purple,
                    onTap: () => context.push('/delivery-orders'),
                  ),
                ),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.bar_chart,
                    label: 'Reports',
                    color: Colors.teal,
                    onTap: () => context.push('/reports'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading(width: double.infinity, height: 80, borderRadius: 16),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: List.generate(4, (index) => const ShimmerLoading(
              width: double.infinity,
              height: 120,
              borderRadius: 16,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.08),
              colorScheme.secondary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty
                              ? 'Welcome, $_userName!'
                              : 'Welcome back!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Here\'s your business overview today.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = num.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }
}