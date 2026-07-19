# AquaPath — Code Audit Report
**تاريخ المراجعة:** 2026-07-19  
**المراجع:** Claude Sonnet 4.6  
**الملفات المفحوصة:** كل ملفات `lib/` (114 ملف Dart) + `pubspec.yaml` + `AndroidManifest.xml` + `google-services.json`

---

## 1. فهم المشروع

### ما يفعله المشروع
AquaPath تطبيق لتتبع شاحنات المياه في قطاع غزة في الوقت الفعلي. يخدم ثلاثة أنواع مستخدمين:
- **مستفيد (Resident):** يرى مواقع الشاحنات على الخريطة، يتابع ETA، يسجل بيانات أسرته، يستقبل إشعارات توزيع المياه.
- **سائق (Driver):** يُدير رحلات التوزيع، يشارك موقعه الحي، يسجّل كميات التوزيع.
- **مؤسسة (Organization):** لوحة تحكم لإدارة السائقين والأسر والمناطق والشاحنات والجداول الزمنية، مراقبة حية، تقارير.

### الـ Architecture
**Clean Architecture + Feature-First** — مُطبَّق بشكل جيد:
```
lib/
├── core/           ← أدوات مشتركة (router, errors, theme, security, logging)
├── features/       ← 16 feature كل منها يحتوي data/domain/presentation
└── shared/         ← models وservices وwidgets مشتركة بين features
```

### الـ State Management
**Riverpod (v2) + GetIt Hybrid:**
- Riverpod: لحالة الواجهة (StreamProvider, FutureProvider, NotifierProvider)
- GetIt: لحقن الاعتماديات (repositories, services, data sources)
- النمط مقصود ومبرَّر — ليس اختلاطاً عشوائياً

### الـ Packages
| الحزمة | الإصدار | الحالة |
|--------|---------|--------|
| flutter_riverpod | ^2.5.1 | حديث ✅ |
| go_router | ^14.2.7 | حديث ✅ |
| firebase_* | ^3–5 | حديث ✅ |
| hive_flutter | ^1.1.0 | مستقر، لكن Isar أحدث للبدائل |
| dartz | ^0.10.1 | يعمل، لكن مهجور نسبياً (فريق Dart ينصح بـ Result pattern بدلاً منه) |
| flutter_screenutil | ^5.9.3 | حديث ✅ |
| iconsax | ^0.0.8 | لم أجد له استخداماً في الكود المقروء |
| logger | ^2.4.0 | حديث ✅ |
| equatable | ^2.0.5 | حديث ✅ |

### تدفق البيانات
```
User Action (Widget)
    → Riverpod Notifier / Provider
        → Repository (domain interface)
            → Firebase Source / Local Source (Hive)
                ↔ Firestore / SecureStorage / Hive
    ← Either<Failure, T>
        ← UI يتعامل مع fold()
```

---

## 2. طريقة كتابة الكود

### نقاط إيجابية
- **نمط تسمية ثابت:** snake_case للملفات، PascalCase للكلاسات، camelCase للمتغيرات — لا استثناءات.
- **الـ DTO/Domain separation** محترمة في كل feature (TruckDto ↔ Truck، ParkingSpotDto ↔ ParkingSpot).
- **Controllers مُدارة بشكل صحيح:** dispose() في كل StatefulWidget فيه controller.
- **الـ Timers مُلغاة** في dispose() في DriverLocationNotifier.
- **Inline comments تشرح الـ WHY** وليس الـ WHAT — مستوى ممتاز للتوثيق.
- **لا تكرار في المنطق الأساسي** — EtaService, GeoUtils, OfflineWriteQueueService كل منها في مكان واحد.

### نقاط ضعف في أسلوب الكود
- **`_timeAgo` مكرر في 3 أماكن** (تفاصيل في قسم المشاكل).
- **Widgets ضخمة في بعض الشاشات:** `driver_schedule_screen.dart` يحتوي `_RouteCard`, `_WaterDistributionStatsCard`, `_StatRow` كلها في نفس الملف — كانت تستحق ملف مستقل.
- **`registration_screen.dart`** يحتوي 5 classes مختلفة (RegistrationErrorBanner, _HeaderCard, RegistrationAreaDropdown, RegistrationCounterWidget, RegistrationSwitchTile) — بعضها قابل لإعادة الاستخدام ويستحق أن يكون في `core/widgets/`.
- **الفصل بين المنطق والواجهة ممتاز** في أغلب الشاشات — المنطق في Notifiers والواجهة في Widgets فقط.

