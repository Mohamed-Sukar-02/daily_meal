import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/router/app_router.dart';
import 'package:daily_meal/features/home/presentation/home_screen.dart';
import 'package:daily_meal/features/meals/presentation/meal_screen.dart';
import 'package:daily_meal/features/notifications/data/remote_notification_service.dart';
import 'package:daily_meal/features/notifications/domain/notification_item.dart';
import 'package:daily_meal/features/notifications/presentation/notifications_screen.dart';
import 'package:daily_meal/features/notifications/providers/notifications_provider.dart';
import 'package:daily_meal/features/settings/presentation/settings_screen.dart';
import 'package:daily_meal/features/vault/presentation/meal_vault_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// Replaces the Firestore feed: `FirebaseFirestore.instance` is unavailable in
/// tests, so the real service always yields an empty inbox.
class _FakeFeed extends RemoteNotificationService {
  _FakeFeed(this._items);

  final List<NotificationItem> _items;

  @override
  Stream<List<NotificationItem>> getNotificationsStream() => Stream.value(_items);
}

NotificationItem _item(String route) => NotificationItem(
      id: 'n-$route',
      title: const {'ar': 'feed-title', 'en': 'feed-title'},
      subtitle: const {'ar': 'body', 'en': 'body'},
      time: DateTime.now(),
      type: NotificationType.meal,
      route: route,
    );

void main() {
  late AppDatabase db;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Boots the app, feeds the inbox with one card and opens the notification
  /// centre the same way the Home bell does.
  Future<void> openFeed(WidgetTester tester, NotificationItem item) async {
    db = await pumpApp(
      tester,
      overrides: [
        notificationsProvider.overrideWith((ref) => NotificationsNotifier(_FakeFeed([item]))),
      ],
    );
    // `GoRouter.of` only resolves from inside the router's own subtree.
    GoRouter.of(tester.element(find.byType(ScaffoldWithNavBar))).push('/notifications');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
  }

  Future<void> tapCard(WidgetTester tester) async {
    await tester.tap(find.text('feed-title'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a notification opens the route the admin panel sent', (tester) async {
    await openFeed(tester, _item('/settings'));

    await tapCard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsNothing);

    await tearDownApp(tester, db);
  });

  testWidgets('a query-string route (/vault?tab=explore) lands on the vault without throwing',
      (tester) async {
    await openFeed(tester, _item('/vault?tab=explore'));

    await tapCard(tester);

    expect(tester.takeException(), isNull);
    // Painted, not merely kept alive inside the shell's IndexedStack.
    expect(find.byType(MealVaultScreen), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsNothing);
    // The bottom bar is still there, so the tab strip follows the branch.
    expect(find.byType(ScaffoldWithNavBar), findsOneWidget);

    await tearDownApp(tester, db);
  });

  testWidgets('a cloud meal route pushes the meal screen', (tester) async {
    await openFeed(tester, _item('/meal/cloud/abc123'));

    await tapCard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(MealScreen), findsOneWidget);

    await tearDownApp(tester, db);
  });

  testWidgets('the Home fallback route closes the feed instead of erroring', (tester) async {
    await openFeed(tester, _item('/'));

    await tapCard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsNothing);

    await tearDownApp(tester, db);
  });

  testWidgets('a notification without a route marks itself read and stays put', (tester) async {
    await openFeed(tester, NotificationItem(
      id: 'no-route',
      title: const {'ar': 'feed-title', 'en': 'feed-title'},
      subtitle: const {'ar': 'body', 'en': 'body'},
      time: DateTime.now(),
      type: NotificationType.meal,
    ));

    await tapCard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await tearDownApp(tester, db);
  });
}
