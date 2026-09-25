import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/notification_route.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/notifications_provider.dart';
import '../domain/notification_item.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final allNotifications = ref.watch(notificationsProvider);
    final filteredNotifications = allNotifications.where((n) {
      if (_activeTabIndex == 0) return n.type == NotificationType.meal;
      if (_activeTabIndex == 1) return n.type == NotificationType.reminder;
      return n.type == NotificationType.update;
    }).toList();

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      appBar: AppBar(
        backgroundColor: AppPalette.background(brightness),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.textPrimary(brightness),
            size: 22,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.notificationCenterTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            Text(
              strings.notificationCenterSubtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: AppPalette.textPrimary(brightness),
            ),
            color: AppPalette.card(brightness),
            onSelected: (value) {
              if (value == 'readAll') {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              } else if (value == 'deleteAll') {
                _showDeleteConfirmation(context, ref, strings, brightness);
              } else if (value == 'settings') {
                // `?section=notifications` tells the settings page to auto-
                // scroll to its notifications section. push (not go) keeps
                // the notifications screen on the stack so Back returns here.
                context.push('/settings?section=notifications');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'readAll',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: AppPalette.textPrimary(brightness), size: 20),
                    const SizedBox(width: 8),
                    Text(strings.readAll, style: TextStyle(color: AppPalette.textPrimary(brightness))),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deleteAll',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: AppPalette.heartCoral, size: 20),
                    const SizedBox(width: 8),
                    Text(strings.deleteAll, style: const TextStyle(color: AppPalette.heartCoral)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: AppPalette.textPrimary(brightness), size: 20),
                    const SizedBox(width: 8),
                    Text(strings.notificationSettings, style: TextStyle(color: AppPalette.textPrimary(brightness))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTab(0, strings.tabMeals, brightness),
                const SizedBox(width: 8),
                _buildTab(1, strings.tabReminders, brightness),
                const SizedBox(width: 8),
                _buildTab(2, strings.tabUpdates, brightness),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // List
          Expanded(
            child: filteredNotifications.isEmpty
                ? _buildEmptyState(strings, brightness)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredNotifications.length + 1, // +1 for the signature at the end
                    itemBuilder: (context, index) {
                      if (index == filteredNotifications.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              '~ ${strings.goodFoodBrighterDays} ~',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppPalette.textSecondary(brightness).withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      final item = filteredNotifications[index];
                      return _buildNotificationCard(item, strings, brightness, isRtl);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, Brightness brightness) {
    final isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppPalette.sparkOrange : AppPalette.tabContainer(brightness),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppPalette.textSecondary(brightness),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item, AppStrings strings, Brightness brightness, bool isRtl) {
    final isDark = brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1A29) : const Color(0xFFF9F5FF);
    final iconColor = isDark ? const Color(0xFFB794F4) : const Color(0xFF8B5CF6);

    IconData getIconForType(NotificationType type) {
      switch (type) {
        case NotificationType.meal:
          return Icons.restaurant_menu;
        case NotificationType.reminder:
          return Icons.access_time;
        case NotificationType.update:
          return Icons.new_releases_outlined;
      }
    }

    return GestureDetector(
      onTap: () {
        ref.read(notificationsProvider.notifier).markAsRead(item.id);
        if (item.route != null) {
          context.push(sanitizeNotificationRoute(item.route));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead ? AppPalette.card(brightness) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? AppPalette.outline(brightness) : iconColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: item.isRead ? AppPalette.background(brightness) : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  getIconForType(item.type),
                  color: item.isRead ? AppPalette.textSecondary(brightness) : iconColor,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.getLocalizedTitle(strings.isEn),
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 16,
                            color: AppPalette.textPrimary(brightness),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.getLocalizedSubtitle(strings.isEn),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPalette.textSecondary(brightness),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.timeAgo(DateTime.now().difference(item.time).inMinutes),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.textSecondary(brightness).withOpacity(0.7),
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

  Widget _buildEmptyState(AppStrings strings, Brightness brightness) {
    String emptyText;
    if (_activeTabIndex == 0) emptyText = strings.emptyNotificationsMeals;
    else if (_activeTabIndex == 1) emptyText = strings.emptyNotificationsReminders;
    else emptyText = strings.emptyNotificationsUpdates;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: AppPalette.textSecondary(brightness).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            emptyText,
            style: TextStyle(
              fontSize: 16,
              color: AppPalette.textSecondary(brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, AppStrings strings, Brightness brightness) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card(brightness),
        title: Text(strings.deleteConfirmTitle, style: TextStyle(color: AppPalette.textPrimary(brightness))),
        content: Text(strings.deleteConfirmBody, style: TextStyle(color: AppPalette.textSecondary(brightness))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel, style: TextStyle(color: AppPalette.textSecondary(brightness))),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).deleteAll();
              Navigator.pop(ctx);
            },
            child: Text(strings.delete, style: const TextStyle(color: AppPalette.heartCoral)),
          ),
        ],
      ),
    );
  }
}
