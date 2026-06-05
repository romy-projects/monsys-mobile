import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedReport = 0;
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _reportTypes = [
    {'name': 'Profit & Loss', 'endpoint': ApiConstants.reportsProfitLoss, 'icon': Icons.show_chart},
    {'name': 'Stock Summary', 'endpoint': ApiConstants.reportsStockSummary, 'icon': Icons.inventory},
    {'name': 'Shipment Tracking', 'endpoint': ApiConstants.reportsShipmentTracking, 'icon': Icons.local_shipping},
    {'name': 'Sales Period', 'endpoint': ApiConstants.reportsSalesPeriod, 'icon': Icons.date_range},
    {'name': 'Branch Ranking', 'endpoint': ApiConstants.reportsBranchRanking, 'icon': Icons.leaderboard},
    {'name': 'Stock Audit', 'endpoint': ApiConstants.reportsStockAudit, 'icon': Icons.assignment},
    {'name': 'HPP Report', 'endpoint': ApiConstants.reportsHpp, 'icon': Icons.calculate},
    {'name': 'Receivables Aging', 'endpoint': ApiConstants.reportsReceivablesAging, 'icon': Icons.account_balance},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (_reportData != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadReport,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // Report selector - mobile friendly
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_reportTypes.length, (index) {
                  final report = _reportTypes[index];
                  final isSelected = index == _selectedReport;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      avatar: Icon(
                        report['icon'] as IconData,
                        size: 16,
                      ),
                      label: Text(report['name'] as String),
                      onSelected: (selected) {
                        setState(() {
                          _selectedReport = index;
                          _reportData = null;
                          _errorMessage = null;
                        });
                        _loadReport();
                      },
                      showCheckmark: false,
                      selectedColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Report content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadReport,
      );
    }

    if (_reportData == null) {
      return AppEmptyState(
        icon: _reportTypes[_selectedReport]['icon'],
        message: 'Select a report to view',
        subtitle: _reportTypes[_selectedReport]['name'],
      );
    }

    return _buildReportContent();
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading(width: 200, height: 24, borderRadius: 4),
          const SizedBox(height: 24),
          ...List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const ShimmerLoading(width: 40, height: 40, borderRadius: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerLoading(width: 120, height: 14, borderRadius: 4),
                          const SizedBox(height: 8),
                          const ShimmerLoading(width: 80, height: 20, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final endpoint = _reportTypes[_selectedReport]['endpoint'];
      final response = await apiService.get(endpoint);

      if (response.statusCode == 200) {
        final responseData = response.data;
        setState(() {
          _reportData = responseData['data'] ?? responseData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load report';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load report data';
        _isLoading = false;
      });
    }
  }

  Widget _buildReportContent() {
    switch (_selectedReport) {
      case 0:
        return _buildProfitLossReport();
      case 1:
        return _buildStockSummaryReport();
      case 2:
        return _buildShipmentTracking();
      case 3:
        return _buildSalesPeriod();
      case 4:
        return _buildBranchRanking();
      case 5:
        return _buildStockAudit();
      case 6:
        return _buildHppReport();
      case 7:
        return _buildReceivablesAging();
      default:
        return _buildGenericReport();
    }
  }

  Widget _buildSummaryCard(String title, String value, Color color, {IconData? icon}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon ?? Icons.analytics, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLossReport() {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profit & Loss Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 24),
            _buildSummaryCard('Total Revenue', 'Rp ${_formatNumber(_reportData?['total_revenue'])}', Colors.green, icon: Icons.trending_up),
            _buildSummaryCard('Total Expenses', 'Rp ${_formatNumber(_reportData?['total_expenses'])}', Colors.red, icon: Icons.trending_down),
            _buildSummaryCard('Net Profit', 'Rp ${_formatNumber(_reportData?['net_profit'])}', Colors.blue, icon: Icons.account_balance_wallet),
            if (_reportData?['details'] is List) ...[
              const SizedBox(height: 24),
              Text('Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 12),
              ...(_reportData!['details'] as List).map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item['description'] ?? ''),
                  trailing: Text('Rp ${_formatNumber(item['amount'])}'),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockSummaryReport() {
    final items = _reportData?['items'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock Summary Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            if (_reportData?['total_items'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Total Items: ${_reportData!['total_items']}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (items != null && items.isNotEmpty)
              ...items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2, color: Colors.blue),
                  ),
                  title: Text(item['cylinder_type'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Branch: ${item['branch']?['name'] ?? 'N/A'}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item['quantity'] ?? 0}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'units',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
            else
              const AppEmptyState(message: 'No stock items found'),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentTracking() {
    final shipments = _reportData?['shipments'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipment Tracking', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 24),
            if (shipments != null && shipments.isNotEmpty)
              ...shipments.map((shipment) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping,
                            color: _getShipmentStatusColor(shipment['status'] ?? ''),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DO #${shipment['do_number'] ?? 'N/A'}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          StatusBadge(status: shipment['status'] ?? 'N/A'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (shipment['origin'] != null)
                        _buildInfoRow('From', shipment['origin']),
                      if (shipment['destination'] != null)
                        _buildInfoRow('To', shipment['destination']),
                      if (shipment['order_date'] != null)
                        _buildInfoRow('Date', DateFormat('dd MMM yyyy').format(
                          DateTime.parse(shipment['order_date']))),
                    ],
                  ),
                ),
              ))
            else
              const AppEmptyState(
                message: 'No shipments found',
                icon: Icons.local_shipping,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesPeriod() {
    final salesData = _reportData?['sales'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Period Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            if (_reportData?['period'] != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text('Period: ${_reportData!['period']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildSummaryCard('Total Sales', 'Rp ${_formatNumber(_reportData?['total_sales'])}', Colors.green, icon: Icons.shopping_cart),
            if (salesData != null && salesData.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Sales Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 12),
              ...salesData.map((sale) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(sale['description'] ?? ''),
                  trailing: Text('Rp ${_formatNumber(sale['amount'])}'),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBranchRanking() {
    final rankings = _reportData?['rankings'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branch Ranking', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 24),
            if (rankings != null && rankings.isNotEmpty)
              ...rankings.asMap().entries.map((entry) {
                final index = entry.key;
                final branch = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index < 3
                          ? [Colors.amber, Colors.grey, Colors.brown][index]
                          : Colors.grey.shade300,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: index < 3 ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    title: Text(branch['name'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Total: ${branch['total'] ?? 0}'),
                    trailing: Icon(
                      index == 0 ? Icons.emoji_events : Icons.leaderboard,
                      color: index == 0 ? Colors.amber : Colors.grey,
                    ),
                  ),
                );
              })
            else
              const AppEmptyState(
                message: 'No ranking data available',
                icon: Icons.leaderboard,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAudit() {
    final auditItems = _reportData?['items'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock Audit Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 24),
            if (auditItems != null && auditItems.isNotEmpty)
              ...auditItems.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item['cylinder_type'] ?? 'N/A',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (item['status'] != null)
                            StatusBadge(status: item['status']),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Branch', item['branch']?['name'] ?? 'N/A'),
                      _buildInfoRow('System', '${item['system_qty'] ?? 0}'),
                      _buildInfoRow('Physical', '${item['physical_qty'] ?? 0}'),
                      if (item['difference'] != null)
                        _buildInfoRow('Difference', item['difference'].toString(),
                          valueColor: (item['difference'] as num) != 0 ? Colors.red : Colors.green,
                        ),
                    ],
                  ),
                ),
              ))
            else
              const AppEmptyState(
                message: 'No audit data available',
                icon: Icons.assignment,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHppReport() {
    final hppItems = _reportData?['items'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HPP Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            _buildSummaryCard('Total HPP', 'Rp ${_formatNumber(_reportData?['total_hpp'])}', Colors.indigo, icon: Icons.calculate),
            const SizedBox(height: 16),
            if (hppItems != null && hppItems.isNotEmpty)
              ...hppItems.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item['cylinder_type'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Qty: ${item['quantity'] ?? 0}'),
                  trailing: Text(
                    'Rp ${_formatNumber(item['hpp'])}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ))
            else
              const AppEmptyState(
                message: 'No HPP data available',
                icon: Icons.calculate,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivablesAging() {
    final receivables = _reportData?['receivables'] as List?;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receivables Aging', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            _buildSummaryCard('Total Receivables', 'Rp ${_formatNumber(_reportData?['total_receivables'])}', Colors.deepOrange, icon: Icons.account_balance),
            const SizedBox(height: 16),
            if (receivables != null && receivables.isNotEmpty)
              ...receivables.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getAgingColor(item['aging_days'] ?? 0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance, color: _getAgingColor(item['aging_days'] ?? 0)),
                  ),
                  title: Text(item['customer'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${item['aging_days'] ?? 0} days'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rp ${_formatNumber(item['amount'])}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getAgingColor(item['aging_days'] ?? 0),
                        ),
                      ),
                      Text(
                        _getAgingLabel(item['aging_days'] ?? 0),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ))
            else
              const AppEmptyState(
                message: 'No receivables data',
                icon: Icons.account_balance,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _reportTypes[_selectedReport]['name'],
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    _reportTypes[_selectedReport]['icon'],
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This report is available but detailed implementation is pending.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getShipmentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'in-transit': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getAgingColor(int days) {
    if (days <= 30) return Colors.green;
    if (days <= 60) return Colors.orange;
    if (days <= 90) return Colors.deepOrange;
    return Colors.red;
  }

  String _getAgingLabel(int days) {
    if (days <= 30) return 'Current';
    if (days <= 60) return '30-60 days';
    if (days <= 90) return '60-90 days';
    return '> 90 days';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = num.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }
}