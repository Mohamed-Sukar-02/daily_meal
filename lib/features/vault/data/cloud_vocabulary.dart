import '../../../core/database/app_database.dart';

/// The single owner of the local ↔ cloud tag vocabulary.
///
/// The cloud schema (see `CloudMeal` and `firestore.rules::isValidStagingMeal`)
/// is *narrower* than the local Drift enums, so every value has to map into the
/// allowed set:
///   protein:  chicken | beef | fish | meatless | other
///   carbs:    rice | pasta | bread | none
///   category: tabeekh | casserole | dry_sandwich | popular | seafood |
///             soup_stew | vegetarian
///
/// Both directions used to live in two files — the upload mapping in
/// `meal_proposal_service.dart`, the download mapping in
/// `discovery_providers.dart` — and the space between them is where the bugs
/// were: `cloud_category_mapper_test.dart` exists precisely because a stale
/// download map made freshly synced meals report a phantom change forever. This
/// file is the merge; nothing else may hand-roll a token.
///
/// The mapping is **lossy in one direction only**, and the lossy axes are the
/// ones a diff must never look at:
///  * `dairy` and `none` both upload as `other`, which downloads back as `none`;
///  * `potato` and `grains` both upload as `none`, which downloads as
///    `CarbsType.none` — and that is not cosmetic, because protein `none` falls
///    under the meatless cooldown window rather than the global one.
/// So [proteinWouldFoldAway] / [carbsWouldFoldAway] exist: they are what the
/// sync diff and the "update from cloud" write both ask before touching an axis.
class MealCloudVocabulary {
  const MealCloudVocabulary._();

  // ---------------------------------------------------------------------------
  // local → cloud (upload / staging payload)
  // ---------------------------------------------------------------------------

  /// `legume` is the cloud's `meatless`; `dairy` and `none` have no cloud
  /// counterpart and fold into `other`, which downloads back as `none`.
  static String proteinToCloud(ProteinType protein) {
    switch (protein) {
      case ProteinType.chicken:
        return 'chicken';
      case ProteinType.beef:
        return 'beef';
      case ProteinType.fish:
        return 'fish';
      case ProteinType.legume:
        return 'meatless';
      case ProteinType.dairy:
      case ProteinType.none:
        return 'other';
    }
  }

  /// The cloud knows only rice/pasta/bread; potato & grains fold into `none`
  /// (the honest fallback — claiming bread or rice would mislabel the meal).
  static String carbsToCloud(CarbsType carbs) {
    switch (carbs) {
      case CarbsType.rice:
        return 'rice';
      case CarbsType.pasta:
        return 'pasta';
      case CarbsType.bread:
        return 'bread';
      case CarbsType.potato:
      case CarbsType.grains:
      case CarbsType.none:
        return 'none';
    }
  }

  /// Every local category has its own cloud token, so an upload lands back on
  /// the enum it started from. `popular` stays cloud-only — admins use it as a
  /// catch-all and it downloads as `egyptianTraditional`; the client never
  /// writes it.
  static String categoryToCloud(MealCategory category) {
    switch (category) {
      case MealCategory.egyptianTraditional:
        return 'tabeekh';
      case MealCategory.ovenBaked:
        return 'casserole';
      case MealCategory.fastFood:
        return 'dry_sandwich';
      case MealCategory.seafood:
        return 'seafood';
      case MealCategory.soupStew:
        return 'soup_stew';
      case MealCategory.vegetarian:
        return 'vegetarian';
    }
  }

  // ---------------------------------------------------------------------------
  // cloud → local (download, sync diff, cloud-shaped view of a meal)
  // ---------------------------------------------------------------------------

  static ProteinType proteinFromCloud(String token) {
    switch (token) {
      case 'chicken':
        return ProteinType.chicken;
      case 'beef':
        return ProteinType.beef;
      case 'fish':
        return ProteinType.fish;
      case 'meatless':
        return ProteinType.legume;
      default:
        return ProteinType.none;
    }
  }

