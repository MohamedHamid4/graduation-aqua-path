import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquapath/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays app name and logo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    await tester.pump();

    expect(find.text('AquaPath'), findsOneWidget);
    expect(find.text('طريقك إلى المياه'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('SplashScreen shows loading indicator',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
