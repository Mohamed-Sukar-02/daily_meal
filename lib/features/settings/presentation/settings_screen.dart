import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/app_database.dart';
import '../providers/settings_providers.dart';
import 'widgets/legal_policies_dialog.dart' as widgets;

// ---------- الألوان المستخدمة في التصميم ----------
class AppColors {
  static const background = Color(0xFF0E1220);
  static const card = Color(0xFF161B2E);
  static const cardBorder = Color(0xFF232A44);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF8A93B2);
  static const green = Color(0xFF17C97B);
  static const purple = Color(0xFF5B4FE9);
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {


  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: settingsAsync.when(
          data: (settings) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildProfileCard(),
                const SizedBox(height: 20),
                _buildSmartCooldownCard(context, ref, settings),
                const SizedBox(height: 20),
                _buildNotificationsCard(context, ref, settings),
                const SizedBox(height: 20),
                _buildAppearanceCard(context, ref, settings),
                const SizedBox(height: 20),
                _buildExtraCard(context, ref, settings),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  // ---------- الهيدر ----------
  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Make your meals work better for you',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- كارت البروفايل ----------
  Widget _buildProfileCard() {
    return _cardContainer(
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.amber,
                child: Icon(Icons.face, size: 32, color: Colors.brown),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.purple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mohamed Sukar',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'mohamed@example.com',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  // ---------- كارت Smart Cooldown Engine ----------
  Widget _buildSmartCooldownCard(BuildContext context, WidgetRef ref, AppSetting settings) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.ac_unit,
            iconBg: AppColors.purple,
            title: 'Smart Cooldown Engine',
            subtitle: "Adjust how often you'll see the same meals",
          ),
          const Divider(color: AppColors.cardBorder, height: 28),
          Row(
            children: [
              _iconCircle(Icons.access_time, AppColors.green),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meal Repeat Delay',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text('Wait time before showing the same meal again',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${settings.cooldownDays} days',
                  style: const TextStyle(
                      color: AppColors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.green,
              inactiveTrackColor: AppColors.cardBorder,
              thumbColor: AppColors.green,
              overlayColor: AppColors.green.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: settings.cooldownDays.toDouble(),
              min: 1,
              max: 30,
              onChanged: (v) {
                ref.read(settingsControllerProvider.notifier).updateCooldownDays(v.toInt());
              },
            ),
          ),
          const Divider(color: AppColors.cardBorder, height: 10),
          _stepperRow('🐔', 'Chicken', 'Days to wait', settings.chickenCooldownDays,
              onMinus: () {
                if (settings.chickenCooldownDays > 1) {
                  ref.read(settingsControllerProvider.notifier).updateChickenCooldownDays(settings.chickenCooldownDays - 1);
                }
              },
              onPlus: () {
                ref.read(settingsControllerProvider.notifier).updateChickenCooldownDays(settings.chickenCooldownDays + 1);
              },
              iconBg: Colors.amber),
          const Divider(color: AppColors.cardBorder, height: 24),
          _stepperRow('🥩', 'Beef', 'Days to wait', settings.beefCooldownDays,
              onMinus: () {
                if (settings.beefCooldownDays > 1) {
                  ref.read(settingsControllerProvider.notifier).updateBeefCooldownDays(settings.beefCooldownDays - 1);
                }
              },
              onPlus: () {
                ref.read(settingsControllerProvider.notifier).updateBeefCooldownDays(settings.beefCooldownDays + 1);
              },
              iconBg: Colors.redAccent),
          const Divider(color: AppColors.cardBorder, height: 24),
          _stepperRow('🐟', 'Fish', 'Days to wait', settings.fishCooldownDays,
              onMinus: () {
                if (settings.fishCooldownDays > 1) {
                  ref.read(settingsControllerProvider.notifier).updateFishCooldownDays(settings.fishCooldownDays - 1);
                }
              },
              onPlus: () {
                ref.read(settingsControllerProvider.notifier).updateFishCooldownDays(settings.fishCooldownDays + 1);
              },
              iconBg: Colors.blueAccent),
        ],
      ),
    );
  }

  // ---------- كارت Notifications ----------
  Widget _buildNotificationsCard(BuildContext context, WidgetRef ref, AppSetting settings) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.notifications,
            iconBg: Colors.orange,
            title: 'Notifications',
            subtitle: 'Stay on track with your meal plan',
          ),
          const Divider(color: AppColors.cardBorder, height: 28),
          Row(
            children: [
              _iconCircle(Icons.wb_sunny, AppColors.green),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Reminder',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text('Get notified at your preferred time',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: settings.notificationsEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.green,
                onChanged: (v) {
                  ref.read(settingsControllerProvider.notifier).toggleNotifications(v);
                },
              ),
            ],
          ),
          if (settings.notificationsEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _iconCircle(Icons.access_time_filled, AppColors.purple),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reminder Time',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      Text('When do you want to be reminded?',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.notificationHour,
                        minute: settings.notificationMinute,
                      ),
                    );
                    if (picked != null) {
                      ref.read(settingsControllerProvider.notifier).updateNotificationTime(picked.hour, picked.minute);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          '${settings.notificationHour > 12 ? settings.notificationHour - 12 : settings.notificationHour == 0 ? 12 : settings.notificationHour}:${settings.notificationMinute.toString().padLeft(2, '0')} ${settings.notificationHour >= 12 ? 'PM' : 'AM'}',
                          style: const TextStyle(color: Colors.white)
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------- كارت Appearance & Backup ----------
  Widget _buildAppearanceCard(BuildContext context, WidgetRef ref, AppSetting settings) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.settings,
            iconBg: Colors.blue,
            title: 'Appearance & Backup',
            subtitle: 'Customize your app experience',
          ),
          const Divider(color: AppColors.cardBorder, height: 28),
          Row(
            children: [
              _iconCircle(Icons.nightlight_round, AppColors.purple),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dark Mode',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text('Switch between light and dark themes',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: settings.themeMode == AppThemeModePreference.dark,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.green,
                onChanged: (v) {
                  ref.read(settingsControllerProvider.notifier).updateThemeMode(
                        v ? AppThemeModePreference.dark : AppThemeModePreference.light,
                      );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              // Option for data backup
            },
            child: Row(
              children: [
                _iconCircle(Icons.cloud, AppColors.green),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data Backup',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      Text('Keep your data safe and synced',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showAdminPasswordDialog(context),
            child: Row(
              children: [
                _iconCircle(Icons.security, Colors.orangeAccent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Database',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      Text('Access cloud database (Admin only)',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- كارت Language & Legal (Extra) ----------
  Widget _buildExtraCard(BuildContext context, WidgetRef ref, AppSetting settings) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.language,
            iconBg: Colors.teal,
            title: 'Language & More',
            subtitle: 'Language preferences and legal policies',
          ),
          const Divider(color: AppColors.cardBorder, height: 28),
          Row(
            children: [
              _iconCircle(Icons.translate, Colors.teal),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Language',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text('App language (Ar / En)',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              SegmentedButton<AppLanguagePreference>(
                segments: const [
                  ButtonSegment(
                    value: AppLanguagePreference.ar,
                    label: Text('عربي'),
                  ),
                  ButtonSegment(
                    value: AppLanguagePreference.en,
                    label: Text('En'),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (selected) {
                  if (selected.isNotEmpty) {
                    ref.read(settingsControllerProvider.notifier).updateLanguage(selected.first);
                  }
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.cardBorder,
                  foregroundColor: Colors.white,
                  selectedForegroundColor: AppColors.background,
                  selectedBackgroundColor: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const widgets.LegalPoliciesDialog(isPrivacy: true),
              );
            },
            child: Row(
              children: [
                _iconCircle(Icons.privacy_tip, Colors.blueGrey),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Privacy Policy',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      Text('Read our privacy policies',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('تسجيل دخول المسئول', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'كلمة المرور',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(Icons.lock, color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cardBorder)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () {
              if (passwordController.text == '747474') {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('https://daily-meal000.web.app/#/admin'));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('كلمة المرور غير صحيحة')),
                );
              }
            },
            child: const Text('دخول', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ---------- Widgets مساعدة قابلة لإعادة الاستخدام ----------
  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        _iconCircle(icon, iconBg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconCircle(IconData icon, Color bg) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Icon(icon, color: bg, size: 20),
    );
  }

  Widget _stepperRow(
    String emoji,
    String title,
    String subtitle,
    int value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required Color iconBg,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.2), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        _circleButton(Icons.remove, onMinus),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ),
        _circleButton(Icons.add, onPlus),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.cardBorder,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white70),
      ),
    );
  }
}
