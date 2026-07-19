# AquaPath

تطبيق ذكي لتتبع شاحنات المياه الصالحة للشرب في قطاع غزة لحظة بلحظة.

## الميزات الرئيسية

- تتبع مباشر لمواقع الشاحنات عبر Google Maps
- حساب وقت الوصول (ETA) بخوارزمية تعتمد على المسافة والوقت
- إشعارات ذكية عند اقتراب الشاحنة
- نظام تسجيل الأسر وحساب أولوية التوزيع
- عمل بدون إنترنت (Offline-First) عبر Hive

## البنية المعمارية

- Clean Architecture مع تنظيم Feature-First
- Riverpod لإدارة الحالة
- get_it لحقن التبعيات (Manual DI، بدون code generation)
- Firebase (Firestore) كمصدر بيانات حي
- Hive للتخزين المحلي والعمل دون اتصال

## التشغيل

```bash
flutter pub get
flutter run
```

> ملاحظة: يجب استبدال القيم الوهمية في `lib/firebase_options.dart` بقيم
> مشروعك الحقيقي على Firebase، واستبدال `YOUR_GOOGLE_MAPS_API_KEY` في
> `android/app/src/main/AndroidManifest.xml` بمفتاح خرائط Google صالح.

## الاختبارات

```bash
flutter test --coverage
```

## متطلبات تقنية

- Flutter 3.16+ / Dart 3.2+
- Minimum SDK: Android 6.0 (API 23)
- Target SDK: Android 15 (API 35)
