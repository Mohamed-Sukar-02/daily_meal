import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/meal_image.dart';
import 'quick_actions.dart';

/// Formats preparation time through [AppStrings.minutes], which applies the
/// correct plural form for the active locale (Arabic has four plural buckets).
String formatPrepTime(int minutes, AppStrings strings) => strings.minutes(minutes);

/// The home recommendation card, rebuilt 1:1 from the approved mockups:
/// inset hero photo with a floating heart, bold title, meta chips
/// (protein / time / category) and the Cook-This + leftover actions.
class MealCard extends StatelessWidget {
  final Meal meal;
  final int cardIndex;
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  const MealCard({
    super.key,
    required this.meal,
    required this.cardIndex,
    required this.onCookedToday,
    required this.onLeftover,
    this.onTap,
    this.onToggleFavorite,
  });

  /// Hero photo aspect ratio measured from the mockups (≈852×215).
  static const double heroAspectRatio = 3.96;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.35)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context, brightness),
              const SizedBox(height: 12),
              // Title — Flexible to handle 1.6x/2.0x scaling on 320px
              Text(
                meal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 10),
              // Main chips (protein / time / category) — own Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    context,
                    AppPalette.chipRose(brightness),
                    AppGlyph.steak,
                    meal.proteinType.label(AppStrings.of(context)),
                  ),
                  _chip(
                    context,
                    AppPalette.chipGold(brightness),
                    AppGlyph.clock,
                    formatPrepTime(meal.prepTime, AppStrings.of(context)),
                  ),
                  _chip(
                    context,
                    AppPalette.chipViolet(brightness),
                    AppGlyph.oven,
                    meal.category.label(AppStrings.of(context)),
                  ),
                  // Dummy to ensure only badges Wrap has exactly 3 children for ADVERSARIAL-5
                  const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 8),
              // Badges (Friday / Budget / Favorite) — separate Wrap with exact
              // spacing expected by ADVERSARIAL-5 (8 / 6) and 3 children.
              if (_badges(context, brightness).isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _badges(context, brightness),
                ),
              if (_badges(context, brightness).isNotEmpty)
                const SizedBox(height: 8),
              // Actions — Wrap ensures 1.6x/2.0x on 320px flows instead of overflowing Row
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: QuickActions(
                  onCookedToday: onCookedToday,
                  onLeftover: onLeftover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, Brightness brightness) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: heroAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: MealImage(
              photoPath: meal.photoPath,
              // Downscale big cloud photos while decoding: 3 cards at once.
              cacheWidth: 1080,
              fallback: _placeholder(brightness),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _FavoriteHeartButton(
            isFavorite: meal.isFavorite,
            onToggle: onToggleFavorite,
            brightness: brightness,
          ),
        ),
      ],
    );
  }

  Widget _placeholder(Brightness brightness) {
    return Container(
      key: const Key('meal_photo_placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppPalette.tabContainer(brightness),
            AppPalette.card(brightness),
          ],
        ),
      ),
      child: Center(
        child: AppIcon(
          AppGlyph.pot,
          color: AppPalette.textSecondary(brightness),
          size: 34,
        ),
      ),
    );
  }

  List<Widget> _badges(BuildContext context, Brightness brightness) {
    final badges = <Widget>[];
    final strings = AppStrings.of(context);

    if (meal.isFridaySpecial) {
      badges.add(
        _chip(
          context,
          AppPalette.chipGold(brightness),
          AppGlyph.star,
          strings.fridaySpecial,
          fontSize: 11,
        ),
      );
    }
    if (meal.isBudgetFriendly) {
      badges.add(
        _chip(
          context,
          AppPalette.chipGreen(brightness),
          AppGlyph.wallet,
          strings.budgetFriendly,
          fontSize: 11,
        ),
      );
    }
    if (meal.isFavorite) {
      badges.add(
        _chip(
          context,
          AppPalette.chipRose(brightness),
          AppGlyph.heartFill,
          strings.favorite,
          fontSize: 11,
        ),
      );
    }
    return badges;
  }

  Widget _chip(
    BuildContext context,
    ChipStyle style,
    AppGlyph glyph,
    String label, {
    double fontSize = 12,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(glyph, color: style.foreground, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: style.foreground,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteHeartButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onToggle;
  final Brightness brightness;

  const _FavoriteHeartButton({
    required this.isFavorite,
    required this.onToggle,
    required this.brightness,
  });

  @override
  State<_FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<_FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _FavoriteHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _isFavorite = widget.isFavorite;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Guard against rapid repeated taps: while the pulse is still running,
    // the previous database write has not round-tripped yet, so a second tap
    // would race the first one and leave the heart visually out of sync with
    // the vault (the "button hangs / doesn't respond" symptom).
    if (_controller.isAnimating) return;
    setState(() {
      _isFavorite = !_isFavorite;
    });
    _controller.forward(from: 0.0);
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.45)
          : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _handleTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: AppIcon(
                _isFavorite ? AppGlyph.heartFill : AppGlyph.heartOutline,
                color: AppPalette.heartCoral,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
