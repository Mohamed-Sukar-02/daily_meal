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
import 'widgets/meal_name_scrim.dart';
import 'widgets/meal_screen_palette.dart';
import 'widgets/more_favorites_grid.dart';

/// Full meal screen — ported from the approved `premium-flutter-meal-screen`
/// prototype, which itself follows `meal_screen - dark.png` for structure and
/// `meal_screen - light.png` for colour distribution.
///
/// Layout (top → bottom):
///   1. Solid app bar: back · centred short name · sync / favourite / status.
///   2. Full-bleed hero photo whose bottom [_heroBleed] continues behind the
///      info card, fading into the page. The full name sits on top of it over
///      a corner-anchored elliptical bloom (see [MealNameScrim]).
///   3. Green info card fused with the dish strip via the folder-tab curve.
///   4. Selected-dish panel shell · "More Favorites" grid.
///   5. Pinned, deliberately empty bottom pill.
///
/// Reached at `/meal/:id` on the root navigator.
class MealScreen extends ConsumerStatefulWidget {
  final int mealId;

  const MealScreen({super.key, required this.mealId});

  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  static const double _heroBleed = 110;

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
        // The app bar is solid and dark in both modes, so the status bar
        // inherits its colour and always shows light icons.
        statusBarColor: MealScreenPalette.appBar(brightness),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: MealScreenPalette.footer(brightness),
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        key: const Key('meal_screen'),
        backgroundColor: MealScreenPalette.background(brightness),
        body: mealsAsync.when(
          data: (meals) {
            final meal = _findMeal(meals);
            if (meal == null) {
              return _NotFound(brightness: brightness, strings: strings);
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
  static const double _heroBleed = _MealScreenState._heroBleed;

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
    final screenH = MediaQuery.sizeOf(context).height;
    final heroH = (screenH * 0.36).clamp(240.0, 300.0);
    final sheet = MealScreenPalette.sheet(brightness);

    return Column(
      children: [
        _MealAppBar(
          shortName: shortName,
          meal: meal,
          brightness: brightness,
          strings: strings,
          isProposing: isProposing,
          onCloudTap: onCloudTap,
          onFavoriteTap: onFavoriteTap,
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('meal_screen_body'),
            physics: const BouncingScrollPhysics(),
            child: ColoredBox(
              // The active folder tab is cut in this same colour, so the tab
              // and the surface it stands on have to be one continuous fill.
              color: sheet,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The photo keeps running behind the info card and dissolves
                  // into the page colour, exactly like the reference.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: heroH + _heroBleed,
                    child: ClipRect(
                      key: const Key('meal_screen_hero'),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MealImage(
                            photoPath: meal.photoPath,
                            cacheWidth: 1080,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            fallback: _HeroFallback(brightness: brightness),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: _heroBleed + 30,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    sheet.withValues(alpha: 0),
                                    sheet.withValues(alpha: 0.55),
                                    sheet,
                                  ],
                                  stops: const [0, 0.45, 1],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: heroH,
                        child: _HeroName(
                          fullName: meal.name,
                          heroHeight: heroH,
                          brightness: brightness,
                        ),
                      ),
                      _InterlockedInfoTabs(
                        meal: meal,
                        brightness: brightness,
                        selected: selectedDish,
                        onChanged: onDishChanged,
                      ),
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
                      MoreFavoritesGrid(currentMealId: meal.id),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _BottomBar(brightness: brightness),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar: [back] · short name (centred) · [sync] [favourite] [status]
// ─────────────────────────────────────────────────────────────────────────────

class _MealAppBar extends StatelessWidget {
  final String shortName;
  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;
  final bool isProposing;
  final VoidCallback? onCloudTap;
  final VoidCallback onFavoriteTap;

  const _MealAppBar({
    required this.shortName,
    required this.meal,
    required this.brightness,
    required this.strings,
    required this.isProposing,
    required this.onCloudTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final synced = meal.cloudId != null;
    final statusGlyph = meal.isFridaySpecial
        ? AppGlyph.flame
        : (meal.isBudgetFriendly ? AppGlyph.wallet : null);

    return Container(
      color: MealScreenPalette.appBar(brightness),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    shortName,
                    key: const Key('meal_screen_short_name'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Row(
                  children: [
                    _BarButton(
                      key: const Key('meal_screen_back_button'),
                      tooltip: strings.welcomeBack,
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go('/vault');
                        }
                      },
                      child: Icon(
                        rtl
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    _BarButton(
                      key: const Key('meal_screen_cloud_button'),
                      tooltip: isProposing
                          ? strings.proposalInProgress
                          : strings.proposalCta,
                      onTap: onCloudTap,
                      child: _SyncMark(
                        isProposing: isProposing,
                        synced: synced,
                        color: synced
                            ? MealScreenPalette.syncDone(brightness)
                            : MealScreenPalette.syncIdle(brightness),
                      ),
                    ),
                    _BarButton(
                      key: const Key('meal_screen_favorite_button'),
                      tooltip: strings.favorite,
                      onTap: onFavoriteTap,
                      child: AppIcon(
                        meal.isFavorite
                            ? AppGlyph.heartFill
                            : AppGlyph.heartOutline,
                        color: meal.isFavorite
                            ? MealScreenPalette.heart(brightness)
                            : Colors.white,
                        size: 22,
                      ),
                    ),
                    if (statusGlyph != null)
                      Tooltip(
                        message: meal.isFridaySpecial
                            ? strings.fridaySpecial
                            : strings.budgetFriendly,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: AppIcon(
                            statusGlyph,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final Key? key;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  const _BarButton({
    this.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        iconSize: 24,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        splashColor: Colors.white.withValues(alpha: 0.12),
        icon: child,
      ),
    );
  }
}

class _SyncMark extends StatelessWidget {
  final bool isProposing;
  final bool synced;
  final Color color;

  const _SyncMark({
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
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return AppIcon(
      synced ? AppGlyph.cloudDown : AppGlyph.cloudUp,
      color: color,
      size: 23,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero name + bloom
// ─────────────────────────────────────────────────────────────────────────────

class _HeroName extends StatelessWidget {
  final String fullName;
  final double heroHeight;
  final Brightness brightness;

  const _HeroName({
    required this.fullName,
    required this.heroHeight,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      fit: StackFit.expand,
      children: [
        MealNameScrim(brightness: brightness, heroHeight: heroHeight),
        Positioned(
          left: 24,
          right: 24,
          bottom: 12,
          child: Text(
            fullName,
            key: const Key('meal_screen_full_name'),
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: MealScreenPalette.fullName(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroFallback extends StatelessWidget {
  final Brightness brightness;
  const _HeroFallback({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MealScreenPalette.cardBottom(brightness),
      alignment: Alignment.center,
      child: AppIcon(
        AppGlyph.pot,
        color: Colors.white.withValues(alpha: 0.55),
        size: 56,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card + dish strip interlock: the strip tucks [MealDishTabs.overlap] up
// over the card's bottom edge, and the folder-tab curve carries the active
// segment into the page.
// ─────────────────────────────────────────────────────────────────────────────

class _InterlockedInfoTabs extends StatelessWidget {
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
    const stickOut = MealDishTabs.height - MealDishTabs.overlap;

    return SizedBox(
      height: bannerH + stickOut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
            top: bannerH - MealDishTabs.overlap,
            height: MealDishTabs.height,
            child: MealDishTabs(selected: selected, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dish panel shell (per-dish content arrives with the backend)
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
                  _Heading(brightness: brightness, title: title),
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
                  _Heading(brightness: brightness, title: title),
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

class _Heading extends StatelessWidget {
  final Brightness brightness;
  final String title;
  const _Heading({required this.brightness, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: MealScreenPalette.muted(brightness),
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
// Pinned bottom bar — locked shell, deliberately empty until its content is
// decided (the Arabic sentence in the mockup is an instruction, not UI copy).
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final Brightness brightness;
  const _BottomBar({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final isDark = MealScreenPalette.isDark(brightness);

    return Container(
      color: MealScreenPalette.footer(brightness),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        key: const Key('meal_screen_bottom_pill'),
        height: 56,
        padding: const EdgeInsetsDirectional.only(start: 18, end: 12),
        decoration: BoxDecoration(
          color: MealScreenPalette.bottomPill(brightness),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? MealScreenPalette.accent(
                        brightness,
                      ).withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.16),
              ),
              child: Icon(
                rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
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
