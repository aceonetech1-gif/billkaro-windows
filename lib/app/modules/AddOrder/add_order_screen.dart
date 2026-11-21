import 'package:billkaro/app/Widgets/app_dropdowns.dart';
import 'package:billkaro/app/Widgets/horizontal_scroll_with_arrows.dart';
import 'package:billkaro/app/modules/AddOrder/add_order_controller.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:billkaro/app/modules/AddOrder/add_order_list_screen.dart';
import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:billkaro/app/services/Modals/orders/createOrders/createOrder_request.dart';
import 'package:billkaro/app/services/Modals/addItem/item_response.dart';
import 'package:billkaro/app/services/Modals/orders/split_payment.dart';
import 'package:billkaro/app/services/common_function.dart';
import 'package:billkaro/app/modules/AddOrder/widgets/cart_line_offer_details.dart';
import 'package:billkaro/app/utils/cart_line_display.dart';
import 'package:billkaro/app/utils/combo_display.dart';
import 'package:billkaro/config/config.dart';
import 'package:billkaro/utils/staff_access.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Neutral surface tokens for the POS screen (brand colour comes from [AppColor]).
abstract final class _Pos {
  static const background = Color(0xFFF4F6F9);
  static const surface = Colors.white;
  static const border = Color(0xFFE3E7ED);
  static const muted = Color(0xFFF3F5F8);
  static const textPrimary = AppColor.textPrimary;
  static const textSecondary = AppColor.textSecondary;
  static const kot = Color(0xFFE65100);
  static const radius = 12.0;
  static const gridSpacing = 12.0;
  static const gridPadding = 16.0;
}

String _amount(double value) => '₹${value.toStringAsFixed(2)}';

String _price(double value) => value == value.roundToDouble()
    ? '₹${value.toStringAsFixed(0)}'
    : '₹${value.toStringAsFixed(2)}';

Widget _orderSourceIcon(String source, {double size = 20}) {
  switch (source) {
    case 'Delivery':
      return Assets.delivery.image(width: size, height: size);
    case 'Dine In':
      return Assets.dineIn.image(width: size, height: size);
    case 'Swiggy':
      return Assets.svg.swiggy.svg(width: size, height: size);
    case 'Takeaway':
      return Assets.takeaway.image(width: size, height: size);
    case 'Zomato':
      return Assets.svg.zomato.svg(width: size, height: size);
    default:
      return Icon(Icons.storefront_outlined, size: size);
  }
}

