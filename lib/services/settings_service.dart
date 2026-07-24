import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/config/brand.dart';

class SettingsService extends ChangeNotifier {
  String _language = 'en';
  ThemeMode _themeMode = ThemeMode.light;
  Color _accentColor = Brand.primary;
  List<Map<String, String>> _rememberedAccounts = [];
  String _currentRole = '';

  String get language => _language;
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  List<Map<String, String>> get rememberedAccounts => _rememberedAccounts;
  String get currentRole => _currentRole;
  set currentRole(String role) {
    _currentRole = role;
    notifyListeners();
  }

  static const _langKey = 'language';
  static const _themeKey = 'theme';
  static const _accentKey = 'accent';
  static const _accountsKey = 'accounts';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_langKey) ?? 'en';
    final themeStr = prefs.getString(_themeKey) ?? 'light';
    _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final accentStr = prefs.getInt(_accentKey) ?? Brand.primary.toARGB32();
    _accentColor = Color(accentStr);
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson != null) {
      _rememberedAccounts = (accountsJson.split('|').where((s) => s.isNotEmpty).map((s) {
        final parts = s.split(',');
        if (parts.length >= 2) return {'email': parts[0], 'name': parts[1]};
        return {'email': parts[0], 'name': parts[0]};
      })).toList();
    }
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
  }

  Future<void> addAccount(String email, String name) async {
    _rememberedAccounts.removeWhere((a) => a['email'] == email);
    _rememberedAccounts.insert(0, {'email': email, 'name': name});
    notifyListeners();
    await _saveAccounts();
  }

  Future<void> removeAccount(String email) async {
    _rememberedAccounts.removeWhere((a) => a['email'] == email);
    notifyListeners();
    await _saveAccounts();
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _rememberedAccounts.map((a) => '${a['email']},${a['name']}').join('|');
    await prefs.setString(_accountsKey, json);
  }

  String t(String key) {
    return _strings[_language]?[key] ?? _strings['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'app_name': 'Task Tracker',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'sign_out': 'Sign Out',

      'email': 'Email',
      'password': 'Password',
      'no_account': "Don't have an account? Create one",
      'has_account': 'Already have an account? Sign In',
      'select_role': 'Select Your Role',
      'i_am_manager': 'I am a Manager',
      'i_am_employee': 'I am an Employee',
      'manager_dashboard': 'Manager Dashboard',
      'my_tasks': 'My Tasks',
      'new_task': 'New Task',
      'title': 'Title',
      'description': 'Description',
      'employee_name': 'Employee Name',
      'employee_email': 'Employee Email',
      'assign_to_all': 'Assign to all employees',
      'customer': 'Customer',
      'car_thing': 'Car / Thing',
      'preset_task': 'Preset Task',
      'custom_task': 'Custom Task',
      'create': 'Create',
      'cancel': 'Cancel',
      'pending': 'Pending',
      'doing': 'In Progress',
      'done': 'Done',
      'claim': 'Claim Task',
      'claim_hint': 'I will do this task',
      'complete_with_photo': 'Take Photo & Complete',
      'uploading': 'Uploading...',
      'reset_task': 'Reset Task',
      'reset_confirm': 'Mark this task as incomplete again?',
      'no_tasks': 'No tasks yet',
      'no_tasks_assigned': 'No tasks assigned yet',
      'tasks': 'tasks',
      'tasks_pending': 'pending',
      'tasks_done': 'done',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'accent_color': 'Accent Color',
      'accounts': 'Accounts',
      'remembered_accounts': 'Remembered Accounts',
      'delete_account': 'Remove from device',
      'confirm_delete_account': 'Remove this account from this device?',
      'create_first_task': 'Create First Task',
      'task_completed': 'Task completed! Photo proof submitted.',
      'failed': 'Failed',
      'assigned_to': 'Assigned to',
      'created': 'Created',
      'completed': 'Completed',
      'proof_photo': 'Proof Photo',
      'no_description': 'No description',
      'preset_tasks': 'Preset Tasks',
      'manage_presets': 'Manage Presets',
      'new_preset': 'New Preset',
      'preset_name': 'Preset Name',
      'default_desc': 'Default description',
      'req_car': 'Ask for car/thing',
      'save': 'Save',
      'delete': 'Delete',
      'claimed_by': 'In progress by',
      'free': 'Available',
      'confirm_logout': 'Sign out?',
      'pending_review': 'Pending Review',
      'manage_employees': 'Manage Employees',
      'manage_items': 'Manage Preset Items',
      'problems': 'Problems',
      'report_problem': 'Report Problem',
      'new_employee': 'New Employee',
      'manager_password': 'Your Password (Manager)',
      'no_employees': 'No employees yet',
      'no_items': 'No preset items yet',
      'open': 'Open',
      'resolved': 'Resolved',
      'convert_to_task': 'Convert to Task',
      'none': 'None',
      'take_photo': 'Take Photo',
      'retake': 'Retake',
      'send': 'Send',
      'approve': 'Approve',
      'reject': 'Reject',
      'reassign': 'Reassign',
      'tasks_tab': 'Tasks',
      'problems_tab': 'Problems',
      'item_name': 'Item Name',
      'start_task': 'Start Task',
      'filter_active': 'Active',
      'filter_all': 'All',
      'filter_pending': 'Pending',
      'filter_doing': 'In Progress',
      'filter_review': 'Pending Review',
      'filter_completed': 'Completed',
      'filter_open': 'Open',
      'filter_assigned': 'Assigned',
      'filter_resolved': 'Resolved',
      'show_password': 'Show password',
      'hide_password': 'Hide password',
      'search': 'Search',
      'edit_task': 'Edit Task',
      'task_started': 'Task started',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'saved': 'Saved',
      'task_reset': 'Task reset',
      'rejection_reason': 'Rejection reason',
      'reject_reason': 'Reason for rejection?',
      'reject_reason_hint': 'Enter a reason…',
      'tap_to_zoom': 'Tap to zoom',
      'history': 'History',
      'started': 'Started',
      'submitted_proof': 'Submitted proof',
      'status_change': 'Status changed',
      'by': 'by',
      'rename_employee': 'Rename Employee',
      'total_tasks': 'Total Tasks',
      'open_problems': 'Open Problems',
      'export_data': 'Export Data',
      'exported': 'Data copied to clipboard',
      'data': 'Data',
      'about': 'About',
      'check_for_updates': 'Check for Updates',
      'checking_for_updates': 'Checking for updates...',
      'account_not_configured': 'Account Not Configured',
      'contact_administrator': 'Contact your administrator to set up your account.',
      'up_to_date': 'You are up to date!',
      'update_available': 'Update Available',
    },
    'fr': {
      'app_name': 'Gestionnaire de Tâches',
      'sign_in': 'Connexion',
      'sign_up': "S'inscrire",
      'sign_out': 'Déconnexion',

      'email': 'Email',
      'password': 'Mot de passe',
      'no_account': 'Pas de compte? Créez-en un',
      'has_account': 'Déjà un compte? Connectez-vous',
      'select_role': 'Choisissez votre rôle',
      'i_am_manager': 'Je suis Manager',
      'i_am_employee': 'Je suis Employé',
      'manager_dashboard': 'Tableau de Bord',
      'my_tasks': 'Mes Tâches',
      'new_task': 'Nouvelle Tâche',
      'title': 'Titre',
      'description': 'Description',
      'employee_name': "Nom de l'employé",
      'employee_email': "Email de l'employé",
      'assign_to_all': 'Assigner à tous',
      'customer': 'Client',
      'car_thing': 'Voiture / Objet',
      'preset_task': 'Tâche prédéfinie',
      'custom_task': 'Tâche personnalisée',
      'create': 'Créer',
      'cancel': 'Annuler',
      'pending': 'En attente',
      'doing': 'En cours',
      'done': 'Terminé',
      'claim': 'Prendre la tâche',
      'claim_hint': 'Je vais faire cette tâche',
      'complete_with_photo': 'Photo & Terminer',
      'uploading': 'Téléchargement...',
      'reset_task': 'Réinitialiser',
      'reset_confirm': 'Marquer comme non terminé?',
      'no_tasks': 'Aucune tâche',
      'no_tasks_assigned': 'Aucune tâche assignée',
      'tasks': 'tâches',
      'tasks_pending': 'en attente',
      'tasks_done': 'terminées',
      'settings': 'Paramètres',
      'language': 'Langue',
      'theme': 'Thème',
      'light': 'Clair',
      'dark': 'Sombre',
      'accent_color': 'Couleur',
      'accounts': 'Comptes',
      'remembered_accounts': 'Comptes enregistrés',
      'delete_account': 'Supprimer',
      'confirm_delete_account': 'Supprimer ce compte?',
      'create_first_task': 'Créer une tâche',
      'task_completed': 'Tâche terminée! Preuve soumise.',
      'failed': 'Échec',
      'assigned_to': 'Assigné à',
      'created': 'Créé',
      'completed': 'Terminé',
      'proof_photo': 'Photo preuve',
      'no_description': 'Aucune description',
      'preset_tasks': 'Tâches prédéfinies',
      'manage_presets': 'Gérer les prédéfinis',
      'new_preset': 'Nouveau prédéfini',
      'preset_name': 'Nom du prédéfini',
      'default_desc': 'Description par défaut',
      'req_car': 'Demander voiture/objet',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'claimed_by': 'En cours par',
      'free': 'Disponible',
      'confirm_logout': 'Se déconnecter?',
      'pending_review': 'En attente de validation',
      'manage_employees': 'Gérer les employés',
      'manage_items': 'Gérer les éléments',
      'problems': 'Problèmes',
      'report_problem': 'Signaler un problème',
      'new_employee': 'Nouvel employé',
      'manager_password': 'Votre mot de passe (gestionnaire)',
      'no_employees': 'Aucun employé',
      'no_items': 'Aucun élément',
      'open': 'Ouvert',
      'resolved': 'Résolu',
      'convert_to_task': 'Convertir en tâche',
      'none': 'Aucun',
      'take_photo': 'Prendre une photo',
      'retake': 'Reprendre',
      'send': 'Envoyer',
      'approve': 'Approuver',
      'reject': 'Rejeter',
      'reassign': 'Réassigner',
      'tasks_tab': 'Tâches',
      'problems_tab': 'Problèmes',
      'item_name': "Nom de l'élément",
      'start_task': 'Commencer la tâche',
      'filter_active': 'Actif',
      'filter_all': 'Tout',
      'filter_pending': 'En attente',
      'filter_doing': 'En cours',
      'filter_review': 'En validation',
      'filter_completed': 'Terminé',
      'filter_open': 'Ouvert',
      'filter_assigned': 'Assigné',
      'filter_resolved': 'Résolu',
      'show_password': 'Afficher le mot de passe',
      'hide_password': 'Cacher le mot de passe',
      'search': 'Rechercher',
      'edit_task': 'Modifier la tâche',
      'task_started': 'Tâche commencée',
      'approved': 'Approuvé',
      'rejected': 'Rejeté',
      'saved': 'Enregistré',
      'task_reset': 'Tâche réinitialisée',
      'rejection_reason': 'Raison du rejet',
      'reject_reason': 'Raison du rejet?',
      'reject_reason_hint': 'Entrez une raison…',
      'tap_to_zoom': 'Appuyez pour zoomer',
      'history': 'Historique',
      'started': 'Commencée',
      'submitted_proof': 'Preuve soumise',
      'status_change': 'Statut modifié',
      'by': 'par',
      'rename_employee': "Renommer l'employé",
      'total_tasks': 'Total des tâches',
      'open_problems': 'Problèmes ouverts',
      'export_data': 'Exporter les données',
      'exported': 'Données copiées dans le presse-papier',
      'data': 'Données',
      'about': 'À propos',
      'check_for_updates': 'Vérifier les mises à jour',
      'checking_for_updates': 'Vérification des mises à jour...',
      'account_not_configured': 'Compte non configuré',
      'contact_administrator': 'Contactez votre administrateur pour configurer votre compte.',
      'up_to_date': 'Vous êtes à jour !',
      'update_available': 'Mise à jour disponible',
    },
    'ar': {
      'app_name': 'مدير المهام',
      'sign_in': 'تسجيل الدخول',
      'sign_up': 'إنشاء حساب',
      'sign_out': 'تسجيل الخروج',

      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'no_account': 'ليس لديك حساب؟ إنشاء واحد',
      'has_account': 'لديك حساب؟ تسجيل الدخول',
      'select_role': 'اختر دورك',
      'i_am_manager': 'أنا مدير',
      'i_am_employee': 'أنا موظف',
      'manager_dashboard': 'لوحة التحكم',
      'my_tasks': 'مهامي',
      'new_task': 'مهمة جديدة',
      'title': 'العنوان',
      'description': 'الوصف',
      'employee_name': 'اسم الموظف',
      'employee_email': 'بريد الموظف',
      'assign_to_all': 'تعيين للجميع',
      'customer': 'العميل',
      'car_thing': 'السيارة / الشيء',
      'preset_task': 'مهمة محددة مسبقاً',
      'custom_task': 'مهمة مخصصة',
      'create': 'إنشاء',
      'cancel': 'إلغاء',
      'pending': 'قيد الانتظار',
      'doing': 'قيد التنفيذ',
      'done': 'مكتمل',
      'claim': 'تولي المهمة',
      'claim_hint': 'سأقوم بهذه المهمة',
      'complete_with_photo': 'تصوير وإكمال',
      'uploading': 'جاري الرفع...',
      'reset_task': 'إعادة المهمة',
      'reset_confirm': 'هل تريد إرجاع المهمة كغير مكتملة؟',
      'no_tasks': 'لا توجد مهام',
      'no_tasks_assigned': 'لا توجد مهام مسندة',
      'tasks': 'مهام',
      'tasks_pending': 'قيد الانتظار',
      'tasks_done': 'مكتملة',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'light': 'فاتح',
      'dark': 'داكن',
      'accent_color': 'اللون الرئيسي',
      'accounts': 'الحسابات',
      'remembered_accounts': 'الحسابات المحفوظة',
      'delete_account': 'حذف من الجهاز',
      'confirm_delete_account': 'حذف هذا الحساب من الجهاز؟',
      'create_first_task': 'إنشاء أول مهمة',
      'task_completed': 'تم إكمال المهمة! تم إرسال الصورة.',
      'failed': 'فشل',
      'assigned_to': 'مسندة إلى',
      'created': 'تم الإنشاء',
      'completed': 'تم الإكمال',
      'proof_photo': 'صورة الإثبات',
      'no_description': 'لا يوجد وصف',
      'preset_tasks': 'مهام محددة مسبقاً',
      'manage_presets': 'إدارة المهام المحددة',
      'new_preset': 'إضافة مهمة محددة',
      'preset_name': 'اسم المهمة',
      'default_desc': 'الوصف الافتراضي',
      'req_car': 'طلب السيارة/الشيء',
      'save': 'حفظ',
      'delete': 'حذف',
      'claimed_by': 'قيد التنفيذ بواسطة',
      'free': 'متاحة',
      'confirm_logout': 'تسجيل الخروج؟',
      'pending_review': 'قيد المراجعة',
      'manage_employees': 'إدارة الموظفين',
      'manage_items': 'إدارة العناصر',
      'problems': 'المشاكل',
      'report_problem': 'الإبلاغ عن مشكلة',
      'new_employee': 'موظف جديد',
      'manager_password': 'كلمة مرورك (مدير)',
      'no_employees': 'لا يوجد موظفون',
      'no_items': 'لا توجد عناصر',
      'open': 'مفتوح',
      'resolved': 'تم الحل',
      'convert_to_task': 'تحويل إلى مهمة',
      'none': 'لا شيء',
      'take_photo': 'التقاط صورة',
      'retake': 'إعادة التصوير',
      'send': 'إرسال',
      'approve': 'موافقة',
      'reject': 'رفض',
      'reassign': 'إعادة تعيين',
      'tasks_tab': 'المهام',
      'problems_tab': 'المشاكل',
      'item_name': 'اسم العنصر',
      'start_task': 'بدء المهمة',
      'filter_active': 'نشط',
      'filter_all': 'الكل',
      'filter_pending': 'قيد الانتظار',
      'filter_doing': 'قيد التنفيذ',
      'filter_review': 'قيد المراجعة',
      'filter_completed': 'مكتمل',
      'filter_open': 'مفتوح',
      'filter_assigned': 'مسند',
      'filter_resolved': 'تم الحل',
      'show_password': 'إظهار كلمة المرور',
      'hide_password': 'إخفاء كلمة المرور',
      'search': 'بحث',
      'edit_task': 'تعديل المهمة',
      'task_started': 'بدأت المهمة',
      'approved': 'تمت الموافقة',
      'rejected': 'تم الرفض',
      'saved': 'تم الحفظ',
      'task_reset': 'تم إعادة تعيين المهمة',
      'rejection_reason': 'سبب الرفض',
      'reject_reason': 'سبب الرفض؟',
      'reject_reason_hint': 'أدخل السبب…',
      'tap_to_zoom': 'اضغط للتكبير',
      'history': 'السجل',
      'started': 'بدأت',
      'submitted_proof': 'تم تقديم الإثبات',
      'status_change': 'تم تغيير الحالة',
      'by': 'بواسطة',
      'rename_employee': 'إعادة تسمية الموظف',
      'total_tasks': 'إجمالي المهام',
      'open_problems': 'المشاكل المفتوحة',
      'export_data': 'تصدير البيانات',
      'exported': 'تم نسخ البيانات إلى الحافظة',
      'data': 'البيانات',
      'about': 'حول',
      'check_for_updates': 'التحقق من التحديثات',
      'checking_for_updates': 'جاري التحقق من التحديثات...',
      'account_not_configured': 'الحساب غير مكون',
      'contact_administrator': 'اتصل بمسؤولك لإعداد حسابك.',
      'up_to_date': 'أنت تستخدم أحدث إصدار!',
      'update_available': 'تحديث متاح',
    },
  };

  TextDirection get textDirection =>
      _language == 'ar' ? TextDirection.rtl : TextDirection.ltr;
}
