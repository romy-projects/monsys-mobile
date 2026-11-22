class ApiConstants {
  /// Base URL. Override at build/run time when testing against the local
  /// panelx backend, e.g.:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  ///
  /// (10.0.2.2 = host machine from the Android emulator; iOS simulator and
  /// desktop builds can use http://localhost:8000/api/v1 directly.)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sumenergy.id/api/v1',
  );

  static const Duration timeout = Duration(seconds: 30);

  // Auth (Sanctum, 90-day tokens)
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/me';
  static const String authRefresh = '/auth/refresh';
  static const String authPassword = '/auth/password'; // T18-01: change password

  // Dashboard
  static const String dashboardMain = '/dashboard/main';
  static const String dashboardBranch = '/dashboard/branch';

  // Stock
  static const String stock = '/stock';
  static const String stockMutations = '/stock-mutations';
  static const String stockCloses = '/stock/closes';
  static const String stockClose = '/stock/close';
  static const String stockIsClosed = '/stock/is-closed';

  // Orders — SO / LO / PO live under delivery_orders on the API and are
  // distinguished by `document_type`. Delivery Orders (DO) were retired:
  // POST /delivery-orders no longer exists, so the app has no DO endpoints.
  static const String salesOrders = '/sales-orders'; // SO: Main Branch -> Pertamina
  static const String loadingOrders = '/loading-orders'; // LO: loading instruction to Transportir
  static const String purchaseOrders = '/purchase-orders'; // PO: Branches -> Main Branch

  // Sales & Costs
  static const String sales = '/sales';
  static const String costs = '/costs';

  // Finance — Invoices & Payables (Utang Transportir)
  static const String invoices = '/invoices';
  static const String payables = '/payables';
  static const String actionPay = '/pay';
  static const String actionIssue = '/issue';

  // Tabung Sirkulasi (cylinder circulation ledger)
  static const String cylinderCirculations = '/cylinder-circulations';
  static const String cylinderCirculationsSummary = '/cylinder-circulations/summary';

  // Master Data
  static const String branches = '/branches';
  static const String expeditions = '/expeditions';
  static const String transportirs = '/transportirs';
  static const String prices = '/prices';
  static const String pricesCurrent = '/prices/current';
  static const String customers = '/customers';
  static const String vehicles = '/vehicles';
  static const String users = '/users';

  // Device (FCM push token registration)
  static const String deviceToken = '/device/token';
  static const String deviceRevoke = '/device/revoke';

  // Reports
  static const String reportsProfitLoss = '/reports/profit-loss';
  static const String reportsStockSummary = '/reports/stock-summary';
  static const String reportsShipmentTracking = '/reports/shipment-tracking';
  static const String reportsSalesPeriod = '/reports/sales-period';
  static const String reportsBranchRanking = '/reports/branch-ranking';
  static const String reportsStockAudit = '/reports/stock-audit';
  static const String reportsHpp = '/reports/hpp';
  static const String reportsReceivablesAging = '/reports/receivables-aging';

  // Scanner (POST /scan — Claude Vision OCR)
  static const String scan = '/scan';

  // Import / Export — Data
  static String importTemplate(String table) => '/import/templates/$table';
  static String import(String table) => '/import/$table';
}
