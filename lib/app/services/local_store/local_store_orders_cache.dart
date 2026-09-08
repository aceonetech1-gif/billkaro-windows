import 'package:billkaro/app/Database/app_database.dart' as dbs;
import 'package:billkaro/app/services/Modals/orders/orders/orderResponse.dart';
import 'package:billkaro/app/services/local_store/local_store_client.dart';
import 'package:billkaro/config/app_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Pulls orders from the Windows store host into local SQLite (staff cache).
abstract final class LocalStoreOrdersCache {
  static Future<bool> pullFromHost({String? status}) async {
    if (!Get.isRegistered<AppPref>()) return false;
    final pref = Get.find<AppPref>();
    if (!pref.localStoreClientJoined) return false;

    final outletId = pref.selectedOutlet?.id;
    if (outletId == null || !Get.isRegistered<dbs.AppDatabase>()) return false;

    final client = LocalStoreClient();
    try {
      final raw = await client.listOrders(
        baseUrl: pref.localStoreClientBaseUrl,
        token: pref.localStoreClientToken,
        status: status,
      );
      if (raw.isEmpty) {
        // Empty can mean host has no orders OR unreachable — keep local cache.
        debugPrint('LocalStoreOrdersCache: host returned 0 orders');
        return true;
      }

      final models = <OrderModel>[];
      for (final map in raw) {
        try {
          models.add(OrderModel.fromJson(map));
        } catch (e) {
          debugPrint('LocalStoreOrdersCache skip bad order: $e');
        }
      }
      if (models.isEmpty) return false;

      final db = Get.find<dbs.AppDatabase>();
      await db.insertOrders(
        models,
        outletId,
        isSyncedFromApi: true,
        protectUnsynced: false,
      );
      return true;
    } catch (e) {
      debugPrint('LocalStoreOrdersCache.pullFromHost failed: $e');
      return false;
    } finally {
      client.close();
    }
  }
}
