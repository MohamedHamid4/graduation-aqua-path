# AquaPath — دليل تشغيلي: إنشاء أول حساب مؤسسة (Bootstrap)

هذا الإجراء **يُنفَّذ مرة واحدة فقط** لكل بيئة (development / staging / production) — بعد ذلك، كل حساب مؤسسة إضافي يُنشأ من داخل التطبيق عبر Cloud Function `createOrganizationUser` (تتطلب أن يكون المستدعي مسجّلاً دخوله بالفعل كحساب مؤسسة، لذا لا يمكن استخدامها لأول حساب).

## لماذا لا يوجد مسار داخل التطبيق لهذا؟

لأن `createOrganizationUser` نفسها تتحقق من `request.auth.token.role == 'organization'` قبل تنفيذ أي شيء — وهذا يعني عمليًا "لا يمكن إنشاء أول حساب مؤسسة إلا من قبل حساب مؤسسة موجود مسبقًا"، وهو تناقض منطقي لأول حساب. هذا قرار أمني مقصود: منع أي مسار تسجيل ذاتي لأعلى صلاحية في النظام.

## المتطلبات المسبقة

- صلاحية IAM على مشروع Firebase تخوّلك استخدام Firebase Admin SDK (عادة: Owner أو Editor).
- Node.js مثبت محليًا.
- بيانات الدخول (Service Account key) لمشروع Firebase — **يجب عدم رفع هذا الملف لأي مستودع Git**.

## الخطوات

### 1. تحميل مفتاح حساب الخدمة (Service Account)

من Firebase Console → Project Settings → Service Accounts → Generate New Private Key. احفظ الملف محليًا (مثلاً `serviceAccountKey.json`) خارج مجلد المشروع تمامًا.

### 2. تشغيل سكربت التمهيد لمرة واحدة

من داخل مجلد `functions/`:

```bash
npm install firebase-admin --no-save
node -e "
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require('/المسار/الكامل/إلى/serviceAccountKey.json')),
});

(async () => {
  // إنشاء حساب Firebase Auth للمؤسسة
  const user = await admin.auth().createUser({
    email: 'admin@aquapath.example',
    password: 'REPLACE_WITH_A_STRONG_PASSWORD',
  });

  // منح صلاحية organization عبر custom claim — هذا هو السطر الحاسم
  await admin.auth().setCustomUserClaims(user.uid, { role: 'organization' });

  // إنشاء وثيقة الملف الشخصي في Firestore
  await admin.firestore().collection('organizations').doc(user.uid).set({
    orgName: 'AquaPath Operations',
    contactEmail: 'admin@aquapath.example',
    contactPhone: '',
    createdAt: new Date().toISOString(),
    createdBy: 'bootstrap-script',
  });

  console.log('تم إنشاء أول حساب مؤسسة بنجاح — uid:', user.uid);
  process.exit(0);
})();
"
```

### 3. التحقق

سجّل الدخول من شاشة `/org/login` داخل التطبيق بالبريد وكلمة المرور المستخدَمين أعلاه. يجب أن تصل مباشرة إلى `OrgDashboardScreen`.

### 4. بعد التحقق

- احذف `serviceAccountKey.json` من أي مكان محلي لم يعد بحاجته.
- غيّر كلمة المرور المؤقتة من داخل التطبيق أو عبر Firebase Console فور أول تسجيل دخول.
- من الآن فصاعدًا، استخدم هذا الحساب لإنشاء أي حساب مؤسسة إضافي عبر واجهة `createOrganizationUser` من داخل التطبيق (تحتاج شاشة إدارة مخصصة لذلك — غير موجودة بعد، انظر قائمة أعمال P2/P3).

## ملاحظة أمنية

لا تُبقِ مفتاح Service Account على أي جهاز أو مستودع بعد إتمام هذا الإجراء. إن أُنشئت بيئات متعددة (staging/production)، كرّر هذا الإجراء بمفتاح Service Account خاص بكل بيئة على حدة — لا تُعِد استخدام نفس المفتاح بين بيئتين.
