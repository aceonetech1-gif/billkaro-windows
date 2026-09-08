import 'package:billkaro/app/Widgets/app_dropdowns.dart';
import 'package:billkaro/app/modules/Promotions/controllers/offer_form_controller.dart';
import 'package:billkaro/app/modules/Promotions/promotions_routes.dart';
import 'package:billkaro/app/modules/Promotions/widgets/offer_form_widgets.dart';
import 'package:billkaro/app/services/Modals/promotions/promotion_response.dart';
import 'package:billkaro/app/utils/promotion_types.dart';
import 'package:billkaro/config/config.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class OfferFormScreen extends StatelessWidget {
  OfferFormScreen({super.key});

  late final OfferFormController controller = _initController();

  OfferFormController _initController() {
    if (Get.isRegistered<OfferFormController>()) {
      Get.delete<OfferFormController>();
    }
    final args = PromotionsRoutes.readArgs();
    final existing = args?[PromotionsRoutes.argExisting] as PromotionData?;
    final type = args?[PromotionsRoutes.argType] as String?;
    return Get.put(OfferFormController(existing: existing, initialType: type));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        title: Text(
          controller.isEditing ? 'Edit offer' : 'Create offer',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(
                    () => OfferSectionCard(
                      title: 'Offer details',
                      child: Column(
                        children: [
                          AppDropdownFormField2<String>(
                            value: controller.selectedType.value,
                            decoration: offerFieldDecoration('Offer type'),
                            items: PromotionTypes.all
                                .map(
                                  (type) => DropdownItem(
                                    value: type,
                                    child: Text(
                                      PromotionTypes.label(type).capitalize ??
                                          PromotionTypes.label(type),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: controller.onTypeChanged,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller.nameController,
                            decoration: offerFieldDecoration(
                              'Offer name',
                              helper: PromotionTypes.example(
                                controller.selectedType.value,
                              ),
                            ),
                          ),
                          if (controller.needsMinAmount) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.amountController,
                              keyboardType: TextInputType.number,
                              decoration: offerFieldDecoration(
                                controller.minAmountLabel,
                                prefix: '₹ ',
                              ),
                            ),
                          ],
                          if (controller.needsBuyQty) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.buyQtyController,
                              keyboardType: TextInputType.number,
                              decoration: offerFieldDecoration('Buy quantity'),
                            ),
                          ],
                          if (controller.needsGetQty) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.getQtyController,
                              keyboardType: TextInputType.number,
                              decoration: offerFieldDecoration('Free quantity'),
                            ),
                            Obx(
                              () => SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Same product (BOGO)'),
                                subtitle: const Text(
                                  'Free item is the same as the purchased product',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColor.textSecondary,
                                  ),
                                ),
                                value: controller.sameAsTrigger.value,
                                onChanged: controller.onSameAsTriggerChanged,
                              ),
                            ),
                          ],
                          if (controller.needsFlatAmount &&
                              controller.selectedType.value !=
                                  PromotionTypes.timeBased) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.flatController,
                              keyboardType: TextInputType.number,
                              decoration: offerFieldDecoration(
                                'Discount amount (₹)',
                                prefix: '₹ ',
                              ),
                            ),
                          ],
                          if (controller.needsPercent) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.percentController,
                              keyboardType: TextInputType.number,
                              decoration: offerFieldDecoration(
                                'Discount (%)',
                                prefix: '% ',
                              ),
                            ),
                          ],
                          if (controller.needsTime) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller.startTimeController,
                                    decoration: offerFieldDecoration(
                                      'Start time',
                                      helper: 'HH:MM',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: controller.endTimeController,
                                    decoration: offerFieldDecoration(
                                      'End time',
                                      helper: 'HH:MM',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.flatController,
                              keyboardType: TextInputType.number,
                              decoration: offerFieldDecoration(
                                'Flat discount (₹) — optional',
                                prefix: '₹ ',
                              ),
                            ),
                          ],
                          if (controller.needsCategoryOptional ||
                              controller.needsCategory) ...[
                            const SizedBox(height: 12),
                            Obx(() {
                              final categories = controller.availableCategories;
                              if (categories.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return AppDropdownFormField2<String>(
                                value: controller.selectedCategory.value ??
                                    OfferFormController.allCategoriesValue,
                                decoration: offerFieldDecoration(
                                  controller.needsCategory
                                      ? 'Category'
                                      : 'Offer category (optional)',
                                  helper: controller.needsCategory
                                      ? 'Discount applies to this category only'
                                      : 'Leave on entire order for all items',
                                ),
                                items: [
                                  if (controller.needsCategoryOptional)
                                    const DropdownItem(
                                      value: OfferFormController.allCategoriesValue,
                                      child: Text('Entire order'),
                                    ),
                                  ...categories.map(
                                    (category) => DropdownItem(
                                      value: category,
                                      child: Text(
                                        category.capitalize ?? category,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: controller.onCategoryChanged,
                              );
                            }),
                          ],
                          const SizedBox(height: 4),
                          Obx(
                            () => SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Offer active',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: const Text(
                                'Inactive offers are hidden at billing',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColor.textSecondary,
                                ),
                              ),
                              value: controller.active.value,
                              onChanged: (value) =>
                                  controller.active.value = value,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Obx(() {
                    controller.selectedType.value;
                    controller.sameAsTrigger.value;
                    if (!controller.showItemList) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              controller.itemsSectionTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColor.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (controller.needsFreeItems)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColor.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${controller.selectedItemIds.length} selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: controller.searchController,
                          onChanged: controller.onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search items by name, category, SKU…',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: Obx(
                              () => controller.searchQuery.value.isEmpty
                                  ? const SizedBox.shrink()
                                  : IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: controller.clearSearch,
                                    ),
                            ),
                            filled: true,
                            fillColor: AppColor.backGroundColor,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildItemPicker(controller),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(
              () => Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.isSaving.value ? null : Get.back,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: controller.isSaving.value
                          ? null
                          : controller.save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: controller.isSaving.value
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              controller.isEditing
                                  ? 'Save changes'
                                  : 'Create offer',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildItemPicker(OfferFormController controller) {
  return Obx(() {
    if (controller.isLoadingItems.value) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final items = controller.filteredItems();
    if (controller.menuItems.isEmpty) {
      return OfferEmptyItemsState(
        message: 'No menu items found',
        actionLabel: 'Reload items',
        onAction: controller.loadMenuItems,
      );
    }
    if (items.isEmpty) {
      return OfferEmptyItemsState(
        message: 'No items match "${controller.searchQuery.value}"',
        actionLabel: 'Clear search',
        onAction: controller.clearSearch,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColor.backGroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColor.cardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 112,
          color: AppColor.cardBorder.withValues(alpha: 0.7),
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          if (controller.selectedType.value == PromotionTypes.buyXGetY &&
              !controller.sameAsTrigger.value) {
            return OfferItemBuyFreeTile(
              item: item,
              isBuyProduct: controller.productItemId.value == item.id,
              isFreeChoice: controller.selectedItemIds.contains(item.id),
              onBuyTap: () => controller.productItemId.value = item.id,
              onFreeChanged: (checked) {
                if (checked) {
                  controller.selectedItemIds.add(item.id);
                } else {
                  controller.selectedItemIds.remove(item.id);
                }
              },
            );
          }
          if (controller.singleProductSelect) {
            return OfferItemRadioTile(
              item: item,
              groupValue: controller.productItemId.value,
              value: item.id,
              onChanged: (value) => controller.productItemId.value = value,
            );
          }
          final isSelected = controller.selectedItemIds.contains(item.id);
          return OfferItemCheckboxTile(
            item: item,
            selected: isSelected,
            onChanged: (checked) {
              if (checked) {
                if (controller.needsProduct && !controller.needsFreeItems) {
                  controller.selectedItemIds
                    ..clear()
                    ..add(item.id);
                  controller.productItemId.value = item.id;
                } else {
                  controller.selectedItemIds.add(item.id);
                }
              } else {
                controller.selectedItemIds.remove(item.id);
              }
            },
          );
        },
      ),
    );
  });
}
