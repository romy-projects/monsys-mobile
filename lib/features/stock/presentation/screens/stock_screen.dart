import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';
import 'package:intl/intl.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
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

  final List<String> _cylinderTypes = ['all', 'tube', 'crane', 'forklift'];
  final List<String> _mutationTypes = ['all', 'in', 'out', 'transfer', 'adjustment'];

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
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedTab = _tabController.index;
      });

      if (_selectedTab == 1 && _mutations.isEmpty) {
        _loadMutations();
      } else if (_selectedTab == 2 && _closes.isEmpty) {
        _loadCloses();
      }
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

      final response =
          await apiService.get(ApiConstants.stock, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData['data'] ?? responseData;

        setState(() {
          _stockItems = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load stock items';
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

      final response = await apiService.get(ApiConstants.stockMutations,
          queryParameters: queryParams);

      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData['data'] ?? responseData;

        setState(() {
          _mutations = data is List ? data : [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load mutations')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load mutations')),
        );
      }
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load closing records')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load closing records')),
        );
      }
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
      body: Column(
        children: [
          // Filter bar
          if (_selectedTab == 0 || _selectedTab == 1) _buildFilterBar(),
          Expanded(
            child: _isLoading && _selectedTab == 0
                ? _buildSkeletonLoading()
                : _errorMessage != null && _selectedTab == 0
                    ? AppErrorState(
                        message: _errorMessage!,
                        onRetry: _loadStockItems,
                      )
                    : TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStockItemsTab(),
                          _buildMutationsTab(),
                          _buildClosesTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Cylinder type filter
            const Icon(Icons.filter_alt, size: 18),
            const SizedBox(width: 8),
            ...(_selectedTab == 0 ? _cylinderTypes : _cylinderTypes).map(
              (type) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildFilterChip(
                  label: type == 'all' ? 'All' : type,
                  isSelected: _selectedCylinderType == type,
                  onTap: () {
                    setState(() {
                      _selectedCylinderType = type;
                    });
                    _loadStockItems();
                  },
                ),
              ),
            ),
            if (_selectedTab == 1) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: theme.dividerColor),
              const SizedBox(width: 8),
              ..._mutationTypes.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildFilterChip(
                    label: type == 'all' ? 'All' : type,
                    isSelected: _selectedMutationType == type,
                    onTap: () {
                      setState(() {
                        _selectedMutationType = type;
                      });
                      _loadMutations();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const ShimmerLoading(width: 40, height: 40, borderRadius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerLoading(width: 120, height: 14, borderRadius: 4),
                      const SizedBox(height: 8),
                      const ShimmerLoading(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ShimmerLoading(width: 60, height: 20, borderRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockItemsTab() {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    if (_stockItems.isEmpty) {
      return const AppEmptyState(
        message: 'No stock items available',
        icon: Icons.inventory_2,
      );
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['cylinder_type'] ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Branch: ${item['branch_name'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item['qty_full'] ?? 0}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMutationsTab() {
    if (_mutations.isEmpty) {
      return const AppEmptyState(
        message: 'No mutations available',
        icon: Icons.swap_horiz,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMutations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mutations.length,
        itemBuilder: (context, index) {
          final mutation = _mutations[index];
          final date = mutation['mutation_date'] != null
              ? DateFormat('dd MMM yyyy')
                  .format(DateTime.parse(mutation['mutation_date']))
              : 'N/A';

          Color getTypeColor(String type) {
            switch (type) {
              case 'in':
                return Colors.green;
              case 'out':
                return Colors.red;
              case 'transfer':
                return Colors.orange;
              case 'adjustment':
                return Colors.blue;
              default:
                return Colors.grey;
            }
          }

          final typeColor = getTypeColor(mutation['mutation_type'] ?? '');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.swap_horiz, color: typeColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${mutation['cylinder_type'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Date: $date',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: mutation['mutation_type'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Branch: ${mutation['branch']?['name'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${mutation['quantity'] ?? 0} units',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (mutation['notes'] != null &&
                      mutation['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Notes: ${mutation['notes']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClosesTab() {
    if (_closes.isEmpty) {
      return const AppEmptyState(
        message: 'No closing records available',
        icon: Icons.close,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCloses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _closes.length,
        itemBuilder: (context, index) {
          final close = _closes[index];
          final date = close['close_date'] != null
              ? DateFormat('dd MMM yyyy')
                  .format(DateTime.parse(close['close_date']))
              : 'N/A';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${close['cylinder_type'] ?? 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (close['status'] != null)
                        StatusBadge(status: close['status']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCloseInfoRow('Date', date),
                  _buildCloseInfoRow('Branch', close['branch']?['name'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQtyChip('Full', close['qty_full'], Colors.green),
                      const SizedBox(width: 8),
                      _buildQtyChip('Empty', close['qty_empty'], Colors.orange),
                      const SizedBox(width: 8),
                      _buildQtyChip('Damaged', close['qty_damaged'], Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCloseInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyChip(String label, dynamic qty, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '${qty ?? 0}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}