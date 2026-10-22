// ignore_for_file: unnecessary_null_comparison
import 'dart:convert';

import 'package:billkaro/app/services/Modals/login_response.dart';
import 'package:billkaro/app/services/Modals/tables/tables_response.dart';
import 'package:billkaro/utils/po_print_orientation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPref {
  final SharedPreferences _preferences;
  static String keyUsers = 'saved_users';
  static const String keyCurrentUser = 'current_user';
  static const String keyToken = 'token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser = 'user';
  static const String keySelectedOutlet = 'selected_outlet';
  static const String prefixUserPassword = 'user_password_';
  static const String keyRecentusers = 'recent_users';
  static const String keyIsKOT = 'is_kot';
  static const String keyShowcaseCompleted = 'showcase_completed';
  static const String keyIsListView = 'is_list_view';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyKitchenBumpLastSince = 'kitchen_bump_last_since_iso';
  static const String keyKitchenBumpNotifiedKeys = 'kitchen_bump_notified_keys';
  static const String keyKitchenNewOrderNotifiedKeys =
      'kitchen_new_order_notified_keys';
  static const String keyAppNotificationsJson = 'app_notifications_json';
  static const String keyShowQrOnBill = 'show_qr_on_bill';
  static const String keyShowLogoOnBill = 'show_logo_on_bill';
  static const String keyShowOutletNameOnBill = 'show_outlet_name_on_bill';
  static const String keyShowBillHeader = 'show_bill_header';
  static const String keyShowBillFooter = 'show_bill_footer';
  static const String keyShowGstSplitOnBill = 'show_gst_split_on_bill';
  static const String keyShowAddDetailsOnCreateOrder =
      'show_add_details_on_create_order';
  static const String keyDownloadPath = 'download_path';
  static const String keyQrMenuBaseUrl = 'qr_menu_base_url';
  static const String keyInventoryEnabled = 'inventory_enabled';
  static const String keyAutoSyncEnabled = 'auto_sync_enabled';
  static const String keyOfflineModeEnabled = 'offline_mode_enabled';
  static const String keyCashDrawerEnabled = 'cash_drawer_enabled';
  static const String keyOpenCashDrawerOnCashPayment =
      'open_cash_drawer_on_cash_payment';
  static const String keyCashDrawerPin = 'cash_drawer_pin';
  static const String keyPoDefaultTermsPrefix = 'po_default_terms_';
  static const String keyPoPrintOrientation = 'po_print_orientation';

  /// True when the user signed in via the staff tab (`auth/staff/login`).
  static const String keyStaffSession = 'staff_session';
  static const String keyStaffPermissions = 'staff_permissions';
  static const String keyCachedTablesPrefix = 'cached_tables_';
  static const String keyCachedTableSectionsPrefix = 'cached_table_sections_';
  static const String keyWalletBalancePrefix = 'wallet_balance_';
  static const String keyWalletHistoryPrefix = 'wallet_history_';
  static const String keyWalletInitializedPrefix = 'wallet_initialized_';
  static const String keyBillingAccessModePrefix = 'billing_access_mode_';
  static const String keyPendingPlatformFeeOrderIds =
      'pending_platform_fee_order_ids';

  /// LAN store host (Petpooja-style offline Wi‑Fi server on this PC).
  static const String keyLocalStoreHostEnabled = 'local_store_host_enabled';
  static const String keyLocalStorePort = 'local_store_port';
  static const String keyLocalStoreJoinToken = 'local_store_join_token';
  static const String keyLocalStoreClientBaseUrl = 'local_store_client_base_url';
  static const String keyLocalStoreClientToken = 'local_store_client_token';
  static const String keyLocalStoreClientOutletName =
      'local_store_client_outlet_name';
  static const String keyLocalStoreDeviceId = 'local_store_device_id';

  AppPref(this._preferences);

  /// Login
  bool get isLogin => token.isNotEmpty;

  String get token => _preferences.getString('token') ?? '';
  set token(String value) => _preferences.setString('token', value);

  String get refreshToken =>
      _preferences.getString(keyRefreshToken) ?? '';
  set refreshToken(String value) =>
      _preferences.setString(keyRefreshToken, value);

  User? get user => _preferences.containsKey(keyUser)
      ? User.fromJson(
          jsonDecode(_preferences.getString(keyUser) ?? '')
              as Map<String, dynamic>,
        )
      : null;

  set user(User? value) {
    if (value == null) {
      _preferences.remove(keyUser);
    } else {
      _preferences.setString(keyUser, jsonEncode(value.toJson()));
    }
  }

  /// 👉 Selected Outlet
  OutletData? get selectedOutlet {
    if (!_preferences.containsKey(keySelectedOutlet)) return null;
    try {
      return OutletData.fromJson(
        jsonDecode(_preferences.getString(keySelectedOutlet) ?? ''),
      );
    } catch (e) {
      return null;
    }
  }

  set selectedOutlet(OutletData? value) {
    if (value == null) {
      _preferences.remove(keySelectedOutlet);
    } else {
      _preferences.setString(keySelectedOutlet, jsonEncode(value.toJson()));
    }
  }

  /// Get all outlets from user
  List<OutletData> get allOutlets => user?.outletData ?? [];

  /// Owner account id for outlet/user APIs (staff sessions use [User.userId]).
  String? get ownerUserId {
    final u = user;
    if (u == null) return null;
    if (u.role == 'staff') {
      final ownerId = u.userId?.trim();
      return (ownerId == null || ownerId.isEmpty) ? null : ownerId;
    }
    final id = (u.userId ?? u.id)?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Business owner user id for order/report APIs (never the staff record id).
  String? get ordersApiUserId => ownerUserId;

  /// Check if outlet is selected
  bool get hasSelectedOutlet => selectedOutlet != null;

  /// Select outlet by ID
  bool selectOutletById(String outletId) {
    final outlets = allOutlets;
    try {
      final outlet = outlets.firstWhere((o) => o.id == outletId);
      selectedOutlet = outlet;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Select first outlet (useful for auto-selection)
  bool selectFirstOutlet() {
    final outlets = allOutlets;
    if (outlets.isEmpty) return false;
    selectedOutlet = outlets.first;
    return true;
  }

  bool selectLastOutlet() {
    final outlets = allOutlets;
    if (outlets.isEmpty) return false;
    selectedOutlet = outlets.last;
    return true;
  }

  /// Clear selected outlet
  void clearSelectedOutlet() {
    selectedOutlet = null;
  }

  /// 👉 KOT flag
  bool get isKOT => _preferences.getBool(keyIsKOT) ?? false;
  set isKOT(bool value) => _preferences.setBool(keyIsKOT, value);

  /// 👉 Billing View preference (true = List View, false = Image View)
  bool get isListView => _preferences.getBool(keyIsListView) ?? false;
  set isListView(bool value) => _preferences.setBool(keyIsListView, value);

  /// 👉 Showcase completion flag
  bool get isShowcaseCompleted =>
      _preferences.getBool(keyShowcaseCompleted) ?? false;
  set isShowcaseCompleted(bool value) =>
      _preferences.setBool(keyShowcaseCompleted, value);

  /// 👉 Notifications enabled
  bool get notificationsEnabled =>
      _preferences.getBool(keyNotificationsEnabled) ?? true;
  set notificationsEnabled(bool value) =>
      _preferences.setBool(keyNotificationsEnabled, value);

  String get kitchenBumpLastSinceIso =>
      _preferences.getString(keyKitchenBumpLastSince) ?? '';
  set kitchenBumpLastSinceIso(String value) =>
      _preferences.setString(keyKitchenBumpLastSince, value);

  String get kitchenBumpNotifiedKeys =>
      _preferences.getString(keyKitchenBumpNotifiedKeys) ?? '';
  set kitchenBumpNotifiedKeys(String value) =>
      _preferences.setString(keyKitchenBumpNotifiedKeys, value);

  void clearKitchenBumpNotifiedKeys() =>
      _preferences.remove(keyKitchenBumpNotifiedKeys);

  String get kitchenNewOrderNotifiedKeys =>
      _preferences.getString(keyKitchenNewOrderNotifiedKeys) ?? '';
  set kitchenNewOrderNotifiedKeys(String value) =>
      _preferences.setString(keyKitchenNewOrderNotifiedKeys, value);

  void clearKitchenNewOrderNotifiedKeys() =>
      _preferences.remove(keyKitchenNewOrderNotifiedKeys);

  String get appNotificationsJson =>
      _preferences.getString(keyAppNotificationsJson) ?? '';
  set appNotificationsJson(String value) =>
      _preferences.setString(keyAppNotificationsJson, value);

  /// 👉 Show QR code on bill/invoice (UPI scan to pay)
  bool get showQrOnBill => _preferences.getBool(keyShowQrOnBill) ?? true;
  set showQrOnBill(bool value) => _preferences.setBool(keyShowQrOnBill, value);

  bool get showLogoOnBill => _preferences.getBool(keyShowLogoOnBill) ?? true;
  set showLogoOnBill(bool value) =>
      _preferences.setBool(keyShowLogoOnBill, value);

  /// 👉 Show selected outlet's name under the brand name on printed bills
  bool get showOutletNameOnBill =>
      _preferences.getBool(keyShowOutletNameOnBill) ?? true;
  set showOutletNameOnBill(bool value) =>
      _preferences.setBool(keyShowOutletNameOnBill, value);

  /// 👉 Show the header / footer messages on bills (messages are kept either way)
  bool get showBillHeader => _preferences.getBool(keyShowBillHeader) ?? true;
  set showBillHeader(bool value) =>
      _preferences.setBool(keyShowBillHeader, value);

  bool get showBillFooter => _preferences.getBool(keyShowBillFooter) ?? true;
  set showBillFooter(bool value) =>
      _preferences.setBool(keyShowBillFooter, value);

  /// 👉 Show GST as CGST + SGST on bills
  bool get showGstSplitOnBill =>
      _preferences.getBool(keyShowGstSplitOnBill) ?? true;
  set showGstSplitOnBill(bool value) =>
      _preferences.setBool(keyShowGstSplitOnBill, value);

  /// CGST/SGST only apply to a GST-registered outlet (one with a GSTIN).
  bool get splitGstOnBill =>
      showGstSplitOnBill &&
      (selectedOutlet?.gstinNumber?.trim().isNotEmpty ?? false);

  /// Selected outlet's message shown below the logo on bills and the QR menu.
  String get billHeaderMessage =>
      selectedOutlet?.billHeaderMessage?.trim() ?? '';

  /// Selected outlet's message shown at the bottom of bills.
  String get billFooterMessage =>
      selectedOutlet?.billFooterMessage?.trim() ?? '';

  /// Inventory management (stock, suppliers, recipes, purchase orders).
  bool get inventoryEnabled =>
      _preferences.getBool(keyInventoryEnabled) ?? true;
  set inventoryEnabled(bool value) =>
      _preferences.setBool(keyInventoryEnabled, value);

  /// 👉 Show "Add Details" on create order (customer, table, discounts, etc.)
  bool get showAddDetailsOnCreateOrder =>
      _preferences.getBool(keyShowAddDetailsOnCreateOrder) ?? true;
  set showAddDetailsOnCreateOrder(bool value) =>
      _preferences.setBool(keyShowAddDetailsOnCreateOrder, value);

  /// 👉 Preferred download directory for saved files
  String get downloadPath => _preferences.getString(keyDownloadPath) ?? '';
  set downloadPath(String value) =>
      _preferences.setString(keyDownloadPath, value);

  /// 👉 Custom base URL for table QR menu (empty = use API URL from .env)
  String get qrMenuBaseUrl => _preferences.getString(keyQrMenuBaseUrl) ?? '';
  set qrMenuBaseUrl(String value) =>
      _preferences.setString(keyQrMenuBaseUrl, value.trim());

  /// 👉 Auto sync enabled (offline -> online reconciliation)
  bool get autoSyncEnabled => _preferences.getBool(keyAutoSyncEnabled) ?? true;
  set autoSyncEnabled(bool value) =>
      _preferences.setBool(keyAutoSyncEnabled, value);

  /// Allow creating/saving orders when internet is unavailable.
  bool get offlineModeEnabled =>
      _preferences.getBool(keyOfflineModeEnabled) ?? true;
  set offlineModeEnabled(bool value) =>
      _preferences.setBool(keyOfflineModeEnabled, value);

  /// This PC acts as the in-store LAN host for staff devices.
  bool get localStoreHostEnabled =>
      _preferences.getBool(keyLocalStoreHostEnabled) ?? false;
  set localStoreHostEnabled(bool value) =>
      _preferences.setBool(keyLocalStoreHostEnabled, value);

  int get localStorePort =>
      _preferences.getInt(keyLocalStorePort) ?? 47831;
  set localStorePort(int value) =>
      _preferences.setInt(keyLocalStorePort, value);

  String get localStoreJoinToken =>
      _preferences.getString(keyLocalStoreJoinToken) ?? '';
  set localStoreJoinToken(String value) =>
      _preferences.setString(keyLocalStoreJoinToken, value);

  /// Secondary till / waiter PC joined to another host on the same Wi‑Fi.
  String get localStoreClientBaseUrl =>
      _preferences.getString(keyLocalStoreClientBaseUrl) ?? '';
  set localStoreClientBaseUrl(String value) =>
      _preferences.setString(keyLocalStoreClientBaseUrl, value.trim());

  String get localStoreClientToken =>
      _preferences.getString(keyLocalStoreClientToken) ?? '';
  set localStoreClientToken(String value) =>
      _preferences.setString(keyLocalStoreClientToken, value.trim());

  String get localStoreClientOutletName =>
      _preferences.getString(keyLocalStoreClientOutletName) ?? '';
  set localStoreClientOutletName(String value) =>
      _preferences.setString(keyLocalStoreClientOutletName, value.trim());

  bool get localStoreClientJoined =>
      localStoreClientBaseUrl.isNotEmpty && localStoreClientToken.isNotEmpty;

  String get localStoreDeviceId {
    var id = _preferences.getString(keyLocalStoreDeviceId) ?? '';
    if (id.isEmpty) {
      id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
      _preferences.setString(keyLocalStoreDeviceId, id);
    }
    return id;
  }

  void clearLocalStoreClient() {
    _preferences.remove(keyLocalStoreClientBaseUrl);
    _preferences.remove(keyLocalStoreClientToken);
    _preferences.remove(keyLocalStoreClientOutletName);
  }

  /// 👉 RJ11 cash drawer connected to bill printer DK port
  bool get cashDrawerEnabled =>
      _preferences.getBool(keyCashDrawerEnabled) ?? false;
  set cashDrawerEnabled(bool value) =>
      _preferences.setBool(keyCashDrawerEnabled, value);

  /// 👉 Open drawer automatically when billing with Cash payment
  bool get openCashDrawerOnCashPayment =>
      _preferences.getBool(keyOpenCashDrawerOnCashPayment) ?? true;
  set openCashDrawerOnCashPayment(bool value) =>
      _preferences.setBool(keyOpenCashDrawerOnCashPayment, value);

  /// Drawer kick pin: `pin2` (most RJ11 drawers) or `pin5`
  String get cashDrawerPin =>
      _preferences.getString(keyCashDrawerPin) ?? 'pin2';
  set cashDrawerPin(String value) =>
      _preferences.setString(keyCashDrawerPin, value);

  /// Default landscape — PO line-item tables fit wide layouts better.
  PoPrintOrientation get poPrintOrientation => PoPrintOrientation.fromStorage(
        _preferences.getString(keyPoPrintOrientation),
      );

  set poPrintOrientation(PoPrintOrientation value) =>
      _preferences.setString(keyPoPrintOrientation, value.storageValue);

  String poDefaultTermsForOutlet(String outletId) {
    final id = outletId.trim();
    if (id.isEmpty) return '';
    return _preferences.getString('$keyPoDefaultTermsPrefix$id') ?? '';
  }

  void setPoDefaultTermsForOutlet(String outletId, String value) {
    final id = outletId.trim();
    if (id.isEmpty) return;
    final trimmed = value.trim();
    final key = '$keyPoDefaultTermsPrefix$id';
    if (trimmed.isEmpty) {
      _preferences.remove(key);
    } else {
      _preferences.setString(key, trimmed);
    }
  }

  /// 👉 Staff sign-in path (role from API may be missing or inconsistent).
  bool get isStaffSession => _preferences.getBool(keyStaffSession) ?? false;
  set isStaffSession(bool value) =>
      _preferences.setBool(keyStaffSession, value);

  List<String> get staffPermissions {
    final raw = _preferences.getString(keyStaffPermissions);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  set staffPermissions(List<String> value) {
    if (value.isEmpty) {
      _preferences.remove(keyStaffPermissions);
    } else {
      _preferences.setString(keyStaffPermissions, jsonEncode(value));
    }
  }

  /// Cached outlet table layout for offline table screen
  List<TableData>? getCachedOutletTables(String outletId) {
    final tables = <TableData>[];
    for (final map in _decodeJsonObjectList(
      _preferences.getString('$keyCachedTablesPrefix$outletId'),
    )) {
      try {
        tables.add(TableData.fromJson(map));
      } catch (_) {}
    }
    return tables.isEmpty ? null : tables;
  }

  void setCachedOutletTables(String outletId, List<TableData> tables) {
    _preferences.setString(
      '$keyCachedTablesPrefix$outletId',
      jsonEncode(tables.map((e) => e.toJson()).toList()),
    );
  }

  List<TableSectionModel>? getCachedOutletTableSections(String outletId) {
    final sections = <TableSectionModel>[];
    for (final map in _decodeJsonObjectList(
      _preferences.getString('$keyCachedTableSectionsPrefix$outletId'),
    )) {
      try {
        final section = TableSectionModel.fromJson(map);
        if (section.name.trim().isEmpty) continue;
        sections.add(section);
      } catch (_) {}
    }
    return sections.isEmpty ? null : sections;
  }

  void setCachedOutletTableSections(
    String outletId,
    List<TableSectionModel> sections,
  ) {
    _preferences.setString(
      '$keyCachedTableSectionsPrefix$outletId',
      jsonEncode(sections.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearCachedOutletTables() async {
    final keys = _preferences.getKeys().where(
      (k) =>
          k.startsWith(keyCachedTablesPrefix) ||
          k.startsWith(keyCachedTableSectionsPrefix),
    );
    for (final key in keys) {
      await _preferences.remove(key);
    }
  }

  static List<Map<String, dynamic>> _decodeJsonObjectList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _walletOutletKey(String? outletId) {
    final id = outletId?.trim();
    return (id == null || id.isEmpty) ? 'default' : id;
  }

  double walletBalanceForOutlet(String? outletId) =>
      _preferences.getDouble(
        '${keyWalletBalancePrefix}${_walletOutletKey(outletId)}',
      ) ??
      0;

  void setWalletBalanceForOutlet(String? outletId, double balance) {
    _preferences.setDouble(
      '${keyWalletBalancePrefix}${_walletOutletKey(outletId)}',
      balance,
    );
  }

  String? walletHistoryJsonForOutlet(String? outletId) =>
      _preferences.getString(
        '${keyWalletHistoryPrefix}${_walletOutletKey(outletId)}',
      );

  void setWalletHistoryJsonForOutlet(String? outletId, String json) {
    _preferences.setString(
      '${keyWalletHistoryPrefix}${_walletOutletKey(outletId)}',
      json,
    );
  }

  bool isWalletInitializedForOutlet(String? outletId) =>
      _preferences.getBool(
        '${keyWalletInitializedPrefix}${_walletOutletKey(outletId)}',
      ) ??
      false;

  void setWalletInitializedForOutlet(String? outletId, bool value) {
    _preferences.setBool(
      '${keyWalletInitializedPrefix}${_walletOutletKey(outletId)}',
      value,
    );
  }

  /// Per-outlet billing access mode (`subscription` | `wallet`).
  String? billingAccessModeRawForOutlet(String? outletId) =>
      _preferences.getString(
        '${keyBillingAccessModePrefix}${_walletOutletKey(outletId)}',
      );

  void setBillingAccessModeRawForOutlet(String? outletId, String mode) {
    _preferences.setString(
      '${keyBillingAccessModePrefix}${_walletOutletKey(outletId)}',
      mode,
    );
  }

  List<String> get pendingPlatformFeeOrderIds =>
      _preferences.getStringList(keyPendingPlatformFeeOrderIds) ?? const [];

  void addPendingPlatformFeeOrderId(String orderId) {
    final id = orderId.trim();
    if (id.isEmpty) return;
    final next = {...pendingPlatformFeeOrderIds, id}.toList();
    _preferences.setStringList(keyPendingPlatformFeeOrderIds, next);
  }

  /// Returns true if [orderId] was pending and removes it.
  bool consumePendingPlatformFeeOrderId(String orderId) {
    final id = orderId.trim();
    if (id.isEmpty) return false;
    final current = pendingPlatformFeeOrderIds;
    if (!current.contains(id)) return false;
    _preferences.setStringList(
      keyPendingPlatformFeeOrderIds,
      current.where((e) => e != id).toList(),
    );
    return true;
  }

  /// Clear all
  Future<bool> clear() async => await _preferences.clear();

  /// Clear only auth data
  Future<bool> clearAuthData() async {
    await _preferences.remove(keyToken);
    await _preferences.remove(keyRefreshToken);
    await _preferences.remove(keyUser);
    await _preferences.remove(keyCurrentUser);
    await _preferences.remove(keySelectedOutlet);
    await _preferences.remove(keyIsKOT);
    await _preferences.remove(keyStaffSession);
    await _preferences.remove(keyStaffPermissions);
    await _preferences.remove(keyShowcaseCompleted); // Reset showcase on logout
    // Keeping saved users & recent users
    return true;
  }

  /// Clear all data including saved users (complete logout)
  Future<bool> clearAllData() async {
    await clearAuthData();
    await _preferences.remove(keyUsers);
    await _preferences.remove(keyRecentusers);
    await clearCachedOutletTables();
    return true;
  }
}
