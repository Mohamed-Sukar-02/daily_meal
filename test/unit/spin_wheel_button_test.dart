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
}
