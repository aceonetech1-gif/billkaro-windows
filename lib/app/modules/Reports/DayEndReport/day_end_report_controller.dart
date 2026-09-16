import 'package:billkaro/app/services/Modals/store_session/store_session_model.dart';
import 'package:billkaro/config/config.dart';
import 'package:intl/intl.dart';

class DayEndReportController extends BaseController {
  final isLoading = false.obs;
  final liveSummary = Rxn<LiveDaySummary>();
  final sessions = <OutletDaySession>[].obs;
  final isStoreOpen = false.obs;

  String? get _outletId => appPref.selectedOutlet?.id;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return;

    isLoading.value = true;
    try {
      final current = await callApi(
        apiClient.getCurrentDaySession(outletId),
        showLoader: false,
      );

      final open = current != null &&
          current['status'] == 'success' &&
          current['isOpen'] == true;
      isStoreOpen.value = open;

      if (open) {
        final summaryRes = await callApi(
          apiClient.getDaySessionSummary(outletId),
          showLoader: false,
        );
        if (summaryRes != null &&
            summaryRes['status'] == 'success' &&
            summaryRes['data'] is Map) {
          liveSummary.value = LiveDaySummary.fromJson(
            Map<String, dynamic>.from(summaryRes['data'] as Map),
          );
        }
      } else {
        liveSummary.value = null;
      }

      final now = DateTime.now();
      final start = DateFormat('yyyy-MM-dd').format(
        now.subtract(const Duration(days: 14)),
      );
      final end = DateFormat('yyyy-MM-dd').format(now);

      final history = await callApi(
        apiClient.getDaySessionHistory(outletId, start, end),
        showLoader: false,
      );
      if (history != null &&
          history['status'] == 'success' &&
          history['data'] is List) {
        sessions.assignAll(
          (history['data'] as List)
              .whereType<Map>()
              .map(
                (e) => OutletDaySession.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }
}
