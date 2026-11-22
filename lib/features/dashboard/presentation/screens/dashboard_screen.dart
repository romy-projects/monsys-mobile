import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/features/dashboard/domain/dashboard_summary.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/services/notification/notification_service.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Home tab — role-aware dashboard.
///
/// HQ roles (owner_pusat / super_admin / regional_leader) read
/// `/dashboard/main` (cross-branch KPIs, low-stock alerts, 14-day sales).
/// Branch roles read `/dashboard/branch` (branch KPIs, stock alerts, incoming
/// POs, 7-day sales). The previous build always called `/dashboard/main`,
/// which 403s for branch users.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardSummary? _summary;
  UserAccount _user = const UserAccount();
  bool _isLoading = true;
  int _requestId = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    // Register the FCM push token (covers app start while logged in).
    // Safe no-op until the Firebase config files are added (TASKLIST.md → M-11).
    ref.read(notificationServiceProvider).initializeAndRegister();
  }

  Future<void> _loadDashboard() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      final endpoint = user.isHqRole
          ? ApiConstants.dashboardMain
          : ApiConstants.dashboardBranch;
      final response = await ref.read(apiServiceProvider).get(endpoint);
      if (!mounted || requestId != _requestId) return;

      if (response.statusCode == 200) {
        final raw = response.data;
        final payload = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
        final summary = user.isHqRole
            ? DashboardSummary.fromMain(payload)
            : DashboardSummary.fromBranch(payload);
        setState(() {
          _user = user;
          _summary = summary;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load dashboard data';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted || requestId != _requestId) return;
      final data = e.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : null;
      setState(() {
        _errorMessage = message ?? 'Failed to load dashboard data';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _errorMessage = 'An error occurred while loading data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboard,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 360,
            child: AppErrorState(
              message: _errorMessage!,
              onRetry: _loadDashboard,
            ),
          ),
        ],
      );
    }

    final summary = _summary;
    if (summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 360, child: AppEmptyState(message: 'No data available')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildWelcomeCard(),
        const SizedBox(height: 16),
        _buildKpiGrid(summary),
        if (summary.hasLowStock) ...[
          const SizedBox(height: 20),
          _buildLowStockSection(summary),
        ],
        if (summary.salesChart.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSalesChart(summary),
        ],
        if (summary.isBranchScoped && summary.incomingOrders.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildIncomingOrders(summary),
        ],
        const SizedBox(height: 20),
        _buildQuickActions(),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildWelcomeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.05),
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
                          _user.name.isNotEmpty
                              ? 'Welcome, ${_user.name}!'
                              : 'Welcome back!',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Here's your business overview today.",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    tooltip: 'Account',
                    onPressed: () => context.go('/account'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(_user.roleLabel, Icons.verified_user_outlined,
                      colorScheme.primary),
                  _chip(_user.scopeLabel, Icons.location_on_outlined,
                      colorScheme.secondary),
                ],
              ),
              if (_user.hasPendingPasswordRotation) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push('/change-password?forced=1'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock,
                            size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Password change required — tap to update.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── KPIs ─────────────────────────────────────────────────────

  Widget _buildKpiGrid(DashboardSummary summary) {
    final cards = summary.isBranchScoped
        ? <Widget>[
            StatCard(
              title: "Today's Revenue",
              value: _formatCurrency(summary.todayRevenue),
              icon: Icons.today,
              color: Colors.green,
            ),
            StatCard(
              title: 'Month Revenue',
              value: _formatCurrency(summary.monthRevenue),
              icon: Icons.calendar_month,
              color: Colors.blue,
            ),
            StatCard(
              title: 'Month Profit',
              value: _formatCurrency(summary.monthProfit),
              icon: Icons.trending_up,
              color: summary.monthProfit < 0 ? Colors.red : Colors.teal,
              trend: 'Costs ${_formatCurrency(summary.monthCosts)}',
              isPositive: summary.monthProfit >= 0,
            ),
            StatCard(
              title: 'Incoming POs',
              value: '${summary.incomingOrderCount}',
              icon: Icons.local_shipping,
              color: Colors.orange,
            ),
          ]
        : <Widget>[
            StatCard(
              title: "Today's Revenue",
              value: _formatCurrency(summary.todayRevenue),
              icon: Icons.today,
              color: Colors.green,
            ),
            StatCard(
              title: 'Month Revenue',
              value: _formatCurrency(summary.monthRevenue),
              icon: Icons.calendar_month,
              color: Colors.blue,
            ),
            StatCard(
              title: 'Pending Approval',
              value: '${summary.pendingOrderCount}',
              icon: Icons.pending_actions,
              color: Colors.orange,
              trend: summary.pendingOrderCount > 0 ? 'Needs attention' : null,
              isPositive: summary.pendingOrderCount == 0,
            ),
            StatCard(
              title: 'Active Shipments',
              value: '${summary.activeShipmentCount}',
              icon: Icons.local_shipping,
              color: Colors.indigo,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: cards,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: summary.isBranchScoped
              ? [
                  _chip('${summary.lowStockItems.length} stock alerts',
                      Icons.warning_amber_rounded, Colors.orange),
                ]
              : [
                  _chip('${summary.branchCount} active branches',
                      Icons.storefront, Colors.blue),
                  _chip('${summary.lowStockCount} low stock',
                      Icons.warning_amber_rounded, Colors.orange),
                ],
        ),
      ],
    );
  }

  // ── Low stock ────────────────────────────────────────────────

  Widget _buildLowStockSection(DashboardSummary summary) {
    final theme = Theme.of(context);
    final rows = summary.isBranchScoped
        ? summary.lowStockItems
            .map((row) => _LowStockRow(
                  title: '${row.cylinderType} cylinders',
                  subtitle: '${row.qtyFull} full · ${row.qtyEmpty} empty',
                  level: row.alertLevel,
                ))
            .toList()
        : summary.lowStockAlerts
            .map((alert) => _LowStockRow(
                  title: '${alert.cylinderType} · ${alert.branchName}',
                  subtitle: '${alert.qtyFull} full cylinders left',
                  level: StockAlertLevel.danger,
                ))
            .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Low stock alerts',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/stock'),
                  child: const Text('View stock'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final row in rows.take(4)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: row.level == StockAlertLevel.danger
                            ? Colors.red
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(row.title)),
                    Text(
                      row.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (rows.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${rows.length - 4} more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 14/7-day sales strip ─────────────────────────────────────

  Widget _buildSalesChart(DashboardSummary summary) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = summary.salesChartMax;
    const chartHeight = 64.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sales · last ${summary.chartDays} days',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _formatCurrency(summary.salesChartTotal),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: chartHeight + 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in summary.salesChart)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${point.date == null ? '' : DateFormat('dd MMM').format(point.date!)}'
                            ' · ${_formatCurrency(point.revenue)} · ${point.qty} qty',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: max <= 0
                                    ? 3
                                    : (point.revenue / max) * chartHeight,
                                decoration: BoxDecoration(
                                  color: point.revenue > 0
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                point.date == null
                                    ? ''
                                    : DateFormat('d').format(point.date!),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (max <= 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No sales recorded in this period.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Incoming POs (branch) ────────────────────────────────────

  Widget _buildIncomingOrders(DashboardSummary summary) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Incoming Purchase Orders',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/orders'),
                  child: const Text('View all'),
                ),
              ],
            ),
            for (final order in summary.incomingOrders.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 18, color: Colors.indigo),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.number,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${order.cylinderType} · ${order.quantity} qty'
                            '${order.expedition != null ? ' · ${order.expedition}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: order.status),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────────────

  Widget _buildQuickActions() {
    final actions = <Widget>[
      _actionCard(Icons.receipt_long, 'Orders', Colors.purple,
          () => context.go('/orders')),
      _actionCard(Icons.inventory, 'Stock', Colors.blue,
          () => context.go('/stock')),
      _actionCard(Icons.bar_chart, 'Reports', Colors.teal,
          () => context.go('/reports')),
      if (_user.canViewFinance)
        _actionCard(Icons.receipt, 'Finance', Colors.green,
            () => context.push('/finance')),
      if (_user.canManageUsers)
        _actionCard(Icons.dataset, 'Master Data', Colors.indigo,
            () => context.push('/master-data')),
      _actionCard(Icons.swap_horiz, 'Sirkulasi', Colors.deepOrange,
          () => context.push('/cylinder-circulations')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: actions,
        ),
      ],
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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

  // ── Loading & formatting ─────────────────────────────────────

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerLoading(
            width: double.infinity, height: 120, borderRadius: 16),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: List.generate(
            4,
            (index) => const ShimmerLoading(
              width: double.infinity,
              height: 120,
              borderRadius: 16,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const ShimmerLoading(
            width: double.infinity, height: 160, borderRadius: 16),
      ],
    );
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }
}

class _LowStockRow {
  const _LowStockRow({
    required this.title,
    required this.subtitle,
    required this.level,
  });

  final String title;
  final String subtitle;
  final StockAlertLevel level;
}
