import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';

/// Bottom sheet for creating a Purchase Order (branch -> Main Branch).
///
/// Matches panelx `PurchaseOrderController@store`: the client sends business
/// data only (`order_date`, `cylinder_type`, `quantity_ordered`, plus optional
/// transportir/container/ETA/notes). The server fills `document_type = po`,
/// origin = main branch, destination = the requesting user's branch,
/// counterparty and the `do_number` inside the insert transaction.
///
/// Note: panelx requires the branch's stock close for today to be submitted
/// before a PO can be created — a 422 with that message is surfaced inline.
class CreatePoSheet extends ConsumerStatefulWidget {
  const CreatePoSheet({super.key});

  /// Opens the sheet; returns the created order map (with the server-assigned
  /// `do_number`) or null when cancelled/failed.
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: CreatePoSheet(),
      ),
    );
  }

  @override
  ConsumerState<CreatePoSheet> createState() => _CreatePoSheetState();
}

class _CreatePoSheetState extends ConsumerState<CreatePoSheet> {
  static const _cylinderTypes = ['3kg', '5.5kg', '12kg', '50kg'];

  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _containerController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _orderDate = DateTime.now();
  DateTime? _eta;
  String _cylinderType = _cylinderTypes.first;
  int? _transportirId;
  List<Map<String, dynamic>> _transportirs = [];
  UserAccount _user = const UserAccount();
  bool _loadingMasterData = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _containerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    try {
      _user = await ref.read(currentUserProvider.future);
    } catch (_) {}
    try {
      final response =
          await ref.read(apiServiceProvider).get(ApiConstants.transportirs);
      final payload = response.data;
      final outer = payload is Map ? payload['data'] : null;
      final list =
          outer is List ? outer : (outer is Map ? outer['data'] : null);
      if (list is List) {
        _transportirs = list
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false);
      }
    } catch (_) {
      // The transportir picker is optional — degrade silently.
    }
    if (!mounted) return;
    setState(() => _loadingMasterData = false);
  }

  int? _asId(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  Future<void> _pickDate({required String which}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: which == 'eta' ? (_eta ?? _orderDate) : _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (which == 'eta') {
        _eta = picked;
      } else {
        _orderDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final body = <String, dynamic>{
        'order_date': DateFormat('yyyy-MM-dd').format(_orderDate),
        'cylinder_type': _cylinderType,
        'quantity_ordered': int.parse(_quantityController.text.trim()),
        if (_transportirId != null) 'transportir_id': _transportirId,
        if (_containerController.text.trim().isNotEmpty)
          'container_number': _containerController.text.trim(),
        if (_eta != null) 'eta': DateFormat('yyyy-MM-dd').format(_eta!),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      };

      final response = await ref.read(apiServiceProvider).post(
            ApiConstants.purchaseOrders,
            data: body,
          );
      if (!mounted) return;
      final data = response.data;
      if (response.statusCode == 201 && data is Map) {
        final order = data['data'];
        Navigator.pop(
          context,
          order is Map ? Map<String, dynamic>.from(order) : null,
        );
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage =
            'Unexpected response from the server (HTTP ${response.statusCode}).';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : null;
      setState(() {
        _submitting = false;
        _errorMessage =
            message ?? 'Failed to create the purchase order. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage =
            'Failed to create the purchase order. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final destination = _user.branchName;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'New Purchase Order (PO)',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                destination == null
                    ? 'The PO number is assigned automatically after saving.'
                    : 'Requested by $destination from the main branch. '
                        'The PO number is assigned automatically after saving.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _cylinderType,
                decoration: const InputDecoration(
                  labelText: 'Cylinder type',
                  prefixIcon: Icon(Icons.propane_tank),
                ),
                items: [
                  for (final type in _cylinderTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) =>
                    setState(() => _cylinderType = value ?? _cylinderType),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity requested',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                validator: (value) {
                  final qty = int.tryParse(value?.trim() ?? '');
                  if (qty == null || qty < 1) {
                    return 'Enter a quantity of at least 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Order date',
                value: _orderDate,
                onTap: () => _pickDate(which: 'order'),
              ),
              const SizedBox(height: 12),
              _transportirDropdown(),
              const SizedBox(height: 12),
              _DateField(
                label: _eta == null
                    ? 'ETA (optional)'
                    : 'ETA: ${DateFormat('dd MMM yyyy').format(_eta!)}',
                value: _eta,
                canClear: _eta != null,
                onClear: () => setState(() => _eta = null),
                onTap: () => _pickDate(which: 'eta'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _containerController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Container number (optional)',
                  prefixIcon: Icon(Icons.inventory),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_submitting ? 'Saving…' : 'Create PO'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transportirDropdown() {
    if (_loadingMasterData) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Transportir (optional)',
          prefixIcon: Icon(Icons.local_shipping),
        ),
        child: SizedBox(
          height: 16,
          child: Center(child: LinearProgressIndicator()),
        ),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _transportirId,
      decoration: const InputDecoration(
        labelText: 'Transportir (optional)',
        prefixIcon: Icon(Icons.local_shipping),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None')),
        for (final t in _transportirs)
          DropdownMenuItem(
            value: _asId(t['id']),
            child: Text((t['name'] ?? t['code'] ?? '#${t['id']}').toString()),
          ),
      ],
      onChanged: (value) => setState(() => _transportirId = value),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.canClear = false,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool canClear;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: canClear
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          value == null ? '' : DateFormat('dd MMM yyyy').format(value!),
        ),
      ),
    );
  }
}
