import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';

/// Custom scrollable time picker matching the reference screenshot:
/// Sleek floating card, borderless CupertinoPickers, active center row,
/// and bottom Cancel | Done actions with localization support.
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

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialTime.hour;
    _period = h24 >= 12 ? 1 : 0;
    final h12 = h24 % 12;
    _hour = h12 == 0 ? 12 : h12;
    _minute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _periodController = FixedExtentScrollController(initialItem: _period);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
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
    final strings = AppStrings.of(context);

    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final primaryTextColor = AppPalette.textPrimary(brightness);
    final secondaryTextColor = primaryTextColor.withValues(alpha: 0.3);
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          // Scrollable Wheels
          SizedBox(
            height: 160,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hour Wheel
                  SizedBox(
                    width: 60,
                    child: CupertinoPicker(
                      scrollController: _hourController,
                      itemExtent: 48,
                      selectionOverlay: const SizedBox.shrink(),
                      squeeze: 1.05,
                      diameterRatio: 1.4,
                      onSelectedItemChanged: (i) => setState(() => _hour = i + 1),
                      children: List.generate(12, (i) {
                        final h = i + 1;
                        final isSelected = h == _hour;
                        return Center(
                          child: Text(
                            '$h',
                            style: TextStyle(
                              fontSize: isSelected ? 30 : 22,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Colon Separator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),

                  // Minute Wheel
                  SizedBox(
                    width: 68,
                    child: CupertinoPicker(
                      scrollController: _minuteController,
                      itemExtent: 48,
                      selectionOverlay: const SizedBox.shrink(),
                      squeeze: 1.05,
                      diameterRatio: 1.4,
                      onSelectedItemChanged: (i) => setState(() => _minute = i),
                      children: List.generate(60, (i) {
                        final isSelected = i == _minute;
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSelected ? 30 : 22,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // AM/PM Wheel
                  SizedBox(
                    width: 68,
                    child: CupertinoPicker(
                      scrollController: _periodController,
                      itemExtent: 48,
                      selectionOverlay: const SizedBox.shrink(),
                      squeeze: 1.05,
                      diameterRatio: 1.4,
                      onSelectedItemChanged: (i) => setState(() => _period = i),
                      children: [
                        Center(
                          child: Text(
                            strings.am,
                            style: TextStyle(
                              fontSize: _period == 0 ? 24 : 18,
                              fontWeight: _period == 0 ? FontWeight.w700 : FontWeight.w400,
                              color: _period == 0 ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            strings.pm,
                            style: TextStyle(
                              fontSize: _period == 1 ? 24 : 18,
                              fontWeight: _period == 1 ? FontWeight.w700 : FontWeight.w400,
                              color: _period == 1 ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),

          // Bottom Actions: Cancel | Done
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24)),
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Text(
                        strings.cancel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: dividerColor,
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(24)),
                    onTap: () => Navigator.pop(context, _toTimeOfDay()),
                    child: Center(
                      child: Text(
                        strings.done,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to show the wheel picker as a floating dialog exactly matching the reference design
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context,
  Brightness brightness,
  TimeOfDay initial,
) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: TimeWheelPicker(initialTime: initial, brightness: brightness),
      ),
    ),
  );
}
