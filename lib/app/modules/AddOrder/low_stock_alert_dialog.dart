import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:billkaro/app/services/Modals/inventory/inventory_models.dart';
import 'package:billkaro/config/config.dart';
import 'package:billkaro/utils/staff_access.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Shows a one-shot dialog listing low-stock materials when opening Add Order.
Future<void> maybeShowLowStockAlert({
  required AppPref appPref,
  ApiClient? apiClient,
}) async {
  if (!StaffAccess.canViewInventory) return;

  final outletId = appPref.selectedOutlet?.id;
  if (outletId == null || outletId.isEmpty) return;

  final context = Get.context;
  if (context == null || !context.mounted) return;

  final items = await _fetchLowStockItems(
    outletId: outletId,
    apiClient: apiClient,
  );
  if (items.isEmpty) return;
  if (!context.mounted) return;

  final loc = AppLocalizations.of(context)!;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.section_low_stock_alerts,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = items[index];
                return _LowStockRow(item: item);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(loc.got_it),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Modular.to.pushNamed(HomeMainRoutes.inventory);
            },
            child: Text(loc.view_all),
          ),
        ],
      );
    },
  );
}

Future<List<LowStockMaterial>> _fetchLowStockItems({
  required String outletId,
  ApiClient? apiClient,
}) async {
  final client =
      apiClient ??
      (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null);
  if (client == null) return const [];

  try {
    final res = await callApi(
      client.getInventoryDashboard(outletId),
      showLoader: false,
    );
    if (res is! Map || res['data'] == null) return const [];
    final dashboard = InventoryDashboardData.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
    return dashboard.lowStockMaterials;
  } catch (_) {
    return const [];
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final LowStockMaterial item;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(item.currentStock)} / ${_fmt(item.minStock)} ${item.unit}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
