import 'package:billkaro/app/services/Modals/expenses/expense_model.dart';
import 'package:billkaro/config/config.dart';
import 'package:billkaro/utils/staff_access.dart';
import 'package:intl/intl.dart';

class ExpensesController extends BaseController {
  final expenses = <ExpenseData>[].obs;
  final summary = Rxn<ExpenseReportSummary>();
  final isLoading = false.obs;

  final startDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>();
  final categoryFilter = RxnString();

  String? get _outletId => appPref.selectedOutlet?.id;

  String get _userId => appPref.user?.id ?? appPref.user?.userId ?? '';

  String get _createdByName {
    final user = appPref.user;
    final name = (user?.firstName ?? user?.userName ?? '').trim();
    if (name.isNotEmpty) return name;
    return (user?.email ?? '').trim();
  }

  @override
  void onReady() {
    super.onReady();
    final now = DateTime.now();
    startDate.value = DateTime(now.year, now.month, 1);
    endDate.value = DateTime(now.year, now.month, now.day);
    loadExpenses();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> loadExpenses() async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return;
    if (!StaffAccess.canViewExpenses) return;

    isLoading.value = true;
    try {
      final response = await callApi(
        apiClient.getExpenses(
          outletId,
          startDate.value != null ? _fmt(startDate.value!) : null,
          endDate.value != null ? _fmt(endDate.value!) : null,
          categoryFilter.value,
        ),
        showLoader: false,
      );

      if (response != null && response['status'] == 'success') {
        final list = response['data'];
        if (list is List) {
          expenses.assignAll(
            list
                .whereType<Map>()
                .map((e) => ExpenseData.fromJson(Map<String, dynamic>.from(e)))
                .toList(),
          );
        } else {
          expenses.clear();
        }
        summary.value = ExpenseReportSummary.fromJson(
          response['summary'] is Map
              ? Map<String, dynamic>.from(response['summary'] as Map)
              : null,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createExpense({
    required String title,
    required double amount,
    required String category,
    required String paymentMethod,
    required DateTime expenseDate,
    String? notes,
  }) async {
    if (!StaffAccess.ensure(StaffAccess.canCreateExpenses)) return false;
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return false;

    final body = <String, dynamic>{
      'userId': _userId,
      'title': title.trim(),
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'expenseDate': _fmt(expenseDate),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (_createdByName.isNotEmpty) 'createdByName': _createdByName,
    };

    final response = await callApi(
      apiClient.createExpense(outletId, body),
      showLoader: true,
    );

    if (response != null && response['status'] == 'success') {
      await loadExpenses();
      return true;
    }
    return false;
  }

  Future<bool> deleteExpense(String id) async {
    if (!StaffAccess.ensure(StaffAccess.canCreateExpenses)) return false;
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return false;

    final response = await callApi(
      apiClient.deleteExpense(outletId, id),
      showLoader: true,
    );

    if (response != null && response['status'] == 'success') {
      await loadExpenses();
      return true;
    }
    return false;
  }

  void setDateRange(DateTime? start, DateTime? end) {
    startDate.value = start;
    endDate.value = end;
    loadExpenses();
  }

  void setCategory(String? category) {
    categoryFilter.value = category;
    loadExpenses();
  }
}
