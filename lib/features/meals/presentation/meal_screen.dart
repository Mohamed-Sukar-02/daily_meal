import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/meal_image.dart';
import '../../vault/application/meal_proposal_service.dart';
import '../../vault/providers/vault_providers.dart';
import 'widgets/meal_dish_tabs.dart';
import 'widgets/meal_info_banner.dart';
import 'widgets/meal_screen_palette.dart';
import 'widgets/more_favorites_grid.dart';

/// Full meal screen — pixel-aligned to `meal_screen - dark.png`.
///
/// Layout (top → bottom), matching the mockup exactly:
///   1. Header pill: short name between the upload mark and the heart,
///      with the back bubble floating off its side.
///   2. Rounded hero photo UNDER the header (no more full-bleed behind the
///      status bar) with the full name overlaid at its bottom.
///   3. Info banner whose white outline fuses with the dish-tab strip
///      (Main sits raised, connected to the banner — [interlock]).
///   4. Dish panel shell · "More Favorites" grid.
///   5. Bottom pill bar (left as-is per mockup note).
///
/// Reached at `/meal/:id` on the root navigator.
class MealScreen extends ConsumerStatefulWidget {
  final int mealId;

  const MealScreen({super.key, required this.mealId});

  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  MealDishTab _selectedDish = MealDishTab.main;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final mealsAsync = ref.watch(allMealsProvider);
    final isProposing =
        ref.watch(activeProposalMealIdProvider) == widget.mealId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Page chrome is solid now (no photo behind the status bar), so the
        // icons simply follow the theme.
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: MealScreenPalette.background(brightness),
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        key: const Key('meal_screen'),
        backgroundColor: MealScreenPalette.background(brightness),
        body: mealsAsync.when(
          data: (meals) {
            final meal = _findMeal(meals);
            if (meal == null) {
              return _NotFound(
                brightness: brightness,
                strings: strings,
              );
            }
            return _MealBody(
              meal: meal,
              brightness: brightness,
              strings: strings,
              isProposing: isProposing,
              selectedDish: _selectedDish,
              onDishChanged: (t) => setState(() => _selectedDish = t),
              onCloudTap: isProposing || meal.cloudId != null
                  ? null
                  : () => runProposalFlow(context, ref, meal),
              onFavoriteTap: () => ref
                  .read(vaultControllerProvider.notifier)
                  .toggleFavorite(meal.id, meal.isFavorite),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                strings.errorGeneric(error),
                textAlign: TextAlign.center,
                style: TextStyle(color: MealScreenPalette.muted(brightness)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Meal? _findMeal(List<Meal> meals) {
    for (final meal in meals) {
      if (meal.id == widget.mealId) return meal;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _MealBody extends StatelessWidget {
  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;
  final bool isProposing;
  final MealDishTab selectedDish;
  final ValueChanged<MealDishTab> onDishChanged;
  final VoidCallback? onCloudTap;
  final VoidCallback onFavoriteTap;

  const _MealBody({
    required this.meal,
    required this.brightness,
    required this.strings,
    required this.isProposing,
    required this.selectedDish,
    required this.onDishChanged,
    required this.onCloudTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = (meal.shortName?.trim().isNotEmpty == true)
        ? meal.shortName!.trim()
        : meal.name;
    final fullName = meal.name;
    final screenH = MediaQuery.sizeOf(context).height;
    // Hero proportions from the mockup once the header sits above it.
    final heroH = (screenH * 0.36).clamp(240.0, 380.0);

    return Stack(
      children: [
        // ── Scrollable content (header included — nothing floats over it) ──
        Positioned.fill(
          child: CustomScrollView(
            key: const Key('meal_screen_body'),
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1) Header pill (short name + upload mark + heart + back).
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: _MealHeaderBar(
                      shortName: shortName,
                      brightness: brightness,
                      strings: strings,
                      meal: meal,
                      isProposing: isProposing,
                      onCloudTap: onCloudTap,
                      onFavoriteTap: onFavoriteTap,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // 2) Hero photo — rounded card under the header, full name
              //    overlaid at the bottom.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: heroH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _HeroPhoto(
                        meal: meal,
                        fullName: fullName,
                        brightness: brightness,
                        strings: strings,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // 3) Info banner fused with the dish tabs (the mockup
              //    interlock, white edges included).
              SliverToBoxAdapter(
                child: _InterlockedInfoTabs(
                  meal: meal,
                  brightness: brightness,
                  selected: selectedDish,
                  onChanged: onDishChanged,
                ),
              ),

              // 4) Selected-dish panel shell (frontend only).
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _DishPanel(
                    key: const Key('meal_screen_dish_panel'),
                    tab: selectedDish,
                    meal: meal,
                    brightness: brightness,
                    strings: strings,
                  ),
                ),
              ),

              // 5) More Favorites grid
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(
                child: MoreFavoritesGrid(currentMealId: meal.id),
              ),

              // Bottom breathing room above the sticky pill
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),

        // ── Bottom pill bar (left as-is per mockup note) ───────────────────
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 12,
          child: _BottomPill(
            brightness: brightness,
            hint: strings.mealScreenBottomHint,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header pill: [back] · [upload  |  short name  |  heart]
// ─────────────────────────────────────────────────────────────────────────────

class _MealHeaderBar extends StatelessWidget {
  final String shortName;
  final Brightness brightness;
  final AppStrings strings;
  final Meal meal;
  final bool isProposing;
  final VoidCallback? onCloudTap;
  final VoidCallback onFavoriteTap;

  const _MealHeaderBar({
    required this.shortName,
    required this.brightness,
    required this.strings,
    required this.meal,
    required this.isProposing,
    required this.onCloudTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    // The mockup pins this chrome in RTL order in every locale: the pill is
    // right-dominant with the upload mark at its right end, and the back
    // bubble floats at the far left.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          // ── The pill itself ──────────────────────────────────────────
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  MealScreenPalette.headerBar(brightness),
                  MealScreenPalette.headerBarDeep(brightness),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: MealScreenPalette.headerBarBorder(brightness),
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                // Upload mark — the mockup's cloud doodle (top-right in RTL).
                IconButton(
                  key: const Key('meal_screen_cloud_button'),
                  tooltip: isProposing
                      ? strings.proposalInProgress
                      : strings.proposalCta,
                  onPressed: onCloudTap,
                  icon: _UploadMark(
                    isProposing: isProposing,
                    synced: meal.cloudId != null,
                    color: MealScreenPalette.cloud(brightness),
                  ),
                ),
                Expanded(
                  child: Text(
                    shortName,
                    key: const Key('meal_screen_short_name'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: MealScreenPalette.headerBarText(brightness),
                    ),
                  ),
                ),
                // Favourite heart — second mark inside the pill.
                IconButton(
                  key: const Key('meal_screen_favorite_button'),
                  tooltip: strings.favorite,
                  onPressed: onFavoriteTap,
                  icon: AppIcon(
                    meal.isFavorite
                        ? AppGlyph.heartFill
                        : AppGlyph.heartOutline,
                    color: meal.isFavorite
                        ? const Color(0xFFFF6B6B)
                        : Colors.white.withValues(alpha: 0.9),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // ── Back bubble floating off the pill's end ───────────────────
        Material(
          key: const Key('meal_screen_back_button'),
          color: MealScreenPalette.headerBarDeep(brightness),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/vault');
              }
            },
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MealScreenPalette.headerBarBorder(brightness),
                  width: 1.1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload mark: prefers the bundled `assets/icons/upload_icon.png`; while the
// asset is absent it falls back to an exact gold line-drawing of the mockup
// doodle (cloud + up arrow) so the chrome never breaks.
// ─────────────────────────────────────────────────────────────────────────────

class _UploadMark extends StatelessWidget {
  final bool isProposing;
  final bool synced;
  final Color color;

  const _UploadMark({
    required this.isProposing,
    required this.synced,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isProposing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }
    if (synced) {
      // Already published to the cloud vault — keep the synced variant.
      return AppIcon(AppGlyph.cloudDown, color: color, size: 24);
    }
    return Image.asset(
      'assets/icons/upload_icon.png',
      width: 26,
      height: 26,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        size: const Size(26, 26),
        painter: _UploadDoodlePainter(color),
      ),
    );
  }
}

/// Line-art replica of the mockup's hand-drawn upload doodle: a cloud
/// outline with an up arrow inside, drawn with round caps so it keeps the
/// same playful feel at any size/colour.
class _UploadDoodlePainter extends CustomPainter {
  final Color color;

  _UploadDoodlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.scale(s);

    // Cloud silhouette (classic cloud outline, bounds y 4 → 20).
    final cloud = Path()
      ..moveTo(19.35, 10.04)
      ..cubicTo(18.67, 6.59, 15.64, 4.0, 12.0, 4.0)
      ..cubicTo(9.11, 4.0, 6.6, 5.64, 5.35, 8.04)
      ..cubicTo(2.34, 8.36, 0.0, 10.91, 0.0, 14.0)
      ..cubicTo(0.0, 17.31, 2.69, 20.0, 6.0, 20.0)
      ..lineTo(19.0, 20.0)
      ..cubicTo(21.76, 20.0, 24.0, 17.76, 24.0, 15.0)
      ..cubicTo(24.0, 12.36, 21.95, 10.22, 19.35, 10.04)
      ..close();
    canvas.drawPath(cloud, paint);

    // Up arrow centred inside the cloud.
    final arrow = Path()
      ..moveTo(12.0, 18.4)
      ..lineTo(12.0, 10.8)
      ..moveTo(9.4, 13.3)
      ..lineTo(12.0, 10.7)
      ..lineTo(14.6, 13.3);
    canvas.drawPath(arrow, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UploadDoodlePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero photo, full-name overlay and meta chips (prep time / budget) — the
// chips keep the data that used to sit inside the old banner meta row.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroPhoto extends StatelessWidget {
  final Meal meal;
  final String fullName;
  final Brightness brightness;
  final AppStrings strings;

  const _HeroPhoto({
    required this.meal,
    required this.fullName,
    required this.brightness,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('meal_screen_hero'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MealImage(
            photoPath: meal.photoPath,
            cacheWidth: 1080,
            fit: BoxFit.cover,
            fallback: Container(
              color: MealScreenPalette.infoCard(brightness),
              child: Center(
                child: AppIcon(
                  AppGlyph.pot,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 56,
                ),
              ),
            ),
          ),
          // Subtle bottom band so the name reads over any photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.42),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Full meal name, large display type, one line when possible.
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: Text(
              fullName,
              key: const Key('meal_screen_full_name'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 26,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: MealScreenPalette.fullName(brightness),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Prep-time + budget chips, tucked into the photo's top corner.
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _MetaChip(
                      icon: AppGlyph.clock,
                      label: strings
                          .prepMinutesShort(meal.prepTime > 0 ? meal.prepTime : 0),
                      brightness: brightness,
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: AppGlyph.wallet,
                      label: meal.isBudgetFriendly
                          ? strings.budgetFriendly
                          : meal.category.label(strings),
                      brightness: brightness,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final AppGlyph icon;
  final String label;
  final Brightness brightness;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, color: Colors.white.withValues(alpha: 0.92), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interlock: info banner + dish tabs.
//
// The tab strip overlaps the banner's lower edge (18px). Around the ACTIVE
// tab the strip's own top border is erased ([_SeamPainter]) and the tab is
// raised + filled with the banner's deep green — so banner border, tab fill
// and strip border read as one continuous, white-edged shape, exactly like
// the mockup's "تداخل".
// ─────────────────────────────────────────────────────────────────────────────

class _InterlockedInfoTabs extends StatelessWidget {
  static const double _overlap = 18;

  final Meal meal;
  final Brightness brightness;
  final MealDishTab selected;
  final ValueChanged<MealDishTab> onChanged;

  const _InterlockedInfoTabs({
    required this.meal,
    required this.brightness,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const bannerH = MealInfoBanner.height;
    const pillH = MealDishTabs.height;
    const stickOut = pillH - _overlap;

    return SizedBox(
      height: bannerH + stickOut,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final activeIndex = switch (selected) {
            MealDishTab.main => 0,
            MealDishTab.side1 => 1,
            MealDishTab.side2 => 2,
          };
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner on top so its white border is drawn over the strip
              // everywhere; the strip stays visible in its stick-out zone.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bannerH,
                child: MealInfoBanner(meal: meal, brightness: brightness),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: bannerH - _overlap,
                height: pillH,
                child: MealDishTabs(selected: selected, onChanged: onChanged),
              ),
              // Foreground seam eraser (painted last = topmost).
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SeamPainter(
                      activeIndex: activeIndex,
                      bannerColor:
                          MealScreenPalette.infoCardDeep(brightness),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Erases the tab strip's top border ONLY above the active tab so the
/// raised tab fill (same colour family as the banner bottom) merges with
/// the banner body — the two white outlines become one.
class _SeamPainter extends CustomPainter {
  static const double _overlap = 18;
  static const double _hMargin = 16; // matches banner & strip margins
  static const double _stripPad = 6; // matches MealDishTabs padding

  final int activeIndex;
  final Color bannerColor;

  _SeamPainter({required this.activeIndex, required this.bannerColor});

  @override
  void paint(Canvas canvas, Size size) {
    const bannerH = MealInfoBanner.height;
    const stripTop = bannerH - _overlap;

    final slotW = (size.width - _hMargin * 2 - _stripPad * 2) / 3;
    final left = _hMargin + _stripPad + slotW * activeIndex;

    // Wipe the strip's top border across the active slot (inset 3 so the
    // erased band never eats the neighbouring border, which reads as the
    // tab's "shoulders").
    canvas.drawRect(
      Rect.fromLTWH(left + 3, stripTop - 0.9, slotW - 6, 3.2),
      Paint()..color = bannerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SeamPainter old) =>
      old.activeIndex != activeIndex || old.bannerColor != bannerColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dish panel shell (Main / Side content — frontend placeholder)
// ─────────────────────────────────────────────────────────────────────────────

class _DishPanel extends StatelessWidget {
  final MealDishTab tab;
  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;

  const _DishPanel({
    super.key,
    required this.tab,
    required this.meal,
    required this.brightness,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final notes = meal.notes?.trim() ?? '';
    final title = switch (tab) {
      MealDishTab.main => strings.mainDish,
      MealDishTab.side1 => strings.sideDish1,
      MealDishTab.side2 => strings.sideDish2,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(tab),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MealScreenPalette.card(brightness),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MealScreenPalette.cardBorder(brightness)),
        ),
        child: tab == MealDishTab.main && notes.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: MealScreenPalette.muted(brightness),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: MealScreenPalette.text(brightness),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: MealScreenPalette.muted(brightness),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Bone(brightness: brightness, widthFactor: 0.92),
                  const SizedBox(height: 8),
                  _Bone(brightness: brightness, widthFactor: 0.68),
                  const SizedBox(height: 8),
                  _Bone(brightness: brightness, widthFactor: 0.78),
                ],
              ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final Brightness brightness;
  final double widthFactor;
  const _Bone({required this.brightness, required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: MealScreenPalette.cardBorder(brightness),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom pill (left empty — mockup note)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPill extends StatelessWidget {
  final Brightness brightness;
  final String hint;

  const _BottomPill({required this.brightness, required this.hint});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          key: const Key('meal_screen_bottom_pill'),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: MealScreenPalette.bottomBar(brightness)
                .withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Not found
// ─────────────────────────────────────────────────────────────────────────────

class _NotFound extends StatelessWidget {
  final Brightness brightness;
  final AppStrings strings;

  const _NotFound({required this.brightness, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('meal_screen_not_found'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppGlyph.pot,
              color: MealScreenPalette.muted(brightness),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              strings.mealNotFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MealScreenPalette.muted(brightness),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/vault');
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(strings.close),
            ),
          ],
        ),
      ),
    );
  }
}
