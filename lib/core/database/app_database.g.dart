// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MealsTable extends Meals with TableInfo<$MealsTable, Meal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameNormalizedMeta = const VerificationMeta(
    'nameNormalized',
  );
  @override
  late final GeneratedColumn<String> nameNormalized = GeneratedColumn<String>(
    'name_normalized',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProteinType, String> proteinType =
      GeneratedColumn<String>(
        'protein_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProteinType>($MealsTable.$converterproteinType);
  @override
  late final GeneratedColumnWithTypeConverter<CarbsType, String> carbsType =
      GeneratedColumn<String>(
        'carbs_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CarbsType>($MealsTable.$convertercarbsType);
  @override
  late final GeneratedColumnWithTypeConverter<MealCategory, String> category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MealCategory>($MealsTable.$convertercategory);
  static const VerificationMeta _prepTimeMeta = const VerificationMeta(
    'prepTime',
  );
  @override
  late final GeneratedColumn<int> prepTime = GeneratedColumn<int>(
    'prep_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFridaySpecialMeta = const VerificationMeta(
    'isFridaySpecial',
  );
  @override
  late final GeneratedColumn<bool> isFridaySpecial = GeneratedColumn<bool>(
    'is_friday_special',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_friday_special" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isBudgetFriendlyMeta = const VerificationMeta(
    'isBudgetFriendly',
  );
  @override
  late final GeneratedColumn<bool> isBudgetFriendly = GeneratedColumn<bool>(
    'is_budget_friendly',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_budget_friendly" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNormalized,
    photoPath,
    proteinType,
    carbsType,
    category,
    prepTime,
    isFridaySpecial,
    isBudgetFriendly,
    isFavorite,
    createdAt,
    updatedAt,
    cloudId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_normalized')) {
      context.handle(
        _nameNormalizedMeta,
        nameNormalized.isAcceptableOrUnknown(
          data['name_normalized']!,
          _nameNormalizedMeta,
        ),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('prep_time')) {
      context.handle(
        _prepTimeMeta,
        prepTime.isAcceptableOrUnknown(data['prep_time']!, _prepTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_prepTimeMeta);
    }
    if (data.containsKey('is_friday_special')) {
      context.handle(
        _isFridaySpecialMeta,
        isFridaySpecial.isAcceptableOrUnknown(
          data['is_friday_special']!,
          _isFridaySpecialMeta,
        ),
      );
    }
    if (data.containsKey('is_budget_friendly')) {
      context.handle(
        _isBudgetFriendlyMeta,
        isBudgetFriendly.isAcceptableOrUnknown(
          data['is_budget_friendly']!,
          _isBudgetFriendlyMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_normalized'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      proteinType: $MealsTable.$converterproteinType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}protein_type'],
        )!,
      ),
      carbsType: $MealsTable.$convertercarbsType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}carbs_type'],
        )!,
      ),
      category: $MealsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      prepTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prep_time'],
      )!,
      isFridaySpecial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_friday_special'],
      )!,
      isBudgetFriendly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_budget_friendly'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProteinType, String, String> $converterproteinType =
      const EnumNameConverter<ProteinType>(ProteinType.values);
  static JsonTypeConverter2<CarbsType, String, String> $convertercarbsType =
      const EnumNameConverter<CarbsType>(CarbsType.values);
  static JsonTypeConverter2<MealCategory, String, String> $convertercategory =
      const EnumNameConverter<MealCategory>(MealCategory.values);
}

