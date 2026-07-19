import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquapath/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding shows first page content',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );
    await tester.pump();

    expect(find.text('تتبع لحظي'), findsOneWidget);
    expect(find.text('تخطي'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
  });
}
