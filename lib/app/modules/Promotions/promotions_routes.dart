import 'package:billkaro/app/routes/app_routes.dart';
import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:get/get.dart';

class PromotionsRoutes {
  static const offerType = '/promotions/offer-type';
  static const offerForm = '/promotions/offer-form';

  static const argType = 'type';
  static const argExisting = 'existing';

  static Map<String, dynamic>? readArgs() {
    final data = Modular.args.data;
    if (data is Map<String, dynamic>) return data;
    if (data != null) return Map<String, dynamic>.from(data as Map);

    final getArgs = Get.arguments;
    if (getArgs is Map<String, dynamic>) return getArgs;
    if (getArgs != null) return Map<String, dynamic>.from(getArgs as Map);
    return null;
  }

  static void toOfferType() {
    if (_useModular()) {
      Modular.to.pushNamed(HomeMainRoutes.offerType);
    } else {
      Get.toNamed(AppRoute.offerType);
    }
  }

  static void toOfferForm({String? type, dynamic existing}) {
    final args = <String, dynamic>{
      if (type != null) argType: type,
      if (existing != null) argExisting: existing,
    };
    if (_useModular()) {
      Modular.to.pushNamed(HomeMainRoutes.offerForm, arguments: args);
    } else {
      Get.toNamed(AppRoute.offerForm, arguments: args);
    }
  }

  static bool _useModular() {
    try {
      return Modular.to.path.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
