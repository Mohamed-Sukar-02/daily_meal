import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

class BlinkingCard extends StatefulWidget {
  final Brightness brightness;
  final Widget child;
  final bool shouldBlink;

  const BlinkingCard({
    super.key,
    required this.brightness,
    required this.child,
    this.shouldBlink = false,
  });

  @override
  State<BlinkingCard> createState() => _BlinkingCardState();
}

class _BlinkingCardState extends State<BlinkingCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _setupAnimation();
    if (widget.shouldBlink) {
      _controller.forward(from: 0.0);
    }
  }

  void _setupAnimation() {
    final baseColor = AppPalette.card(widget.brightness);
    final highlightColor = widget.brightness == Brightness.dark 
        ? Colors.white.withOpacity(0.15) 
        : Colors.black.withOpacity(0.15);
    
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        weight: 30,
        tween: ColorTween(begin: baseColor, end: highlightColor),
      ),
      TweenSequenceItem(
        weight: 70,
        tween: ColorTween(begin: highlightColor, end: baseColor),
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(BlinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      _setupAnimation();
    }
    if (widget.shouldBlink && !oldWidget.shouldBlink) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF1E293B).withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        );
      },
    );
  }
}
