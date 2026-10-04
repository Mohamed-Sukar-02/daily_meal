import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/notification_route.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/meal_image.dart';
import '../domain/notification_item.dart';
import '../providers/notifications_provider.dart';

/// The three bands of the feed, in tab order.
const List<NotificationType> _tabTypes = [
  NotificationType.meal,
  NotificationType.reminder,
  NotificationType.update,
];

const double _gutter = 20;
const double _cardRadius = 22;
const double _tileRadius = 18;
const double _tileSize = 64;

/// The one elevation the feed uses. Dark mode separates its cards by tone
/// already, so it ships without a shadow rather than a black smudge.
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x0F16283B), blurRadius: 18, offset: Offset(0, 6)),
];

const List<BoxShadow> _segmentShadow = [
  BoxShadow(color: Color(0x1416283B), blurRadius: 10, offset: Offset(0, 3)),
];

/// The glyph and tint a broadcast wears when it has no photograph behind it.
class _TypeMark {
  const _TypeMark(this.glyph, this.chip);

  final AppGlyph glyph;
  final ChipStyle chip;
}

_TypeMark _markFor(NotificationType type, Brightness brightness) {
  return switch (type) {
    NotificationType.meal => _TypeMark(
      AppGlyph.pot,
      AppPalette.chipGreen(brightness),
    ),
    NotificationType.reminder => _TypeMark(
      AppGlyph.clock,
      AppPalette.chipGold(brightness),
    ),
    NotificationType.update => _TypeMark(
      AppGlyph.bell,
      AppPalette.chipViolet(brightness),
    ),
  };
}

/// One line of the scrollable feed.
sealed class _FeedRow {
  const _FeedRow();
}

class _BandRow extends _FeedRow {
  const _BandRow(this.age);

  final NotificationAge age;
}

class _BroadcastRow extends _FeedRow {
  const _BroadcastRow(this.item);

  final NotificationItem item;
}

class _SignatureRow extends _FeedRow {
  const _SignatureRow();
}

