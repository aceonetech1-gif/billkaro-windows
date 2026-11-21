import 'package:billkaro/config/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class SidebarColors {
  static const background = Color(0xFF0B1120);
  static const border = Color(0xFF1E293B);
  static const textStrong = Color(0xFFF8FAFC);
  static const textInactive = Color(0xFFA3AEC2);
  static const iconInactive = Color(0xFF8391A7);
  static const sectionLabel = Color(0xFF64748B);
  static const hover = Color(0x0FFFFFFF);
  static const divider = Color(0xFF1E293B);
  static const textActive = Color(0xFFFFFFFF);
  static const childActiveBackground = Color(0x14FFFFFF);

  static Color get activeBackground => AppColor.primary;
}
