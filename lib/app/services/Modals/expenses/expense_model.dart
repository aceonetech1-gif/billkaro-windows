class ExpenseData {
  final String id;
  final String outletId;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final String paymentMethod;
  final String expenseDate;
  final String? notes;
  final String? createdByName;
  final DateTime? createdAt;

  ExpenseData({
    required this.id,
    required this.outletId,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.expenseDate,
    this.notes,
    this.createdByName,
    this.createdAt,
  });

  factory ExpenseData.fromJson(Map<String, dynamic> json) {
    return ExpenseData(
      id: json['id']?.toString() ?? '',
      outletId: json['outletId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category']?.toString() ?? 'Other',
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      expenseDate: json['expenseDate']?.toString() ?? '',
      notes: json['notes']?.toString(),
      createdByName: json['createdByName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class ExpenseReportSummary {
  final int totalCount;
  final double totalAmount;
  final Map<String, double> byCategory;
  final Map<String, double> byPaymentMethod;

  ExpenseReportSummary({
    required this.totalCount,
    required this.totalAmount,
    required this.byCategory,
    required this.byPaymentMethod,
  });

  factory ExpenseReportSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ExpenseReportSummary(
        totalCount: 0,
        totalAmount: 0,
        byCategory: {},
        byPaymentMethod: {},
      );
    }

    Map<String, double> parseMap(dynamic raw) {
      final out = <String, double>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          out[key.toString()] = (value as num?)?.toDouble() ?? 0;
        });
      }
      return out;
    }

    return ExpenseReportSummary(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      byCategory: parseMap(json['byCategory']),
      byPaymentMethod: parseMap(json['byPaymentMethod']),
    );
  }
}

const List<String> kExpenseCategories = [
  'Rent',
  'Utilities',
  'Salaries',
  'Supplies',
  'Transport',
  'Maintenance',
  'Petty Cash',
  'Other',
];

const List<String> kExpensePaymentMethods = [
  'cash',
  'upi',
  'card',
  'bank',
  'other',
];
