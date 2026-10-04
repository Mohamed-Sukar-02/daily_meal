import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/services/device_profile.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/core/widgets/meal_image.dart';
import 'package:daily_meal/features/notifications/data/remote_notification_service.dart';
import 'package:daily_meal/features/notifications/domain/notification_item.dart';
import 'package:daily_meal/features/notifications/presentation/notifications_screen.dart';
import 'package:daily_meal/features/notifications/providers/notifications_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFeed extends RemoteNotificationService {
  _FakeFeed(this._items);

  final List<NotificationItem> _items;

  @override
  Stream<List<NotificationItem>> getNotificationsStream() =>
      Stream.value(_items);
}

NotificationItem _item({
  required String id,
  required NotificationType type,
  required DateTime time,
  String? route,
}) {
  return NotificationItem(
    id: id,
    title: {'ar': 'title-$id', 'en': 'title-$id'},
    subtitle: {'ar': 'body-$id', 'en': 'body-$id'},
    time: time,
    type: type,
    route: route,
  );
}

MealsCompanion _meal({String? photoPath, String? cloudId}) {
  return MealsCompanion(
    name: drift.Value(
      photoPath == null ? 'meal without photo' : 'meal with photo',
    ),
    photoPath: drift.Value(photoPath),
    cloudId: drift.Value(cloudId),
    proteinType: const drift.Value(ProteinType.beef),
    carbsType: const drift.Value(CarbsType.rice),
    category: const drift.Value(MealCategory.egyptianTraditional),
    prepTime: const drift.Value(60),
  );
}

/// Opens the notification centre on its own, without booting the shell.
///
/// The app-wide harness pumps the whole router, which never settles while the
/// vault's idle sway is alive. The centre is what is under test here, so it is
/// pumped against a stub router that only has to answer the taps.
///
/// [vault] rows are added after the database seeds its starter meals, so
/// [items] is given the id of the last one rather than a guessed `/meal/1`.
Future<void> _pumpCenter(
  WidgetTester tester, {
  required List<NotificationItem> Function(int mealId) items,
  List<MealsCompanion> vault = const [],
  Locale locale = const Locale('ar'),
  Brightness brightness = Brightness.light,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  var mealId = 0;
  for (final meal in vault) {
    mealId = await db.mealsDao.insertMeal(meal);
  }
  addTearDown(db.close);

  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Placeholder(key: Key('stub-home')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Placeholder(key: Key('stub-settings')),
      ),
      GoRoute(
        path: '/meal/:id',
        builder: (context, state) => const Placeholder(key: Key('stub-meal')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(
            service: _FakeFeed(items(mealId)),
            deviceProfile: Future.value(
              DeviceProfile(firstOpenedAt: DateTime(2020), hasCooked: false),
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a meal broadcast shows the photo of the vault row its route points at',
    (tester) async {
      await _pumpCenter(
        tester,
        items: (mealId) => [
          _item(
            id: 'm1',
            type: NotificationType.meal,
            time: DateTime.now(),
            route: '/meal/$mealId',
          ),
        ],
        vault: [_meal(photoPath: 'assets/welcome_hero.jpg')],
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MealImage &&
              widget.photoPath == 'assets/welcome_hero.jpg',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a cloud meal route reaches the downloaded copy of the same photo',
    (tester) async {
      await _pumpCenter(
        tester,
        items: (mealId) => [
          _item(
            id: 'm2',
            type: NotificationType.meal,
            time: DateTime.now(),
            route: '/meal/cloud/abc123',
          ),
        ],
        vault: [_meal(photoPath: 'assets/welcome_hero.jpg', cloudId: 'abc123')],
      );

      expect(find.byType(MealImage), findsOneWidget);
    },
  );

  testWidgets(
    'a meal with no photo keeps the type glyph instead of a broken frame',
    (tester) async {
      await _pumpCenter(
        tester,
        items: (mealId) => [
          _item(
            id: 'm3',
            type: NotificationType.meal,
            time: DateTime.now(),
            route: '/meal/$mealId',
          ),
        ],
        vault: [_meal()],
      );

      expect(find.text('title-m3'), findsOneWidget);
      expect(find.byType(MealImage), findsNothing);
    },
  );

  testWidgets('a broadcast about nothing keeps its own glyph', (tester) async {
    await _pumpCenter(
      tester,
      items: (mealId) => [
        _item(
          id: 'u1',
          type: NotificationType.update,
          time: DateTime.now(),
          route: '/settings',
        ),
      ],
    );

    await tester.tap(find.text('تحديثات'));
    await tester.pumpAndSettle();

    expect(find.text('title-u1'), findsOneWidget);
    expect(find.byType(MealImage), findsNothing);
  });

  testWidgets('the feed splits into day bands', (tester) async {
    final now = DateTime.now();
    await _pumpCenter(
      tester,
      items: (mealId) => [
        _item(id: 't1', type: NotificationType.meal, time: now, route: '/'),
        _item(
          id: 'y1',
          type: NotificationType.meal,
          time: now.subtract(const Duration(days: 1)),
        ),
        _item(
          id: 'e1',
          type: NotificationType.meal,
          time: now.subtract(const Duration(days: 6)),
        ),
        _item(
          id: 'e2',
          type: NotificationType.meal,
          time: now.subtract(const Duration(days: 9)),
        ),
      ],
    );

    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('أمس'), findsOneWidget);
    // The two older broadcasts share one band instead of repeating it.
    expect(find.text('سابقاً'), findsOneWidget);
  });

  testWidgets('bands are named in English when the app speaks English', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      locale: const Locale('en'),
      items: (mealId) => [
        _item(id: 't1', type: NotificationType.meal, time: DateTime.now()),
      ],
    );

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets(
    'tapping a broadcast still opens the route the admin panel sent',
    (tester) async {
      await _pumpCenter(
        tester,
        items: (mealId) => [
          _item(
            id: 'm4',
            type: NotificationType.meal,
            time: DateTime.now(),
            route: '/settings',
          ),
        ],
      );

      await tester.tap(find.text('title-m4'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stub-settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the meals tab hides reminders and updates', (tester) async {
    final now = DateTime.now();
    await _pumpCenter(
      tester,
      items: (mealId) => [
        _item(id: 'meal', type: NotificationType.meal, time: now),
        _item(id: 'remind', type: NotificationType.reminder, time: now),
        _item(id: 'update', type: NotificationType.update, time: now),
      ],
    );

    expect(find.text('title-meal'), findsOneWidget);
    expect(find.text('title-remind'), findsNothing);

    await tester.tap(find.text('التذكيرات'));
    await tester.pumpAndSettle();

    expect(find.text('title-meal'), findsNothing);
    expect(find.text('title-remind'), findsOneWidget);
  });

  testWidgets('an empty tab says so instead of showing a bare list', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      items: (mealId) => [
        _item(id: 'meal', type: NotificationType.meal, time: DateTime.now()),
      ],
    );

    await tester.tap(find.text('تحديثات'));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد تحديثات'), findsOneWidget);
  });

  testWidgets('the feed survives dark mode at phone width', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpCenter(
      tester,
      brightness: Brightness.dark,
      items: (mealId) => [
        _item(
          id: 'dark',
          type: NotificationType.meal,
          time: DateTime.now(),
          route: '/',
        ),
      ],
    );

    expect(find.text('title-dark'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
