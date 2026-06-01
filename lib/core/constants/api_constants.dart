class ApiConstants {
  static const String baseUrl = 'http://localhost:8000/api/v1'; // Default for iOS Simulator
  
  static const Duration timeout = Duration(seconds: 30);
  
  // Endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/me';
  
  static const String dashboardMain = '/dashboard/main';
  static const String dashboardBranch = '/dashboard/branch';
  
  static const String stock = '/stock';
  static const String stockMutations = '/stock-mutations';
  static const String stockCloses = '/stock/closes';
  static const String stockClose = '/stock/close';
  
  static const String deliveryOrders = '/delivery-orders';
  static const String sales = '/sales';
  static const String costs = '/costs';
  
  static const String reportsProfitLoss = '/reports/profit-loss';
  static const String reportsStockSummary = '/reports/stock-summary';
  static const String reportsShipmentTracking = '/reports/shipment-tracking';
  static const String reportsSalesPeriod = '/reports/sales-period';
  static const String reportsBranchRanking = '/reports/branch-ranking';
  static const String reportsStockAudit = '/reports/stock-audit';
  static const String reportsHpp = '/reports/hpp';
  static const String reportsReceivablesAging = '/reports/receivables-aging';
  
  static const String scan = '/scan';
}
