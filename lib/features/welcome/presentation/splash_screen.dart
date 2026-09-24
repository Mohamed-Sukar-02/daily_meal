import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../settings/providers/settings_providers.dart';

/// Aurora accent ramp used only by the splash chrome (glow + loader dots).
/// The logo artwork itself is never recoloured by these.
const List<Color> _aurora = [
  Color(0xFF0FB5BA), // teal
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // purple
];

/// Brand lockup rendered on the splash. The artwork already spells
/// "أكلة النهاردة", so no wordmark or tagline is drawn beneath it.
const String _logoAsset = 'assets/logos/daily_meal_logo.png';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// Keeps the branding on screen long enough to read on fast devices, where
  /// settings resolve in well under the entrance animation's own runtime.
  static const Duration _minDisplay = Duration(milliseconds: 1400);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _entrance,
          curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
        ),
      );
  late final Animation<double> _glow = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _checkFirstRun();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _dots.dispose();
    super.dispose();
  }

  void _checkFirstRun() async {
    // Wait for the first frame to render before checking to avoid go_router state issues
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final startedAt = DateTime.now();
      final destination = await _resolveDestination();

      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minDisplay) {
        await Future.delayed(_minDisplay - elapsed);
      }
      if (!mounted) return;
      context.go(destination);
    });
  }

  Future<String> _resolveDestination() async {
    try {
      final existing = ref.read(appSettingsProvider).valueOrNull;
      if (existing != null) return existing.isFirstRun ? '/welcome' : '/';

      final settings = await ref.read(appSettingsProvider.stream).first;
      return settings.isFirstRun ? '/welcome' : '/';
    } catch (_) {
      return '/'; // Fallback to home if something fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppPalette.background(brightness),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SplashBackdrop(isDark: isDark, glow: reduceMotion ? null : _glow),
            SafeArea(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The wordmark is dense illustration — it needs real pixel
                    // room or the spice textures collapse into mush.
                    final logoSize =
                        (constraints.maxWidth * 0.52).clamp(160.0, 230.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (reduceMotion)
                          Image.asset(
                            _logoAsset,
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          )
                        else
                          FadeTransition(
                            opacity: _fade,
                            child: ScaleTransition(
                              scale: _scale,
                              child: Image.asset(
                                _logoAsset,
                                width: logoSize,
                                height: logoSize,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        const SizedBox(height: 56),
                        if (reduceMotion)
                          const SizedBox(height: 21)
                        else
                          _BouncingDots(controller: _dots),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radial surface wash plus two low-opacity aurora orbs, so the splash shares
/// the app's cool-slate neutrals instead of a flat fill.
class _SplashBackdrop extends StatelessWidget {
  final bool isDark;
  final Animation<double>? glow;

  const _SplashBackdrop({required this.isDark, this.glow});

  @override
  Widget build(BuildContext context) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final base = AppPalette.background(brightness);
    final mid = AppPalette.card(brightness);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [mid, base],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _Orb(
              color: _aurora[0],
              size: 360,
              opacity: isDark ? 0.22 : 0.14,
              animation: glow,
            ),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: _Orb(
              color: _aurora[2],
              size: 420,
              opacity: isDark ? 0.24 : 0.16,
              animation: glow,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final Animation<double>? animation;

  const _Orb({
    required this.color,
    required this.size,
    required this.opacity,
    this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final orb = IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );

    if (animation == null) return orb;
    return FadeTransition(opacity: animation!, child: orb);
  }
}

class _BouncingDots extends StatelessWidget {
  final AnimationController controller;

  const _BouncingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot trails the last by a third of the cycle.
            final t = (controller.value + i / 3) % 1.0;
            final bounce = t < 0.5
                ? Curves.easeOut.transform(t * 2)
                : Curves.easeIn.transform((1 - t) * 2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.translate(
                offset: Offset(0, -12 * bounce),
                child: Transform.scale(
                  scale: 0.85 + 0.25 * bounce,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: _aurora),
                      boxShadow: [
                        BoxShadow(
                          color: _aurora[1].withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
