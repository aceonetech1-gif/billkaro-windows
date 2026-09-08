import 'package:billkaro/app/modules/Promotions/controllers/promotions_list_controller.dart';
import 'package:billkaro/app/modules/Promotions/promotions_routes.dart';
import 'package:billkaro/app/modules/Promotions/widgets/promotion_card.dart';
import 'package:billkaro/config/config.dart';

class PromotionsListScreen extends StatelessWidget {
  PromotionsListScreen({super.key});

  final controller = Get.put(PromotionsListController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        title: const Text('Offers & Promotions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: PromotionsRoutes.toOfferType,
        icon: const Icon(Icons.add),
        label: const Text('Create offer'),
      ),
      body: Obx(() {
        if (controller.promotions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No offers yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BOGO, discounts, free items & more',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: PromotionsRoutes.toOfferType,
                  icon: const Icon(Icons.add),
                  label: const Text('Create offer'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.promotions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final promo = controller.promotions[index];
            return PromotionCard(
              promotion: promo,
              subtitle: controller.offerSummary(promo),
              onEdit: () => PromotionsRoutes.toOfferForm(existing: promo),
              onDelete: () => controller.deletePromotion(promo),
              onToggle: () => controller.toggleActive(promo),
            );
          },
        );
      }),
    );
  }
}

/// Backward-compatible alias for existing route registrations.
class PromotionsScreen extends PromotionsListScreen {
  PromotionsScreen({super.key});
}
