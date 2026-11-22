import 'package:flutter/material.dart';

/// Shared vocabulary for the three active order document types (SO/LO/PO) and
/// their workflow statuses, matching the panelx delivery_orders schema.
///
/// Delivery Orders (DO) were retired in panelx — `POST /delivery-orders` no
/// longer exists and the app no longer offers a DO tab. Existing DO rows are
/// still readable through the API for reporting only.
class OrderDocument {
  const OrderDocument._();

  static const docTypeLabels = <String, String>{
    'so': 'Sales Order',
    'lo': 'Loading Order',
    'po': 'Purchase Order',
  };

  static String docTypeLabel(String? documentType) =>
      docTypeLabels[documentType] ?? 'Order';

  static Color docTypeColor(String? documentType) {
    switch (documentType) {
      case 'so':
        return Colors.purple;
      case 'lo':
        return Colors.orange;
      case 'po':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  /// Human label for a workflow status
  /// ('pending_approval' -> 'Pending Approval').
  static String statusLabel(String? status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'pending_approval':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'in_transit':
        return 'In Transit';
      case 'on_transportir':
        return 'On Transportir';
      case 'loaded':
        return 'Loaded';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return (status ?? 'Unknown').replaceAll('_', ' ');
    }
  }

  /// Filter values shown in the status chip row.
  static const statusFilters = <String>[
    'all',
    'draft',
    'pending_approval',
    'approved',
    'in_transit',
    'on_transportir',
    'loaded',
    'delivered',
    'cancelled',
  ];

  static String shipmentStatusLabel(String? shipmentStatus) {
    switch (shipmentStatus) {
      case 'at_transportir_warehouse':
        return 'At Transportir Warehouse';
      case 'delivered_to_destination':
        return 'Delivered to Destination';
      default:
        return (shipmentStatus ?? '').replaceAll('_', ' ');
    }
  }

  static String counterpartyLabel(String? type, String? name) {
    if (name == null || name.isEmpty) return '—';
    switch (type) {
      case 'pertamina':
        return 'Pertamina · $name';
      case 'branch':
        return 'Branch · $name';
      default:
        return name;
    }
  }
}
