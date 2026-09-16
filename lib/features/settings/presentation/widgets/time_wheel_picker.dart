import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';

/// Custom scrollable time picker matching the reference screenshot:
/// Sleek bottom sheet, borderless wheels, active center row,
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

  bool _isHourScrolling = false;
  bool _isMinuteScrolling = false;
  bool _isPeriodScrolling = false;

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

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required bool isScrolling,
    required bool loop,
    required Widget Function(int index, bool isSelected, bool isScrolling) builder,
    required ValueChanged<int> onSelectedItemChanged,
    required ValueChanged<bool> onScrollingChanged,
    double width = 60,
  }) {
    return SizedBox(
      width: width,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notif) {
          if (notif is ScrollStartNotification) {
            onScrollingChanged(true);
          } else if (notif is ScrollEndNotification) {
            onScrollingChanged(false);
          }
          return false;
        },
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          clipBehavior: Clip.hardEdge,
          physics: const FixedExtentScrollPhysics(),
          squeeze: 1.05,
          diameterRatio: 1.3,
          useMagnifier: true,
          magnification: 1.08,
          overAndUnderCenterOpacity: 0.45,
          onSelectedItemChanged: onSelectedItemChanged,
          childDelegate: loop
              ? ListWheelChildLoopingListDelegate(
                  children: List.generate(itemCount, (i) => builder(i, i == selectedIndex, isScrolling)),
                )
              : ListWheelChildListDelegate(
                  children: List.generate(itemCount, (i) => builder(i, i == selectedIndex, isScrolling)),
                ),
        ),
      ),
    );
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
    const activeBlueColor = Color(0xFF3E63DD);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewPadding.bottom > 0 ? 10 : 18),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            // Scrollable Wheels (Height = 132 for exactly 3 items of 44px)
            SizedBox(
              height: 132,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hour Wheel
                    _buildWheel(
                      controller: _hourController,
                      itemCount: 12,
                      selectedIndex: _hour - 1,
                      isScrolling: _isHourScrolling,
                      loop: true,
                      onSelectedItemChanged: (i) => setState(() => _hour = i + 1),
                      onScrollingChanged: (val) => setState(() => _isHourScrolling = val),
                      width: 72,
                      builder: (i, isSelected, isScrolling) {
                        final h = i + 1;
                        return Center(
                          child: Text(
                            '$h',
                            style: TextStyle(
                              fontSize: isSelected ? 30 : 22,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isScrolling 
                                  ? (isSelected ? activeBlueColor : activeBlueColor.withValues(alpha: 0.5))
                                  : (isSelected ? primaryTextColor : secondaryTextColor),
                            ),
                          ),
                        );
                      },
                    ),

                    // Colon Separator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                    ),

                    // Minute Wheel
                    _buildWheel(
                      controller: _minuteController,
                      itemCount: 60,
                      selectedIndex: _minute,
                      isScrolling: _isMinuteScrolling,
                      loop: true,
                      onSelectedItemChanged: (i) => setState(() => _minute = i),
                      onScrollingChanged: (val) => setState(() => _isMinuteScrolling = val),
                      width: 72,
                      builder: (i, isSelected, isScrolling) {
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSelected ? 30 : 22,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isScrolling 
                                  ? (isSelected ? activeBlueColor : activeBlueColor.withValues(alpha: 0.5))
                                  : (isSelected ? primaryTextColor : secondaryTextColor),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 32),

                    // AM/PM Wheel
                    _buildWheel(
                      controller: _periodController,
                      itemCount: 2,
                      selectedIndex: _period,
                      isScrolling: _isPeriodScrolling,
                      loop: false, // NO LOOPING FOR AM/PM
                      onSelectedItemChanged: (i) => setState(() => _period = i),
                      onScrollingChanged: (val) => setState(() => _isPeriodScrolling = val),
                      width: 72,
                      builder: (i, isSelected, isScrolling) {
                        final text = i == 0 ? strings.am : strings.pm;
                        return Center(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: isSelected ? 22 : 16,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isScrolling 
                                  ? (isSelected ? activeBlueColor : activeBlueColor.withValues(alpha: 0.5))
                                  : (isSelected ? primaryTextColor : secondaryTextColor),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Bottom Actions: Cancel | Done (No top divider line, brought up)
            SizedBox(
              height: 48,
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
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// Helper to show the wheel picker as a bottom sheet exactly matching the reference design
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context,
  Brightness brightness,
  TimeOfDay initial, {
  AppStrings? strings,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    builder: (ctx) => TimeWheelPicker(
      initialTime: initial,
      brightness: brightness,
      strings: strings,
    ),
  );
}
