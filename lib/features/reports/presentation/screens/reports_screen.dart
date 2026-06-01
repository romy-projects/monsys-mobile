import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Row(
        children: [
          // Report type list
          NavigationRail(
            selectedIndex: _selectedReport,
            onDestinationSelected: (index) {
              setState(() {
                _selectedReport = index;
                _reportData = null;
                _errorMessage = null;
              });
              _loadReport();
            },
            labelType: NavigationRailLabelType.all,
            destinations: _reportTypes
                .map((report) => NavigationRailDestination(
                      icon: Icon(report['icon']),
                      label: Text(report['name']),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Report content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadReport,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _reportData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _reportTypes[_selectedReport]['icon'],
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a report to view',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _reportTypes[_selectedReport]['name'],
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          )
                        : _buildReportContent(),
          ),
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
      default:
        return _buildGenericReport();
    }
  }

  Widget _buildProfitLossReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profit & Loss Report', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _buildSummaryCard('Total Revenue', 'Rp ${_reportData?['total_revenue'] ?? '0'}', Colors.green),
          _buildSummaryCard('Total Expenses', 'Rp ${_reportData?['total_expenses'] ?? '0'}', Colors.red),
          _buildSummaryCard('Net Profit', 'Rp ${_reportData?['net_profit'] ?? '0'}', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStockSummaryReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock Summary Report', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          if (_reportData?['items'] is List)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (_reportData?['items'] as List).length,
              itemBuilder: (context, index) {
                final item = (_reportData?['items'] as List)[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item['cylinder_type'] ?? 'N/A'),
                    subtitle: Text('Branch: ${item['branch']?['name'] ?? 'N/A'}'),
                    trailing: Text(
                      '${item['quantity'] ?? 0} units',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGenericReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_reportTypes[_selectedReport]['name'], style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('This report is available but detailed implementation is pending.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.analytics, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}