class Meal extends DataClass implements Insertable<Meal> {
  final int id;
  final String name;
  final String? nameNormalized;
  final String? photoPath;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final MealCategory category;
  final int prepTime;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? cloudId;
  const Meal({
    required this.id,
    required this.name,
    this.nameNormalized,
    this.photoPath,
    required this.proteinType,
    required this.carbsType,
    required this.category,
    required this.prepTime,
    required this.isFridaySpecial,
    required this.isBudgetFriendly,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    this.cloudId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameNormalized != null) {
      map['name_normalized'] = Variable<String>(nameNormalized);
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    {
      map['protein_type'] = Variable<String>(
        $MealsTable.$converterproteinType.toSql(proteinType),
      );
    }
    {
      map['carbs_type'] = Variable<String>(
        $MealsTable.$convertercarbsType.toSql(carbsType),
      );
    }
    {
      map['category'] = Variable<String>(
        $MealsTable.$convertercategory.toSql(category),
      );
    }
    map['prep_time'] = Variable<int>(prepTime);
    map['is_friday_special'] = Variable<bool>(isFridaySpecial);
    map['is_budget_friendly'] = Variable<bool>(isBudgetFriendly);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
    }
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      name: Value(name),
      nameNormalized: nameNormalized == null && nullToAbsent
          ? const Value.absent()
          : Value(nameNormalized),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      proteinType: Value(proteinType),
      carbsType: Value(carbsType),
      category: Value(category),
      prepTime: Value(prepTime),
      isFridaySpecial: Value(isFridaySpecial),
      isBudgetFriendly: Value(isBudgetFriendly),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
    );
  }

  factory Meal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meal(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNormalized: serializer.fromJson<String?>(json['nameNormalized']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      proteinType: $MealsTable.$converterproteinType.fromJson(
        serializer.fromJson<String>(json['proteinType']),
      ),
      carbsType: $MealsTable.$convertercarbsType.fromJson(
        serializer.fromJson<String>(json['carbsType']),
      ),
      category: $MealsTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      prepTime: serializer.fromJson<int>(json['prepTime']),
      isFridaySpecial: serializer.fromJson<bool>(json['isFridaySpecial']),
      isBudgetFriendly: serializer.fromJson<bool>(json['isBudgetFriendly']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameNormalized': serializer.toJson<String?>(nameNormalized),
      'photoPath': serializer.toJson<String?>(photoPath),
      'proteinType': serializer.toJson<String>(
        $MealsTable.$converterproteinType.toJson(proteinType),
      ),
      'carbsType': serializer.toJson<String>(
        $MealsTable.$convertercarbsType.toJson(carbsType),
      ),
      'category': serializer.toJson<String>(
        $MealsTable.$convertercategory.toJson(category),
      ),
      'prepTime': serializer.toJson<int>(prepTime),
      'isFridaySpecial': serializer.toJson<bool>(isFridaySpecial),
      'isBudgetFriendly': serializer.toJson<bool>(isBudgetFriendly),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cloudId': serializer.toJson<String?>(cloudId),
    };
  }

  Meal copyWith({
    int? id,
    String? name,
    Value<String?> nameNormalized = const Value.absent(),
    Value<String?> photoPath = const Value.absent(),
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    int? prepTime,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> cloudId = const Value.absent(),
  }) => Meal(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNormalized: nameNormalized.present
        ? nameNormalized.value
        : this.nameNormalized,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    proteinType: proteinType ?? this.proteinType,
    carbsType: carbsType ?? this.carbsType,
    category: category ?? this.category,
    prepTime: prepTime ?? this.prepTime,
    isFridaySpecial: isFridaySpecial ?? this.isFridaySpecial,
    isBudgetFriendly: isBudgetFriendly ?? this.isBudgetFriendly,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
  );
  Meal copyWithCompanion(MealsCompanion data) {
    return Meal(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNormalized: data.nameNormalized.present
          ? data.nameNormalized.value
          : this.nameNormalized,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      proteinType: data.proteinType.present
          ? data.proteinType.value
          : this.proteinType,
      carbsType: data.carbsType.present ? data.carbsType.value : this.carbsType,
      category: data.category.present ? data.category.value : this.category,
      prepTime: data.prepTime.present ? data.prepTime.value : this.prepTime,
      isFridaySpecial: data.isFridaySpecial.present
          ? data.isFridaySpecial.value
          : this.isFridaySpecial,
      isBudgetFriendly: data.isBudgetFriendly.present
          ? data.isBudgetFriendly.value
          : this.isBudgetFriendly,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meal(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('photoPath: $photoPath, ')
          ..write('proteinType: $proteinType, ')
          ..write('carbsType: $carbsType, ')
          ..write('category: $category, ')
          ..write('prepTime: $prepTime, ')
          ..write('isFridaySpecial: $isFridaySpecial, ')
          ..write('isBudgetFriendly: $isBudgetFriendly, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameNormalized,
    photoPath,
    proteinType,
    carbsType,
    category,
    prepTime,
    isFridaySpecial,
    isBudgetFriendly,
    isFavorite,
    createdAt,
    updatedAt,
    cloudId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meal &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNormalized == this.nameNormalized &&
          other.photoPath == this.photoPath &&
          other.proteinType == this.proteinType &&
          other.carbsType == this.carbsType &&
          other.category == this.category &&
          other.prepTime == this.prepTime &&
          other.isFridaySpecial == this.isFridaySpecial &&
          other.isBudgetFriendly == this.isBudgetFriendly &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cloudId == this.cloudId);
}

class MealsCompanion extends UpdateCompanion<Meal> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> nameNormalized;
  final Value<String?> photoPath;
  final Value<ProteinType> proteinType;
  final Value<CarbsType> carbsType;
  final Value<MealCategory> category;
  final Value<int> prepTime;
  final Value<bool> isFridaySpecial;
  final Value<bool> isBudgetFriendly;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> cloudId;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNormalized = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.proteinType = const Value.absent(),
    this.carbsType = const Value.absent(),
    this.category = const Value.absent(),
    this.prepTime = const Value.absent(),
    this.isFridaySpecial = const Value.absent(),
    this.isBudgetFriendly = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
  });
  MealsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.nameNormalized = const Value.absent(),
    this.photoPath = const Value.absent(),
    required ProteinType proteinType,
    required CarbsType carbsType,
    required MealCategory category,
    required int prepTime,
    this.isFridaySpecial = const Value.absent(),
    this.isBudgetFriendly = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
  }) : name = Value(name),
       proteinType = Value(proteinType),
       carbsType = Value(carbsType),
       category = Value(category),
       prepTime = Value(prepTime);
  static Insertable<Meal> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameNormalized,
    Expression<String>? photoPath,
    Expression<String>? proteinType,
    Expression<String>? carbsType,
    Expression<String>? category,
    Expression<int>? prepTime,
    Expression<bool>? isFridaySpecial,
    Expression<bool>? isBudgetFriendly,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? cloudId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNormalized != null) 'name_normalized': nameNormalized,
      if (photoPath != null) 'photo_path': photoPath,
      if (proteinType != null) 'protein_type': proteinType,
      if (carbsType != null) 'carbs_type': carbsType,
      if (category != null) 'category': category,
      if (prepTime != null) 'prep_time': prepTime,
      if (isFridaySpecial != null) 'is_friday_special': isFridaySpecial,
      if (isBudgetFriendly != null) 'is_budget_friendly': isBudgetFriendly,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cloudId != null) 'cloud_id': cloudId,
    });
  }

  MealsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? nameNormalized,
    Value<String?>? photoPath,
    Value<ProteinType>? proteinType,
    Value<CarbsType>? carbsType,
    Value<MealCategory>? category,
    Value<int>? prepTime,
    Value<bool>? isFridaySpecial,
    Value<bool>? isBudgetFriendly,
    Value<bool>? isFavorite,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? cloudId,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      photoPath: photoPath ?? this.photoPath,
      proteinType: proteinType ?? this.proteinType,
      carbsType: carbsType ?? this.carbsType,
      category: category ?? this.category,
      prepTime: prepTime ?? this.prepTime,
      isFridaySpecial: isFridaySpecial ?? this.isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly ?? this.isBudgetFriendly,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cloudId: cloudId ?? this.cloudId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameNormalized.present) {
      map['name_normalized'] = Variable<String>(nameNormalized.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (proteinType.present) {
      map['protein_type'] = Variable<String>(
        $MealsTable.$converterproteinType.toSql(proteinType.value),
      );
    }
    if (carbsType.present) {
      map['carbs_type'] = Variable<String>(
        $MealsTable.$convertercarbsType.toSql(carbsType.value),
      );
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $MealsTable.$convertercategory.toSql(category.value),
      );
    }
    if (prepTime.present) {
      map['prep_time'] = Variable<int>(prepTime.value);
    }
    if (isFridaySpecial.present) {
      map['is_friday_special'] = Variable<bool>(isFridaySpecial.value);
    }
    if (isBudgetFriendly.present) {
      map['is_budget_friendly'] = Variable<bool>(isBudgetFriendly.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('photoPath: $photoPath, ')
          ..write('proteinType: $proteinType, ')
          ..write('carbsType: $carbsType, ')
          ..write('category: $category, ')
          ..write('prepTime: $prepTime, ')
          ..write('isFridaySpecial: $isFridaySpecial, ')
          ..write('isBudgetFriendly: $isBudgetFriendly, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }
}

class $MealHistoryTable extends MealHistory
    with TableInfo<$MealHistoryTable, MealHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES meals(id) ON DELETE SET NULL',
  );
  static const VerificationMeta _mealNameMeta = const VerificationMeta(
    'mealName',
  );
  @override
  late final GeneratedColumn<String> mealName = GeneratedColumn<String>(
    'meal_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProteinType, String> proteinType =
      GeneratedColumn<String>(
        'protein_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProteinType>($MealHistoryTable.$converterproteinType);
  @override
  late final GeneratedColumnWithTypeConverter<CarbsType, String> carbsType =
      GeneratedColumn<String>(
        'carbs_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CarbsType>($MealHistoryTable.$convertercarbsType);
  static const VerificationMeta _cookedAtMeta = const VerificationMeta(
    'cookedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cookedAt = GeneratedColumn<DateTime>(
    'cooked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MealEntryType, String> entryType =
      GeneratedColumn<String>(
        'entry_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('cooked'),
      ).withConverter<MealEntryType>($MealHistoryTable.$converterentryType);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    mealName,
    proteinType,
    carbsType,
    cookedAt,
    entryType,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    }
    if (data.containsKey('meal_name')) {
      context.handle(
        _mealNameMeta,
        mealName.isAcceptableOrUnknown(data['meal_name']!, _mealNameMeta),
      );
    } else if (isInserting) {
      context.missing(_mealNameMeta);
    }
    if (data.containsKey('cooked_at')) {
      context.handle(
        _cookedAtMeta,
        cookedAt.isAcceptableOrUnknown(data['cooked_at']!, _cookedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cookedAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_id'],
      ),
      mealName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_name'],
      )!,
      proteinType: $MealHistoryTable.$converterproteinType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}protein_type'],
        )!,
      ),
      carbsType: $MealHistoryTable.$convertercarbsType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}carbs_type'],
        )!,
      ),
      cookedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cooked_at'],
      )!,
      entryType: $MealHistoryTable.$converterentryType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entry_type'],
        )!,
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MealHistoryTable createAlias(String alias) {
    return $MealHistoryTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProteinType, String, String> $converterproteinType =
      const EnumNameConverter<ProteinType>(ProteinType.values);
  static JsonTypeConverter2<CarbsType, String, String> $convertercarbsType =
      const EnumNameConverter<CarbsType>(CarbsType.values);
  static JsonTypeConverter2<MealEntryType, String, String> $converterentryType =
      const EnumNameConverter<MealEntryType>(MealEntryType.values);
}

