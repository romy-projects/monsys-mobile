/// Parsed dashboard payloads for the two panelx endpoints.
///
/// `GET /dashboard/main` (HQ: owner_pusat / super_admin / regional_leader):
/// ```json
/// {"stats": {"today_revenue": 0, "month_revenue": 0, "pending_do_count": 0,
///            "active_do_count": 0, "branch_count": 0, "low_stock_count": 0},
///  "low_stock_alerts": [{"branch_id":1,"branch_name":"..","cylinder_type":"3kg","qty_full":4}],
///  "sales_chart": [{"date":"2026-11-01","revenue":0,"qty":0}],
///  "stock_summary": [{"cylinder_type":"3kg","total_full":0,"total_empty":0}]}
/// ```
///
/// `GET /dashboard/branch` (owner_cabang / staff_gudang):
/// ```json
/// {"branch_id": 12, "stats": {"today_revenue":0, "month_revenue":0,
///   "month_costs":0, "month_profit":0, "incoming_do_count":0},
///  "stock": [{"cylinder_type":"3kg","qty_full":0,"qty_empty":0,
///             "qty_damaged":0,"alert_level":"ok|warning|danger"}],
///  "incoming_dos": [{"id":1,"do_number":"PO-..","cylinder_type":"3kg",
///                    "quantity":0,"status":"approved","eta":null,"expedition":null}],
///  "sales_chart": [{"date":"2026-11-01","revenue":0,"qty":0}]}
/// ```
///
/// `DeliveryOrder` counter keys keep their legacy `*_do_*` names on the API
/// (the DO flow itself is retired); the model renames them to order terms.
class DashboardSummary {
  const DashboardSummary({
    required this.isBranchScoped,
    this.todayRevenue = 0,
    this.monthRevenue = 0,
    this.monthCosts = 0,
    this.monthProfit = 0,
    this.pendingOrderCount = 0,
    this.activeShipmentCount = 0,
    this.branchCount = 0,
    this.lowStockCount = 0,
    this.incomingOrderCount = 0,
    this.lowStockAlerts = const [],
    this.branchStock = const [],
    this.stockSummary = const [],
    this.salesChart = const [],
    this.incomingOrders = const [],
  });

  factory DashboardSummary.fromMain(Map<String, dynamic> json) {
    final payload = _unwrap(json);
    final stats = _map(payload['stats']);

    return DashboardSummary(
      isBranchScoped: false,
      todayRevenue: _num(stats['today_revenue']),
      monthRevenue: _num(stats['month_revenue']),
      pendingOrderCount: _int(stats['pending_do_count']),
      activeShipmentCount: _int(stats['active_do_count']),
      branchCount: _int(stats['branch_count']),
      lowStockCount: _int(stats['low_stock_count']),
      lowStockAlerts: [
        for (final row in _list(payload['low_stock_alerts']))
          LowStockAlert(
            branchName: _str(row['branch_name']) ?? 'Unknown branch',
            cylinderType: _str(row['cylinder_type']) ?? '—',
            qtyFull: _int(row['qty_full']),
          ),
      ],
      stockSummary: [
        for (final row in _list(payload['stock_summary']))
          StockSummaryRow(
            cylinderType: _str(row['cylinder_type']) ?? '—',
            totalFull: _int(row['total_full']),
            totalEmpty: _int(row['total_empty']),
          ),
      ],
      salesChart: _salesChart(payload['sales_chart']),
    );
  }

  factory DashboardSummary.fromBranch(Map<String, dynamic> json) {
    final payload = _unwrap(json);
    final stats = _map(payload['stats']);

    return DashboardSummary(
      isBranchScoped: true,
      todayRevenue: _num(stats['today_revenue']),
      monthRevenue: _num(stats['month_revenue']),
      monthCosts: _num(stats['month_costs']),
      monthProfit: _num(stats['month_profit']),
      incomingOrderCount: _int(stats['incoming_do_count']),
      branchStock: [
        for (final row in _list(payload['stock']))
          BranchStockRow(
            cylinderType: _str(row['cylinder_type']) ?? '—',
            qtyFull: _int(row['qty_full']),
            qtyEmpty: _int(row['qty_empty']),
            qtyDamaged: _int(row['qty_damaged']),
            alertLevel: StockAlertLevel.parse(_str(row['alert_level'])),
          ),
      ],
      incomingOrders: [
        for (final row in _list(payload['incoming_dos']))
          IncomingOrder(
            id: _int(row['id']),
            number: _str(row['do_number']) ?? '—',
            cylinderType: _str(row['cylinder_type']) ?? '—',
            quantity: _int(row['quantity']),
            status: _str(row['status']) ?? '—',
            eta: _str(row['eta']),
            expedition: _str(row['expedition']),
          ),
      ],
      salesChart: _salesChart(payload['sales_chart']),
    );
  }

