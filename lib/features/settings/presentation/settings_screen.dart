import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../home/presentation/widgets/home_header.dart' show EmphasisMarks;
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
      body: SafeArea(
        bottom: false,
        child: settingsAsync.when(
          data: (settings) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildHeader(brightness),
              const SizedBox(height: 20),
              _buildProfileCard(context, ref, settings, brightness),
              const SizedBox(height: 24),
              _buildCooldownSection(context, ref, settings, brightness),
              const SizedBox(height: 24),
              _buildNotificationsSection(context, ref, settings, brightness),
              const SizedBox(height: 24),
              _buildAppearanceSection(context, ref, settings, brightness),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 30,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
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
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعديل الملف الشخصي قريباً!')),
        ),
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
                    child: const Center(
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
                          child: Text(
                            'تأخير تكرار الأكلة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.chipGreen(brightness).background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${settings.cooldownDays} يوم',
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
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
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
                  (d) => ref.read(databaseProvider).appSettingsDao.updateSettings(
                        AppSettingsCompanion(meatlessCooldownDays: Value(d)),
                      ),
                ),
              ],
            ),
          ),
        ],
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
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
                Text(
                  'أيام انتظار',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          _stepButton(brightness, AppGlyph.minus, () => onChanged((days - 1).clamp(0, 30))),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
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
          const SizedBox(width: 10),
          _stepButton(brightness, AppGlyph.plus, () => onChanged((days + 1).clamp(0, 30))),
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
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
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
                    _iconCircle(brightness, AppGlyph.sun, AppPalette.chipGreen(brightness)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تذكير يومي',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          Text(
                            'هيصلك إشعار في الوقت اللي تختاره',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    _iconCircle(brightness, AppGlyph.clock, AppPalette.chipViolet(brightness)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'موعد التذكير',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          Text(
                            'امتى تحب نذكّرك؟',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
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
    final isDarkMode = settings.themeMode == AppThemeModePreference.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(brightness: brightness, title: 'المظهر والنسخ الاحتياطي'),
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
                            'الوضع الداكن',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          Text(
                            'بدّل بين الوضع الفاتح والداكن',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isDarkMode,
                      onChanged: (v) => controller.updateThemeMode(
                        v ? AppThemeModePreference.dark : AppThemeModePreference.light,
                      ),
                    ),
                  ],
                ),
              ),
              _divider(brightness),
              _linkRow(
                context,
                brightness,
                AppGlyph.cloud,
                AppPalette.chipGreen(brightness),
                'نسخ البيانات',
                'حافظ على بياناتك آمنة ومتزامنة',
                () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('النسخ الاحتياطي السحابي قريباً!')),
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

  void _pickLanguage(BuildContext context, WidgetRef ref, AppSettingsData settings) {
    final controller = ref.read(settingsControllerProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('اللغة'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              controller.updateLanguage(AppLanguagePreference.ar);
              Navigator.pop(ctx);
            },
            child: const Text('العربية'),
          ),
          SimpleDialogOption(
            onPressed: () {
              controller.updateLanguage(AppLanguagePreference.en);
              Navigator.pop(ctx);
            },
            child: const Text('English'),
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
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
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
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppPalette.textPrimary(brightness),
            ),
          ),
        ),
        if (link != null)
          GestureDetector(
            onTap: onLink,
            child: Text(
              link!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: linkColor ?? AppPalette.brandGreen,
              ),
            ),
          ),
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
