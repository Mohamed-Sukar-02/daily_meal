import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import 'spin_wheel_button.dart';

/// Bottom action bar of the home screen:
/// [بواقي الأكل]  (spin wheel)  [توصيل]
class HomeActionBar extends StatelessWidget {
  final VoidCallback onLeftover;
  final VoidCallback onDelivery;
  final VoidCallback? onSpin;
  final bool canSpin;

  const HomeActionBar({
    super.key,
    required this.onLeftover,
    required this.onDelivery,
    this.onSpin,
    this.canSpin = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final leftover = AppPalette.leftoverPill(brightness);
    final delivery = AppPalette.deliveryPill(brightness);

    return Container(
      color: AppPalette.background(brightness),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Directionality(
        // Mockups: leftover pill left, delivery pill right.
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: _Pill(
                glyph: AppGlyph.fridge,
                label: 'بواقي الأكل',
                style: leftover,
                onTap: onLeftover,
              ),
            ),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: SpinWheelButton(onTap: onSpin, enabled: canSpin),
                ),
              ),
            ),
            Flexible(
              child: _Pill(
                glyph: AppGlyph.scooter,
                label: 'توصيل',
                style: delivery,
                onTap: onDelivery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final AppGlyph glyph;
  final String label;
  final PillStyle style;
  final VoidCallback onTap;

  const _Pill({
    super.key,
    required this.glyph,
    required this.label,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.background,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          constraints: const BoxConstraints(minWidth: 88, maxWidth: 150),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(glyph, color: style.icon, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: style.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
