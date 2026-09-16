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
  final AppStrings? strings;

  const TimeWheelPicker({
    super.key,
    required this.initialTime,
    required this.brightness,
    this.strings,
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
    final strings = widget.strings ?? AppStrings.of(context);

    final cardBg = isDark ? const Color(0xFF1B1C1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppPalette.textPrimary(brightness);
    final secondaryTextColor = isDark ? const Color(0xFF555558) : primaryTextColor.withValues(alpha: 0.35);
    final dividerColor = isDark ? const Color(0xFF333336) : Colors.black12;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
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
                              fontSize: isSelected ? 32 : 24,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Colon Separator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
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
                              fontSize: isSelected ? 32 : 24,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(width: 16),

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
                              fontSize: _period == 0 ? 26 : 20,
                              fontWeight: _period == 0 ? FontWeight.w800 : FontWeight.w500,
                              color: _period == 0 ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            strings.pm,
                            style: TextStyle(
                              fontSize: _period == 1 ? 26 : 20,
                              fontWeight: _period == 1 ? FontWeight.w800 : FontWeight.w500,
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

          const SizedBox(height: 16),

          // Bottom Actions: Cancel | Done
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28)),
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
                  height: 22,
                  color: dividerColor,
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(28)),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Helper to show the wheel picker as a floating dialog exactly matching the reference design
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context,
  Brightness brightness,
  TimeOfDay initial, {
  AppStrings? strings,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: TimeWheelPicker(
          initialTime: initial,
          brightness: brightness,
          strings: strings,
        ),
      ),
    ),
  );
}
