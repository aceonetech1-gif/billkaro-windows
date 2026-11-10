import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Top-down view of a round table with its chairs spaced evenly around it.
///
/// Sizes itself to the available space (the smaller of width and height), so
/// it can sit inside an [Expanded] in a grid card. One chair is drawn per
/// seat, capped at [maxChairs] so large tables stay readable.
class RoundTableView extends StatelessWidget {
  /// Text in the middle of the table, e.g. "Table 4".
  final String label;

  /// Optional smaller line under [label], e.g. "4 seats".
  final String? caption;

  /// Number of chairs to draw.
  final int seats;

  /// Status colour used for the table rim and the chairs.
  final Color color;

  /// Colour of [label]; defaults to the theme's onSurface.
  final Color? labelColor;

  static const int maxChairs = 12;

  const RoundTableView({
    super.key,
    required this.label,
    required this.seats,
    required this.color,
    this.caption,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        if (!size.isFinite || size < 40) return const SizedBox.shrink();

        final chairCount = seats.clamp(0, maxChairs);
        // Chair depth (radial). Chairs tuck slightly under the table edge.
        final chairDepth = size * 0.17;
        final tuck = chairDepth * 0.04;
        final tableDiameter = size - 2 * (chairDepth - tuck) - 4;
        final tableRadius = tableDiameter / 2;
        final orbit = tableRadius + chairDepth / 2 - tuck;
        // Chair width along the rim, shrunk on busy tables so they never touch.
        final spacing = chairCount == 0
            ? double.infinity
            : 2 * math.pi * orbit / chairCount;
        final chairWidth = math.min(size * 0.21, spacing * 0.7);
        final center = size / 2;
        final textColor =
            labelColor ?? Theme.of(context).colorScheme.onSurface;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < chairCount; i++)
                  _chair(
                    angle: -math.pi / 2 + 2 * math.pi * i / chairCount,
                    center: center,
                    orbit: orbit,
                    width: chairWidth,
                    depth: chairDepth,
                  ),
                Positioned(
                  left: center - tableRadius,
                  top: center - tableRadius,
                  width: tableDiameter,
                  height: tableDiameter,
                  child: _table(tableDiameter, textColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A chair seen from above: a solid backrest bar on the outside and a
  /// lighter seat facing the table.
  Widget _chair({
    required double angle,
    required double center,
    required double orbit,
    required double width,
    required double depth,
  }) {
    final cx = center + orbit * math.cos(angle);
    final cy = center + orbit * math.sin(angle);
    final backrest = depth * 0.34;
    return Positioned(
      left: cx - width / 2,
      top: cy - depth / 2,
      width: width,
      height: depth,
      child: Transform.rotate(
        // Unrotated, the box's top edge points away from the table.
        angle: angle + math.pi / 2,
        child: Column(
          children: [
            Container(
              height: backrest,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(backrest),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            SizedBox(height: depth * 0.04),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: width * 0.06),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    color.withValues(alpha: 0.24),
                    Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(depth * 0.22),
                  border: Border.all(
                    color: color.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(double diameter, Color textColor) {
    final rim = math.max(2.0, diameter * 0.022);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.70), width: rim),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      // Faint inner ring gives the table top some depth.
      child: Container(
        margin: EdgeInsets.all(diameter * 0.07),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.alphaBlend(
            color.withValues(alpha: 0.06),
            Colors.white,
          ),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        padding: EdgeInsets.all(diameter * 0.11),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.15,
                  letterSpacing: 0.2,
                ),
              ),
              if (caption != null && caption!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    caption!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color.lerp(color, Colors.black, 0.25),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
