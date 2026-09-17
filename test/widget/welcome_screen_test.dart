import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/core/services/avatar_service.dart';
import 'package:daily_meal/features/welcome/presentation/welcome_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({Locale locale = const Locale('ar')}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const WelcomeScreen(),
      ),
    );
  }

  testWidgets('Step 1 renders hero branding and START NOW button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify Step 1 elements
    expect(find.byKey(const Key('welcome_start_now_button')), findsOneWidget);
    expect(find.text(AppStrings(const Locale('ar')).welcomeHeroTitle), findsOneWidget);
    expect(find.text(AppStrings(const Locale('ar')).welcomeHeroDescription), findsOneWidget);
  });

  testWidgets('Tapping START NOW navigates to Step 2 and Back returns to Step 1', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap START NOW
    await tester.tap(find.byKey(const Key('welcome_start_now_button')));
    await tester.pumpAndSettle();

    // Verify Step 2 elements exist
    expect(find.byKey(const Key('welcome_name_field')), findsOneWidget);
    expect(find.byKey(const Key('welcome_gender_male')), findsOneWidget);
    expect(find.byKey(const Key('welcome_gender_female')), findsOneWidget);
    expect(find.byKey(const Key('welcome_submit_button')), findsOneWidget);
    expect(find.byKey(const Key('welcome_back_button')), findsOneWidget);

    // Tap Back button
    await tester.tap(find.byKey(const Key('welcome_back_button')));
    await tester.pumpAndSettle();

    // Back on Step 1
    expect(find.byKey(const Key('welcome_start_now_button')), findsOneWidget);
  });

  testWidgets('Selecting gender shows corresponding avatars and updates selection', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome_start_now_button')));
    await tester.pumpAndSettle();

    // Initially no avatar list is visible
    expect(find.byKey(const Key('welcome_avatar_MO1.png')), findsNothing);
    expect(find.byKey(const Key('welcome_avatar_F01.png')), findsNothing);

    // Select Male
    await tester.tap(find.byKey(const Key('welcome_gender_male')));
    await tester.pumpAndSettle();

    // Male avatars appear
    expect(find.byKey(const Key('welcome_avatar_MO1.png')), findsOneWidget);
    expect(find.byKey(const Key('welcome_avatar_F01.png')), findsNothing);

    // Switch to Female
    await tester.tap(find.byKey(const Key('welcome_gender_female')));
    await tester.pumpAndSettle();

    // Female avatars appear
    expect(find.byKey(const Key('welcome_avatar_F01.png')), findsOneWidget);
    expect(find.byKey(const Key('welcome_avatar_MO1.png')), findsNothing);
  });

  testWidgets('Submitting form saves welcome data to database', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome_start_now_button')));
    await tester.pumpAndSettle();

    // Fill Name
    await tester.enterText(find.byKey(const Key('welcome_name_field')), 'سارة أحمد');
    await tester.pumpAndSettle();

    // Select Female
    await tester.tap(find.byKey(const Key('welcome_gender_female')));
    await tester.pumpAndSettle();

    // Tap specific avatar F02.png
    final avatarFinder = find.byKey(const Key('welcome_avatar_F02.png'));
    await tester.ensureVisible(avatarFinder);
    await tester.pumpAndSettle();
    await tester.tap(avatarFinder);
    await tester.pumpAndSettle();

    // Scroll to submit button and tap
    final submitFinder = find.byKey(const Key('welcome_submit_button'));
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    // Verify in database
    final settings = await db.appSettingsDao.getSettings();
    expect(settings.userName, equals('سارة أحمد'));
    expect(settings.userGender, equals(UserGender.female));
    expect(settings.userAvatar, equals('assets/avatars/F02.png'));
    expect(settings.isFirstRun, isFalse);
  });
}
