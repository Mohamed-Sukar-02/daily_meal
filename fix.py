import sys

file_path = r'e:\Mohamed\Personal_Project\daily-meal\app_v2\lib\features\settings\presentation\settings_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''              // Always drawn, unlike the three above it. Its value used to
              // default to 0, which is what hid it — so the row a user has to
              // touch to turn the no-meat window on only appeared once that
              // window was already on.
              _divider(brightness),
              _stepperRow(
                context,
                ref,
                brightness,
                strings,
                key: const Key('cooldown_stepper_meatless'),
                emoji: '🌿',
                style: AppPalette.chipGreen(brightness),
                name: strings.meatlessLabel,
                days: settings.meatlessCooldownDays,
                onChanged: (d) => controller.updateMeatlessCooldownDays(d),
              ),'''

replacement = '''              if (settings.meatlessCooldownDays > 0) ...[
                _divider(brightness),
                _stepperRow(
                  context,
                  ref,
                  brightness,
                  strings,
                  key: const Key('cooldown_stepper_meatless'),
                  emoji: '🌿',
                  style: AppPalette.chipGreen(brightness),
                  name: strings.meatlessLabel,
                  days: settings.meatlessCooldownDays,
                  onChanged: (d) => controller.updateMeatlessCooldownDays(d),
                ),
              ],'''

if target in content:
    new_content = content.replace(target, replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Success")
else:
    print("Target not found")