---

## 3 + 4. المشاكل والثغرات

---

### 🔴 خطير

---

#### [C-1] مفاتيح API مكشوفة في سورس كود مُتتبَّع بـ Git

**الملفات:**
- `lib/firebase_options.dart:23` — مفتاح Firebase API: `AIzaSyDjIjr-t6liXDdf8DqoUuek233sCpDqwGw`
- `android/app/google-services.json:17` — نفس المفتاح
- `android/app/src/main/AndroidManifest.xml:39` — مفتاح Google Maps API: `AIzaSyAyFT3HMBXZfMCa34A53TRujnjrS3AssKE`

**المشكلة:**  
المفاتيح مرئية لأي شخص يملك الكود. مفتاح Firebase Android محمي نسبياً بـ package name و SHA fingerprint، لكن مفتاح Maps غير مقيَّد ظاهرياً (لا يوجد تقييد بـ Android App Restriction). أي شخص يأخذ المفتاح يمكنه استخدام Google Maps بلا حدود على حساب صاحب المشروع.

**لماذا هو مشكلة:**  
- مفتاح Maps بلا قيود → فاتورة Google Cloud غير متوقعة.
- مفتاح Firebase → يُمكّن المهاجم من إرسال طلبات Firebase Auth إذا لم تكن قواعد Firestore مغلقة.

**الحل:**
1. **Maps:** اذهب إلى Google Cloud Console → قيّد المفتاح بـ `Android apps` مع package name `com.aquapath.app` و SHA-1 fingerprint.
2. **Firebase:** `google-services.json` للـ Android عادةً مقبول بالـ commit (فهو مخصص لمعرّف التطبيق)، لكن تأكد من Firestore Security Rules المغلقة (انظر C-2).
3. أضف `*.jks` و `local.properties` لـ `.gitignore` إذا لم يكونوا موجودين.

---

#### [C-2] لا يوجد ملف Firestore Security Rules في المشروع

**الملف المتوقع:** `firestore.rules` (غير موجود)

**المشكلة:**  
لا يوجد في مجلد المشروع أي ملف `firestore.rules` أو `firebase.json`. هذا يعني إما:
- القواعد مكتوبة مباشرة في Firebase Console (غير متتبَّعة)، أو
- القواعد لا تزال على الإعداد الافتراضي (مفتوحة كلياً أو مغلقة كلياً)

إذا كانت القواعد مفتوحة، فإن `OrganizationFirebaseSource` يقرأ **كل الأسر** و**كل السائقين** و**كل المناطق** بدون تحقق من صلاحيات. أي مستخدم مسجّل يمكنه قراءة بيانات الأسر الضعيفة (مرضى، كبار سن، أطفال).

**لماذا هو مشكلة:**  
بيانات الأسر تحتوي على `hasElderly`, `hasSick`, `hasChildren` — معلومات حساسة. تسريبها ينتهك الخصوصية ويضر بالمستفيدين في بيئة حرب.

**الحل:**
```javascript
// firestore.rules — مثال على قواعد صحيحة
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // المستخدم يقرأ فقط أسرته
    match /households/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    // السائق يقرأ/يكتب بياناته فقط
    match /drivers/{uid} {
      allow read, write: if request.auth.uid == uid;
      allow read: if request.auth.token.role == 'organization';
    }
    // الشاحنات مفتوحة للقراءة للمستفيدين، للكتابة للسائق صاحبها فقط
    match /trucks/{truckId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == truckId;
    }
    // المؤسسة فقط تقرأ/تكتب كل شيء
    match /{document=**} {
      allow read, write: if request.auth.token.role == 'organization';
    }
  }
}
```
أضف `firestore.rules` للـ repo وتتبّعه مع الكود.

---

#### [C-3] تعطيل السائق لا يُلغي صلاحية الدخول فعلياً

**الملف:** `lib/features/organization/data/datasources/organization_firebase_source.dart:101-103`

```dart
Future<void> setDriverStatus(String driverUid, String status) async {
  await _driversRef.doc(driverUid).update({'status': status}); // ← فقط هذا!
}
```

