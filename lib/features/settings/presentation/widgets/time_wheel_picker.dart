import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Custom scrollable time picker matching the reference screenshot:
/// hour wheel (1-12), minute wheel (00-59), AM/PM wheel, with Cancel/Done.
class TimeWheelPicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final Brightness brightness;

  const TimeWheelPicker({
    super.key,
    required this.initialTime,
    required this.brightness,
  });

  @override
  State<TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<TimeWheelPicker> {
  late int _hour; // 1-12
  late int _minute; // 0-59
  late int _period; // 0=AM, 1=PM

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialTime.hour;
    _period = h24 >= 12 ? 1 : 0;
    final h12 = h24 % 12;
    _hour = h12 == 0 ? 12 : h12;
    _minute = widget.initialTime.minute;
  }

  TimeOfDay _toTimeOfDay() {
    int hour24 = _hour % 12;
    if (_period == 1) hour24 += 12;
    if (_period == 0 && _hour == 12) hour24 = 0;
    return TimeOfDay(hour: hour24, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top bar Cancel / Done
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Text(
                    'اختر الوقت',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context, _toTimeOfDay()),
                    child: const Text(
                      'تم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.brandGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: AppPalette.hairline(brightness)),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // Hour wheel
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: _hour - 1),
                      itemExtent: 44,
                      magnification: 1.1,
                      useMagnifier: true,
                      onSelectedItemChanged: (i) => setState(() => _hour = i + 1),
                      children: List.generate(12, (i) {
                        final h = i + 1;
                        final selected = h == _hour;
                        return Center(
                          child: Text(
                            h.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: selected ? 22 : 18,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              color: selected
                                  ? AppPalette.textPrimary(brightness)
                                  : AppPalette.textSecondary(brightness),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Separator
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                  // Minute wheel
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: _minute),
                      itemExtent: 44,
                      magnification: 1.1,
                      useMagnifier: true,
                      onSelectedItemChanged: (i) => setState(() => _minute = i),
                      children: List.generate(60, (i) {
                        final selected = i == _minute;
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: selected ? 22 : 18,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              color: selected
                                  ? AppPalette.textPrimary(brightness)
                                  : AppPalette.textSecondary(brightness),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // AM/PM wheel
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: _period),
                      itemExtent: 44,
                      magnification: 1.1,
                      useMagnifier: true,
                      onSelectedItemChanged: (i) => setState(() => _period = i),
                      children: [
                        Center(
                          child: Text(
                            'ص',
                            style: TextStyle(
                              fontSize: _period == 0 ? 22 : 18,
                              fontWeight: _period == 0 ? FontWeight.w800 : FontWeight.w500,
                              color: _period == 0
                                  ? AppPalette.textPrimary(brightness)
                                  : AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'م',
                            style: TextStyle(
                              fontSize: _period == 1 ? 22 : 18,
                              fontWeight: _period == 1 ? FontWeight.w800 : FontWeight.w500,
                              color: _period == 1
                                  ? AppPalette.textPrimary(brightness)
                                  : AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Helper to show the wheel picker as modal bottom sheet
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context,
  Brightness brightness,
  TimeOfDay initial,
) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => TimeWheelPicker(initialTime: initial, brightness: brightness),
  );
}
