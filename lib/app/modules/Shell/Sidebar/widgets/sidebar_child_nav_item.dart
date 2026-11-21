import 'package:billkaro/app/modules/Shell/Sidebar/sidebar_navigation.dart';
import 'package:billkaro/app/modules/Shell/Sidebar/sidebar_theme.dart';
import 'package:billkaro/config/config.dart';
import 'package:flutter/material.dart';

class SidebarChildNavItem extends StatelessWidget {
  const SidebarChildNavItem({
    super.key,
    required this.label,
    required this.selected,
    required this.targetRoute,
  });

  final String label;
  final bool selected;
  final String targetRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Material(
        color: selected
            ? SidebarColors.childActiveBackground
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => SidebarNavigation.navigateFromSidebar(
            context,
            targetRoute,
          ),
          borderRadius: BorderRadius.circular(8),
          hoverColor: SidebarColors.hover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? SidebarColors.textActive
                          : SidebarColors.textInactive,
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
