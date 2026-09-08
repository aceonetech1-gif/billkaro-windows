import 'package:billkaro/app/modules/Promotions/promotions_routes.dart';
import 'package:billkaro/app/modules/Promotions/widgets/offer_type_tile.dart';
import 'package:billkaro/app/utils/promotion_types.dart';
import 'package:billkaro/config/config.dart';

class OfferTypeScreen extends StatelessWidget {
  const OfferTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        title: const Text('Choose offer type'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: PromotionTypes.all.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final type = PromotionTypes.all[index];
          return OfferTypeTile(
            type: type,
            onTap: () => PromotionsRoutes.toOfferForm(type: type),
          );
        },
      ),
    );
  }
}
