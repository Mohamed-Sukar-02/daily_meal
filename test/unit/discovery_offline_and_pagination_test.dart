import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/providers/network_provider.dart';
import 'package:daily_meal/features/notifications/data/remote_notification_service.dart';
import 'package:daily_meal/features/vault/data/discovery_repository.dart';

void main() {
  group('DiscoveryRepository without Firebase', () {
    test('fetchPublicMeals returns an empty list instead of throwing', () async {
      final repo = DiscoveryRepository(null);

      final meals = await repo.fetchPublicMeals();

      expect(meals, isEmpty);
    });

    test('fetchPublicMeals stays empty even with pagination arguments', () async {
      final repo = DiscoveryRepository(null);

      final meals = await repo.fetchPublicMeals(limit: 10);

      expect(meals, isEmpty);
    });

    test('fetchMealById returns null instead of throwing', () async {
      final repo = DiscoveryRepository(null);

      expect(await repo.fetchMealById('some-cloud-id'), isNull);
    });
  });

  group('RemoteNotificationService without Firebase', () {
    test('Firebase is not initialized in this test environment', () {
      expect(Firebase.apps, isEmpty);
    });

    test('getNotificationsStream ends quietly without emitting or throwing', () async {
      final service = RemoteNotificationService();
      final logged = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logged.add(message);
      };
      try {
        final emitted = await service.getNotificationsStream().toList();

        expect(emitted, isEmpty);
        expect(logged, isEmpty, reason: 'offline guard must not log stream errors');
      } finally {
        debugPrint = originalDebugPrint;
      }
    });
  });

  group('firebaseAvailableProvider', () {
    test('defaults to false so providers stay offline-safe by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(firebaseAvailableProvider), isFalse);
    });

    test('can be overridden and observed cleanly', () async {
      final container = ProviderContainer(
        overrides: [firebaseAvailableProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);

      expect(container.read(firebaseAvailableProvider), isTrue);

      final sub = container.listen(firebaseAvailableProvider, (_, next) => next);
      addTearDown(sub.close);
      expect(sub.read(), isTrue);
    });
  });
}
