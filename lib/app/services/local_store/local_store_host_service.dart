import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:billkaro/app/Database/app_database.dart' as dbs;
import 'package:billkaro/app/services/Modals/orders/orders/orderResponse.dart';
import 'package:billkaro/app/services/local_store/lan_ipv4.dart';
import 'package:billkaro/app/services/local_store/local_store_joined_staff.dart';
import 'package:billkaro/app/services/local_store/local_store_order_mapper.dart';
import 'package:billkaro/app/services/local_store/local_store_protocol.dart';
import 'package:billkaro/app/services/sync/bill_number_util.dart';
import 'package:billkaro/app/services/sync/sync_manager.dart';
import 'package:billkaro/config/app_pref.dart';
import 'package:billkaro/utils/connectivity/connectivity_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Embedded LAN API so staff devices work when internet is down.
///
/// This PC is the store host; phones / secondary tills call these endpoints
/// over the same Wi‑Fi (no cloud required for live service).
class LocalStoreHostService extends GetxService {
  HttpServer? _server;
  StreamSubscription? _serverSub;
  RawDatagramSocket? _discoverySocket;
  StreamSubscription? _discoverySub;
  final _clients = <WebSocket>{};
  final _clientSubs = <WebSocket, StreamSubscription>{};
  Future<void> _billLock = Future<void>.value();

  final isRunning = false.obs;
  final connectedClients = 0.obs;
  final lanIp = RxnString();
  final port = LocalStoreProtocol.defaultPort.obs;
  final lastError = RxnString();
  final joinToken = ''.obs;
  final joinedStaff = <LocalStoreJoinedStaff>[].obs;

  AppPref get _pref => Get.find<AppPref>();

  dbs.AppDatabase? get _dbOrNull =>
      Get.isRegistered<dbs.AppDatabase>() ? Get.find<dbs.AppDatabase>() : null;

  String? get joinPayload {
    final ip = lanIp.value;
    final token = joinToken.value;
    if (ip == null || ip.isEmpty || token.isEmpty) return null;
    final outlet = _pref.selectedOutlet;
    return LocalStoreProtocol.buildJoinPayload(
      host: ip,
      port: port.value,
      token: token,
      outletId: outlet?.id,
      outletName: outlet?.businessName,
    );
  }

  String? get baseUrl {
    final ip = lanIp.value;
    if (ip == null || ip.isEmpty) return null;
    return LocalStoreProtocol.baseUrl(host: ip, port: port.value);
  }

  Future<LocalStoreHostService> initFromPrefs() async {
    joinToken.value = _pref.localStoreJoinToken;
    if (joinToken.value.isEmpty) {
      joinToken.value = LocalStoreProtocol.newJoinToken();
      _pref.localStoreJoinToken = joinToken.value;
    }
    port.value = _pref.localStorePort;
    if (_pref.localStoreHostEnabled) {
      // Host and client modes are mutually exclusive.
      if (_pref.localStoreClientJoined) {
        _pref.clearLocalStoreClient();
      }
      try {
        await start();
      } catch (e) {
        debugPrint('LocalStoreHostService auto-start failed: $e');
        lastError.value = e.toString();
      }
    }
    return this;
  }

  Future<void> setEnabled(bool enabled) async {
    _pref.localStoreHostEnabled = enabled;
    if (enabled) {
      // Host and client modes are mutually exclusive.
      if (_pref.localStoreClientJoined) {
        _pref.clearLocalStoreClient();
      }
      await start();
    } else {
      await stop();
      _pref.localStoreHostEnabled = false;
    }
  }

  Future<void> regenerateJoinToken() async {
    joinToken.value = LocalStoreProtocol.newJoinToken();
    _pref.localStoreJoinToken = joinToken.value;
    joinedStaff.clear();
    connectedClients.value = 0;
  }

  Future<void> start() async {
    lastError.value = null;
    await stop(clearError: false);

    if (joinToken.value.isEmpty) {
      joinToken.value = LocalStoreProtocol.newJoinToken();
      _pref.localStoreJoinToken = joinToken.value;
    }

    lanIp.value = await resolveLanIpv4();
    if (lanIp.value == null) {
      final msg =
          'No Wi‑Fi / LAN IP found. Connect this PC to the same Wi‑Fi as staff devices.';
      lastError.value = msg;
      isRunning.value = false;
      throw StateError(msg);
    }

    final preferredPort = _pref.localStorePort;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } catch (_) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    port.value = _server!.port;
    _pref.localStorePort = port.value;
    _pref.localStoreHostEnabled = true;