**المشكلة:**  
التعليق في الكود يقول "يجب إلغاء تفعيل حساب Firebase Auth عبر Cloud Function"، لكن لا يوجد استدعاء للـ Cloud Function في هذا الكود. يُعطَّل السائق في قاعدة البيانات لكن يمكنه تسجيل الدخول وبدء رحلات فعلياً.

**لماذا هو مشكلة:**  
السائق "المعطّل" يبقى قادراً على الوصول الكامل للتطبيق، مشاركة موقعه، وتسجيل توزيعات مياه.

**الحل:**
```dart
// في driver_management_screen.dart عند الضغط على "تعطيل"
// استدعاء Firebase Callable Function
final callable = FirebaseFunctions.instance.httpsCallable('setDriverStatus');
await callable.call({'uid': driverUid, 'disabled': true});
// ثم تحديث Firestore
await _orgRepo.setDriverStatus(driverUid, 'disabled');
```

---

#### [C-4] تسجيل الأخطاء معطّل كلياً في الإنتاج

**الملف:** `lib/core/logging/app_logger.dart:51-54`

```dart
class _ReleaseOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // TODO: forward to Firebase Crashlytics.  ← لم يُنفَّذ
  }
}
```

**المشكلة:**  
في release mode، كل الـ warnings والـ errors والـ fatals تختفي في الفراغ. لو انهار التطبيق على جهاز مستخدم، لن تعرف شيئاً عنه.

**لماذا هو مشكلة:**  
مشروع تخرّج يُقدَّم: الأستاذ إذا سأل "كيف تتعامل مع الأخطاء في الإنتاج؟" — الإجابة الحالية هي "لا نعرف عنها شيئاً".

**الحل:**
```dart
// في pubspec.yaml: أضف firebase_crashlytics: ^4.1.0
// ثم في _ReleaseOutput:
@override
void output(OutputEvent event) {
  if (event.level.index >= Level.warning.index) {
    FirebaseCrashlytics.instance.log(event.lines.join('\n'));
  }
  if (event.level.index >= Level.error.index) {
    FirebaseCrashlytics.instance.recordError(
      event.lines.join('\n'),
      null,
      fatal: event.level == Level.fatal,
    );
  }
}
```

---

#### [C-5] لا يوجد server-side validation لكميات التوزيع

**الملف:** `lib/features/driver/presentation/driver_route_map_screen.dart:473-476`

```dart
final amount = double.tryParse(amountCtrl.text.trim());
if (amount == null || amount <= 0) return;  // ← validation بسيط جداً
```

**المشكلة:**  
السائق يمكنه تسجيل 999,999 لتر أو 0.0001 لتر. لا يوجد حد أقصى منطقي. الـ `FieldValue.increment` في Firestore يقبل أي قيمة.

**لماذا هو مشكلة:**  
يمكن التلاعب بالإحصاءات وتقارير المؤسسة بشكل كامل.

**الحل:**
```dart
// client-side
final amount = double.tryParse(amountCtrl.text.trim());
const maxDelivery = 15000.0; // أكبر من أكبر شاحنة متوقعة
if (amount == null || amount <= 0 || amount > maxDelivery) {
  // أظهر خطأ واضح
  return;
}
// server-side: يجب إضافة Firestore rule تمنع currentLoad من الانخفاض تحت 0
```

---

### 🟡 متوسط

---

#### [M-1] `withOpacity()` مُهمَل وتم استبداله بـ `withValues(alpha:)` في Flutter 3.x

**الملفات المتأثرة:**
- `driver_schedule_screen.dart:204, 261, 342, 347`
- `registration_screen.dart:211, 229, 311, 492, 497, 506`
- `live_monitoring_screen.dart` (عدة أسطر)
- و3 ملفات أخرى

**مثال:**
```dart
// قديم — يُنتج deprecation warning
color: AppColors.success.withOpacity(0.4)

// صحيح
color: AppColors.success.withValues(alpha: 0.4)
```

**المشكلة:** في بعض أجزاء الكود يُستخدَم الأسلوب الجديد (`.withValues(alpha:)`) وفي أجزاء أخرى القديم. عدم اتساق + تحذيرات مستقبلية.

---

#### [M-2] دائرة نصف قطر الإشعارات مثبّتة على مركز غزة بدلاً من موقع المستخدم

**الملف:** `lib/features/map/presentation/map_screen.dart:131-138`

```dart
circles: {
  Circle(
    circleId: const CircleId('userRadius'),
    center: _gazaCenter,  // ← دائماً مركز غزة!
    radius: notificationRadius.toDouble(),
    ...
  ),
},
```

