import 'dart:async';
import 'dart:convert';

import 'package:billkaro/app/modules/Home/home_screen_controller.dart';
import 'package:billkaro/app/modules/Order/HoldOrders/hold_orders_controller.dart';
import 'package:billkaro/app/modules/Tables/table_controller.dart';
import 'package:billkaro/app/services/local_store/local_store_orders_cache.dart';
import 'package:billkaro/app/services/local_store/local_store_protocol.dart';
import 'package:billkaro/config/app_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live channel to the Windows store host (Petpooja-style staff client).
class LocalStoreLiveService extends GetxService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _refreshDebounce;
  var _intentionalStop = false;

  final isConnected = false.obs;
  final lastEvent = RxnString();
  final orderRevision = 0.obs;

  AppPref get _pref => Get.find<AppPref>();

  Future<LocalStoreLiveService> initFromPrefs() async {
    if (_pref.localStoreClientJoined) {
      await connect();
    }
    return this;
  }

  Future<void> connect() async {
    _intentionalStop = false;
    await disconnect(clearFlag: false);
    if (!_pref.localStoreClientJoined) return;

    final base = _pref.localStoreClientBaseUrl.trim();
    final token = _pref.localStoreClientToken.trim();
    if (base.isEmpty || token.isEmpty) return;

    final wsBase = base
        .replaceFirst(RegExp(r'^http://', caseSensitive: false), 'ws://')
        .replaceFirst(RegExp(r'^https://', caseSensitive: false), 'wss://');
    final uri = Uri.parse('$wsBase/v1/live').replace(
      queryParameters: {'token': token},
    );

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        (message) {
          isConnected.value = true;
          lastEvent.value = message?.toString();
          _onMessage(message?.toString() ?? '');
        },
        onDone: () {
          isConnected.value = false;
          _scheduleReconnect();
        },
        onError: (e, st) {
          debugPrint('LocalStoreLiveService error: $e');
          isConnected.value = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      isConnected.value = true;
      try {
        channel.sink.add(LocalStoreProtocol.encodeHello(role: 'staff'));
      } catch (_) {}
      unawaited(LocalStoreOrdersCache.pullFromHost());
    } catch (e) {
      debugPrint('LocalStoreLiveService connect failed: $e');
      isConnected.value = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(String raw) {
    if (raw.isEmpty) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return;
      final event = json['event']?.toString() ?? '';
      if (event == 'order_upserted' ||
          event == 'bill_reserved' ||
          event == 'bill_synced') {
        _scheduleUiRefresh();
      }
    } catch (_) {}
  }

  void _scheduleUiRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () async {
      await LocalStoreOrdersCache.pullFromHost();
      orderRevision.value++;
      try {
        if (Get.isRegistered<HomeScreenController>()) {
          await Get.find<HomeScreenController>().getOrderList();
        }
      } catch (_) {}
      try {
        if (Get.isRegistered<HoldOrdersController>()) {
          await Get.find<HoldOrdersController>().getOrderList();
        }
      } catch (_) {}
      try {
        if (Get.isRegistered<TableController>()) {
          await Get.find<TableController>().loadTables();
        }
      } catch (_) {}
    });
  }

  void _scheduleReconnect() {
    if (_intentionalStop || !_pref.localStoreClientJoined) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_intentionalStop && _pref.localStoreClientJoined) {
        unawaited(connect());
      }
    });
  }

  Future<void> disconnect({bool clearFlag = true}) async {
    if (clearFlag) _intentionalStop = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    isConnected.value = false;
  }

  @override
  void onClose() {
    unawaited(disconnect());
    super.onClose();
  }
}
