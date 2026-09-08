import 'dart:io';

/// Resolves a usable LAN IPv4 for same-Wi‑Fi device pairing.
Future<String?> resolveLanIpv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );

  final preferred = <NetworkInterface>[];
  final others = <NetworkInterface>[];
  for (final iface in interfaces) {
    final name = iface.name.toLowerCase();
    final isVirtual = name.contains('vethernet') ||
        name.contains('virtual') ||
        name.contains('vmware') ||
        name.contains('hyper-v') ||
        name.contains('docker') ||
        name.contains('wsl') ||
        name.contains('loopback');
    if (isVirtual) continue;
    final isPreferred = name.contains('wi-fi') ||
        name.contains('wifi') ||
        name.contains('wlan') ||
        name.contains('ethernet') ||
        name.contains('en0') ||
        name.contains('eth');
    if (isPreferred) {
      preferred.add(iface);
    } else {
      others.add(iface);
    }
  }

  for (final iface in [...preferred, ...others]) {
    for (final addr in iface.addresses) {
      if (addr.isLoopback) continue;
      final ip = addr.address;
      if (ip.startsWith('169.254.')) continue;
      return ip;
    }
  }
  return null;
}
