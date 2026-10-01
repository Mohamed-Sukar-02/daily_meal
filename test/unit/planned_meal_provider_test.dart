import 'package:daily_meal/features/home/providers/planned_meal_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The plan is the state between "not yet" and "it is in the log", and it is the
/// only Home state that lives outside Drift. Two properties matter and both are
/// about *time*, because that is what a day-keyed value in SharedPreferences can
/// get wrong:
///
///  * it must not outlive its own day — nothing cleans these keys up, so a plan
///    made yesterday would greet the user tomorrow and keep the reminder quiet
///    for a decision nobody made today;
///  * withdrawing one must not withdraw another — the undo lives in a toast that
///    can be tapped after the user has already changed their mind.
///
/// [DateTime] is a parameter on each call for exactly these two cases: no test
/// here has to wait for midnight to prove the boundary holds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tuesdayNight = DateTime(2026, 10, 20, 22, 15);
  final wednesdayEarly = DateTime(2026, 10, 21, 0, 5);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PlannedMeal', () {
    test('an empty store reads as no plan, not as an error', () async {
      expect(await PlannedMeal.current(now: tuesdayNight), isNull);
    });

    test('a planned meal reads back on the day it was set', () async {
      await PlannedMeal.plan(7, now: tuesdayNight);

      expect(await PlannedMeal.current(now: tuesdayNight), 7);
    });

    test('the plan does not cross into the next local day', () async {
      await PlannedMeal.plan(7, now: tuesdayNight);

      // 45 minutes later, across midnight: the same preference pair, a
      // different answer.
      expect(
        await PlannedMeal.current(now: wednesdayEarly),
        isNull,
        reason: 'the day travels with the id, so nothing has to be cleaned up',
      );
    });

    test('clearing takes it back', () async {
      await PlannedMeal.plan(7, now: tuesdayNight);
      await PlannedMeal.clear();

      expect(await PlannedMeal.current(now: tuesdayNight), isNull);
    });

    test('re-planning replaces the choice', () async {
      await PlannedMeal.plan(7, now: tuesdayNight);
      await PlannedMeal.plan(9, now: tuesdayNight);

      expect(await PlannedMeal.current(now: tuesdayNight), 9);
    });

    test('an undo only withdraws the plan it described', () async {
      await PlannedMeal.plan(7, now: tuesdayNight);
      // The user moved on to another dish before the toast expired, so the
      // pending "تراجع" now names a plan that is no longer the current one.
      await PlannedMeal.plan(9, now: tuesdayNight);

      await PlannedMeal.clearIfMatches(7, now: tuesdayNight);
      expect(await PlannedMeal.current(now: tuesdayNight), 9,
          reason: 'withdrawing a newer decision than the one offered is worse '
              'than a tap that does nothing');

      await PlannedMeal.clearIfMatches(9, now: tuesdayNight);
      expect(await PlannedMeal.current(now: tuesdayNight), isNull);
    });
  });
}
