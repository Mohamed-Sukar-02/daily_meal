import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../settings/providers/settings_providers.dart';
import '../../../notifications/providers/notifications_provider.dart';
import 'dart:io';

class HomeHeader extends ConsumerWidget {
  final VoidCallback? onProfileTap;
  final bool? hasUnreadNotifications;

  const HomeHeader({
    super.key,
    this.onProfileTap,
    this.hasUnreadNotifications,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final settingsAsync = ref.watch(appSettingsProvider);
    final avatarPath = settingsAsync.valueOrNull?.userAvatar;
    final bool isUnread = (hasUnreadNotifications ?? ref.watch(unreadNotificationsProvider)) == true;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final tiltAngle = isRtl ? 0.15 : -0.15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Notification icon - left side
          GestureDetector(
            onTap: () {
              ref.read(unreadNotificationsProvider.notifier).state = false;
              context.push('/notifications');
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Transform.rotate(
                angle: tiltAngle, // Adaptive tilt depending on layout direction
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/icons/notification_bell.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.contain,
                        color: AppPalette.textPrimary(brightness),
                        errorBuilder: (context, error, stackTrace) => AppIcon(
                          AppGlyph.bell,
                          color: AppPalette.textPrimary(brightness),
                          size: 40,
                        ),
                      ),
                      if (isUnread)
                        Image.asset(
                          'assets/icons/notification_around.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  strings.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.appTagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3C64F),
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.hairline(brightness)),
                boxShadow: [
                  BoxShadow(
                    color: brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppPalette.lightTextPrimary.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildAvatarImage(avatarPath, brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String? avatarPath, Brightness brightness) {
    Widget fallback() => Center(
          child: AppIcon(
            AppGlyph.person,
            color: AppPalette.avatarForeground(brightness),
            size: 22,
          ),
        );

    if (avatarPath == null || avatarPath.isEmpty) {
      return fallback();
    }

    if (avatarPath.startsWith('assets/')) {
      return Image.asset(
        avatarPath,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) {
          debugPrint('HomeHeader avatar asset error $avatarPath: $err');
          return fallback();
        },
      );
    }

    // File path: use Image.file with errorBuilder, avoid existsSync in build
    // If file doesn't exist, errorBuilder will show fallback
    // For robustness, also handle async existence via FutureBuilder for remote downloaded avatars
    return Image.file(
      File(avatarPath),
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, st) {
        debugPrint('HomeHeader avatar file error $avatarPath: $err - trying asset fallback');
        // If file path contains assets segment, try as asset
        if (avatarPath.contains('assets/')) {
          final assetPart = avatarPath.substring(avatarPath.indexOf('assets/'));
          return Image.asset(
            assetPart,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          );
        }
        return fallback();
      },
    );
  }
}