    isRunning.value = true;
    connectedClients.value = joinedStaff.length;
    _serverSub = _server!.listen(
      _handleRequest,
      onError: (e, st) {
        debugPrint('LocalStoreHostService server error: $e\n$st');
        lastError.value = e.toString();
      },
    );
    await _startDiscoveryResponder();
  }

  Future<void> _startDiscoveryResponder() async {
    await _stopDiscoveryResponder();
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LocalStoreProtocol.discoveryPort,
      );
      _discoverySocket!.broadcastEnabled = true;
      _discoverySocket!.readEventsEnabled = true;
      _discoverySub = _discoverySocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _discoverySocket?.receive();
        if (dg == null) return;
        final raw = utf8.decode(dg.data, allowMalformed: true);
        final requested = LocalStoreProtocol.parseDiscoverToken(raw);
        if (requested == null) return;
        if (requested != LocalStoreProtocol.normalizeJoinCode(joinToken.value)) {
          return;
        }
        final ip = lanIp.value;
        if (ip == null || ip.isEmpty) return;
        final outlet = _pref.selectedOutlet;
        final reply = utf8.encode(
          LocalStoreProtocol.encodeDiscoverReply(
            token: joinToken.value,
            ip: ip,
            port: port.value,
            outletId: outlet?.id,
            outletName: outlet?.businessName,
          ),
        );
        try {
          _discoverySocket?.send(reply, dg.address, dg.port);
        } catch (e) {
          debugPrint('LocalStoreHostService discovery reply failed: $e');
        }
      });
    } catch (e) {
      debugPrint('LocalStoreHostService discovery bind failed: $e');
    }
  }

  Future<void> _stopDiscoveryResponder() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    try {
      _discoverySocket?.close();
    } catch (_) {}
    _discoverySocket = null;
  }

  Future<void> stop({bool clearError = true}) async {
    await _stopDiscoveryResponder();
    for (final sub in _clientSubs.values) {
      await sub.cancel();
    }
    _clientSubs.clear();
    for (final ws in _clients.toList()) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clients.clear();
    connectedClients.value = 0;

    await _serverSub?.cancel();
    _serverSub = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    isRunning.value = false;
    joinedStaff.clear();
    connectedClients.value = 0;
    if (clearError) lastError.value = null;
  }

  Future<void> broadcast(String event, [Map<String, dynamic>? data]) async {
    final payload = LocalStoreProtocol.encodeEvent(event, data);
    for (final ws in _clients.toList()) {
      try {
        ws.add(payload);
      } catch (_) {
        _detachClient(ws);
      }
    }
  }

  Future<String> peekNextBillNumber(String outletId) async {
    final db = _dbOrNull;
    final bills = db == null
        ? const <String>[]
        : (await db.getAllOrders(outletId: outletId)).map((o) => o.billNumber);
    return computeNextBillNumber(
      outletLastBillNumber: _pref.selectedOutlet?.billNumber ?? 0,
      orderBillNumbers: bills,
    ).toString();
  }

  Future<String> reserveNextBillNumber(
    String outletId, {
    String? excludeOrderId,
  }) {
    return _withBillLock(() async {
      var candidate = int.tryParse(await peekNextBillNumber(outletId)) ?? 1;
      final db = _dbOrNull;
      for (var i = 0; i < 500; i++) {
        final bill = candidate.toString();
        final taken = db == null
            ? false
            : await db.isBillNumberTaken(
                outletId: outletId,
                billNumber: bill,
                excludeOrderId: excludeOrderId,
              );
        if (!taken) {
          syncLocalOutletBillNumber(_pref, bill);
          unawaited(broadcast('bill_reserved', {'billNumber': bill}));
          return bill;
        }
        candidate++;
      }
      throw StateError('Unable to allocate a unique bill number on host');
    });
  }

  Future<void> reconcileIssuedBill(String billNumber) async {
    await _withBillLock(() async {
      syncLocalOutletBillNumber(_pref, billNumber);
      unawaited(broadcast('bill_synced', {'billNumber': billNumber}));
    });
  }

  Future<T> _withBillLock<T>(Future<T> Function() action) {
    final previous = _billLock;
    final gate = Completer<void>();
    _billLock = gate.future;
    return previous.then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      // CORS for browser-based staff / KDS on LAN.
      request.response.headers
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        ..set(
          'Access-Control-Allow-Headers',
          'Content-Type, Authorization, X-Join-Token',
        );

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      if (path == '/health') {
        await _json(request, {
          'ok': true,
          'role': 'host',
          'v': LocalStoreProtocol.protocolVersion,
        });
        return;
      }

      if (path == '/v1/info') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final outlet = _pref.selectedOutlet;
        await _json(request, {
          'ok': true,
          'role': 'host',
          'v': LocalStoreProtocol.protocolVersion,
          'baseUrl': baseUrl,
          'outletId': outlet?.id,
          'outletName': outlet?.businessName,
          'shopName': outlet?.businessName ?? 'BillKaro Store',
          'clients': joinedStaff.length,
          'lastBillNumber': outlet?.billNumber ?? 0,
        });
        return;
      }

      if (path == '/v1/bills/next' && request.method == 'GET') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final outletId = _pref.selectedOutlet?.id;
        if (outletId == null) {
          request.response.statusCode = HttpStatus.badRequest;
          await _json(request, {'ok': false, 'error': 'no_outlet'});
          return;
        }
        final next = await peekNextBillNumber(outletId);
        await _json(request, {
          'ok': true,
          'nextBillNumber': next,
          'lastBillNumber': _pref.selectedOutlet?.billNumber ?? 0,
        });
        return;
      }

      if (path == '/v1/bills/reserve' && request.method == 'POST') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final outletId = _pref.selectedOutlet?.id;
        if (outletId == null) {
          request.response.statusCode = HttpStatus.badRequest;
          await _json(request, {'ok': false, 'error': 'no_outlet'});
          return;
        }
        try {
          final bill = await reserveNextBillNumber(outletId);
          await _json(request, {'ok': true, 'billNumber': bill});
        } catch (e) {
          request.response.statusCode = HttpStatus.conflict;
          await _json(request, {'ok': false, 'error': e.toString()});
        }
        return;
      }

      if (path == '/v1/bills/sync' && request.method == 'POST') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        try {
          final raw = await utf8.decoder.bind(request).join();
          final decoded = raw.isEmpty ? null : jsonDecode(raw);
          final bill =
              decoded is Map ? decoded['billNumber']?.toString() : null;
          if (bill != null && bill.isNotEmpty) {
            await reconcileIssuedBill(bill);
          }
          await _json(request, {'ok': true});
        } catch (e) {
          request.response.statusCode = HttpStatus.badRequest;
          await _json(request, {'ok': false, 'error': e.toString()});
        }
        return;
      }

      if (path == '/v1/staff' && request.method == 'GET') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        await _json(request, {
          'ok': true,
          'staff': joinedStaff.map((s) => s.toJson()).toList(),
        });
        return;
      }

      if (path == '/v1/staff/register' && request.method == 'POST') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        try {
          final raw = await utf8.decoder.bind(request).join();
          final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
          if (decoded is! Map) {
            request.response.statusCode = HttpStatus.badRequest;
            await _json(request, {'ok': false, 'error': 'invalid_body'});
            return;
          }
          final deviceId = decoded['deviceId']?.toString().trim() ?? '';
          if (deviceId.isEmpty) {
            request.response.statusCode = HttpStatus.badRequest;
            await _json(request, {'ok': false, 'error': 'deviceId_required'});
            return;
          }
          final staff = LocalStoreJoinedStaff(
            deviceId: deviceId,
            displayName: (decoded['displayName']?.toString().trim().isNotEmpty ==
                    true)
                ? decoded['displayName'].toString().trim()
                : 'Staff',
            joinMethod:
                (decoded['joinMethod']?.toString().trim().toLowerCase() == 'qr')
                    ? 'qr'
                    : 'code',
            joinedAt: DateTime.now(),
            userId: decoded['userId']?.toString(),
            platform: decoded['platform']?.toString(),
            remoteAddress: request.connectionInfo?.remoteAddress.address,
          );
          upsertJoinedStaff(staff);
          await _json(request, {'ok': true, 'staff': staff.toJson()});
        } catch (e) {
          request.response.statusCode = HttpStatus.badRequest;
          await _json(request, {'ok': false, 'error': e.toString()});
        }
        return;
      }

      if (path == '/v1/staff/leave' && request.method == 'POST') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        try {
          final raw = await utf8.decoder.bind(request).join();
          final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
          final deviceId = decoded is Map
              ? decoded['deviceId']?.toString().trim() ?? ''
              : '';
          if (deviceId.isNotEmpty) {
            removeJoinedStaff(deviceId);
          }
          await _json(request, {'ok': true});
        } catch (e) {
          request.response.statusCode = HttpStatus.badRequest;
          await _json(request, {'ok': false, 'error': e.toString()});
        }
        return;
      }

      if (path == '/v1/orders' && request.method == 'GET') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        await _handleListOrders(request);
        return;
      }

      if (path == '/v1/orders' && request.method == 'POST') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        await _handleUpsertOrder(request, existingId: null);
        return;
      }

      if (path.startsWith('/v1/orders/') && request.method == 'GET') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final id = Uri.decodeComponent(path.substring('/v1/orders/'.length));
        await _handleGetOrder(request, id);
        return;
      }

      if (path.startsWith('/v1/orders/') && request.method == 'PUT') {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final id = Uri.decodeComponent(path.substring('/v1/orders/'.length));
        await _handleUpsertOrder(request, existingId: id);
        return;
      }

      if (path == '/v1/live' &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        if (!_authorized(request)) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        _attachClient(socket);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await _json(request, {'ok': false, 'error': 'not_found'});
    } catch (e, st) {
      debugPrint('LocalStoreHostService request error: $e\n$st');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  void upsertJoinedStaff(LocalStoreJoinedStaff staff) {
    final index =
        joinedStaff.indexWhere((s) => s.deviceId == staff.deviceId);
    if (index >= 0) {
      joinedStaff[index] = staff;
    } else {
      joinedStaff.add(staff);
    }
    joinedStaff.refresh();
    connectedClients.value = joinedStaff.length;
    unawaited(broadcast('staff_joined', staff.toJson()));
  }

  void removeJoinedStaff(String deviceId) {
    joinedStaff.removeWhere((s) => s.deviceId == deviceId);
    joinedStaff.refresh();
    connectedClients.value = joinedStaff.length;
    unawaited(broadcast('staff_left', {'deviceId': deviceId}));
  }

  Future<void> _handleListOrders(HttpRequest request) async {
    final db = _dbOrNull;
    final outletId = _pref.selectedOutlet?.id;
    if (db == null || outletId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await _json(request, {'ok': false, 'error': 'no_outlet'});
      return;
    }

    final status = request.uri.queryParameters['status'];
    final search = request.uri.queryParameters['search'];
    final limit =
        int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 200;
    final offset =
        int.tryParse(request.uri.queryParameters['offset'] ?? '') ?? 0;

    final page = await db.getOrdersPage(
      outletId: outletId,
      limit: limit.clamp(1, 500),
      offset: offset.clamp(0, 100000),
      searchQuery: search,
      status: status,
    );

    await _json(request, {
      'ok': true,
      'orders': page.items.map((o) => o.toJson()).toList(),
      'hasMore': page.hasMore,
    });
  }

  Future<void> _handleGetOrder(HttpRequest request, String id) async {
    final db = _dbOrNull;
    final outletId = _pref.selectedOutlet?.id;
    if (db == null || outletId == null || id.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await _json(request, {'ok': false, 'error': 'bad_request'});
      return;
    }

    final orders = await db.getAllOrders(outletId: outletId);
    OrderModel? found;
    for (final o in orders) {
      if (o.id == id) {
        found = o;
        break;
      }
    }
    if (found == null) {
      request.response.statusCode = HttpStatus.notFound;
      await _json(request, {'ok': false, 'error': 'not_found'});
      return;
    }
    await _json(request, {'ok': true, 'order': found.toJson()});
  }

  Future<void> _handleUpsertOrder(
    HttpRequest request, {
    required String? existingId,
  }) async {
    final db = _dbOrNull;
    final outletId = _pref.selectedOutlet?.id;
    if (db == null || outletId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await _json(request, {'ok': false, 'error': 'no_outlet'});
      return;
    }

    try {
      final raw = await utf8.decoder.bind(request).join();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is! Map) {
        request.response.statusCode = HttpStatus.badRequest;
        await _json(request, {'ok': false, 'error': 'invalid_body'});
        return;
      }
      final body = Map<String, dynamic>.from(decoded);

      final localStatus = (body['localStatus'] ?? body['status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      final statusForStore = localStatus.isEmpty ? 'pending' : localStatus;

      var id = (existingId ?? body['id']?.toString() ?? '').trim();
      if (id.isEmpty) {
        id = 'lan_${DateTime.now().millisecondsSinceEpoch}';
      }

      String? createdAtOverride;
      final existingOrders = await db.getAllOrders(outletId: outletId);
      for (final o in existingOrders) {
        if (o.id == id) {
          createdAtOverride = o.createdAt;
          break;
        }
      }

      var bill = body['billNumber']?.toString().trim() ?? '';
      if (bill.isEmpty) {
        bill = await reserveNextBillNumber(outletId, excludeOrderId: id);
        body['billNumber'] = bill;
      } else {
        final taken = await db.isBillNumberTaken(
          outletId: outletId,
          billNumber: bill,
          excludeOrderId: id,
        );
        if (taken) {
          bill = await reserveNextBillNumber(outletId, excludeOrderId: id);
          body['billNumber'] = bill;
        } else {
          syncLocalOutletBillNumber(_pref, bill);
        }
      }

      final model = orderModelFromLanBody(
        body,
        id: id,
        outletId: outletId,
        localStatus: statusForStore,
        createdAtOverride: createdAtOverride,
      );

      await db.insertOrders(
        [model],
        outletId,
        isSyncedFromApi: false,
        protectUnsynced: false,
      );

      unawaited(
        broadcast('order_upserted', {
          'id': model.id,
          'status': model.status,
          'tableNumber': model.tableNumber,
          'billNumber': model.billNumber,
        }),
      );

      // Host is cloud sync authority for LAN orders.
      unawaited(() async {
        try {
          if (await NetworkUtils.hasInternetConnection()) {
            await SyncManager().triggerSync(immediate: true);
          }
        } catch (e) {
          debugPrint('LocalStoreHostService post-order sync failed: $e');
        }
      }());

      await _json(request, {'ok': true, 'order': model.toJson()});
    } catch (e, st) {
      debugPrint('LocalStoreHostService upsert order failed: $e\n$st');
      request.response.statusCode = HttpStatus.internalServerError;
      await _json(request, {'ok': false, 'error': e.toString()});
    }
  }

  bool _authorized(HttpRequest request) {
    final q = request.uri.queryParameters['token'];
    final header = request.headers.value('x-join-token');
    final auth = request.headers.value('authorization');
    String? bearer;
    if (auth != null && auth.toLowerCase().startsWith('bearer ')) {
      bearer = auth.substring(7).trim();
    }
    final provided = (q ?? header ?? bearer ?? '').trim();
    return provided.isNotEmpty && provided == joinToken.value;
  }

  void _attachClient(WebSocket socket) {
    _clients.add(socket);
    try {
      socket.add(LocalStoreProtocol.encodeHello(role: 'host'));
    } catch (_) {}

    _clientSubs[socket] = socket.listen(
      (_) {},
      onDone: () => _detachClient(socket),
      onError: (e, st) {
        debugPrint('LocalStoreHostService client error: $e\n$st');
        _detachClient(socket);
      },
      cancelOnError: true,
    );
  }

  void _detachClient(WebSocket socket) {
    _clientSubs.remove(socket)?.cancel();
    _clients.remove(socket);
    try {
      socket.close();
    } catch (_) {}
  }

  Future<void> _json(HttpRequest request, Map<String, dynamic> body) async {
    if (request.response.statusCode < 400) {
      request.response.statusCode = HttpStatus.ok;
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