class AddOrderScreen extends StatefulWidget {
  AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  late final AddOrderController controller;
  final ScrollController scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    // This screen is routed by Modular, so GetX may keep an old controller alive.
    // Recreate it to always consume the latest route arguments (edit order/customer data).
    if (Get.isRegistered<AddOrderController>()) {
      Get.delete<AddOrderController>(force: true);
    }
    controller = Get.put(AddOrderController());
    scrollController.addListener(_onScroll);
    _workers
      ..add(ever<List<ItemData>>(controller.items, (_) => _scheduleFillCheck()))
      ..add(
        ever<String>(controller.searchQuery, (query) {
          if (query.isEmpty && _searchController.text.isNotEmpty) {
            _searchController.clear();
          }
        }),
      );
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    // Paginate every view (All, a category, or a search). Restricting this to
    // "All" made items beyond the first page unreachable elsewhere.
    if (position.pixels >= position.maxScrollExtent - 400) {
      controller.loadMoreItems();
    }
  }

  /// Wide monitors often fit the whole first page without a scrollbar, which
  /// meant the next page never loaded. Fetch it automatically in that case.
  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      if (controller.items.isNotEmpty &&
          scrollController.position.maxScrollExtent <= 0) {
        controller.loadMoreItems();
      }
    });
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    controller.clearOrderDraft();
    // Only delete if this screen still owns the registered instance.
    // Navigating Create Order → Invoice (push) → Create Order (sidebar) can
    // dispose the old screen after a new controller was already put, which
    // would otherwise unregister the active one and break ConfirmOrderDialog.
    if (Get.isRegistered<AddOrderController>() &&
        identical(Get.find<AddOrderController>(), controller)) {
      Get.delete<AddOrderController>(force: true);
    }
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    controller.clearSearch();
  }

  void _ifHasItems(VoidCallback action) {
    if (controller.hasSelectedItems) action();
  }

  void _bill() =>
      _ifHasItems(() => controller.showConfirmOrderDialog(PosOrderAction.bill));

  void _hold() =>
      _ifHasItems(() => controller.showConfirmOrderDialog(PosOrderAction.hold));

  void _kot() {
    if (!controller.isKotFeatureActive || !StaffAccess.canPrintKot) return;
    _ifHasItems(() => controller.executePosAction(PosOrderAction.kot));
  }

  /// Every "create" entry point goes through the same subscription gate.
  void _withSubscription(VoidCallback action) {
    if (!hasTrialOrSubscription(Get.find<AppPref>())) {
      checkSubscription();
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return WillPopScope(
      onWillPop: () => _showLeaveConfirmationDialog(context),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.f7): _kot,
          const SingleActivator(LogicalKeyboardKey.f8): _hold,
          const SingleActivator(LogicalKeyboardKey.f9): _bill,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: _Pos.background,
            endDrawer: Drawer(
              width: 420,
              shape: const RoundedRectangleBorder(),
              child: SafeArea(child: _CartPanel(controller: controller)),
            ),
            appBar: _buildAppBar(context, loc),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // The cart used to disappear entirely below 1000px — narrow or
                // snapped windows had no way to see the order. Now it shrinks,
                // and on very narrow widths opens as a drawer from the footer.
                final cartWidth = width >= 1320
                    ? 400.0
                    : width >= 900
                    ? 344.0
                    : 0.0;
                final sideCart = cartWidth > 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildMenuArea(loc)),
                          if (sideCart)
                            SizedBox(
                              width: cartWidth,
                              child: _CartPanel(controller: controller),
                            ),
                        ],
                      ),
                    ),
                    _Footer(
                      controller: controller,
                      showViewOrder: !sideCart,
                      onViewOrder: () =>
                          _scaffoldKey.currentState?.openEndDrawer(),
                      onPreview: () =>
                          _ifHasItems(controller.viewInvoicePreview),
                      onKot: _kot,
                      onHold: _hold,
                      onBill: _bill,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations loc) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => _onBackPressed(context),
      ),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      toolbarHeight: 60,
      title: Obx(() {
        controller.orderDetailsVersion.value;
        final source = controller.selectedOrderSource.value;
        final subtitle = [
          'Bill #${controller.displayBillNumber}',
          if (source.isNotEmpty) source,
        ].join('  ·  ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.isEdit.value ? 'Edit Order' : loc.add_Order,
              style: const TextStyle(
                color: AppColor.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColor.white.withOpacity(0.72),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }),
      actions: [
        Obx(() {
          if (controller.isFromTableScreen.value) {
            return const SizedBox.shrink();
          }
          controller.homeController.selectedOutlet.value;
          if (!HomeMainRoutes.outletIsCafeOrRestaurant()) {
            return const SizedBox.shrink();
          }
          final selected = controller.selectedOrderSource.value;
          return Tooltip(
            message: 'Change order type',
            child: AppActionDropdown2<String>(
              width: 220,
              customButton: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected.isNotEmpty) ...[
                      _orderSourceIcon(selected, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      selected.isEmpty ? 'Order type' : selected,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              items: controller.ordersList.map((source) {
                final isSelected = source == selected;
                return DropdownItem<String>(
                  value: source,
                  height: 44,
                  child: Row(
                    children: [
                      _orderSourceIcon(source),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(source, overflow: TextOverflow.ellipsis),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColor.primary,
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) controller.setOrderSource(value);
              },
            ),
          );
        }),
        if (StaffAccess.canManageSettings)
          IconButton(
            tooltip: 'Order preferences',
            icon: const Icon(Icons.settings_outlined, color: AppColor.white),
            onPressed: controller.openSettings,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMenuArea(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuToolbar(
          controller: controller,
          searchController: _searchController,
          searchFocus: _searchFocus,
          onClearSearch: _clearSearch,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _GridLayout.resolve(constraints.maxWidth);
              return Obx(() {
                if (controller.isListView.value) {
                  return AddOrderListScreen(controller: controller);
                }
                final grid = _buildGrid(layout, loc);
                final state = controller.items.isEmpty
                    ? (controller.isLoadingItems.value ? 'loading' : 'empty')
                    : 'grid';
                // No AnimatedSwitcher here: during its cross-fade the old and
                // new grids were mounted together and shared one
                // ScrollController/Scrollbar, which caused "Duplicate
                // GlobalKey" and huge RenderFlex overflow errors.
                return KeyedSubtree(
                  key: ValueKey(
                    '$state|${controller.selectedCategory.value}'
                    '|${controller.searchQuery.value.trim()}',
                  ),
                  child: grid,
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(_GridLayout layout, AppLocalizations loc) {
    final items = controller.items;
    final query = controller.searchQuery.value.trim();
    final selected = controller.selectedCategory.value.toLowerCase();
    controller.categories.length;
    controller.recommendedItems.length;

    if (items.isEmpty) {
      if (controller.isLoadingItems.value) {
        return _SkeletonGrid(layout: layout);
      }
      if (query.isNotEmpty) {
        return _MenuEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matches for "$query"',
          message: 'Check the spelling or try a shorter search.',
          primaryLabel: 'Clear search',
          primaryIcon: Icons.close_rounded,
          onPrimary: _clearSearch,
        );
      }
      final canCreate = StaffAccess.canCreateProducts;
      if (selected != 'none') {
        return _MenuEmptyState(
          icon: Icons.category_outlined,
          title: 'No items in this category',
          message: canCreate
              ? 'Add an item here or pick another category.'
              : 'Pick another category to continue.',
          primaryLabel: canCreate ? loc.addItems : null,
          onPrimary: canCreate
              ? () => _withSubscription(
                  () => controller.addItem(controller.selectedCategory.value),
                )
              : null,
          secondaryLabel: loc.all,
          onSecondary: () => controller.selectCategory('none'),
        );
      }
      if (!canCreate) {
        return _MenuEmptyState(
          icon: Icons.restaurant_menu_rounded,
          title: loc.no_items_found,
          message: 'Ask your manager to add items to the menu.',
        );
      }
      return _MenuEmptyState(
        icon: Icons.restaurant_menu_rounded,
        title: 'Your menu is empty',
        message: 'Add items to start taking orders.',
        primaryLabel: loc.add_your_menu_using_photos,
        primaryIcon: Icons.auto_awesome,
        onPrimary: () => _withSubscription(controller.addMenuUsingAI),
        secondaryLabel: loc.addItems,
        onSecondary: () => _withSubscription(() => controller.addItem('none')),
      );
    }

    final sections = _buildMenuSections(
      controller,
      recommendedTitle: loc.recommended_items,
    );

    return Scrollbar(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          for (final section in sections) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                _Pos.gridPadding + 2,
                18,
                _Pos.gridPadding,
                10,
              ),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(section: section),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: _Pos.gridPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: layout.columns,
                  mainAxisSpacing: _Pos.gridSpacing,
                  crossAxisSpacing: _Pos.gridSpacing,
                  mainAxisExtent: layout.extent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTile(section, index, layout, loc),
                  childCount: section.tileCount,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Obx(
              () => controller.isLoadingMore.value
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    )
                  : const SizedBox(height: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    _MenuSection section,
    int index,
    _GridLayout layout,
    AppLocalizations loc,
  ) {
    if (index < section.items.length) {
      // Staggered pop-in for the first screenful; later tiles (scrolling,
      // pagination) appear almost instantly so scrolling stays snappy.
      return _FadeSlideIn(
        key: ValueKey('tile-${section.items[index].id}'),
        delay: Duration(milliseconds: index < 24 ? index * 18 : 0),
        duration: Duration(milliseconds: index < 24 ? 300 : 160),
        child: PosMenuItemTile(
          controller: controller,
          item: section.items[index],
          imageHeight: layout.imageHeight,
        ),
      );
    }
    final extra = index - section.items.length;
    if (section.showAiTile && extra == 0) {
      return _CreateTile(
        icon: Icons.auto_awesome,
        label: loc.add_your_menu_using_photos,
        highlighted: true,
        onTap: () => _withSubscription(controller.addMenuUsingAI),
      );
    }
    return _CreateTile(
      icon: Icons.add_rounded,
      label: loc.addItems,
      onTap: () => _withSubscription(
        () => controller.addItem(section.addToCategory ?? 'none'),
      ),
    );
  }

  Future<void> _onBackPressed(BuildContext context) async {
    final canLeave = await _showLeaveConfirmationDialog(context);
    if (!canLeave || !context.mounted) return;

    if (controller.isFromTableScreen.value) {
      Modular.to.navigate(HomeMainRoutes.tables);
      return;
    }
    if (Modular.to.canPop()) {
      Modular.to.pop();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Modular.to.navigate(HomeMainRoutes.home);
  }

  Future<bool> _showLeaveConfirmationDialog(BuildContext context) async {
    if (!controller.hasSelectedItems) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          constraints: const BoxConstraints(maxWidth: 400),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Discard this order?'),
          content: const Text(
            'Items added to this order will be lost if you leave now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColor.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return shouldLeave ?? false;
  }
}

// ---------------------------------------------------------------------------
// Menu sections
// ---------------------------------------------------------------------------

class _MenuSection {
  const _MenuSection({
    required this.title,
    required this.items,
    this.icon,
    this.addToCategory,
    this.showAiTile = false,
  });

  final String title;
  final IconData? icon;
  final List<ItemData> items;
  final String? addToCategory;
  final bool showAiTile;

  int get tileCount {
    if (!StaffAccess.canCreateProducts) return items.length;
    return items.length +
        (showAiTile ? 1 : 0) +
        (addToCategory != null ? 1 : 0);
  }
}

List<_MenuSection> _buildMenuSections(
  AddOrderController c, {
  required String recommendedTitle,
}) {
  // Items already in the order are pinned on top; they also stay in their
  // own category below.
  final added = c.selectedOrderItems;
  return [
    if (added.isNotEmpty)
      _MenuSection(
        title: 'Added items',
        icon: Icons.shopping_cart_checkout_rounded,
        items: added,
      ),
    ..._buildCatalogSections(c, recommendedTitle: recommendedTitle),
  ];
}

List<_MenuSection> _buildCatalogSections(
  AddOrderController c, {
  required String recommendedTitle,
}) {
  // De-duplicate by id: a repeated item gives two tiles the same key and
  // the whole section fails to render (blank menu).
  final seenIds = <String>{};
  final items = c.items.where((i) => seenIds.add(i.id)).toList();
  final query = c.searchQuery.value.trim();
  final selected = c.selectedCategory.value.toLowerCase();

  if (query.isNotEmpty) {
    return [
      _MenuSection(
        title: 'Results for "$query"',
        icon: Icons.search_rounded,
        items: items,
      ),
    ];
  }

  if (selected != 'none') {
    // Uncategorised items first (existing desktop behaviour), then the category.
    final uncategorised = <ItemData>[];
    final match = <ItemData>[];
    final rest = <ItemData>[];
    for (final item in items) {
      final key = item.category.toLowerCase();
      if (key == 'none') {
        uncategorised.add(item);
      } else if (key == selected) {
        match.add(item);
      } else {
        rest.add(item);
      }
    }
    final category = c.categories.firstWhereOrNull(
      (x) => x.categoryName.toLowerCase() == selected,
    );
    final title = category?.categoryName ?? c.selectedCategory.value;
    return [
      _MenuSection(
        title: title.capitalize ?? title,
        items: [...uncategorised, ...match, ...rest],
        addToCategory: c.selectedCategory.value,
      ),
    ];
  }

  // Best sellers get their own section only while it's shown; otherwise they
  // used to vanish from the grid (e.g. after typing a search).
  final showBest = c.showRecommendedSection && c.recommendedItems.isNotEmpty;
  final bestIds = showBest ? c.bestSellingItemIds : const <String>{};
  final sections = <_MenuSection>[];

  if (showBest) {
    sections.add(
      _MenuSection(
        title: recommendedTitle,
        icon: Icons.local_fire_department_rounded,
        items: c.recommendedItems.toList(),
      ),
    );
  }

  final knownCategories = c.categories
      .map((x) => x.categoryName.toLowerCase())
      .toSet();
  // Uncategorised items and items whose category is inactive/unknown (these
  // were previously dropped from "All").
  final other = items
      .where(
        (item) =>
            !knownCategories.contains(item.category.toLowerCase()) &&
            !bestIds.contains(item.id),
      )
      .toList();
  if (other.isNotEmpty) {
    sections.add(
      _MenuSection(
        title: 'Other items',
        items: other,
        addToCategory: 'none',
        showAiTile: true,
      ),
    );
  }

  final seenCategories = <String>{};
  for (final category in c.categories) {
    final key = category.categoryName.toLowerCase();
    // Same-named categories would show the same items twice.
    if (!seenCategories.add(key)) continue;
    final categoryItems = items
        .where(
          (item) =>
              item.category.toLowerCase() == key && !bestIds.contains(item.id),
        )
        .toList();
    if (categoryItems.isEmpty) continue;
    sections.add(
      _MenuSection(
        title: category.categoryName.capitalize ?? category.categoryName,
        items: categoryItems,
        addToCategory: category.categoryName,
      ),
    );
  }

  if (sections.isEmpty) {
    sections.add(
      const _MenuSection(
        title: 'Other items',
        items: [],
        addToCategory: 'none',
        showAiTile: true,
      ),
    );
  }
  return sections;
}

class _GridLayout {
  const _GridLayout({
    required this.columns,
    required this.imageHeight,
    required this.extent,
  });

  final int columns;
  final double imageHeight;
  final double extent;

  static _GridLayout resolve(double width) {
    final available = width - _Pos.gridPadding * 2;
    const minWidth = 160.0;
    final columns = max(
      2,
      ((available + _Pos.gridSpacing) / (minWidth + _Pos.gridSpacing)).floor(),
    );
    final cardWidth = (available - _Pos.gridSpacing * (columns - 1)) / columns;
    final imageHeight = (cardWidth * 0.6).clamp(84.0, 132.0);
    return _GridLayout(
      columns: columns,
      imageHeight: imageHeight,
      extent: imageHeight + 92,
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _MenuToolbar extends StatelessWidget {
  const _MenuToolbar({
    required this.controller,
    required this.searchController,
    required this.searchFocus,
    required this.onClearSearch,
  });

  final AddOrderController controller;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Obx(() {
      if (controller.isListView.value) return const SizedBox.shrink();
      final selected = controller.selectedCategory.value.toLowerCase();
      // Read inside Obx (not inside LayoutBuilder's builder, which runs later
      // at layout time and is not tracked) so pills refresh when categories load.
      final categories = controller.categories.toList();

      return Container(
        decoration: const BoxDecoration(
          color: _Pos.surface,
          border: Border(bottom: BorderSide(color: _Pos.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchWidth = constraints.maxWidth >= 900 ? 300.0 : 220.0;
            return Row(
              children: [
                SizedBox(
                  width: searchWidth,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        onClearSearch();
                        searchFocus.unfocus();
                      },
                    },
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (context, value, _) {
                        return TextField(
                          controller: searchController,
                          focusNode: searchFocus,
                          decoration: InputDecoration(
                            hintText: 'Search items  (Ctrl+F)',
                            hintStyle: const TextStyle(
                              color: _Pos.textSecondary,
                              fontSize: 13.5,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: _Pos.textSecondary,
                            ),
                            suffixIcon: value.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear (Esc)',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    onPressed: onClearSearch,
                                  ),
                            filled: true,
                            fillColor: _Pos.muted,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColor.primary,
                                width: 1.4,
                              ),
                            ),
                          ),
                          onChanged: (text) =>
                              controller.filterItemsBySearch(text.trim()),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HorizontalScrollWithArrows(
                    arrowButtonSize: 32,
                    child: Row(
                      spacing: 8,
                      children: [
                        _CategoryPill(
                          label: loc.all,
                          selected: selected == 'none',
                          onTap: () => controller.selectCategory('none'),
                        ),
                        ...categories.asMap().entries.map((entry) {
                          final category = entry.value;
                          final key = category.categoryName.toLowerCase();
                          return _CategoryPill(
                            // Names can repeat (e.g. two "Starters"), so key by position + id.
                            key: ValueKey('cat-${entry.key}-${category.id}'),
                            index: entry.key + 1,
                            label:
                                category.categoryName.capitalize ??
                                category.categoryName,
                            selected: selected == key,
                            onTap: () => controller.selectCategory(key),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                // Was shown to every staff member; creating categories is a
                // product-management action, same as on mobile.
                if (StaffAccess.canCreateProducts) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Add category',
                    child: OutlinedButton(
                      onPressed: () => Modular.to.pushNamed(
                        HomeMainRoutes.category,
                        arguments: {'voiceCallback': controller.getCategories},
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColor.primary,
                        side: const BorderSide(color: _Pos.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.add_rounded, size: 20),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    });
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.index = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Position in the pill row; staggers the entrance animation.
  final int index;

  @override
  Widget build(BuildContext context) {
    final pill = AnimatedScale(
      scale: selected ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: ShapeDecoration(
          color: selected ? AppColor.primary : _Pos.surface,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? AppColor.primary : _Pos.border),
          ),
          shadows: selected
              ? [
                  BoxShadow(
                    color: AppColor.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: selected ? Colors.white : _Pos.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );

    return _FadeSlideIn(
      delay: Duration(milliseconds: (index * 35).clamp(0, 350)),
      offset: const Offset(0.15, 0),
      child: pill,
    );
  }
}

/// Plays a one-shot fade + slide when first mounted.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 280),
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting offset as a fraction of the child's size.
  final Offset offset;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid pieces
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final _MenuSection section;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (section.icon != null) ...[
          Icon(section.icon, size: 18, color: AppColor.secondaryPrimary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            section.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _Pos.textPrimary,
            ),
          ),
        ),
        if (section.items.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _Pos.muted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${section.items.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _Pos.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: _Pos.border)),
      ],
    );
  }
}

/// Parses a `#RRGGBB` / `#AARRGGBB` POS colour; null when invalid.
/// (Previously `int.parse` threw on a malformed value and broke the tile.)
Color? _parsePosColor(String raw) {
  var value = raw.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({
    required this.name,
    required this.imageUrl,
    required this.posColor,
  });

  final String name;
  final String imageUrl;
  final String posColor;

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback();
    if (imageUrl.isEmpty) return fallback;
    // AppCachedNetworkImage resolves relative media paths (plain
    // Image.network didn't, so server-relative images never loaded) and
    // caches them across sessions.
    return AppCachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => const ColoredBox(color: _Pos.muted),
      errorWidget: (_, __, ___) => fallback,
    );
  }

  Widget _fallback() {
    final solid = _parsePosColor(posColor);
    final palette = AppColor.chartPalette;
    final tint = solid ?? palette[name.hashCode.abs() % palette.length];
    return Container(
      color: solid ?? tint.withOpacity(0.12),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: solid != null ? Colors.white : tint,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class PosItemCard extends StatelessWidget {
  const PosItemCard({
    super.key,
    required this.name,
    required this.price,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.imageUrl = '',
    this.posColor = '',
    this.imageHeight = 110,
  });

  final String name;
  final double price;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String imageUrl;
  final String posColor;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _Pos.surface,
        borderRadius: BorderRadius.circular(_Pos.radius),
        border: Border.all(
          color: selected ? AppColor.primary : _Pos.border,
          width: selected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColor.primary.withOpacity(0.12)
                : Colors.black.withOpacity(0.025),
            blurRadius: selected ? 14 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Pos.radius - 1),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onAdd,
            hoverColor: AppColor.primary.withOpacity(0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: imageHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ItemImage(
                        name: name,
                        imageUrl: imageUrl,
                        posColor: posColor,
                      ),
                      if (selected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColor.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '× $quantity',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            height: 1.25,
                            color: _Pos.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _price(price),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppColor.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _QtyStepper(
                              quantity: quantity,
                              onAdd: onAdd,
                              onRemove: onRemove,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.filled = true,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  /// Filled (menu card) vs outlined (cart line).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled && quantity <= 0) {
      return Material(
        color: AppColor.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(Icons.add_rounded, size: 18, color: AppColor.primary),
          ),
        ),
      );
    }
    final fg = filled ? Colors.white : _Pos.textPrimary;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: filled ? AppColor.primary : _Pos.surface,
        border: filled ? null : Border.all(color: _Pos.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.remove_rounded, onRemove, fg),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 20),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _button(Icons.add_rounded, onAdd, fg),
        ],
      ),
    );
  }

  Widget _button(IconData icon, VoidCallback? onTap, Color fg) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 28,
        height: 32,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? fg.withOpacity(0.35) : fg,
        ),
      ),
    );
  }
}

/// "Add item" / "Add menu from photos" tile — replaces the old cards that
/// mimicked a product with a fake "₹0.00" price and a dead stepper.
class _CreateTile extends StatelessWidget {
  const _CreateTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? Colors.white : AppColor.primary;
    return Material(
      color: highlighted ? null : AppColor.primary.withOpacity(0.03),
      borderRadius: BorderRadius.circular(_Pos.radius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: highlighted
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                )
              : null,
          borderRadius: BorderRadius.circular(_Pos.radius),
          border: highlighted
              ? null
              : Border.all(color: AppColor.primary.withOpacity(0.22)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? Colors.white.withOpacity(0.2)
                        : AppColor.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: fg, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({required this.layout});

  final _GridLayout layout;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(_Pos.gridPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: layout.columns,
        mainAxisSpacing: _Pos.gridSpacing,
        crossAxisSpacing: _Pos.gridSpacing,
        mainAxisExtent: layout.extent,
      ),
      itemCount: layout.columns * 3,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: _Pos.surface,
          borderRadius: BorderRadius.circular(_Pos.radius),
          border: Border.all(color: _Pos.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: layout.imageHeight,
              decoration: const BoxDecoration(
                color: _Pos.muted,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_Pos.radius - 1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(double.infinity),
                  const SizedBox(height: 8),
                  _bar(56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width) => Container(
    width: width,
    height: 10,
    decoration: BoxDecoration(
      color: _Pos.muted,
      borderRadius: BorderRadius.circular(5),
    ),
  );
}

class _MenuEmptyState extends StatelessWidget {
  const _MenuEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColor.primary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColor.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _Pos.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _Pos.textSecondary),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(140, 44),
                      foregroundColor: AppColor.primary,
                      side: const BorderSide(color: _Pos.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(secondaryLabel!),
                  ),
                if (primaryLabel != null && onPrimary != null)
                  FilledButton.icon(
                    onPressed: onPrimary,
                    icon: Icon(primaryIcon ?? Icons.add_rounded, size: 18),
                    label: Text(primaryLabel!),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, 44),
                      backgroundColor: AppColor.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rebuilds only this menu tile on qty changes (avoids full-grid Obx storms).
class PosMenuItemTile extends StatelessWidget {
  const PosMenuItemTile({
    super.key,
    required this.controller,
    required this.item,
    this.imageHeight = 110,
  });

  final AddOrderController controller;
  final ItemData item;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GetBuilder<AddOrderController>(
        id: AddOrderController.posItemUiId(item.id),
        builder: (c) {
          final itemName = item.itemName;
          return PosItemCard(
            imageHeight: imageHeight,
            imageUrl: item.itemImage,
            posColor: item.posColor,
            name: itemName.capitalize ?? itemName,
            price: item.salePrice,
            quantity: c.getParentItemQuantity(item.id),
            onAdd: () => c.handlePosItemTap(item),
            onRemove: () => c.decrementItemQuantity(item.id),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer({
    required this.controller,
    required this.showViewOrder,
    required this.onViewOrder,
    required this.onPreview,
    required this.onKot,
    required this.onHold,
    required this.onBill,
  });

  final AddOrderController controller;
  final bool showViewOrder;
  final VoidCallback onViewOrder;
  final VoidCallback onPreview;
  final VoidCallback onKot;
  final VoidCallback onHold;
  final VoidCallback onBill;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Obx(() {
      controller.itemQuantities.length;
      controller.isKOT.value;
      controller.totalAmount.value;
      controller.homeController.selectedOutlet.value;
      final hasItems = controller.hasSelectedItems;
      final kotEnabled = controller.isKotFeatureActive;
      final showKot = kotEnabled && StaffAccess.canPrintKot;
      final pendingKot = controller.pendingKotItemCount;
      final qty = controller.totalSelectedQuantity;

      ButtonStyle outlined({Color? color}) => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        foregroundColor: color ?? _Pos.textPrimary,
        side: BorderSide(color: color?.withOpacity(0.6) ?? _Pos.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );

      return Container(
        decoration: const BoxDecoration(
          color: _Pos.surface,
          border: Border(top: BorderSide(color: _Pos.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: hasItems
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$qty ${qty == 1 ? 'item' : 'items'}  ·  Total',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _Pos.textSecondary,
                          ),
                        ),
                        Text(
                          _amount(controller.totalAmount.value),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColor.primary,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Add items to start the order',
                      style: TextStyle(color: _Pos.textSecondary, fontSize: 14),
                    ),
            ),
            if (showViewOrder) ...[
              Badge(
                isLabelVisible: hasItems,
                label: Text('$qty'),
                backgroundColor: AppColor.secondaryPrimary,
                child: OutlinedButton.icon(
                  onPressed: onViewOrder,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View order'),
                  style: outlined(),
                ),
              ),
              const SizedBox(width: 10),
            ],
            OutlinedButton(
              onPressed: hasItems ? onPreview : null,
              style: outlined(),
              child: const Text('Preview'),
            ),
            if (showKot) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: 'Send to kitchen (F7)',
                child: OutlinedButton(
                  onPressed: hasItems ? onKot : null,
                  style: outlined(color: _Pos.kot),
                  child: Text(pendingKot > 0 ? 'KOT ($pendingKot)' : 'KOT'),
                ),
              ),
            ],
            const SizedBox(width: 10),
            Tooltip(
              message: 'F8',
              child: OutlinedButton(
                onPressed: hasItems ? onHold : null,
                style: outlined(),
                child: Text(kotEnabled ? 'Save' : loc.save_and_hold),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'F9',
              child: FilledButton(
                onPressed: hasItems ? onBill : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(150, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  backgroundColor: AppColor.primary,
                  foregroundColor: AppColor.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(kotEnabled ? 'Bill' : loc.save_and_bill),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Cart panel
// ---------------------------------------------------------------------------

class _CartPanel extends StatelessWidget {
  final AddOrderController controller;

  const _CartPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Obx(() {
      controller.orderDetailsVersion.value;
      controller.selectedOrderSource.value;
      controller.showAddDetailsOnCreateOrder.value;
      controller.availableTables.length;
      controller.itemQuantities.length;
      controller.totalAmount.value;
      final cartItems = controller.cartLines;

      final selectedTable = (controller.orderDetails['tableNumber'] ?? '')
          .toString()
          .trim();
      final isDineIn =
          controller.selectedOrderSource.value.toLowerCase() == 'dine in';
      final showTable = isDineIn && HomeMainRoutes.outletShowsTables();

      return Container(
        decoration: const BoxDecoration(
          color: _Pos.surface,
          border: Border(left: BorderSide(color: _Pos.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _Pos.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bill #${controller.displayBillNumber}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _Pos.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (controller.isEdit.value)
                        const _Tag(label: 'Running', color: _Pos.kot),
                    ],
                  ),
                  if (showTable) ...[
                    const SizedBox(height: 12),
                    _TableField(
                      controller: controller,
                      selectedTable: selectedTable,
                      loc: loc,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (controller.showAddDetailsOnCreateOrder.value) ...[
                        Expanded(
                          child: _ChipButton(
                            icon: Icons.person_outline_rounded,
                            label: loc.add_details,
                            onTap: () async {
                              final result = await Modular.to.pushNamed(
                                HomeMainRoutes.orderDetails,
                                arguments: controller.orderDetailsRouteArgs(),
                              );
                              if (result != null &&
                                  result is CreateorderRequest) {
                                controller.setOrderDetails(result.toJson());
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _ChipButton(
                          icon: Icons.sticky_note_2_outlined,
                          label: 'Order note',
                          onTap: controller.showRemarkDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _Pos.border),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: cartItems.isEmpty
                    ? const _CartEmpty(key: ValueKey('cart-empty'))
                    : ListView.separated(
                        key: const ValueKey('cart-list'),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: _Pos.border),
                        itemBuilder: (context, index) => _FadeSlideIn(
                          // Keyed by line so only newly added lines animate.
                          key: ValueKey('cart-${cartItems[index].lineKey}'),
                          offset: const Offset(0.12, 0),
                          duration: const Duration(milliseconds: 240),
                          child: _CartLine(
                            controller: controller,
                            line: cartItems[index],
                          ),
                        ),
                      ),
              ),
            ),
            if (cartItems.isNotEmpty) ...[
              const Divider(height: 1, color: _Pos.border),
              Container(
                color: _Pos.muted,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _Totals(controller: controller, loc: loc),
              ),
              const Divider(height: 1, color: _Pos.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: _PaymentSection(controller: controller, loc: loc),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _TableField extends StatelessWidget {
  const _TableField({
    required this.controller,
    required this.selectedTable,
    required this.loc,
  });

  final AddOrderController controller;
  final String selectedTable;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final tables = controller.availableTables;
    if (tables.isEmpty) {
      final loading = controller.isLoadingTables.value;
      if (selectedTable.isEmpty && !loading) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _Pos.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.table_restaurant_outlined,
              size: 18,
              color: _Pos.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              selectedTable.isEmpty
                  ? loc.loading
                  : '${loc.table_number}: $selectedTable',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Match by display name OR table number (mobile already did; desktop
    // showed an empty dropdown when the order stored the raw number).
    String? value;
    for (final t in tables) {
      if (t.displayName == selectedTable || t.tableNumber == selectedTable) {
        value = t.displayName;
        break;
      }
    }

    return AppDropdownFormField2<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.table_restaurant_outlined, size: 18),
        hintText: loc.table_number,
        isDense: true,
        filled: true,
        fillColor: _Pos.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      hint: Text(loc.enter_table_number),
      items: tables
          .map(
            (t) =>
                DropdownItem(value: t.displayName, child: Text(t.displayName)),
          )
          .toList(),
      onChanged: controller.setTableNumber,
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: _Pos.textPrimary,
        side: const BorderSide(color: _Pos.border),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  const _CartEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: _Pos.muted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 28,
                color: _Pos.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No items yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _Pos.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Click a menu item to add it to this order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _Pos.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.controller, required this.line});

  final AddOrderController controller;
  final CartLineDisplay line;

  @override
  Widget build(BuildContext context) {
    final remark = line.remark.trim();
    final showRemark = remark.isNotEmpty && !remark.startsWith('Promo: ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: _Pos.textPrimary,
                        ),
                      ),
                    ),
                    if (line.isPromo) ...[
                      const SizedBox(width: 6),
                      const _Tag(label: 'FREE', color: AppColor.success),
                    ],
                  ],
                ),
                if (line.comboIncludes != null) ...[
                  const SizedBox(height: 2),
                  ComboIncludesLabel(text: line.comboIncludes!),
                ],
                if (line.hasOfferInfo) ...[
                  const SizedBox(height: 4),
                  CartLineOfferDetails(
                    offerName: line.offerName,
                    offerDetail: line.offerDetail,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  line.isPromo
                      ? 'Offer item'
                      : [
                          '${_amount(line.unitPrice)} each',
                          if (line.hasGst) line.gstLabel,
                        ].join('  ·  '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _Pos.textSecondary,
                  ),
                ),
                if (line.pendingKot > 0 && controller.isKotFeatureActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${line.pendingKot} new for kitchen',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _Pos.kot,
                      ),
                    ),
                  ),
                if (showRemark)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Note: $remark',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColor.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyStepper(
                      filled: false,
                      quantity: line.quantity,
                      onRemove: () =>
                          controller.decrementItemQuantity(line.lineKey),
                      onAdd: line.isPromo
                          ? () {}
                          : () =>
                                controller.incrementItemQuantity(line.lineKey),
                    ),
                    if (!line.isPromo) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: remark.isEmpty ? 'Add note' : 'Edit note',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          showRemark
                              ? Icons.sticky_note_2
                              : Icons.sticky_note_2_outlined,
                          size: 18,
                          color: showRemark
                              ? AppColor.primary
                              : _Pos.textSecondary,
                        ),
                        onPressed: () => controller.showItemRemarkDialog(
                          line.lineKey,
                          line.name,
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: _Pos.textSecondary,
                      ),
                      onPressed: () =>
                          controller.removeItemCompletely(line.lineKey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            line.isPromo ? 'FREE' : _amount(line.lineTotalWithGst),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: line.isPromo ? AppColor.success : _Pos.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.controller, required this.loc});

  final AddOrderController controller;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final discount = controller.appliedDiscountAmount();
    final service = controller.serviceChargeAmount();
    return Column(
      children: [
        _row('Subtotal', _amount(controller.subtotal.value)),
        for (final row in controller.taxRows)
          _row(row.label, _amount(row.amount)),
        if (service > 0) _row('Service charge', _amount(service)),
        if (discount > 0)
          _row(
            controller.discountSummaryLabel(loc.discount),
            '-${_amount(discount)}',
            color: AppColor.success,
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: _Pos.border),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                loc.total_amount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _Pos.textPrimary,
                ),
              ),
            ),
            Text(
              _amount(controller.totalAmount.value),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColor.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _Pos.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? _Pos.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

class _PaymentSection extends StatelessWidget {
  final AddOrderController controller;
  final AppLocalizations loc;

  const _PaymentSection({required this.controller, required this.loc});

  static const Set<String> _allowedPaymentMethods = {'cash', 'card', 'upi'};

  String _normalizePaymentMethod(String value) {
    final normalized = value.trim().toLowerCase();
    return _allowedPaymentMethods.contains(normalized) ? normalized : 'cash';
  }

  Widget _paymentSvgIcon(String method, {double size = 20}) {
    switch (_normalizePaymentMethod(method)) {
      case 'card':
        return Assets.svg.cardIcon.svg(width: size, height: size);
      case 'upi':
        return Assets.svg.upiIcon.svg(width: size, height: size);
      case 'cash':
      default:
        return Assets.svg.cashIcon.svg(width: size, height: size);
    }
  }

  List<(String method, String label)> get _paymentMethods => [
    ('cash', loc.cash),
    ('card', loc.card),
    ('upi', loc.upi),
  ];

  /// Segmented selector: three equal tiles, selected one tinted.
  Widget _buildPaymentMethodSelector({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Row(
      children: [
        for (final (index, entry) in _paymentMethods.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _PaymentTile(
              icon: _paymentSvgIcon(entry.$1, size: 18),
              label: entry.$2,
              selected: selected == entry.$1,
              onTap: () => onSelected(entry.$1),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.orderDetailsVersion.value;
      controller.totalAmount.value;
      controller.splitPayments.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.payment_received_in,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _Pos.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'Split',
                style: TextStyle(fontSize: 12.5, color: _Pos.textSecondary),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: controller.useSplitPayment.value,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: controller.setUseSplitPayment,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!controller.useSplitPayment.value) ...[
            _buildPaymentMethodSelector(
              selected: _normalizePaymentMethod(
                controller.paymentReceivedIn.value,
              ),
              onSelected: controller.setPaymentMethod,
            ),
          ] else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...controller.splitPayments.asMap().entries.map(
                  (entry) => _buildSplitPaymentItem(entry.key, entry.value),
                ),
                _buildRemainingBanner(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showAddSplitPaymentDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add payment'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: AppColor.primary,
                    side: const BorderSide(color: _Pos.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    });
  }

  Widget _buildRemainingBanner() {
    final remaining = controller.remainingPaymentAmount;
    final (Color color, String label) = remaining < -0.01
        ? (AppColor.error, 'Excess')
        : remaining > 0.01
        ? (AppColor.warning, 'Remaining')
        : (AppColor.success, 'Fully paid');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            _amount(remaining.abs()),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentItem(int index, SplitPayment payment) {
    final safeMethod = _normalizePaymentMethod(payment.paymentMethod);
    return Container(
      // The amount field keeps its own text state. Without a key, removing a
      // row left the next row showing the deleted row's amount.
      key: ValueKey('split-$index-of-${controller.splitPayments.length}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: _Pos.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPaymentMethodSelector(
            selected: safeMethod,
            onSelected: (method) {
              controller.updateSplitPayment(
                index,
                SplitPayment(paymentMethod: method, amount: payment.amount),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: payment.amount.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    controller.updateSplitPayment(
                      index,
                      SplitPayment(
                        paymentMethod: payment.paymentMethod,
                        amount: double.tryParse(value) ?? 0.0,
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove payment',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColor.error,
                  size: 20,
                ),
                onPressed: () => controller.removeSplitPayment(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSplitPaymentDialog(BuildContext context) {
    // Prefill with what's still owed — the common case is "pay the rest".
    final remaining = controller.remainingPaymentAmount;
    final amountController = TextEditingController(
      text: remaining > 0.01 ? remaining.toStringAsFixed(2) : '',
    );
    var selectedMethod = 'cash';
    String? error;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final amount = double.tryParse(amountController.text) ?? 0.0;
            if (amount <= 0) {
              // Used to silently do nothing on an invalid amount.
              setDialogState(() => error = 'Enter an amount greater than 0');
              return;
            }
            controller.addSplitPayment(selectedMethod, amount);
            Navigator.of(dialogCtx).pop();
          }

          return AlertDialog(
            constraints: const BoxConstraints(maxWidth: 420),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Add payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Method',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _Pos.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPaymentMethodSelector(
                  selected: selectedMethod,
                  onSelected: (method) {
                    setDialogState(() => selectedMethod = method);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onFieldSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                    errorText: error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColor.primary,
                ),
                onPressed: submit,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColor.primary.withOpacity(0.07) : _Pos.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppColor.primary : _Pos.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColor.primary : _Pos.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