**المشكلة:** الدائرة يُفترض أن تظهر حول موقع المستخدم الفعلي، لكنها مُثبَّتة على `LatLng(31.5018, 34.4668)`. مستخدم في شمال غزة يرى الدائرة في الجنوب.

**الحل:**
```dart
// استخدم userLocationProvider الموجود أصلاً
final locAsync = ref.watch(userLocationProvider);
final center = locAsync.valueOrNull != null
    ? LatLng(locAsync.valueOrNull!.lat, locAsync.valueOrNull!.lng)
    : _gazaCenter;

circles: {
  Circle(
    center: center,
    ...
  ),
},
```

---

#### [M-3] زر "موقعي" في شاشة الخريطة ديكور لا يعمل

**الملف:** `lib/features/map/presentation/map_screen.dart:155-188`

```dart
Positioned(
  bottom: 165.h,
  right: 16.w,
  child: Container(  // ← Container بدون GestureDetector!
    ...
    child: Icon(Icons.my_location_rounded, ...),
  ),
),
```

**المشكلة:** الزر مرسوم لكنه لا يفعل شيئاً عند الضغط عليه. المستخدم يضغطه ويتوقع أن الخريطة تنتقل لموقعه.

**الحل:**
```dart
GestureDetector(
  onTap: () async {
    final controller = await _mapController.future;
    final loc = ref.read(userLocationProvider).valueOrNull;
    if (loc != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(loc.lat, loc.lng)),
      );
    }
  },
  child: Container(...),
),
```

---

#### [M-4] رسالة `unsubscribeFromArea` تحتوي double prefix في الـ log

**الملف:** `lib/shared/services/push_notification_service.dart:96`

```dart
Future<void> unsubscribeFromArea(String areaName) async {
  final topic = 'area_${topicSuffixFor(areaName)}';
  await _messaging.unsubscribeFromTopic(topic);
  AppLogger.info('Unsubscribed from FCM topic: area_$topic', tag: 'FCM');
  //                                              ^^^^^^^^^^^^
  //  topic هو أصلاً 'area_XXXX' — النتيجة: 'area_area_XXXX'
}
```

**المشكلة:** bug في رسالة اللوج فقط (الـ unsubscribe نفسه يعمل بشكل صحيح لأن `topic` المُرسَل للـ API صحيح).

**الحل:**
```dart
AppLogger.info('Unsubscribed from FCM topic: $topic', tag: 'FCM');
```

---

#### [M-5] الإشعارات في الـ foreground تُسقَط دون أي تفاعل مع المستخدم

**الملف:** `lib/shared/services/push_notification_service.dart:57-63`

```dart
void _onForegroundMessage(RemoteMessage message) {
  AppLogger.info(
    'Foreground FCM: ${message.notification?.title}',
    tag: 'FCM',
  );
  // ← تنتهي هنا! لا يُظهَر للمستخدم شيء
}
```

**المشكلة:** إشعارات "شاحنتك قريبة" تصل وقت فتح التطبيق وتختفي صامتة.

**الحل:** استخدم `flutter_local_notifications` لعرض in-app notification banner، أو افتح SnackBar عبر GlobalKey أو NavigatorKey.

---

#### [M-6] `getTrucksStream()` عند الوضع الأوفلاين يُكمل Stream بدل أن يبقى مفتوحاً

**الملف:** `lib/features/trucks/data/repositories/truck_repository_impl.dart:23-43`

```dart
Stream<Either<Failure, List<Truck>>> getTrucksStream() async* {
  final connected = await connectivityService.isConnected;

  if (connected) {
    yield* firebaseSource.getTrucksStream().map((_) { ... });
  } else {
    final cachedMaps = localSource.getCachedTrucks();
    yield Right<Failure, List<Truck>>(trucks); // ← yield مرة واحدة ثم ينتهي
  }
}
```

**المشكلة:** لو كان الجهاز أوفلاين عند فتح التطبيق، يُعاد الكاش مرة واحدة والـ stream يكتمل. الـ `StreamProvider` في Riverpod يصبح في حالة `data` ولا تصله أي تحديثات لاحقة — حتى لو عاد الاتصال.

**لماذا هو مشكلة:**  
الأوفلاين كاش يعمل، لكن المستخدم لو أغلق وأعاد فتح التطبيق عند الأوفلاين ثم عاد الإنترنت، لا يرى التحديثات.

