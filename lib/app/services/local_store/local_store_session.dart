import 'dart:async';

import 'package:billkaro/app/services/local_store/local_store_client.dart';
import 'package:billkaro/app/services/local_store/local_store_live_service.dart';
import 'package:billkaro/app/services/local_store/local_store_orders_cache.dart';
import 'package:billkaro/app/services/local_store/local_store_staff_session.dart';
import 'package:billkaro/config/app_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Cold-start / resume: re-validate join prefs and re-announce this staff till.
Future<bool> restoreLocalStoreClientSession(AppPref pref) async {
  if (!pref.localStoreClientJoined) return false;

  final client = LocalStoreClient();
  try {
    final healthy = await client.checkHealth(pref.localStoreClientBaseUrl);
    if (!healthy) {
      // Don't keep a dead join forever — it blocks normal online/offline billing.
      debugPrint('Local store host unreachable — clearing stale join prefs');
      pref.clearLocalStoreClient();
      if (Get.isRegistered<LocalStoreLiveService>()) {
        await Get.find<LocalStoreLiveService>().disconnect();
      }
      return false;
    }

    final info = await client.fetchInfo(
      baseUrl: pref.localStoreClientBaseUrl,
      token: pref.localStoreClientToken,
    );
    if (info == null) {
      debugPrint('Local store join token rejected — clearing client prefs');
      pref.clearLocalStoreClient();
      if (Get.isRegistered<LocalStoreLiveService>()) {
        await Get.find<LocalStoreLiveService>().disconnect();
      }
      return false;
    }

    final outletName = info['outletName']?.toString().trim() ?? '';
    if (outletName.isNotEmpty) {
      pref.localStoreClientOutletName = outletName;
    }

    await registerWithLocalStoreHost(
      pref: pref,
      baseUrl: pref.localStoreClientBaseUrl,
      token: pref.localStoreClientToken,
      joinMethod: 'code',
    );

    if (!Get.isRegistered<LocalStoreLiveService>()) {
      Get.put(LocalStoreLiveService(), permanent: true);
    }
    await Get.find<LocalStoreLiveService>().connect();
    unawaited(LocalStoreOrdersCache.pullFromHost());
    return true;
  } catch (e) {
    debugPrint('restoreLocalStoreClientSession failed: $e');
    return false;
  } finally {
    client.close();
  }
}

Future<void> startLocalStoreLiveIfJoined(AppPref pref) async {
  if (!pref.localStoreClientJoined) return;
  if (!Get.isRegistered<LocalStoreLiveService>()) {
    Get.put(LocalStoreLiveService(), permanent: true);
  }
  await Get.find<LocalStoreLiveService>().connect();
}

Future<void> stopLocalStoreLive() async {
  if (Get.isRegistered<LocalStoreLiveService>()) {
    await Get.find<LocalStoreLiveService>().disconnect();
  }
}
