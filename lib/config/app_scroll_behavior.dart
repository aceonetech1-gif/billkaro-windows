import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Desktop-friendly scroll: mouse wheel, trackpad, and scrollbar thumb drag.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return const ClampingScrollPhysics();
      default:
        return super.getScrollPhysics(context);
    }
  }
}