**الحل:** 
```dart
// أبسط حل: حوّل الـ offline case لـ stream أيضاً باستخدام Stream.value
} else {
  yield Right<Failure, List<Truck>>(trucks);
  // لا تغلق — انتظر connectivity ثم أعد المحاولة
  // (أو استخدم switchMap على ConnectivityService.onConnectivityChanged)
}
```

---

#### [M-7] تحقق البريد الإلكتروني غير مُفعَّل

**الملف:** `lib/features/auth/data/datasources/firebase_auth_source.dart:121`

```dart
return AppUser(
  uid: user.uid,
  email: user.email,
  displayName: user.displayName,
  emailVerified: user.emailVerified, // ← يُخزَّن لكن لا يُفحَص أبداً
  role: role,
);
```

**المشكلة:** `emailVerified` موجود في `AppUser` لكن لا أحد يتحقق منه في أي Router redirect أو Guard. مستخدم بإيميل مزيّف يدخل التطبيق مباشرة.

**الحل (اختياري لكن موصى):**  
في `app_router.dart` redirect، بعد تأكيد الـ role:
```dart
if (role == UserRole.resident && !authRepo.currentUser!.emailVerified) {
  return '/verify-email'; // شاشة جديدة تطلب من المستخدم التحقق
}
```

---

#### [M-8] `_timeAgo` مكرر في 3 أماكن

**الملفات:**
- `lib/features/map/presentation/map_screen.dart:776-780` (داخل `_ParkingSpotDetailSheet`)
- `lib/features/driver/presentation/driver_route_map_screen.dart:70-75`  
- `lib/features/organization/presentation/live_monitoring_screen.dart:217-222`

**المشكلة:** نفس المنطق بصياغات مختلفة طفيفة. لو أُريد تغيير التنسيق ("منذ X دقيقة" ← "قبل X دقيقة") يجب التغيير في 3 أماكن.

**الحل:**
```dart
// في lib/core/utils/extensions.dart — الملف موجود أصلاً، أضف فيه:
extension DateTimeArabicExt on DateTime {
  String toArabicTimeAgo() {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'منذ ${diff.inSeconds} ثانية';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}
// الاستخدام: spot.lastStoppedAt.toArabicTimeAgo()
```

---

#### [M-9] `EtaService._trafficFactor()` يستخدم timezone الجهاز لا توقيت غزة

**الملف:** `lib/shared/services/eta_service.dart:45-50`

```dart
double _trafficFactor() {
  final hour = DateTime.now().hour; // ← timezone الجهاز!
  if (hour >= 6 && hour < 10) return 0.90;
  ...
}
```

**المشكلة:** لو جهاز المستخدم مضبوط على توقيت مختلف (مثلاً GMT+0 بدل GMT+3)، عامل الازدحام يكون خاطئاً.

**الحل:**
```dart
final hour = DateTime.now().toUtc().add(const Duration(hours: 3)).hour; // Gaza = UTC+3
```

---

### 🟢 بسيط

---

#### [L-1] مجلدات Assets مُعلَنة في pubspec لكن فارغة

**الملف:** `pubspec.yaml:72-73`

```yaml
assets:
  - assets/images/    # ← فيها ملفين فقط
  - assets/icons/     # ← فارغة على الأرجح
  - assets/animations/ # ← فارغة على الأرجح
```

لا توجد أي ملفات icons أو animations مستخدمة في الكود المقروء. إذا كانت فعلاً فارغة، احذف التصريح أو أضف الملفات.

---

#### [L-2] `iconsax` package معلَن لكن غير مستخدم ظاهرياً

**الملف:** `pubspec.yaml:49`

لم أجد أي `import 'package:iconsax/iconsax.dart'` في الكود المقروء. تحقق وأزل إذا لم يكن مستخدماً.

```bash
# للتحقق
grep -r "iconsax" lib/
```

---

#### [L-3] تنسيق `driver_schedule_screen.dart` مكسور في أسطر 107-113

**الملف:** `lib/features/driver/presentation/driver_schedule_screen.dart:107-113`

```dart
      ),  // ← تتابع مُشوَّه
    ),]   // ← ],  في نفس السطر
    ,
    )
    ,
    );
```

الكود يعمل لكنه غير قابل للقراءة. يحتاج `dart format .`

---

