import 'dart:ui' as ui;

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The FAB's "add in 10 seconds" bubble is a fixed 86x47 design box — same
/// family as the 85px vault header clip: a pinned chrome surface that cannot
/// grow with the system text scale. Its label area is 47 - 4 (top) - 11
/// (bottom padding, the 7px tail inside it) = 32px, but the two-line label at
/// fontSize 11.5 / height 1.15 measures 2 x 13.225 = 26.45px at a 1.0 text
/// scale and 2 x 19.8375 = 39.675px at 1.5 — so before the guard the label
/// painted 7.7px below its own text area, past the bubble body's bottom edge
/// (the tail line at y = 40) and over the FAB underneath.
///
/// No RenderFlex error ever flagged it: the chain is Padding + Center, neither
/// of which is a Flex, and an overflowing paragraph only paints wider than the
/// box it was squeezed into. So this file measures the painted line boxes of
/// the label (via RenderParagraph.getBoxesForSelection) against the bubble in
/// the bubble's own local coordinates, which cancels the static -0.055 rad
/// sway the tooltip holds still in widget tests.
///
/// The guard is the one `_buildVaultHeaderWidget` already uses:
/// LayoutBuilder + FittedBox(fit: BoxFit.scaleDown) with a width-pinned child.
/// scaleDown never enlarges, so the 1.0x case below pins the measured painted
/// geometry (label box pair 25.362px tall, top 7.638, bottom 33.000) to prove
/// the guard is inert — i.e. the bubble stays pixel-identical — at a normal
/// text scale.
void main() {
  testWidgets('FAB tooltip keeps the painted label inside the bubble at 1.5x '
      'text on a narrow phone', (tester) async {
    final db = await _openVault(tester, textScale: 1.5);
    final g = _measureTooltip(tester);

    // The guard shrinks the label, never the pinned 86x47 bubble.
    expect(g.bubbleWidth, closeTo(_bubbleWidth, 0.5));
    expect(g.bubbleHeight, closeTo(_bubbleHeight, 0.5));

    debugPrint('tooltip 1.5x/360: label top ${g.label.top.toStringAsFixed(3)} '
        'bottom ${g.label.bottom.toStringAsFixed(3)} '
        'height ${g.label.height.toStringAsFixed(3)} '
        '(body ends at ${_bubbleHeight - _tailHeight})');

    // The tail line is the edge the 39.675px label used to hang 3.7px past at
    // this scale — that is the "over the FAB" of the bug report.
    _expectInsideBody(g.label, 'the "add in 10 seconds" label');
    expect(g.label.height, greaterThan(20.0),
        reason: 'the label scales down to fit, it must not be crushed away');

    expect(tester.takeException(), isNull,
        reason: 'the tooltip must not overflow its bubble at 1.5x text');
    await _close(tester, db);
  });

  testWidgets('FAB tooltip keeps its designed label geometry at 1.0x text',
      (tester) async {
    final db = await _openVault(tester, textScale: 1.0);
    final g = _measureTooltip(tester);

    expect(g.bubbleWidth, closeTo(_bubbleWidth, 0.5));
    expect(g.bubbleHeight, closeTo(_bubbleHeight, 0.5));

    debugPrint('tooltip 1.0x/360: label top ${g.label.top.toStringAsFixed(3)} '
        'bottom ${g.label.bottom.toStringAsFixed(3)} '
        'height ${g.label.height.toStringAsFixed(3)}');

    // 2 lines of 11.5 x 1.15 = 13.225px of line box, centred in the 32px
    // label area the 4/11 gutters leave. Measured on this harness with the
    // bundled Cairo and [ui.BoxHeightStyle.includeLineSpacingMiddle]: the
    // painted box pair is 25.362px tall, top at 7.638, bottom at 33.000 —
    // the same numbers with the guard in and with it taken out (checked on
    // the reverted widget), i.e. scaleDown is inert at a normal text scale.
    expect(g.label.height, closeTo(25.362, 0.6),
        reason: 'the guard must be inert at a normal text scale');
    expect(g.label.top, closeTo(7.638, 0.6),
        reason: 'the label must sit exactly where it did before the guard');
    expect(g.label.bottom, closeTo(33.000, 0.6));

    _expectInsideBody(g.label, 'the unscaled label');
    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// The narrow phone the other text-scale cases use.
const _narrowPhone = Size(360, 640);

/// `_AddIn10SecondsTooltip`'s pinned box and the tail that eats its bottom
/// padding — mirrored from the widget's design constants, not imported from
/// it, so the test keeps its own copy of the contract.
const _bubbleWidth = 86.0;
const _bubbleHeight = 47.0;
const _tailHeight = 7.0;

class _TooltipGeometry {
  _TooltipGeometry(this.bubbleWidth, this.bubbleHeight, this.label);

  final double bubbleWidth;
  final double bubbleHeight;

  /// Union of the label's painted line boxes, in the bubble's local
  /// coordinates (y = 0 at the bubble's top edge).
  final Rect label;
}

/// The bubble's painted body: the 86x47 box minus its 7px tail, because a
/// label hanging into the tail strip is a label hanging over the FAB.
Rect _bubbleBody() =>
    Rect.fromLTRB(0, 0, _bubbleWidth, _bubbleHeight - _tailHeight);

void _expectInsideBody(Rect label, String what) {
  final body = _bubbleBody();
  expect(label.top, greaterThanOrEqualTo(body.top - 0.5),
      reason: '$what is painted above the bubble');
  expect(label.bottom, lessThanOrEqualTo(body.bottom + 0.5),
      reason: '$what hangs below the bubble body into the tail — over the FAB');
  expect(label.left, greaterThanOrEqualTo(body.left - 0.5),
      reason: '$what starts outside the bubble on the left');
  expect(label.right, lessThanOrEqualTo(body.right + 0.5),
      reason: '$what runs past the bubble on the right');
}

_TooltipGeometry _measureTooltip(WidgetTester tester) {
  final tooltip = find.byKey(const ValueKey('vault_add_tooltip'));
  expect(tooltip, findsOneWidget,
      reason: 'the vault FAB must still show the speech-bubble tooltip');
  final strings = AppStrings(const Locale('ar'));
  expect(
      find.descendant(of: tooltip, matching: find.text(strings.vaultAddIn10Seconds)),
      findsOneWidget,
      reason: 'the two-line label is still in the tree (a guard may shrink it, '
          'never drop it)');

  final bubbleFinder = find.descendant(
      of: tooltip, matching: find.byType(CustomPaint));
  expect(bubbleFinder, findsOneWidget,
      reason: 'the only CustomPaint in the tooltip is the bubble painter');
  final bubbleRo = tester.renderObject(bubbleFinder) as RenderBox;

  final paragraph =
      tester.renderObject(find.descendant(of: tooltip, matching: find.byType(RichText)).first)
          as RenderParagraph;
  final text = paragraph.text.toPlainText();
  expect(text, contains('\n'), reason: 'the bug is a two-line label');
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
  );
  expect(boxes, hasLength(2),
      reason: 'both lines are laid out and painted — this is what the fix has '
          'to keep inside the bubble');

  // Bubble-local, so the static sway rotation cancels out of the comparison.
  final toBubble = paragraph.getTransformTo(bubbleRo);
  Rect? label;
  for (final box in boxes) {
    final a = MatrixUtils.transformPoint(toBubble, Offset(box.left, box.top));
    final b = MatrixUtils.transformPoint(toBubble, Offset(box.right, box.bottom));
    // No Rect.union on this dart:ui — fold the two corners in by hand.
    label = label == null
        ? Rect.fromPoints(a, b)
        : Rect.fromLTRB(
            a.dx < label.left ? a.dx : label.left,
            a.dy < label.top ? a.dy : label.top,
            b.dx > label.right ? b.dx : label.right,
            b.dy > label.bottom ? b.dy : label.bottom,
          );
  }
  return _TooltipGeometry(bubbleRo.size.width, bubbleRo.size.height, label!);
}

/// Boots the shell at [textScale] on a narrow phone and opens the Meal Vault.
Future<AppDatabase> _openVault(WidgetTester tester,
    {required double textScale}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(_narrowPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  await db.appSettingsDao.updateSettings(
    const AppSettingsCompanion(
      isFirstRun: drift.Value(false),
      language: drift.Value(AppLanguagePreference.ar),
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const DailyMealApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
  await tester.pumpAndSettle();
  return db;
}

Future<void> _close(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await db.close();
}
