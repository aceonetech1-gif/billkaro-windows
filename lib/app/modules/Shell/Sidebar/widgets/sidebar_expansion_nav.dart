import 'package:billkaro/app/modules/Shell/Sidebar/sidebar_theme.dart';
import 'package:billkaro/config/config.dart';
import 'package:flutter/material.dart';

class SidebarExpansionNav extends StatelessWidget {
  const SidebarExpansionNav({
    super.key,
    required this.storageKey,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.isSelected,
    required this.activeBackground,
    required this.leading,
    required this.title,
    required this.children,
  });

  final String storageKey;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final bool isSelected;
  final Color activeBackground;
  final Widget leading;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>(storageKey),
            initiallyExpanded: initiallyExpanded,
            onExpansionChanged: onExpansionChanged,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            childrenPadding: const EdgeInsets.only(
              left: 21,
              right: 0,
              bottom: 6,
            ),
            iconColor: SidebarColors.textStrong,
            collapsedIconColor: SidebarColors.iconInactive,
            leading: SizedBox(
              width: 24,
              height: 24,
              child: Center(child: leading),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? SidebarColors.textActive
                    : SidebarColors.textInactive,
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: SidebarColors.border, width: 1.5),
                  ),
                ),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
