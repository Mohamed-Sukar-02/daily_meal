import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('ar');
    return AppStrings(locale);
  }

  bool get isEn => locale.languageCode == 'en';

  String get appName => isEn ? 'Daily Meal' : 'أكلة النهاردة';
  String get appSubtitle => isEn ? 'Smart daily meal suggestions for your home' : 'اقتراحات يومية ذكية لوجبات البيت المصري';
  
  // Navigation
  String get navHome => isEn ? 'Home' : 'الرئيسية';
  String get navVault => isEn ? 'Vault' : 'خزانة الأكلات';
  String get navHistory => isEn ? 'History' : 'السجل';
  String get navSettings => isEn ? 'Settings' : 'الإعدادات';
  
  // Settings
  String get languageSettings => isEn ? 'Language' : 'اللغة';
  String get cooldownSettings => isEn ? 'Cooldown Period' : 'فترة استبعاد الأكلات (Cooldown)';
  String get cooldownDesc => isEn ? 'Duration to exclude a cooked meal from suggestions.' : 'المدة التي تظل فيها الأكلة مستبعدة من الاقتراحات بعد طبخها.';
  String get appearanceSettings => isEn ? 'Appearance & Theme' : 'المظهر والألوان';
  String get themeSystem => isEn ? 'System' : 'تلقائي';
  String get themeLight => isEn ? 'Light' : 'فاتح';
  String get themeDark => isEn ? 'Dark' : 'داكن';
  String get dietaryRules => isEn ? 'Dietary Rules' : 'قواعد التنوع الغذائي';
  String get preventProteinRepeat => isEn ? 'Prevent Consecutive Protein' : 'منع تكرار نوع البروتين المتتالي';
  String get preventProteinRepeatDesc => isEn ? 'Exclude same protein cooked today or yesterday' : 'استبعاد نفس البروتين المطبوخ بالأمس أو اليوم';
  String get preventCarbRepeat => isEn ? 'Prevent Consecutive Carbs' : 'منع تكرار نوع النشويات المتتالي';
  String get preventCarbRepeatDesc => isEn ? 'Avoid repeating rice or pasta consecutively' : 'تجنب تكرار الأرز أو المكرونة يومين وراء بعض';
  String get dailyReminder => isEn ? 'Daily Reminder' : 'تنبيه الاقتراح اليومي';
  String get enableReminder => isEn ? 'Enable Daily Reminder' : 'تفعيل التذكير اليومي';
  String get enableReminderDesc => isEn ? 'Notification to check today\'s meal suggestions' : 'إشعار تذكير لتفقد اقتراحات وجبة اليوم';
  String get reminderTime => isEn ? 'Reminder Time' : 'موعد التذكير';
  String get networkCloud => isEn ? 'Network & Cloud' : 'الشبكة والسحابة';
  String get wifiOnly => isEn ? 'Cloud on Wi-Fi Only' : 'السحابة تعمل عبر Wi-Fi فقط';
  String get wifiOnlyDesc => isEn ? 'Download meals only when connected to Wi-Fi.' : 'تنزيل واستكشاف الأكلات يعمل فقط عند الاتصال بشبكة واي فاي للحفاظ على باقتك.';
  String get legalPolicies => isEn ? 'Legal Policies' : 'السياسات القانونية';
  String get privacyPolicy => isEn ? 'Privacy Policy' : 'سياسة الخصوصية';
  String get termsConditions => isEn ? 'Terms & Conditions' : 'إخلاء المسؤولية والشروط';
  String get restoreDefaults => isEn ? 'Restore Defaults' : 'استعادة الإعدادات الافتراضية';
  String get restoredSuccess => isEn ? 'Settings restored to defaults' : 'تم استعادة الإعدادات الافتراضية';
  String get errorOccurred => isEn ? 'An error occurred: ' : 'حدث خطأ: ';

  // Home Screen
  String get refreshSuggestions => isEn ? 'Refresh Suggestions' : 'تحديث الاقتراحات';
  String get vaultEmpty => isEn ? 'Vault is empty!' : 'خزنة الأكلات فارغة!';
  String get vaultEmptyDesc => isEn ? 'Start by adding a meal or download suggestions.' : 'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.';
  String get addFirstMeal => isEn ? 'Add first meal' : 'أضف أكلتك الأولى';
  String get errorPreparing => isEn ? 'Error preparing suggestions' : 'حدث خطأ في تجهيز الاقتراحات';
  String get retry => isEn ? 'Retry' : 'إعادة المحاولة';
  String get todaySuggestions => isEn ? 'Today\'s suggestions for you:' : 'اقتراحات النهاردة المختارة لك:';
  
  String greetingMorning(String name) => isEn ? 'Good morning, $name ☀️' : 'صباح الفل والجمال يا $name ☀️';
  String greetingAfternoon(String name) => isEn ? 'What to cook today, $name? 🍲' : 'أكلة النهاردة.. هنطبخ إيه يا $name؟ 🍲';
  String greetingEvening(String name) => isEn ? 'Good evening, $name 🌙' : 'مساء الهنا والسرور يا $name 🌙';
  
  String get greetingMorningNoName => isEn ? 'Good morning ☀️' : 'صباح الفل والجمال ☀️';
  String get greetingAfternoonNoName => isEn ? 'What to cook today? 🍲' : 'أكلة النهاردة.. هنطبخ إيه؟ 🍲';
  String get greetingEveningNoName => isEn ? 'Good evening 🌙' : 'مساء الهنا والسرور 🌙';

  String get top3Balanced => isEn ? 'Selected best 3 balanced meals.' : 'اخترنا لك أفضل 3 وجبات متنوعة ومتوازنة.';
  String get spinWheel => isEn ? 'Spin the Wheel' : 'لف العجلة';
  String get varietyAlert => isEn ? 'Variety Alert' : 'تنبيه التنوع الغذائي';
  
  String get cookedToday => isEn ? 'Cooked Today' : 'طبختها النهاردة';
  String get leftover => isEn ? 'Leftover' : 'بواقي أكل';
  String cookedSuccess(String mealName) => isEn ? 'Enjoy! "$mealName" added to history.' : 'بالهنا والشفا! تم تسجيل "$mealName" في السجل.';
  String leftoverSuccess(String mealName) => isEn ? 'Logged leftover for "$mealName".' : 'تم تسجيل بواقي أكل "$mealName".';
  String get undo => isEn ? 'Undo' : 'تراجع';

  // Profile Settings
  String get settingsSubtitle => isEn ? 'Make your meals work for you' : 'خلّي أكلاتك تشتغل لمصلحتك';
  String get editProfile => isEn ? 'Edit Profile' : 'تعديل الملف الشخصي';
  String get nameField => isEn ? 'Name' : 'الاسم';
  String get emailField => isEn ? 'Email' : 'البريد الإلكتروني';
  String get chooseAvatar => isEn ? 'Choose Avatar' : 'اختر الصورة الرمزية';
  String get profileSaved => isEn ? 'Profile saved' : 'تم حفظ الملف الشخصي';
  String get cancel => isEn ? 'Cancel' : 'إلغاء';
  String get done => isEn ? 'Done' : 'تم';
  String get am => isEn ? 'AM' : 'ص';
  String get pm => isEn ? 'PM' : 'م';
  String get save => isEn ? 'Save' : 'حفظ';

  // Cooldown Settings
  String get smartCooldownEngine => isEn ? 'Smart Cooldown Engine' : 'محرك الكولداون الذكي';
  String get more => isEn ? 'More' : 'المزيد';
  String get delayMealRepeat => isEn ? 'Delay Meal Repeat' : 'تأخير تكرار الأكلة';
  String get chicken => isEn ? 'Chicken' : 'فراخ';
  String get beef => isEn ? 'Beef' : 'لحمة';
  String get fish => isEn ? 'Fish' : 'سمك';
  String get veggies => isEn ? 'Veggies' : 'خضار';
  String get waitingDays => isEn ? 'Waiting days' : 'أيام انتظار';

  // Notifications
  String get notifications => isEn ? 'Notifications' : 'التنبيهات';
  String get dailyReminderDesc => isEn ? 'Get notified at your preferred time' : 'هيصلك إشعار في الوقت اللي تختاره';
  String get reminderTimeDesc => isEn ? 'When should we remind you?' : 'امتى تحب نذكّرك؟';

  // Appearance & Admin
  String get appearanceAndLanguage => isEn ? 'Appearance & Language' : 'المظهر واللغة';
  String get appearance => isEn ? 'Appearance' : 'المظهر';
  String get chooseAppAppearance => isEn ? 'Choose app appearance' : 'اختر مظهر التطبيق';
  String get admin => isEn ? 'Administration' : 'الإدارة';
  String get databaseManagement => isEn ? 'Database Management' : 'إدارة قاعدة البيانات';
  String get manageLocalData => isEn ? 'View and manage local data' : 'عرض وإدارة البيانات المحلية';
  String get databaseComingSoon => isEn ? 'Database management coming soon!' : 'إدارة قاعدة البيانات قريباً!';
  String get languageEnglish => isEn ? 'English' : 'English';
  String get languageArabic => isEn ? 'Arabic' : 'العربية';

  // Other common
  String daysText(int days) {
    if (isEn) return '$days days';
    if (days == 1) return 'يوم واحد';
    if (days == 2) return 'يومان';
    if (days <= 10) return '$days أيام';
    return '$days يوماً';
  }
}
