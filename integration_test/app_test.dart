import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aquapath/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Full app flow: Splash -> Onboarding -> Register -> Home',
    (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('AquaPath'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 4));

      expect(find.text('تتبع لحظي'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('إشعارات ذكية'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('يعمل بدون إنترنت'), findsOneWidget);

      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل بيانات الأسرة'), findsOneWidget);

      await tester.tap(find.text('تسجيل البيانات'));
      await tester.pumpAndSettle();

      expect(find.text('AquaPath'), findsOneWidget);
    },
  );
}
