import 'package:billkaro/app/services/Modals/addItem/item_response.dart';
import 'package:billkaro/config/config.dart';

InputDecoration offerFieldDecoration(
  String label, {
  String? helper,
  String? prefix,
}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    prefixText: prefix,
    filled: true,
    fillColor: AppColor.backGroundColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );
}

class OfferSectionCard extends StatelessWidget {
  const OfferSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColor.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColor.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class OfferEmptyItemsState extends StatelessWidget {
  const OfferEmptyItemsState({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class OfferItemThumb extends StatelessWidget {
  const OfferItemThumb({super.key, required this.imageUrl});

  final String imageUrl;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final url = resolvedMediaUrl(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const _OfferItemThumbPlaceholder()
            : CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const _OfferItemThumbPlaceholder(),
              ),
      ),
    );
  }
}

class _OfferItemThumbPlaceholder extends StatelessWidget {
  const _OfferItemThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.backGroundColor,
      child: Icon(
        Icons.restaurant_outlined,
        size: 20,
        color: Colors.grey.shade400,
      ),
    );
  }
}

class OfferItemDetails extends StatelessWidget {
  const OfferItemDetails({
    super.key,
    required this.item,
    required this.highlighted,
  });

  final ItemData item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final category = item.category.trim();
    final hasCategory = category.isNotEmpty && category.toLowerCase() != 'none';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.itemName.capitalize ?? item.itemName,
            style: TextStyle(
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
              color: AppColor.textPrimary,
            ),
          ),
          if (hasCategory)
            Text(
              category.capitalize ?? category,
              style: const TextStyle(
                fontSize: 12,
                color: AppColor.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class OfferItemRadioTile extends StatelessWidget {
  const OfferItemRadioTile({
    super.key,
    required this.item,
    required this.groupValue,
    required this.value,
    required this.onChanged,
  });

  final ItemData item;
  final String? groupValue;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;

    return Material(
      color: selected
          ? AppColor.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: groupValue,
                activeColor: AppColor.primary,
                onChanged: onChanged,
              ),
              OfferItemThumb(imageUrl: item.itemImage),
              const SizedBox(width: 10),
              OfferItemDetails(item: item, highlighted: selected),
              Text(
                '₹${item.salePrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColor.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfferItemBuyFreeTile extends StatelessWidget {
  const OfferItemBuyFreeTile({
    super.key,
    required this.item,
    required this.isBuyProduct,
    required this.isFreeChoice,
    required this.onBuyTap,
    required this.onFreeChanged,
  });

  final ItemData item;
  final bool isBuyProduct;
  final bool isFreeChoice;
  final VoidCallback onBuyTap;
  final ValueChanged<bool> onFreeChanged;

  @override
  Widget build(BuildContext context) {
    final highlighted = isBuyProduct || isFreeChoice;

    return Material(
      color: highlighted
          ? AppColor.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Buy product',
              onPressed: onBuyTap,
              icon: Icon(
                isBuyProduct ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                color: isBuyProduct ? AppColor.primary : AppColor.textSecondary,
                size: 20,
              ),
            ),
            Checkbox(
              value: isFreeChoice,
              activeColor: AppColor.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (value) => onFreeChanged(value == true),
            ),
            OfferItemThumb(imageUrl: item.itemImage),
            const SizedBox(width: 10),
            OfferItemDetails(item: item, highlighted: highlighted),
            Text(
              '₹${item.salePrice.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColor.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfferItemCheckboxTile extends StatelessWidget {
  const OfferItemCheckboxTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final ItemData item;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColor.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                activeColor: AppColor.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (value) => onChanged(value == true),
              ),
              OfferItemThumb(imageUrl: item.itemImage),
              const SizedBox(width: 10),
              OfferItemDetails(item: item, highlighted: selected),
              Text(
                '₹${item.salePrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColor.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
