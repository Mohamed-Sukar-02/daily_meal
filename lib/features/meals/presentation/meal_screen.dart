import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Full meal screen — pixel-aligned to the approved mockups
/// (`meal_screen - light.png` / `meal_screen - dark.png`).
///
/// Layout (top → bottom):
///   1. Transparent status + floating short-name header + cloud mark
///   2. Full-bleed hero photo with soft full-name scrim at the bottom
///   3. Dark-green info banner overlapping the photo
///   4. Cream/dark sheet: Main / Side1 / Side2 curved tabs
///   5. "More Favorites" 2-col grid (outer chrome locked; interior free)
///   6. Bottom pill bar (placeholder — left empty per mockup note)
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
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
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
              topInset: topInset,
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
  final double topInset;
  final bool isProposing;
  final MealDishTab selectedDish;
  final ValueChanged<MealDishTab> onDishChanged;
  final VoidCallback? onCloudTap;
  final VoidCallback onFavoriteTap;

  const _MealBody({
    required this.meal,
    required this.brightness,
    required this.strings,
    required this.topInset,
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
    final isDark = brightness == Brightness.dark;
    final screenH = MediaQuery.sizeOf(context).height;
    // Hero fills ~48% of the screen like the mockup.
    final heroH = (screenH * 0.48).clamp(280.0, 420.0);

    return Stack(
      children: [
        // ── Scrollable content ────────────────────────────────────────
        Positioned.fill(
          child: CustomScrollView(
            key: const Key('meal_screen_body'),
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero + overlapping info card live in one sliver so the
              // banner can hang off the bottom of the photo.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: heroH + 78,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Full-bleed photo
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: heroH,
                        child: _HeroPhoto(
                          meal: meal,
                          fullName: fullName,
                          brightness: brightness,
                        ),
                      ),
                      // Soft header wash so short name + cloud stay legible
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: topInset + 72,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (isDark
                                          ? MealScreenPalette.darkHeader
                                          : MealScreenPalette.lightHeaderDeep)
                                      .withValues(alpha: 0.72),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Info banner overlapping the photo bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MealInfoBanner(
                          meal: meal,
                          brightness: brightness,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sheet body under the banner
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: MealScreenPalette.background(brightness),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),
                        // Dish tabs — curved pill strip
                        MealDishTabs(
                          selected: selectedDish,
                          onChanged: onDishChanged,
                        ),
                        // Selected-dish panel shell (frontend only)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: _DishPanel(
                            key: const Key('meal_screen_dish_panel'),
                            tab: selectedDish,
                            meal: meal,
                            brightness: brightness,
                            strings: strings,
                          ),
                        ),
                        const SizedBox(height: 22),
                        // More Favorites grid
                        MoreFavoritesGrid(currentMealId: meal.id),
                        // Bottom breathing room above the sticky pill
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Floating header (short name + cloud) ──────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('meal_screen_back_button'),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go('/vault');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                      iconSize: 20,
                    ),
                    Expanded(
                      child: Text(
                        shortName,
                        key: const Key('meal_screen_short_name'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: MealScreenPalette.shortName(brightness),
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Cloud mark (propose / synced) — top-right per mockup
                    IconButton(
                      key: const Key('meal_screen_cloud_button'),
                      tooltip: isProposing
                          ? strings.proposalInProgress
                          : strings.proposalCta,
                      onPressed: onCloudTap,
                      icon: isProposing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : AppIcon(
                              meal.cloudId != null
                                  ? AppGlyph.cloudDown
                                  : AppGlyph.cloudUp,
                              color: MealScreenPalette.cloud(brightness),
                              size: 24,
                            ),
                    ),
                    // Favourite (heart) — third app mark, kept accessible
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
          ),
        ),

        // ── Bottom pill bar (empty per mockup note) ───────────────────
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
// Hero photo + full-name scrim
// ─────────────────────────────────────────────────────────────────────────────

class _HeroPhoto extends StatelessWidget {
  final Meal meal;
  final String fullName;
  final Brightness brightness;

  const _HeroPhoto({
    required this.meal,
    required this.fullName,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final textDir = Directionality.of(context);
    // Trailing-edge dissolve: text ends on the left in RTL, right in LTR.
    final fadeOnStart = textDir == TextDirection.rtl;

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
          // Dual-axis name scrim: vertical top-fade + horizontal end-fade.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _NameScrimPainter(
                  veil: isDark
                      ? const Color(0xFF0B1210).withValues(alpha: 0.78)
                      : const Color(0xFF0F3D28).withValues(alpha: 0.55),
                  fadeOnStart: fadeOnStart,
                ),
              ),
            ),
          ),
          // Full name sitting on the scrim, just above the info banner.
          Positioned(
            left: 24,
            right: 24,
            bottom: 88,
            child: Text(
              fullName,
              key: const Key('meal_screen_full_name'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: MealScreenPalette.fullName(brightness),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft rectangular veil: transparent at top, solid at bottom; trailing edge
/// (text-end side) dissolves into the photo so the two layers blend.
class _NameScrimPainter extends CustomPainter {
  final Color veil;
  final bool fadeOnStart;

  _NameScrimPainter({required this.veil, required this.fadeOnStart});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final vertical = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          veil.withValues(alpha: 0.0),
          veil.withValues(alpha: veil.a * 0.55),
          veil,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vertical);

    // Erase the text-end side so the photo bleeds back in.
    final erase = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = LinearGradient(
        begin: fadeOnStart ? Alignment.centerLeft : Alignment.centerRight,
        end: fadeOnStart ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: 0.75),
          Colors.black.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.48],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, erase);
  }

  @override
  bool shouldRepaint(covariant _NameScrimPainter old) =>
      old.veil != veil || old.fadeOnStart != fadeOnStart;
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
              key: const Key('meal_screen_back_button'),
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
