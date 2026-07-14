/// All user-facing UI text (Arabic).
class AppStrings {
  AppStrings._();

  static const appTitle = 'دفتر الديون';

  // Dashboard
  static const dashboardTitle = 'الرئيسية';
  static const totalOwed = 'إجمالي الديون المستحقة';
  static const clientsCount = 'عدد العملاء';
  static const searchHint = 'ابحث بالاسم أو رقم الهاتف';
  static const noClients = 'لا يوجد عملاء بعد';
  static const noSearchResults = 'لا توجد نتائج مطابقة';

  // Clients
  static const addClient = 'إضافة عميل';
  static const editClient = 'تعديل العميل';
  static const deleteClient = 'حذف العميل';
  static const clientName = 'اسم العميل';
  static const phone = 'رقم الهاتف';
  static const notes = 'ملاحظات';
  static const balance = 'الرصيد';
  static const confirmDeleteClient = 'هل أنت متأكد من حذف هذا العميل؟';
  static const clientHasTransactionsWarning =
      'تحذير: لدى هذا العميل معاملات مسجلة وسيتم حذفها جميعاً.';

  // Transactions
  static const recordDebt = 'تسجيل دين';
  static const recordPayment = 'تسجيل دفعة';
  static const editTransaction = 'تعديل المعاملة';
  static const debt = 'دين';
  static const payment = 'دفعة';
  static const amount = 'المبلغ';
  static const date = 'التاريخ';
  static const note = 'ملاحظة (اختياري)';
  static const noTransactions = 'لا توجد معاملات بعد';
  static const confirmDeleteTransaction =
      'هل أنت متأكد من حذف هذه المعاملة؟';
  static const payDirectly = 'سداد مباشر';
  static const payDirectlyHint =
      'تسجيل دفعة بنفس المبلغ فوراً (الرصيد لا يتغير)';

  // Common
  static const save = 'حفظ';
  static const cancel = 'إلغاء';
  static const delete = 'حذف';
  static const edit = 'تعديل';
  static const confirm = 'تأكيد';
  static const requiredField = 'هذا الحقل مطلوب';
  static const invalidAmount = 'أدخل مبلغاً صحيحاً أكبر من صفر';

  // PIN
  static const enterPin = 'أدخل الرمز السري';
  static const wrongPin = 'رمز خاطئ، حاول مرة أخرى';
  static const createPin = 'أنشئ رمزاً سرياً (4-6 أرقام)';
  static const confirmPin = 'أعد إدخال الرمز السري';
  static const pinMismatch = 'الرمزان غير متطابقين، حاول مجدداً';
  static const currentPin = 'أدخل الرمز الحالي';
  static const newPin = 'أدخل الرمز الجديد';
  static const pinChanged = 'تم تغيير الرمز السري بنجاح';

  // Profile / user name
  static const fullName = 'الاسم الكامل';
  static const nameSetupTitle = 'عرّف عن نفسك';
  static const nameSetupSubtitle =
      'أدخل اسمك الكامل ليظهر بجانب المعاملات التي تسجلها';
  static const continueLabel = 'متابعة';

  // Business setup
  static const businessSetupTitle = 'الانضمام إلى نشاط تجاري';
  static const businessSetupSubtitle =
      'أدخل معرّف النشاط التجاري الذي حصلت عليه من المسؤول لربط هذا الجهاز';
  static const businessIdLabel = 'معرّف النشاط التجاري';
  static const join = 'انضمام';
  static const businessNotFound =
      'المعرّف غير موجود — تأكد من المعرّف مع المسؤول';
  static const connectionError =
      'تعذر الاتصال — تحقق من الإنترنت وحاول مجدداً';

  // Settings
  static const settings = 'الإعدادات';
  static const changePin = 'تغيير الرمز السري';
  static const businessId = 'معرّف النشاط التجاري';
  static const businessIdCopyHint = 'شاركه مع موظف جديد لربط جهازه';
  static const copied = 'تم نسخ المعرّف';
  static const lockTimeout = 'مدة القفل التلقائي';
  static const lockImmediately = 'فوراً';
  static const appVersion = 'إصدار التطبيق';
  static const editLabels = 'تخصيص التسميات';
  static const editLabelsSubtitle =
      'غيّر أسماء الأزرار والمعاملات لتناسب نشاطك (تظهر لجميع الموظفين). اترك الحقل فارغاً للعودة إلى الاسم الافتراضي.';
  static const labelRecordDebt = 'زر تسجيل الدين';
  static const labelRecordPayment = 'زر تسجيل الدفعة';
  static const labelDebt = 'اسم معاملة الدين';
  static const labelPayment = 'اسم معاملة الدفعة';
  static const labelsSaved = 'تم حفظ التسميات';

  static String minutesLabel(int minutes) {
    switch (minutes) {
      case 1:
        return 'دقيقة واحدة';
      case 2:
        return 'دقيقتان';
      default:
        return '$minutes دقائق';
    }
  }
}
