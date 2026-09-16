import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../providers/settings_providers.dart';

/// Smart Cooldown Engine details.
///
/// Shown as a real [showModalBottomSheet] route instead of an in-page
/// expansion. That gives, for free and correctly:
///  * a dimmed barrier over the settings page ([ModalBarrier]),
///  * the page behind it can no longer be scrolled (the barrier absorbs
///    pointer events instead of leaking the gesture to the list below),
///  * tapping anywhere outside the sheet — or dragging it down — dismisses it
///    immediately as a cancel.
class CooldownDetailsSheet extends ConsumerWidget {
  const CooldownDetailsSheet({super.key});

  static const double _topRadius = 28;

  /// Opens the sheet. `barrierColor` provides the dimming; `isScrollControlled`
  /// lets the content grow past half the screen and scroll internally.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) => const CooldownDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final settingsAsync = ref.watch(appSettingsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: settingsAsync.when(
          data: (settings) => SingleChildScrollView(
            key: const Key('cooldown_details_sheet_scroll'),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.hairline(brightness),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _header(context, brightness, strings),
                const SizedBox(height: 6),
                Text(
                  strings.cooldownSheetSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 18),
                _proteinRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  protein: CooldownProtein.chicken,
                  emoji: '🐔',
                  style: AppPalette.chipGold(brightness),
                  name: strings.chicken,
                  days: settings.chickenCooldownDays,
                  defaultDays: 7,
                ),
                _divider(brightness),
                _proteinRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  protein: CooldownProtein.beef,
                  emoji: '🥩',
                  style: AppPalette.chipRose(brightness),
                  name: strings.beef,
                  days: settings.beefCooldownDays,
                  defaultDays: 10,
                ),
                _divider(brightness),
                _proteinRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  protein: CooldownProtein.fish,
                  emoji: '🐟',
                  style: AppPalette.chipBlue(brightness),
                  name: strings.fish,
                  days: settings.fishCooldownDays,
                  defaultDays: 5,
                ),
                _divider(brightness),
                _proteinRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  protein: CooldownProtein.meatless,
                  emoji: '🌿',
                  style: AppPalette.chipGreen(brightness),
                  name: strings.veggies,
                  days: settings.meatlessCooldownDays,
                  defaultDays: 3,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const Key('cooldown_details_done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.brandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      strings.done,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: CircularProgressIndicator(color: AppPalette.brandGreen),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              strings.errorGeneric(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary(brightness)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Brightness brightness, AppStrings strings) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppPalette.chipGreen(brightness).background,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AppIcon(
              AppGlyph.clock,
              color: AppPalette.chipGreen(brightness).foreground,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              strings.cooldownSheetTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _proteinRow(
    BuildContext context,
    WidgetRef ref,
    Brightness brightness,
    AppStrings strings, {
    required CooldownProtein protein,
    required String emoji,
    required ChipStyle style,
    required String name,
    required int days,
    required int defaultDays,
  }) {
    final enabled = days > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? strings.daysText(days) : strings.cooldownDisabledHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: Key('cooldown_switch_${protein.name}'),
            value: enabled,
            onChanged: (on) => _toggle(ref, protein, on, defaultDays),
          ),
        ],
      ),
    );
  }

  /// Turning a rule off stores the current day count in [cooldownMemoryProvider]
  /// (done inside the controller); turning it back on restores that value, or
  /// falls back to the product default.
  void _toggle(
    WidgetRef ref,
    CooldownProtein protein,
    bool on,
    int defaultDays,
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);
    if (on) {
      final remembered = ref.read(cooldownMemoryProvider)[protein];
      controller.setProteinCooldown(protein, remembered ?? defaultDays);
    } else {
      controller.setProteinCooldown(protein, 0);
    }
  }

  Widget _divider(Brightness brightness) => Divider(
        height: 1,
        thickness: 1,
        color: AppPalette.hairline(brightness),
      );
}
