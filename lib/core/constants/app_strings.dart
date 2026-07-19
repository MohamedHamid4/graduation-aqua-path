abstract final class AppStrings {
  static const appName = 'AquaPath';
  static const appTagline = 'طريقك إلى المياه';
  static const appDescription = 'تتبع شاحنات المياه في قطاع غزة لحظة بلحظة';

  // ── Onboarding ────────────────────────────────────────────────────────
  static const onboardingSkip = 'تخطي';
  static const onboardingNext = 'التالي';
  static const onboardingStart = 'ابدأ الآن';
  static const onboarding1Title = 'تتبع لحظي';
  static const onboarding1Desc =
      'شاهد مواقع شاحنات المياه على الخريطة\nفي الوقت الحقيقي ومعرفة المسافة الباقية';
  static const onboarding2Title = 'إشعارات ذكية';
  static const onboarding2Desc =
      'تلقَّ إشعاراً فورياً عندما تقترب\nشاحنة المياه من منزلك';
  static const onboarding3Title = 'يعمل بدون إنترنت';
  static const onboarding3Desc =
      'يعرض آخر معلومات متاحة عن الشاحنات\nحتى عند انقطاع الاتصال';

  // ── Registration ──────────────────────────────────────────────────────
  static const regTitle = 'تسجيل بيانات الأسرة';
  static const regHeaderTitle = 'بيانات الأسرة';
  static const regHeaderSubtitle = 'سجّل بيانات أسرتك لتصلك المياه أولاً';
  static const regAreaLabel = 'المنطقة السكنية';
  static const regSizeLabel = 'عدد أفراد الأسرة';
  static const regDaysLabel = 'أيام منذ آخر توصيل';
  static const regVulnerabilityLabel = 'الأوضاع الخاصة';
  static const regSubmit = 'تسجيل البيانات';

  // ── Auth ──────────────────────────────────────────────────────────────
  static const loginTitle = 'تسجيل الدخول';
  static const loginSubtitle = 'مرحباً بعودتك إلى AquaPath';
  static const loginButton = 'تسجيل الدخول';
  static const forgotPassword = 'نسيت كلمة المرور؟';
  static const noAccount = 'ليس لديك حساب؟';
  static const createAccount = 'إنشاء حساب';
  static const orgLoginEntry = 'دخول حسابات المؤسسة';

  static const signupTitle = 'إنشاء حساب جديد';
  static const signupSubtitle = 'انضم إلى AquaPath لتتبع شاحنات المياه';
  static const signupButton = 'إنشاء الحساب';
  static const haveAccount = 'لديك حساب بالفعل؟';
  static const goToLogin = 'تسجيل الدخول';

  static const fullNameLabel = 'الاسم الكامل';
  static const fullNameHint = 'أدخل اسمك الكامل';
  static const emailLabel = 'البريد الإلكتروني';
  static const emailHint = 'example@email.com';
  static const passwordLabel = 'كلمة المرور';
  static const passwordHint = 'أدخل كلمة المرور';
  static const confirmPasswordLabel = 'تأكيد كلمة المرور';
  static const confirmPasswordHint = 'أعد إدخال كلمة المرور';

  static const resetPasswordTitle = 'استعادة كلمة المرور';
  static const resetPasswordDesc =
      'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة تعيين كلمة المرور';
  static const resetPasswordButton = 'إرسال رابط الاستعادة';
  static const resetPasswordSent =
      'تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني';

  // ── Common ────────────────────────────────────────────────────────────
  static const active = 'نشطة';
  static const idle = 'متوقفة';
  static const eta = 'وقت الوصول';
  static const distance = 'المسافة';
  static const load = 'الحمولة';
  static const speed = 'السرعة';
  static const closeButton = 'إغلاق';
  static const confirm = 'تأكيد';

  // ── Notifications ─────────────────────────────────────────────────────
  static const notificationsTitle = 'الإشعارات';
  static const notificationsMarkAllRead = 'قراءة الكل';
  static const notificationsEmpty = 'لا توجد إشعارات بعد';
  static const notificationsAll = 'الكل';
  static const notificationsUnread = 'غير مقروءة';

  // ── Driver ────────────────────────────────────────────────────────────
  static const resumeTrip = 'استئناف';
  static const pauseTrip = 'إيقاف مؤقت';
  static const confirmDelivery = 'تأكيد تسليم';

  // ── Settings ──────────────────────────────────────────────────────────
  static const settingsTitle = 'حسابي';
  static const settingsGeneral = 'الإعدادات العامة';
  static const settingsFamily = 'بيانات الأسرة';
  static const settingsAbout = 'حول';
  static const settingsNotifications = 'إعدادات الإشعارات';
  static const settingsNotificationsSubtitle = 'إدارة تنبيهات الشاحنات';
  static const settingsRadius = 'منطقة الإشعارات';
  static const settingsEditFamily = 'تعديل بيانات الأسرة';
  static const settingsEditFamilySubtitle = 'المنطقة، عدد الأفراد، الاحتياجات';
  static const settingsHistory = 'سجل التوصيلات';
  static const settingsHistorySubtitle = 'آخر توصيل: أمس';
  static const settingsAboutApp = 'عن AquaPath';
  static const settingsHelp = 'المساعدة والدعم';
  static const settingsHelpSubtitle = 'الأسئلة الشائعة';
  static const settingsLogout = 'تسجيل الخروج';

  // ── Organization: Reports export ────────────────────────────────────────
  static const reportsExportTitle = 'تصدير التقرير';
  static const reportsExportCsvLabel = 'CSV';
  static const reportsExportCsvDesc = 'ملف نصي بسيط، يفتح في Excel أو Sheets';
  static const reportsExportPdfLabel = 'PDF';
  static const reportsExportPdfDesc = 'مستند جاهز للعرض والطباعة';
  static const reportsExportExcelLabel = 'Excel';
  static const reportsExportExcelDesc = 'جدول بيانات ‎.xlsx بأعمدة رقمية';

  // ── Areas ─────────────────────────────────────────────────────────────
  static const List<String> gazaAreas = [
    'الشجاعية',
    'الزيتون',
    'الدرج',
    'الرمال',
    'جباليا',
    'بيت لاهيا',
    'بيت حانون',
    'خان يونس',
    'رفح',
    'المغازي',
    'النصيرات',
    'دير البلح',
  ];
}
