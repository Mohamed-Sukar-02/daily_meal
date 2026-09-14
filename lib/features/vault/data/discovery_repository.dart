import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/cloud_meal.dart';

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
      throw Exception('فشل جلب الأكلات السحابية: $e');
    }
  }
}
