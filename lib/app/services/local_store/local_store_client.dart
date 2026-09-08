import 'dart:convert';

import 'package:billkaro/app/services/local_store/local_store_discovery.dart';
import 'package:billkaro/app/services/local_store/local_store_protocol.dart';
import 'package:http/http.dart' as http;

class LocalStoreJoinResult {
  const LocalStoreJoinResult({
    required this.ok,
    required this.baseUrl,
    required this.token,
    this.outletId,
    this.outletName,
    this.error,
  });

  final bool ok;
  final String baseUrl;
  final String token;
  final String? outletId;
  final String? outletName;
  final String? error;
}

/// Staff / secondary till talks to the Windows host over LAN.
class LocalStoreClient {
  LocalStoreClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  Map<String, String> _authHeaders(String token) => {
        'X-Join-Token': token,
        'Content-Type': 'application/json',
      };

  /// Discover host on the same Wi‑Fi using only the join code, then join.
  Future<LocalStoreJoinResult> joinByCode(String joinCode) async {
    final token = LocalStoreProtocol.normalizeJoinCode(joinCode);
    if (token.isEmpty) {
      return const LocalStoreJoinResult(
        ok: false,
        baseUrl: '',
        token: '',
        error: 'Join code is required',
      );
    }

    final found = await LocalStoreDiscovery.findHostByCode(token);
    if (found == null) {
      return LocalStoreJoinResult(
        ok: false,
        baseUrl: '',
        token: token,
        error:
            'No store host found for this code. Same Wi‑Fi? Is the host PC online?',
      );
    }

    final port = int.tryParse(found['port'] ?? '') ??
        LocalStoreProtocol.defaultPort;
    return probeAndJoin(
      ip: found['ip']!,
      port: port,
      token: token,
    );
  }

  Future<LocalStoreJoinResult> probeAndJoin({
    required String ip,
    required int port,
    required String token,
  }) async {
    final base = LocalStoreProtocol.baseUrl(host: ip, port: port);
    try {
      final health = await _http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 4));
      if (health.statusCode != 200) {
        return LocalStoreJoinResult(
          ok: false,
          baseUrl: base,
          token: token,
          error: 'Host not reachable (HTTP ${health.statusCode})',
        );
      }

      final infoUri = Uri.parse('$base/v1/info').replace(
        queryParameters: {'token': token},
      );
      final info =
          await _http.get(infoUri).timeout(const Duration(seconds: 4));
      if (info.statusCode == 401) {
        return LocalStoreJoinResult(
          ok: false,
          baseUrl: base,
          token: token,
          error: 'Invalid join code',
        );
      }
      if (info.statusCode != 200) {
        return LocalStoreJoinResult(
          ok: false,
          baseUrl: base,
          token: token,
          error: 'Host rejected join (HTTP ${info.statusCode})',
        );
      }

      String? outletId;
      String? outletName;
      try {
        final body = jsonDecode(info.body);
        if (body is Map) {
          outletId = body['outletId']?.toString();
          outletName = body['outletName']?.toString();
        }
      } catch (_) {}

      return LocalStoreJoinResult(
        ok: true,
        baseUrl: base,
        token: token,
        outletId: outletId,
        outletName: outletName,
      );
    } catch (e) {
      return LocalStoreJoinResult(
        ok: false,
        baseUrl: base,
        token: token,
        error:
            'Cannot reach host at $base. Same Wi‑Fi? Firewall blocking port $port?',
      );
    }
  }

  /// Join using a QR / clipboard payload (`billkaro://local-store?...`).
  Future<LocalStoreJoinResult> joinFromPayload(String raw) async {
    final parsed = LocalStoreProtocol.parseJoinPayload(raw);
    if (parsed == null) {
      return const LocalStoreJoinResult(
        ok: false,
        baseUrl: '',
        token: '',
        error: 'Invalid join QR / link',
      );
    }
    final port =
        int.tryParse(parsed['port'] ?? '') ?? LocalStoreProtocol.defaultPort;
    return probeAndJoin(
      ip: parsed['ip']!,
      port: port,
      token: parsed['token']!,
    );
  }

  Future<bool> checkHealth(String baseUrl) async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns host info map, or null if unauthorized / unreachable.
  Future<Map<String, dynamic>?> fetchInfo({
    required String baseUrl,
    required String token,
  }) async {
    try {
      final infoUri = Uri.parse('$baseUrl/v1/info').replace(
        queryParameters: {'token': token},
      );
      final info =
          await _http.get(infoUri).timeout(const Duration(seconds: 4));
      if (info.statusCode != 200) return null;
      final body = jsonDecode(info.body);
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return Map<String, dynamic>.from(body);
    } catch (_) {}
    return null;
  }

  Future<String?> peekNextBill({
    required String baseUrl,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/bills/next').replace(
        queryParameters: {'token': token},
      );
      final res = await _http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map) {
        return body['nextBillNumber']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<String?> reserveBill({
    required String baseUrl,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/bills/reserve');
      final res = await _http
          .post(uri, headers: _authHeaders(token), body: '{}')
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map && body['ok'] == true) {
        return body['billNumber']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> syncIssuedBill({
    required String baseUrl,
    required String token,
    required String billNumber,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/bills/sync');
      await _http
          .post(
            uri,
            headers: _authHeaders(token),
            body: jsonEncode({'billNumber': billNumber}),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<bool> registerStaff({
    required String baseUrl,
    required String token,
    required String deviceId,
    required String displayName,
    required String joinMethod,
    String? userId,
    String? platform,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/staff/register');
      final res = await _http
          .post(
            uri,
            headers: _authHeaders(token),
            body: jsonEncode({
              'deviceId': deviceId,
              'displayName': displayName,
              'joinMethod': joinMethod,
              if (userId != null && userId.isNotEmpty) 'userId': userId,
              if (platform != null && platform.isNotEmpty) 'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> leaveStaff({
    required String baseUrl,
    required String token,
    required String deviceId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/staff/leave');
      await _http
          .post(
            uri,
            headers: _authHeaders(token),
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> upsertOrder({
    required String baseUrl,
    required String token,
    required Map<String, dynamic> body,
    String? orderId,
  }) async {
    try {
      final uri = orderId == null || orderId.isEmpty
          ? Uri.parse('$baseUrl/v1/orders')
          : Uri.parse('$baseUrl/v1/orders/${Uri.encodeComponent(orderId)}');
      final res = orderId == null || orderId.isEmpty
          ? await _http
              .post(
                uri,
                headers: _authHeaders(token),
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 12))
          : await _http
              .put(
                uri,
                headers: _authHeaders(token),
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['ok'] == true && decoded['order'] is Map) {
        return Map<String, dynamic>.from(decoded['order'] as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> listOrders({
    required String baseUrl,
    required String token,
    String? status,
    String? search,
    int limit = 200,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/orders').replace(
        queryParameters: {
          'token': token,
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': '$limit',
        },
      );
      final res = await _http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['ok'] != true) return const [];
      final list = decoded['orders'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> getOrder({
    required String baseUrl,
    required String token,
    required String orderId,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/v1/orders/${Uri.encodeComponent(orderId)}',
      ).replace(queryParameters: {'token': token});
      final res = await _http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['ok'] == true && decoded['order'] is Map) {
        return Map<String, dynamic>.from(decoded['order'] as Map);
      }
    } catch (_) {}
    return null;
  }

  void close() => _http.close();
}
