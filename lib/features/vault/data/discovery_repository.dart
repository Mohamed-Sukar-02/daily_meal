import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return DiscoveryRepository(FirebaseFirestore.instance);
});

class DiscoveryRepository {
  final FirebaseFirestore _firestore;

  DiscoveryRepository(this._firestore);

  /// Fetches all approved meals from the public vault.
  Future<List<CloudMeal>> fetchPublicMeals() async {
    try {
      final snapshot = await _firestore
          .collection('vault_meals')
          .where('status', isEqualTo: 'approved')
          .get();

      return snapshot.docs.map((doc) => CloudMeal.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw CloudMealsFetchException(e);
    }
  }
}
