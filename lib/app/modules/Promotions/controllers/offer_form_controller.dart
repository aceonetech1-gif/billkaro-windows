import 'package:billkaro/app/modules/Promotions/controllers/promotions_list_controller.dart';
import 'package:billkaro/app/services/Modals/addItem/item_response.dart';
import 'package:billkaro/app/services/Modals/promotions/promotion_response.dart';
import 'package:billkaro/app/utils/promotion_engine.dart';
import 'package:billkaro/app/utils/promotion_types.dart';
import 'package:billkaro/config/config.dart';

class OfferFormController extends BaseController {
  OfferFormController({this.existing, this.initialType});

  final PromotionData? existing;
  final String? initialType;

  static const allCategoriesValue = '__all_order__';

  final menuItems = <ItemData>[].obs;
  final isSaving = false.obs;
  final isLoadingItems = false.obs;

  late final TextEditingController nameController;
  late final TextEditingController amountController;
  late final TextEditingController buyQtyController;
  late final TextEditingController getQtyController;
  late final TextEditingController flatController;
  late final TextEditingController percentController;
  late final TextEditingController startTimeController;
  late final TextEditingController endTimeController;
  late final TextEditingController searchController;

  final selectedType = PromotionTypes.spendThresholdFreeItem.obs;
  final active = true.obs;
  final sameAsTrigger = false.obs;
  final productItemId = RxnString();
  final selectedCategory = RxnString();
  final selectedItemIds = <String>{}.obs;
  final searchQuery = ''.obs;

  bool get isEditing => existing != null;

  bool get needsMinAmount =>
      selectedType.value == PromotionTypes.spendThresholdFreeItem ||
      selectedType.value == PromotionTypes.amountThresholdDiscount ||
      selectedType.value == PromotionTypes.percentageThreshold;

  bool get needsBuyQty =>
      selectedType.value == PromotionTypes.buyXGetY ||
      selectedType.value == PromotionTypes.buyXPercentOff ||
      selectedType.value == PromotionTypes.productSpecific;

  bool get needsGetQty => selectedType.value == PromotionTypes.buyXGetY;

  bool get needsFlatAmount =>
      selectedType.value == PromotionTypes.amountThresholdDiscount ||
      selectedType.value == PromotionTypes.flatDiscount ||
      selectedType.value == PromotionTypes.productSpecific ||
      (selectedType.value == PromotionTypes.timeBased &&
          (double.tryParse(flatController.text) ?? 0) > 0);

  bool get needsPercent =>
      selectedType.value == PromotionTypes.percentageThreshold ||
      selectedType.value == PromotionTypes.buyXPercentOff ||
      selectedType.value == PromotionTypes.categoryPercent ||
      selectedType.value == PromotionTypes.timeBased;

  bool get needsCategory =>
      selectedType.value == PromotionTypes.categoryPercent ||
      (selectedType.value == PromotionTypes.spendThresholdFreeItem &&
          selectedCategory.value != allCategoriesValue);

  bool get needsCategoryOptional =>
      selectedType.value == PromotionTypes.spendThresholdFreeItem;

  bool get needsTime => selectedType.value == PromotionTypes.timeBased;

  bool get needsFreeItems =>
      selectedType.value == PromotionTypes.spendThresholdFreeItem ||
      (selectedType.value == PromotionTypes.buyXGetY && !sameAsTrigger.value);

  bool get needsProduct =>
      selectedType.value == PromotionTypes.productSpecific ||
      selectedType.value == PromotionTypes.buyXGetY;

  bool get singleProductSelect =>
      selectedType.value == PromotionTypes.productSpecific ||
      (selectedType.value == PromotionTypes.buyXGetY && sameAsTrigger.value);

  bool get showItemList => needsFreeItems || needsProduct;

  List<String> get availableCategories {
    final names = menuItems
        .map((item) => item.category.trim())
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'none')
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  String? get categoryNameForSave {
    final category = selectedCategory.value;
    if (category == null || category == allCategoriesValue) return null;
    return category;
  }

  String get minAmountLabel {
    final category = selectedCategory.value;
    if (needsCategory && category != null && category != allCategoriesValue) {
      final label = category.capitalize ?? category;
      return 'Minimum $label amount (₹)';
    }
    return 'Minimum order amount (₹)';
  }

