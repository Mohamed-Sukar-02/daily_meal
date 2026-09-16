import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../settings/providers/settings_providers.dart';
import 'dart:io';

class HomeHeader extends ConsumerWidget {
  final VoidCallback? onProfileTap;

  const HomeHeader({super.key, this.onProfileTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final settingsAsync = ref.watch(appSettingsProvider);
    final avatarPath = settingsAsync.valueOrNull?.userAvatar;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Notification icon - left side
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppPalette.tabContainer(brightness),
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: ClipOval(
                      child: Image.asset(
                        'assets/notification_icon.jpg',
                        width: 22,
                        height: 22,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => AppIcon(
                          AppGlyph.bell,
                          color: AppPalette.textPrimary(brightness),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppPalette.heartCoral,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppPalette.card(brightness), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'أكلة النهاردة',
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
                  'من غير حيرة كل يوم .. هناكل ايه؟',
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
    if (avatarPath == null || avatarPath.isEmpty) {
      return Center(
        child: AppIcon(
          AppGlyph.person,
          color: AppPalette.avatarForeground(brightness),
          size: 22,
        ),
      );
    }
    if (avatarPath.startsWith('assets/')) {
      return Image.asset(
        avatarPath,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    } else {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        );
      } else {
        return Center(
          child: AppIcon(
            AppGlyph.person,
            color: AppPalette.avatarForeground(brightness),
            size: 22,
          ),
        );
      }
    }
  }
}
