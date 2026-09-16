import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/presentation/widgets/emphasis_marks.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/avatar_service.dart';
import '../../../core/services/admin_auth_service.dart';
import '../providers/settings_providers.dart';
import 'widgets/legal_policies_dialog.dart' as widgets;
import 'widgets/time_wheel_picker.dart';

/// Settings screen rebuilt from the approved mockups (light + dark):
/// header with shine marks, profile card, then titled sections whose cards
/// float on the page background. "more" expands the per-protein cooldown
/// enable/disable switches (a protein at 0 days = cooldown off).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _expanded = false;
  // حفظ القيم السابقة للمستخدم عند إيقاف السويتش حتى لا تضيع
  final Map<String, int> _previousDays = {};

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildHeader(brightness, strings),
                const SizedBox(height: 20),
                IgnorePointer(
                  ignoring: _expanded,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _expanded ? 0.38 : 1.0,
                    child: _buildProfileCard(context, ref, settings, brightness, strings),
                  ),
                ),
                const SizedBox(height: 24),
                _buildCooldownSection(context, ref, settings, brightness, strings),
                const SizedBox(height: 24),
                IgnorePointer(
                  ignoring: _expanded,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _expanded ? 0.38 : 1.0,
                    child: _buildDietaryRulesSection(context, ref, settings, brightness, strings),
                  ),
                ),
                const SizedBox(height: 24),
                IgnorePointer(
                  ignoring: _expanded,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _expanded ? 0.38 : 1.0,
                    child: _buildNotificationsSection(context, ref, settings, brightness, strings),
                  ),
                ),
                const SizedBox(height: 24),
                IgnorePointer(
                  ignoring: _expanded,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _expanded ? 0.38 : 1.0,
                    child: _buildAppearanceSection(context, ref, settings, brightness, strings),
                  ),
                ),
                const SizedBox(height: 24),
                IgnorePointer(
                  ignoring: _expanded,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _expanded ? 0.38 : 1.0,
                    child: _buildAdminSection(context, brightness, strings),
                  ),
                ),
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
            const EmphasisMarks(size: 20),
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
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showProfileEditDialog(context, ref, settings, strings),
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
                      settings.userName ?? 'Mohamed Sukar',
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
                      settings.userEmail ?? 'mohamed@example.com',
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
          brightness: brightness,
          title: strings.smartCooldownEngine,
          link: _expanded ? strings.cancel : strings.more,
          linkColor: _expanded ? AppPalette.heartCoral : const Color(0xFF3E63DD),
          onLink: () => setState(() => _expanded = !_expanded),
        ),
        const SizedBox(height: 12),
        if (!_expanded)
          _Card(
            brightness: brightness,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _iconCircle(brightness, AppGlyph.clock, AppPalette.chipGreen(brightness)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                strings.delayMealRepeat,
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
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppPalette.chipGreen(brightness).background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              strings.daysText(settings.cooldownDays),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.chipGreen(brightness).foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.cooldownDays.toDouble().clamp(1, 30),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        onChanged: (v) => controller.updateCooldownDays(v.round()),
                      ),
                    ],
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
              ],
            ),
          )
        else
          _Card(
            brightness: brightness,
            child: Column(
              children: [
                _proteinSwitch(
                  ref, brightness, strings, '🐔', AppPalette.chipGold(brightness), strings.chicken,
                  settings.chickenCooldownDays, 7, controller.updateChickenCooldownDays,
                ),
                _divider(brightness),
                _proteinSwitch(
                  ref, brightness, strings, '🥩', AppPalette.chipRose(brightness), strings.beef,
                  settings.beefCooldownDays, 10, controller.updateBeefCooldownDays,
                ),
                _divider(brightness),
                _proteinSwitch(
                  ref, brightness, strings, '🐟', AppPalette.chipBlue(brightness), strings.fish,
                  settings.fishCooldownDays, 5, controller.updateFishCooldownDays,
                ),
                _divider(brightness),
                _proteinSwitch(
                  ref, brightness, strings, '🌿', AppPalette.chipGreen(brightness), strings.veggies,
                  settings.meatlessCooldownDays, 3,
                  (d) => ref.read(appSettingsDaoProvider).updateMeatlessCooldownDays(d),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stepperRow(
    BuildContext context,
    WidgetRef ref,
    Brightness brightness,
    AppStrings strings, {
    required String emoji,
    required ChipStyle style,
    required String name,
    required int days,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
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

  Widget _proteinSwitch(
    WidgetRef ref,
    Brightness brightness,
    AppStrings strings,
    String emoji,
    ChipStyle style,
    String name,
    int days,
    int defaultDays,
    ValueChanged<int> onChanged,
  ) {
    final key = name; // استخدام الاسم كمفتاح مؤقت للحفظ
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _emojiCircle(brightness, emoji, style),
          const SizedBox(width: 14),
          Expanded(
            child: FittedBox(
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
          ),
          const Spacer(),
          Switch(
            value: days > 0,
            onChanged: (on) {
              if (on) {
                // استرجاع القيمة المحفوظة للمستخدم أو الافتراضي
                final restored = _previousDays[key] ?? defaultDays;
                onChanged(restored);
              } else {
                // حفظ القيمة الحالية قبل الإيقاف
                if (days > 0) {
                  _previousDays[key] = days;
                }
                onChanged(0);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryRulesSection(
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
        _SectionHeader(brightness: brightness, title: 'قواعد التنوع الغذائي'),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    _iconCircle(brightness, AppGlyph.steak, AppPalette.chipRose(brightness)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.preventProteinRepeat,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          Text(
                            strings.preventProteinRepeatDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: settings.preventRepeatProtein,
                      onChanged: (v) => controller.updateDietaryRules(preventProtein: v),
                    ),
                  ],
                ),
              ),
              _divider(brightness),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    _iconCircle(brightness, AppGlyph.pot, AppPalette.chipGold(brightness)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.preventCarbRepeat,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          Text(
                            strings.preventCarbRepeatDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: settings.preventRepeatCarbs,
                      onChanged: (v) => controller.updateDietaryRules(preventCarbs: v),
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
                    _iconCircle(brightness, AppGlyph.bell, AppPalette.chipGold(brightness)),
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
                        _iconCircle(brightness, AppGlyph.clock, AppPalette.chipViolet(brightness)),
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
                                  _formatTime(settings),
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
                    _iconCircle(brightness, AppGlyph.moon, AppPalette.chipViolet(brightness)),
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
  ) {
    return showWheelTimePicker(context, brightness, initial);
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
                  child: AppIcon(AppGlyph.shield, color: AppPalette.chipViolet(brightness).foreground, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Admin Access',
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
                'أدخل كلمة مرور المسؤول للوصول إلى لوحة التحكم',
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
                  hintText: 'كلمة المرور',
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
              const SizedBox(height: 8),
              Row(
                children: [
                  AppIcon(AppGlyph.shield, color: AppPalette.textSecondary(brightness), size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'محمية بتشفير آمن - لا يتم تخزين كلمة المرور كنص واضح',
                      style: TextStyle(fontSize: 10, color: AppPalette.textSecondary(brightness)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.brandGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _attemptAdminLogin(ctx, context, passwordController.text, brightness, strings, (err) => setState(() => errorText = err)),
              child: Text(strings.save == 'Save' ? 'دخول' : 'دخول', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
      onError(result.errorMessage ?? 'كلمة المرور غير صحيحة');
      return;
    }
    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
    final uri = Uri.parse('https://daily-meal000.web.app/#/admin');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        AppToast.showError(context, 'تعذر فتح صفحة الإدارة');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, 'خطأ: $e');
      }
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
        _SectionHeader(brightness: brightness, title: strings.privacyPolicy),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              _linkRow(
                context,
                brightness,
                AppGlyph.shield,
                AppPalette.chipViolet(brightness),
                'Admin database',
                'لوحة تحكم المسؤول - محمية بكلمة مرور',
                () => _showAdminPasswordDialog(context, brightness, strings),
              ),
              _divider(brightness),
              _linkRow(
                context,
                brightness,
                AppGlyph.bookmark,
                AppPalette.chipRose(brightness),
                strings.legalPolicies,
                strings.privacyPolicy,
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

  void _showProfileEditDialog(BuildContext context, WidgetRef ref, AppSettingsData settings, AppStrings strings) {
    final nameController = TextEditingController(text: settings.userName ?? '');
    final emailController = TextEditingController(text: settings.userEmail ?? '');
    String? selectedAvatar = settings.userAvatar;
    final avatars = [
      'assets/avatars/MO1.png', 'assets/avatars/MO2.png', 'assets/avatars/MO3.png', 'assets/avatars/MO4.png', 'assets/avatars/MO5.png',
      'assets/avatars/MY1.png', 'assets/avatars/MY2.png', 'assets/avatars/MY3.png', 'assets/avatars/MY4.png', 'assets/avatars/MY5.png',
      'assets/avatars/F01.png', 'assets/avatars/F02.png', 'assets/avatars/F03.png', 'assets/avatars/F04.png', 'assets/avatars/F05.png',
      'assets/avatars/FY1.png', 'assets/avatars/FY2.png', 'assets/avatars/FY3.png', 'assets/avatars/FY4.png', 'assets/avatars/FY5.png',
    ];
    // Trigger avatar download when internet available - small size, improves performance
    // This ensures avatars are in file system for faster loading and future remote updates
    Future.microtask(() async {
      try {
        await AvatarService.instance.downloadAvatarsIfNeeded();
      } catch (e) {
        debugPrint('Avatar download on dialog open failed: $e');
      }
    });
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(strings.editProfile),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: strings.nameField, prefixIcon: const Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: strings.emailField, prefixIcon: const Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                Text(strings.chooseAvatar, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(avatars.length, (i) {
                    final isSelected = selectedAvatar == avatars[i];
                    return GestureDetector(
                      onTap: () => setState(() => selectedAvatar = avatars[i]),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppPalette.tabContainer(Theme.of(context).brightness),
                          border: Border.all(
                            color: isSelected ? AppPalette.brandGreen : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppPalette.brandGreen.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset(
                            avatars[i],
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            cacheWidth: 112,
                            errorBuilder: (ctx, err, st) {
                              debugPrint('Avatar grid load error ${avatars[i]}: $err');
                              return Container(
                                color: const Color(0xFFF3C64F),
                                child: Center(
                                  child: AppIcon(AppGlyph.person, color: Colors.white, size: 24),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strings.cancel)),
            FilledButton(
              onPressed: () async {
                final dao = ref.read(appSettingsDaoProvider);
                await dao.updateWelcomeData(
                  userName: nameController.text.trim().isEmpty ? 'Mohamed Sukar' : nameController.text.trim(),
                  userEmail: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  userGender: settings.userGender,
                  userAvatar: selectedAvatar,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  AppToast.showSuccess(context, strings.profileSaved);
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared bits
  // ---------------------------------------------------------------------------

  String _formatTime(AppSettingsData s) {
    final hour12 = s.notificationHour > 12
        ? s.notificationHour - 12
        : (s.notificationHour == 0 ? 12 : s.notificationHour);
    final minute = s.notificationMinute.toString().padLeft(2, '0');
    final period = s.notificationHour >= 12 ? 'م' : 'ص';
    return '$hour12:$minute $period';
  }

  Widget _divider(Brightness brightness) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppPalette.hairline(brightness),
    );
  }

  Widget _iconCircle(Brightness brightness, AppGlyph glyph, ChipStyle style) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
      child: Center(child: AppIcon(glyph, color: style.foreground, size: 20)),
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
    AppGlyph glyph,
    ChipStyle style,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _iconCircle(brightness, glyph, style),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

  const _SectionHeader({
    required this.brightness,
    required this.title,
    this.link,
    this.linkColor,
    this.onLink,
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


