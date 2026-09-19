import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/presentation/widgets/emphasis_marks.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/admin_auth_service.dart';
import '../../../core/navigation/nav_lifecycle.dart';
import '../providers/settings_providers.dart';
import 'widgets/cooldown_details_sheet.dart';
import 'widgets/legal_policies_dialog.dart' as widgets;
import 'widgets/profile_edit_dialog.dart';
import 'widgets/time_wheel_picker.dart';

/// Settings screen rebuilt from the approved mockups (light + dark):
/// header with shine marks, profile card, then titled sections whose cards
/// float on the page background. "More" opens the per-protein cooldown
/// enable/disable switches in a modal bottom sheet (a protein at 0 days =
/// cooldown off).
///
/// Lifecycle: leaving this tab and coming back resets UI-only state (the page
/// scroll offset). The cooldown details are a modal route, so there is no
/// long-lived "expanded" flag left to reset. Settings data itself is never
/// invalidated here.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with NavBranchReentry {
  final ScrollController _scrollController = ScrollController();

  /// Anchors the notifications section so an incoming
  /// `/settings?section=notifications` navigation can auto-scroll to it.
  final GlobalKey _notificationsSectionKey = GlobalKey();

  /// The GoRouterState instance we already auto-scrolled for — a fresh push
  /// creates a fresh instance, while unrelated dependency changes (locale,
  /// theme) must not re-trigger the scroll.
  GoRouterState? _scrolledForState;

  @override
  int get navBranchIndex => NavBranch.settings;

  @override
  void resetTransientUi() => resetScroll(_scrollController);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// When opened via `/settings?section=notifications` (from the
  /// notifications center), scroll straight to the notifications section.
  ///
  /// The shell reuses this state across navigations, so the check lives in
  /// [didChangeDependencies] — it fires both on first mount and whenever the
  /// route's GoRouterState changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routerState = GoRouterState.maybeOf(context);
    if (routerState == null) return;
    if (routerState.uri.queryParameters['section'] != 'notifications') return;
    if (identical(_scrolledForState, routerState)) return;
    _scrolledForState = routerState;
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        _scrollToNotificationsSection(attempt: 0));
  }

  /// The section only exists once the settings data has loaded, so the first
  /// frame may not have it yet — retry a bounded number of frames.
  void _scrollToNotificationsSection({required int attempt}) {
    if (!mounted) return;
    final sectionContext = _notificationsSectionKey.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        alignment: 0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    if (attempt < 30) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _scrollToNotificationsSection(attempt: attempt + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    watchNavReentry();
    // Register a dependency on the route state so didChangeDependencies fires
    // on every navigation (a fresh GoRouterState per push).
    GoRouterState.maybeOf(context);
    final settingsAsync = ref.watch(appSettingsProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      body: SafeArea(
        bottom: false,
        child: settingsAsync.when(
          data: (settings) {
            final strings = AppStrings(settings.language == AppLanguagePreference.ar ? const Locale('ar') : const Locale('en'));
            return ListView(
              key: const Key('settings_scroll_view'),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildHeader(brightness, strings),
                const SizedBox(height: 20),
                _buildProfileCard(context, ref, settings, brightness, strings),
                const SizedBox(height: 24),
                _buildCooldownSection(context, ref, settings, brightness, strings),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _notificationsSectionKey,
                  child: _buildNotificationsSection(context, ref, settings, brightness, strings),
                ),
                const SizedBox(height: 24),
                _buildAppearanceSection(context, ref, settings, brightness, strings),
                const SizedBox(height: 24),
                _buildAdminSection(context, brightness, strings),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppPalette.brandGreen),
          ),
          error: (err, _) {
            final fallbackStrings = AppStrings(const Locale('ar'));
            return Center(
              child: Text(
                '${fallbackStrings.errorOccurred}$err',
                style: TextStyle(color: AppPalette.textSecondary(brightness)),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header + profile
  // ---------------------------------------------------------------------------

  Widget _buildHeader(Brightness brightness, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  strings.navSettings,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            EmphasisMarks(size: 20, mirrored: strings.isEn),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          strings.settingsSubtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppPalette.textSecondary(brightness),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    Brightness brightness,
    AppStrings strings,
  ) {
    return _Card(
      brightness: brightness,
      child: InkWell(
        key: const Key('settings_profile_card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => ProfileEditDialog.show(context, settings),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _AvatarWidget(
                    avatarPath: settings.userAvatar,
                    size: 72,
                    brightness: brightness,
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppPalette.card(brightness),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: AppIcon(AppGlyph.pencil, color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.userName?.trim().isNotEmpty == true
                          ? settings.userName!
                          : strings.defaultUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      settings.userEmail?.trim().isNotEmpty == true
                          ? settings.userEmail!
                          : strings.defaultUserEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon(
                AppGlyph.chevron,
                color: AppPalette.textSecondary(brightness),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Cooldown Engine
  // ---------------------------------------------------------------------------

  Widget _buildCooldownSection(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    Brightness brightness,
    AppStrings strings,
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          key: const Key('settings_cooldown_header'),
          brightness: brightness,
          title: strings.smartCooldownEngine,
          link: strings.more,
          linkKey: const Key('settings_cooldown_more'),
          linkColor: const Color(0xFF3E63DD),
          // A real modal bottom sheet: dims the page, blocks background
          // scrolling and closes on an outside tap or a downward drag.
          onLink: () => CooldownDetailsSheet.show(context),
        ),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: _CooldownSliderItem(
                  initialDays: settings.cooldownDays,
                  brightness: brightness,
                  strings: strings,
                  onChangeEnd: (days) => controller.updateCooldownDays(days),
                ),
              ),
              if (settings.chickenCooldownDays > 0) ...[
                _divider(brightness),
                _stepperRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  emoji: '🐔',
                  style: AppPalette.chipGold(brightness),
                  name: strings.chicken,
                  days: settings.chickenCooldownDays,
                  onChanged: (d) => controller.updateChickenCooldownDays(d),
                ),
              ],
              if (settings.beefCooldownDays > 0) ...[
                _divider(brightness),
                _stepperRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  emoji: '🥩',
                  style: AppPalette.chipRose(brightness),
                  name: strings.beef,
                  days: settings.beefCooldownDays,
                  onChanged: (d) => controller.updateBeefCooldownDays(d),
                ),
              ],
              if (settings.fishCooldownDays > 0) ...[
                _divider(brightness),
                _stepperRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  emoji: '🐟',
                  style: AppPalette.chipBlue(brightness),
                  name: strings.fish,
                  days: settings.fishCooldownDays,
                  onChanged: (d) => controller.updateFishCooldownDays(d),
                ),
              ],
              if (settings.meatlessCooldownDays > 0) ...[
                _divider(brightness),
                _stepperRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  key: const Key('cooldown_stepper_meatless'),
                  emoji: '🌿',
                  style: AppPalette.chipGreen(brightness),
                  name: strings.veggies,
                  days: settings.meatlessCooldownDays,
                  onChanged: (d) => controller.updateMeatlessCooldownDays(d),
                ),
              ],
            ],
          ),
        )
      ],
    );
  }

  Widget _stepperRow(
    BuildContext context,
    WidgetRef ref,
    Brightness brightness,
    AppStrings strings, {
    Key? key,
    required String emoji,
    required ChipStyle style,
    required String name,
    required int days,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _emojiCircle(brightness, emoji, style),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    strings.waitingDays,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.textSecondary(brightness),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _stepButton(brightness, AppGlyph.minus, () => onChanged((days - 1).clamp(0, 30))),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24, maxWidth: 36),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$days',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                ),
              ),
              _stepButton(brightness, AppGlyph.plus, () => onChanged((days + 1).clamp(0, 30))),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Widget _buildNotificationsSection(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    Brightness brightness,
    AppStrings strings,
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: strings.notifications),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconCircle(brightness, Icons.notifications_active_outlined, AppPalette.chipGold(brightness)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              strings.dailyReminder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.textPrimary(brightness),
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              strings.dailyReminderDesc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppPalette.textSecondary(brightness),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: settings.notificationsEnabled,
                      onChanged: (v) => controller.toggleNotifications(v),
                    ),
                  ],
                ),
              ),
              _divider(brightness),
              Opacity(
                opacity: settings.notificationsEnabled ? 1.0 : 0.45,
                child: IgnorePointer(
                  ignoring: !settings.notificationsEnabled,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _iconCircle(brightness, Icons.access_time_rounded, AppPalette.chipViolet(brightness)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  strings.reminderTime,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppPalette.textPrimary(brightness),
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  strings.reminderTimeDesc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.textSecondary(brightness),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final picked = await _showWheelTimePicker(
                              context,
                              brightness,
                              TimeOfDay(
                                hour: settings.notificationHour,
                                minute: settings.notificationMinute,
                              ),
                              strings,
                            );
                            if (picked != null) {
                              controller.updateNotificationTime(picked.hour, picked.minute);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppPalette.chipViolet(brightness).background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  AppGlyph.clock,
                                  color: AppPalette.chipViolet(brightness).foreground,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(settings, strings),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.chipViolet(brightness).foreground,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AppIcon(
                                  AppGlyph.chevron,
                                  color: AppPalette.chipViolet(brightness).foreground,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Appearance & Backup
  // ---------------------------------------------------------------------------

  Widget _buildAppearanceSection(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    Brightness brightness,
    AppStrings strings,
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    String themeLabel(AppThemeModePreference m) {
      switch (m) {
        case AppThemeModePreference.dark:
          return strings.themeDark;
        case AppThemeModePreference.light:
          return strings.themeLight;
        case AppThemeModePreference.system:
          return strings.themeSystem;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: strings.appearanceAndLanguage),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconCircle(
                      brightness,
                      brightness == Brightness.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      brightness == Brightness.dark
                          ? AppPalette.chipViolet(brightness)
                          : AppPalette.chipGold(brightness),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              strings.appearance,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.textPrimary(brightness),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              strings.chooseAppAppearance,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppPalette.textSecondary(brightness),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.tabContainer(brightness),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.hairline(brightness)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AppThemeModePreference>(
                          value: settings.themeMode,
                          isDense: true,
                          icon: AppIcon(AppGlyph.chevron, color: AppPalette.textSecondary(brightness), size: 14),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textPrimary(brightness),
                          ),
                          dropdownColor: AppPalette.card(brightness),
                          borderRadius: BorderRadius.circular(12),
                          onChanged: (v) {
                            if (v != null) controller.updateThemeMode(v);
                          },
                          items: [
                            DropdownMenuItem(value: AppThemeModePreference.system, child: Text(themeLabel(AppThemeModePreference.system))),
                            DropdownMenuItem(value: AppThemeModePreference.light, child: Text(themeLabel(AppThemeModePreference.light))),
                            DropdownMenuItem(value: AppThemeModePreference.dark, child: Text(themeLabel(AppThemeModePreference.dark))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _divider(brightness),
              // Language Segmented Control - SAME outer shape as switch cards (radius 20, height 44, tabContainer bg, hairline border)
              // Divided in middle: EN left, AR right - exactly as old design requested
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconCircle(brightness, AppGlyph.globe, AppPalette.chipBlue(brightness)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              strings.languageSettings,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.textPrimary(brightness),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              settings.language == AppLanguagePreference.ar ? strings.languageArabic : strings.languageEnglish,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppPalette.textSecondary(brightness),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // EXACT old shape: same outer shape as switches, divided middle AR right EN left
                    Container(
                      height: 44,
                      width: 124,
                      decoration: BoxDecoration(
                        color: AppPalette.tabContainer(brightness),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppPalette.hairline(brightness), width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _LanguageSegment(
                                brightness: brightness,
                                label: 'EN',
                                isLeft: true,
                                selected: settings.language == AppLanguagePreference.en,
                                onTap: () => controller.updateLanguage(AppLanguagePreference.en),
                              ),
                            ),
                            Container(width: 1, color: AppPalette.hairline(brightness)),
                            Expanded(
                              child: _LanguageSegment(
                                brightness: brightness,
                                label: 'AR',
                                isRight: true,
                                selected: settings.language == AppLanguagePreference.ar,
                                onTap: () => controller.updateLanguage(AppLanguagePreference.ar),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<TimeOfDay?> _showWheelTimePicker(
    BuildContext context,
    Brightness brightness,
    TimeOfDay initial,
    AppStrings strings,
  ) {
    return showWheelTimePicker(context, brightness, initial, strings: strings);
  }

  // Secure admin password handling - replaced by AdminAuthService (see lib/core/services/admin_auth_service.dart)
  // Uses env var ADMIN_PASSWORD_HASH + Firebase Auth + rate limiting, no plain text

  void _showAdminPasswordDialog(BuildContext context, Brightness brightness, AppStrings strings) {
    final passwordController = TextEditingController();
    var obscure = true;
    var errorText = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppPalette.card(brightness),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.chipViolet(brightness).background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.storage_rounded, color: AppPalette.chipViolet(brightness).foreground, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.adminAccessTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.adminAccessDesc,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppPalette.textPrimary(brightness)),
                decoration: InputDecoration(
                  hintText: strings.adminPasswordHint,
                  hintStyle: TextStyle(color: AppPalette.textSecondary(brightness)),
                  prefixIcon: Icon(Icons.lock_rounded, color: AppPalette.textSecondary(brightness)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppPalette.textSecondary(brightness)),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                  filled: true,
                  fillColor: AppPalette.tabContainer(brightness),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: errorText.isNotEmpty ? Colors.red : AppPalette.hairline(brightness)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: errorText.isNotEmpty ? Colors.red : AppPalette.hairline(brightness)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: errorText.isNotEmpty ? Colors.red : AppPalette.brandGreen, width: 1.5),
                  ),
                  errorText: errorText.isEmpty ? null : errorText,
                ),
                onSubmitted: (_) => _attemptAdminLogin(ctx, context, passwordController.text, brightness, strings, (err) => setState(() => errorText = err)),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppGlyph.shield, color: AppPalette.textSecondary(brightness), size: 14),
                const SizedBox(width: 4),
                Text(
                  strings.encrypted,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppPalette.textSecondary(brightness)),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(strings.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _attemptAdminLogin(ctx, context, passwordController.text, brightness, strings, (err) => setState(() => errorText = err)),
                  child: Text(strings.adminLogin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attemptAdminLogin(BuildContext dialogCtx, BuildContext context, String input, Brightness brightness, AppStrings strings, ValueChanged<String> onError) async {
    // Use secure AdminAuthService with rate limiting and env hash
    final result = await AdminAuthService.instance.verifyPassword(input.trim());
    if (!result.isSuccess) {
      onError(_adminFailureMessage(result, strings));
      return;
    }
    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
    final uri = Uri.parse('https://daily-meal000.web.app/#/admin');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        AppToast.showError(context, strings.adminOpenFailed);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, strings.errorGeneric(e));
      }
    }
  }

  /// Maps the locale-free failure code from [AdminAuthService] onto user copy.
  String _adminFailureMessage(AdminAuthResult result, AppStrings strings) {
    switch (result.failure) {
      case AdminAuthFailure.emptyPassword:
        return strings.adminPasswordEmpty;
      case AdminAuthFailure.lockedOut:
        return strings.adminLockedOut(result.lockoutMinutes);
      case AdminAuthFailure.notConfigured:
        return strings.adminNotConfigured;
      case AdminAuthFailure.wrongPassword:
        return strings.adminAttemptsLeft(result.remainingAttempts);
      case null:
        return strings.adminPasswordWrong;
    }
  }

  Widget _buildAdminSection(
    BuildContext context,
    Brightness brightness,
    AppStrings strings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: strings.admin),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              _linkRow(
                context,
                brightness,
                Icons.storage_rounded,
                AppPalette.chipViolet(brightness),
                strings.adminDashboardTitle,
                () => _showAdminPasswordDialog(context, brightness, strings),
              ),
              _divider(brightness),
              _linkRow(
                context,
                brightness,
                AppGlyph.shield,
                AppPalette.chipRose(brightness),
                strings.privacyPolicyTitle,
                () => showDialog(
                  context: context,
                  builder: (_) => const widgets.LegalPoliciesDialog(isPrivacy: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared bits
  // ---------------------------------------------------------------------------

  String _formatTime(AppSettingsData s, AppStrings strings) {
    final hour12 = s.notificationHour > 12
        ? s.notificationHour - 12
        : (s.notificationHour == 0 ? 12 : s.notificationHour);
    final minute = s.notificationMinute.toString().padLeft(2, '0');
    final period = s.notificationHour >= 12 ? strings.pm : strings.am;
    return '$hour12:$minute $period';
  }

  Widget _divider(Brightness brightness) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppPalette.hairline(brightness),
    );
  }

  Widget _iconCircle(Brightness brightness, dynamic glyphOrIcon, ChipStyle style) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
      child: Center(
        child: glyphOrIcon is IconData
            ? Icon(glyphOrIcon, color: style.foreground, size: 22)
            : AppIcon(glyphOrIcon as AppGlyph, color: style.foreground, size: 20),
      ),
    );
  }

  Widget _emojiCircle(Brightness brightness, String emoji, ChipStyle style) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }

  Widget _stepButton(Brightness brightness, AppGlyph glyph, VoidCallback onTap) {
    return Material(
      color: AppPalette.tabContainer(brightness),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: AppIcon(glyph, color: AppPalette.textPrimary(brightness), size: 16),
          ),
        ),
      ),
    );
  }

  Widget _linkRow(
    BuildContext context,
    Brightness brightness,
    dynamic glyphOrIcon,
    ChipStyle style,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _iconCircle(brightness, glyphOrIcon, style),
            const SizedBox(width: 14),
            Expanded(
              child: subtitle != null && subtitle.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ),
                      ],
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textPrimary(brightness),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            AppIcon(
              AppGlyph.chevron,
              color: AppPalette.textSecondary(brightness),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  final String? avatarPath;
  final double size;
  final Brightness brightness;

  const _AvatarWidget({
    required this.avatarPath,
    required this.size,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3C64F),
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.hairline(brightness), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (avatarPath == null || avatarPath!.isEmpty) {
      return _fallback();
    }

    // If path is from local file system (downloaded avatars), use Image.file
    if (!avatarPath!.startsWith('assets/')) {
      final file = File(avatarPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (ctx, err, st) {
          debugPrint('Avatar file load error for $avatarPath: $err - falling back to asset');
          // Try to load as asset if file fails
          return Image.asset(
            avatarPath!.contains('assets/') ? avatarPath! : 'assets/avatars/MO1.png',
            fit: BoxFit.cover,
            width: size,
            height: size,
            cacheWidth: (size * 2).toInt(),
            errorBuilder: (_, __, ___) => _fallback(),
          );
        },
      );
    }

    // Bundled asset path
    return Image.asset(
      avatarPath!,
      fit: BoxFit.cover,
      width: size,
      height: size,
      cacheWidth: (size * 2).toInt(),
      errorBuilder: (ctx, err, st) {
        debugPrint('Avatar asset load error for $avatarPath: $err');
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFF3C64F),
      child: Center(
        child: AppIcon(AppGlyph.person, color: Colors.white, size: size * 0.47),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final Brightness brightness;
  final String title;
  final String? link;
  final Color? linkColor;
  final VoidCallback? onLink;
  final Key? linkKey;

  const _SectionHeader({
    super.key,
    required this.brightness,
    required this.title,
    this.link,
    this.linkColor,
    this.onLink,
    this.linkKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
        ),
        if (link != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: GestureDetector(
                key: linkKey,
                onTap: onLink,
                child: Text(
                  link!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: linkColor ?? AppPalette.brandGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Brightness brightness;
  final Widget child;

  const _Card({required this.brightness, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LanguageSegment extends StatelessWidget {
  final Brightness brightness;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLeft;
  final bool isRight;

  const _LanguageSegment({
    required this.brightness,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isLeft = false,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(20) : Radius.zero,
            right: isRight ? const Radius.circular(20) : Radius.zero,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.brandGreen.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: selected ? Colors.white : AppPalette.textSecondary(brightness),
            ),
          ),
        ),
      ),
    );
  }
}

class _CooldownSliderItem extends StatefulWidget {
  final int initialDays;
  final Brightness brightness;
  final AppStrings strings;
  final ValueChanged<int> onChangeEnd;

  const _CooldownSliderItem({
    required this.initialDays,
    required this.brightness,
    required this.strings,
    required this.onChangeEnd,
  });

  @override
  State<_CooldownSliderItem> createState() => _CooldownSliderItemState();
}

class _CooldownSliderItemState extends State<_CooldownSliderItem> {
  late double _currentValue;
  bool _isDragging = false;
  int _lastTickValue = -1;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialDays.toDouble().clamp(1, 30);
    _lastTickValue = _currentValue.round();
  }

  @override
  void didUpdateWidget(covariant _CooldownSliderItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _currentValue = widget.initialDays.toDouble().clamp(1, 30);
      _lastTickValue = _currentValue.round();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppPalette.chipGreen(widget.brightness).background,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  AppGlyph.clock,
                  color: AppPalette.chipGreen(widget.brightness).foreground,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.strings.delayMealRepeat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(widget.brightness),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.chipGreen(widget.brightness).background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.strings.daysText(_currentValue.round()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.chipGreen(widget.brightness).foreground,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _currentValue,
          min: 1,
          max: 30,
          divisions: 29,
          onChangeStart: (v) {
            _isDragging = true;
          },
          onChanged: (v) {
            final newInt = v.round();
            if (newInt != _lastTickValue) {
              _lastTickValue = newInt;
              if (defaultTargetPlatform == TargetPlatform.iOS) {
                SystemSound.play(SystemSoundType.tick);
              } else {
                SystemSound.play(SystemSoundType.click);
              }
              HapticFeedback.selectionClick();
            }
            setState(() {
              _currentValue = v;
            });
          },
          onChangeEnd: (v) {
            _isDragging = false;
            widget.onChangeEnd(v.round());
          },
        ),
      ],
    );
  }
}



