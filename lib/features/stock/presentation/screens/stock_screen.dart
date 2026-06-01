import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:intl/intl.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _stockItems = [];
  List<dynamic> _mutations = [];
  List<dynamic> _closes = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0;

  // Filters
  String _selectedCylinderType = 'all';
  String _selectedMutationType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadStockItems();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {
      _selectedTab = _tabController.index;
    });
    
    // Load data for the selected tab if not loaded
    if (_selectedTab == 1 && _mutations.isEmpty) {
      _loadMutations();
    } else if (_selectedTab == 2 && _closes.isEmpty) {
      _loadCloses();
    }
  }

  Future<void> _loadStockItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      Map<String, dynamic>? queryParams;
      
      if (_selectedCylinderType != 'all') {
        queryParams = {'cylinder_type': _selectedCylinderType};
      }

      final response = await apiService.get(ApiConstants.stock, queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData['data'] ?? responseData;
        
        setState(() {
          _stockItems = data is List ? data : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stock items';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMutations() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      Map<String, dynamic>? queryParams;
      
      if (_selectedMutationType != 'all') {
        queryParams = {'mutation_type': _selectedMutationType};
      }
      if (_selectedCylinderType != 'all') {
        queryParams ??= {};
        queryParams['cylinder_type'] = _selectedCylinderType;
      }

      final response = await apiService.get(ApiConstants.stockMutations, queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData['data'] ?? responseData;
        
        setState(() {
          _mutations = data is List ? data : [];
        });
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> _loadCloses() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(ApiConstants.stockCloses);
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData['data'] ?? responseData;
        
        setState(() {
          _closes = data is List ? data : [];
        });
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedTab == 0) {
                _loadStockItems();
              } else if (_selectedTab == 1) {
                _loadMutations();
              } else {
                _loadCloses();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stock Items'),
            Tab(text: 'Mutations'),
            Tab(text: 'Closes'),
          ],
        ),
      ),
      body: _isLoading
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
                        onPressed: _loadStockItems,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStockItemsTab(),
                    _buildMutationsTab(),
                    _buildClosesTab(),
                  ],
                ),
    );
  }

  Widget _buildStockItemsTab() {
    if (_stockItems.isEmpty) {
      return const Center(child: Text('No stock items available'));
    }

    return RefreshIndicator(
      onRefresh: _loadStockItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stockItems.length,
        itemBuilder: (context, index) {
          final item = _stockItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.inventory_2, color: Colors.blue),
              title: Text(item['cylinder_type'] ?? 'N/A'),
              subtitle: Text('Branch: ${item['branch_name'] ?? 'N/A'}'),
              trailing: Text(
                '${item['qty_full'] ?? 0} units',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMutationsTab() {
    if (_mutations.isEmpty) {
      return const Center(child: Text('No mutations available'));
    }

    return RefreshIndicator(
      onRefresh: _loadMutations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mutations.length,
        itemBuilder: (context, index) {
          final mutation = _mutations[index];
          final date = mutation['mutation_date'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(mutation['mutation_date']))
              : 'N/A';
          
          Color getTypeColor(String type) {
            switch (type) {
              case 'in': return Colors.green;
              case 'out': return Colors.red;
              case 'transfer': return Colors.orange;
              case 'adjustment': return Colors.blue;
              default: return Colors.grey;
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                Icons.swap_horiz,
                color: getTypeColor(mutation['mutation_type'] ?? ''),
              ),
              title: Text('${mutation['cylinder_type'] ?? 'N/A'} - ${mutation['mutation_type'] ?? 'N/A'}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: $date'),
                  Text('Branch: ${mutation['branch']?['name'] ?? 'N/A'}'),
                  if (mutation['notes'] != null) Text('Notes: ${mutation['notes']}'),
                ],
              ),
              trailing: Text(
                '${mutation['quantity'] ?? 0} units',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClosesTab() {
    if (_closes.isEmpty) {
      return const Center(child: Text('No closing records available'));
    }

    return RefreshIndicator(
      onRefresh: _loadCloses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _closes.length,
        itemBuilder: (context, index) {
          final close = _closes[index];
          final date = close['close_date'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(close['close_date']))
              : 'N/A';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.close, color: Colors.orange),
              title: Text('${close['cylinder_type'] ?? 'N/A'} - Close'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: $date'),
                  Text('Branch: ${close['branch']?['name'] ?? 'N/A'}'),
                  Text('Full: ${close['qty_full'] ?? 0}, Empty: ${close['qty_empty'] ?? 0}, Damaged: ${close['qty_damaged'] ?? 0}'),
                ],
              ),
              trailing: Chip(
                label: Text(close['status'] ?? 'N/A'),
                backgroundColor: close['status'] == 'submitted' ? Colors.green : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }
}