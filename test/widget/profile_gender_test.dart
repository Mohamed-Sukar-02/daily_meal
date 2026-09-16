import 'package:daily_meal/core/services/avatar_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

Finder get avatarTiles => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith('profile_avatar_');
    });

Future<void> openProfileDialog(WidgetTester tester) async {
  await tapNav(tester, 'settings');
  await tester.ensureVisible(find.byKey(const Key('settings_profile_card')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings_profile_card')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('profile_save_button')), findsOneWidget);
}

bool saveEnabled(WidgetTester tester) => tester
    .widget<FilledButton>(find.byKey(const Key('profile_save_button')))
    .onPressed !=
    null;

void main() {
  testWidgets('gender is required and nothing can be saved before choosing',
      (tester) async {
    final db = await pumpApp(tester);
    addTearDown(db.close);

    await openProfileDialog(tester);

    expect(find.byKey(const Key('profile_gender_male')), findsOneWidget);
    expect(find.byKey(const Key('profile_gender_female')), findsOneWidget);
    // No avatar is shown until a gender exists…
    expect(avatarTiles, findsNothing);
    expect(find.byKey(const Key('profile_avatar_empty_hint')), findsOneWidget);
    // …and saving is blocked.
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('choosing a gender shows only that gender\'s avatars',
      (tester) async {
    final db = await pumpApp(tester);
    addTearDown(db.close);

    await openProfileDialog(tester);

    await tester.tap(find.byKey(const Key('profile_gender_male')));
    await tester.pumpAndSettle();

    expect(avatarTiles, findsNWidgets(AvatarService.maleAvatars.length));
    expect(find.byKey(const Key('profile_avatar_F01.png')), findsNothing);
    expect(find.byKey(const Key('profile_avatar_FY5.png')), findsNothing);
    expect(find.byKey(const Key('profile_avatar_MO1.png')), findsOneWidget);
    // An avatar was auto-picked, so saving is now allowed.
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('profile_gender_female')));
    await tester.pumpAndSettle();

    expect(avatarTiles, findsNWidgets(AvatarService.femaleAvatars.length));
    expect(find.byKey(const Key('profile_avatar_MO1.png')), findsNothing);
    expect(find.byKey(const Key('profile_avatar_MY3.png')), findsNothing);
    expect(find.byKey(const Key('profile_avatar_F01.png')), findsOneWidget);
    expect(saveEnabled(tester), isTrue,
        reason: 'the profile must never be left without an avatar');
  });

  testWidgets('a saved gender + avatar are restored when reopening the dialog',
      (tester) async {
    final db = await pumpApp(tester);
    addTearDown(db.close);

    await openProfileDialog(tester);
    await tester.tap(find.byKey(const Key('profile_gender_female')));
    await tester.pumpAndSettle();
    // Pick a specific avatar so the assertion below is deterministic.
    await tester.tap(find.byKey(const Key('profile_avatar_FY2.png')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    // Dialog closed and the choice was written to the database.
    expect(find.byKey(const Key('profile_save_button')), findsNothing);
    final settings = await db.appSettingsDao.getSettings();
    expect(settings.userGender, UserGender.female);
    expect(settings.userAvatar, 'assets/avatars/FY2.png');

    await openProfileDialog(tester);
    expect(avatarTiles, findsNWidgets(AvatarService.femaleAvatars.length));
    expect(find.byKey(const Key('profile_avatar_FY2.png')), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a stored avatar that does not match the gender is replaced',
      (tester) async {
    final db = await pumpApp(tester);
    addTearDown(db.close);

    // Simulate legacy data: a male avatar stored against a female profile.
    await db.appSettingsDao.updateSettings(
      AppSettingsCompanion(
        userGender: const Value(UserGender.female),
        userAvatar: const Value('assets/avatars/MO1.png'),
      ),
    );

    await openProfileDialog(tester);
    expect(avatarTiles, findsNWidgets(AvatarService.femaleAvatars.length));
    expect(find.byKey(const Key('profile_avatar_MO1.png')), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });
}
