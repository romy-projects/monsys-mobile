import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:intl/intl.dart';

class DeliveryOrderScreen extends ConsumerStatefulWidget {
  const DeliveryOrderScreen({super.key});

  @override
  ConsumerState<DeliveryOrderScreen> createState() => _DeliveryOrderScreenState();
}

class _DeliveryOrderScreenState extends ConsumerState<DeliveryOrderScreen> {
  List<dynamic> _deliveryOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeliveryOrders();
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
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load delivery orders';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String orderId, String action) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '$ApiConstants.deliveryOrders/$orderId/$action',
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order status updated successfully')),
        );
        _loadDeliveryOrders();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update order status')),
      );
    }
  }

  void _showOrderDetails(dynamic order) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${order['do_number']}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildDetailRow('Customer', order['destination_branch']?['name'] ?? 'N/A'),
            _buildDetailRow('Status', order['status'] ?? 'N/A'),
            _buildDetailRow('Date', order['order_date'] != null 
                ? DateFormat('dd MMM yyyy').format(DateTime.parse(order['order_date'])) 
                : 'N/A'),
            _buildDetailRow('Address', order['destination_branch']?['address'] ?? 'N/A'),
            _buildDetailRow('Items', order['cylinder_type']?.toString() ?? 'N/A'),
            _buildDetailRow('Notes', order['notes'] ?? 'N/A'),
            const SizedBox(height: 24),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(dynamic order) {
    final status = order['status'] ?? '';
    final orderId = order['id'].toString();
    
    List<Widget> buttons = [];
    
    if (status == 'pending') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(orderId, 'submit'),
          icon: const Icon(Icons.send),
          label: const Text('Submit'),
        ),
      );
    } else if (status == 'submitted') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(orderId, 'approve'),
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
        ),
      );
    } else if (status == 'approved') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(orderId, 'mark-in-transit'),
          icon: const Icon(Icons.local_shipping),
          label: const Text('Mark In-Transit'),
        ),
      );
    } else if (status == 'in-transit') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(orderId, 'receive'),
          icon: const Icon(Icons.check_circle),
          label: const Text('Mark Received'),
        ),
      );
    }
    
    if (status != 'cancelled' && status != 'received') {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _updateOrderStatus(orderId, 'cancel'),
          icon: const Icon(Icons.cancel),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons.map((btn) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: btn,
      )).toList(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'submitted': return Colors.blue;
      case 'approved': return Colors.green;
      case 'in-transit': return Colors.purple;
      case 'received': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
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
                        onPressed: _loadDeliveryOrders,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDeliveryOrders,
                  child: _deliveryOrders.isEmpty
                      ? const Center(child: Text('No delivery orders available'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _deliveryOrders.length,
                          itemBuilder: (context, index) {
                            final order = _deliveryOrders[index];
                            final date = order['order_date'] != null
                                ? DateFormat('dd MMM yyyy').format(DateTime.parse(order['order_date']))
                                : 'N/A';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(
                                  Icons.local_shipping,
                                  color: _getStatusColor(order['status'] ?? ''),
                                ),
                                title: Text('Order ${order['do_number']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Customer: ${order['destination_branch']?['name'] ?? 'N/A'}'),
                                    Text('Date: $date'),
                                    const SizedBox(height: 4),
                                    Chip(
                                      label: Text(order['status'] ?? 'N/A'),
                                      backgroundColor: _getStatusColor(order['status'] ?? '').withOpacity(0.2),
                                      labelStyle: TextStyle(color: _getStatusColor(order['status'] ?? '')),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => _showOrderDetails(order),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}