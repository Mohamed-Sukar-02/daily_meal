import sys

# Update app_settings_table.dart
table_file = r'e:\Mohamed\Personal_Project\daily-meal\app_v2\lib\core\database\tables\app_settings_table.dart'
with open(table_file, 'r', encoding='utf-8') as f:
    table_content = f.read()
table_content = table_content.replace('IntColumn get meatlessCooldownDays => integer().withDefault(const Constant(3))();', 'IntColumn get meatlessCooldownDays => integer().withDefault(const Constant(0))();')
with open(table_file, 'w', encoding='utf-8') as f:
    f.write(table_content)

# Update app_settings_dao.dart
dao_file = r'e:\Mohamed\Personal_Project\daily-meal\app_v2\lib\core\database\daos\app_settings_dao.dart'
with open(dao_file, 'r', encoding='utf-8') as f:
    dao_content = f.read()
dao_content = dao_content.replace('meatlessCooldownDays: const Value(3),', 'meatlessCooldownDays: const Value(0),')
with open(dao_file, 'w', encoding='utf-8') as f:
    f.write(dao_content)

print("Updated defaults")
