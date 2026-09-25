import 'package:flutter/material.dart';

/// Single source of truth for every user-facing string in the app.
///
/// Rules enforced across the codebase:
///  * No hardcoded Arabic/English literals in widgets — always go through here.
///  * Domain/data layers never embed display text; they expose stable keys or
///    enums and the UI maps them here (see [relaxationReason], [proteinLabel]…).
///  * The only exception is meal names coming from the database (`meal.name`),
///    which are user content, not UI copy.
class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('ar');
    return AppStrings(locale);
  }

  bool get isEn => locale.languageCode == 'en';

  // ===========================================================================
  // App shell & navigation
  // ===========================================================================
  String get appName => isEn ? 'Daily Meal' : 'أكلة النهاردة';
  String get appSubtitle => isEn
      ? 'Smart daily meal suggestions for your home'
      : 'اقتراحات يومية ذكية لوجبات البيت المصري';
  String get appTagline => isEn
      ? 'No more daily dilemmas… what are we eating?'
      : 'من غير حيرة كل يوم .. هناكل ايه؟';

  String get navHome => isEn ? 'Home' : 'الرئيسية';
  String get navVault => isEn ? 'Vault' : 'خزانة الأكلات';
  String get navHistory => isEn ? 'History' : 'السجل';
  String get navSettings => isEn ? 'Settings' : 'الإعدادات';

  // ===========================================================================
  // Common
  // ===========================================================================
  String get ok => isEn ? 'OK' : 'حسناً';
  String get cancel => isEn ? 'Cancel' : 'إلغاء';
  String get done => isEn ? 'Done' : 'تم';
  String get save => isEn ? 'Save' : 'حفظ';
  String get edit => isEn ? 'Edit' : 'تعديل';
  String get close => isEn ? 'Close' : 'إغلاق';
  String get retry => isEn ? 'Retry' : 'إعادة المحاولة';
  String get undo => isEn ? 'Undo' : 'تراجع';
  String get more => isEn ? 'More' : 'المزيد';
  String get encrypted => isEn ? 'Encrypted' : 'مشفر';
  String get loading => isEn ? 'Loading…' : 'جاري التحميل...';
  String get flagYes => isEn ? 'Yes' : 'نعم';
  String get flagNo => isEn ? 'No' : 'لا';
  String get am => isEn ? 'AM' : 'ص';
  String get pm => isEn ? 'PM' : 'م';
  String get pressAgainToExit => isEn ? 'Press again to exit' : 'اضغط مرة أخرى للخروج';

  String get errorOccurred => isEn ? 'An error occurred: ' : 'حدث خطأ: ';
  String errorGeneric(Object error) =>
      isEn ? 'An error occurred: $error' : 'حدث خطأ: $error';

  // Unsaved changes confirmation (shared by all edit surfaces)
  String get discardChangesTitle =>
      isEn ? 'Discard changes?' : 'تجاهل التعديلات؟';
  String get discardChangesMessage => isEn
      ? 'You have unsaved changes. Are you sure you want to leave and discard your edits?'
      : 'لديك تغييرات غير محفوظة، هل أنت متأكد من رغبتك في المغادرة وتجاهل ما قمت بتعديله؟';
  String get keepEditing => isEn ? 'Keep Editing' : 'متابعة التعديل';
  String get discardChanges => isEn ? 'Discard' : 'تجاهل التغييرات';

  String get today => isEn ? 'Today' : 'اليوم';
  String get yesterday => isEn ? 'Yesterday' : 'أمس';
  String get thisMonth => isEn ? 'This month' : 'هذا الشهر';
  String get earlier => isEn ? 'Earlier' : 'سابقاً';

  /// "12 minutes" with proper Arabic plural forms.
  String minutes(int minutes) {
    if (isEn) return minutes == 1 ? '1 minute' : '$minutes minutes';
    if (minutes == 1) return 'دقيقة واحدة';
    if (minutes == 2) return 'دقيقتان';
    if (minutes >= 3 && minutes <= 10) return '$minutes دقائق';
    return '$minutes دقيقة';
  }

  String daysText(int days) {
    if (isEn) return days == 1 ? '1 day' : '$days days';
    if (days == 1) return 'يوم واحد';
    if (days == 2) return 'يومان';
    if (days <= 10) return '$days أيام';
    return '$days يوماً';
  }

  String mealsCount(int count) {
    if (isEn) return count == 1 ? '1 meal' : '$count meals';
    if (count == 1) return 'أكلة واحدة';
    if (count == 2) return 'أكلتان';
    if (count >= 3 && count <= 10) return '$count أكلات';
    return '$count أكلة';
  }

  String daysAgo(int days) {
    if (isEn) return days == 1 ? 'Yesterday' : '$days days ago';
    if (days == 1) return 'أمس';
    if (days == 2) return 'منذ يومين';
    if (days >= 3 && days <= 10) return 'منذ $days أيام';
    return 'منذ $days يوماً';
  }

  String hoursAgo(int hours) {
    if (isEn) return hours == 1 ? 'An hour ago' : '$hours hours ago';
    if (hours == 1) return 'منذ ساعة';
    if (hours == 2) return 'منذ ساعتين';
    if (hours >= 3 && hours <= 10) return 'منذ $hours ساعات';
    return 'منذ $hours ساعة';
  }

  /// Localised weekday name for [DateTime.weekday] (1 = Monday … 7 = Sunday).
  String weekdayName(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    const arabic = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const english = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return isEn ? english[weekday - 1] : arabic[weekday - 1];
  }

  String get minutesAgo => isEn ? 'Minutes ago' : 'منذ دقائق';
  String get twoDaysAgo => isEn ? 'Two days ago' : 'منذ يومين';

  // ===========================================================================
  // Home screen
  // ===========================================================================
  String get refreshSuggestions => isEn ? 'Refresh Suggestions' : 'تحديث الاقتراحات';
  String get vaultEmpty => isEn ? 'Vault is empty!' : 'خزنة الأكلات فارغة!';
  String get vaultEmptyDesc => isEn
      ? 'Start by adding a meal or download suggestions.'
      : 'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.';
  String get addFirstMeal => isEn ? 'Add first meal' : 'أضف أكلتك الأولى';
  String get errorPreparing => isEn ? 'Error preparing suggestions' : 'حدث خطأ في تجهيز الاقتراحات';
  String get todaySuggestions => isEn
      ? 'Today\'s suggestions for you:'
      : 'اقتراحات النهاردة المختارة لك:';

  String greetingMorning(String name) =>
      isEn ? 'Good morning, $name ☀️' : 'صباح الفل والجمال يا $name ☀️';
  String greetingAfternoon(String name) =>
      isEn ? 'What to cook today, $name? 🍲' : 'أكلة النهاردة.. هنطبخ إيه يا $name؟ 🍲';
  String greetingEvening(String name) =>
      isEn ? 'Good evening, $name 🌙' : 'مساء الهنا والسرور يا $name 🌙';

  String get greetingMorningNoName => isEn ? 'Good morning ☀️' : 'صباح الفل والجمال ☀️';
  String get greetingAfternoonNoName => isEn ? 'What to cook today? 🍲' : 'أكلة النهاردة.. هنطبخ إيه؟ 🍲';
  String get greetingEveningNoName => isEn ? 'Good evening 🌙' : 'مساء الهنا والسرور 🌙';

  String get top3Balanced => isEn
      ? 'Selected best 3 balanced meals.'
      : 'اخترنا لك أفضل 3 وجبات متنوعة ومتوازنة.';
  String get spinWheel => isEn ? 'Spin the Wheel' : 'لف العجلة';
  String get spinNow => isEn ? 'Spin now' : 'لف العجلة';
  String get varietyAlert => isEn ? 'Variety Alert' : 'تنبيه التنوع الغذائي';
  String varietyAlertDetailed(int level, String reason) => isEn
      ? 'Variety alert (level $level): $reason'
      : 'تنبيه التنوع الغذائي (مستوى $level): $reason';

  String get cookedToday => isEn ? 'Cooked Today' : 'طبختها النهاردة';
  String get leftover => isEn ? 'Leftover' : 'بواقي أكل';
  String cookedSuccess(String mealName) => isEn
      ? 'Enjoy! "$mealName" added to history.'
      : 'بالهنا والشفا! تم تسجيل "$mealName" في السجل.';
  String cookedShort(String mealName) =>
      isEn ? 'Enjoy! "$mealName" logged' : 'بالهنا والشفا! تم تسجيل "$mealName"';
  String leftoverSuccess(String mealName) => isEn
      ? 'Logged leftover for "$mealName".'
      : 'تم تسجيل بواقي من "$mealName".';
  String get takeoutSuccess => isEn
      ? 'Logged takeout for today.'
      : 'تم تسجيل أكل من بره (هطلب من برا).';
  String get skippedSuccess => isEn
      ? 'Logged skipped meal.'
      : 'تم تسجيل تفويت وجبة الغداء.';
  String get notCookingToday => isEn ? 'Not cooking today?' : 'مش هتطبخ النهاردة؟';
  String get cookThis => 'Cook This';
  String get eatYesterdayLeftovers => isEn ? 'Eat yesterday\'s leftovers' : 'هاكل بواقي امبارح';
  String get orderTakeout => isEn ? 'Order takeout' : 'هطلب من برا';
  String get confirmRefreshTitle => isEn ? 'Change suggestions' : 'تغيير الاقتراحات';
  String get confirmRefreshMessage => isEn
      ? 'Are you sure you want to change the 3 current suggestions?'
      : 'هل أنت متأكد من تغيير الـ 3 اقتراحات الحالية؟';
  String get confirmRefreshConfirm => isEn ? 'Yes, change' : 'نعم، غيّرها';
  String get refreshNoNewSuggestions => isEn
      ? 'No new suggestions available today — these are still your best picks.'
      : 'مفيش اقتراحات جديدة متاحة النهارده — دي لسه أفضل ترشيحات ليك.';
  String refreshKeptSuggestions(int keptCount) {
    if (isEn) {
      return keptCount == 1
          ? 'One suggestion stayed the same — no better alternative is available today.'
          : '$keptCount suggestions stayed the same — no better alternatives are available today.';
    }
    switch (keptCount) {
      case 1:
        return 'اقتراح واحد فضل زي ما هو — مفيش بديل أنسب متاح النهارده.';
      case 2:
        return 'اقتراحين فضلوا زي ما هما — مفيش بدائل أنسب متاحة النهارده.';
      default:
        return '$keptCount اقتراحات فضلت زي ما هي — مفيش بدائل أنسب متاحة النهارده.';
    }
  }
  String get leftoverSuccessGeneral => isEn
      ? 'Done, but there is no record of yesterday\'s meal.'
      : 'تم ولكن لا يوجد سجل بأكلة أمس.';
  String get leftoverPrefix => isEn ? '(Leftovers)' : '(بقايا امبارح)';
  String get leftoverOnly => isEn ? 'Leftovers' : 'بقايا امبارح';

  String get mainDish => isEn ? 'Main Dish' : 'الطبق الرئيسي';
  String get sideDish1 => isEn ? 'Side Dish 1' : 'طبق جانبي ١';
  String get sideDish2 => isEn ? 'Side Dish 2' : 'طبق جانبي ٢';

  String get fridaySpecial => isEn ? 'Friday special' : 'أكلة جمعة';
  String get budgetFriendly => isEn ? 'Budget friendly' : 'اقتصادي';
  String get favorite => isEn ? 'Favorite' : 'مفضلة';
  String get mealFlagsLabel => isEn ? 'Meal options' : 'خيارات الوجبة';

  // Full meal screen (mockup-aligned)
  String get moreFavorites => isEn ? 'More Favorites' : 'مزيد من المفضلات';
  String get freshAndNatural => isEn ? 'Fresh & Natural' : 'طازج وطبيعي';
  String get healthyTag => isEn ? 'Healthy' : 'صحي';
  String get balancedTag => isEn ? 'Balanced' : 'متوازن';
  String get deliciousTag => isEn ? 'Delicious' : 'لذيذ';
  String prepMinutesShort(int minutes) => isEn ? '$minutes min' : '$minutes د';

  // Spin the wheel
  String get spinWheelTitle => isEn ? 'Wheel of Fortune' : 'عجلة الحظ';
  String get spinWheelTitleEmoji => isEn ? 'Wheel of Fortune 🎡' : 'عجلة الحظ 🎡';
  String get spinWheelNeedsTwo => isEn
      ? 'The wheel needs at least two suggested meals to spin!'
      : 'عجلة الحظ تحتاج إلى وجبتين على الأقل في الاقتراحات للتدوير!';
  String get spinWheelLandedOn => isEn
      ? '🎉 Today\'s meal landed on:'
      : '🎉 أكلة النهاردة وقعت على:';
  String get spinWheelStart => isEn ? 'Start spinning' : 'ابدأ التدوير';
  String get spinWheelAgain => isEn ? 'Spin again' : 'لف تاني';
  String get cookedThisOne => isEn ? 'Cook This' : 'هنطبخها النهاردة';
  String get wheelSpin => isEn ? 'Spin' : 'لف';
  String get wheelTheWheel => isEn ? 'the wheel' : 'العجلة';

  // ===========================================================================
  // Meal vault
  // ===========================================================================
  String get vaultTitle => isEn ? 'Meal Vault' : 'خزانة الأكلات';
  String get vaultSubtitle => isEn
      ? 'Save your favourite meals and cook them anytime 🧡'
      : 'احفظ أكلاتك المفضلة واطبخها في أي وقت 🧡';
  String get vaultSubtitleExplore => isEn
      ? 'Discover community recipes and explore new meal ideas 🌟'
      : 'استكشف وصفات المجتمع وأفكار أكلات جديدة 🌟';
  String get vaultAddIn10Seconds => isEn ? 'Add in\n10 seconds' : 'أضفها في\n10 ثواني بس';
  String get vaultSearchHint => isEn ? 'Search a meal by name…' : 'ابحث عن أكلة بالاسم...';
  String vaultLoadError(Object error) => isEn
      ? 'Failed to load meals: $error'
      : 'حدث خطأ في عرض الوجبات: $error';
  String get vaultTabMine => isEn ? 'My Vault' : 'خزانتي';
  String get vaultTabExplore => isEn ? 'Explore' : 'استكشاف';

  String vaultCloudCount(int count) => isEn ? '$count meals ☁️' : '$count أكلة ☁️';
  String vaultNewCount(int count) => isEn ? '$count new ✨' : '$count جديدة ✨';

  // Sync defaults icon (My Vault header)
  String get syncDefaultsTooltip =>
      isEn ? 'Sync default meals' : 'مزامنة الأكلات الافتراضية';
  String get syncingDefaults =>
      isEn ? 'Syncing default meals…' : 'جاري مزامنة الأكلات الافتراضية...';
  String get defaultsSynced =>
      isEn ? 'Default meals synced successfully' : 'تمت مزامنة الأكلات الافتراضية بنجاح';
  String get defaultsSyncFailed =>
      isEn ? 'Syncing default meals failed' : 'فشلت مزامنة الأكلات الافتراضية';
  String get syncOffline =>
      isEn ? 'You are offline. Cannot sync right now.' : 'أنت الآن في وضع عدم الاتصال.';
  String get syncUpToDate =>
      isEn ? 'Everything is up to date and synced.' : 'تمت المزامنة، كل شيء محدث.';

  // Sync window — opened from the meal screen when the cloud copy changed
  String get syncWindowCloudHint => isEn
      ? 'The cloud version has details yours does not — tap to review'
      : 'نسخة السحابة فيها تفاصيل مختلفة عن نسختك — اضغط للمراجعة';
  String get syncWindowTitle => isEn ? 'Sync window' : 'نافذة المزامنة';
  String get syncWindowMessage => isEn
      ? 'These details differ between your device and the cloud:'
      : 'التفاصيل دي مختلفة بين جهازك وبين السحابة:';
  String get syncWindowLocalColumn => isEn ? 'On my device' : 'عندي';
  String get syncWindowCloudColumn => isEn ? 'In the cloud' : 'في السحابة';
  String get syncStateSynced => isEn
      ? 'In sync with the cloud'
      : 'متزامن مع نسخة السحابة';
  String get syncWindowUpdate => isEn
      ? 'Update from cloud'
      : 'تحديث من السحابة';
  String get syncWindowKeep => isEn ? 'Keep my copy' : 'الإبقاء على نسختي';

  String get filterAll => isEn ? 'All' : 'الكل';
  String get filterQuick => isEn ? 'Quick 30m' : 'سريع 30م';

  /// My Vault: meals the user loved (the `Meal.isFavorite` flag).
  String get filterLoved => isEn ? 'Fav ❤️' : 'المفضلة ❤️';

  /// Explore: cloud meals that already have a copy in the local vault.
  String get filterSaved => isEn ? 'Saved 🔖' : 'مضافة 🔖';

  String get vaultNoResultsTitle => isEn ? 'No matching results' : 'لا توجد نتائج مطابقة';
  String get vaultNoResultsDesc => isEn
      ? 'We could not find meals matching your search or filters.'
      : 'لم نجد أكلات تطابق كلمات البحث أو الفلاتر المحددة.';
  String get vaultResetFilters => isEn ? 'Reset filters & search' : 'إعادة ضبط الفلاتر والبحث';

  // Delete meal dialog
  String get deleteMealTitle => isEn ? 'Delete meal' : 'حذف الأكلة';
  String deleteMealConfirm(String mealName) => isEn
      ? 'Are you sure you want to permanently delete "$mealName" from your vault?'
      : 'هل أنت متأكد من رغبتك في حذف "$mealName" نهائياً من خزانة الأكلات؟';
  String get deleteMealHistorySafe => isEn
      ? 'Your cooking log is safe: previous times you cooked this meal stay in history and will not be deleted.'
      : 'سجل الطبخ في أمان: سيتم الاحتفاظ بسجل المرات السابقة التي طبخت فيها هذه الأكلة ولن يُحذف من سجل الأكلات.';
  String mealDeletedWithHistory(String mealName) => isEn
      ? '"$mealName" deleted — its previous cooking log was kept'
      : 'تم حذف "$mealName" مع الاحتفاظ بسجل طبخها السابق';

  // Quick add / edit sheet
  String get photoAccessLimited => isEn ? 'Limited photo access' : 'الوصول للصور محدود';
  String get photoAccessLimitedDesc => isEn
      ? 'You can allow access to selected photos from Settings, or use the system photo picker.'
      : 'يمكنك السماح بالوصول لبعض الصور فقط من الإعدادات، أو استخدام منتقي الصور النظامي.';
  String get openSettings => isEn ? 'Open Settings' : 'فتح الإعدادات';
  String get cameraPermissionDenied => isEn ? 'Camera permission denied' : 'تم رفض إذن الكاميرا';
  String get cameraPermissionTitle => isEn ? 'Camera permission required' : 'إذن الكاميرا مطلوب';
  String get cameraPermissionDesc => isEn
      ? 'Please allow camera access from Settings to take a photo.'
      : 'يرجى السماح بالوصول للكاميرا من الإعدادات لالتقاط صورة.';
  String get photoCaptured => isEn ? 'Photo captured successfully' : 'تم التقاط الصورة بنجاح';
  String get photoPicked => isEn ? 'Photo selected successfully' : 'تم اختيار الصورة بنجاح';
  String imagePickError(String message) => isEn
      ? 'Error while picking an image: $message'
      : 'خطأ في اختيار الصورة: $message';
  String get chooseMealPhoto => isEn ? 'Choose meal photo' : 'اختر صورة الأكلة';
  String get takePhoto => isEn ? 'Take a photo' : 'التقاط صورة بالكاميرا';
  String get takePhotoDesc => isEn ? 'Use the camera to take a new photo' : 'استخدم الكاميرا لالتقاط صورة جديدة';
  String get pickFromGallery => isEn ? 'Choose from gallery' : 'اختيار من المعرض';
  String get pickFromGalleryDesc => isEn ? 'Pick a photo from your album' : 'اختر صورة من ألبوم الصور';
  String get removePhoto => isEn ? 'Remove photo' : 'إزالة الصورة';
  String get removePhotoDesc => isEn ? 'Delete the current photo' : 'حذف الصورة الحالية';
  String mealUpdated(String name) => isEn
      ? 'Meal "$name" updated successfully'
      : 'تم تعديل أكلة "$name" بنجاح';
  String mealAdded(String name) => isEn
      ? '"$name" added to your meal vault'
      : 'تمت إضافة "$name" إلى خزانة الأكلات';
  String saveError(Object error) => isEn
      ? 'Error while saving: $error'
      : 'حدث خطأ أثناء الحفظ: $error';
  String get mealNameRequired => isEn ? 'Please enter the meal name' : 'من فضلك أدخل اسم الأكلة';
  String get mealNameMinLength => isEn ? 'At least two characters' : 'حرفين على الأقل';
  String get carbsTypeLabel => isEn ? 'Carbs type' : 'نوع الكارب';
  String get proteinTypeLabel => isEn ? 'Protein type' : 'نوع البروتين';
  String get categoryShortLabel => isEn ? 'Category' : 'التصنيف';
  String get quickAddMealTitle => isEn ? 'Quick Add Meal' : 'إضافة أكلة سريعة';
  String get quickAddMealSubtitle => isEn
      ? 'Add a new meal to the community'
      : 'أضف أكلة جديدة للمجتمع';
  String get addPhoto => isEn ? 'Add Photo' : 'أضف صورة';
  String get mealNameLabel => isEn ? 'Meal Name' : 'اسم الأكلة';
  String get mealNameHint => isEn
      ? 'e.g. Grilled Chicken with Rice'
      : 'مثال: فراخ مشوية مع أرز';
  String get shortNameLabel => isEn ? 'Short name' : 'الاسم المختصر';
  String get mealNotesLabel => isEn
      ? 'Meal Notes or Recipe (Optional)'
      : 'ملاحظات أو وصفة الوجبة (اختياري)';
  String get mealNotesHint => isEn
      ? 'Write notes, ingredients, or preparation steps...'
      : 'اكتب ملاحظاتك، مقادير الأكلة، أو طريقة التحضير...';
  String get mealShortNameLabel => isEn
      ? 'Short Name (Optional)'
      : 'اسم مختصر (اختياري)';
  String get mealShortNameHint => isEn
      ? 'Short title shown in header (e.g. Bechamel)'
      : 'اسم مختصر يظهر بأعلى الشاشة (مثلاً: بشاميل)';
  String get timeLabel => isEn ? 'Time' : 'الوقت';
  String get carbsTypeShort => isEn ? 'Carb Type' : 'نوع الكارب';
  String get saveChanges => isEn ? 'Save Changes' : 'حفظ التعديلات';
  String get saveMeal => isEn ? 'Save Meal' : 'حفظ الأكلة';
  String get fieldRequired => isEn ? 'Required' : 'مطلوب';
  String get fieldInvalid => isEn ? 'Invalid value' : 'قيمة غير صحيحة';

  // ===========================================================================
  // Discovery / cloud meals
  // ===========================================================================
  String get discoveryTitle => isEn ? 'Discover' : 'استكشاف';
  String get discoverySearchHint => isEn
      ? 'Search for meals, cuisines, or ingredients…'
      : 'ابحث عن أكلات أو مطابخ أو مكونات...';
  String get discoveryTrending => isEn ? 'Trending' : 'الأكثر رواجاً';
  String get discoveryAdminPicks => isEn ? 'Admin Picks' : 'اختيارات الإدارة';
  String get discoveryQuickMeals => isEn ? 'Quick Meals' : 'وجبات سريعة';
  String get discoveryGlobal => isEn ? 'Global' : 'عالمي';
  String get discoveryOfflineTitle => isEn ? 'You are offline' : 'أنت غير متصل بالإنترنت';
  String get discoveryOfflineDesc => isEn
      ? 'Check your network connection to browse cloud recipes.'
      : 'تحقّق من اتصالك بالشبكة لمشاهدة الوصفات السحابية.';
  String get discoveryWifiTitle => isEn ? 'Wi-Fi connection required' : 'مطلوب اتصال Wi-Fi';
  String get discoveryWifiDesc => isEn
      ? 'You enabled the Wi-Fi-only download option.'
      : 'فعّلت خيار التحميل عبر الواي فاي فقط.';
  String get discoveryEmptyTitle => isEn ? 'No cloud recipes right now' : 'لا توجد وصفات سحابية حالياً';
  String get discoveryEmptyDesc => isEn
      ? 'Try again later or add your own recipes.'
      : 'جرّب لاحقاً أو أضف وصفاتك الخاصة.';
  String get discoveryNoResultsDesc => isEn
      ? 'Try different search words or change the filter.'
      : 'جرّب كلمات بحث مختلفة أو غيّر الفلتر.';
  String get discoveryError => isEn ? 'An error occurred' : 'حدث خطأ';
  String discoveryFetchFailed(Object error) => isEn
      ? 'Failed to fetch cloud meals: $error'
      : 'فشل جلب الأكلات السحابية: $error';
  String discoveryAddedBy(String users) => isEn
      ? 'Added by ${users}k users'
      : 'أضيفت من ${users}k مستخدم';
  String mealDownloaded(String name) => isEn ? 'Downloaded: $name' : 'تم تنزيل: $name';

  String get mealDownloadFailed => isEn ? 'Download failed' : 'فشل التنزيل';
  String mealUpdatedToast(String name) => isEn ? 'Updated: $name' : 'تم التحديث: $name';
  String mealAddedNewCopy(String name) => isEn
      ? 'A new copy was downloaded: $name'
      : 'تم تنزيل نسخة جديدة: $name';
  String get discoveryUpdate => isEn ? 'Update' : 'تحديث';
  String get discoveryDownload => isEn ? 'Download' : 'تنزيل';
  String get discoveryUpdateExistingTitle => isEn
      ? 'Update the existing meal'
      : 'تحديث الأكلة الموجودة';
  String get discoveryUpdateExistingDesc => isEn
      ? 'The meal data in your vault will be replaced with the new data.'
      : 'سيتم تحديث بيانات الأكلة في خزانتك بالبيانات الجديدة.';
  String get discoveryAddAsNewTitle => isEn ? 'Add as a new copy' : 'إضافة كنسخة جديدة';
  String get discoveryAddAsNewDesc => isEn
      ? 'This meal will be added as a new entry without deleting the old copy.'
      : 'سيتم إضافة هذه الأكلة كوجبة جديدة دون مسح النسخة القديمة.';

  // Meal details sheet
  String get savedInVault =>
      isEn ? 'Saved to your vault' : 'محفوظة في خزانتك';

  // Full meal screen
  String get mealDetailsTitle => isEn ? 'Meal details' : 'تفاصيل الأكلة';
  String get mealNotFound => isEn
      ? 'This meal is no longer in the vault'
      : 'هذه الأكلة لم تعد موجودة في الخزانة';
  String get fullDetails => isEn ? 'Full details' : 'التفاصيل الكاملة';
  String get notesLabel => isEn ? 'Notes' : 'ملاحظات';

  /// Tooltip of the app bar overflow button that carries the screen's local
  /// actions (edit · delete).
  String get mealScreenActionsMenu => isEn
      ? 'Meal actions'
      : 'إجراءات الأكلة';

  // Cloud Staging Export (propose a meal for the public cloud vault)
  String get proposalCta => isEn ? 'Propose to cloud' : 'اقتراح للسحابة';
  String get proposalInProgress => isEn ? 'Sending…' : 'جاري الإرسال...';
  String get proposalSuccess => isEn
      ? 'Sent for review — thank you!'
      : 'تم إرسال اقتراحك للمراجعة — شكراً!';
  String get proposalAlready => isEn
      ? 'Already proposed — edit the meal to send it again'
      : 'مُقترحة من قبل — عدّل الأكلة لإرسالها مرة أخرى';
  String get proposalInvalidName => isEn
      ? 'The meal name is too short to propose (2 letters minimum)'
      : 'اسم الأكلة قصير جداً للاقتراح (حرفان على الأقل)';
  String proposalDailyLimit(int limit) => isEn
      ? 'You reached the daily limit of $limit proposals — try again tomorrow'
      : 'وصلت للحد اليومي للاقتراحات ($limit) — حاول تاني بكرة';
  String get proposalUnchangedFromCloud => isEn
      ? 'This meal already matches its cloud copy — edit it to propose changes'
      : 'الأكلة مطابقة لنسختها في السحابة — عدّلها لاقتراح التغييرات';
  /// The public-vault pre-flight found this exact name already published
  /// (`ProposalOutcomeCode.alreadyInPublicVault`) — wording kept verbatim from
  /// the backlog item so the user reads the promise they were given.
  String get proposalAlreadyInPublicVault => isEn
      ? 'This meal is already available in the public vault 👏'
      : 'هذه الأكلة متوفرة بالفعل في الخزنة العامة 👏';
  String get proposalOffline => isEn
      ? 'No connection — your proposal was not sent'
      : 'لا يوجد اتصال — لم يتم إرسال الاقتراح';
  String get proposalWifiOnly => isEn
      ? 'Cloud is Wi-Fi-only right now — connect to Wi-Fi or change the setting'
      : 'السحابة على وضع الواي فاي فقط — اتصل بالواي فاي أو غيّر الإعداد';
  // Which stage rejected the proposal. Named after ProposalFailureReason so a
  // new reason cannot be added in the service layer without a label here.
  String get proposalFailFirebaseNotReady => isEn
      ? 'Firebase is not initialised in this build'
      : 'Firebase غير مهيّأ في هذا البناء';
  String get proposalFailAnonymousDisabled => isEn
      ? 'Anonymous sign-in is disabled in the Firebase console'
      : 'تسجيل الدخول المجهول مقفول من إعدادات Firebase';
  String get proposalFailAnonymousRejected => isEn
      ? 'Anonymous sign-in was rejected'
      : 'رُفض تسجيل الدخول المجهول';
  String get proposalFailSignInLost => isEn
      ? 'The anonymous sign-in expired — send the proposal again'
      : 'انتهت جلسة تسجيل الدخول المجهول — ابعت الاقتراح مرة تانية';
  String get proposalFailSignInNoUid => isEn
      ? 'Firebase returned an empty user id for the anonymous sign-in'
      : 'Firebase رجّع معرّف مستخدم فاضي لتسجيل الدخول المجهول';
  String get proposalFailPermissionDenied => isEn
      ? 'Firestore security rules rejected the upload'
      : 'قواعد أمان Firestore رفضت الرفع';
  String get proposalFailUnreachable => isEn
      ? 'Could not reach the cloud — no connection, or it took too long'
      : 'ما وصلنش للسحابة — لا يوجد اتصال أو الطلب أخد وقت أكتر من اللازم';
  String get proposalFailCancelled => isEn
      ? 'The request was cancelled before it reached the cloud'
      : 'الطلب اتلغى قبل ما يوصل للسحابة';
  String get proposalFailTargetMissing => isEn
      ? 'This Firebase project has nowhere to store proposals'
      : 'مشروع Firebase ده مفيهوش مكان بيتخزن فيه الاقتراحات';
  String get proposalFailQuotaExhausted => isEn
      ? 'The cloud used up its limit for this device — try again later'
      : 'السحابة استهلكت حد الطلبات للجهاز ده — حاول بعد شوية';
  String get proposalFailLedger => isEn
      ? 'The proposal record on this phone could not be read'
      : 'سجل الاقتراحات على الموبايل ده ما قدرناش نقراه';
  String get proposalFailPhotoUnreadable => isEn
      ? 'The meal photo could not be read — open the meal and pick it again'
      : 'صورة الأكلة ما قدرناش نقراها — افتح الأكلة واختارها تاني';
  String get proposalFailPhotoTooLarge => isEn
      ? 'The meal photo is too large — pick another photo or retake it'
      : 'صورة الأكلة أكبر من الحد المسموح — اختار صورة تانية أو صوّرها من جديد';
  String get proposalFailPhotoLinkInvalid => isEn
      ? 'The saved photo link is too long to send'
      : 'لينك الصورة المحفوظ أطول من إنه يتبعت';
  String get proposalFailPhotoUploadTimeout => isEn
      ? 'Uploading the meal photo took too long'
      : 'رفع صورة الأكلة اخد وقت أكتر من اللازم';
  String get proposalFailPhotoUploadRefused => isEn
      ? 'The photo host refused the upload'
      : 'مضيف الصور رفض عملية الرفع';
  String get proposalFailPhotoUploadFailed => isEn
      ? 'Uploading the meal photo failed'
      : 'فشل رفع صورة الأكلة';

  /// The generic failure line with the identified cause appended.
  String proposalFailedReason(String reason) => isEn
      ? 'Proposal failed: $reason'
      : 'فشل إرسال الاقتراح: $reason';

  // ===========================================================================
  // History
  // ===========================================================================
  String get historyTitle => isEn ? 'Cooking Log' : 'سجل الأكلات';
  String get historySubtitle => isEn
      ? 'Your meal journey this month'
      : 'رحلة وجباتك خلال هذا الشهر';
  String get clearAllHistory => isEn ? 'Clear the whole log' : 'مسح السجل بالكامل';
  String get clearHistoryTitle => isEn ? 'Clear log' : 'مسح السجل';
  String get clearHistoryConfirm => isEn
      ? 'Are you sure you want to clear all cooking records?'
      : 'هل أنت متأكد من مسح جميع سجلات الطبخ؟';
  String get clearAll => isEn ? 'Clear all' : 'مسح الكل';
  String get historyCleared => isEn
      ? 'The whole log was cleared'
      : 'تم مسح السجل بالكامل';
  String get historyEmptyTitle => isEn ? 'Cooking log is empty!' : 'سجل الطبخ فارغ!';
  String get historyEmptyDesc => isEn
      ? 'Once you log meals from the home screen they will appear here, sorted by date.'
      : 'عندما تسجل وجباتك من الصفحة الرئيسية ستظهر هنا مرتبة بالتواريخ.';
  String get goToHome => isEn ? 'Go to Home' : 'العودة للرئيسية';
  String get veggieShort => isEn ? 'Veggie' : 'نباتي';

  // ===========================================================================
  // Notifications screen
  // ===========================================================================
  String get notificationsTitle => isEn ? 'Notifications' : 'الإشعارات';
  String get notificationsSubtitle => isEn
      ? 'All your notifications in one place'
      : 'كل إشعاراتك في مكان واحد';
  String get notificationsFollow => isEn
      ? 'Follow your reminders and new meal suggestions'
      : 'تابع تذكيراتك واقتراحات الأكلات الجديدة';
  String newBadge(int count) => isEn ? '$count new' : '$count جديد';
  String get notifDailyReminder => isEn ? 'Daily reminder' : 'تذكير يومي';
  String notifDailyReminderBody(String time) => isEn
      ? 'Don\'t forget to check today\'s meal suggestion — at $time'
      : 'متنساش تشوف اقتراح أكلة النهاردة - الساعة $time ظهراً';
  String get notifNewSuggestion => isEn ? 'New suggested meal' : 'كلة جديدة مقترحة';
  String get notifNewSuggestionBody => isEn
      ? 'Try authentic Egyptian Koshary with sauce and dakka — budget friendly and healthy'
      : 'جرب كشري مصري أصلي بالصلصة والدقة - اقتصادي ومفيد';
  String get notifFavoriteWaiting => isEn ? 'A favourite is waiting' : 'كلة مفضلة في انتظارك';
  String get notifFavoriteWaitingBody => isEn
      ? 'Green Molokhia with chicken — one of your favourites'
      : 'ملوخية خضراء بالفراخ - من مفضلاتك';
  String get notifMealLogged => isEn ? 'Meal logged' : 'تم تسجيل وجبة';
  String get notifMealLoggedBody => isEn
      ? 'Enjoy! Hawawshi Baladi was added to your log'
      : 'بالهنا والشفا! تم تسجيل حواوشي بلدي في السجل';
  String get notifVaultUpdate => isEn ? 'Meal vault' : 'خزانة الأكلات';
  String notifVaultUpdateBody(int count) => isEn
      ? 'You added $count new meals to your vault this week'
      : 'أضفت $count وجبات جديدة لخزانتك هذا الأسبوع';
  String get notifSettingsUpdate => isEn ? 'Settings updated' : 'تحديث الإعدادات';
  String get notifSettingsUpdateBody => isEn
      ? 'The daily reminder was enabled successfully'
      : 'تم تفعيل التذكير اليومي بنجاح';
  String get notificationSettings => isEn ? 'Notification settings' : 'إعدادات الإشعارات';
  String get notificationSettingsDesc => isEn
      ? 'Customise times and enable reminders'
      : 'تخصيص مواعيد وتفعيل التذكيرات';

  // ===========================================================================
  // Settings screen
  // ===========================================================================
  String get languageSettings => isEn ? 'Language' : 'اللغة';
  String get cooldownSettings => isEn ? 'Cooldown Period' : 'فترة استبعاد الأكلات (Cooldown)';
  String get cooldownDesc => isEn
      ? 'Duration to exclude a cooked meal from suggestions.'
      : 'المدة التي تظل فيها الأكلة مستبعدة من الاقتراحات بعد طبخها.';
  String get appearanceSettings => isEn ? 'Appearance & Theme' : 'المظهر والألوان';
  String get themeSystem => isEn ? 'System' : 'تلقائي';
  String get themeLight => isEn ? 'Light' : 'فاتح';
  String get themeDark => isEn ? 'Dark' : 'داكن';
  String get dietaryRules => isEn ? 'Dietary Rules' : 'قواعد التنوع الغذائي';
  String get dailyReminder => isEn ? 'Daily Reminder' : 'تنبيه الاقتراح اليومي';
  String get enableReminder => isEn ? 'Enable Daily Reminder' : 'تفعيل التذكير اليومي';
  String get enableReminderDesc => isEn
      ? 'Notification to check today\'s meal suggestions'
      : 'إشعار تذكير لتفقد اقتراحات وجبة اليوم';
  String get reminderTime => isEn ? 'Reminder Time' : 'موعد التذكير';
  String get networkCloud => isEn ? 'Network & Cloud' : 'الشبكة والسحابة';
  String get wifiOnly => isEn ? 'Cloud on Wi-Fi Only' : 'السحابة تعمل عبر Wi-Fi فقط';
  String get wifiOnlyDesc => isEn
      ? 'Browse, download and propose meals only on Wi-Fi to save mobile data.'
      : 'استكشاف وتنزيل واقتراح الأكلات يعمل فقط على الواي فاي للحفاظ على باقتك.';
  String get legalPolicies => isEn ? 'Legal Policies' : 'السياسات القانونية';
  String get privacyPolicy => isEn ? 'Privacy Policy' : 'سياسة الخصوصية';
  String get termsConditions => isEn
      ? 'Terms & Conditions'
      : 'إخلاء المسؤولية والشروط';
  String get restoreDefaults => isEn ? 'Restore Defaults' : 'استعادة الإعدادات الافتراضية';
  String get restoredSuccess => isEn
      ? 'Settings restored to defaults'
      : 'تم استعادة الإعدادات الافتراضية';

  // Profile
  String get settingsSubtitle => isEn
      ? 'Make your meals work for you'
      : 'خلّي أكلاتك تشتغل لمصلحتك';
  String get editProfile => isEn ? 'Edit Profile' : 'تعديل الملف الشخصي';
  String get nameField => isEn ? 'Name' : 'الاسم';
  String get emailField => isEn ? 'Email' : 'البريد الإلكتروني';
  String get chooseAvatar => isEn ? 'Choose Avatar' : 'اختر الصورة الرمزية';
  String get profileSaved => isEn ? 'Profile saved' : 'تم حفظ الملف الشخصي';
  String get defaultUserName => 'User name';
  String get defaultUserEmail => 'user@example.com';
  String get genderField => isEn ? 'Gender' : 'النوع';
  String get genderMale => isEn ? 'Male' : 'ذكر';
  String get genderFemale => isEn ? 'Female' : 'أنثى';
  String get genderRequired => isEn
      ? 'Please choose a gender to continue'
      : 'من فضلك اختر النوع (ذكر/أنثى)';
  String get avatarsForGenderHint => isEn
      ? 'Avatars shown match the selected gender'
      : 'الصور المعروضة مطابقة للنوع المختار';

  // Smart cooldown engine
  String get smartCooldownEngine => isEn ? 'Smart Cooldown Engine' : 'محرك الكولداون الذكي';
  String get cooldownSheetTitle => isEn
      ? 'Smart Cooldown Engine'
      : 'محرك الكولداون الذكي';
  String get cooldownSheetSubtitle => isEn
      ? 'Customise cooldown periods for proteins and vegetables. Zero days means disabled.'
      : 'تخصيص فترات الاستبعاد للبروتينات والخضار. صفر أيام تعني إيقاف الاستبعاد.';
  String get cooldownEnabledHint => isEn
      ? 'Cooldown active'
      : 'الاستبعاد مفعّل';
  String get cooldownDisabledHint => isEn
      ? 'Cooldown off — repeats freely'
      : 'الاستبعاد متوقف — يتكرر بحرية في أي وقت';
  String get delayMealRepeat => isEn ? 'Delay Meal Repeat' : 'تأخير تكرار الأكلة';
  String get chicken => isEn ? 'Chicken' : 'فراخ';
  String get beef => isEn ? 'Beef' : 'لحمة';
  String get fish => isEn ? 'Fish' : 'سمك';
  String get veggies => isEn ? 'Veggies' : 'خضار';
  String get legumes => isEn ? 'Legumes' : 'بقوليات';
  String get dairyEggs => isEn ? 'Eggs / Cheese' : 'بيض / أجبان';
  String get noProtein => isEn ? 'No protein' : 'بدون بروتين';
  String get waitingDays => isEn ? 'Waiting days' : 'أيام انتظار';

  // Notifications section
  String get notifications => isEn ? 'Notifications' : 'التنبيهات';
  String get dailyReminderDesc => isEn
      ? 'Get notified at your preferred time'
      : 'هيصلك إشعار في الوقت اللي تختاره';
  String get reminderTimeDesc => isEn ? 'When should we remind you?' : 'امتى تحب نذكّرك؟';

  // Appearance & admin
  String get appearanceAndLanguage => isEn ? 'Appearance & Language' : 'المظهر واللغة';
  String get appearance => isEn ? 'Appearance' : 'المظهر';
  String get chooseAppAppearance => isEn ? 'Choose app appearance' : 'اختر مظهر التطبيق';
  String get admin => isEn ? 'Administration' : 'الإدارة';
  String get databaseManagement => isEn ? 'Database Management' : 'إدارة قاعدة البيانات';
  String get manageLocalData => isEn
      ? 'View and manage local data'
      : 'عرض وإدارة البيانات المحلية';
  String get databaseComingSoon => isEn
      ? 'Database management coming soon!'
      : 'إدارة قاعدة البيانات قريباً!';
  String get languageEnglish => isEn ? 'English' : 'English';
  String get languageArabic => isEn ? 'Arabic' : 'العربية';
  String get languageCodeEn => 'EN';
  String get languageCodeAr => 'AR';
  String get privacyPolicyTitle => isEn ? 'Privacy policy' : 'Privacy policy';
  String get privacyBody => isEn
      ? 'The "Daily Meal" app is built with an offline-first approach.\n\n'
          'We do not track, collect, or transmit your personal data, location, or usage habits.\n\n'
          'All your personal meal data and settings are stored locally on your device to guarantee your privacy. '
          'If you use the "Explore" community recipes or "Suggest a Meal" features, the app connects to our cloud database to fetch or submit public recipes, but this is done without tracking any personally identifiable information.'
      : 'تطبيق "أكلة النهاردة" هو تطبيق يعتمد على التخزين المحلي (Offline-First).\n\n'
          'نحن لا نقوم بجمع أو تتبع بياناتك الشخصية، أو موقعك الجغرافي، أو عادات استخدامك.\n\n'
          'جميع بيانات وجباتك الشخصية وإعداداتك يتم حفظها بشكل أساسي على جهازك لضمان خصوصيتك. '
          'في حال استخدامك لميزة "استكشاف أكلات جديدة" أو "اقتراح أكلة"، يتصل التطبيق بقاعدة بياناتنا السحابية لتبادل الوصفات العامة، وذلك دون ربطها بأي بيانات شخصية تحدد هويتك.';

  String get termsBody => isEn
      ? 'The app is an organisational tool meant to help you suggest and plan daily home '
          'meals; it does not provide any medical or nutritional advice.\n\n'
          'Please note that checking meal ingredients and making sure they are free of '
          'allergens is entirely the user\'s responsibility.\n\n'
          'The app developers bear no responsibility for any health damage that may result '
          'from using the app\'s recipes or suggestions.'
      : 'التطبيق هو أداة تنظيمية تهدف إلى مساعدتك في اقتراح وتنظيم الوجبات المنزلية اليومية، ولا يقدم أي استشارات طبية أو غذائية متخصصة.\n\n'
          'يُرجى الانتباه إلى أن فحص مكونات الوجبات والتأكد من خلوها من أي مسببات للحساسية هو مسؤولية المستخدم بالكامل.\n\n'
          'لا يتحمل مطورو التطبيق أي مسؤولية عن أي أضرار صحية قد تنتج عن استخدام وصفات أو اقتراحات التطبيق.';

  // ===========================================================================
  // Welcome / onboarding
  // ===========================================================================
  String get welcomeTitle => isEn ? 'Welcome to Daily Meal!' : 'مرحباً بك في أكلة النهاردة!';
  String get welcomeSubtitle => isEn
      ? 'To tailor the experience for you, we need to know you a little.'
      : 'علشان نقدر نخصص لك التجربة بشكل أفضل، محتاجين نتعرف عليك.';
  String get welcomeHeroTitle => isEn ? 'WELCOME' : 'أهلاً بك';
  String get welcomeHeroDescription => isEn
      ? 'Tired of “What to cook today?”. Daily Meal is your offline companion that suggests dishes from your own favorite home recipes using smart repetition control. Plan easily, save left-overs, and log meals in seconds.'
      : 'محتار تطبخ إيه النهاردة؟ «أكلة النهاردة» رفيقك في المطبخ بدون إنترنت، بيقترح عليك أكلات من وصفات بيتك المفضلة مع تحكم ذكي في التكرار لتجديد سفرتك كل يوم.';
  String get welcomeStartNow => isEn ? 'START NOW' : 'ابدأ الآن';
  String get welcomeProfileTitle => isEn ? 'Let\'s Get Started' : 'لنبدأ رحلتك';
  String get welcomeProfileSubtitle => isEn
      ? 'Tell us a bit about yourself to personalize your kitchen.'
      : 'أخبرنا قليلاً عن نفسك لتخصيص مطبخك واقتراحاتك.';
  String get welcomeNameLabel => isEn ? 'Your Name (Required)' : 'اسمك (إجباري)';
  String get welcomeNameHint => isEn ? 'Enter your name' : 'اكتب اسمك هنا';
  String get welcomeNameRequired => isEn ? 'Please enter your name' : 'من فضلك أدخل اسمك';
  String get welcomeEmailLabel => isEn
      ? 'Your email (optional)'
      : 'بريدك الإلكتروني (اختياري)';
  String get welcomeEmailHint => isEn
      ? 'name@example.com'
      : 'name@example.com';
  String get welcomeGenderLabel => isEn ? 'Gender (Required)' : 'النوع (إجباري)';
  String get welcomeGenderRequired => isEn ? 'Please select your gender' : 'من فضلك اختر النوع';
  String get welcomeAvatarLabel => isEn ? 'Your Avatar' : 'صورتك الرمزية';
  String get welcomeChooseAvatarHint => isEn
      ? 'Tap to choose your avatar'
      : 'اضغط على الصورة لاختيار الأفاتار المفضل';
  String get welcomeFinish => isEn ? 'Enter the Kitchen' : 'انطلق إلى المطبخ';
  String get welcomeBack => isEn ? 'Back' : 'رجوع';
  String get welcomeStart => isEn ? 'Get started' : 'ابدأ الاستخدام';

  // ===========================================================================
  // Local notification (scheduled reminder)
  // ===========================================================================
  String get localNotificationTitle => isEn ? 'Daily Meal 🍽️' : 'أكلة النهاردة 🍽️';
  String get localNotificationBody => isEn
      ? 'Time to pick today\'s meal! Open the app to see the suggestions.'
      : 'حان وقت اختيار وجبة اليوم! افتح التطبيق لمعرفة الاقتراحات.';
  String get localNotificationDescription => isEn
      ? 'Daily reminder to check today\'s meal'
      : 'تذكير يومي لمعرفة أكلة النهاردة';
  String get localNotificationChannelName =>
      isEn ? 'Daily Meal Suggestions' : 'اقتراحات أكلة النهاردة';

  String get adminChannelName =>
      isEn ? 'Daily Meal announcements & updates' : 'إعلانات وتحديثات أكلة النهاردة';

  String get adminChannelDescription => isEn
      ? 'General announcements and updates from the app team'
      : 'إشعارات وتحديثات عامة من إدارة التطبيق';

  // ===========================================================================
  // Recommendation engine — relaxation reasons
  //
  // The engine is pure Dart and must stay free of display copy, so it reports a
  // numeric level + `isEmptyVault` flag and the UI resolves the text here.
  // ===========================================================================
  String relaxationReason(int level, {bool isEmptyVault = false}) {
    if (isEmptyVault) {
      return isEn
          ? 'The meal database is empty, please add meals.'
          : 'قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.';
    }
    switch (level) {
      case 0:
        return isEn
            ? 'Perfect suggestions matching every variety and cooldown rule.'
            : 'اقتراحات مثالية مطابقة لجميع شروط التنوع الغذائي وفترة الاستبعاد.';
      case 1:
        return isEn
            ? 'Repeating a carbs type was allowed to provide enough suggestions.'
            : 'تم السماح بتكرار صنف النشويات لتوفير اقتراحات كافية.';
      case 2:
        return isEn
            ? 'The cooldown period was halved to provide enough suggestions.'
            : 'تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية.';
      case 3:
        return isEn
            ? 'The protein rule and cooldown were relaxed to offer varied suggestions.'
            : 'تم تخفيف شرط البروتين وفترة الاستبعاد لتوفير اقتراحات متنوعة.';
      case 4:
        return isEn
            ? 'Emergency mode: only today\'s meals are excluded to provide suggestions.'
            : 'وضع الطوارئ: استبعاد وجبات اليوم فقط لتوفير اقتراحات.';
      case 5:
      default:
        return isEn
            ? 'All available meals are shown because there are no other options.'
            : 'تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى.';
    }
  }

  // ===========================================================================
  // Enum / entry-type labels
  //
  // Keys are stable identifiers produced by the data layer; the display text
  // lives here so switching language updates every badge and chip instantly.
  // ===========================================================================
  String proteinLabel(String enumName) {
    switch (enumName) {
      case 'chicken':
        return chicken;
      case 'beef':
        return beef;
      case 'fish':
        return fish;
      case 'legume':
        return legumes;
      case 'dairy':
        return dairyEggs;
      case 'none':
        return noProtein;
      default:
        return enumName;
    }
  }

  String carbsLabel(String enumName) {
    switch (enumName) {
      case 'rice':
        return isEn ? 'Rice' : 'أرز';
      case 'pasta':
        return isEn ? 'Pasta' : 'مكرونة';
      case 'bread':
        return isEn ? 'Bread' : 'عيش';
      case 'potato':
        return isEn ? 'Potatoes' : 'بطاطس';
      case 'grains':
        return isEn ? 'Grains / Freekeh' : 'حبوب / فريك';
      case 'none':
        return isEn ? 'No carbs' : 'بدون نشويات';
      default:
        return enumName;
    }
  }

  String categoryLabel(String enumName) {
    switch (enumName) {
      case 'egyptianTraditional':
        return isEn ? 'Traditional & stews' : 'أكلات شعبية وطبيخ';
      case 'ovenBaked':
        return isEn ? 'Tagines & oven dishes' : 'طواجن وصواني فرن';
      case 'fastFood':
        return isEn ? 'Fast food & sandwiches' : 'سريع وسندوتشات';
      case 'seafood':
        return isEn ? 'Fish & seafood' : 'أسماك وبحريات';
      case 'soupStew':
        return isEn ? 'Soups & stews' : 'شوربات ويخنات';
      case 'vegetarian':
        return isEn ? 'Vegetarian' : 'نباتي / قرديحي';
      default:
        return enumName;
    }
  }

  /// History entry types are persisted as `'cooked'` / `'leftover'`.
  String entryTypeLabel(String entryType) {
    switch (entryType) {
      case 'cooked':
        return isEn ? 'Freshly cooked' : 'طبخة جديدة';
      case 'leftover':
        return leftover;
      case 'takeout':
        return isEn ? 'Takeout' : 'تيك أواي';
      case 'skipped':
        return isEn ? 'Skipped' : 'تفويت الوجبة';
      default:
        return entryType;
    }
  }

  /// Localized display name for a history entry's stored `mealName`.
  ///
  /// Takeout/skipped rows persist a language-neutral key (`'takeout'` /
  /// `'skipped'`), so the raw DB string is not user-facing copy. This resolves
  /// those keys — and legacy rows that stored Arabic directly — to the current
  /// locale. Genuine cooked/leftover meal names pass through unchanged.
  String historyEntryDisplayName({
    required String mealName,
    required String entryType,
  }) {
    final lowerType = entryType.toLowerCase();
    final lowerName = mealName.trim().toLowerCase();
    if (lowerType == 'takeout' ||
        lowerName == 'takeout' ||
        lowerName == 'خارج البيت' ||
        lowerName == 'أكل من بره' ||
        lowerName == 'تيك أواي') {
      return isEn ? 'Takeout' : 'أكل من بره';
    }
    if (lowerType == 'skipped' ||
        lowerName == 'skipped' ||
        lowerName == 'تفويت الوجبة') {
      return isEn ? 'Skipped Meal' : 'تفويت الوجبة';
    }
    return mealName;
  }

  // ===========================================================================
  // Notification Center
  // ===========================================================================
  String get notificationCenterTitle => isEn ? 'Notification Center' : 'مركز الإشعارات';
  String get notificationCenterSubtitle => isEn ? 'Stay updated with your meals and reminders' : 'تابع أحدث الوجبات والتذكيرات';
  String get readAll => isEn ? 'Read All' : 'تحديد كـ مقروء';
  String get deleteAll => isEn ? 'Delete All' : 'حذف الكل';
  String get tabMeals => isEn ? 'Meals' : 'الوجبات';
  String get tabReminders => isEn ? 'Reminders' : 'التذكيرات';
  String get tabUpdates => isEn ? 'Updates' : 'تحديثات';
  String get emptyNotifications => isEn ? 'No notifications yet' : 'لا توجد إشعارات بعد';
  String get emptyNotificationsMeals => isEn ? 'No meal notifications' : 'لا توجد إشعارات للوجبات';
  String get emptyNotificationsReminders => isEn ? 'No reminders' : 'لا توجد تذكيرات';
  String get emptyNotificationsUpdates => isEn ? 'No updates' : 'لا توجد تحديثات';
  String get goodFoodBrighterDays => isEn ? 'Good Food, Brighter Days' : 'أكل حلو، أيام أحلى';
  String get deleteConfirmTitle => isEn ? 'Delete All' : 'حذف الكل';
  String get deleteConfirmBody => isEn ? 'Are you sure you want to delete all notifications?' : 'هل أنت متأكد من حذف جميع الإشعارات؟';
  String get delete => isEn ? 'Delete' : 'حذف';
  
  String timeAgo(int minutes) {
    if (minutes < 60) return isEn ? 'm ago' : 'منذ  دقيقة';
    final hours = minutes ~/ 60;
    if (hours < 24) return isEn ? 'h ago' : 'منذ  ساعة';
    final days = hours ~/ 24;
    if (days == 1) return isEn ? 'Yesterday' : 'أمس';
    return isEn ? 'd ago' : 'منذ  أيام';
  }
}