  String get itemsSectionTitle {
    if (selectedType.value == PromotionTypes.buyXGetY && !sameAsTrigger.value) {
      return 'Buy product & free choices';
    }
    if (singleProductSelect) return 'Select product';
    if (needsFreeItems) return 'Free item choices';
    return 'Items';
  }

  @override
  void onInit() {
    super.onInit();
    _initFields();
    loadMenuItems();
  }

  @override
  void onClose() {
    nameController.dispose();
    amountController.dispose();
    buyQtyController.dispose();
    getQtyController.dispose();
    flatController.dispose();
    percentController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void _initFields() {
    final promo = existing;
    selectedType.value = initialType ?? _normalizeEditType(promo);
    sameAsTrigger.value = promo?.rewards.sameAsTrigger ?? false;
    productItemId.value = promo?.conditions.itemId;

    nameController = TextEditingController(text: promo?.name ?? '');
    amountController = TextEditingController(
      text: promo?.conditions.minOrderAmount.toStringAsFixed(0) ?? '250',
    );
    buyQtyController = TextEditingController(
      text: (promo?.conditions.buyQuantity ?? 1).toString(),
    );
    getQtyController = TextEditingController(
      text: (promo?.rewards.getQuantity ?? 1).toString(),
    );
    flatController = TextEditingController(
      text: promo?.rewards.flatAmount.toStringAsFixed(0) ?? '0',
    );
    percentController = TextEditingController(
      text: promo?.rewards.percent.toStringAsFixed(0) ?? '0',
    );
    startTimeController = TextEditingController(
      text: promo?.conditions.startTime ?? '14:00',
    );
    endTimeController = TextEditingController(
      text: promo?.conditions.endTime ?? '17:00',
    );
    searchController = TextEditingController();

    selectedItemIds.assignAll(
      promo?.rewards.freeItems.map((e) => e.itemId).toList() ?? [],
    );
    active.value = promo?.active ?? true;

    final existingCategory = promo?.conditions.categoryName?.trim();
    selectedCategory.value = existingCategory != null && existingCategory.isNotEmpty
        ? existingCategory
        : allCategoriesValue;
  }

  String _normalizeEditType(PromotionData? promo) {
    if (promo == null) return PromotionTypes.spendThresholdFreeItem;
    if (promo.type == PromotionTypes.categorySpendThresholdFreeItem) {
      return PromotionTypes.spendThresholdFreeItem;
    }
    return promo.type;
  }

  Future<void> loadMenuItems() async {
    final outletId = appPref.selectedOutlet?.id;
    if (outletId == null) return;

    isLoadingItems.value = true;
    try {
      final loaded = await _fetchAllMenuItems(outletId);
      menuItems.assignAll(loaded);
    } catch (e, st) {
      debugPrint('Failed to load menu items for offers: $e\n$st');
    } finally {
      isLoadingItems.value = false;
    }
  }

  Future<List<ItemData>> _fetchAllMenuItems(String outletId) async {
    final db = AppDatabase();
    final isOnline = await NetworkUtils.hasInternetConnection();

    if (isOnline) {
      const pageSize = 100;
      final fetched = <ItemData>[];
      var page = 1;
      var hasMore = true;

      while (hasMore) {
        final response = await callApi(
          apiClient.getItems(
            outletId,
            page,
            pageSize,
            null,
            null,
            null,
            null,
          ),
          showLoader: false,
        );

        if (response?.status != 'success') break;

        final batch = response!.data;
        if (batch.isEmpty) break;

        for (final item in batch) {
          if (!fetched.any((existing) => existing.id == item.id)) {
            fetched.add(item);
          }
        }

        final pagination = response.pagination;
        if (pagination?.hasNextPage != null) {
          hasMore = pagination!.hasNextPage!;
        } else {
          hasMore = batch.length >= pageSize;
        }
        page++;
      }

      if (fetched.isNotEmpty) {
        await db.saveItems(fetched, outletId);
        return fetched;
      }
    }

    return db.getItems(outletId: outletId);
  }

  List<ItemData> filteredItems() {
    var scoped = menuItems.toList();
    final category = selectedCategory.value;
    if (category != null && category != allCategoriesValue) {
      scoped = scoped
          .where(
            (item) => PromotionEngine.categoryMatches(item.category, category),
          )
          .toList();
    }

    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return scoped;

    return scoped.where((item) {
      final name = item.itemName.toLowerCase();
      final itemCategory = item.category.toLowerCase();
      final sku = item.sku.toLowerCase();
      final barcode = item.barcode.toLowerCase();
      return name.contains(query) ||
          itemCategory.contains(query) ||
          sku.contains(query) ||
          barcode.contains(query);
    }).toList();
  }

  void onTypeChanged(String? value) {
    if (value == null) return;
    selectedType.value = value;
    selectedItemIds.clear();
    productItemId.value = null;
  }

  void onSameAsTriggerChanged(bool value) {
    sameAsTrigger.value = value;
    selectedItemIds.clear();
  }

  void onCategoryChanged(String? value) {
    selectedCategory.value = value;
    selectedItemIds.removeWhere((id) {
      final item = menuItems.firstWhereOrNull((entry) => entry.id == id);
      if (item == null) return true;
      if (value == null || value == allCategoriesValue) return false;
      return !PromotionEngine.categoryMatches(item.category, value);
    });
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  void onSearchChanged(String value) => searchQuery.value = value;

  Future<void> save() async {
    final outletId = appPref.selectedOutlet?.id;
    final userId = appPref.ordersApiUserId;
    if (outletId == null || userId == null) return;

    final name = nameController.text;
    if (name.trim().isEmpty) {
      showError(description: 'Enter an offer name.');
      return;
    }

    final type = selectedType.value;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final buyQty = int.tryParse(buyQtyController.text.trim()) ?? 1;
    final getQty = int.tryParse(getQtyController.text.trim()) ?? 1;
    final flat = double.tryParse(flatController.text.trim()) ?? 0;
    final percent = double.tryParse(percentController.text.trim()) ?? 0;

    final freeItems = selectedItemIds.map((id) {
      final item = menuItems.firstWhereOrNull((entry) => entry.id == id);
      return PromotionFreeItem(itemId: id, label: item?.itemName);
    }).toList();

    final productId = productItemId.value ??
        (needsProduct && selectedItemIds.length == 1 ? selectedItemIds.first : null);

    final validationError = _validateOffer(
      type: type,
      minOrderAmount: amount,
      buyQuantity: buyQty,
      flatAmount: flat,
      percent: percent,
      categoryName: categoryNameForSave,
      productItemId: productId,
      startTime: startTimeController.text.trim(),
      endTime: endTimeController.text.trim(),
      freeItems: freeItems,
      sameAsTrigger: sameAsTrigger.value,
    );
    if (validationError != null) {
      showError(description: validationError);
      return;
    }

    final resolvedType = _resolveSaveType(type, categoryNameForSave);
    final conditions = <String, dynamic>{
      'amountBasis': 'subtotal',
      if (amount > 0) 'minOrderAmount': amount,
      if (buyQty > 0 && _needsBuyQuantity(type)) 'buyQuantity': buyQty,
      if (categoryNameForSave != null && categoryNameForSave!.trim().isNotEmpty)
        'categoryName': categoryNameForSave!.trim(),
      if (productId != null && productId.trim().isNotEmpty) 'itemId': productId.trim(),
      if (startTimeController.text.trim().isNotEmpty)
        'startTime': startTimeController.text.trim(),
      if (endTimeController.text.trim().isNotEmpty)
        'endTime': endTimeController.text.trim(),
    };

    final rewards = <String, dynamic>{
      'deductStock': true,
      if (getQty > 0 && PromotionTypes.isFreeItemType(type)) 'getQuantity': getQty,
      if (flat > 0) 'flatAmount': flat,
      if (percent > 0) 'percent': percent,
      if (sameAsTrigger.value) 'sameAsTrigger': true,
      if (freeItems.isNotEmpty)
        'freeItems': freeItems.map((e) => e.toJson()).toList(),
      if (PromotionTypes.isFreeItemType(type)) 'rewardKind': 'free_item',
      if (PromotionTypes.isDiscountType(type) && flat > 0) 'rewardKind': 'flat_off',
      if (PromotionTypes.isDiscountType(type) && percent > 0 && flat <= 0)
        'rewardKind': 'percent_off',
      if (PromotionTypes.isFreeItemType(type) && freeItems.length > 1)
        'choiceMode': 'pick_one',
    };

    isSaving.value = true;
    try {
      final body = {
        'userId': userId,
        'name': name.trim(),
        'type': resolvedType,
        'active': active.value,
        'conditions': conditions,
        'rewards': rewards,
      };

      if (existing == null) {
        await callApi(apiClient.createPromotion(outletId, body));
      } else {
        await callApi(apiClient.updatePromotion(outletId, existing!.id, body));
      }

      if (Get.isRegistered<PromotionsListController>()) {
        await Get.find<PromotionsListController>().loadPromotions();
      }
      Get.back();
      showSuccess(
        description: existing == null ? 'Offer created' : 'Offer updated',
      );
    } catch (e) {
      showError(description: 'Could not save offer');
    } finally {
      isSaving.value = false;
    }
  }

  String _resolveSaveType(String type, String? categoryName) {
    if (type == PromotionTypes.spendThresholdFreeItem) {
      final category = categoryName?.trim();
      if (category != null && category.isNotEmpty) {
        return PromotionTypes.categorySpendThresholdFreeItem;
      }
    }
    return type;
  }

  bool _needsBuyQuantity(String type) {
    return type == PromotionTypes.buyXGetY ||
        type == PromotionTypes.buyXPercentOff ||
        type == PromotionTypes.productSpecific;
  }

  String? _validateOffer({
    required String type,
    required double minOrderAmount,
    required int buyQuantity,
    required double flatAmount,
    required double percent,
    String? categoryName,
    String? productItemId,
    String? startTime,
    String? endTime,
    required List<PromotionFreeItem> freeItems,
    required bool sameAsTrigger,
  }) {
    switch (type) {
      case PromotionTypes.buyXGetY:
        if (buyQuantity < 1) return 'Buy quantity must be at least 1.';
        if (productItemId == null || productItemId.trim().isEmpty) {
          return 'Select the product for this offer.';
        }
        if (!sameAsTrigger && freeItems.isEmpty) {
          return 'Select at least one free item choice.';
        }
        return null;
      case PromotionTypes.amountThresholdDiscount:
        if (minOrderAmount <= 0) return 'Enter a minimum order amount.';
        if (flatAmount <= 0) return 'Enter the discount amount.';
        return null;
      case PromotionTypes.percentageThreshold:
        if (minOrderAmount <= 0) return 'Enter a minimum order amount.';
        if (percent <= 0) return 'Enter the discount percentage.';
        return null;
      case PromotionTypes.flatDiscount:
        if (flatAmount <= 0) return 'Enter the flat discount amount.';
        return null;
      case PromotionTypes.buyXPercentOff:
        if (buyQuantity < 1) return 'Buy quantity must be at least 1.';
        if (percent <= 0) return 'Enter the discount percentage.';
        return null;
      case PromotionTypes.productSpecific:
        if (buyQuantity < 1) return 'Buy quantity must be at least 1.';
        if (productItemId == null || productItemId.trim().isEmpty) {
          return 'Select a product for this offer.';
        }
        if (flatAmount <= 0) return 'Enter the discount amount.';
        return null;
      case PromotionTypes.categoryPercent:
        if (categoryName == null || categoryName.trim().isEmpty) {
          return 'Select a category.';
        }
        if (percent <= 0) return 'Enter the discount percentage.';
        return null;
      case PromotionTypes.timeBased:
        if (startTime == null ||
            startTime.trim().isEmpty ||
            endTime == null ||
            endTime.trim().isEmpty) {
          return 'Enter start and end time (HH:MM).';
        }
        if (flatAmount <= 0 && percent <= 0) {
          return 'Enter a flat amount or percentage discount.';
        }
        return null;
      case PromotionTypes.spendThresholdFreeItem:
        if (minOrderAmount <= 0) return 'Enter a minimum order amount.';
        if (freeItems.isEmpty) return 'Select at least one free item.';
        return null;
      default:
        return 'Unsupported offer type.';
    }
  }
}
