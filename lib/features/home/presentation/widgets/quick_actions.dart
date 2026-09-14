import 'package:flutter/material.dart';

/// Quick action buttons for marking a meal as cooked today or leftover.
/// In RTL, the primary action ("طبخت دي النهاردة") is placed first so it appears on the right.
class QuickActions extends StatelessWidget {
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;

  const QuickActions({
    super.key,
    required this.onCookedToday,
    required this.onLeftover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('btn_cooked_today'),
        onPressed: onCookedToday,
        icon: const Icon(Icons.soup_kitchen, size: 24, color: Colors.white),
        label: const Text(
          'Cook This',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF17C97B),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}
