import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';

class EmphasisMarks extends StatelessWidget {
  final Color color;
  final double size;
  final bool mirrored;

  const EmphasisMarks({
    super.key,
    this.color = AppPalette.sparkOrange,
    this.size = 22,
    this.mirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AppIcon(AppGlyph.spark, color: color, size: size);
    if (!mirrored) return icon;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
      child: icon,
    );
  }
}
