import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'in-transit':
      case 'in_transit':
        return Colors.purple;
      case 'received':
      case 'delivered':
      case 'loaded':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      case 'on_transportir':
        return Colors.deepPurple;
      case 'pending_approval':
        return Colors.orange;
      case 'draft':
        return Colors.grey;
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'in':
        return Colors.green;
      case 'out':
        return Colors.red;
      case 'transfer':
        return Colors.orange;
      case 'adjustment':
        return Colors.blue;
      case 'debit':
        return Colors.green;
      case 'kredit':
        return Colors.red;
      case 'issued':
        return Colors.blue;
      case 'partial':
        return Colors.orange;
      case 'paid':
        return Colors.teal;
      case 'overdue':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}