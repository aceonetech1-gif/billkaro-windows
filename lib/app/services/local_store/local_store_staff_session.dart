import 'dart:io' show Platform;

import 'package:billkaro/app/services/local_store/local_store_client.dart';
import 'package:billkaro/config/app_pref.dart';
import 'package:flutter/foundation.dart';

String localStoreStaffDisplayName(AppPref pref) {
  final user = pref.user;
  final first = user?.firstName?.trim() ?? '';
  final last = user?.lastName?.trim() ?? '';
  final full = '$first $last'.trim();
  if (full.isNotEmpty) return full;
  final brand = user?.brandName?.trim();
  if (brand != null && brand.isNotEmpty) return brand;
  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) return email;
  return 'Staff';
}

String localStorePlatformLabel() {
  if (kIsWeb) return 'web';
  try {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
  } catch (_) {}
  return 'unknown';
}

Future<void> registerWithLocalStoreHost({
  required AppPref pref,
  required String baseUrl,
  required String token,
  required String joinMethod,
}) async {
  final client = LocalStoreClient();
  try {
    await client.registerStaff(
      baseUrl: baseUrl,
      token: token,
      deviceId: pref.localStoreDeviceId,
      displayName: localStoreStaffDisplayName(pref),
      joinMethod: joinMethod,
      userId: pref.user?.id ?? pref.user?.userId,
      platform: localStorePlatformLabel(),
    );
  } finally {
    client.close();
  }
}

Future<void> leaveLocalStoreHostOnServer(AppPref pref) async {
  if (!pref.localStoreClientJoined) return;
  final client = LocalStoreClient();
  try {
    await client.leaveStaff(
      baseUrl: pref.localStoreClientBaseUrl,
      token: pref.localStoreClientToken,
      deviceId: pref.localStoreDeviceId,
    );
  } finally {
    client.close();
  }
}
