import 'package:billkaro/app/utils/promotion_types.dart';
import 'package:billkaro/config/config.dart';

class OfferTypeTile extends StatelessWidget {
  const OfferTypeTile({super.key, required this.type, required this.onTap});

  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.backGroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColor.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  PromotionTypes.icon(type),
                  color: AppColor.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PromotionTypes.label(type).capitalize ??
                          PromotionTypes.label(type),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColor.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PromotionTypes.example(type).capitalize ??
                          PromotionTypes.example(type),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
