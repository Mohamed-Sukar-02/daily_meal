import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';

class SpinWheelBottomSheet extends StatefulWidget {
  final List<Meal> candidates;
  final ValueChanged<Meal>? onWinnerCooked;

  const SpinWheelBottomSheet({
    super.key,
    required this.candidates,
    this.onWinnerCooked,
  });

  @override
  State<SpinWheelBottomSheet> createState() => _SpinWheelBottomSheetState();
}

class _SpinWheelBottomSheetState extends State<SpinWheelBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0.0;
  Meal? _winnerMeal;
  bool _isSpinning = false;
  int _lastSegment = 0;
  late AudioPlayer _audioPlayer;

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
    _audioPlayer = AudioPlayer();
    _audioPlayer.setAsset('assets/audio/tick.wav');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000), // Longer for premium casino feel
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
    
    // Distribute into many segments evenly
    int multiplier = 12 ~/ candidateCount;
    if (multiplier < 2) multiplier = 2; 
    final totalSegments = candidateCount * multiplier;

    final winnerIndex = random.nextInt(candidateCount);
    final sectorAngle = (2 * math.pi) / totalSegments;

    // Find all segments on the wheel that belong to the winner
    List<int> winningSegments = [];
    for (int i = 0; i < totalSegments; i++) {
      if (i % candidateCount == winnerIndex) {
        winningSegments.add(i);
      }
    }
    
    // Pick a random specific segment to land on
    final targetSegment = winningSegments[random.nextInt(winningSegments.length)];

    // Target angle brings the chosen sector directly under the top pointer (-pi/2 relative to wheel)
    final targetSectorAngle = (targetSegment + 0.5) * sectorAngle;
    const fullSpins = 8 * 2 * math.pi;
    final endAngle = _currentAngle + fullSpins + (2 * math.pi - targetSectorAngle);

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc),
    )..addListener(() {
        final currentA = _animation.value;
        final currentSegment = (currentA + math.pi / 2) ~/ sectorAngle;
        if (currentSegment != _lastSegment) {
          _lastSegment = currentSegment;
          HapticFeedback.selectionClick();
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        }
        setState(() {});
      });

    // Seed the pointer's starting segment so the first peg crossing ticks.
    _lastSegment = (_currentAngle + math.pi / 2) ~/ sectorAngle;

    _controller.forward(from: 0.0).then((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
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
    final strings = AppStrings.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (widget.candidates.length < 2) {
      return Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.all(24),
        child: Text(strings.spinWheelNeedsTwo),
      );
    }

    return PopScope(
      canPop: !_isSpinning,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.90,
        decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.spinWheelTitleEmoji,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isSpinning ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content Area (Candidates or Winner)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _winnerMeal == null 
                  ? _buildCandidatesList(isRtl)
                  : _buildWinnerCard(strings, theme),
            ),
          ),

          // Roulette Wheel Anchored at Bottom
          _buildRouletteWheel(context, strings),
        ],
      ),
    ),
    );
  }

  Widget _buildCandidatesList(bool isRtl) {
    return ListView.builder(
      itemCount: widget.candidates.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final meal = widget.candidates[index];
        final color = _palette[index % _palette.length];
        return _GlassyCandidateItem(
          index: index,
          meal: meal,
          baseColor: color,
          isRtl: isRtl,
        );
      },
    );
  }

  Widget _buildWinnerCard(AppStrings strings, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            strings.spinWheelLandedOn,
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)
              ]
            ),
            child: Text(
              _winnerMeal!.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _spin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(strings.spinWheelAgain, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onWinnerCooked?.call(_winnerMeal!);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(strings.cookedThisOne, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouletteWheel(BuildContext context, AppStrings strings) {
    final wheelSize = MediaQuery.sizeOf(context).width * 1.1;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buttonText = isArabic ? 'لف' : 'SPIN';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pointer behaves like a spring-loaded flapper pushed back by each peg.
    final currentA = _controller.isAnimating ? _animation.value : _currentAngle;
    final multiplier = 12 ~/ widget.candidates.length;
    final effectiveMultiplier = multiplier < 2 ? 2 : multiplier;
    final totalSegments = widget.candidates.length * effectiveMultiplier;
    final sweepAngle = (2 * math.pi) / totalSegments;

    final phase = (currentA + math.pi / 2) % sweepAngle;
    final phaseNormalized = phase / sweepAngle;
    // Slowly gets pushed back, then snaps to 0 when passing the peg.
    final flapperAngle = -0.5 * math.pow(phaseNormalized, 4).toDouble();

    return SizedBox(
      height: (wheelSize / 2) + 24, 
      width: MediaQuery.sizeOf(context).width,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Wheel Background
          Positioned(
            bottom: -(wheelSize / 2),
            child: Transform.rotate(
              angle: _controller.isAnimating ? _animation.value : _currentAngle,
              child: CustomPaint(
                size: Size(wheelSize, wheelSize),
                painter: _WheelPainter(
                  candidates: widget.candidates,
                  palette: _palette,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Top Arrow Indicator
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: flapperAngle,
              alignment: Alignment.topCenter,
              child: Icon(
                Icons.arrow_drop_down,
                size: 64,
                color: Colors.redAccent.shade400,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),

          // Central SPIN Button
          Positioned(
            bottom: -24, 
            child: GestureDetector(
              onTap: _isSpinning ? null : _spin,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
                ),
                alignment: Alignment.center,
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassyCandidateItem extends StatelessWidget {
  final int index;
  final Meal meal;
  final Color baseColor;
  final bool isRtl;

  const _GlassyCandidateItem({
    required this.index,
    required this.meal,
    required this.baseColor,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 700 + (index * 150)),
      curve: Curves.elasticOut, // High quality elastic bounce
      builder: (context, value, child) {
        final offset = (1 - value) * (isRtl ? 150 : -150);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), // Glassmorphism effect
            child: CustomPaint(
              painter: _GlassyItemPainter(
                baseColor: baseColor,
                isDark: isDark,
              ),
              child: Row(
                children: [
                  if (!isRtl) ...[
                    // LTR Layout
                    Expanded(child: _buildNameText(isDark)),
                    _buildNumberText(),
                  ] else ...[
                    // RTL Layout (first child is visually on the right)
                    _buildNumberText(),
                    Expanded(child: _buildNameText(isDark)),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberText() {
    return Container(
      width: 60,
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }

  Widget _buildNameText(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        meal.name,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GlassyItemPainter extends CustomPainter {
  final Color baseColor;
  final bool isDark;

  _GlassyItemPainter({
    required this.baseColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgOpacity = isDark ? 0.2 : 0.15;
    final blockOpacity = isDark ? 0.9 : 1.0;

    // Background fill
    final bgPaint = Paint()
      ..color = baseColor.withValues(alpha: bgOpacity)
      ..style = PaintingStyle.fill;
    
    // Slanted block fill
    final blockPaint = Paint()
      ..color = baseColor.withValues(alpha: blockOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, bgPaint);

    final path = Path();
    final blockWidth = 60.0;
    final slant = 15.0;

    // Draw block on the right side with a slant `\`. 
    // Top-left is at width - blockWidth + slant (further right)
    // Bottom-left is at width - blockWidth - slant (further left)
    // This creates a `/` shape divider.
    path.moveTo(size.width - blockWidth + slant, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - blockWidth - slant, size.height);
    path.close();

    canvas.drawPath(path, blockPaint);
    
    // Subtle inner border for glass effect
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.1 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassyItemPainter oldDelegate) => 
      oldDelegate.baseColor != baseColor || oldDelegate.isDark != isDark;
}

class _WheelPainter extends CustomPainter {
  final List<Meal> candidates;
  final List<Color> palette;
  final bool isDark;

  _WheelPainter({
    required this.candidates,
    required this.palette,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = candidates.length;
    
    // Distribute into many segments evenly
    int multiplier = 12 ~/ count;
    if (multiplier < 2) multiplier = 2; // guarantees at least 12 or 14 segments for >6 items
    final totalSegments = count * multiplier;
    
    final sweepAngle = (2 * math.pi) / totalSegments;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black.withValues(alpha: 0.15); // soft segment dividers

    final bgOpacity = isDark ? 0.2 : 0.15;

    for (int i = 0; i < totalSegments; i++) {
      final mealIndex = i % count;
      final startAngle = i * sweepAngle;

      // Match the exact faded color of the list item name section
      paint.color = palette[mealIndex % palette.length].withValues(alpha: bgOpacity);

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

      final textAngle = startAngle + sweepAngle / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final shortName = candidates[mealIndex].shortName?.isNotEmpty == true
          ? candidates[mealIndex].shortName!
          : candidates[mealIndex].name;

      final span = TextSpan(
        text: shortName,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          shadows: isDark 
              ? const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))]
              : const [Shadow(color: Colors.white70, blurRadius: 2, offset: Offset(0, 1))],
        ),
      );

      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.rtl,
      )..layout();

      // Place text nicely along the outer radius (2/3 from center)
      tp.paint(canvas, Offset(radius * 0.66 - tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    
    // Draw an elegant outer ring
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.candidates != candidates || oldDelegate.isDark != isDark;
  }
}
