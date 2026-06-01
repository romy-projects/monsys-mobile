import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
          // Laravel API wraps response in 'data' field
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
    try {
      final apiService = ref.read(apiServiceProvider);
      final authStorage = ref.read(authStorageProvider);

      await apiService.post(ApiConstants.logout);
      await authStorage.clearAll();

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      // Even if logout API fails, clear local data
      final authStorage = ref.read(authStorageProvider);
      await authStorage.clearAll();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _onItemTapped(int index) {
    // Navigate to the corresponding screen
    switch (index) {
      case 0:
        // Dashboard - stay on current screen
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
    final colorScheme = Theme.of(context).colorScheme;

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDashboardData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard, color: colorScheme.onSurfaceVariant),
            activeIcon: Icon(Icons.dashboard, color: colorScheme.onPrimary),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory, color: colorScheme.onSurfaceVariant),
            activeIcon: Icon(Icons.inventory, color: colorScheme.onPrimary),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping, color: colorScheme.onSurfaceVariant),
            activeIcon: Icon(Icons.local_shipping, color: colorScheme.onPrimary),
            label: 'Delivery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart, color: colorScheme.onSurfaceVariant),
            activeIcon: Icon(Icons.bar_chart, color: colorScheme.onPrimary),
            label: 'Reports',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        elevation: 8,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return const Center(child: Text('Stock Management'));
      case 2:
        return const Center(child: Text('Delivery Orders'));
      case 3:
        return const Center(child: Text('Reports'));
      default:
        return const Center(child: Text('Dashboard'));
    }
  }

  Widget _buildDashboardTab() {
    if (_dashboardData == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Here\'s what\'s happening with your business today.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Sales',
                  'Rp ${_dashboardData?['total_sales'] ?? '0'}',
                  Icons.shopping_cart,
                  Colors.green,
                ),
                _buildStatCard(
                  'Orders',
                  '${_dashboardData?['total_orders'] ?? '0'}',
                  Icons.receipt_long,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Stock Items',
                  '${_dashboardData?['stock_items'] ?? '0'}',
                  Icons.inventory_2,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Pending',
                  '${_dashboardData?['pending_orders'] ?? '0'}',
                  Icons.pending_actions,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}