import 'dart:async';

import 'package:billkaro/app/Database/app_database.dart' as dbs;
import 'package:billkaro/app/services/local_store/local_store_client.dart';
import 'package:billkaro/app/services/local_store/local_store_host_service.dart';
import 'package:billkaro/app/services/sync/bill_number_util.dart';
import 'package:billkaro/config/app_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Allocates unique per-outlet bill numbers for offline / LAN multi-till use.
///
/// Online creates still let the cloud assign (or accept a preferred offline
/// number). This class is the authority for local + host-LAN reservation so
/// two tills cannot print the same bill while offline.
class BillNumberAllocator {
  BillNumberAllocator._();
  static final BillNumberAllocator instance = BillNumberAllocator._();

  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return previous.then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  AppPref get _pref => Get.find<AppPref>();
  dbs.AppDatabase get _db => Get.find<dbs.AppDatabase>();

  /// Peek only — does not reserve.
  Future<String> peekNext({required String outletId}) async {
    if (_pref.localStoreClientJoined && !_pref.localStoreHostEnabled) {
      final fromHost = await LocalStoreClient().peekNextBill(
        baseUrl: _pref.localStoreClientBaseUrl,
        token: _pref.localStoreClientToken,
      );
      if (fromHost != null && fromHost.isNotEmpty) return fromHost;
    }

    if (Get.isRegistered<LocalStoreHostService>()) {
      final host = Get.find<LocalStoreHostService>();
      if (host.isRunning.value) {
        return host.peekNextBillNumber(outletId);
      }
    }

    return _localPeek(outletId);
  }

  /// Reserve the next free bill and bump the local / host counter immediately.
  Future<String> reserveNext({
    required String outletId,
    String? excludeOrderId,
  }) {
    return _serialized(() async {
      if (_pref.localStoreClientJoined && !_pref.localStoreHostEnabled) {
        final reserved = await LocalStoreClient().reserveBill(
          baseUrl: _pref.localStoreClientBaseUrl,
          token: _pref.localStoreClientToken,
        );
        if (reserved != null && reserved.isNotEmpty) {
          syncLocalOutletBillNumber(_pref, reserved);
          return reserved;
        }
        debugPrint(
          '⚠️ Host bill reserve failed — falling back to local allocator',
        );
      }

      if (Get.isRegistered<LocalStoreHostService>()) {
        final host = Get.find<LocalStoreHostService>();
        if (host.isRunning.value) {
          final reserved = await host.reserveNextBillNumber(
            outletId,
            excludeOrderId: excludeOrderId,
          );
          syncLocalOutletBillNumber(_pref, reserved);
          return reserved;
        }
      }

      final reserved = await _localReserve(
        outletId,
        excludeOrderId: excludeOrderId,
      );
      syncLocalOutletBillNumber(_pref, reserved);
      return reserved;
    });
  }

  /// True when [billNumber] is already used by another order for this outlet.
  Future<bool> isDuplicate({
    required String outletId,
    required String billNumber,
    String? excludeOrderId,
  }) async {
    final taken = await _db.isBillNumberTaken(
      outletId: outletId,
      billNumber: billNumber,
      excludeOrderId: excludeOrderId,
    );
    return taken;
  }

  /// Push cloud / local counter up so LAN host stays ahead after online save.
  Future<void> reconcileFromIssued(String billNumber) async {
    syncLocalOutletBillNumber(_pref, billNumber);
    if (Get.isRegistered<LocalStoreHostService>()) {
      final host = Get.find<LocalStoreHostService>();
      if (host.isRunning.value) {
        await host.reconcileIssuedBill(billNumber);
      }
    }
    if (_pref.localStoreClientJoined && !_pref.localStoreHostEnabled) {
      unawaited(
        LocalStoreClient().syncIssuedBill(
          baseUrl: _pref.localStoreClientBaseUrl,
          token: _pref.localStoreClientToken,
          billNumber: billNumber,
        ),
      );
    }
  }

  Future<String> _localPeek(String outletId) async {
    final localOrders = await _db.getAllOrders(outletId: outletId);
    return computeNextBillNumber(
      outletLastBillNumber: _pref.selectedOutlet?.billNumber ?? 0,
      orderBillNumbers: localOrders.map((o) => o.billNumber),
    ).toString();
  }

  Future<String> _localReserve(
    String outletId, {
    String? excludeOrderId,
  }) async {
    var candidate = int.tryParse(await _localPeek(outletId)) ?? 1;
    for (var i = 0; i < 500; i++) {
      final bill = candidate.toString();
      final taken = await _db.isBillNumberTaken(
        outletId: outletId,
        billNumber: bill,
        excludeOrderId: excludeOrderId,
      );
      if (!taken) return bill;
      candidate++;
    }
    throw StateError('Unable to allocate a unique local bill number');
  }
}
