import 'package:billkaro/app/Widgets/logout_dialog.dart';
import 'package:billkaro/app/modules/HomeMain/home_main_routes.dart';
import 'package:billkaro/app/modules/Shell/Sidebar/sidebar_navigation.dart';
import 'package:billkaro/app/modules/Shell/Sidebar/sidebar_theme.dart';
import 'package:billkaro/app/modules/Tables/table_controller.dart';
import 'package:billkaro/config/config.dart';

class SidebarNavItem extends StatelessWidget {
  const SidebarNavItem({
    super.key,
    required this.selectedIndex,
    required this.collapsed,
    required this.index,
    required this.label,
    required this.icon,
    this.isSignOut = false,
    this.selectedOverride,
    this.onTapOverride,
    this.trailing,
  });

  final int selectedIndex;
  final bool collapsed;
  final int index;
  final String label;
  final Widget icon;
  final bool isSignOut;
  final bool? selectedOverride;
  final Future<void> Function()? onTapOverride;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isSelected =
        selectedOverride ?? (selectedIndex == index && !isSignOut);

    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? SidebarColors.activeBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(8),
          hoverColor: SidebarColors.hover,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 10 : 10,
              vertical: 9,
            ),
            child: Row(
              children: [
                SizedBox(width: 24, height: 24, child: Center(child: icon)),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSignOut
                            ? const Color(0xFFF87171)
                            : (isSelected
                                  ? SidebarColors.textActive
                                  : SidebarColors.textInactive),
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!collapsed || label.trim().isEmpty) return item;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 300),
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsets.only(left: 8),
      child: item,
    );
  }

  Future<void> _onTap(BuildContext context) async {
    if (isSignOut) {
      showLogoutDialog(context, AppLocalizations.of(context)!);
      return;
    }

    if (onTapOverride != null) {
      await onTapOverride!();
      return;
    }

    final targetRoute = HomeMainRoutes.routeForIndex(index);
    final navLoc = AppLocalizations.of(context)!;
    if (!SidebarNavigation.canNavigateToRoute(targetRoute)) {
      showError(description: navLoc.no_permission_section);
      return;
    }

    await SidebarNavigation.navigateFromSidebar(
      context,
      targetRoute,
      onAfterNavigate: () {
        if (HomeMainRoutes.outletShowsTables() &&
            targetRoute == HomeMainRoutes.tables) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Get.isRegistered<TableController>()) {
              Get.find<TableController>().refresh();
            }
          });
        }
      },
      staffFromSidebar: targetRoute == HomeMainRoutes.staff,
    );
  }
}
