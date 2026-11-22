import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/features/orders/domain/order_document.dart';
import 'package:monsys_mobile/features/orders/presentation/widgets/create_order_sheet.dart';
import 'package:monsys_mobile/features/orders/presentation/widgets/create_po_sheet.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Orders hub for the active document flow — SO / LO / PO. All three are
/// `delivery_orders` rows on the panelx API, distinguished by `document_type`.
///
/// Delivery Orders are retired in panelx (`POST /delivery-orders` is gone), so
/// the app no longer exposes a DO tab. Tabs are role-aware (Phase 7/8 RBAC):
///  - owner_pusat / super_admin / regional_leader -> SO | LO | PO
///  - owner_cabang / staff_gudang               -> PO only (branch roles get
///    403 from the SO/LO endpoints and create Purchase Orders instead).
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _hqDocTypes = ['so', 'lo', 'po'];
  static const _branchDocTypes = ['po'];
  static const _endpoints = <String, String>{
    'so': ApiConstants.salesOrders,
    'lo': ApiConstants.loadingOrders,
    'po': ApiConstants.purchaseOrders,
  };
  static const _tabLabels = <String, String>{
    'so': 'SO',
    'lo': 'LO',
    'po': 'PO',
  };

  UserAccount _user = const UserAccount();
  String _docType = 'so';
  bool _initialized = false;

  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  int _requestId = 0;
  String? _errorMessage;
  final _searchController = TextEditingController();
  String _statusFilter = 'all';

  List<String> _visibleDocTypesFor(UserAccount user) =>
      user.isHqRole ? _hqDocTypes : _branchDocTypes;

  List<String> get _visibleDocTypes => _visibleDocTypesFor(_user);

  String get _currentEndpoint => _endpoints[_docType] ?? ApiConstants.purchaseOrders;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    UserAccount user;
    try {
      user = await ref.read(currentUserProvider.future);
    } catch (_) {
      user = const UserAccount();
    }
    if (!mounted) return;
    setState(() {
      _user = user;
      _docType = _visibleDocTypesFor(user).first;
      _initialized = true;
    });
    await _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDocType(String docType) {
    if (docType == _docType) return;
    setState(() {
      _docType = docType;
      _statusFilter = 'all';
      _orders = const [];
      _filteredOrders = const [];
    });
    _loadOrders();
  }

  // ── Data loading & filtering ─────────────────────────────────

  Future<void> _loadOrders() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ref.read(apiServiceProvider).get(_currentEndpoint);
      if (!mounted || requestId != _requestId) return;
      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData is Map ? (responseData['data'] ?? responseData) : responseData;
        setState(() {
          _orders = data is List ? data : [];
          _isLoading = false;
        });
        _applyFilters();
      } else {
        _fail('Failed to load orders');
      }
    } on DioException catch (e) {
      if (!mounted || requestId != _requestId) return;
      final data = e.response?.data;
      final message = data is Map ? data['message'] : null;
      _fail(message is String ? message : 'Failed to load orders');
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      _fail('Failed to load orders');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
      _orders = const [];
      _filteredOrders = const [];
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredOrders = _orders.where((raw) {
        if (raw is! Map) return false;
        final order = raw;
        if (_statusFilter != 'all' && order['status'] != _statusFilter) {
          return false;
        }
        if (query.isEmpty) return true;
        final haystacks = [
          order['do_number'],
          order['counterparty_name'],
          order['origin_branch']?['name'],
          order['destination_branch']?['name'],
          order['transportir_name'],
        ];
        return haystacks
            .any((f) => (f ?? '').toString().toLowerCase().contains(query));
      }).toList();
    });
  }

  // ── Workflow actions ─────────────────────────────────────────
  // Transitions per the panelx controllers:
  //   draft -> submit -> pending_approval -> approve -> approved
  //   approved -> mark-in-transit (SO/PO) | mark-loaded (LO)
  //   in_transit -> receive {quantity_received, received_date} -> delivered (PO)
  //   cancel: draft/pending_approval (approver only)

  Future<void> _runAction(Map order, _OrderAction action) async {
    Map<String, dynamic>? body;
    if (action.needsReceiveDetails) {
      body = await _promptReceiveDetails(order);
      if (body == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.label),
          content: Text(action.destructive
              ? 'Are you sure you want to cancel this order?'
              : 'Are you sure you want to ${action.label.toLowerCase()} this order?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: action.destructive
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              child: Text(action.destructive ? 'Yes, Cancel' : 'Yes'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final response = await ref.read(apiServiceProvider).post(
            '$_currentEndpoint/${order['id']}/${action.suffix}',
            data: body,
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final message = data is Map && data['message'] != null
            ? data['message'].toString()
            : '${action.label} successful';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ));
        _loadOrders();
      } else {
        _showActionError(action, null);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _showActionError(
          action,
          data is Map && data['message'] is String
              ? data['message'] as String
              : null);
    } catch (_) {
      _showActionError(action, null);
    }
  }

  void _showActionError(_OrderAction action, String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message ?? 'Failed to ${action.label.toLowerCase()}'),
      backgroundColor: Colors.red,
    ));
  }

  /// `receive` requires a payload: quantity_received + received_date (today).
  Future<Map<String, dynamic>?> _promptReceiveDetails(Map order) async {
    final qtyController =
        TextEditingController(text: '${order['quantity_ordered'] ?? 0}');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Purchase Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm the received quantity for ${order['do_number']}.'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Quantity received'),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim());
              if (qty == null || qty < 0) return;
              Navigator.pop(ctx, <String, dynamic>{
                'quantity_received': qty,
                'received_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              });
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    qtyController.dispose();
    return result;
  }

  List<_OrderAction> _actionsFor(Map order) {
    final status = (order['status'] ?? '').toString();
    final docType = _docType;
    final canApprove = _user.canApprove;
    final readOnly = _user.isReadOnlyRole;

    switch (status) {
      case 'draft':
        return [
          if (!readOnly) const _OrderAction('Submit', 'submit'),
          if (canApprove)
            const _OrderAction('Cancel', 'cancel', destructive: true),
        ];
      case 'pending_approval':
        return [
          if (canApprove) const _OrderAction('Approve', 'approve'),
          if (canApprove)
            const _OrderAction('Cancel', 'cancel', destructive: true),
        ];
      case 'approved':
        if (docType == 'lo') {
          return canApprove
              ? const [_OrderAction('Mark Loaded', 'mark-loaded')]
              : const [];
        }
        return canApprove
            ? const [_OrderAction('Mark In-Transit', 'mark-in-transit')]
            : const [];
      case 'in_transit':
        return docType == 'po'
            ? const [
                _OrderAction('Receive', 'receive', needsReceiveDetails: true),
              ]
            : const [];
      default:
        return const [];
    }
  }

  // ── Order creation ───────────────────────────────────────────

  bool get _canCreatePo => _docType == 'po' && !_user.isHqRole && !_user.isReadOnlyRole;

  bool get _canCreateHqOrder =>
      _user.isHqRole && (_docType == 'so' || _docType == 'lo');

  Future<void> _openCreatePo() async {
    final created = await CreatePoSheet.show(context);
    if (created == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Purchase Order ${created['do_number'] ?? ''} created successfully'),
      backgroundColor: Colors.green,
    ));
    _loadOrders();
  }

  Future<void> _openCreateHqOrder() async {
    final created = await CreateOrderSheet.show(context, docType: _docType);
    if (created == null) return;
    if (!mounted) return;
    final label = OrderDocument.docTypeLabel(_docType);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '$label ${created['do_number'] ?? ''} created successfully'),
      backgroundColor: Colors.green,
    ));
    _loadOrders();
  }

  Widget? _buildCreateFab() {
    if (_canCreatePo) {
      return FloatingActionButton.extended(
        onPressed: _openCreatePo,
        icon: const Icon(Icons.add),
        label: const Text('New PO'),
      );
    }
    if (_canCreateHqOrder) {
      return FloatingActionButton.extended(
        onPressed: _openCreateHqOrder,
        icon: const Icon(Icons.add),
        label: Text('New ${_docType.toUpperCase()}'),
      );
    }
    return null;
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docTypes = _visibleDocTypes;
    return Scaffold(
      appBar: AppBar(
        title: Text(_user.isHqRole ? 'Orders' : 'Purchase Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (docTypes.length > 1)
                  AppSegmentedTabs(
                    labels: [for (final type in docTypes) _tabLabels[type]!],
                    selectedIndex: docTypes.indexOf(_docType),
                    onChanged: (index) => _selectDocType(docTypes[index]),
                  ),
                _buildFilterBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? AppErrorState(
                              message: _errorMessage!,
                              onRetry: _loadOrders,
                            )
                          : _filteredOrders.isEmpty
                              ? const AppEmptyState(
                                  message: 'No orders found',
                                  subtitle:
                                      'Try adjusting your search or filters',
                                  icon: Icons.receipt_long,
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadOrders,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 96),
                                    itemCount: _filteredOrders.length,
                                    itemBuilder: (context, index) =>
                                        _buildOrderCard(
                                            _filteredOrders[index]),
                                  ),
                                ),
                ),
              ],
            ),
      floatingActionButton: _buildCreateFab(),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Search number, branch, transportir…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
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
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in OrderDocument.statusFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status == 'all'
                          ? 'All'
                          : OrderDocument.statusLabel(status)),
                      selected: _statusFilter == status,
                      onSelected: (_) {
                        setState(() => _statusFilter = status);
                        _applyFilters();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map order) {
    final status = (order['status'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _docBadge(_docType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${order['do_number'] ?? 'N/A'}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_fmtDate(order['order_date']?.toString())}  •  '
                '${order['cylinder_type'] ?? '—'}  •  '
                'Qty ${order['quantity_ordered'] ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                _routeLabel(order),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (status == 'in_transit' || status == 'on_transportir') ...[
                const SizedBox(height: 8),
                _shipmentChip(order),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _docBadge(String docType) {
    final color = OrderDocument.docTypeColor(docType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        docType.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _shipmentChip(Map order) {
    final label =
        OrderDocument.shipmentStatusLabel(order['shipment_status']?.toString());
    if (label.isEmpty) return const SizedBox.shrink();
    final transportir = order['transportir_name']?.toString();
    return Row(
      children: [
        const Icon(Icons.local_shipping, size: 14, color: Colors.indigo),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            transportir != null && transportir.isNotEmpty
                ? '$label  •  $transportir'
                : label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _routeLabel(Map order) {
    final origin = order['origin_branch']?['name']?.toString();
    final dest = order['destination_branch']?['name']?.toString();
    final counterparty = order['counterparty_name']?.toString();
    if ((origin ?? '').isNotEmpty && (dest ?? '').isNotEmpty) {
      return '$origin → $dest';
    }
    if ((counterparty ?? '').isNotEmpty) {
      return OrderDocument.counterpartyLabel(
          order['counterparty_type']?.toString(), counterparty);
    }
    return '—';
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat('dd MMM yyyy').format(dt);
  }

  void _showOrderDetails(Map order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
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
                      '${OrderDocument.docTypeLabel(_docType)} '
                      '${order['do_number'] ?? ''}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusBadge(status: (order['status'] ?? '').toString()),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailCard(order),
              const SizedBox(height: 20),
              Text(
                'Actions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(Map order) {
    final expedition = order['expedition'];
    final vehicle = order['vehicle'];
    final shipmentStatus = order['shipment_status']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _detailRow(Icons.description, 'Document',
                OrderDocument.docTypeLabel(_docType)),
            if ((order['counterparty_name'] ?? '').toString().isNotEmpty)
              _detailRow(
                  Icons.handshake,
                  'Counterparty',
                  OrderDocument.counterpartyLabel(
                      order['counterparty_type']?.toString(),
                      order['counterparty_name']?.toString())),
            if ((order['origin_branch']?['name'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.north_east, 'From',
                  order['origin_branch']?['name']?.toString() ?? '—'),
            if ((order['destination_branch']?['name'] ?? '')
                .toString()
                .isNotEmpty)
              _detailRow(Icons.south_west, 'To',
                  order['destination_branch']?['name']?.toString() ?? '—'),
            _detailRow(Icons.propane_tank, 'Cylinder',
                '${order['cylinder_type'] ?? '—'}'),
            _detailRow(
                Icons.inventory_2,
                'Quantity',
                'Ordered ${order['quantity_ordered'] ?? '—'}'
                '${order['quantity_received'] != null ? ' / Received ${order['quantity_received']}' : ''}'),
            if ((order['so_number'] ?? '').toString().isNotEmpty)
              _detailRow(
                  Icons.link, 'SO Ref', order['so_number']?.toString() ?? '—'),
            if ((order['po_number'] ?? '').toString().isNotEmpty)
              _detailRow(
                  Icons.link, 'PO Ref', order['po_number']?.toString() ?? '—'),
            if ((order['container_number'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.inventory, 'Container',
                  order['container_number']?.toString() ?? '—'),
            _detailRow(Icons.calendar_today, 'Order date',
                _fmtDate(order['order_date']?.toString())),
            if (order['eta'] != null)
              _detailRow(
                  Icons.schedule, 'ETA', _fmtDate(order['eta']?.toString())),
            if (order['loading_date'] != null)
              _detailRow(Icons.event, 'Loading date',
                  _fmtDate(order['loading_date']?.toString())),
            if (order['received_date'] != null)
              _detailRow(Icons.event_available, 'Received date',
                  _fmtDate(order['received_date']?.toString())),
            if ((shipmentStatus ?? '').isNotEmpty) ...[
              _detailRow(Icons.local_shipping, 'Shipment',
                  OrderDocument.shipmentStatusLabel(shipmentStatus)),
              if ((order['transportir_name'] ?? '').toString().isNotEmpty)
                _detailRow(Icons.person, 'Transportir',
                    order['transportir_name']?.toString() ?? '—'),
            ],
            if (expedition is Map)
              _detailRow(Icons.directions_boat, 'Expedition',
                  expedition['name']?.toString() ?? '—'),
            if (vehicle is Map)
              _detailRow(
                  Icons.directions_car,
                  'Vehicle',
                  '${vehicle['plate_number'] ?? '—'}'
                  '${(vehicle['driver_name'] ?? '').toString().isNotEmpty ? ' (${vehicle['driver_name']})' : ''}'),
            if ((order['requested_by'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.person_outline, 'Requested by',
                  order['requested_by']?.toString() ?? '—'),
            if ((order['approved_by'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.how_to_reg, 'Approved by',
                  order['approved_by']?.toString() ?? '—'),
            if ((order['notes'] ?? '').toString().isNotEmpty)
              _detailRow(
                  Icons.notes, 'Notes', order['notes']?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map order) {
    final actions = _actionsFor(order);
    if (actions.isEmpty) {
      return Text(
        'No actions available for this order status.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          action.destructive
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    Navigator.pop(context); // close the sheet first
                    _runAction(order, action);
                  },
                  child: Text(action.label),
                )
              : FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // close the sheet first
                    _runAction(order, action);
                  },
                  child: Text(action.label),
                ),
      ],
    );
  }
}

class _OrderAction {
  const _OrderAction(
    this.label,
    this.suffix, {
    this.destructive = false,
    this.needsReceiveDetails = false,
  });

  final String label;
  final String suffix;
  final bool destructive;
  final bool needsReceiveDetails;
}
