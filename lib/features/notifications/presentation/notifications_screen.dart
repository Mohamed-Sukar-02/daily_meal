import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      appBar: AppBar(
        backgroundColor: AppPalette.background(brightness),
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppGlyph.chevron, color: AppPalette.textPrimary(brightness), size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          strings.notificationsTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary(brightness),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Header
            Row(
              children: [
                _iconCircle(brightness, AppGlyph.bell, AppPalette.chipGold(brightness)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.notificationsSubtitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.notificationsFollow,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.chipGreen(brightness).background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    strings.newBadge(3),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.chipGreen(brightness).foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Today section
            Text(
              strings.today,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              brightness: brightness,
              child: Column(
                children: [
                  _NotificationTile(
                    brightness: brightness,
                    glyph: AppGlyph.clock,
                    style: AppPalette.chipGold(brightness),
                    title: strings.notifDailyReminder,
                    subtitle: strings.notifDailyReminderBody('12'),
                    time: strings.minutesAgo,
                    isUnread: true,
                    onTap: () => context.go('/'),
                  ),
                  _divider(brightness),
                  _NotificationTile(
                    brightness: brightness,
                    glyph: AppGlyph.pot,
                    style: AppPalette.chipGreen(brightness),
                    title: strings.notifNewSuggestion,
                    subtitle: strings.notifNewSuggestionBody,
                    time: strings.hoursAgo(1),
                    isUnread: true,
                    onTap: () => context.go('/'),
                  ),
                  _divider(brightness),
                  _NotificationTile(
                    brightness: brightness,
                    glyph: AppGlyph.heartFill,
                    style: AppPalette.chipRose(brightness),
                    title: strings.notifFavoriteWaiting,
                    subtitle: strings.notifFavoriteWaitingBody,
                    time: strings.hoursAgo(3),
                    isUnread: true,
                    onTap: () => context.go('/vault'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Earlier section
            Text(
              strings.earlier,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              brightness: brightness,
              child: Column(
                children: [
                  _NotificationTile(
                    brightness: brightness,
                    glyph: AppGlyph.history,
                    style: AppPalette.chipBlue(brightness),
                    title: strings.notifMealLogged,
                    subtitle: strings.notifMealLoggedBody,
                    time: strings.yesterday,
                    isUnread: false,
                    onTap: () => context.go('/history'),
                  ),
                  _divider(brightness),
                  _NotificationTile(
                    brightness: brightness,
                    glyph: AppGlyph.vault,
                    style: AppPalette.chipViolet(brightness),
                    title: strings.notifVaultUpdate,
                    subtitle: strings.notifVaultUpdateBody(3),
                    time: strings.twoDaysAgo,
                    isUnread: false,
                    onTap: () => context.go('/vault'),
                  ),
                  _divider(brightness),
                  _NotificationTile(
                    brightness: brightness,
                    glyph: AppGlyph.settings,
                    style: AppPalette.chipGold(brightness),
                    title: strings.notifSettingsUpdate,
                    subtitle: strings.notifSettingsUpdateBody,
                    time: strings.daysAgo(3),
                    isUnread: false,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Settings shortcut
            _Card(
              brightness: brightness,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.go('/settings'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      _iconCircle(brightness, AppGlyph.bell, AppPalette.chipGold(brightness)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.notificationSettings,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.textPrimary(brightness),
                              ),
                            ),
                            Text(
                              strings.notificationSettingsDesc,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppPalette.textSecondary(brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(AppGlyph.chevron, color: AppPalette.textSecondary(brightness), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Brightness brightness) => Divider(height: 1, thickness: 1, color: AppPalette.hairline(brightness));

  Widget _iconCircle(Brightness brightness, AppGlyph glyph, ChipStyle style) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
      child: Center(child: AppIcon(glyph, color: style.foreground, size: 20)),
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
            color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : AppPalette.lightTextPrimary.withValues(alpha: 0.05),
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

class _NotificationTile extends StatelessWidget {
  final Brightness brightness;
  final AppGlyph glyph;
  final ChipStyle style;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.brightness,
    required this.glyph,
    required this.style,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? style.background.withValues(alpha: 0.5) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
              child: Center(child: AppIcon(glyph, color: style.foreground, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: AppPalette.textPrimary(brightness),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppPalette.brandGreen, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppPalette.textSecondary(brightness),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textSecondary(brightness).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