/// The day bands, in the order the newest-first feed walks into them.
List<_FeedRow> _buildFeedRows(List<NotificationItem> items) {
  final rows = <_FeedRow>[];
  NotificationAge? band;
  for (final item in items) {
    if (item.age != band) {
      rows.add(_BandRow(item.age));
      band = item.age;
    }
    rows.add(_BroadcastRow(item));
  }
  if (rows.isNotEmpty) rows.add(const _SignatureRow());
  return rows;
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final localizations = MaterialLocalizations.of(context);

    final tabType = _tabTypes[_activeTabIndex];
    final allNotifications = ref.watch(notificationsProvider);
    final visibleNotifications = allNotifications
        .where((item) => item.type == tabType)
        .toList();
    final rows = _buildFeedRows(visibleNotifications);

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      appBar: AppBar(
        backgroundColor: AppPalette.background(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppPalette.textPrimary(brightness),
          tooltip: localizations.backButtonTooltip,
          onPressed: () => context.pop(),
          style: IconButton.styleFrom(
            backgroundColor: AppPalette.tabContainer(brightness),
            foregroundColor: AppPalette.textPrimary(brightness),
            fixedSize: const Size(42, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              strings.notificationCenterTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 2),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: PopupMenuButton<String>(
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
                _menuEntry(
                  value: 'readAll',
                  label: strings.readAll,
                  brightness: brightness,
                  icon: Icons.done_all,
                ),
                _menuEntry(
                  value: 'deleteAll',
                  label: strings.deleteAll,
                  brightness: brightness,
                  icon: Icons.delete_outline,
                ),
                _menuEntry(
                  value: 'settings',
                  label: strings.notificationSettings,
                  brightness: brightness,
                  icon: Icons.settings_outlined,
                ),
              ],
              child: Ink(
                decoration: BoxDecoration(
                  color: AppPalette.tabContainer(brightness),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.more_vert,
                    size: 22,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 6, _gutter, 20),
            child: _FeedTabs(
              index: _activeTabIndex,
              labels: [
                strings.tabMeals,
                strings.tabReminders,
                strings.tabUpdates,
              ],
              onChanged: (index) => setState(() => _activeTabIndex = index),
            ),
          ),
          Expanded(
            child: visibleNotifications.isEmpty
                ? _EmptyFeed(
                    mark: _markFor(tabType, brightness),
                    message: _emptyMessage(strings, tabType),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, index) => switch (rows[index]) {
                      _BandRow(:final age) => _BandHeader(age: age),
                      _BroadcastRow(:final item) => _BroadcastCard(item),
                      _SignatureRow() => const _FeedSignature(),
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuEntry({
    required String value,
    required String label,
    required Brightness brightness,
    required IconData icon,
  }) {
    final color = value == 'deleteAll'
        ? AppPalette.heartCoral
        : AppPalette.textPrimary(brightness);
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _emptyMessage(AppStrings strings, NotificationType type) {
    return switch (type) {
      NotificationType.meal => strings.emptyNotificationsMeals,
      NotificationType.reminder => strings.emptyNotificationsReminders,
      NotificationType.update => strings.emptyNotificationsUpdates,
    };
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
    Brightness brightness,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card(brightness),
        title: Text(
          strings.deleteConfirmTitle,
          style: TextStyle(color: AppPalette.textPrimary(brightness)),
        ),
        content: Text(
          strings.deleteConfirmBody,
          style: TextStyle(color: AppPalette.textSecondary(brightness)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              strings.cancel,
              style: TextStyle(color: AppPalette.textSecondary(brightness)),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).deleteAll();
              Navigator.pop(ctx);
            },
            child: Text(
              strings.delete,
              style: const TextStyle(color: AppPalette.heartCoral),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three bands of the feed as one segmented control.
class _FeedTabs extends StatelessWidget {
  const _FeedTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.tabContainer(brightness),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _Segment(
                label: labels[i],
                active: i == index,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: active ? AppPalette.card(brightness) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: active && !isDark ? _segmentShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active
                      ? AppPalette.textPrimary(brightness)
                      : AppPalette.textSecondary(brightness),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandHeader extends StatelessWidget {
  const _BandHeader({required this.age});

  final NotificationAge age;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Text(
        switch (age) {
          NotificationAge.today => strings.notificationGroupToday,
          NotificationAge.yesterday => strings.notificationGroupYesterday,
          NotificationAge.earlier => strings.notificationGroupEarlier,
        },
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppPalette.textSecondary(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

/// One broadcast: the meal's own photograph when the route reaches one, the
/// type glyph when it does not.
class _BroadcastCard extends ConsumerWidget {
  const _BroadcastCard(this.item);

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final isDark = brightness == Brightness.dark;
    final mark = _markFor(item.type, brightness);

    final target = item.mealTarget;
    final photoPath = target == null
        ? null
        : ref.watch(notificationMealPhotoProvider(target)).valueOrNull;

    final tile = Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: mark.chip.background,
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
      child: Center(
        child: AppIcon(mark.glyph, color: mark.chip.foreground, size: 26),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: item.isRead
              ? AppPalette.card(brightness)
              : AppPalette.unreadSurface(brightness),
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: isDark ? null : _cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ref.read(notificationsProvider.notifier).markAsRead(item.id);
              if (item.route != null) {
                context.push(sanitizeNotificationRoute(item.route));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoPath == null)
                    tile
                  else
                    MealImage(
                      photoPath: photoPath,
                      width: _tileSize,
                      height: _tileSize,
                      cacheWidth: 200,
                      borderRadius: BorderRadius.circular(_tileRadius),
                      fallback: tile,
                      loading: Container(
                        width: _tileSize,
                        height: _tileSize,
                        color: AppPalette.tabContainer(brightness),
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.getLocalizedTitle(strings.isEn),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.28,
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: AppPalette.textPrimary(brightness),
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  left: 6,
                                  right: 6,
                                ),
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppPalette.brandGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                strings.timeAgo(
                                  DateTime.now()
                                      .difference(item.time)
                                      .inMinutes,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.28,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.textSecondary(brightness),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.getLocalizedSubtitle(strings.isEn),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: AppPalette.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedSignature extends StatelessWidget {
  const _FeedSignature();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ornament = AppIcon(
      AppGlyph.sprig,
      color: AppPalette.sparkOrange.withValues(alpha: 0.55),
      size: 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ornament,
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              AppStrings.of(context).goodFoodBrighterDays,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.textSecondary(
                  brightness,
                ).withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ornament,
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.mark, required this.message});

  final _TypeMark mark;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.tabContainer(brightness),
              ),
              child: Center(
                child: AppIcon(
                  mark.glyph,
                  color: mark.chip.foreground,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
