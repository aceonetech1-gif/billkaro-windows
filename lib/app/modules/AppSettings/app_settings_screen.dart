import 'package:billkaro/app/modules/AppSettings/app_settings_controller.dart';
import 'package:billkaro/app/modules/Home/home_screen_controller.dart';
import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:billkaro/app/modules/Language/language_dialog.dart';
import 'package:billkaro/app/modules/Theme/theme_controller.dart';
import 'package:billkaro/app/Widgets/billing_mode_selector.dart';
import 'package:billkaro/app/Widgets/switch_with_on_off_label.dart';
import 'package:billkaro/app/services/printerService.dart/thermal_printer/helpers/cash_drawer_helper.dart';
import 'package:billkaro/config/config.dart';
import 'package:billkaro/utils/kitchen_display_browser.dart';
import 'package:billkaro/utils/staff_access.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_modular/flutter_modular.dart';


enum _SettingsCategory {
  ordersBilling,
  hardware,
  syncDevices,
  billingPlan,
  notifications,
  appearance,
  help,
}

class _SettingsCategoryInfo {
  const _SettingsCategoryInfo({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _SettingsCategory id;
  final IconData icon;
  final String title;
  final String subtitle;
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late final controller = Get.put(AppSettingsController());
  final ThemeController themeController = Get.find<ThemeController>();
  final TextEditingController _searchController = TextEditingController();

  _SettingsCategory? _selected;
  String _query = '';

  static const double _wideBreakpoint = 900;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_SettingsCategoryInfo> _allCategories(AppLocalizations loc) {
    final items = <_SettingsCategoryInfo>[
      _SettingsCategoryInfo(
        id: _SettingsCategory.ordersBilling,
        icon: Icons.receipt_long_outlined,
        title: loc.settings_section_orders_billing,
        subtitle: loc.settings_section_orders_billing_desc,
      ),
      _SettingsCategoryInfo(
        id: _SettingsCategory.hardware,
        icon: Icons.print_outlined,
        title: loc.settings_section_hardware,
        subtitle: loc.settings_section_hardware_desc,
      ),
      _SettingsCategoryInfo(
        id: _SettingsCategory.syncDevices,
        icon: Icons.devices_outlined,
        title: loc.settings_section_sync_devices,
        subtitle: loc.settings_section_sync_devices_desc,
      ),
    ];
    if (StaffAccess.isOwnerSession) {
      items.add(
        _SettingsCategoryInfo(
          id: _SettingsCategory.billingPlan,
          icon: Icons.account_balance_wallet_outlined,
          title: loc.settings_section_billing,
          subtitle: loc.settings_section_billing_desc,
        ),
      );
    }
    items.addAll([
      _SettingsCategoryInfo(
        id: _SettingsCategory.notifications,
        icon: Icons.notifications_outlined,
        title: loc.settings_section_notifications,
        subtitle: loc.settings_section_notifications_desc,
      ),
      _SettingsCategoryInfo(
        id: _SettingsCategory.appearance,
        icon: Icons.palette_outlined,
        title: loc.settings_section_appearance_language,
        subtitle: loc.settings_section_appearance_language_desc,
      ),
      _SettingsCategoryInfo(
        id: _SettingsCategory.help,
        icon: Icons.support_outlined,
        title: loc.help_and_setup,
        subtitle: loc.settings_section_help_desc,
      ),
    ]);
    return items;
  }

  List<_SettingsCategoryInfo> _filteredCategories(AppLocalizations loc) {
    final q = _query.trim().toLowerCase();
    final all = _allCategories(loc);
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q),
        )
        .toList();
  }

  void _selectCategory(_SettingsCategory id) {
    setState(() => _selected = id);
  }

  void _clearCategory() {
    setState(() => _selected = null);
  }