  static CarbsType carbsFromCloud(String token) {
    switch (token) {
      case 'rice':
        return CarbsType.rice;
      case 'pasta':
        return CarbsType.pasta;
      case 'bread':
        return CarbsType.bread;
      default:
        return CarbsType.none;
    }
  }

  static MealCategory categoryFromCloud(String token) {
    switch (token) {
      case 'tabeekh':
        return MealCategory.egyptianTraditional;
      case 'casserole':
        return MealCategory.ovenBaked;
      case 'dry_sandwich':
        return MealCategory.fastFood;
      case 'seafood':
        return MealCategory.seafood;
      case 'soup_stew':
        return MealCategory.soupStew;
      case 'vegetarian':
        return MealCategory.vegetarian;
      default:
        return MealCategory.egyptianTraditional;
    }
  }

  // ---------------------------------------------------------------------------
  // The lossy axes
  // ---------------------------------------------------------------------------

  /// True when [local] has no token of its own and is only ever represented by a
  /// fold (`other` for protein, `none` for carbs).
  static bool proteinWouldFoldAway(ProteinType local) =>
      proteinFromCloud(proteinToCloud(local)) != local;

  static bool carbsWouldFoldAway(CarbsType local) =>
      carbsFromCloud(carbsToCloud(local)) != local;

  /// Whether the cloud row and the local row agree on one axis.
  ///
  /// The comparison happens in the cloud's own vocabulary: the local enum is
  /// folded to its token and matched against the stored token, so two local
  /// values that share a token (`dairy`/`none` → `other`, `potato`/`grains` →
  /// `none`) can never read as an edit nobody made. That matters because the
  /// diff is not just a badge — `isProposableAgainstCloud` is built on it, so a
  /// phantom difference keeps a meal looking "not yet proposed" and burns a slot
  /// of the daily staging quota, forever.
  ///
  /// When the stored token has no name in the local set at all (the admin-only
  /// `popular`, or any token added server-side later), there is nothing to fold
  /// to; the test then falls back to what downloading that token would write,
  /// which is the same question asked in the other direction.
  static bool _agree<T>({
    required String cloudToken,
    required T local,
    required String Function(T) toCloud,
    required T Function(String) fromCloud,
  }) {
    final tokenIsNamedLocally = toCloud(fromCloud(cloudToken)) == cloudToken;
    return tokenIsNamedLocally
        ? toCloud(local) == cloudToken
        : fromCloud(cloudToken) == local;
  }

  static bool sameCloudProtein(ProteinType local, String cloudToken) => _agree(
        cloudToken: cloudToken,
        local: local,
        toCloud: proteinToCloud,
        fromCloud: proteinFromCloud,
      );

  static bool sameCloudCarbs(CarbsType local, String cloudToken) => _agree(
        cloudToken: cloudToken,
        local: local,
        toCloud: carbsToCloud,
        fromCloud: carbsFromCloud,
      );

  static bool sameCloudCategory(MealCategory local, String cloudToken) => _agree(
        cloudToken: cloudToken,
        local: local,
        toCloud: categoryToCloud,
        fromCloud: categoryFromCloud,
      );

  /// Whether applying [cloudToken] to [local] would be a *silent* downgrade: the
  /// two agree in cloud terms — so the sync diff has nothing to show — yet the
  /// local row holds a distinction the cloud cannot name (`dairy` under `other`,
  /// `potato`/`grains` under `none`). Callers skip the axis when this is true:
  /// copying the fold would rewrite a tag the user never contested, and for
  /// protein that also moves the meal into a different cooldown window.
  static bool proteinFoldWouldDowngrade(ProteinType local, String cloudToken) =>
      sameCloudProtein(local, cloudToken) && proteinFromCloud(cloudToken) != local;

  static bool carbsFoldWouldDowngrade(CarbsType local, String cloudToken) =>
      sameCloudCarbs(local, cloudToken) && carbsFromCloud(cloudToken) != local;
}
