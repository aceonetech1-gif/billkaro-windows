import 'package:billkaro/config/config.dart';

class SwitchWithOnOffLabel extends StatelessWidget {
  const SwitchWithOnOffLabel({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.materialTapTargetSize,
    this.adaptive = false,
    this.scale,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;
  final MaterialTapTargetSize? materialTapTargetSize;
  final bool adaptive;
  final double? scale;

  @override
  Widget build(BuildContext context) {
    Widget switchWidget = adaptive
        ? Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
            activeTrackColor: activeTrackColor,
            inactiveThumbColor: inactiveThumbColor,
            inactiveTrackColor: inactiveTrackColor,
            materialTapTargetSize: materialTapTargetSize,
          )
        : Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
            activeTrackColor: activeTrackColor,
            inactiveThumbColor: inactiveThumbColor,
            inactiveTrackColor: inactiveTrackColor,
            materialTapTargetSize: materialTapTargetSize,
          );

    if (scale != null) {
      switchWidget = Transform.scale(scale: scale!, child: switchWidget);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        switchWidget,
        const SizedBox(height: 4),
        Text(
          value ? 'On' : 'Off',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1,
            color: value ? AppColor.primary : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
