import 'package:daily_meal/core/navigation/notification_route.dart';
import 'package:daily_meal/features/notifications/domain/notification_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mealTargetFromRoute', () {
    test('reads the vault row out of both meal route shapes', () {
      expect(mealTargetFromRoute('/meal/7'), const MealTarget.local(7));
      expect(
        mealTargetFromRoute('/meal/cloud/abc_123'),
        const MealTarget.cloud('abc_123'),
      );
    });

    test(
      'is equal by value so one photo read serves every card with the same route',
      () {
        expect(mealTargetFromRoute('/meal/7'), mealTargetFromRoute('/meal/7'));
        expect(
          mealTargetFromRoute('/meal/7'),
          isNot(mealTargetFromRoute('/meal/8')),
        );
        expect(
          mealTargetFromRoute('/meal/7'),
          isNot(mealTargetFromRoute('/meal/cloud/7')),
        );
      },
    );

    test('returns nothing for a broadcast that is not about a meal', () {
      expect(mealTargetFromRoute(null), isNull);
      expect(mealTargetFromRoute(''), isNull);
      // The sanitizer's fallback for anything it could not trust.
      expect(mealTargetFromRoute('/'), isNull);
      expect(mealTargetFromRoute('/settings'), isNull);
      expect(mealTargetFromRoute('/vault?tab=explore'), isNull);
      expect(mealTargetFromRoute('/meal/'), isNull);
      expect(mealTargetFromRoute('/meal/zero'), isNull);
      expect(mealTargetFromRoute('/meal/0'), isNull);
      expect(mealTargetFromRoute('/meal/-3'), isNull);
      expect(mealTargetFromRoute('/meal/cloud/'), isNull);
      expect(mealTargetFromRoute('https://example.com/meal/7'), isNull);
    });
  });

  group('notificationAgeOf', () {
    final now = DateTime(2026, 10, 4, 13, 30);

    test('bands by calendar day, not by elapsed hours', () {
      // 23 hours apart, but the same calendar day.
      expect(
        notificationAgeOf(DateTime(2026, 10, 4, 1), now: now),
        NotificationAge.today,
      );
      expect(
        notificationAgeOf(DateTime(2026, 10, 4, 23, 59), now: now),
        NotificationAge.today,
      );
      expect(
        notificationAgeOf(DateTime(2026, 10, 3, 23, 59), now: now),
        NotificationAge.yesterday,
      );
      expect(
        notificationAgeOf(DateTime(2026, 9, 30), now: now),
        NotificationAge.earlier,
      );
    });

    test('keeps a clock that drifted ahead inside today', () {
      expect(
        notificationAgeOf(DateTime(2026, 10, 5), now: now),
        NotificationAge.today,
      );
    });

    test('crosses a month boundary by days, not by month number', () {
      expect(
        notificationAgeOf(DateTime(2026, 9, 30), now: DateTime(2026, 10, 1)),
        NotificationAge.yesterday,
      );
    });
  });
}