  /// Branch payloads are branch-scoped, HQ payloads are global.
  final bool isBranchScoped;
  final double todayRevenue;
  final double monthRevenue;
  final double monthCosts;
  final double monthProfit;
  final int pendingOrderCount;
  final int activeShipmentCount;
  final int branchCount;
  final int lowStockCount;
  final int incomingOrderCount;
  final List<LowStockAlert> lowStockAlerts;
  final List<BranchStockRow> branchStock;
  final List<StockSummaryRow> stockSummary;
  final List<DashboardSalesPoint> salesChart;
  final List<IncomingOrder> incomingOrders;

  bool get hasData =>
      todayRevenue > 0 ||
      monthRevenue > 0 ||
      branchStock.isNotEmpty ||
      stockSummary.isNotEmpty ||
      salesChart.isNotEmpty;

  List<BranchStockRow> get lowStockItems =>
      branchStock.where((row) => row.alertLevel != StockAlertLevel.ok).toList();

  int get effectiveLowStockCount =>
      isBranchScoped ? lowStockItems.length : lowStockCount;

  bool get hasLowStock => effectiveLowStockCount > 0;

  /// Chart window: 14 days for HQ, 7 days for a branch.
  int get chartDays => isBranchScoped ? 7 : 14;

  double get salesChartMax {
    var max = 0.0;
    for (final point in salesChart) {
      if (point.revenue > max) max = point.revenue;
    }
    return max;
  }

  double get salesChartTotal =>
      salesChart.fold<double>(0, (sum, point) => sum + point.revenue);

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final nested = json['data'];
    if (nested is Map && !json.containsKey('stats')) {
      return Map<String, dynamic>.from(nested);
    }
    return json;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  static List<DashboardSalesPoint> _salesChart(dynamic value) => [
        for (final row in _list(value))
          DashboardSalesPoint(
            date: DateTime.tryParse(_str(row['date']) ?? ''),
            revenue: _num(row['revenue']),
            qty: _int(row['qty']),
          ),
      ];

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _str(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class LowStockAlert {
  const LowStockAlert({
    required this.branchName,
    required this.cylinderType,
    required this.qtyFull,
  });

  final String branchName;
  final String cylinderType;
  final int qtyFull;
}

class StockSummaryRow {
  const StockSummaryRow({
    required this.cylinderType,
    required this.totalFull,
    required this.totalEmpty,
  });

  final String cylinderType;
  final int totalFull;
  final int totalEmpty;
}

class BranchStockRow {
  const BranchStockRow({
    required this.cylinderType,
    required this.qtyFull,
    required this.qtyEmpty,
    required this.qtyDamaged,
    required this.alertLevel,
  });

  final String cylinderType;
  final int qtyFull;
  final int qtyEmpty;
  final int qtyDamaged;
  final StockAlertLevel alertLevel;

  bool get isLow => alertLevel != StockAlertLevel.ok;
}

class DashboardSalesPoint {
  const DashboardSalesPoint({
    required this.date,
    required this.revenue,
    required this.qty,
  });

  final DateTime? date;
  final double revenue;
  final int qty;
}

class IncomingOrder {
  const IncomingOrder({
    required this.id,
    required this.number,
    required this.cylinderType,
    required this.quantity,
    required this.status,
    this.eta,
    this.expedition,
  });

  final int id;
  final String number;
  final String cylinderType;
  final int quantity;
  final String status;
  final String? eta;
  final String? expedition;
}

enum StockAlertLevel {
  ok,
  warning,
  danger;

  static StockAlertLevel parse(String? raw) {
    switch (raw) {
      case 'danger':
        return StockAlertLevel.danger;
      case 'warning':
        return StockAlertLevel.warning;
      default:
        return StockAlertLevel.ok;
    }
  }
}
