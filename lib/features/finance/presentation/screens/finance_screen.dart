import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Finance hub — Invoices (Piutang) and Payables (Utang Transportir).
///
/// RBAC per panelx: invoices are branch-scoped for everyone; payables are
/// visible only to roles with can_view_finance (owner_pusat,
/// regional_leader, owner_cabang) — the Payables tab is hidden otherwise.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  static const _invoiceStatuses = [
    'all',
    'draft',
    'issued',
    'partial',
    'paid',
    'overdue',
    'cancelled',
  ];

  TabController? _tabController;
  bool _canViewFinance = false;
  int _selectedTab = 0;

  List<dynamic> _invoices = [];
  bool _isInvoicesLoading = true;
  String? _invoicesError;
  String _invoiceStatusFilter = 'all';

  List<dynamic> _payables = [];
  bool _isPayablesLoading = false;
  String? _payablesError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userJson = await ref.read(authStorageProvider).getUser();
    if (!mounted) return;
    setState(() {
      _canViewFinance =
          UserAccount.fromJsonString(userJson ?? '').canViewFinance;
      _tabController = TabController(
        length: _canViewFinance ? 2 : 1,
        vsync: this,
      )..addListener(_handleTabChanged);
    });
    _loadInvoices();
  }

  void _handleTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    setState(() => _selectedTab = controller.index);
    if (controller.index == 1 && _payables.isEmpty) {
      _loadPayables();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────

  Future<void> _loadInvoices() async {
    setState(() {
      _isInvoicesLoading = true;
      _invoicesError = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_invoiceStatusFilter != 'all') {
        params['status'] = _invoiceStatusFilter;
      }
      final response = await ref
          .read(apiServiceProvider)
          .get(ApiConstants.invoices, queryParameters: params);
      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data['data'] : null;
        if (!mounted) return;
        setState(() {
          _invoices = data is List ? data : [];
          _isInvoicesLoading = false;
        });
      } else {
        _failInvoices('Failed to load invoices');
      }
    } on DioException catch (e) {
      _failInvoices(_messageFrom(e.response?.data) ?? 'Failed to load invoices');
    } catch (_) {
      _failInvoices('Failed to load invoices');
    }
  }

  void _failInvoices(String message) {
    if (!mounted) return;
    setState(() {
      _invoicesError = message;
      _isInvoicesLoading = false;
      _invoices = const [];
    });
  }

  Future<void> _loadPayables() async {
    setState(() {
      _isPayablesLoading = true;
      _payablesError = null;
    });
    try {
      final response =
          await ref.read(apiServiceProvider).get(ApiConstants.payables);
      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data['data'] : null;
        if (!mounted) return;
        setState(() {
          _payables = data is List ? data : [];
          _isPayablesLoading = false;
        });
      } else {
        _failPayables('Failed to load payables');
      }
    } on DioException catch (e) {
      _failPayables(_messageFrom(e.response?.data) ?? 'Failed to load payables');
    } catch (_) {
      _failPayables('Failed to load payables');
    }
  }

  void _failPayables(String message) {
    if (!mounted) return;
    setState(() {
      _payablesError = message;
      _isPayablesLoading = false;
      _payables = const [];
    });
  }

  void _refreshCurrent() {
    if (_selectedTab == 0) {
      _loadInvoices();
    } else {
      _loadPayables();
    }
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final controller = _tabController;
    final isInvoiceTab = _selectedTab == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCurrent,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AppSegmentedTabs(
                  labels: [
                    'Invoices',
                    if (_canViewFinance) 'Payables',
                  ],
                  selectedIndex: controller.index,
                  onChanged: (index) => controller.animateTo(index),
                ),
                if (isInvoiceTab) _buildInvoiceFilterBar(),
                Expanded(
                  child: isInvoiceTab
                      ? _buildInvoicesContent()
                      : _buildPayablesContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildInvoiceFilterBar() {
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
            for (final status in _invoiceStatuses)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status == 'all' ? 'All' : _statusLabel(status)),
                  selected: _invoiceStatusFilter == status,
                  onSelected: (_) {
                    setState(() => _invoiceStatusFilter = status);
                    _loadInvoices();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_approval':
        return 'Pending Approval';
      case 'bongkar_kosong':
        return 'Bongkar Kosong';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Widget _buildInvoicesContent() {
    if (_isInvoicesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_invoicesError != null) {
      return AppErrorState(message: _invoicesError!, onRetry: _loadInvoices);
    }
    if (_invoices.isEmpty) {
      return const AppEmptyState(
        message: 'No invoices found',
        subtitle: 'Try a different status filter',
        icon: Icons.receipt_long,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invoices.length,
        itemBuilder: (context, index) =>
            _buildInvoiceCard(_invoices[index]),
      ),
    );
  }

  Widget _buildInvoiceCard(Map invoice) {
    final status = invoice['status']?.toString() ?? '';
    final balance = (num.tryParse('${invoice['balance'] ?? 0}') ?? 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showInvoiceActions(invoice),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice['invoice_number']?.toString() ?? 'N/A',
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
                '${invoice['customer']?.toString() ?? '—'}  •  '
                '${invoice['branch']?.toString() ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${invoice['cylinder_type'] ?? '—'} × ${invoice['quantity'] ?? 0}'
                '  •  Due ${_fmtDate(invoice['due_date']?.toString())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total ${_fmtMoney(num.tryParse('${invoice['total_amount'] ?? 0}'))}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    balance > 0 ? 'Balance ${_fmtMoney(balance)}' : 'Settled',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: balance > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Invoice actions ──────────────────────────────────────────

  void _showInvoiceActions(Map invoice) {
    final status = invoice['status']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invoice ${invoice['invoice_number'] ?? ''}',
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
                'Issued ${_fmtDate(invoice['issue_date']?.toString())}  •  '
                'Paid ${_fmtMoney(num.tryParse('${invoice['paid_amount'] ?? 0}'))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if ((invoice['notes'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  invoice['notes'].toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              if (status == 'draft')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _issueInvoice(invoice);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Issue Invoice'),
                  ),
                ),
              if (status == 'issued' ||
                  status == 'partial' ||
                  status == 'overdue')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showInvoicePayDialog(invoice);
                    },
                    icon: const Icon(Icons.payments),
                    label: const Text('Record Payment'),
                  ),
                ),
              if (status == 'paid' || status == 'cancelled' || status == 'draft')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      status == 'draft'
                          ? 'Issue this invoice to enable payments.'
                          : 'No actions available for this status.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _issueInvoice(Map invoice) async {
    try {
      final response = await ref.read(apiServiceProvider).post(
            '${ApiConstants.invoices}/${invoice['id']}${ApiConstants.actionIssue}',
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(_messageFrom(response.data) ?? 'Invoice issued.');
        _loadInvoices();
      } else {
        _showSnack(_messageFrom(response.data) ?? 'Failed to issue invoice',
            error: true);
      }
    } on DioException catch (e) {
      _showSnack(_messageFrom(e.response?.data) ?? 'Failed to issue invoice',
          error: true);
    } catch (_) {
      _showSnack('Failed to issue invoice', error: true);
    }
  }

  Future<void> _showInvoicePayDialog(Map invoice) async {
    final balance = num.tryParse('${invoice['balance'] ?? 0}') ?? 0;
    final amountController = TextEditingController(
        text: balance > 0 ? balance.toStringAsFixed(0) : '');
    final amount = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invoice ${invoice['invoice_number'] ?? ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Amount (Rp), min 1'),
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
              final value = num.tryParse(amountController.text.trim());
              if (value == null || value < 1) return;
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null) return;

    try {
      final response = await ref.read(apiServiceProvider).post(
            '${ApiConstants.invoices}/${invoice['id']}${ApiConstants.actionPay}',
            data: {'amount': amount},
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(_messageFrom(response.data) ?? 'Payment recorded.');
        _loadInvoices();
      } else {
        _showSnack(_messageFrom(response.data) ?? 'Failed to record payment',
            error: true);
      }
    } on DioException catch (e) {
      _showSnack(_messageFrom(e.response?.data) ?? 'Failed to record payment',
          error: true);
    } catch (_) {
      _showSnack('Failed to record payment', error: true);
    }
  }

  // ── Payables (Utang Transportir) ─────────────────────────────

  Widget _buildPayablesContent() {
    if (_isPayablesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_payablesError != null) {
      return AppErrorState(message: _payablesError!, onRetry: _loadPayables);
    }
    if (_payables.isEmpty) {
      return const AppEmptyState(
        message: 'No payables found',
        subtitle: 'Transportir debts will appear here',
        icon: Icons.account_balance_wallet,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPayables,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payables.length,
        itemBuilder: (context, index) => _buildPayableCard(_payables[index]),
      ),
    );
  }

  Widget _buildPayableCard(Map payable) {
    final status = payable['status']?.toString() ?? '';
    final transportir = payable['transportir'];
    final transportirName = transportir is Map
        ? transportir['name']?.toString() ?? '—'
        : 'Transportir #${payable['transportir_id'] ?? '—'}';
    final deliveryOrder = payable['delivery_order'];
    final balance = num.tryParse('${payable['balance'] ?? 0}') ?? 0;
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
                    transportirName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            if ((payable['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                payable['description'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Amount ${_fmtMoney(num.tryParse('${payable['amount'] ?? 0}'))}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  balance > 0 ? 'Balance ${_fmtMoney(balance)}' : 'Settled',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: balance > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Paid ${_fmtMoney(num.tryParse('${payable['paid_amount'] ?? 0}'))}'
              '  •  Due ${_fmtDate(payable['due_date']?.toString())}'
              '${deliveryOrder is Map ? '  •  ${deliveryOrder['do_number'] ?? ''}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showPayablePayDialog(payable),
                  icon: const Icon(Icons.payments),
                  label: const Text('Record Payment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPayablePayDialog(Map payable) async {
    final balance = num.tryParse('${payable['balance'] ?? 0}') ?? 0;
    final amountController = TextEditingController(
        text: balance > 0 ? balance.toStringAsFixed(0) : '0');
    final paidAmount = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the total paid amount for this payable.'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Paid amount (Rp)'),
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
              final value = num.tryParse(amountController.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (paidAmount == null) return;

    try {
      final response = await ref.read(apiServiceProvider).post(
            '${ApiConstants.payables}/${payable['id']}${ApiConstants.actionPay}',
            data: {'paid_amount': paidAmount},
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(_messageFrom(response.data) ?? 'Payment recorded.');
        _loadPayables();
      } else {
        _showSnack(_messageFrom(response.data) ?? 'Failed to record payment',
            error: true);
      }
    } on DioException catch (e) {
      _showSnack(_messageFrom(e.response?.data) ?? 'Failed to record payment',
          error: true);
    } catch (_) {
      _showSnack('Failed to record payment', error: true);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────

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
}