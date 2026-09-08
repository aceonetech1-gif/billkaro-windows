import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:billkaro/app/services/local_store/local_store_protocol.dart';
import 'package:flutter/foundation.dart';

/// Finds a store host on the same Wi‑Fi using only the join code (UDP broadcast).
class LocalStoreDiscovery {
  static Future<Map<String, String>?> findHostByCode(
    String joinCode, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final token = LocalStoreProtocol.normalizeJoinCode(joinCode);
    if (token.isEmpty) return null;

    RawDatagramSocket? socket;
    StreamSubscription? sub;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.readEventsEnabled = true;

      final completer = Completer<Map<String, String>?>();
      final payload = utf8.encode(
        LocalStoreProtocol.encodeDiscoverRequest(token),
      );

      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket?.receive();
        if (dg == null) return;
        final raw = utf8.decode(dg.data, allowMalformed: true);
        final reply = LocalStoreProtocol.parseDiscoverReply(raw);
        if (reply == null) return;
        if (reply['token'] != token) return;
        if (!completer.isCompleted) completer.complete(reply);
      });

      void sendDiscover(InternetAddress address) {
        try {
          socket?.send(payload, address, LocalStoreProtocol.discoveryPort);
        } catch (e) {
          debugPrint('LocalStoreDiscovery send failed: $e');
        }
      }

      sendDiscover(InternetAddress('255.255.255.255'));
      for (final bcast in await _subnetBroadcasts()) {
        sendDiscover(bcast);
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('LocalStoreDiscovery failed: $e');
      return null;
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }

  static Future<List<InternetAddress>> _subnetBroadcasts() async {
    final result = <InternetAddress>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          // Assume /24 — common for shop Wi‑Fi.
          final bcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          result.add(InternetAddress(bcast));
        }
      }
    } catch (_) {}
    return result;
  }
}