#### [L-4] نص عربي مُضمَّن مباشرة في بعض الشاشات بدلاً من AppStrings

**أمثلة:**
- `login_screen.dart:406`: `child: Text('إغلاق', ...)` — بدون AppStrings
- `live_monitoring_screen.dart:289`: `'مواقف بانتظار الاعتماد (${pending.length})'`
- `driver_route_map_screen.dart:131,302`: نصوص inline عديدة

المشروع يمتلك `AppStrings` جيد لكنه لم يُكتمَل في كل الشاشات.

---

#### [L-5] `_ReleaseOutput` التعليق TODO موجود منذ بداية المشروع

**الملف:** `lib/core/logging/app_logger.dart:52`

سبق ذكره في [C-4] — مُدرَج هنا كتذكير إضافي.

---

#### [L-6] نمط closing brace متقطع في `map_screen.dart` بين `_ParkingSpotDetailSheet` والـ class قبلها

**الملف:** `lib/features/map/presentation/map_screen.dart:706-707`

```dart
}  // ← نهاية _QuickTruckSheet بدون سطر فاصل
/// Detail sheet shown when...
class _ParkingSpotDetailSheet extends StatelessWidget {
```

استحسان: أضف سطراً فارغاً بين الكلاسات.

---

## ملخص

### نقاط القوة
1. **Architecture ممتاز** — Clean Architecture مُطبَّق بشكل صحيح ومتسق بدون استثناءات واضحة.
2. **Error handling شامل** — `Either<Failure, T>` في كل repository، `GlobalExceptionHandler` مُركَّب بشكل صحيح، Zone guard في `main()`.
3. **الأوفلاين queue مدروس** — `OfflineWriteQueueService` مع تحليل واضح لمتى يُستخدَم ومتى لا (تعليق QueuedWrite ممتاز).
4. **Auth flow متطور** — Role-based routing مع JWT claims، fallback للـ pending role، retry loop للـ claim propagation.
5. **Driver location broadcasting** — foreground service + position stream + parking stop detection كل هذا في كلاس واحد منظم.
6. **FCM topic encoding** للأسماء العربية — حل ذكي ومُوثَّق مع ملاحظة ضرورة مطابقته مع Cloud Function.
7. **التوثيق الداخلي** — التعليقات تشرح الـ WHY وتُشير للـ trade-offs — مستوى professional.

### أخطر 5 مشاكل قبل التسليم

| # | المشكلة | الملف | الخطورة |
|---|---------|-------|---------|
| 1 | **Firestore Security Rules غائبة** — كل البيانات قابلة للوصول لأي مستخدم | `firestore.rules` (غير موجود) | 🔴🔴 |
| 2 | **Google Maps API key بدون قيود** — خطر فاتورة مفتوحة | `AndroidManifest.xml:39` | 🔴 |
| 3 | **تعطيل السائق لا يمنعه من الدخول** — فجوة أمنية وظيفية | `organization_firebase_source.dart:102` | 🔴 |
| 4 | **لا logging في الإنتاج** — الأخطاء تختفي صامتة | `app_logger.dart:51` | 🔴 |
| 5 | **لا validation لكمية التوزيع من الـ server** — قابلة للتلاعب | `driver_route_map_screen.dart:473` | 🔴 |

---

### التقييم العام

```
Architecture & Design:      9/10  ← Clean Architecture مُطبَّق بامتياز
Code Quality & Style:       8/10  ← نمط ثابت، توثيق ممتاز، بعض التكرار
Error Handling:             7/10  ← ممتاز في Dart، معدوم في الإنتاج
Security:                   4/10  ← keys مكشوفة، Firestore rules غائبة
Feature Completeness:       8/10  ← المشروع يعمل كاملاً مع ميزات متقدمة
Performance:                7/10  ← بعض مشاكل الـ stream والـ rebuilds
```

### **التقييم الكلي: 7.2 / 10**

المشروع يُظهر مستوى تقني عالياً لمشروع تخرّج — الـ architecture واضح، الكود مُنظَّم، والقرارات الصعبة (أوفلاين queue، role claims، FCM Arabic topics) مُفكَّر فيها جيداً. المشكلة الأساسية هي **الأمان الخلفي**: مفاتيح API مكشوفة وغياب Firestore Security Rules هما الخطران الوحيدان اللذان يمكن أن يُلغيا كل ما بُني بعناية. أصلِح هذين قبل التسليم.