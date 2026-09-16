import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:billkaro/app/modules/Reports/DayEndReport/day_end_report_controller.dart';
import 'package:billkaro/app/services/Modals/store_session/store_session_model.dart';
import 'package:billkaro/config/config.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class DayEndReportScreen extends StatefulWidget {
  const DayEndReportScreen({super.key});

  @override
  State<DayEndReportScreen> createState() => _DayEndReportScreenState();
}

class _DayEndReportScreenState extends State<DayEndReportScreen> {
  late final DayEndReportController controller;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _timeFmt = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    controller = Get.put(DayEndReportController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<DayEndReportController>()) {
      Get.delete<DayEndReportController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Day End Report',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.load,
          ),
          TextButton(
            onPressed: () =>
                Modular.to.pushNamed(HomeMainRoutes.storeSessionHistory),
            child: const Text('History'),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.liveSummary.value == null &&
            controller.sessions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.isStoreOpen.value &&
                  controller.liveSummary.value != null)
                _liveCard(controller.liveSummary.value!)
              else
                _closedBanner(),
              const SizedBox(height: 20),
              const Text(
                'Recent days',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (controller.sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text(
                      'No day sessions yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                ...controller.sessions.map(_sessionCard),
            ],
          ),
        );
      }),
    );
  }

  Widget _closedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Store is currently closed. Open the store to see live day-end summary.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveCard(LiveDaySummary data) {
    final s = data.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColor.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.session.businessDate,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat('Orders', '${s.totalOrders}')),
              Expanded(
                child: _stat('Sales', _currency.format(s.totalSales)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Expenses',
                  _currency.format(s.totalExpenses),
                ),
              ),
              Expanded(
                child: _stat(
                  'Expected cash',
                  _currency.format(data.expectedCash),
                ),
              ),
            ],
          ),
          if (s.paymentBreakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...s.paymentBreakdown.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      _currency.format(e.value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _sessionCard(OutletDaySession session) {
    final s = session.summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.businessDate,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: session.isOpen
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  session.isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: session.isOpen
                        ? const Color(0xFF10B981)
                        : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (session.openedAt != null)
            Text(
              'Opened ${_timeFmt.format(session.openedAt!.toLocal())}'
              '${session.closedAt != null ? ' · Closed ${_timeFmt.format(session.closedAt!.toLocal())}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (s != null) ...[
            const SizedBox(height: 8),
            Text(
              'Orders ${s.totalOrders} · Sales ${_currency.format(s.totalSales)} · Expenses ${_currency.format(s.totalExpenses)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
          if (session.expectedCash != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expected cash ${_currency.format(session.expectedCash!)}'
              '${session.closingCash != null ? ' · Closing ${_currency.format(session.closingCash!)}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }
}
