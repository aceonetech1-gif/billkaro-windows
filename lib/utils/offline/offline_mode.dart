import 'package:billkaro/config/app_pref.dart';
import 'package:get/get.dart';

/// Settings toggle: allow saving / working when internet is unavailable.
abstract final class OfflineMode {
  static bool get isEnabled {
    if (!Get.isRegistered<AppPref>()) return true;
    return Get.find<AppPref>().offlineModeEnabled;
  }
}
