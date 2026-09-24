import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import 'spin_wheel_candidate_tile.dart';
import 'spin_wheel_painter.dart';
import 'spin_wheel_pointer.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0.0;
  Meal? _winnerMeal;
  bool _isSpinning = false;
  int _lastSegment = 0;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioSession();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setAsset('assets/audio/tick.wav');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000), // Longer for premium casino feel
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.assistanceSonification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: true,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    
    double baseEndAngle = -math.pi / 2 - targetSectorAngle;
    while (baseEndAngle < 0) {
      baseEndAngle += 2 * math.pi;
    }
    
    const fullSpins = 8 * 2 * math.pi;
    final minEndAngle = _currentAngle + fullSpins;
    
    double endAngle = baseEndAngle;
    while (endAngle < minEndAngle) {
      endAngle += 2 * math.pi;
    }

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc),
    )..addListener(() {
        final currentA = _animation.value;
        final currentSegment = ((currentA + math.pi / 2) / sectorAngle).floor();
        if (currentSegment != _lastSegment) {
          _lastSegment = currentSegment;
          HapticFeedback.lightImpact();
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        }
        setState(() {});
      });

    // Seed the pointer's starting segment so the first peg crossing ticks.
    _lastSegment = ((_currentAngle + math.pi / 2) / sectorAngle).floor();

    _controller.forward(from: 0.0).then((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isSpinning = false;
        _currentAngle = endAngle % (2 * math.pi); // Keep it normalized
        _winnerMeal = widget.candidates[winnerIndex];
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        // Optionally show celebration
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
        height: MediaQuery.sizeOf(context).height * 0.75,
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
            child: Center(
              child: Text(
                strings.spinWheelTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    return AnimatedOpacity(
      // The wheel owns the moment while it spins; the list steps back.
      opacity: _isSpinning ? 0.45 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: ListView.builder(
        itemCount: widget.candidates.length,
        padding: const EdgeInsets.only(top: 2, bottom: 14),
        itemBuilder: (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 420 + math.min(index, 9) * 55),
            curve: Curves.easeOutQuint,
            builder: (context, value, child) => Transform.translate(
              offset: Offset((1 - value) * (isRtl ? 26 : -26), 0),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
            child: SpinWheelCandidateTile(
              index: index,
              meal: widget.candidates[index],
              tint: kSpinWheelTints[index % kSpinWheelTints.length],
              isRtl: isRtl,
            ),
          );
        },
      ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    strings.spinWheelLandedOn,
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _winnerMeal = null;
                  });
                },
              ),
            ],
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

    final phase = ((currentA + math.pi / 2) % sweepAngle + sweepAngle) % sweepAngle;
    final phaseNormalized = phase / sweepAngle;
    // Slowly gets pushed back, then snaps to 0 when passing the peg. The pin
    // now pivots on its rivet instead of its top edge, so the amplitude is
    // raised to keep the same visible flick at the tip.
    final flapperAngle = -0.68 * math.pow(phaseNormalized, 4).toDouble();

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
                painter: SpinWheelPainter(
                  candidates: widget.candidates,
                  tints: kSpinWheelTints,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Pawl riding the pegs.
          Positioned(
            top: 0,
            child: SpinWheelPointer(angle: flapperAngle),
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