  String _appBarTitle(
    AppLocalizations loc, {
    required bool isWide,
    required _SettingsCategory? selected,
  }) {
    if (isWide || selected == null) return loc.settings;
    for (final c in _allCategories(loc)) {
      if (c.id == selected) return c.title;
    }
    return loc.settings;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final categories = _filteredCategories(loc);
    var selected = _selected;
    if (isWide) {
      selected ??= categories.isNotEmpty ? categories.first.id : null;
      if (selected != null &&
          categories.isNotEmpty &&
          !categories.any((c) => c.id == selected)) {
        selected = categories.first.id;
      }
    }

    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        elevation: 0,
        shadowColor: Colors.transparent,
        leading: (!isWide && selected != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearCategory,
                tooltip: loc.settings_back_to_categories,
              )
            : null,
        title: Text(
          _appBarTitle(loc, isWide: isWide, selected: selected),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: loc.settings_search_hint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColor.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        loc.settings_no_results,
                        style: _subtitleStyle,
                      ),
                    )
                  : isWide
                      ? _buildWideBody(loc, categories, selected!)
                      : (selected == null
                          ? _buildCategoryHub(loc, categories)
                          : _buildCategoryDetailScroll(loc, selected)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideBody(
    AppLocalizations loc,
    List<_SettingsCategoryInfo> categories,
    _SettingsCategory selected,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: _buildCategoryList(categories, selected),
        ),
        VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade200),
        Expanded(child: _buildCategoryDetailScroll(loc, selected)),
      ],
    );
  }

  Widget _buildCategoryHub(
    AppLocalizations loc,
    List<_SettingsCategoryInfo> categories,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _buildSectionCard(
          children: [
            for (var i = 0; i < categories.length; i++) ...[
              if (i > 0) _buildDivider(),
              _buildCategoryHubTile(categories[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryList(
    List<_SettingsCategoryInfo> categories,
    _SettingsCategory selected,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat.id == selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: isSelected
                ? AppColor.primary.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _selectCategory(cat.id),
              borderRadius: BorderRadius.circular(12),
              hoverColor: _tileHover,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColor.primary.withOpacity(0.14)
                            : AppColor.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        cat.icon,
                        size: 20,
                        color: AppColor.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHubTile(_SettingsCategoryInfo cat) {
    return _buildTile(
      icon: cat.icon,
      title: cat.title,
      subtitle: cat.subtitle,
      onTap: () => _selectCategory(cat.id),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
    );
  }

  Widget _buildCategoryDetailScroll(
    AppLocalizations loc,
    _SettingsCategory selected,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      child: _buildCategoryContent(loc, selected),
    );
  }

  Widget _buildCategoryContent(
    AppLocalizations loc,
    _SettingsCategory selected,
  ) {
    switch (selected) {
      case _SettingsCategory.ordersBilling:
        return _buildOrdersBillingContent(loc);
      case _SettingsCategory.hardware:
        return _buildHardwareContent(loc);
      case _SettingsCategory.syncDevices:
        return _buildSyncDevicesContent(loc);
      case _SettingsCategory.billingPlan:
        return _buildBillingPlanContent(loc);
      case _SettingsCategory.notifications:
        return _buildNotificationsContent(loc);
      case _SettingsCategory.appearance:
        return _buildAppearanceContent(loc);
      case _SettingsCategory.help:
        return _buildHelpContent(loc);
    }
  }

  Widget _buildOrdersBillingContent(AppLocalizations loc) {
    return _buildSection(
      loc.settings_section_orders_billing,
      _withDividers([
        _buildSwitchTile(
          icon: Icons.qr_code_2_outlined,
          title: loc.show_qr_on_bill,
          subtitle: loc.show_qr_on_bill_subtitle,
          value: controller.showQrOnBill,
          onChanged: controller.setShowQrOnBill,
        ),
        _buildSwitchTile(
          icon: Icons.edit_note_outlined,
          title: loc.add_details_on_create_order,
          subtitle: loc.add_details_on_create_order_subtitle,
          value: controller.showAddDetailsOnCreateOrder,
          onChanged: controller.setShowAddDetailsOnCreateOrder,
        ),
        _buildActionOrNavTile(
          icon: Icons.local_offer_outlined,
          title: loc.settings_offers_promotions,
          subtitle: loc.settings_offers_promotions_subtitle,
          onTap: () => Modular.to.pushNamed(HomeMainRoutes.promotions),
          showChevron: true,
        ),
        Obx(
          () => _buildActionOrNavTile(
            icon: Icons.folder_open_outlined,
            title: loc.download_path,
            subtitle: controller.downloadPath.value.isEmpty
                ? loc.default_downloads_folder
                : controller.downloadPath.value,
            onTap: controller.pickDownloadPath,
            showChevron: true,
          ),
        ),
      ]),
    );
  }

  Widget _buildHardwareContent(AppLocalizations loc) {
    return _buildSection(
      loc.settings_section_hardware,
      _withDividers([
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSwitchTile(
              icon: Icons.point_of_sale_outlined,
              title: loc.cash_drawer,
              subtitle: loc.cash_drawer_subtitle,
              value: controller.cashDrawerEnabled,
              onChanged: controller.setCashDrawerEnabled,
            ),
            Obx(() {
              if (!controller.cashDrawerEnabled.value) {
                return const SizedBox.shrink();
              }
              final openOnCash =
                  controller.openCashDrawerOnCashPayment.value;
              final selected = cashDrawerPinFromStorage(
                controller.cashDrawerPin.value,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.payments_outlined,
                    title: loc.open_cash_drawer_on_cash_payment,
                    subtitle:
                        loc.open_cash_drawer_on_cash_payment_subtitle,
                    trailing: SwitchWithOnOffLabel(
                      value: openOnCash,
                      onChanged: controller.setOpenCashDrawerOnCashPayment,
                      activeColor: AppColor.primary,
                    ),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.settings_input_component_outlined,
                    title: loc.cash_drawer_kick_pin,
                    subtitle: loc.cash_drawer_kick_pin_subtitle,
                    trailing: SegmentedButton<CashDrawerPin>(
                      segments: [
                        ButtonSegment(
                          value: CashDrawerPin.pin2,
                          label: Text(loc.cash_drawer_pin_2),
                        ),
                        ButtonSegment(
                          value: CashDrawerPin.pin5,
                          label: Text(loc.cash_drawer_pin_5),
                        ),
                      ],
                      selected: {selected},
                      onSelectionChanged: (set) {
                        controller.setCashDrawerPin(set.first);
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        if (Get.isRegistered<HomeScreenController>())
          Obx(() {
            Get.find<HomeScreenController>().selectedOutlet.value;
            if (!HomeMainRoutes.outletIsCafeOrRestaurant()) {
              return const SizedBox.shrink();
            }
            final kotOn = controller.kotModeEnabled.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTile(
                  icon: Icons.restaurant_menu_outlined,
                  title: loc.kot_mode,
                  subtitle: loc.printKOT_desc.replaceAll('\n', ' '),
                  trailing: SwitchWithOnOffLabel(
                    value: kotOn,
                    onChanged: controller.setKotMode,
                    activeColor: AppColor.primary,
                  ),
                ),
                if (kotOn) ...[
                  _buildDivider(),
                  _buildActionOrNavTile(
                    icon: Icons.open_in_browser_rounded,
                    title: loc.kitchen_display_in_browser,
                    subtitle: loc.kitchen_display_browser_subtitle,
                    onTap: KitchenDisplayBrowser.open,
                  ),
                ],
              ],
            );
          })
        else if (HomeMainRoutes.outletIsCafeOrRestaurant())
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSwitchTile(
                icon: Icons.restaurant_menu_outlined,
                title: loc.kot_mode,
                subtitle: loc.printKOT_desc.replaceAll('\n', ' '),
                value: controller.kotModeEnabled,
                onChanged: controller.setKotMode,
              ),
              Obx(() {
                if (!controller.kotModeEnabled.value) {
                  return const SizedBox.shrink();
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDivider(),
                    _buildActionOrNavTile(
                      icon: Icons.open_in_browser_rounded,
                      title: loc.kitchen_display_in_browser,
                      subtitle: loc.kitchen_display_browser_subtitle,
                      onTap: KitchenDisplayBrowser.open,
                    ),
                  ],
                );
              }),
            ],
          ),
      ]),
    );
  }

  Widget _buildSyncDevicesContent(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          loc.settings_section_sync_devices,
          _withDividers([
            _buildSwitchTile(
              icon: Icons.sync_rounded,
              title: loc.sync_devices,
              subtitle: loc.sync_across_multiple_devices,
              value: controller.autoSyncEnabled,
              onChanged: controller.setAutoSyncEnabled,
            ),
            _buildSwitchTile(
              icon: Icons.cloud_off_outlined,
              title: loc.offline_mode,
              subtitle: loc.offline_mode_subtitle,
              value: controller.offlineModeEnabled,
              onChanged: controller.setOfflineModeEnabled,
            ),
          ]),
        ),
        const Gap(24),
        _buildSection(loc.settings_section_local_store, [
          _buildSwitchTile(
            icon: Icons.wifi_tethering,
            title: loc.local_store_host_mode,
            subtitle: loc.local_store_host_mode_subtitle,
            value: controller.localStoreHostEnabled,
            onChanged: controller.setLocalStoreHostEnabled,
          ),
          Obx(() {
            if (!controller.localStoreHostEnabled.value) {
              return const SizedBox.shrink();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDivider(),
                _buildActionOrNavTile(
                  icon: Icons.qr_code_2_rounded,
                  title: loc.local_store_show_qr,
                  subtitle: loc.local_store_show_qr_subtitle,
                  onTap: () => Modular.to.pushNamed(
                    HomeMainRoutes.localStoreHost,
                  ),
                  showChevron: true,
                ),
              ],
            );
          }),
          Obx(() {
            final joined = controller.localStoreClientJoined.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDivider(),
                if (joined) ...[
                  _buildTile(
                    icon: Icons.devices_other_outlined,
                    title: loc.local_store_joined_status(
                      controller.localStoreClientLabel.value,
                    ),
                    subtitle: loc.local_store_leave_host_subtitle,
                    trailing: TextButton(
                      onPressed: controller.leaveLocalStoreHost,
                      child: Text(loc.local_store_leave_host),
                    ),
                  ),
                ] else
                  _buildActionOrNavTile(
                    icon: Icons.link_rounded,
                    title: loc.local_store_join_other,
                    subtitle: loc.local_store_join_other_subtitle,
                    onTap: controller.joinLocalStoreHost,
                    showChevron: true,
                  ),
              ],
            );
          }),
        ]),
      ],
    );
  }

  Widget _buildBillingPlanContent(AppLocalizations loc) {
    return _buildSection(loc.settings_section_billing, [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.billing_mode_title, style: _titleStyle),
            const Gap(4),
            Text(loc.billing_mode_subtitle, style: _subtitleStyle),
          ],
        ),
      ),
      Obx(
        () => BillingModeSelector(
          selected: controller.billingAccessMode.value,
          enabled: controller.canChangeBillingMode,
          onSelected: controller.requestBillingModeChange,
          subscriptionTitle: loc.billing_mode_subscription,
          subscriptionSubtitle: loc.billing_mode_subscription_desc,
          walletTitle: loc.billing_mode_wallet,
          walletSubtitle: loc.billing_mode_wallet_desc,
        ),
      ),
    ]);
  }

  Widget _buildNotificationsContent(AppLocalizations loc) {
    return _buildSection(
      loc.settings_section_notifications,
      _withDividers([
        _buildSwitchTile(
          icon: Icons.notifications_outlined,
          title: loc.settings_section_notifications,
          subtitle: loc.settings_notifications_subtitle,
          value: controller.notificationsEnabled,
          onChanged: controller.setNotificationsEnabled,
        ),
        _buildTile(
          icon: Icons.inbox_outlined,
          title: loc.notification_history,
          subtitle: loc.notification_history_subtitle,
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 20,
          ),
          onTap: () => Modular.to.pushNamed(HomeMainRoutes.notifications),
        ),
      ]),
    );
  }

  Widget _buildAppearanceContent(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(loc.settings_section_appearance, [
          Obx(
            () => _buildTile(
              icon: Icons.palette_outlined,
              title: loc.theme_color,
              subtitle: themeController.selectedThemeColorName,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: themeController.themeColor.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
              onTap: () => _showThemeColorPicker(context, loc),
            ),
          ),
        ]),
        const Gap(24),
        _buildSection(loc.settings_section_language_region, [
          _buildActionOrNavTile(
            icon: Icons.language,
            title: loc.language,
            subtitle: loc.change_app_language,
            onTap: () => showLanguagePickerDialog(context),
            showChevron: true,
          ),
        ]),
      ],
    );
  }

  Widget _buildHelpContent(AppLocalizations loc) {
    return _buildSection(loc.help_and_setup, [
      _buildActionOrNavTile(
        icon: Icons.support_outlined,
        title: loc.help_and_setup,
        subtitle: loc.help_subtitle,
        onTap: () => Modular.to.pushNamed(HomeMainRoutes.helpSetup),
        showChevron: true,
      ),
    ]);
  }


  static const double _sidePadding = 16;
  static const double _tileVerticalPadding = 12;
  static const double _tileHorizontalPadding = 16;
  static const double _tileIconSize = 22;
  static const double _tileIconPadding = 10;
  static const double _tileRadius = 12;
  static const Color _mutedText = Color(0xFF757575);
  static const Color _tileHover = Color(0x22000000);

  TextStyle get _sectionHeaderStyle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _mutedText,
    letterSpacing: 0.5,
  );

  TextStyle get _titleStyle => const TextStyle(
    fontSize: 15,
    color: Colors.black87,
    fontWeight: FontWeight.w600,
  );

  TextStyle get _subtitleStyle =>
      const TextStyle(fontSize: 12, color: _mutedText);

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(title, style: _sectionHeaderStyle),
        ),
        const Gap(8),
        _buildSectionCard(children: children),
      ],
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    color: Colors.grey[200],
    indent: _sidePadding,
    endIndent: _sidePadding,
  );

  List<Widget> _withDividers(List<Widget> tiles) {
    if (tiles.isEmpty) return const [];
    final result = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      result.add(tiles[i]);
      if (i != tiles.length - 1) result.add(_buildDivider());
    }
    return result;
  }

  Widget _buildLeadingIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(_tileIconPadding),
      decoration: BoxDecoration(
        color: AppColor.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColor.primary, size: _tileIconSize),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: _tileHover,
      splashColor: Colors.transparent,
      highlightColor: _tileHover,
      mouseCursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(_tileRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _tileHorizontalPadding,
          vertical: _tileVerticalPadding,
        ),
        child: Row(
          children: [
            _buildLeadingIcon(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _subtitleStyle),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required RxBool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Obx(
        () => SwitchWithOnOffLabel(
          value: value.value,
          onChanged: onChanged,
          activeColor: AppColor.primary,
        ),
      ),
    );
  }

  Widget _buildActionOrNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showChevron = true,
  }) {
    return _buildTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: showChevron
          ? Icon(Icons.chevron_right, color: Colors.grey[400], size: 20)
          : const SizedBox.shrink(),
    );
  }

  static const double _dialogRadius = 8;

  Future<void> _showThemeColorPicker(
    BuildContext context,
    AppLocalizations loc,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_dialogRadius),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
            child: Obx(() {
              final selectedColor = themeController.themeColor.value;
              final selected =
                  selectedColor.value & 0xFFFFFFFF;
              final customs = themeController.customThemeColors.toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.theme_color,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          tooltip: loc.close,
                          icon: Icon(Icons.close, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCurrentThemeColorCard(
                            color: selectedColor,
                            name: themeController.selectedThemeColorName,
                          ),
                          const SizedBox(height: 20),
                          _buildThemeSectionLabel(loc.presets),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final item in ThemeController.colorOptions)
                                _ThemeColorSwatch(
                                  color: item.value,
                                  label: item.key,
                                  selected:
                                      (item.value.value & 0xFFFFFFFF) ==
                                      selected,
                                  onTap: () =>
                                      themeController.setThemeColor(item.value),
                                ),
                            ],
                          ),
                          if (customs.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildThemeSectionLabel(loc.my_colors),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final argb in customs)
                                  _ThemeColorSwatch(
                                    color: Color(argb & 0xFFFFFFFF),
                                    label: ThemeController.hexRgbString(
                                      Color(argb & 0xFFFFFFFF),
                                    ),
                                    selected:
                                        (argb & 0xFFFFFFFF) == selected,
                                    onTap: () => themeController.setThemeColor(
                                      Color(argb & 0xFFFFFFFF),
                                    ),
                                    onDelete: () => themeController
                                        .removeCustomThemeColor(
                                      Color(argb & 0xFFFFFFFF),
                                    ),
                                    deleteTooltip: loc.delete,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          _buildThemeSectionLabel(loc.custom_hex),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => _pickCustomThemeColor(
                              dialogContext,
                              loc,
                            ),
                            icon: const Icon(Icons.colorize_rounded, size: 18),
                            label: Text(loc.custom_hex),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColor.primary,
                              side: BorderSide(
                                color: AppColor.primary.withOpacity(0.35),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  _dialogRadius,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCurrentThemeColorCard({
    required Color color,
    required String name,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_dialogRadius),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_dialogRadius),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ThemeController.hexRgbString(color),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Future<void> _pickCustomThemeColor(
    BuildContext context,
    AppLocalizations loc,
  ) async {
    final start = themeController.themeColor.value;
    final picked = await showColorPickerDialog(
      context,
      start,
      title: Text(
        loc.custom_hex,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      width: 40,
      height: 40,
      spacing: 6,
      runSpacing: 6,
      borderRadius: _dialogRadius,
      wheelDiameter: 190,
      wheelWidth: 18,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      showColorName: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        longPressMenu: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        dialogActionButtons: true,
      ),
      constraints: const BoxConstraints(
        minHeight: 480,
        minWidth: 320,
        maxWidth: 420,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_dialogRadius),
      ),
    );

    if ((picked.value & 0xFFFFFFFF) == (start.value & 0xFFFFFFFF)) return;
    await themeController.registerCustomThemeColor(picked);
    await themeController.setThemeColor(picked);
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onDelete,
    this.deleteTooltip,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final swatch = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.black87 : Colors.grey.shade300,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: 20,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              )
            : null,
      ),
    );

    return Tooltip(
      message: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, bottom: 0, child: swatch),
            if (onDelete != null)
              Positioned(
                top: -2,
                right: -2,
                child: Tooltip(
                  message: deleteTooltip ?? 'Delete',
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: InkWell(
                      onTap: onDelete,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
