import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:billkaro/config/config.dart';
import 'package:showcaseview/showcaseview.dart';

class ShowcaseController extends BaseController {
  // Home-screen tour keys. Each HomeScreen instance claims a fresh set so two
  // mounted copies (e.g. during a route change) never share a GlobalKey.
  HomeShowcaseKeys _home = HomeShowcaseKeys();
  HomeShowcaseKeys claimHomeKeys() => _home = HomeShowcaseKeys();
  // Bottom navigation
  final GlobalKey _bottomNavHomeKey = GlobalKey();
  final GlobalKey _bottomNavItemsKey = GlobalKey();
  final GlobalKey _bottomNavCreateKey = GlobalKey();
  final GlobalKey _bottomNavReportsKey = GlobalKey();
  final GlobalKey _bottomNavMenuKey = GlobalKey();
  final GlobalKey _bottomNavMicKey = GlobalKey();

  GlobalKey get outletSwitcherKey => _home.outletSwitcherKey;
  GlobalKey get profileKey => _home.profileKey;
  GlobalKey get printerBannerKey => _home.printerBannerKey;
  GlobalKey get quickActionsHeaderKey => _home.quickActionsHeaderKey;
  GlobalKey get closedOrdersKey => _home.closedOrdersKey;
  GlobalKey get holdOrdersKey => _home.holdOrdersKey;
  GlobalKey get addOrderKey => _home.addOrderKey;
  GlobalKey get addItemsKey => _home.addItemsKey;
  GlobalKey get kotHistoryKey => _home.kotHistoryKey;
  GlobalKey get businessOverviewKey => _home.businessOverviewKey;
  GlobalKey get salesChartKey => _home.salesChartKey;
  GlobalKey get featuresKey => _home.featuresKey;
  GlobalKey get testimonialsKey => _home.testimonialsKey;
  GlobalKey get bottomNavHomeKey => _bottomNavHomeKey;
  GlobalKey get bottomNavItemsKey => _bottomNavItemsKey;
  GlobalKey get bottomNavCreateKey => _bottomNavCreateKey;
  GlobalKey get bottomNavReportsKey => _bottomNavReportsKey;
  GlobalKey get bottomNavMenuKey => _bottomNavMenuKey;
  GlobalKey get bottomNavMicKey => _bottomNavMicKey;

  /// Set true after [HomeMainShell] starts a showcase run; cleared when user
  /// chooses "Show onboarding again" so the tour can replay.
  bool _shellShowcaseArmConsumed = false;

  bool get shellShowcaseArmConsumed => _shellShowcaseArmConsumed;

  void markShellShowcaseStarted() {
    _shellShowcaseArmConsumed = true;
  }

  /// Check if showcase should be shown
  bool shouldShowShowcase() {
    return !appPref.isShowcaseCompleted;
  }

  /// Mark showcase as completed
  void markShowcaseCompleted() {
    appPref.isShowcaseCompleted = true;
  }

  /// Start showcase for home screen
  void startHomeShowcase(BuildContext context) {
    if (shouldShowShowcase()) {
      // Longer delay to ensure widgets are fully built
      Future.delayed(const Duration(milliseconds: 1000), () {
        try {
          final showcaseWidget = ShowCaseWidget.of(context);
          final keys = <GlobalKey>[
            _home.outletSwitcherKey,
            _home.profileKey,
            _home.printerBannerKey,
            _home.quickActionsHeaderKey,
            _home.closedOrdersKey,
            _home.holdOrdersKey,
            _home.addItemsKey,
            if (HomeMainRoutes.kotFeatureEnabled()) _home.kotHistoryKey,
            _home.businessOverviewKey,
            _home.salesChartKey,
            _home.featuresKey,
            _home.testimonialsKey,
            // Bottom navigation (last)
            _bottomNavHomeKey,
            _bottomNavItemsKey,
            _bottomNavCreateKey,
            _bottomNavReportsKey,
            _bottomNavMenuKey,
            _bottomNavMicKey,
          ];
          showcaseWidget.startShowCase(keys);
        } catch (e) {
          debugPrint('⚠️ Showcase error: $e');
        }
      });
    }
  }

  /// Reset showcase (for testing or re-showing)
  void resetShowcase() {
    resetShowcaseForReplay();
  }

  void resetShowcaseForReplay() {
    appPref.isShowcaseCompleted = false;
    _shellShowcaseArmConsumed = false;
  }
}


class HomeShowcaseKeys {
  final GlobalKey outletSwitcherKey = GlobalKey();
  final GlobalKey profileKey = GlobalKey();
  final GlobalKey printerBannerKey = GlobalKey();
  final GlobalKey quickActionsHeaderKey = GlobalKey();
  final GlobalKey closedOrdersKey = GlobalKey();
  final GlobalKey holdOrdersKey = GlobalKey();
  final GlobalKey addOrderKey = GlobalKey();
  final GlobalKey addItemsKey = GlobalKey();
  final GlobalKey kotHistoryKey = GlobalKey();
  final GlobalKey businessOverviewKey = GlobalKey();
  final GlobalKey salesChartKey = GlobalKey();
  final GlobalKey featuresKey = GlobalKey();
  final GlobalKey testimonialsKey = GlobalKey();
}
