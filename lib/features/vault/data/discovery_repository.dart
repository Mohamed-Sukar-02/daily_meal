import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/network_provider.dart';
import 'models/cloud_meal.dart';

/// Raised when the public vault cannot be read.
///
/// Carries the original error but no display text — the UI localises the
/// message (`AppStrings.discoveryFetchFailed`).
class CloudMealsFetchException implements Exception {
  final Object cause;

  const CloudMealsFetchException(this.cause);

  @override
  String toString() => 'CloudMealsFetchException: $cause';
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  final available = ref.watch(firebaseAvailableProvider);
  return DiscoveryRepository(available ? FirebaseFirestore.instance : null);
});

class DiscoveryRepository {
  final FirebaseFirestore? _firestore;

  DiscoveryRepository([this._firestore]);

  /// Fetches one page of approved meals from the public vault.
  ///
  /// Returns an empty list (never throws) when Firestore is unavailable —
  /// offline boot or tests — so discovery renders an empty state instead of a
  /// `[core/no-app]` crash.
  Future<List<CloudMeal>> fetchPublicMeals({
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return const <CloudMeal>[];
    try {
      var query = firestore
          .collection('vault_meals')
          .where('status', isEqualTo: 'approved')
          .limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();

      return snapshot.docs.map((doc) => CloudMeal.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw CloudMealsFetchException(e);
    }
  }

  /// One approved meal by cloud document id, or `null` when it is gone.
  ///
  /// The meal screen reads a single row to answer "did the vault change this
  /// meal?" without downloading the whole collection for it. Returns `null`
  /// without throwing when Firestore is unavailable.
  Future<CloudMeal?> fetchMealById(String cloudId) async {
    final firestore = _firestore;
    if (firestore == null) return null;
    try {
      final doc = await firestore.collection('vault_meals').doc(cloudId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      final meal = CloudMeal.fromMap(data, doc.id);
      return meal.status == 'approved' ? meal : null;
    } catch (e) {
      throw CloudMealsFetchException(e);
    }
  }
}
