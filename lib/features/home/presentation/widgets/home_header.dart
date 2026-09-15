import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';

/// Home header: notification icon (left), centred brand title, and profile avatar (right)
/// - Removed ugly chef hat logo with heart + spark marks as requested (image-1.png)
/// - Restored profile avatar on right as it was before
/// - Notification icon on left goes to new notifications page
/// - Supports dark/light mode via AppPalette
class HomeHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;

  const HomeHeader({super.key, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Notification icon - left side, new notifications page
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
                    child: AppIcon(
                      AppGlyph.bell,
                      color: AppPalette.textPrimary(brightness),
                      size: 22,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 10,
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
                // Title without ugly chef hat and spark marks - clean as requested
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
                  'كل يوم فكرة جديدة .. على قدك',
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
          // Profile avatar - restored as it was before, as requested
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppPalette.avatarBackground(brightness),
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
              child: Center(
                child: AppIcon(
                  AppGlyph.person,
                  color: AppPalette.avatarForeground(brightness),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
