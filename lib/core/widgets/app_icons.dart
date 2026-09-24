import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's custom glyph set, drawn as vectors in code.
///
/// The mockups ship a bespoke icon language (safe-box vault, scooped chef hat,
/// rainbow wheel…). Until the Figma SVG exports are dropped in, every glyph is
/// hand-drawn here on a 24×24 grid so it stays crisp, tint-able per theme and
/// dependency-free. Swapping a glyph later = editing one `case` below.
///
/// The three cloud transfer marks ([AppGlyph.cloudDown], [AppGlyph.cloudUp],
/// [AppGlyph.sync]) are the exception: they ship as PNGs in `assets/icons/`
/// and are tinted through [AppIcon] like any vector, so call sites stay
/// unaware of the difference.
enum AppGlyph {
  home,
  vault,
  history,
  settings,
  pot,
  compass,
  steak,
  clock,
  oven,
  fridge,
  scooter,
  swap,
  heartFill,
  heartOutline,
  spark,
  person,
  star,
  wallet,
  plus,
  alert,
  grid,
  search,
  bookmark,
  bookmarkFill,
  close,
  sun,
  moon,
  cloud,
  cloudDown,
  cloudUp,
  sync,
  pencil,
  chevron,
  minus,
  flame,
  bolt,
  globe,
  bell,
  shield,
}

class AppIcon extends StatelessWidget {
  final AppGlyph glyph;
  final Color color;
  final double size;

