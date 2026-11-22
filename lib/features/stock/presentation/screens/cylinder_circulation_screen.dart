import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Tabung Sirkulasi — the per-branch cylinder circulation ledger
/// (panelx Phase 6): kirim / bongkar_kosong / pembelian / penyesuaian with
/// debit/kredit direction, plus the branches × cylinder-types running
/// balance matrix (HQ roles see all branches; branch roles see their own).
class CylinderCirculationScreen extends ConsumerStatefulWidget {
  const CylinderCirculationScreen({super.key});

  @override
  ConsumerState<CylinderCirculationScreen> createState() =>
      _CylinderCirculationScreenState();
}

class _CylinderCirculationScreenState
    extends ConsumerState<CylinderCirculationScreen>
    with SingleTickerProviderStateMixin {
  static const _cylinderTypes = ['3kg', '5.5kg', '12kg', '50kg'];
  static const _transactionTypes = [
    'kirim',
    'bongkar_kosong',
    'pembelian',
    'penyesuaian',
  ];

  TabController? _tabController;
  UserAccount _user = const UserAccount();
  int _selectedTab = 0;

  List<dynamic> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _summaryRows = [];
  List<String> _summaryTypes = const [];
  bool _isSummaryLoading = false;
  String? _summaryError;

  // Filters
  String _selectedCylinderType = 'all';
  String _selectedTransactionType = 'all';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userJson = await ref.read(authStorageProvider).getUser();
    if (!mounted) return;
    setState(() {
      _user = UserAccount.fromJsonString(userJson ?? '');
      _tabController = TabController(
        length: _user.isHqRole ? 2 : 1,
        vsync: this,
      )..addListener(_handleTabChanged);
    });
    _loadEntries();
  }

  void _handleTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    setState(() => _selectedTab = controller.index);
    if (controller.index == 1 && _summaryRows.isEmpty) {
      _loadSummary();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_selectedCylinderType != 'all') {
        params['cylinder_type'] = _selectedCylinderType;
      }
      if (_selectedTransactionType != 'all') {
        params['transaction_type'] = _selectedTransactionType;
      }
      final response = await ref
          .read(apiServiceProvider)
          .get(ApiConstants.cylinderCirculations, queryParameters: params);
      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data['data'] : null;
        if (!mounted) return;
        setState(() {
          _entries = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        _failLedger('Failed to load circulation entries');
      }
    } on DioException catch (e) {
      _failLedger(_messageFrom(e.response?.data) ??
          'Failed to load circulation entries');
    } catch (_) {
      _failLedger('Failed to load circulation entries');
    }
  }

  void _failLedger(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
      _entries = const [];
    });
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isSummaryLoading = true;
      _summaryError = null;
    });
    try {
      final response = await ref
          .read(apiServiceProvider)
          .get(ApiConstants.cylinderCirculationsSummary);
      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data['data'] : null;
        if (!mounted) return;
        setState(() {
          _summaryTypes = data is Map && data['types'] is List
              ? (data['types'] as List).map((t) => t.toString()).toList()
              : const [];
          _summaryRows = data is Map && data['rows'] is List
              ? data['rows'] as List
              : [];
          _isSummaryLoading = false;
        });
      } else {
        _failSummary('Failed to load the circulation summary');
      }
    } on DioException catch (e) {
      _failSummary(_messageFrom(e.response?.data) ??
          'Failed to load the circulation summary');
    } catch (_) {
      _failSummary('Failed to load the circulation summary');
    }
  }

  void _failSummary(String message) {
    if (!mounted) return;
    setState(() {
      _summaryError = message;
      _isSummaryLoading = false;
      _summaryRows = const [];
    });
  }

  void _refreshAll() {
    _loadEntries();
    if (_user.isHqRole && _summaryRows.isNotEmpty) _loadSummary();
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final controller = _tabController;
    final isLedger = _selectedTab == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabung Sirkulasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewEntryDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AppSegmentedTabs(
                  labels: [
                    'Ledger',
                    if (_user.isHqRole) 'Summary',
                  ],
                  selectedIndex: controller.index,
                  onChanged: (index) => controller.animateTo(index),
                ),
                if (isLedger) _buildFilterBar(),
                Expanded(
                  child: isLedger
                      ? _buildLedgerContent()
                      : _buildSummaryContent(),
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
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            const Icon(Icons.filter_alt, size: 18),
            const SizedBox(width: 8),
            for (final type in ['all', ..._cylinderTypes])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type == 'all' ? 'All' : type),
                  selected: _selectedCylinderType == type,
                  onSelected: (_) {
                    setState(() => _selectedCylinderType = type);
                    _loadEntries();
                  },
                ),
              ),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: theme.dividerColor),
            const SizedBox(width: 8),
            for (final type in ['all', ..._transactionTypes])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                      type == 'all' ? 'All types' : _transactionLabel(type)),
                  selected: _selectedTransactionType == type,
                  onSelected: (_) {
                    setState(() => _selectedTransactionType = type);
                    _loadEntries();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return AppErrorState(message: _errorMessage!, onRetry: _loadEntries);
    }
    if (_entries.isEmpty) {
      return const AppEmptyState(
        message: 'No circulation entries found',
        subtitle: 'Adjust the filters or add a new entry',
        icon: Icons.sync_alt,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: _entries.length,
        itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
      ),
    );
  }

  Widget _buildEntryCard(Map entry) {
    final direction = entry['direction']?.toString();
    final isDebit = direction == 'debit';
    final typeColor = _transactionColor(entry['transaction_type']?.toString());
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
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sync_alt, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_transactionLabel(entry['transaction_type']?.toString())}  •  '
                        '${entry['cylinder_type'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_fmtDate(entry['transaction_date']?.toString())}  •  '
                        'Qty ${entry['quantity'] ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: isDebit ? 'debit' : 'kredit'),
              ],
            ),
            const SizedBox(height: 12),
            if (entry['branch'] is Map)
              _infoLine('Branch', entry['branch']['name']?.toString() ?? '—'),
            if ((entry['so_number'] ?? '').toString().isNotEmpty)
              _infoLine('SO No', entry['so_number']?.toString() ?? '—'),
            if ((entry['container_no'] ?? '').toString().isNotEmpty)
              _infoLine('Container', entry['container_no']?.toString() ?? '—'),
            if ((entry['handled_by'] ?? '').toString().isNotEmpty)
              _infoLine('Handled by', entry['handled_by']?.toString() ?? '—'),
            if ((entry['description'] ?? '').toString().isNotEmpty)
              _infoLine(
                  'Description', entry['description']?.toString() ?? '—'),
            if ((entry['notes'] ?? '').toString().isNotEmpty)
              _infoLine('Notes', entry['notes']?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat('dd MMM yyyy').format(dt);
  }

  String _transactionLabel(String? type) {
    switch (type) {
      case 'kirim':
        return 'Kirim';
      case 'bongkar_kosong':
        return 'Bongkar Kosong';
      case 'pembelian':
        return 'Pembelian';
      case 'penyesuaian':
        return 'Penyesuaian';
      default:
        return (type ?? '—').replaceAll('_', ' ');
    }
  }

  Color _transactionColor(String? type) {
    switch (type) {
      case 'kirim':
        return Colors.blue;
      case 'bongkar_kosong':
        return Colors.orange;
      case 'pembelian':
        return Colors.purple;
      case 'penyesuaian':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummaryContent() {
    if (_isSummaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_summaryError != null) {
      return AppErrorState(message: _summaryError!, onRetry: _loadSummary);
    }
    if (_summaryRows.isEmpty) {
      return const AppEmptyState(
        message: 'No summary data available',
        subtitle: 'Running balances per branch and cylinder type',
        icon: Icons.table_chart,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
            columns: [
              const DataColumn(label: Text('Branch')),
              for (final type in _summaryTypes) DataColumn(label: Text(type)),
            ],
            rows: [
              for (final row in _summaryRows)
                DataRow(
                  cells: [
                    DataCell(Text(row is Map
                        ? row['branch_name']?.toString() ?? '—'
                        : '—')),
                    for (final type in _summaryTypes)
                      DataCell(Text(
                        row is Map
                            ? '${(row['balances'] as Map?)?[type] ?? 0}'
                            : '0',
                      )),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── New entry (POST /cylinder-circulations) ──────────────────

  Future<void> _showNewEntryDialog() async {
    if (_user.branchId == null) {
      _showSnack(
        'Your account has no branch assigned — cannot create an entry.',
        error: true,
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final soController = TextEditingController();
    final containerController = TextEditingController();
    final handledByController = TextEditingController();
    final descriptionController = TextEditingController();
    var transactionDate = DateTime.now();
    var transactionType = _transactionTypes.first;
    var cylinderType = _cylinderTypes.first;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Circulation Entry'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Branch: ${_user.branchName ?? _user.branchId}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: transactionType,
                    decoration:
                        const InputDecoration(labelText: 'Transaction type'),
                    items: [
                      for (final t in _transactionTypes)
                        DropdownMenuItem(
                            value: t, child: Text(_transactionLabel(t))),
                    ],
                    onChanged: (v) => setDialogState(
                        () => transactionType = v ?? _transactionTypes.first),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: cylinderType,
                    decoration:
                        const InputDecoration(labelText: 'Cylinder type'),
                    items: [
                      for (final t in _cylinderTypes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setDialogState(
                        () => cylinderType = v ?? _cylinderTypes.first),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(transactionDate)}',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: transactionDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => transactionDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantity (min 1)'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                        ? 'Quantity must be at least 1'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: soController,
                    decoration: const InputDecoration(
                        labelText: 'SO number (optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: containerController,
                    decoration: const InputDecoration(
                        labelText: 'Container no. (optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: handledByController,
                    decoration: const InputDecoration(
                        labelText: 'Handled by (optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, <String, dynamic>{
                  'branch_id': _user.branchId,
                  'transaction_date':
                      DateFormat('yyyy-MM-dd').format(transactionDate),
                  'transaction_type': transactionType,
                  'cylinder_type': cylinderType,
                  'quantity': int.parse(quantityController.text.trim()),
                  if (soController.text.trim().isNotEmpty)
                    'so_number': soController.text.trim(),
                  if (containerController.text.trim().isNotEmpty)
                    'container_no': containerController.text.trim(),
                  if (handledByController.text.trim().isNotEmpty)
                    'handled_by': handledByController.text.trim(),
                  if (descriptionController.text.trim().isNotEmpty)
                    'description': descriptionController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    soController.dispose();
    containerController.dispose();
    handledByController.dispose();
    descriptionController.dispose();

    if (payload != null) await _submitEntry(payload);
  }

  Future<void> _submitEntry(Map<String, dynamic> payload) async {
    try {
      final response = await ref
          .read(apiServiceProvider)
          .post(ApiConstants.cylinderCirculations, data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(_messageFrom(response.data) ?? 'Circulation entry created');
        _loadEntries();
        if (_user.isHqRole) _loadSummary();
      } else {
        _showSnack(_messageFrom(response.data) ?? 'Failed to create entry',
            error: true);
      }
    } on DioException catch (e) {
      _showSnack(_messageFrom(e.response?.data) ?? 'Failed to create entry',
          error: true);
    } catch (_) {
      _showSnack('Failed to create entry', error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  String? _messageFrom(Object? data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}