class DaySessionSummary {
  final int totalOrders;
  final double totalSales;
  final double totalTax;
  final double totalDiscount;
  final Map<String, double> paymentBreakdown;
  final double totalExpenses;
  final double cashExpenses;
  final int expenseCount;

  DaySessionSummary({
    required this.totalOrders,
    required this.totalSales,
    required this.totalTax,
    required this.totalDiscount,
    required this.paymentBreakdown,
    this.totalExpenses = 0,
    this.cashExpenses = 0,
    this.expenseCount = 0,
  });

  factory DaySessionSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DaySessionSummary(
        totalOrders: 0,
        totalSales: 0,
        totalTax: 0,
        totalDiscount: 0,
        paymentBreakdown: {},
      );
    }
    final rawBreakdown = json['paymentBreakdown'];
    final breakdown = <String, double>{};
    if (rawBreakdown is Map) {
      rawBreakdown.forEach((key, value) {
        breakdown[key.toString()] = (value as num?)?.toDouble() ?? 0;
      });
    }
    return DaySessionSummary(
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0,
      totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0,
      paymentBreakdown: breakdown,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
      cashExpenses: (json['cashExpenses'] as num?)?.toDouble() ?? 0,
      expenseCount: (json['expenseCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OutletDaySession {
  final String id;
  final String outletId;
  final String businessDate;
  final String status;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? openedByName;
  final String? closedByName;
  final String? openedByUserId;
  final String? closedByUserId;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? cashVariance;
  final String? openingNotes;
  final String? closingNotes;
  final DaySessionSummary? summary;

  OutletDaySession({
    required this.id,
    required this.outletId,
    required this.businessDate,
    required this.status,
    this.openedAt,
    this.closedAt,
    this.openedByName,
    this.closedByName,
    this.openedByUserId,
    this.closedByUserId,
    this.openingCash = 0,
    this.closingCash,
    this.expectedCash,
    this.cashVariance,
    this.openingNotes,
    this.closingNotes,
    this.summary,
  });

  bool get isOpen => status.toLowerCase() == 'open';

  factory OutletDaySession.fromJson(Map<String, dynamic> json) {
    return OutletDaySession(
      id: json['id']?.toString() ?? '',
      outletId: json['outletId']?.toString() ?? '',
      businessDate: json['businessDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'closed',
      openedAt: json['openedAt'] != null
          ? DateTime.tryParse(json['openedAt'].toString())
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'].toString())
          : null,
      openedByName: json['openedByName']?.toString(),
      closedByName: json['closedByName']?.toString(),
      openedByUserId: json['openedByUserId']?.toString(),
      closedByUserId: json['closedByUserId']?.toString(),
      openingCash: (json['openingCash'] as num?)?.toDouble() ?? 0,
      closingCash: (json['closingCash'] as num?)?.toDouble(),
      expectedCash: (json['expectedCash'] as num?)?.toDouble(),
      cashVariance: (json['cashVariance'] as num?)?.toDouble(),
      openingNotes: json['openingNotes']?.toString(),
      closingNotes: json['closingNotes']?.toString(),
      summary: json['summary'] is Map<String, dynamic>
          ? DaySessionSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LiveDaySummary {
  final OutletDaySession session;
  final DaySessionSummary summary;
  final double expectedCash;
  final double cashSales;
  final double totalExpenses;
  final double cashExpenses;

  LiveDaySummary({
    required this.session,
    required this.summary,
    required this.expectedCash,
    required this.cashSales,
    this.totalExpenses = 0,
    this.cashExpenses = 0,
  });

  factory LiveDaySummary.fromJson(Map<String, dynamic> json) {
    final summary = DaySessionSummary.fromJson(
      json['summary'] as Map<String, dynamic>?,
    );
    return LiveDaySummary(
      session: OutletDaySession.fromJson(
        (json['session'] as Map<String, dynamic>?) ?? {},
      ),
      summary: summary,
      expectedCash: (json['expectedCash'] as num?)?.toDouble() ?? 0,
      cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0,
      totalExpenses:
          (json['totalExpenses'] as num?)?.toDouble() ?? summary.totalExpenses,
      cashExpenses:
          (json['cashExpenses'] as num?)?.toDouble() ?? summary.cashExpenses,
    );
  }
}
