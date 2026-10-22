import 'package:billkaro/app/Database/app_database.dart';
import 'package:billkaro/app/modules/Home/home_screen_controller.dart';
import 'package:billkaro/app/services/Modals/analytics/outlet_analytics_models.dart';
import 'package:billkaro/app/services/Modals/orders/orders/orderResponse.dart';
import 'package:billkaro/config/config.dart';
import 'package:get/get.dart';

class PaymentController extends BaseController {
  // Payment statistics
  final RxDouble todayTotalPayments = 0.0.obs;
  final RxDouble yesterdayTotalPayments = 0.0.obs;
  final RxDouble thisWeekTotalPayments = 0.0.obs;
  final RxDouble thisMonthTotalPayments = 0.0.obs;

  // Payment breakdown by method
  final RxMap<String, double> paymentMethodBreakdown = <String, double>{}.obs;
  final RxMap<String, double> todayPaymentBreakdown = <String, double>{}.obs;

  // Loading state
  final RxBool isLoading = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadPaymentStatistics();
  }

  /// Load payment statistics from orders
  Future<void> loadPaymentStatistics() async {
    try {
      isLoading.value = true;
      final outletId = appPref.selectedOutlet?.id;
      if (outletId == null) {
        isLoading.value = false;
        return;
      }

      // Prefer already-hydrated home closed orders to avoid a second full DB scan.
      List<OrderModel> paidOrders;
      if (Get.isRegistered<HomeScreenController>()) {
        final homeOrders = Get.find<HomeScreenController>().allOrders;
        if (homeOrders.isNotEmpty) {
          paidOrders = homeOrders.toList(growable: false);
        } else {
          paidOrders = await _loadClosedOrders(outletId);
        }
      } else {
        paidOrders = await _loadClosedOrders(outletId);
      }

      _applyPaidOrders(paidOrders);
    } catch (e) {
      debugPrint('❌ Error loading payment statistics: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<OrderModel>> _loadClosedOrders(String outletId) async {
    final db = AppDatabase();
    final bundle = await db.getOrdersForHomeDashboard(outletId: outletId);
    return bundle.closed;
  }

  /// Reuse orders already loaded by Home (no extra SQLite round-trip).
  Future<void> refreshFromOrders(List<OrderModel> closedOrders) async {
    try {
      isLoading.value = true;
      _applyPaidOrders(closedOrders);
    } finally {
      isLoading.value = false;
    }
  }

  /// Apply server-side payment summary from dashboard analytics API.
  void applyFromAnalytics(DashboardPayments payments) {
    todayTotalPayments.value = payments.todayTotal;
    yesterdayTotalPayments.value = payments.yesterdayTotal;
    thisWeekTotalPayments.value = payments.weekTotal;
    thisMonthTotalPayments.value = payments.monthTotal;
    todayPaymentBreakdown
      ..clear()
      ..addAll(payments.todayByMethod);
    if (paymentMethodBreakdown.isEmpty) {
      paymentMethodBreakdown
        ..clear()
        ..addAll(payments.todayByMethod);
    }
  }

  void _applyPaidOrders(List<OrderModel> paidOrders) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final breakdown = <String, double>{};
    final todayBreakdown = <String, double>{};

    double todayTotal = 0.0;
    double yesterdayTotal = 0.0;
    double weekTotal = 0.0;
    double monthTotal = 0.0;

    for (final order in paidOrders) {
      try {
        final orderDate = DateTime.parse(order.createdAt);
        final orderAmount = order.totalAmount;

        if (order.splitPayments != null && order.splitPayments!.isNotEmpty) {
          for (final splitPayment in order.splitPayments!) {
            final method = splitPayment.paymentMethod.toLowerCase();
            final amount = splitPayment.amount;

            breakdown[method] = (breakdown[method] ?? 0.0) + amount;

            if (orderDate.isAfter(todayStart) && orderDate.isBefore(todayEnd)) {
              todayBreakdown[method] =
                  (todayBreakdown[method] ?? 0.0) + amount;
              todayTotal += amount;
            } else if (orderDate.isAfter(yesterdayStart) &&
                orderDate.isBefore(todayStart)) {
              yesterdayTotal += amount;
            }
            if (orderDate.isAfter(weekStart)) {
              weekTotal += amount;
            }
            if (orderDate.isAfter(monthStart)) {
              monthTotal += amount;
            }
          }
        } else if (order.paymentReceivedIn != null &&
            order.paymentReceivedIn!.isNotEmpty) {
          final method = order.paymentReceivedIn!.toLowerCase();

          breakdown[method] = (breakdown[method] ?? 0.0) + orderAmount;

          if (orderDate.isAfter(todayStart) && orderDate.isBefore(todayEnd)) {
            todayBreakdown[method] =
                (todayBreakdown[method] ?? 0.0) + orderAmount;
            todayTotal += orderAmount;
          } else if (orderDate.isAfter(yesterdayStart) &&
              orderDate.isBefore(todayStart)) {
            yesterdayTotal += orderAmount;
          }
          if (orderDate.isAfter(weekStart)) {
            weekTotal += orderAmount;
          }
          if (orderDate.isAfter(monthStart)) {
            monthTotal += orderAmount;
          }
        } else {
          breakdown['cash'] = (breakdown['cash'] ?? 0.0) + orderAmount;

          if (orderDate.isAfter(todayStart) && orderDate.isBefore(todayEnd)) {
            todayBreakdown['cash'] =
                (todayBreakdown['cash'] ?? 0.0) + orderAmount;
            todayTotal += orderAmount;
          } else if (orderDate.isAfter(yesterdayStart) &&
              orderDate.isBefore(todayStart)) {
            yesterdayTotal += orderAmount;
          }
          if (orderDate.isAfter(weekStart)) {
            weekTotal += orderAmount;
          }
          if (orderDate.isAfter(monthStart)) {
            monthTotal += orderAmount;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error processing order ${order.id}: $e');
      }
    }

    todayTotalPayments.value = todayTotal;
    yesterdayTotalPayments.value = yesterdayTotal;
    thisWeekTotalPayments.value = weekTotal;
    thisMonthTotalPayments.value = monthTotal;
    paymentMethodBreakdown.value = breakdown;
    todayPaymentBreakdown.value = todayBreakdown;
  }

  /// Get formatted payment method name
  String getPaymentMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'credit':
        return 'Credit';
      case 'debit':
        return 'Debit Card';
      default:
        return method.toUpperCase();
    }
  }

  /// Get payment method icon
  IconData getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'online':
      case 'upi':
        return Icons.account_balance_wallet;
      case 'card':
      case 'credit':
      case 'debit':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  /// Get payment method color
  Color getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppColor.success;
      case 'online':
      case 'upi':
        return AppColor.info;
      case 'card':
      case 'credit':
      case 'debit':
        return AppColor.purple;
      default:
        return AppColor.textSecondary;
    }
  }

  /// Refresh payment statistics
  @override
  Future<void> refresh() async {
    await loadPaymentStatistics();
  }
}