class MealHistoryData extends DataClass implements Insertable<MealHistoryData> {
  final int id;
  final int? mealId;
  final String mealName;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final DateTime cookedAt;
  final MealEntryType entryType;
  final String? notes;
  final DateTime createdAt;
  const MealHistoryData({
    required this.id,
    this.mealId,
    required this.mealName,
    required this.proteinType,
    required this.carbsType,
    required this.cookedAt,
    required this.entryType,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || mealId != null) {
      map['meal_id'] = Variable<int>(mealId);
    }
    map['meal_name'] = Variable<String>(mealName);
    {
      map['protein_type'] = Variable<String>(
        $MealHistoryTable.$converterproteinType.toSql(proteinType),
      );
    }
    {
      map['carbs_type'] = Variable<String>(
        $MealHistoryTable.$convertercarbsType.toSql(carbsType),
      );
    }
    map['cooked_at'] = Variable<DateTime>(cookedAt);
    {
      map['entry_type'] = Variable<String>(
        $MealHistoryTable.$converterentryType.toSql(entryType),
      );
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MealHistoryCompanion toCompanion(bool nullToAbsent) {
    return MealHistoryCompanion(
      id: Value(id),
      mealId: mealId == null && nullToAbsent
          ? const Value.absent()
          : Value(mealId),
      mealName: Value(mealName),
      proteinType: Value(proteinType),
      carbsType: Value(carbsType),
      cookedAt: Value(cookedAt),
      entryType: Value(entryType),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory MealHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealHistoryData(
      id: serializer.fromJson<int>(json['id']),
      mealId: serializer.fromJson<int?>(json['mealId']),
      mealName: serializer.fromJson<String>(json['mealName']),
      proteinType: $MealHistoryTable.$converterproteinType.fromJson(
        serializer.fromJson<String>(json['proteinType']),
      ),
      carbsType: $MealHistoryTable.$convertercarbsType.fromJson(
        serializer.fromJson<String>(json['carbsType']),
      ),
      cookedAt: serializer.fromJson<DateTime>(json['cookedAt']),
      entryType: $MealHistoryTable.$converterentryType.fromJson(
        serializer.fromJson<String>(json['entryType']),
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealId': serializer.toJson<int?>(mealId),
      'mealName': serializer.toJson<String>(mealName),
      'proteinType': serializer.toJson<String>(
        $MealHistoryTable.$converterproteinType.toJson(proteinType),
      ),
      'carbsType': serializer.toJson<String>(
        $MealHistoryTable.$convertercarbsType.toJson(carbsType),
      ),
      'cookedAt': serializer.toJson<DateTime>(cookedAt),
      'entryType': serializer.toJson<String>(
        $MealHistoryTable.$converterentryType.toJson(entryType),
      ),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MealHistoryData copyWith({
    int? id,
    Value<int?> mealId = const Value.absent(),
    String? mealName,
    ProteinType? proteinType,
    CarbsType? carbsType,
    DateTime? cookedAt,
    MealEntryType? entryType,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => MealHistoryData(
    id: id ?? this.id,
    mealId: mealId.present ? mealId.value : this.mealId,
    mealName: mealName ?? this.mealName,
    proteinType: proteinType ?? this.proteinType,
    carbsType: carbsType ?? this.carbsType,
    cookedAt: cookedAt ?? this.cookedAt,
    entryType: entryType ?? this.entryType,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  MealHistoryData copyWithCompanion(MealHistoryCompanion data) {
    return MealHistoryData(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      mealName: data.mealName.present ? data.mealName.value : this.mealName,
      proteinType: data.proteinType.present
          ? data.proteinType.value
          : this.proteinType,
      carbsType: data.carbsType.present ? data.carbsType.value : this.carbsType,
      cookedAt: data.cookedAt.present ? data.cookedAt.value : this.cookedAt,
      entryType: data.entryType.present ? data.entryType.value : this.entryType,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealHistoryData(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('mealName: $mealName, ')
          ..write('proteinType: $proteinType, ')
          ..write('carbsType: $carbsType, ')
          ..write('cookedAt: $cookedAt, ')
          ..write('entryType: $entryType, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mealId,
    mealName,
    proteinType,
    carbsType,
    cookedAt,
    entryType,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealHistoryData &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.mealName == this.mealName &&
          other.proteinType == this.proteinType &&
          other.carbsType == this.carbsType &&
          other.cookedAt == this.cookedAt &&
          other.entryType == this.entryType &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class MealHistoryCompanion extends UpdateCompanion<MealHistoryData> {
  final Value<int> id;
  final Value<int?> mealId;
  final Value<String> mealName;
  final Value<ProteinType> proteinType;
  final Value<CarbsType> carbsType;
  final Value<DateTime> cookedAt;
  final Value<MealEntryType> entryType;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const MealHistoryCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.mealName = const Value.absent(),
    this.proteinType = const Value.absent(),
    this.carbsType = const Value.absent(),
    this.cookedAt = const Value.absent(),
    this.entryType = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MealHistoryCompanion.insert({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    required String mealName,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required DateTime cookedAt,
    this.entryType = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : mealName = Value(mealName),
       proteinType = Value(proteinType),
       carbsType = Value(carbsType),
       cookedAt = Value(cookedAt);
  static Insertable<MealHistoryData> custom({
    Expression<int>? id,
    Expression<int>? mealId,
    Expression<String>? mealName,
    Expression<String>? proteinType,
    Expression<String>? carbsType,
    Expression<DateTime>? cookedAt,
    Expression<String>? entryType,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (mealName != null) 'meal_name': mealName,
      if (proteinType != null) 'protein_type': proteinType,
      if (carbsType != null) 'carbs_type': carbsType,
      if (cookedAt != null) 'cooked_at': cookedAt,
      if (entryType != null) 'entry_type': entryType,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MealHistoryCompanion copyWith({
    Value<int>? id,
    Value<int?>? mealId,
    Value<String>? mealName,
    Value<ProteinType>? proteinType,
    Value<CarbsType>? carbsType,
    Value<DateTime>? cookedAt,
    Value<MealEntryType>? entryType,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return MealHistoryCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      mealName: mealName ?? this.mealName,
      proteinType: proteinType ?? this.proteinType,
      carbsType: carbsType ?? this.carbsType,
      cookedAt: cookedAt ?? this.cookedAt,
      entryType: entryType ?? this.entryType,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (mealName.present) {
      map['meal_name'] = Variable<String>(mealName.value);
    }
    if (proteinType.present) {
      map['protein_type'] = Variable<String>(
        $MealHistoryTable.$converterproteinType.toSql(proteinType.value),
      );
    }
    if (carbsType.present) {
      map['carbs_type'] = Variable<String>(
        $MealHistoryTable.$convertercarbsType.toSql(carbsType.value),
      );
    }
    if (cookedAt.present) {
      map['cooked_at'] = Variable<DateTime>(cookedAt.value);
    }
    if (entryType.present) {
      map['entry_type'] = Variable<String>(
        $MealHistoryTable.$converterentryType.toSql(entryType.value),
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealHistoryCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('mealName: $mealName, ')
          ..write('proteinType: $proteinType, ')
          ..write('carbsType: $carbsType, ')
          ..write('cookedAt: $cookedAt, ')
          ..write('entryType: $entryType, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _cooldownDaysMeta = const VerificationMeta(
    'cooldownDays',
  );
  @override
  late final GeneratedColumn<int> cooldownDays = GeneratedColumn<int>(
    'cooldown_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(14),
  );
  static const VerificationMeta _chickenCooldownDaysMeta =
      const VerificationMeta('chickenCooldownDays');
  @override
  late final GeneratedColumn<int> chickenCooldownDays = GeneratedColumn<int>(
    'chicken_cooldown_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _beefCooldownDaysMeta = const VerificationMeta(
    'beefCooldownDays',
  );
  @override
  late final GeneratedColumn<int> beefCooldownDays = GeneratedColumn<int>(
    'beef_cooldown_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _fishCooldownDaysMeta = const VerificationMeta(
    'fishCooldownDays',
  );
  @override
  late final GeneratedColumn<int> fishCooldownDays = GeneratedColumn<int>(
    'fish_cooldown_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _meatlessCooldownDaysMeta =
      const VerificationMeta('meatlessCooldownDays');
  @override
  late final GeneratedColumn<int> meatlessCooldownDays = GeneratedColumn<int>(
    'meatless_cooldown_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _preventRepeatProteinMeta =
      const VerificationMeta('preventRepeatProtein');
  @override
  late final GeneratedColumn<bool> preventRepeatProtein = GeneratedColumn<bool>(
    'prevent_repeat_protein',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("prevent_repeat_protein" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _preventRepeatCarbsMeta =
      const VerificationMeta('preventRepeatCarbs');
  @override
  late final GeneratedColumn<bool> preventRepeatCarbs = GeneratedColumn<bool>(
    'prevent_repeat_carbs',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("prevent_repeat_carbs" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notificationHourMeta = const VerificationMeta(
    'notificationHour',
  );
  @override
  late final GeneratedColumn<int> notificationHour = GeneratedColumn<int>(
    'notification_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _notificationMinuteMeta =
      const VerificationMeta('notificationMinute');
  @override
  late final GeneratedColumn<int> notificationMinute = GeneratedColumn<int>(
    'notification_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AppThemeModePreference, String>
  themeMode =
      GeneratedColumn<String>(
        'theme_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('system'),
      ).withConverter<AppThemeModePreference>(
        $AppSettingsTable.$converterthemeMode,
      );
  @override
  late final GeneratedColumnWithTypeConverter<AppLanguagePreference, String>
  language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ar'),
  ).withConverter<AppLanguagePreference>($AppSettingsTable.$converterlanguage);
  static const VerificationMeta _isFirstRunMeta = const VerificationMeta(
    'isFirstRun',
  );
  @override
  late final GeneratedColumn<bool> isFirstRun = GeneratedColumn<bool>(
    'is_first_run',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_first_run" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userEmailMeta = const VerificationMeta(
    'userEmail',
  );
  @override
  late final GeneratedColumn<String> userEmail = GeneratedColumn<String>(
    'user_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userGenderMeta = const VerificationMeta(
    'userGender',
  );
  @override
  late final GeneratedColumn<String> userGender = GeneratedColumn<String>(
    'user_gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userAvatarMeta = const VerificationMeta(
    'userAvatar',
  );
  @override
  late final GeneratedColumn<String> userAvatar = GeneratedColumn<String>(
    'user_avatar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cooldownDays,
    chickenCooldownDays,
    beefCooldownDays,
    fishCooldownDays,
    meatlessCooldownDays,
    preventRepeatProtein,
    preventRepeatCarbs,
    notificationHour,
    notificationMinute,
    notificationsEnabled,
    themeMode,
    language,
    isFirstRun,
    userName,
    userEmail,
    userGender,
    userAvatar,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cooldown_days')) {
      context.handle(
        _cooldownDaysMeta,
        cooldownDays.isAcceptableOrUnknown(
          data['cooldown_days']!,
          _cooldownDaysMeta,
        ),
      );
    }
    if (data.containsKey('chicken_cooldown_days')) {
      context.handle(
        _chickenCooldownDaysMeta,
        chickenCooldownDays.isAcceptableOrUnknown(
          data['chicken_cooldown_days']!,
          _chickenCooldownDaysMeta,
        ),
      );
    }
    if (data.containsKey('beef_cooldown_days')) {
      context.handle(
        _beefCooldownDaysMeta,
        beefCooldownDays.isAcceptableOrUnknown(
          data['beef_cooldown_days']!,
          _beefCooldownDaysMeta,
        ),
      );
    }
    if (data.containsKey('fish_cooldown_days')) {
      context.handle(
        _fishCooldownDaysMeta,
        fishCooldownDays.isAcceptableOrUnknown(
          data['fish_cooldown_days']!,
          _fishCooldownDaysMeta,
        ),
      );
    }
    if (data.containsKey('meatless_cooldown_days')) {
      context.handle(
        _meatlessCooldownDaysMeta,
        meatlessCooldownDays.isAcceptableOrUnknown(
          data['meatless_cooldown_days']!,
          _meatlessCooldownDaysMeta,
        ),
      );
    }
    if (data.containsKey('prevent_repeat_protein')) {
      context.handle(
        _preventRepeatProteinMeta,
        preventRepeatProtein.isAcceptableOrUnknown(
          data['prevent_repeat_protein']!,
          _preventRepeatProteinMeta,
        ),
      );
    }
    if (data.containsKey('prevent_repeat_carbs')) {
      context.handle(
        _preventRepeatCarbsMeta,
        preventRepeatCarbs.isAcceptableOrUnknown(
          data['prevent_repeat_carbs']!,
          _preventRepeatCarbsMeta,
        ),
      );
    }
    if (data.containsKey('notification_hour')) {
      context.handle(
        _notificationHourMeta,
        notificationHour.isAcceptableOrUnknown(
          data['notification_hour']!,
          _notificationHourMeta,
        ),
      );
    }
    if (data.containsKey('notification_minute')) {
      context.handle(
        _notificationMinuteMeta,
        notificationMinute.isAcceptableOrUnknown(
          data['notification_minute']!,
          _notificationMinuteMeta,
        ),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('is_first_run')) {
      context.handle(
        _isFirstRunMeta,
        isFirstRun.isAcceptableOrUnknown(
          data['is_first_run']!,
          _isFirstRunMeta,
        ),
      );
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    }
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
    }
    if (data.containsKey('user_gender')) {
      context.handle(
        _userGenderMeta,
        userGender.isAcceptableOrUnknown(data['user_gender']!, _userGenderMeta),
      );
    }
    if (data.containsKey('user_avatar')) {
      context.handle(
        _userAvatarMeta,
        userAvatar.isAcceptableOrUnknown(data['user_avatar']!, _userAvatarMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cooldownDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cooldown_days'],
      )!,
      chickenCooldownDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chicken_cooldown_days'],
      )!,
      beefCooldownDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}beef_cooldown_days'],
      )!,
      fishCooldownDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fish_cooldown_days'],
      )!,
      meatlessCooldownDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meatless_cooldown_days'],
      )!,
      preventRepeatProtein: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}prevent_repeat_protein'],
      )!,
      preventRepeatCarbs: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}prevent_repeat_carbs'],
      )!,
      notificationHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_hour'],
      )!,
      notificationMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_minute'],
      )!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      themeMode: $AppSettingsTable.$converterthemeMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}theme_mode'],
        )!,
      ),
      language: $AppSettingsTable.$converterlanguage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}language'],
        )!,
      ),
      isFirstRun: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_first_run'],
      )!,
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      ),
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
      ),
      userGender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_gender'],
      ),
      userAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_avatar'],
      ),
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AppThemeModePreference, String, String>
  $converterthemeMode = const EnumNameConverter<AppThemeModePreference>(
    AppThemeModePreference.values,
  );
  static JsonTypeConverter2<AppLanguagePreference, String, String>
  $converterlanguage = const EnumNameConverter<AppLanguagePreference>(
    AppLanguagePreference.values,
  );
}

class AppSettingsData extends DataClass implements Insertable<AppSettingsData> {
  final int id;
  final int cooldownDays;
  final int chickenCooldownDays;
  final int beefCooldownDays;
  final int fishCooldownDays;
  final int meatlessCooldownDays;
  final bool preventRepeatProtein;
  final bool preventRepeatCarbs;
  final int notificationHour;
  final int notificationMinute;
  final bool notificationsEnabled;
  final AppThemeModePreference themeMode;
  final AppLanguagePreference language;
  final bool isFirstRun;
  final String? userName;
  final String? userEmail;
  final String? userGender;
  final String? userAvatar;
  const AppSettingsData({
    required this.id,
    required this.cooldownDays,
    required this.chickenCooldownDays,
    required this.beefCooldownDays,
    required this.fishCooldownDays,
    required this.meatlessCooldownDays,
    required this.preventRepeatProtein,
    required this.preventRepeatCarbs,
    required this.notificationHour,
    required this.notificationMinute,
    required this.notificationsEnabled,
    required this.themeMode,
    required this.language,
    required this.isFirstRun,
    this.userName,
    this.userEmail,
    this.userGender,
    this.userAvatar,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cooldown_days'] = Variable<int>(cooldownDays);
    map['chicken_cooldown_days'] = Variable<int>(chickenCooldownDays);
    map['beef_cooldown_days'] = Variable<int>(beefCooldownDays);
    map['fish_cooldown_days'] = Variable<int>(fishCooldownDays);
    map['meatless_cooldown_days'] = Variable<int>(meatlessCooldownDays);
    map['prevent_repeat_protein'] = Variable<bool>(preventRepeatProtein);
    map['prevent_repeat_carbs'] = Variable<bool>(preventRepeatCarbs);
    map['notification_hour'] = Variable<int>(notificationHour);
    map['notification_minute'] = Variable<int>(notificationMinute);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    {
      map['theme_mode'] = Variable<String>(
        $AppSettingsTable.$converterthemeMode.toSql(themeMode),
      );
    }
    {
      map['language'] = Variable<String>(
        $AppSettingsTable.$converterlanguage.toSql(language),
      );
    }
    map['is_first_run'] = Variable<bool>(isFirstRun);
    if (!nullToAbsent || userName != null) {
      map['user_name'] = Variable<String>(userName);
    }
    if (!nullToAbsent || userEmail != null) {
      map['user_email'] = Variable<String>(userEmail);
    }
    if (!nullToAbsent || userGender != null) {
      map['user_gender'] = Variable<String>(userGender);
    }
    if (!nullToAbsent || userAvatar != null) {
      map['user_avatar'] = Variable<String>(userAvatar);
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      cooldownDays: Value(cooldownDays),
      chickenCooldownDays: Value(chickenCooldownDays),
      beefCooldownDays: Value(beefCooldownDays),
      fishCooldownDays: Value(fishCooldownDays),
      meatlessCooldownDays: Value(meatlessCooldownDays),
      preventRepeatProtein: Value(preventRepeatProtein),
      preventRepeatCarbs: Value(preventRepeatCarbs),
      notificationHour: Value(notificationHour),
      notificationMinute: Value(notificationMinute),
      notificationsEnabled: Value(notificationsEnabled),
      themeMode: Value(themeMode),
      language: Value(language),
      isFirstRun: Value(isFirstRun),
      userName: userName == null && nullToAbsent
          ? const Value.absent()
          : Value(userName),
      userEmail: userEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(userEmail),
      userGender: userGender == null && nullToAbsent
          ? const Value.absent()
          : Value(userGender),
      userAvatar: userAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(userAvatar),
    );
  }

  factory AppSettingsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsData(
      id: serializer.fromJson<int>(json['id']),
      cooldownDays: serializer.fromJson<int>(json['cooldownDays']),
      chickenCooldownDays: serializer.fromJson<int>(
        json['chickenCooldownDays'],
      ),
      beefCooldownDays: serializer.fromJson<int>(json['beefCooldownDays']),
      fishCooldownDays: serializer.fromJson<int>(json['fishCooldownDays']),
      meatlessCooldownDays: serializer.fromJson<int>(
        json['meatlessCooldownDays'],
      ),
      preventRepeatProtein: serializer.fromJson<bool>(
        json['preventRepeatProtein'],
      ),
      preventRepeatCarbs: serializer.fromJson<bool>(json['preventRepeatCarbs']),
      notificationHour: serializer.fromJson<int>(json['notificationHour']),
      notificationMinute: serializer.fromJson<int>(json['notificationMinute']),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      themeMode: $AppSettingsTable.$converterthemeMode.fromJson(
        serializer.fromJson<String>(json['themeMode']),
      ),
      language: $AppSettingsTable.$converterlanguage.fromJson(
        serializer.fromJson<String>(json['language']),
      ),
      isFirstRun: serializer.fromJson<bool>(json['isFirstRun']),
      userName: serializer.fromJson<String?>(json['userName']),
      userEmail: serializer.fromJson<String?>(json['userEmail']),
      userGender: serializer.fromJson<String?>(json['userGender']),
      userAvatar: serializer.fromJson<String?>(json['userAvatar']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cooldownDays': serializer.toJson<int>(cooldownDays),
      'chickenCooldownDays': serializer.toJson<int>(chickenCooldownDays),
      'beefCooldownDays': serializer.toJson<int>(beefCooldownDays),
      'fishCooldownDays': serializer.toJson<int>(fishCooldownDays),
      'meatlessCooldownDays': serializer.toJson<int>(meatlessCooldownDays),
      'preventRepeatProtein': serializer.toJson<bool>(preventRepeatProtein),
      'preventRepeatCarbs': serializer.toJson<bool>(preventRepeatCarbs),
      'notificationHour': serializer.toJson<int>(notificationHour),
      'notificationMinute': serializer.toJson<int>(notificationMinute),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'themeMode': serializer.toJson<String>(
        $AppSettingsTable.$converterthemeMode.toJson(themeMode),
      ),
      'language': serializer.toJson<String>(
        $AppSettingsTable.$converterlanguage.toJson(language),
      ),
      'isFirstRun': serializer.toJson<bool>(isFirstRun),
      'userName': serializer.toJson<String?>(userName),
      'userEmail': serializer.toJson<String?>(userEmail),
      'userGender': serializer.toJson<String?>(userGender),
      'userAvatar': serializer.toJson<String?>(userAvatar),
    };
  }

  AppSettingsData copyWith({
    int? id,
    int? cooldownDays,
    int? chickenCooldownDays,
    int? beefCooldownDays,
    int? fishCooldownDays,
    int? meatlessCooldownDays,
    bool? preventRepeatProtein,
    bool? preventRepeatCarbs,
    int? notificationHour,
    int? notificationMinute,
    bool? notificationsEnabled,
    AppThemeModePreference? themeMode,
    AppLanguagePreference? language,
    bool? isFirstRun,
    Value<String?> userName = const Value.absent(),
    Value<String?> userEmail = const Value.absent(),
    Value<String?> userGender = const Value.absent(),
    Value<String?> userAvatar = const Value.absent(),
  }) => AppSettingsData(
    id: id ?? this.id,
    cooldownDays: cooldownDays ?? this.cooldownDays,
    chickenCooldownDays: chickenCooldownDays ?? this.chickenCooldownDays,
    beefCooldownDays: beefCooldownDays ?? this.beefCooldownDays,
    fishCooldownDays: fishCooldownDays ?? this.fishCooldownDays,
    meatlessCooldownDays: meatlessCooldownDays ?? this.meatlessCooldownDays,
    preventRepeatProtein: preventRepeatProtein ?? this.preventRepeatProtein,
    preventRepeatCarbs: preventRepeatCarbs ?? this.preventRepeatCarbs,
    notificationHour: notificationHour ?? this.notificationHour,
    notificationMinute: notificationMinute ?? this.notificationMinute,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    isFirstRun: isFirstRun ?? this.isFirstRun,
    userName: userName.present ? userName.value : this.userName,
    userEmail: userEmail.present ? userEmail.value : this.userEmail,
    userGender: userGender.present ? userGender.value : this.userGender,
    userAvatar: userAvatar.present ? userAvatar.value : this.userAvatar,
  );
  AppSettingsData copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingsData(
      id: data.id.present ? data.id.value : this.id,
      cooldownDays: data.cooldownDays.present
          ? data.cooldownDays.value
          : this.cooldownDays,
      chickenCooldownDays: data.chickenCooldownDays.present
          ? data.chickenCooldownDays.value
          : this.chickenCooldownDays,
      beefCooldownDays: data.beefCooldownDays.present
          ? data.beefCooldownDays.value
          : this.beefCooldownDays,
      fishCooldownDays: data.fishCooldownDays.present
          ? data.fishCooldownDays.value
          : this.fishCooldownDays,
      meatlessCooldownDays: data.meatlessCooldownDays.present
          ? data.meatlessCooldownDays.value
          : this.meatlessCooldownDays,
      preventRepeatProtein: data.preventRepeatProtein.present
          ? data.preventRepeatProtein.value
          : this.preventRepeatProtein,
      preventRepeatCarbs: data.preventRepeatCarbs.present
          ? data.preventRepeatCarbs.value
          : this.preventRepeatCarbs,
      notificationHour: data.notificationHour.present
          ? data.notificationHour.value
          : this.notificationHour,
      notificationMinute: data.notificationMinute.present
          ? data.notificationMinute.value
          : this.notificationMinute,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      language: data.language.present ? data.language.value : this.language,
      isFirstRun: data.isFirstRun.present
          ? data.isFirstRun.value
          : this.isFirstRun,
      userName: data.userName.present ? data.userName.value : this.userName,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      userGender: data.userGender.present
          ? data.userGender.value
          : this.userGender,
      userAvatar: data.userAvatar.present
          ? data.userAvatar.value
          : this.userAvatar,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsData(')
          ..write('id: $id, ')
          ..write('cooldownDays: $cooldownDays, ')
          ..write('chickenCooldownDays: $chickenCooldownDays, ')
          ..write('beefCooldownDays: $beefCooldownDays, ')
          ..write('fishCooldownDays: $fishCooldownDays, ')
          ..write('meatlessCooldownDays: $meatlessCooldownDays, ')
          ..write('preventRepeatProtein: $preventRepeatProtein, ')
          ..write('preventRepeatCarbs: $preventRepeatCarbs, ')
          ..write('notificationHour: $notificationHour, ')
          ..write('notificationMinute: $notificationMinute, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('themeMode: $themeMode, ')
          ..write('language: $language, ')
          ..write('isFirstRun: $isFirstRun, ')
          ..write('userName: $userName, ')
          ..write('userEmail: $userEmail, ')
          ..write('userGender: $userGender, ')
          ..write('userAvatar: $userAvatar')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cooldownDays,
    chickenCooldownDays,
    beefCooldownDays,
    fishCooldownDays,
    meatlessCooldownDays,
    preventRepeatProtein,
    preventRepeatCarbs,
    notificationHour,
    notificationMinute,
    notificationsEnabled,
    themeMode,
    language,
    isFirstRun,
    userName,
    userEmail,
    userGender,
    userAvatar,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsData &&
          other.id == this.id &&
          other.cooldownDays == this.cooldownDays &&
          other.chickenCooldownDays == this.chickenCooldownDays &&
          other.beefCooldownDays == this.beefCooldownDays &&
          other.fishCooldownDays == this.fishCooldownDays &&
          other.meatlessCooldownDays == this.meatlessCooldownDays &&
          other.preventRepeatProtein == this.preventRepeatProtein &&
          other.preventRepeatCarbs == this.preventRepeatCarbs &&
          other.notificationHour == this.notificationHour &&
          other.notificationMinute == this.notificationMinute &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.themeMode == this.themeMode &&
          other.language == this.language &&
          other.isFirstRun == this.isFirstRun &&
          other.userName == this.userName &&
          other.userEmail == this.userEmail &&
          other.userGender == this.userGender &&
          other.userAvatar == this.userAvatar);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingsData> {
  final Value<int> id;
  final Value<int> cooldownDays;
  final Value<int> chickenCooldownDays;
  final Value<int> beefCooldownDays;
  final Value<int> fishCooldownDays;
  final Value<int> meatlessCooldownDays;
  final Value<bool> preventRepeatProtein;
  final Value<bool> preventRepeatCarbs;
  final Value<int> notificationHour;
  final Value<int> notificationMinute;
  final Value<bool> notificationsEnabled;
  final Value<AppThemeModePreference> themeMode;
  final Value<AppLanguagePreference> language;
  final Value<bool> isFirstRun;
  final Value<String?> userName;
  final Value<String?> userEmail;
  final Value<String?> userGender;
  final Value<String?> userAvatar;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.cooldownDays = const Value.absent(),
    this.chickenCooldownDays = const Value.absent(),
    this.beefCooldownDays = const Value.absent(),
    this.fishCooldownDays = const Value.absent(),
    this.meatlessCooldownDays = const Value.absent(),
    this.preventRepeatProtein = const Value.absent(),
    this.preventRepeatCarbs = const Value.absent(),
    this.notificationHour = const Value.absent(),
    this.notificationMinute = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.language = const Value.absent(),
    this.isFirstRun = const Value.absent(),
    this.userName = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.userGender = const Value.absent(),
    this.userAvatar = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.cooldownDays = const Value.absent(),
    this.chickenCooldownDays = const Value.absent(),
    this.beefCooldownDays = const Value.absent(),
    this.fishCooldownDays = const Value.absent(),
    this.meatlessCooldownDays = const Value.absent(),
    this.preventRepeatProtein = const Value.absent(),
    this.preventRepeatCarbs = const Value.absent(),
    this.notificationHour = const Value.absent(),
    this.notificationMinute = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.language = const Value.absent(),
    this.isFirstRun = const Value.absent(),
    this.userName = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.userGender = const Value.absent(),
    this.userAvatar = const Value.absent(),
  });
  static Insertable<AppSettingsData> custom({
    Expression<int>? id,
    Expression<int>? cooldownDays,
    Expression<int>? chickenCooldownDays,
    Expression<int>? beefCooldownDays,
    Expression<int>? fishCooldownDays,
    Expression<int>? meatlessCooldownDays,
    Expression<bool>? preventRepeatProtein,
    Expression<bool>? preventRepeatCarbs,
    Expression<int>? notificationHour,
    Expression<int>? notificationMinute,
    Expression<bool>? notificationsEnabled,
    Expression<String>? themeMode,
    Expression<String>? language,
    Expression<bool>? isFirstRun,
    Expression<String>? userName,
    Expression<String>? userEmail,
    Expression<String>? userGender,
    Expression<String>? userAvatar,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cooldownDays != null) 'cooldown_days': cooldownDays,
      if (chickenCooldownDays != null)
        'chicken_cooldown_days': chickenCooldownDays,
      if (beefCooldownDays != null) 'beef_cooldown_days': beefCooldownDays,
      if (fishCooldownDays != null) 'fish_cooldown_days': fishCooldownDays,
      if (meatlessCooldownDays != null)
        'meatless_cooldown_days': meatlessCooldownDays,
      if (preventRepeatProtein != null)
        'prevent_repeat_protein': preventRepeatProtein,
      if (preventRepeatCarbs != null)
        'prevent_repeat_carbs': preventRepeatCarbs,
      if (notificationHour != null) 'notification_hour': notificationHour,
      if (notificationMinute != null) 'notification_minute': notificationMinute,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (themeMode != null) 'theme_mode': themeMode,
      if (language != null) 'language': language,
      if (isFirstRun != null) 'is_first_run': isFirstRun,
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      if (userGender != null) 'user_gender': userGender,
      if (userAvatar != null) 'user_avatar': userAvatar,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? cooldownDays,
    Value<int>? chickenCooldownDays,
    Value<int>? beefCooldownDays,
    Value<int>? fishCooldownDays,
    Value<int>? meatlessCooldownDays,
    Value<bool>? preventRepeatProtein,
    Value<bool>? preventRepeatCarbs,
    Value<int>? notificationHour,
    Value<int>? notificationMinute,
    Value<bool>? notificationsEnabled,
    Value<AppThemeModePreference>? themeMode,
    Value<AppLanguagePreference>? language,
    Value<bool>? isFirstRun,
    Value<String?>? userName,
    Value<String?>? userEmail,
    Value<String?>? userGender,
    Value<String?>? userAvatar,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      cooldownDays: cooldownDays ?? this.cooldownDays,
      chickenCooldownDays: chickenCooldownDays ?? this.chickenCooldownDays,
      beefCooldownDays: beefCooldownDays ?? this.beefCooldownDays,
      fishCooldownDays: fishCooldownDays ?? this.fishCooldownDays,
      meatlessCooldownDays: meatlessCooldownDays ?? this.meatlessCooldownDays,
      preventRepeatProtein: preventRepeatProtein ?? this.preventRepeatProtein,
      preventRepeatCarbs: preventRepeatCarbs ?? this.preventRepeatCarbs,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      isFirstRun: isFirstRun ?? this.isFirstRun,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userGender: userGender ?? this.userGender,
      userAvatar: userAvatar ?? this.userAvatar,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cooldownDays.present) {
      map['cooldown_days'] = Variable<int>(cooldownDays.value);
    }
    if (chickenCooldownDays.present) {
      map['chicken_cooldown_days'] = Variable<int>(chickenCooldownDays.value);
    }
    if (beefCooldownDays.present) {
      map['beef_cooldown_days'] = Variable<int>(beefCooldownDays.value);
    }
    if (fishCooldownDays.present) {
      map['fish_cooldown_days'] = Variable<int>(fishCooldownDays.value);
    }
    if (meatlessCooldownDays.present) {
      map['meatless_cooldown_days'] = Variable<int>(meatlessCooldownDays.value);
    }
    if (preventRepeatProtein.present) {
      map['prevent_repeat_protein'] = Variable<bool>(
        preventRepeatProtein.value,
      );
    }
    if (preventRepeatCarbs.present) {
      map['prevent_repeat_carbs'] = Variable<bool>(preventRepeatCarbs.value);
    }
    if (notificationHour.present) {
      map['notification_hour'] = Variable<int>(notificationHour.value);
    }
    if (notificationMinute.present) {
      map['notification_minute'] = Variable<int>(notificationMinute.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(
        $AppSettingsTable.$converterthemeMode.toSql(themeMode.value),
      );
    }
    if (language.present) {
      map['language'] = Variable<String>(
        $AppSettingsTable.$converterlanguage.toSql(language.value),
      );
    }
    if (isFirstRun.present) {
      map['is_first_run'] = Variable<bool>(isFirstRun.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
    }
    if (userGender.present) {
      map['user_gender'] = Variable<String>(userGender.value);
    }
    if (userAvatar.present) {
      map['user_avatar'] = Variable<String>(userAvatar.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('cooldownDays: $cooldownDays, ')
          ..write('chickenCooldownDays: $chickenCooldownDays, ')
          ..write('beefCooldownDays: $beefCooldownDays, ')
          ..write('fishCooldownDays: $fishCooldownDays, ')
          ..write('meatlessCooldownDays: $meatlessCooldownDays, ')
          ..write('preventRepeatProtein: $preventRepeatProtein, ')
          ..write('preventRepeatCarbs: $preventRepeatCarbs, ')
          ..write('notificationHour: $notificationHour, ')
          ..write('notificationMinute: $notificationMinute, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('themeMode: $themeMode, ')
          ..write('language: $language, ')
          ..write('isFirstRun: $isFirstRun, ')
          ..write('userName: $userName, ')
          ..write('userEmail: $userEmail, ')
          ..write('userGender: $userGender, ')
          ..write('userAvatar: $userAvatar')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $MealHistoryTable mealHistory = $MealHistoryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final MealsDao mealsDao = MealsDao(this as AppDatabase);
  late final MealHistoryDao mealHistoryDao = MealHistoryDao(
    this as AppDatabase,
  );
  late final AppSettingsDao appSettingsDao = AppSettingsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    meals,
    mealHistory,
    appSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_history', kind: UpdateKind.update)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$MealsTableCreateCompanionBuilder =
    MealsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> nameNormalized,
      Value<String?> photoPath,
      required ProteinType proteinType,
      required CarbsType carbsType,
      required MealCategory category,
      required int prepTime,
      Value<bool> isFridaySpecial,
      Value<bool> isBudgetFriendly,
      Value<bool> isFavorite,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> cloudId,
    });
typedef $$MealsTableUpdateCompanionBuilder =
    MealsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> nameNormalized,
      Value<String?> photoPath,
      Value<ProteinType> proteinType,
      Value<CarbsType> carbsType,
      Value<MealCategory> category,
      Value<int> prepTime,
      Value<bool> isFridaySpecial,
      Value<bool> isBudgetFriendly,
      Value<bool> isFavorite,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> cloudId,
    });

final class $$MealsTableReferences
    extends BaseReferences<_$AppDatabase, $MealsTable, Meal> {
  $$MealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealHistoryTable, List<MealHistoryData>>
  _mealHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealHistory,
    aliasName: $_aliasNameGenerator(db.meals.id, db.mealHistory.mealId),
  );

  $$MealHistoryTableProcessedTableManager get mealHistoryRefs {
    final manager = $$MealHistoryTableTableManager(
      $_db,
      $_db.mealHistory,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProteinType, ProteinType, String>
  get proteinType => $composableBuilder(
    column: $table.proteinType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CarbsType, CarbsType, String> get carbsType =>
      $composableBuilder(
        column: $table.carbsType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MealCategory, MealCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get prepTime => $composableBuilder(
    column: $table.prepTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFridaySpecial => $composableBuilder(
    column: $table.isFridaySpecial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBudgetFriendly => $composableBuilder(
    column: $table.isBudgetFriendly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealHistoryRefs(
    Expression<bool> Function($$MealHistoryTableFilterComposer f) f,
  ) {
    final $$MealHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealHistory,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealHistoryTableFilterComposer(
            $db: $db,
            $table: $db.mealHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proteinType => $composableBuilder(
    column: $table.proteinType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carbsType => $composableBuilder(
    column: $table.carbsType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prepTime => $composableBuilder(
    column: $table.prepTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFridaySpecial => $composableBuilder(
    column: $table.isFridaySpecial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBudgetFriendly => $composableBuilder(
    column: $table.isBudgetFriendly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProteinType, String> get proteinType =>
      $composableBuilder(
        column: $table.proteinType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CarbsType, String> get carbsType =>
      $composableBuilder(column: $table.carbsType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MealCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get prepTime =>
      $composableBuilder(column: $table.prepTime, builder: (column) => column);

  GeneratedColumn<bool> get isFridaySpecial => $composableBuilder(
    column: $table.isFridaySpecial,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBudgetFriendly => $composableBuilder(
    column: $table.isBudgetFriendly,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  Expression<T> mealHistoryRefs<T extends Object>(
    Expression<T> Function($$MealHistoryTableAnnotationComposer a) f,
  ) {
    final $$MealHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealHistory,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.mealHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealsTable,
          Meal,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (Meal, $$MealsTableReferences),
          Meal,
          PrefetchHooks Function({bool mealHistoryRefs})
        > {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nameNormalized = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<ProteinType> proteinType = const Value.absent(),
                Value<CarbsType> carbsType = const Value.absent(),
                Value<MealCategory> category = const Value.absent(),
                Value<int> prepTime = const Value.absent(),
                Value<bool> isFridaySpecial = const Value.absent(),
                Value<bool> isBudgetFriendly = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => MealsCompanion(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                photoPath: photoPath,
                proteinType: proteinType,
                carbsType: carbsType,
                category: category,
                prepTime: prepTime,
                isFridaySpecial: isFridaySpecial,
                isBudgetFriendly: isBudgetFriendly,
                isFavorite: isFavorite,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cloudId: cloudId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> nameNormalized = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                required ProteinType proteinType,
                required CarbsType carbsType,
                required MealCategory category,
                required int prepTime,
                Value<bool> isFridaySpecial = const Value.absent(),
                Value<bool> isBudgetFriendly = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => MealsCompanion.insert(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                photoPath: photoPath,
                proteinType: proteinType,
                carbsType: carbsType,
                category: category,
                prepTime: prepTime,
                isFridaySpecial: isFridaySpecial,
                isBudgetFriendly: isBudgetFriendly,
                isFavorite: isFavorite,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cloudId: cloudId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MealsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({mealHistoryRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mealHistoryRefs) db.mealHistory],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mealHistoryRefs)
                    await $_getPrefetchedData<
                      Meal,
                      $MealsTable,
                      MealHistoryData
                    >(
                      currentTable: table,
                      referencedTable: $$MealsTableReferences
                          ._mealHistoryRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MealsTableReferences(db, table, p0).mealHistoryRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mealId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealsTable,
      Meal,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (Meal, $$MealsTableReferences),
      Meal,
      PrefetchHooks Function({bool mealHistoryRefs})
    >;
typedef $$MealHistoryTableCreateCompanionBuilder =
    MealHistoryCompanion Function({
      Value<int> id,
      Value<int?> mealId,
      required String mealName,
      required ProteinType proteinType,
      required CarbsType carbsType,
      required DateTime cookedAt,
      Value<MealEntryType> entryType,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$MealHistoryTableUpdateCompanionBuilder =
    MealHistoryCompanion Function({
      Value<int> id,
      Value<int?> mealId,
      Value<String> mealName,
      Value<ProteinType> proteinType,
      Value<CarbsType> carbsType,
      Value<DateTime> cookedAt,
      Value<MealEntryType> entryType,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

final class $$MealHistoryTableReferences
    extends BaseReferences<_$AppDatabase, $MealHistoryTable, MealHistoryData> {
  $$MealHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealsTable _mealIdTable(_$AppDatabase db) => db.meals.createAlias(
    $_aliasNameGenerator(db.mealHistory.mealId, db.meals.id),
  );

  $$MealsTableProcessedTableManager? get mealId {
    final $_column = $_itemColumn<int>('meal_id');
    if ($_column == null) return null;
    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $MealHistoryTable> {
  $$MealHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealName => $composableBuilder(
    column: $table.mealName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProteinType, ProteinType, String>
  get proteinType => $composableBuilder(
    column: $table.proteinType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CarbsType, CarbsType, String> get carbsType =>
      $composableBuilder(
        column: $table.carbsType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get cookedAt => $composableBuilder(
    column: $table.cookedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MealEntryType, MealEntryType, String>
  get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $MealHistoryTable> {
  $$MealHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealName => $composableBuilder(
    column: $table.mealName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proteinType => $composableBuilder(
    column: $table.proteinType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carbsType => $composableBuilder(
    column: $table.carbsType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cookedAt => $composableBuilder(
    column: $table.cookedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealHistoryTable> {
  $$MealHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mealName =>
      $composableBuilder(column: $table.mealName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProteinType, String> get proteinType =>
      $composableBuilder(
        column: $table.proteinType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CarbsType, String> get carbsType =>
      $composableBuilder(column: $table.carbsType, builder: (column) => column);

  GeneratedColumn<DateTime> get cookedAt =>
      $composableBuilder(column: $table.cookedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MealEntryType, String> get entryType =>
      $composableBuilder(column: $table.entryType, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealHistoryTable,
          MealHistoryData,
          $$MealHistoryTableFilterComposer,
          $$MealHistoryTableOrderingComposer,
          $$MealHistoryTableAnnotationComposer,
          $$MealHistoryTableCreateCompanionBuilder,
          $$MealHistoryTableUpdateCompanionBuilder,
          (MealHistoryData, $$MealHistoryTableReferences),
          MealHistoryData,
          PrefetchHooks Function({bool mealId})
        > {
  $$MealHistoryTableTableManager(_$AppDatabase db, $MealHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> mealId = const Value.absent(),
                Value<String> mealName = const Value.absent(),
                Value<ProteinType> proteinType = const Value.absent(),
                Value<CarbsType> carbsType = const Value.absent(),
                Value<DateTime> cookedAt = const Value.absent(),
                Value<MealEntryType> entryType = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MealHistoryCompanion(
                id: id,
                mealId: mealId,
                mealName: mealName,
                proteinType: proteinType,
                carbsType: carbsType,
                cookedAt: cookedAt,
                entryType: entryType,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> mealId = const Value.absent(),
                required String mealName,
                required ProteinType proteinType,
                required CarbsType carbsType,
                required DateTime cookedAt,
                Value<MealEntryType> entryType = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MealHistoryCompanion.insert(
                id: id,
                mealId: mealId,
                mealName: mealName,
                proteinType: proteinType,
                carbsType: carbsType,
                cookedAt: cookedAt,
                entryType: entryType,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MealHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mealId,
                                referencedTable: $$MealHistoryTableReferences
                                    ._mealIdTable(db),
                                referencedColumn: $$MealHistoryTableReferences
                                    ._mealIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MealHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealHistoryTable,
      MealHistoryData,
      $$MealHistoryTableFilterComposer,
      $$MealHistoryTableOrderingComposer,
      $$MealHistoryTableAnnotationComposer,
      $$MealHistoryTableCreateCompanionBuilder,
      $$MealHistoryTableUpdateCompanionBuilder,
      (MealHistoryData, $$MealHistoryTableReferences),
      MealHistoryData,
      PrefetchHooks Function({bool mealId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<int> cooldownDays,
      Value<int> chickenCooldownDays,
      Value<int> beefCooldownDays,
      Value<int> fishCooldownDays,
      Value<int> meatlessCooldownDays,
      Value<bool> preventRepeatProtein,
      Value<bool> preventRepeatCarbs,
      Value<int> notificationHour,
      Value<int> notificationMinute,
      Value<bool> notificationsEnabled,
      Value<AppThemeModePreference> themeMode,
      Value<AppLanguagePreference> language,
      Value<bool> isFirstRun,
      Value<String?> userName,
      Value<String?> userEmail,
      Value<String?> userGender,
      Value<String?> userAvatar,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<int> cooldownDays,
      Value<int> chickenCooldownDays,
      Value<int> beefCooldownDays,
      Value<int> fishCooldownDays,
      Value<int> meatlessCooldownDays,
      Value<bool> preventRepeatProtein,
      Value<bool> preventRepeatCarbs,
      Value<int> notificationHour,
      Value<int> notificationMinute,
      Value<bool> notificationsEnabled,
      Value<AppThemeModePreference> themeMode,
      Value<AppLanguagePreference> language,
      Value<bool> isFirstRun,
      Value<String?> userName,
      Value<String?> userEmail,
      Value<String?> userGender,
      Value<String?> userAvatar,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cooldownDays => $composableBuilder(
    column: $table.cooldownDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chickenCooldownDays => $composableBuilder(
    column: $table.chickenCooldownDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beefCooldownDays => $composableBuilder(
    column: $table.beefCooldownDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fishCooldownDays => $composableBuilder(
    column: $table.fishCooldownDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meatlessCooldownDays => $composableBuilder(
    column: $table.meatlessCooldownDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get preventRepeatProtein => $composableBuilder(
    column: $table.preventRepeatProtein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get preventRepeatCarbs => $composableBuilder(
    column: $table.preventRepeatCarbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AppThemeModePreference,
    AppThemeModePreference,
    String
  >
  get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AppLanguagePreference,
    AppLanguagePreference,
    String
  >
  get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isFirstRun => $composableBuilder(
    column: $table.isFirstRun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userGender => $composableBuilder(
    column: $table.userGender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAvatar => $composableBuilder(
    column: $table.userAvatar,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cooldownDays => $composableBuilder(
    column: $table.cooldownDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chickenCooldownDays => $composableBuilder(
    column: $table.chickenCooldownDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beefCooldownDays => $composableBuilder(
    column: $table.beefCooldownDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fishCooldownDays => $composableBuilder(
    column: $table.fishCooldownDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meatlessCooldownDays => $composableBuilder(
    column: $table.meatlessCooldownDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get preventRepeatProtein => $composableBuilder(
    column: $table.preventRepeatProtein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get preventRepeatCarbs => $composableBuilder(
    column: $table.preventRepeatCarbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFirstRun => $composableBuilder(
    column: $table.isFirstRun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userGender => $composableBuilder(
    column: $table.userGender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAvatar => $composableBuilder(
    column: $table.userAvatar,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cooldownDays => $composableBuilder(
    column: $table.cooldownDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chickenCooldownDays => $composableBuilder(
    column: $table.chickenCooldownDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get beefCooldownDays => $composableBuilder(
    column: $table.beefCooldownDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fishCooldownDays => $composableBuilder(
    column: $table.fishCooldownDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get meatlessCooldownDays => $composableBuilder(
    column: $table.meatlessCooldownDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get preventRepeatProtein => $composableBuilder(
    column: $table.preventRepeatProtein,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get preventRepeatCarbs => $composableBuilder(
    column: $table.preventRepeatCarbs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AppThemeModePreference, String>
  get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AppLanguagePreference, String>
  get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<bool> get isFirstRun => $composableBuilder(
    column: $table.isFirstRun,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

  GeneratedColumn<String> get userGender => $composableBuilder(
    column: $table.userGender,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userAvatar => $composableBuilder(
    column: $table.userAvatar,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingsData,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingsData,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsData>,
          ),
          AppSettingsData,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cooldownDays = const Value.absent(),
                Value<int> chickenCooldownDays = const Value.absent(),
                Value<int> beefCooldownDays = const Value.absent(),
                Value<int> fishCooldownDays = const Value.absent(),
                Value<int> meatlessCooldownDays = const Value.absent(),
                Value<bool> preventRepeatProtein = const Value.absent(),
                Value<bool> preventRepeatCarbs = const Value.absent(),
                Value<int> notificationHour = const Value.absent(),
                Value<int> notificationMinute = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<AppThemeModePreference> themeMode = const Value.absent(),
                Value<AppLanguagePreference> language = const Value.absent(),
                Value<bool> isFirstRun = const Value.absent(),
                Value<String?> userName = const Value.absent(),
                Value<String?> userEmail = const Value.absent(),
                Value<String?> userGender = const Value.absent(),
                Value<String?> userAvatar = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                cooldownDays: cooldownDays,
                chickenCooldownDays: chickenCooldownDays,
                beefCooldownDays: beefCooldownDays,
                fishCooldownDays: fishCooldownDays,
                meatlessCooldownDays: meatlessCooldownDays,
                preventRepeatProtein: preventRepeatProtein,
                preventRepeatCarbs: preventRepeatCarbs,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                notificationsEnabled: notificationsEnabled,
                themeMode: themeMode,
                language: language,
                isFirstRun: isFirstRun,
                userName: userName,
                userEmail: userEmail,
                userGender: userGender,
                userAvatar: userAvatar,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cooldownDays = const Value.absent(),
                Value<int> chickenCooldownDays = const Value.absent(),
                Value<int> beefCooldownDays = const Value.absent(),
                Value<int> fishCooldownDays = const Value.absent(),
                Value<int> meatlessCooldownDays = const Value.absent(),
                Value<bool> preventRepeatProtein = const Value.absent(),
                Value<bool> preventRepeatCarbs = const Value.absent(),
                Value<int> notificationHour = const Value.absent(),
                Value<int> notificationMinute = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<AppThemeModePreference> themeMode = const Value.absent(),
                Value<AppLanguagePreference> language = const Value.absent(),
                Value<bool> isFirstRun = const Value.absent(),
                Value<String?> userName = const Value.absent(),
                Value<String?> userEmail = const Value.absent(),
                Value<String?> userGender = const Value.absent(),
                Value<String?> userAvatar = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                cooldownDays: cooldownDays,
                chickenCooldownDays: chickenCooldownDays,
                beefCooldownDays: beefCooldownDays,
                fishCooldownDays: fishCooldownDays,
                meatlessCooldownDays: meatlessCooldownDays,
                preventRepeatProtein: preventRepeatProtein,
                preventRepeatCarbs: preventRepeatCarbs,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                notificationsEnabled: notificationsEnabled,
                themeMode: themeMode,
                language: language,
                isFirstRun: isFirstRun,
                userName: userName,
                userEmail: userEmail,
                userGender: userGender,
                userAvatar: userAvatar,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingsData,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingsData,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsData>,
      ),
      AppSettingsData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$MealHistoryTableTableManager get mealHistory =>
      $$MealHistoryTableTableManager(_db, _db.mealHistory);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
