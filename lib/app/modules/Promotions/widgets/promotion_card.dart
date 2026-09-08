import 'package:billkaro/app/services/Modals/promotions/promotion_response.dart';
import 'package:billkaro/app/utils/promotion_types.dart';
import 'package:billkaro/config/config.dart';

class PromotionCard extends StatelessWidget {
  const PromotionCard({
    super.key,
    required this.promotion,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final PromotionData promotion;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColor.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColor.secondaryPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: AppColor.secondaryPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    promotion.name.capitalize ?? promotion.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColor.textPrimary,
                    ),
                  ),
                ),
                Switch(value: promotion.active, onChanged: (_) => onToggle()),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColor.secondaryPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                PromotionTypes.label(promotion.type).capitalize ??
                    PromotionTypes.label(promotion.type),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColor.secondaryPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle.capitalize ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColor.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: AppColor.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
