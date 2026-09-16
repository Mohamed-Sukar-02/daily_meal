import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';

class SpinWheelDialog extends StatefulWidget {
  final List<Meal> candidates;
  final ValueChanged<Meal>? onWinnerCooked;

  const SpinWheelDialog({
    super.key,
    required this.candidates,
    this.onWinnerCooked,
  });

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0.0;
  Meal? _winnerMeal;
  bool _isSpinning = false;

  final List<Color> _palette = const [
    Color(0xFFE57373), // Coral Red
    Color(0xFFFFB74D), // Saffron Amber
    Color(0xFF4DB6AC), // Nile Teal
    Color(0xFF81C784), // Mint Green
    Color(0xFFBA68C8), // Violet
    Color(0xFFFFD54F), // Mustard
    Color(0xFF4DD0E1), // Cyan
    Color(0xFFA1887F), // Warm Spice
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    // _animation يتعبى بقيمة جاية من _spin() (حساب زاوية الفائز)،
    // بنحط قيمة ابتدائية هنا عشان نتجنب LateInitializationError لو build اتنادى قبل أول spin
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || widget.candidates.length < 2) return;

    setState(() {
      _isSpinning = true;
      _winnerMeal = null;
    });

    final random = math.Random();
    final candidateCount = widget.candidates.length;
    final winnerIndex = random.nextInt(candidateCount);
    final sectorAngle = (2 * math.pi) / candidateCount;

    // Pointer is at 12 o'clock (-pi / 2).
    // Target angle brings the chosen sector directly under the pointer.
    final targetSectorAngle = (winnerIndex + 0.5) * sectorAngle;
    const fullSpins = 6 * 2 * math.pi;
    final endAngle = _currentAngle + fullSpins + (2 * math.pi - targetSectorAngle);

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {});
      });

    _controller.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() {
        _currentAngle = endAngle % (2 * math.pi);
        _winnerMeal = widget.candidates[winnerIndex];
        _isSpinning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = widget.candidates;

    if (candidates.length < 2) {
      return AlertDialog(
        title: const Text('عجلة الحظ'),
        content: const Text('عجلة الحظ تحتاج إلى وجبتين على الأقل في الاقتراحات للتدوير!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Header
              Row(
                children: [
                  Icon(Icons.casino, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عجلة الحظ 🎡',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق',
                    onPressed: _isSpinning ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Roulette Wheel with Top Arrow Pointer
            LayoutBuilder(
              builder: (context, constraints) {
                final wheelSize = (constraints.maxWidth - 8).clamp(180.0, 260.0);
                return SizedBox(
                  height: wheelSize,
                  width: wheelSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating Wheel
                      Transform.rotate(
                        angle: _controller.isAnimating ? _animation.value : _currentAngle,
                        child: CustomPaint(
                          size: Size(wheelSize - 10, wheelSize - 10),
                          painter: _WheelPainter(
                            candidates: candidates,
                            palette: _palette,
                            theme: theme,
                          ),
                        ),
                      ),

                      // Center Spin Hub
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: Icon(
                          Icons.star,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      // Top Indicator Arrow (Pointing Down at 12 o'clock)
                      Positioned(
                        top: 0,
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 40,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Winner Display
            if (_winnerMeal != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '🎉 أكلة النهاردة وقعت على:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _winnerMeal!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isSpinning ? null : _spin,
                    child: Text(_winnerMeal == null ? 'ابدأ التدوير' : 'لف تاني'),
                  ),
                ),
                if (_winnerMeal != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onWinnerCooked?.call(_winnerMeal!);
                    },
                    child: const Text('طبخت دي'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Meal> candidates;
  final List<Color> palette;
  final ThemeData theme;

  _WheelPainter({
    required this.candidates,
    required this.palette,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = candidates.length;
    final sweepAngle = (2 * math.pi) / count;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white;

    for (int i = 0; i < count; i++) {
      final startAngle = i * sweepAngle;
      paint.color = palette[i % palette.length];

      // Draw Sector Wedge
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw Radiating Meal Name
      final textAngle = startAngle + sweepAngle / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final span = TextSpan(
        text: _truncate(candidates[i].name, 14),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      );

      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.rtl,
      )..layout();

      // Position text along outer radius
      tp.paint(canvas, Offset(radius * 0.32, -tp.height / 2));
      canvas.restore();
    }

    // Outer Rim Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = theme.colorScheme.primary,
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.candidates != candidates;
  }
}
