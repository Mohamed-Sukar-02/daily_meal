import os
import io

file_path = r'E:\Mohamed\Personal_Project\daily-meal\app_v2\lib\core\localization\app_strings.dart'
with io.open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_strings = '''
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
  String get cancel => isEn ? 'Cancel' : 'إلغاء';
  String get delete => isEn ? 'Delete' : 'حذف';
  
  String timeAgo(int minutes) {
    if (minutes < 60) return isEn ? 'm ago' : 'منذ  دقيقة';
    final hours = minutes ~/ 60;
    if (hours < 24) return isEn ? 'h ago' : 'منذ  ساعة';
    final days = hours ~/ 24;
    if (days == 1) return isEn ? 'Yesterday' : 'أمس';
    return isEn ? 'd ago' : 'منذ  أيام';
  }
'''

# Find the last closing brace and insert before it
last_brace_index = content.rfind('}')
if last_brace_index != -1:
    content = content[:last_brace_index] + new_strings + content[last_brace_index:]

with io.open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated app_strings.dart')
