import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';
import 'package:intl/intl.dart';

class DeliveryOrderScreen extends ConsumerStatefulWidget {
  const DeliveryOrderScreen({super.key});

  @override
  ConsumerState<DeliveryOrderScreen> createState() =>
      _DeliveryOrderScreenState();
}

class _DeliveryOrderScreenState extends ConsumerState<DeliveryOrderScreen> {
  List<dynamic> _deliveryOrders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDeliveryOrders();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredOrders = _deliveryOrders.where((order) {
        // Status filter
        if (_statusFilter != 'all' && order['status'] != _statusFilter) {
          return false;
        }
        // Search filter
        if (query.isNotEmpty) {
          final doNumber = (order['do_number'] ?? '').toString().toLowerCase();
          final branchName =
              (order['destination_branch']?['name'] ?? '').toString().toLowerCase();
          return doNumber.contains(query) || branchName.contains(query);
        }
        return true;
      }).toList();
    });
  }

  Future<void> _loadDeliveryOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(ApiConstants.deliveryOrders);

      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData['data'] ?? responseData;

        setState(() {
          _deliveryOrders = data is List ? data : [];
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = 'Failed to load delivery orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load delivery orders';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String orderId, String action) async {
    // Confirmation dialog
    final actionLabels = {
      'submit': 'Submit',
      'approve': 'Approve',
      'mark-in-transit': 'Mark In-Transit',
      'receive': 'Mark Received',
      'cancel': 'Cancel',
    };
    final actionLabel = actionLabels[action] ?? action;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'cancel' ? 'Cancel Order' : actionLabel),
        content: Text(
          action == 'cancel'
              ? 'Are you sure you want to cancel this order?'
              : 'Are you sure you want to $actionLabel this order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: action == 'cancel'
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(action == 'cancel' ? 'Yes, Cancel' : 'Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '${ApiConstants.deliveryOrders}/$orderId/$action',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order $actionLabel successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadDeliveryOrders();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to $actionLabel order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $actionLabel order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrderDetails(dynamic order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order ${order['do_number']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StatusBadge(status: order['status'] ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailCard(order),
              const SizedBox(height: 24),
              Text(
                'Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(dynamic order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(Icons.person, 'Customer',
                order['destination_branch']?['name'] ?? 'N/A'),
            const Divider(height: 20),
            _buildDetailRow(Icons.info, 'Status', order['status'] ?? 'N/A'),
            const Divider(height: 20),
            _buildDetailRow(Icons.calendar_today, 'Date',
                order['order_date'] != null
                    ? DateFormat('dd MMM yyyy')
                        .format(DateTime.parse(order['order_date']))
                    : 'N/A'),
            const Divider(height: 20),
            _buildDetailRow(Icons.location_on, 'Address',
                order['destination_branch']?['address'] ?? 'N/A'),
            const Divider(height: 20),
            _buildDetailRow(
                Icons.inventory, 'Items', order['cylinder_type']?.toString() ?? 'N/A'),
            if (order['notes'] != null) ...[
              const Divider(height: 20),
              _buildDetailRow(Icons.notes, 'Notes', order['notes']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
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
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(dynamic order) {
    final status = order['status'] ?? '';
    final orderId = order['id'].toString();

    List<Widget> buttons = [];

    if (status == 'pending') {
      buttons.add(_buildActionButton(
        label: 'Submit',
        icon: Icons.send,
        color: Colors.blue,
        onPressed: () => _updateOrderStatus(orderId, 'submit'),
      ));
    } else if (status == 'submitted') {
      buttons.add(_buildActionButton(
        label: 'Approve',
        icon: Icons.check,
        color: Colors.green,
        onPressed: () => _updateOrderStatus(orderId, 'approve'),
      ));
    } else if (status == 'approved') {
      buttons.add(_buildActionButton(
        label: 'Mark In-Transit',
        icon: Icons.local_shipping,
        color: Colors.purple,
        onPressed: () => _updateOrderStatus(orderId, 'mark-in-transit'),
      ));
    } else if (status == 'in-transit') {
      buttons.add(_buildActionButton(
        label: 'Mark Received',
        icon: Icons.check_circle,
        color: Colors.teal,
        onPressed: () => _updateOrderStatus(orderId, 'receive'),
      ));
    }

    if (status != 'cancelled' && status != 'received') {
      buttons.add(_buildActionButton(
        label: 'Cancel Order',
        icon: Icons.cancel,
        color: Colors.red,
        isOutlined: true,
        onPressed: () => _updateOrderStatus(orderId, 'cancel'),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons,
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveryOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by DO number or customer...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('all', 'All'),
                      _buildStatusFilterChip('pending', 'Pending'),
                      _buildStatusFilterChip('submitted', 'Submitted'),
                      _buildStatusFilterChip('approved', 'Approved'),
                      _buildStatusFilterChip('in-transit', 'In Transit'),
                      _buildStatusFilterChip('received', 'Received'),
                      _buildStatusFilterChip('cancelled', 'Cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoading()
                : _errorMessage != null
                    ? AppErrorState(
                        message: _errorMessage!,
                        onRetry: _loadDeliveryOrders,
                      )
                    : _filteredOrders.isEmpty
                        ? const AppEmptyState(
                            message: 'No delivery orders found',
                            subtitle: 'Try adjusting your search or filters',
                            icon: Icons.local_shipping,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDeliveryOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                final date = order['order_date'] != null
                                    ? DateFormat('dd MMM yyyy').format(
                                        DateTime.parse(order['order_date']))
                                    : 'N/A';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _showOrderDetails(order),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                          order['status'] ?? '')
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.local_shipping,
                                                  color: _getStatusColor(
                                                      order['status'] ?? ''),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Order ${order['do_number']}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Text(
                                                      order['destination_branch']?['name'] ?? 'N/A',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              StatusBadge(
                                                  status: order['status'] ?? 'N/A'),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                date,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _statusFilter = value;
          });
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerLoading(width: 40, height: 40, borderRadius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerLoading(width: 140, height: 14, borderRadius: 4),
                          const SizedBox(height: 6),
                          const ShimmerLoading(width: 100, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const ShimmerLoading(width: 120, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'in-transit':
        return Colors.purple;
      case 'received':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}