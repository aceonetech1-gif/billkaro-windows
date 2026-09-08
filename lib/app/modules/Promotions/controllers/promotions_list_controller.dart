import 'package:billkaro/app/modules/AddOrder/add_order_controller.dart';
import 'package:billkaro/app/services/Modals/promotions/promotion_response.dart';
import 'package:billkaro/app/services/sync/promotion_sync.dart';
import 'package:billkaro/app/utils/promotion_engine.dart';
import 'package:billkaro/config/config.dart';

class PromotionsListController extends BaseController {
  final promotions = <PromotionData>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadPromotions();
  }

  Future<void> loadPromotions() async {
    final outletId = appPref.selectedOutlet?.id;
    if (outletId == null) return;

    try {
      final rules = await PromotionSync(apiClient: apiClient).load(
        outletId: outletId,
        activeOnly: false,
      );
      promotions.assignAll(rules);
      if (Get.isRegistered<AddOrderController>()) {
        await Get.find<AddOrderController>().reloadPromotions();
      }
    } catch (e) {
      showError(description: 'Failed to load offers');
    }
  }

  Future<void> deletePromotion(PromotionData promotion) async {
    final outletId = appPref.selectedOutlet?.id;
    if (outletId == null) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete offer?'),
        content: Text('Remove "${promotion.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await callApi(apiClient.deletePromotion(outletId, promotion.id));
    await loadPromotions();
    showSuccess(description: 'Offer deleted');
  }

  Future<void> toggleActive(PromotionData promotion) async {
    final outletId = appPref.selectedOutlet?.id;
    final userId = appPref.ordersApiUserId;
    if (outletId == null || userId == null) return;

    await callApi(
      apiClient.updatePromotion(outletId, promotion.id, {
        'userId': userId,
        'active': !promotion.active,
      }),
    );
    await loadPromotions();
  }

  String offerSummary(PromotionData promotion) {
    return PromotionEngine.summary(promotion);
  }
}
