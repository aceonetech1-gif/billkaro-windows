import 'dart:convert';
import 'dart:math';

/// LAN host ↔ staff pairing protocol (works without internet).
abstract final class LocalStoreProtocol {
  static const int defaultPort = 47831;
  static const int discoveryPort = 47832;
  static const int protocolVersion = 2;
  static const String qrScheme = 'billkaro';
  static const String qrHost = 'local-store';

  static String newJoinToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String normalizeJoinCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// QR / clipboard payload for staff devices on the same Wi‑Fi.
  static String buildJoinPayload({
    required String host,
    required int port,
    required String token,
    String? outletId,
    String? outletName,
  }) {
    return Uri(
      scheme: qrScheme,
      host: qrHost,
      queryParameters: {
        'ip': host,
        'port': '$port',
        'token': token,
        'v': '$protocolVersion',
        if (outletId != null && outletId.isNotEmpty) 'outletId': outletId,
        if (outletName != null && outletName.trim().isNotEmpty)
          'outletName': outletName.trim(),
      },
    ).toString();
  }

  static String baseUrl({required String host, required int port}) =>
      'http://$host:$port';

  static String encodeDiscoverRequest(String token) {
    return jsonEncode({
      'v': protocolVersion,
      'cmd': 'discover',
      'token': normalizeJoinCode(token),
    });
  }

  static String? parseDiscoverToken(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      if (json['cmd']?.toString() != 'discover') return null;
      final token = normalizeJoinCode(json['token']?.toString() ?? '');
      return token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  static String encodeDiscoverReply({
    required String token,
    required String ip,
    required int port,
    String? outletId,
    String? outletName,
  }) {
    return jsonEncode({
      'v': protocolVersion,
      'cmd': 'hello',
      'token': normalizeJoinCode(token),
      'ip': ip,
      'port': port,
      if (outletId != null && outletId.isNotEmpty) 'outletId': outletId,
      if (outletName != null && outletName.trim().isNotEmpty)
        'outletName': outletName.trim(),
    });
  }

  static Map<String, String>? parseDiscoverReply(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      if (json['cmd']?.toString() != 'hello') return null;
      final ip = json['ip']?.toString().trim() ?? '';
      final port = json['port']?.toString().trim() ?? '';
      final token = normalizeJoinCode(json['token']?.toString() ?? '');
      if (ip.isEmpty || port.isEmpty || token.isEmpty) return null;
      return {
        'ip': ip,
        'port': port,
        'token': token,
        'outletId': json['outletId']?.toString() ?? '',
        'outletName': json['outletName']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Map<String, String>? parseJoinPayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme == qrScheme && uri.host == qrHost) {
        final ip = uri.queryParameters['ip']?.trim();
        final port = uri.queryParameters['port']?.trim();
        final token = uri.queryParameters['token']?.trim();
        if (ip != null &&
            ip.isNotEmpty &&
            port != null &&
            port.isNotEmpty &&
            token != null &&
            token.isNotEmpty) {
          return {
            'ip': ip,
            'port': port,
            'token': normalizeJoinCode(token),
            'outletId': uri.queryParameters['outletId'] ?? '',
            'outletName': uri.queryParameters['outletName'] ?? '',
            'v': uri.queryParameters['v'] ?? '1',
          };
        }
      }
    } catch (_) {}

    // Manual: ip:port:token
    final parts = trimmed.split(':');
    if (parts.length == 3 &&
        parts[0].isNotEmpty &&
        int.tryParse(parts[1]) != null &&
        parts[2].isNotEmpty) {
      return {
        'ip': parts[0].trim(),
        'port': parts[1].trim(),
        'token': normalizeJoinCode(parts[2]),
        'outletId': '',
        'outletName': '',
        'v': '1',
      };
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is Map) {
        final ip = json['ip']?.toString().trim();
        final port = json['port']?.toString().trim();
        final token = json['token']?.toString().trim();
        if (ip != null &&
            ip.isNotEmpty &&
            port != null &&
            port.isNotEmpty &&
            token != null &&
            token.isNotEmpty) {
          return {
            'ip': ip,
            'port': port,
            'token': normalizeJoinCode(token),
            'outletId': json['outletId']?.toString() ?? '',
            'outletName': json['outletName']?.toString() ?? '',
            'v': json['v']?.toString() ?? '1',
          };
        }
      }
    } catch (_) {}

    return null;
  }

  static String encodeHello({required String role}) {
    return jsonEncode({
      'event': 'hello',
      'data': {'role': role, 'v': protocolVersion},
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static String encodeEvent(String event, [Map<String, dynamic>? data]) {
    return jsonEncode({
      'event': event,
      if (data != null) 'data': data,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
