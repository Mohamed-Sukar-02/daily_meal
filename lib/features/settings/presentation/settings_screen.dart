import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../home/presentation/widgets/home_header.dart' show EmphasisMarks;
import '../../../core/localization/app_strings.dart';
import '../providers/settings_providers.dart';
import 'widgets/legal_policies_dialog.dart' as widgets;

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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      body: SafeArea(
        bottom: false,
        child: settingsAsync.when(
          data: (settings) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildHeader(brightness),
              const SizedBox(height: 20),
              IgnorePointer(
                ignoring: _expanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _expanded ? 0.38 : 1.0,
                  child: _buildProfileCard(context, ref, settings, brightness),
                ),
              ),
              const SizedBox(height: 24),
              // Cooldown is the active section — whole card transforms to switches
              _buildCooldownSection(context, ref, settings, brightness),
              const SizedBox(height: 24),
              IgnorePointer(
                ignoring: _expanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _expanded ? 0.38 : 1.0,
                  child: _buildNotificationsSection(context, ref, settings, brightness),
                ),
              ),
              const SizedBox(height: 24),
              IgnorePointer(
                ignoring: _expanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _expanded ? 0.38 : 1.0,
                  child: _buildAppearanceSection(context, ref, settings, brightness),
                ),
              ),
              const SizedBox(height: 24),
              IgnorePointer(
                ignoring: _expanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _expanded ? 0.38 : 1.0,
                  child: _buildAdminSection(context, brightness),
                ),
              ),
            ],
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppPalette.brandGreen),
          ),
          error: (err, _) => Center(
            child: Text(
              'حدث خطأ: $err',
              style: TextStyle(color: AppPalette.textSecondary(brightness)),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header + profile
  // ---------------------------------------------------------------------------

  Widget _buildHeader(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'الإعدادات',
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
          'خلّي أكلاتك تشتغل لمصلحتك',
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
  ) {
    return _Card(
      brightness: brightness,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showProfileEditDialog(context, ref, settings),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3C64F),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: settings.userAvatar != null && settings.userAvatar!.isNotEmpty
                        ? Image.asset(settings.userAvatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: AppIcon(AppGlyph.person, color: Colors.white, size: 34)))
                        : const Center(
                            child: AppIcon(AppGlyph.person, color: Colors.white, size: 34),
                          ),
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
              const SizedBox(width: 14),
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
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          brightness: brightness,
          title: 'محرك الكولداون الذكي',
          link: _expanded ? 'إلغاء' : 'المزيد',
          linkColor: _expanded ? AppPalette.heartCoral : const Color(0xFF3E63DD),
          onLink: () => setState(() => _expanded = !_expanded),
        ),
        const SizedBox(height: 12),
        // Whole cooldown block transforms: closed = slider + steppers for ENABLED proteins,
        // open = 4 switches (Smart Cooldown Engine) — switches control visibility in main view.
        if (!_expanded)
          _Card(
            brightness: brightness,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _iconCircle(brightness, AppGlyph.clock, AppPalette.chipGreen(brightness)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'تأخير تكرار الأكلة',
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
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppPalette.chipGreen(brightness).background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${settings.cooldownDays} يوم',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppPalette.chipGreen(brightness).foreground,
                                  ),
                                ),
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
                // Stepper rows only for enabled proteins (switch ON = days > 0) — original 3 rows
                if (settings.chickenCooldownDays > 0) ...[
                  _divider(brightness),
                  _stepperRow(
                    context,
                    ref,
                    brightness,
                    emoji: '🐔',
                    style: AppPalette.chipGold(brightness),
                    name: 'فراخ',
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
                    emoji: '🥩',
                    style: AppPalette.chipRose(brightness),
                    name: 'لحمة',
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
                    emoji: '🐟',
                    style: AppPalette.chipBlue(brightness),
                    name: 'سمك',
                    days: settings.fishCooldownDays,
                    onChanged: (d) => controller.updateFishCooldownDays(d),
                  ),
                ],
              ],
            ),
          )
        else
          // Smart Cooldown Engine — 4 switches that control main-view visibility, per mock
          _Card(
            brightness: brightness,
            child: Column(
              children: [
                _proteinSwitch(
                  ref, brightness, '🐔', AppPalette.chipGold(brightness), 'فراخ',
                  settings.chickenCooldownDays, 7, controller.updateChickenCooldownDays,
                ),
                _divider(brightness),
                _proteinSwitch(
                  ref, brightness, '🥩', AppPalette.chipRose(brightness), 'لحمة',
                  settings.beefCooldownDays, 10, controller.updateBeefCooldownDays,
                ),
                _divider(brightness),
                _proteinSwitch(
                  ref, brightness, '🐟', AppPalette.chipBlue(brightness), 'سمك',
                  settings.fishCooldownDays, 5, controller.updateFishCooldownDays,
                ),
                _divider(brightness),
                _proteinSwitch(
                  ref, brightness, '🌿', AppPalette.chipGreen(brightness), 'خضار',
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
    Brightness brightness, {
    required String emoji,
    required ChipStyle style,
    required String name,
    required int days,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          _emojiCircle(brightness, emoji, style),
          const SizedBox(width: 12),
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
                    'أيام انتظار',
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
          Flexible(
            child: Wrap(
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
          ),
        ],
      ),
    );
  }

  Widget _proteinSwitch(
    WidgetRef ref,
    Brightness brightness,
    String emoji,
    ChipStyle style,
    String name,
    int days,
    int defaultDays,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          _emojiCircle(brightness, emoji, style),
          const SizedBox(width: 12),
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
          Switch(
            value: days > 0,
            onChanged: (on) => onChanged(on ? defaultDays : 0),
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
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: 'التنبيهات'),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    _iconCircle(brightness, AppGlyph.bell, AppPalette.chipGold(brightness)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'تذكير يومي',
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
                              'هيصلك إشعار في الوقت اللي تختاره',
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
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        _iconCircle(brightness, AppGlyph.clock, AppPalette.chipViolet(brightness)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'موعد التذكير',
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
                                  'امتى تحب نذكّرك؟',
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
                        Flexible(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
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
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatTime(settings),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppPalette.chipViolet(brightness).foreground,
                                        ),
                                      ),
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
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    String themeLabel(AppThemeModePreference m) {
      switch (m) {
        case AppThemeModePreference.dark:
          return 'داكن';
        case AppThemeModePreference.light:
          return 'فاتح';
        case AppThemeModePreference.system:
          return 'حسب الجهاز';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: 'المظهر واللغة'),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    _iconCircle(brightness, AppGlyph.moon, AppPalette.chipViolet(brightness)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المظهر',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          Text(
                            'اختر مظهر التطبيق',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
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
                          items: const [
                            DropdownMenuItem(value: AppThemeModePreference.system, child: Text('حسب الجهاز')),
                            DropdownMenuItem(value: AppThemeModePreference.light, child: Text('فاتح')),
                            DropdownMenuItem(value: AppThemeModePreference.dark, child: Text('داكن')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _divider(brightness),
              _linkRow(
                context,
                brightness,
                AppGlyph.globe,
                AppPalette.chipBlue(brightness),
                'اللغة',
                settings.language == AppLanguagePreference.ar ? 'العربية' : 'English',
                () => _pickLanguage(context, ref, settings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminSection(
    BuildContext context,
    Brightness brightness,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: 'الإدارة'),
        const SizedBox(height: 12),
        _Card(
          brightness: brightness,
          child: Column(
            children: [
              _linkRow(
                context,
                brightness,
                AppGlyph.cloud,
                AppPalette.chipGreen(brightness),
                'إدارة قاعدة البيانات',
                'عرض وإدارة البيانات المحلية',
                () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('إدارة قاعدة البيانات قريباً!')),
                ),
              ),
              _divider(brightness),
              _linkRow(
                context,
                brightness,
                AppGlyph.bookmark,
                AppPalette.chipRose(brightness),
                'السياسات القانونية',
                'الخصوصية والشروط',
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

  void _showProfileEditDialog(BuildContext context, WidgetRef ref, AppSettingsData settings) {
    final nameController = TextEditingController(text: settings.userName ?? '');
    final emailController = TextEditingController(text: settings.userEmail ?? '');
    String? selectedAvatar = settings.userAvatar;
    // List of available avatars
    final avatars = [
      'assets/avatars/MO1.png', 'assets/avatars/MO2.png', 'assets/avatars/MO3.png', 'assets/avatars/MO4.png', 'assets/avatars/MO5.png',
      'assets/avatars/MY1.png', 'assets/avatars/MY2.png', 'assets/avatars/MY3.png', 'assets/avatars/MY4.png', 'assets/avatars/MY5.png',
      'assets/avatars/F01.png', 'assets/avatars/F02.png', 'assets/avatars/F03.png', 'assets/avatars/F04.png', 'assets/avatars/F05.png',
      'assets/avatars/FY1.png', 'assets/avatars/FY2.png', 'assets/avatars/FY3.png', 'assets/avatars/FY4.png', 'assets/avatars/FY5.png',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تعديل الملف الشخصي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                const Text('اختر الصورة الرمزية', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: avatars.length,
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => setState(() => selectedAvatar = avatars[i]),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: selectedAvatar == avatars[i] ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset(avatars[i], fit: BoxFit.cover)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الملف الشخصي')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _pickLanguage(BuildContext context, WidgetRef ref, AppSettingsData settings) {
    final controller = ref.read(settingsControllerProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('اختر اللغة / Choose Language'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await controller.updateLanguage(AppLanguagePreference.ar);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير اللغة إلى العربية')));
              }
            },
            child: const Text('العربية 🇪🇬'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await controller.updateLanguage(AppLanguagePreference.en);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language changed to English')));
              }
            },
            child: const Text('English 🇺🇸'),
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            _iconCircle(brightness, glyph, style),
            const SizedBox(width: 12),
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
          const SizedBox(width: 8),
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