  const AppIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 24,
  });

  static const Map<AppGlyph, String> _pngGlyphs = {
    AppGlyph.cloudDown: 'assets/icons/download_icon.png',
    AppGlyph.cloudUp: 'assets/icons/upload_icon.png',
    AppGlyph.sync: 'assets/icons/sync_icon.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _pngGlyphs[glyph];
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color,
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final AppGlyph glyph;
  final Color color;

  _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case AppGlyph.home:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.1)
            ..lineTo(20.6, 10.1)
            ..lineTo(20.6, 20.6)
            ..lineTo(14.3, 20.6)
            ..lineTo(14.3, 14.9)
            ..lineTo(9.7, 14.9)
            ..lineTo(9.7, 20.6)
            ..lineTo(3.4, 20.6)
            ..lineTo(3.4, 10.1)
            ..close(),
          fill,
        );

      case AppGlyph.vault:
        canvas.drawPath(
          Path()
            ..addRRect(RRect.fromRectAndRadius(
                const Rect.fromLTRB(3.6, 3.6, 20.4, 20.4),
                const Radius.circular(5)))
            ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3))
            ..fillType = PathFillType.evenOdd,
          fill,
        );

      case AppGlyph.history:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12.6), radius: 7.6),
          _rad(-55),
          _rad(250),
          false,
          stroke,
        );
        _arrowHead(canvas, fill, const Offset(15.6, 4.4), _rad(115));
        canvas.drawLine(const Offset(12, 8.6), const Offset(12, 12.8), stroke);
        canvas.drawLine(const Offset(12, 12.8), const Offset(15, 14.4), stroke);

      case AppGlyph.settings:
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.translate(12, 12);
          canvas.rotate(i * math.pi / 4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTRB(-1.7, -10.1, 1.7, -5.4),
                const Radius.circular(1.3)),
            fill,
          );
          canvas.restore();
        }
        canvas.drawPath(
          Path()
            ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 6.6))
            ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.7))
            ..fillType = PathFillType.evenOdd,
          fill,
        );

      case AppGlyph.pot:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(4.6, 10.4, 19.4, 19.4),
              const Radius.circular(2.6)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(3.2, 8.2, 20.8, 10.2),
              const Radius.circular(1.1)),
          fill,
        );
        canvas.drawCircle(const Offset(12, 5.6), 1.5, fill);

      case AppGlyph.compass:
        canvas.drawCircle(const Offset(12, 12), 8.4, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(15.4, 8.6)
            ..lineTo(13.2, 13.2)
            ..lineTo(8.6, 15.4)
            ..lineTo(10.8, 10.8)
            ..close(),
          fill,
        );

      case AppGlyph.steak:
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(_rad(-16));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-8.4, -5.2, 8.4, 5.2),
              const Radius.circular(5)),
          fill,
        );
        canvas.restore();

      case AppGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8.2, stroke);
        canvas.drawLine(const Offset(12, 7.6), const Offset(12, 12.4), stroke);
        canvas.drawLine(const Offset(12, 12.4), const Offset(15.4, 14.1), stroke);

      case AppGlyph.oven:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(3.8, 4.6, 20.2, 19.4),
              const Radius.circular(2.6)),
          stroke,
        );
        canvas.drawLine(const Offset(3.8, 9.4), const Offset(20.2, 9.4), stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(7.2, 12.2, 16.8, 16.6),
              const Radius.circular(1.2)),
          stroke,
        );
        canvas.drawCircle(const Offset(7.4, 7), 1, fill);
        canvas.drawCircle(const Offset(10.6, 7), 1, fill);

      case AppGlyph.fridge:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(6.4, 3.2, 17.6, 20.8),
              const Radius.circular(2.8)),
          stroke,
        );
        canvas.drawLine(const Offset(6.4, 10.2), const Offset(17.6, 10.2), stroke);
        canvas.drawLine(const Offset(9.2, 6.4), const Offset(9.2, 8.2), stroke);
        canvas.drawLine(const Offset(9.2, 12.2), const Offset(9.2, 14.4), stroke);

      case AppGlyph.scooter:
        canvas.drawCircle(const Offset(5.8, 17.6), 2.5, stroke);
        canvas.drawCircle(const Offset(18.2, 17.6), 2.5, stroke);
        canvas.drawLine(const Offset(8.3, 17.6), const Offset(13.4, 17.6), stroke);
        canvas.drawLine(const Offset(13.4, 17.6), const Offset(15.2, 8.4), stroke);
        canvas.drawLine(const Offset(15.2, 8.4), const Offset(17.6, 8.4), stroke);
        canvas.drawLine(const Offset(15.7, 17.6), const Offset(14.2, 12.6), stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(6.2, 7.4, 12.2, 12.6),
              const Radius.circular(1.6)),
          fill,
        );

      case AppGlyph.swap:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 6.8),
          _rad(200),
          _rad(140),
          false,
          stroke,
        );
        _arrowHead(canvas, fill, const Offset(17.9, 8.6), _rad(35));
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 6.8),
          _rad(20),
          _rad(140),
          false,
          stroke,
        );
        _arrowHead(canvas, fill, const Offset(6.1, 15.4), _rad(215));

      case AppGlyph.heartFill:
        canvas.drawPath(_heartPath(), fill);

      case AppGlyph.heartOutline:
        canvas.drawPath(_heartPath(), stroke);

      case AppGlyph.spark:
        final spark = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(6.5, 5.5), const Offset(9.5, 8.5), spark);
        canvas.drawLine(const Offset(3.4, 12), const Offset(7.6, 12), spark);
        canvas.drawLine(const Offset(6.5, 18.5), const Offset(9.5, 15.5), spark);

      case AppGlyph.person:
        canvas.drawCircle(const Offset(12, 8.4), 3.6, fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(5.4, 13.6, 18.6, 20.4),
              const Radius.circular(4)),
          fill,
        );

      case AppGlyph.star:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 8.6 : 3.9;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(12 + r * math.cos(a), 12.6 + r * math.sin(a));
          if (i == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(star..close(), fill);

      case AppGlyph.wallet:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(3.6, 6.2, 20.4, 18.6),
              const Radius.circular(3.2)),
          stroke,
        );
        canvas.drawLine(const Offset(3.6, 10.2), const Offset(20.4, 10.2), stroke);
        canvas.drawCircle(const Offset(16.4, 14.4), 1.4, fill);

      case AppGlyph.plus:
        canvas.drawLine(const Offset(12, 5.4), const Offset(12, 18.6), stroke);
        canvas.drawLine(const Offset(5.4, 12), const Offset(18.6, 12), stroke);

      case AppGlyph.alert:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(4.2, 4.2, 19.8, 19.8),
              const Radius.circular(4.5)),
          stroke,
        );
        canvas.drawLine(const Offset(12, 8.2), const Offset(12, 13.4), stroke);
        canvas.drawCircle(const Offset(12, 16.4), 1.2, fill);

      case AppGlyph.grid:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(4.2, 4.2, 10.6, 10.6), const Radius.circular(2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(13.4, 4.2, 19.8, 10.6), const Radius.circular(2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(4.2, 13.4, 10.6, 19.8), const Radius.circular(2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(13.4, 13.4, 19.8, 19.8), const Radius.circular(2)),
          fill,
        );

      case AppGlyph.search:
        canvas.drawCircle(const Offset(10.6, 10.6), 6.4, stroke);
        canvas.drawLine(const Offset(15.4, 15.4), const Offset(20, 20), stroke);

      case AppGlyph.bookmark:
        canvas.drawPath(_bookmarkPath(), stroke);

      case AppGlyph.bookmarkFill:
        canvas.drawPath(_bookmarkPath(), fill);

      case AppGlyph.close:
        canvas.drawLine(const Offset(6.4, 6.4), const Offset(17.6, 17.6), stroke);
        canvas.drawLine(const Offset(6.4, 17.6), const Offset(17.6, 6.4), stroke);

      case AppGlyph.sun:
        canvas.drawCircle(const Offset(12, 12), 4.2, stroke);
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.translate(12, 12);
          canvas.rotate(i * math.pi / 4);
          canvas.drawLine(const Offset(0, -6.8), const Offset(0, -8.8), stroke);
          canvas.restore();
        }

      case AppGlyph.moon:
        canvas.drawPath(
          Path()
            ..moveTo(15.8, 3.6)
            ..arcToPoint(const Offset(15.8, 20.4),
                radius: const Radius.circular(9.2),
                clockwise: false,
                largeArc: true)
            ..arcToPoint(const Offset(15.8, 3.6),
                radius: const Radius.circular(7.4),
                clockwise: true,
                largeArc: false)
            ..close(),
          fill,
        );

      case AppGlyph.cloud:
        canvas.drawPath(
          Path()
            ..moveTo(7.4, 17.6)
            ..arcToPoint(const Offset(7.4, 10.4),
                radius: const Radius.circular(3.6), clockwise: false)
            ..arcToPoint(const Offset(14.6, 8.6),
                radius: const Radius.circular(4.4), clockwise: true)
            ..arcToPoint(const Offset(17.4, 17.6),
                radius: const Radius.circular(3.8), clockwise: true)
            ..close(),
          fill,
        );

      // Shipped as tinted PNGs by [AppIcon]; never painted.
      case AppGlyph.cloudDown:
      case AppGlyph.cloudUp:
      case AppGlyph.sync:
        break;

      case AppGlyph.pencil:
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(_rad(45));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-2.2, -7.4, 2.2, 5.2),
              const Radius.circular(1.2)),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-2.2, 5.2)
            ..lineTo(0, 8.6)
            ..lineTo(2.2, 5.2)
            ..close(),
          fill,
        );
        canvas.restore();

      case AppGlyph.chevron:
        canvas.drawLine(const Offset(9.4, 6.4), const Offset(15, 12), stroke);
        canvas.drawLine(const Offset(15, 12), const Offset(9.4, 17.6), stroke);

      case AppGlyph.minus:
        canvas.drawLine(const Offset(6.4, 12), const Offset(17.6, 12), stroke);

      case AppGlyph.flame:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.4)
            ..cubicTo(13.6, 6.6, 17.6, 8.6, 17.6, 13.4)
            ..cubicTo(17.6, 17.4, 15, 20.4, 12, 20.4)
            ..cubicTo(9, 20.4, 6.4, 17.4, 6.4, 13.4)
            ..cubicTo(6.4, 10.6, 8.2, 9.2, 9.2, 7.2)
            ..cubicTo(9.8, 8.8, 10.8, 9.6, 11.6, 9.8)
            ..cubicTo(11.2, 7.6, 11.4, 5.4, 12, 3.4)
            ..close(),
          fill,
        );

      case AppGlyph.bolt:
        canvas.drawPath(
          Path()
            ..moveTo(13.4, 3.2)
            ..lineTo(6.6, 13.2)
            ..lineTo(11, 13.2)
            ..lineTo(9.8, 20.8)
            ..lineTo(17.4, 10.4)
            ..lineTo(12.8, 10.4)
            ..close(),
          fill,
        );

      case AppGlyph.globe:
        canvas.drawCircle(const Offset(12, 12), 8.4, stroke);
        canvas.drawOval(
            const Rect.fromLTRB(8.4, 3.6, 15.6, 20.4), stroke);
        canvas.drawLine(const Offset(3.6, 12), const Offset(20.4, 12), stroke);

      case AppGlyph.bell:
        // Bell body
        canvas.drawPath(
          Path()
            ..moveTo(7.2, 17.8)
            ..lineTo(7.2, 12.2)
            ..cubicTo(7.2, 8.2, 9.2, 5.2, 12, 5.2)
            ..cubicTo(14.8, 5.2, 16.8, 8.2, 16.8, 12.2)
            ..lineTo(16.8, 17.8)
            ..close(),
          fill,
        );
        // Bell rim
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(6.6, 17.2, 17.4, 19.4),
              const Radius.circular(1.4)),
          fill,
        );
        // Clapper
        canvas.drawCircle(const Offset(12, 19.8), 1.4, fill);
        // Top knob
        canvas.drawCircle(const Offset(12, 4.2), 1.2, fill);

      case AppGlyph.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.2)
            ..lineTo(19.2, 6.4)
            ..lineTo(19.2, 12.8)
            ..cubicTo(19.2, 17.2, 15.6, 19.8, 12, 21.2)
            ..cubicTo(8.4, 19.8, 4.8, 17.2, 4.8, 12.8)
            ..lineTo(4.8, 6.4)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9.2, 12.2)
            ..lineTo(11.2, 14.2)
            ..lineTo(15.2, 9.2),
          stroke,
        );
    }

    canvas.restore();
  }

  Path _bookmarkPath() {
    return Path()
      ..moveTo(7, 3.8)
      ..lineTo(17, 3.8)
      ..lineTo(17, 20.2)
      ..lineTo(12, 16.4)
      ..lineTo(7, 20.2)
      ..close();
  }

  Path _heartPath() {
    return Path()
      ..moveTo(12, 20.2)
      ..cubicTo(5.4, 15.4, 3.6, 11.6, 4.6, 8.6)
      ..cubicTo(5.5, 5.9, 8.6, 4.9, 10.6, 6.5)
      ..cubicTo(11.3, 7.05, 11.7, 7.6, 12, 8.3)
      ..cubicTo(12.3, 7.6, 12.7, 7.05, 13.4, 6.5)
      ..cubicTo(15.4, 4.9, 18.5, 5.9, 19.4, 8.6)
      ..cubicTo(20.4, 11.6, 18.6, 15.4, 12, 20.2)
      ..close();
  }

  void _arrowHead(Canvas canvas, Paint fill, Offset tip, double angleRad) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angleRad);
    canvas.drawPath(
      Path()
        ..moveTo(1.6, 0)
        ..lineTo(-1.5, -1.7)
        ..lineTo(-1.5, 1.7)
        ..close(),
      fill,
    );
    canvas.restore();
  }

  double _rad(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
