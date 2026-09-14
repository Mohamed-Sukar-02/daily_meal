class CloudMeal {
  final String id;
  final String name;
  final String? imageUrl;
  final String proteinType; // chicken, beef, fish, meatless, other
  final String carbsType;   // rice, pasta, bread, none
  final String category;    // tabeekh, casserole, dry_sandwich, popular, seafood
  final int prepTimeMinutes;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isStarterMeal; // True if this meal is automatically downloaded for fresh installs
  final String? notes;
  final DateTime createdAt;
  final String? proposedBy; // user ID or null for admin
  final String status;     // 'approved' in vault_meals, or 'pending' in staging_meals

  const CloudMeal({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.proteinType,
    required this.carbsType,
    required this.category,
    required this.prepTimeMinutes,
    this.isFridaySpecial = false,
    this.isBudgetFriendly = false,
    this.isStarterMeal = false,
    this.notes,
    required this.createdAt,
    this.proposedBy,
    this.status = 'approved',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'proteinType': proteinType,
      'carbsType': carbsType,
      'category': category,
      'prepTimeMinutes': prepTimeMinutes,
      'isFridaySpecial': isFridaySpecial,
      'isBudgetFriendly': isBudgetFriendly,
      'isStarterMeal': isStarterMeal,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'proposedBy': proposedBy,
      'status': status,
    };
  }

  factory CloudMeal.fromMap(Map<String, dynamic> map, String docId) {
    return CloudMeal(
      id: docId,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      proteinType: map['proteinType'] as String? ?? 'other',
      carbsType: map['carbsType'] as String? ?? 'none',
      category: map['category'] as String? ?? 'popular',
      prepTimeMinutes: (map['prepTimeMinutes'] as num?)?.toInt() ?? 30,
      isFridaySpecial: map['isFridaySpecial'] as bool? ?? false,
      isBudgetFriendly: map['isBudgetFriendly'] as bool? ?? false,
      isStarterMeal: map['isStarterMeal'] as bool? ?? false,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      proposedBy: map['proposedBy'] as String?,
      status: map['status'] as String? ?? 'approved',
    );
  }

  CloudMeal copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? proteinType,
    String? carbsType,
    String? category,
    int? prepTimeMinutes,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isStarterMeal,
    String? notes,
    DateTime? createdAt,
    String? proposedBy,
    String? status,
  }) {
    return CloudMeal(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      proteinType: proteinType ?? this.proteinType,
      carbsType: carbsType ?? this.carbsType,
      category: category ?? this.category,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      isFridaySpecial: isFridaySpecial ?? this.isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly ?? this.isBudgetFriendly,
      isStarterMeal: isStarterMeal ?? this.isStarterMeal,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      proposedBy: proposedBy ?? this.proposedBy,
      status: status ?? this.status,
    );
  }
}
