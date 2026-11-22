import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Master Data viewer — branches, transportirs, expeditions, current LPG
/// prices, customers, vehicles and users. All categories are readable by any
/// authenticated user (the API branch-scopes where needed); the Users category
/// is only shown to accounts with user administration (owner_pusat /
/// super_admin). Write operations are handled in the web panel.
class _Category {
  const _Category(this.label, this.endpoint);

  final String label;
  final String endpoint;
}

class MasterDataScreen extends ConsumerStatefulWidget {
  const MasterDataScreen({super.key});

  @override
  ConsumerState<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends ConsumerState<MasterDataScreen> {
  UserAccount _user = const UserAccount();

  List<_Category> get _categories => [
        const _Category('Branches', ApiConstants.branches),
        const _Category('Transportirs', ApiConstants.transportirs),
        const _Category('Expeditions', ApiConstants.expeditions),
        const _Category('Prices', ApiConstants.pricesCurrent),
        const _Category('Customers', ApiConstants.customers),
        const _Category('Vehicles', ApiConstants.vehicles),
        if (_user.canManageUsers)
          const _Category('Users', ApiConstants.users),
      ];

  int _selectedCategory = 0;
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _user = await ref.read(currentUserProvider.future);
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    _loadData();
  }

  String get _selectedLabel => _categories[_selectedCategory].label;

  // ── Data loading ─────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ref
          .read(apiServiceProvider)
          .get(_categories[_selectedCategory].endpoint);
      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data['data'] : null;
        if (!mounted) return;
        setState(() {
          _items = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        _fail('Failed to load ${_selectedLabel.toLowerCase()}');
      }
    } on DioException catch (e) {
      _fail(_messageFrom(e.response?.data) ??
          'Failed to load ${_selectedLabel.toLowerCase()}');
    } catch (_) {
      _fail('Failed to load ${_selectedLabel.toLowerCase()}');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
      _items = const [];
    });
  }

  String? _messageFrom(Object? data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat('dd MMM yyyy').format(dt);
  }

  String _fmtMoney(num? value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value ?? 0);
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Master Data — ${_categories[_selectedCategory].label}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? AppErrorState(message: _errorMessage!, onRetry: _loadData)
                    : _items.isEmpty
                        ? AppEmptyState(
                            message: 'No ${_selectedLabel.toLowerCase()} found',
                            icon: Icons.dataset_outlined,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, index) =>
                                  _buildCard(_items[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < _categories.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_categories[i].label),
                  selected: _selectedCategory == i,
                  onSelected: (_) {
                    setState(() => _selectedCategory = i);
                    _loadData();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map item) {
    switch (_selectedLabel) {
      case 'Branches':
        return _card(
          title: item['name']?.toString() ?? 'N/A',
          badge: item['status']?.toString(),
          rows: [
            _row('Code', item['code']?.toString() ?? '—'),
            _row('City', item['city']?.toString() ?? '—'),
            _row('Province', item['province']?.toString() ?? '—'),
            if ((item['phone'] ?? '').toString().isNotEmpty)
              _row('Phone', item['phone']?.toString() ?? '—'),
          ],
        );
      case 'Transportirs':
      case 'Expeditions':
        return _card(
          title: item['name']?.toString() ?? 'N/A',
          badge: item['status']?.toString(),
          rows: [
            _row('Code', item['code']?.toString() ?? '—'),
            _row('Contact', item['contact_person']?.toString() ?? '—'),
            _row('Phone', item['phone']?.toString() ?? '—'),
          ],
        );
      case 'Prices':
        return _card(
          title: item['cylinder_type']?.toString() ?? 'N/A',
          rows: [
            _row('Purchase',
                _fmtMoney(num.tryParse('${item['purchase_price'] ?? 0}'))),
            _row(
                'Selling', _fmtMoney(num.tryParse('${item['selling_price'] ?? 0}'))),
            _row('Effective', _fmtDate(item['effective_date']?.toString())),
          ],
        );
      case 'Customers':
        return _card(
          title: item['name']?.toString() ?? 'N/A',
          badge: item['is_active'] == true ? 'active' : 'inactive',
          rows: [
            _row('Type', item['type']?.toString() ?? '—'),
            _row('Branch', item['branch_name']?.toString() ?? '—'),
            _row('Phone', item['phone']?.toString() ?? '—'),
            _row('Credit limit',
                _fmtMoney(num.tryParse('${item['credit_limit'] ?? 0}'))),
          ],
        );
      case 'Vehicles':
        return _card(
          title: item['plate_number']?.toString() ?? 'N/A',
          badge: item['status']?.toString(),
          rows: [
            _row('Type', item['type']?.toString() ?? '—'),
            _row('Driver', item['driver_name']?.toString() ?? '—'),
            _row('Driver phone', item['driver_phone']?.toString() ?? '—'),
            _row('Capacity', '${item['capacity_kg'] ?? '—'} kg'),
            _row('Expedition', item['expedition_name']?.toString() ?? '—'),
          ],
        );
      case 'Users':
        final branch = item['branch'];
        return _card(
          title: item['name']?.toString() ?? 'N/A',
          badge: item['status']?.toString(),
          rows: [
            _row('Email', item['email']?.toString() ?? '—'),
            _row('Role', item['role']?.toString() ?? '—'),
            _row('Phone', item['phone']?.toString() ?? '—'),
            if (branch is Map) _row('Branch', branch['name']?.toString() ?? '—'),
          ],
        );
      default:
        return _card(title: item.toString(), rows: const []);
    }
  }

  Widget _card({
    required String title,
    String? badge,
    required List<Widget> rows,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (badge != null && badge.isNotEmpty)
                  StatusBadge(status: badge),
              ],
            ),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }

  // ── Shared card row ──────────────────────────────────────────

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}