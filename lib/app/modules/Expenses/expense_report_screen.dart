import 'package:billkaro/app/Widgets/app_date_picker.dart';
import 'package:billkaro/app/modules/Expenses/add_expense_dialog.dart';
import 'package:billkaro/app/modules/Expenses/expenses_controller.dart';
import 'package:billkaro/app/services/Modals/expenses/expense_model.dart';
import 'package:billkaro/config/config.dart';
import 'package:billkaro/utils/staff_access.dart';
import 'package:intl/intl.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  late final ExpensesController controller;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    controller = Get.put(ExpensesController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<ExpensesController>()) {
      Get.delete<ExpensesController>();
    }
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: controller.startDate.value ?? DateTime(now.year, now.month, 1),
        end: controller.endDate.value ?? now,
      ),
    );
    if (range == null) return;
    controller.setDateRange(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Expense Report',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadExpenses,
          ),
        ],
      ),
      floatingActionButton: StaffAccess.canCreateExpenses
          ? FloatingActionButton.extended(
              onPressed: () => showAddExpenseDialog(controller),
              backgroundColor: AppColor.primary,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.expenses.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = controller.expenses;
              final summary = controller.summary.value;

              return RefreshIndicator(
                onRefresh: controller.loadExpenses,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    if (summary != null) _summaryCard(summary),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            'No expenses found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ...list.map(_expenseCard),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final start = controller.startDate.value;
              final end = controller.endDate.value;
              final label = (start != null && end != null)
                  ? '${_dateFmt.format(start)} - ${_dateFmt.format(end)}'
                  : 'Select dates';
              return OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(label, overflow: TextOverflow.ellipsis),
              );
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() {
              return DropdownButtonFormField<String?>(
                value: controller.categoryFilter.value,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                hint: const Text('All categories'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ...kExpenseCategories.map(
                    (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                  ),
                ],
                onChanged: controller.setCategory,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ExpenseReportSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric('Total', _currency.format(summary.totalAmount)),
          ),
          Expanded(child: _metric('Entries', '${summary.totalCount}')),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _expenseCard(ExpenseData e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8912E).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFFE8912E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${e.category} · ${e.paymentMethod.toUpperCase()} · ${e.expenseDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (e.notes != null && e.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    e.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currency.format(e.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                ),
              ),
              if (StaffAccess.canCreateExpenses)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, color: Colors.grey[500]),
                  onPressed: () async {
                    final ok = await controller.deleteExpense(e.id);
                    if (ok) {
                      showSuccess(description: 'Expense deleted');
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
