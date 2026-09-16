import 'package:billkaro/app/modules/Home/home_screen_controller.dart';
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
        title: Text(
          loc.section_low_stock_alerts,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 420,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _LowStockRow(item: items[index]),
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
  // Reuse home cache when available so the dialog opens instantly.
  if (Get.isRegistered<HomeScreenController>()) {
    final cached = Get.find<HomeScreenController>().lowStockItems;
    if (cached.isNotEmpty) return List<LowStockMaterial>.from(cached);
  }

  final client =
      apiClient ??
      (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null);
  if (client == null) return const [];

  try {
    final res = await callApi(
      client.getInventoryLowStock(outletId),
      showLoader: false,
    );
    if (res is! Map || res['data'] is! Map) return const [];
    final data = Map<String, dynamic>.from(res['data'] as Map);
    final materials = data['rawMaterials'] as List<dynamic>? ?? const [];
    return materials
        .map(
          (e) => LowStockMaterial.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }
}
