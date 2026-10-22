import 'package:billkaro/app/services/Modals/inventory/inventory_models.dart';

/// Shared Home + Dashboard analytics payloads from
/// `GET /outlets/:outletId/analytics/home|dashboard`.

class HomeAnalyticsData {
  final String outletId;
  final String? asOf;
  final List<OccupiedTableRow> occupiedTables;
  final List<AnalyticsTopItem> topSellingItems;
  final List<LowStockMaterial> lowStockItems;

  HomeAnalyticsData({
    required this.outletId,
    this.asOf,
    required this.occupiedTables,
    required this.topSellingItems,
    required this.lowStockItems,
  });

  factory HomeAnalyticsData.fromJson(Map<String, dynamic> json) {
    final lowStock = json['lowStock'];
    final materials = lowStock is Map
        ? (lowStock['rawMaterials'] as List<dynamic>? ?? const [])
        : const [];

    return HomeAnalyticsData(
      outletId: json['outletId']?.toString() ?? '',
      asOf: json['asOf']?.toString(),
      occupiedTables: (json['occupiedTables'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => OccupiedTableRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topSellingItems: (json['topSellingItems'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => AnalyticsTopItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      lowStockItems: materials
          .whereType<Map>()
          .map(
            (e) => LowStockMaterial.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class OccupiedTableRow {
  final String id;
  final String billNumber;
  final String tableNumber;
  final double totalAmount;
  final String status;
  final String orderFrom;
  final String customerName;
  final String createdAt;
  final String updatedAt;

  OccupiedTableRow({
    required this.id,
    required this.billNumber,
    required this.tableNumber,
    required this.totalAmount,
    required this.status,
    required this.orderFrom,
    required this.customerName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OccupiedTableRow.fromJson(Map<String, dynamic> json) {
    return OccupiedTableRow(
      id: json['id']?.toString() ?? '',
      billNumber: json['billNumber']?.toString() ?? '',
      tableNumber: json['tableNumber']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      orderFrom: json['orderFrom']?.toString() ?? 'Dine In',
      customerName: json['customerName']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class AnalyticsTopItem {
  final String itemId;
  final String name;
  final String category;
  final String imageUrl;
  final int quantity;
  final double amount;

  AnalyticsTopItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.quantity,
    required this.amount,
  });

  factory AnalyticsTopItem.fromJson(Map<String, dynamic> json) {
    return AnalyticsTopItem(
      itemId: json['itemId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DashboardAnalyticsData {
  final String outletId;
  final String? asOf;
  final DashboardKpis kpis;
  final List<AnalyticsCategorySales> salesByCategoryToday;
  final DashboardChart chart;
  final DashboardPayments payments;

  DashboardAnalyticsData({
    required this.outletId,
    this.asOf,
    required this.kpis,
    required this.salesByCategoryToday,
    required this.chart,
    required this.payments,
  });

  factory DashboardAnalyticsData.fromJson(Map<String, dynamic> json) {
    return DashboardAnalyticsData(
      outletId: json['outletId']?.toString() ?? '',
      asOf: json['asOf']?.toString(),
      kpis: DashboardKpis.fromJson(
        Map<String, dynamic>.from(json['kpis'] as Map? ?? const {}),
      ),
      salesByCategoryToday:
          (json['salesByCategoryToday'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (e) => AnalyticsCategorySales.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
      chart: DashboardChart.fromJson(
        Map<String, dynamic>.from(json['chart'] as Map? ?? const {}),
      ),
      payments: DashboardPayments.fromJson(
        Map<String, dynamic>.from(json['payments'] as Map? ?? const {}),
      ),
    );
  }
}

class DashboardKpis {
  final double todaySales;
  final double yesterdaySales;
  final int todayOrders;
  final int yesterdayOrders;

  DashboardKpis({
    required this.todaySales,
    required this.yesterdaySales,
    required this.todayOrders,
    required this.yesterdayOrders,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    return DashboardKpis(
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0,
      yesterdaySales: (json['yesterdaySales'] as num?)?.toDouble() ?? 0,
      todayOrders: (json['todayOrders'] as num?)?.toInt() ?? 0,
      yesterdayOrders: (json['yesterdayOrders'] as num?)?.toInt() ?? 0,
    );
  }
}

class AnalyticsCategorySales {
  final String category;
  final int quantity;
  final double amount;

  AnalyticsCategorySales({
    required this.category,
    required this.quantity,
    required this.amount,
  });

  factory AnalyticsCategorySales.fromJson(Map<String, dynamic> json) {
    return AnalyticsCategorySales(
      category: json['category']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DashboardChart {
  final String period;
  final List<String> labels;
  final List<double> values;

  DashboardChart({
    required this.period,
    required this.labels,
    required this.values,
  });

  factory DashboardChart.fromJson(Map<String, dynamic> json) {
    return DashboardChart(
      period: json['period']?.toString() ?? 'weekly',
      labels: (json['labels'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      values: (json['values'] as List<dynamic>? ?? const [])
          .map((e) => (e as num?)?.toDouble() ?? 0.0)
          .toList(),
    );
  }
}

class DashboardPayments {
  final double todayTotal;
  final double yesterdayTotal;
  final double weekTotal;
  final double monthTotal;
  final Map<String, double> todayByMethod;

  DashboardPayments({
    required this.todayTotal,
    required this.yesterdayTotal,
    required this.weekTotal,
    required this.monthTotal,
    required this.todayByMethod,
  });

  factory DashboardPayments.fromJson(Map<String, dynamic> json) {
    final raw = json['todayByMethod'];
    final map = <String, double>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        map[k.toString()] = (v as num?)?.toDouble() ?? 0;
      });
    }
    return DashboardPayments(
      todayTotal: (json['todayTotal'] as num?)?.toDouble() ?? 0,
      yesterdayTotal: (json['yesterdayTotal'] as num?)?.toDouble() ?? 0,
      weekTotal: (json['weekTotal'] as num?)?.toDouble() ?? 0,
      monthTotal: (json['monthTotal'] as num?)?.toDouble() ?? 0,
      todayByMethod: map,
    );
  }
}
