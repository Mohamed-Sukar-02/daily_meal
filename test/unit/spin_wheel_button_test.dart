import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/features/home/presentation/widgets/spin_wheel_button.dart';

void main() {
  Widget buildTestWidget({
    required Widget child,
    Locale locale = const Locale('ar'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('SpinWheelButton renders in Arabic and responds to tap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      buildTestWidget(
        child: SpinWheelButton(
          onTap: () => tapped = true,
          enabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SpinWheelButton), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.tap(find.byType(SpinWheelButton));
    expect(tapped, isTrue);
  });

  testWidgets('SpinWheelButton renders in English and handles disabled state', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      buildTestWidget(
        locale: const Locale('en'),
        child: SpinWheelButton(
          onTap: () => tapped = true,
          enabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SpinWheelButton), findsOneWidget);

    await tester.tap(find.byType(SpinWheelButton));
    // Disabled should not trigger tap callback
    expect(tapped, isFalse);
  });

  testWidgets('EmphasisMarks have fixed outward orientation in both Arabic and English', (tester) async {
    for (final locale in [const Locale('ar'), const Locale('en')]) {
      await tester.pumpWidget(
        buildTestWidget(
          locale: locale,
          child: const SpinWheelButton(enabled: true),
        ),
      );
      await tester.pumpAndSettle();

      final positionedWidgets = tester.widgetList<Positioned>(find.byType(Positioned));
      final leftSparkPos = positionedWidgets.firstWhere((p) => p.left == 8);
      final rightSparkPos = positionedWidgets.firstWhere((p) => p.right == 8);

      expect(leftSparkPos, isNotNull);
      expect(rightSparkPos, isNotNull);

      final leftChild = leftSparkPos.child as dynamic;
      final rightChild = rightSparkPos.child as dynamic;

      // Left spark must not be mirrored (bursts to the left)
      expect(leftChild.mirrored, isFalse);
      // Right spark must be mirrored (bursts to the right)
      expect(rightChild.mirrored, isTrue);
    }
  });
}
