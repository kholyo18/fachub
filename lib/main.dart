// ============================================================================
// Fachub — main.dart (FULL INTEGRATION) — PART 1/5
// كل الأجزاء تُلصق تباعاً في نفس الملف وبالترتيب.
// ============================================================================
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Local & Files
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';

// PDF & Printing
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// خيارات Firebase التي أنشأتها عبر flutterfire
import 'firebase_options.dart';

// ============================================================================
// ألوان وهوية الواجهة
// ============================================================================
const kFachubGreen = Color(0xFF16434A);
const kFachubBlue  = Color(0xFF2365EB);

// ============================================================================
// تشغيل التطبيق
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FachubApp());
}

// ============================================================================
// واجهة التطبيق
// ============================================================================
class FachubApp extends StatelessWidget {
  const FachubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fachub',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kFachubBlue,
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: const AuthGate(),
    );
  }
}

// ============================================================================
// بوابة المصادقة
// ============================================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) return const SignInScreen();
        return const HomeTabs();
      },
    );
  }
}

// ============================================================================
// شاشة الدخول/التسجيل (بسيطة)
// ============================================================================
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(), password: password.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally { setState(() => loading = false); }
  }

  Future<void> _register() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(), password: password.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التسجيل: $e')));
    } finally { setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.school_rounded, color: kFachubBlue, size: 64),
                const SizedBox(height: 12),
                const Text("مرحبًا بك في Fachub",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined), labelText: "البريد الإلكتروني"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password, obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline), labelText: "كلمة المرور"),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  FilledButton.icon(
                    onPressed: loading ? null : _login,
                    icon: const Icon(Icons.login), label: const Text("دخول")),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _register,
                    icon: const Icon(Icons.person_add_alt), label: const Text("تسجيل")),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// نماذج/قوالب DZ + التخزين المحلي + الفهرس + مزامنة Firestore + هوية الشهادة
// ============================================================================

// ----------------------------- DzSubject/DzTemplate --------------------------
class DzSubject {
  final String name;
  final double coef;
  final Map<String, double> weights; // {"TD":30,"EXAM":70} مئوية

  DzSubject({required this.name, required this.coef, required this.weights});

  factory DzSubject.fromMap(Map<String, dynamic> m) => DzSubject(
        name: m['name'] as String,
        coef: (m['coef'] as num).toDouble(),
        weights: (m['weights'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      );

  Map<String, dynamic> toMap() => {'name': name, 'coef': coef, 'weights': weights};
}

class DzTemplate {
  final String title;
  final double successThreshold;
  final List<DzSubject> subjects;

  DzTemplate({required this.title, required this.successThreshold, required this.subjects});

  factory DzTemplate.fromMap(Map<String, dynamic> m) => DzTemplate(
        title: (m['title'] ?? '') as String,
        successThreshold: (m['success_threshold'] as num?)?.toDouble() ?? 10.0,
        subjects: ((m['subjects'] as List?) ?? const [])
            .cast<Map<String, dynamic>>().map((e) => DzSubject.fromMap(e)).toList(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'success_threshold': successThreshold,
        'subjects': subjects.map((s) => s.toMap()).toList(),
      };
}

/// تحويل DzTemplate إلى شكل المواد المستعمل في شاشة الحاسبة
List<Map<String, dynamic>> dzTemplateToCalculatorModel(DzTemplate t) {
  return t.subjects.map((dz) {
    final m = <String, dynamic>{
      'name': dz.name,
      'coef': dz.coef,
      'weights': dz.weights,
    };
    if (dz.weights.containsKey('TD')) m['td'] = 0.0;
    if (dz.weights.containsKey('TP')) m['tp'] = 0.0;
    if (dz.weights.containsKey('CC')) m['cc'] = 0.0;
    if (dz.weights.containsKey('EXAM')) m['exam'] = 0.0;
    return m;
  }).toList();
}

// ----------------------------- Built-in Catalog ------------------------------
Future<Map<String, Map<String, String>>> dzLoadIndex(BuildContext ctx) async {
  final txt = await DefaultAssetBundle.of(ctx).loadString('assets/templates_dz/index.json');
  final m = jsonDecode(txt) as Map<String, dynamic>;
  final majors = (m['majors'] as Map<String, dynamic>);
  return majors.map((maj, semsAny) {
    final sems = (semsAny as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));
    return MapEntry(maj, Map<String, String>.from(sems));
  });
}

Future<DzTemplate> dzLoadBuiltInTemplateByFile(BuildContext ctx, String filename) async {
  final txt = await DefaultAssetBundle.of(ctx).loadString('assets/templates_dz/$filename');
  return DzTemplate.fromMap(jsonDecode(txt));
}

// --------------------------- CalculatorSubjectsIO ----------------------------
class CalculatorSubjectsIO {
  static const _k = 'calc_subjects_v2';
  static const _kThreshold = 'calc_threshold_v2';

  static Future<void> setSubjects(List<Map<String, dynamic>> subjects, {double? threshold}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k, jsonEncode(subjects));
    if (threshold != null) await prefs.setDouble(_kThreshold, threshold);
  }

  static Future<List<Map<String, dynamic>>?> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_k);
    if (str == null) return null;
    return (jsonDecode(str) as List).cast<Map<String, dynamic>>();
  }

  static Future<double?> getThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kThreshold);
  }
}

// --------------------------- Custom Templates (Local) ------------------------
class DzCustomTemplatesStore {
  static const _key = 'dz_custom_templates_v1';

  static Future<void> saveCustom(DzTemplate t, {required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final filtered = raw
        .map((s) => jsonDecode(s))
        .where((m) => (m['name'] as String?) != name)
        .map((m) => jsonEncode(m))
        .toList();
    filtered.add(jsonEncode({
      'name': name,
      'template': t.toMap(),
      'saved_at': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_key, filtered);
  }

  static Future<List<Map<String, dynamic>>> listCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> deleteCustomByName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final filtered = raw
        .map((s) => jsonDecode(s))
        .where((m) => (m['name'] as String?) != name)
        .map((m) => jsonEncode(m))
        .toList();
    await prefs.setStringList(_key, filtered);
  }
}

// --------------------------- Firestore Sync (Custom) -------------------------
class DzCustomTemplatesSync {
  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users').doc(uid).collection('dz_custom_templates')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? {},
            toFirestore: (m, _) => m,
          );

  static Future<void> uploadAllCustom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'يرجى تسجيل الدخول أولًا';
    final list = await DzCustomTemplatesStore.listCustom();
    final col = _col(user.uid);
    final batch = FirebaseFirestore.instance.batch();
    for (final e in list) {
      final name = (e['name'] as String).trim();
      final t = e['template'] as Map<String, dynamic>;
      final ref = col.doc(name);
      batch.set(ref, {
        'name': name,
        'template': t,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<void> downloadAllToLocal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'يرجى تسجيل الدخول أولًا';
    final snaps = await _col(user.uid).get();
    for (final d in snaps.docs) {
      final m = d.data();
      final t = DzTemplate.fromMap((m['template'] as Map).cast<String, dynamic>());
      await DzCustomTemplatesStore.saveCustom(t, name: m['name'] as String);
    }
  }
}

// --------------------------- شهادة PDF: هوية وتخزين -------------------------
class CertificateIdentityStore {
  static const _kName = 'cert_student_name';
  static const _kUni  = 'cert_university_name';
  static const _kLogo = 'cert_university_logo_b64';

  static Future<void> saveName(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, v);
  }
  static Future<void> saveUniversity(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUni, v);
  }
  static Future<void> saveLogoBytes(Uint8List? bytes) async {
    final p = await SharedPreferences.getInstance();
    if (bytes == null) { await p.remove(_kLogo); return; }
    await p.setString(_kLogo, base64Encode(bytes));
  }

  static Future<String?> getName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kName);
  }
  static Future<String?> getUniversity() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kUni);
  }
  static Future<Uint8List?> getLogoBytes() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kLogo);
    if (s == null) return null;
    try { return base64Decode(s); } catch (_) { return null; }
  }
}

// ---------------------------- قوائم ثابتة + مساعدات -------------------------
const Map<String, String> dzMajorsLabels = {
  'informatique': 'إعلام آلي',
  'mathematiques': 'رياضيات',
  'physique': 'فيزياء',
  'chimie': 'كيمياء',
  'biologie': 'بيولوجيا',
  'economie': 'اقتصاد',
  'gestion': 'تسيير',
  'comptabilite': 'محاسبة',
  'droit': 'قانون',
  'lang_arabe': 'لغة عربية',
  'lang_fr': 'لغة فرنسية',
  'lang_en': 'لغة إنجليزية',
  'psychologie': 'علم النفس',
};

const List<String> dzYears     = ['L1', 'L2', 'L3', 'M1', 'M2'];
const List<String> dzSemesters = ['S1', 'S2'];

String dzBuildIndexKey(String year, String sem) => '${year}_${sem}';

String dzNextSem(String year, String sem) {
  final years = dzYears;
  final sems  = dzSemesters;
  int yi = years.indexOf(year);
  int si = sems.indexOf(sem);
  if (yi < 0 || si < 0) return '$year|$sem';
  if (si == 0) return '${years[yi]}|S2';
  if (yi + 1 < years.length) return '${years[yi+1]}|S1';
  return '${years[yi]}|S2';
}

String dzPrevSem(String year, String sem) {
  final years = dzYears;
  final sems  = dzSemesters;
  int yi = years.indexOf(year);
  int si = sems.indexOf(sem);
  if (yi < 0 || si < 0) return '$year|$sem';
  if (si == 1) return '${years[yi]}|S1';
  if (yi - 1 >= 0) return '${years[yi-1]}|S2';
  return '${years[yi]}|S1';
}

// ============================================================================
// يتبع في PART 2/5:
// - شاشة الإعدادات (DZ) مع: القوائم المنسدلة + البحث الداخلي + إدارة القوالب
//   (حفظ/استيراد/تصدير) + مزامنة Firestore + كارد هوية الشهادة (اسم/جامعة/شعار).
// ============================================================================
// ============================================================================
// PART 2/5 — SettingsDzScreen: قوائم + بحث + حفظ/استيراد/تصدير + مزامنة + هوية PDF
// ============================================================================

class SettingsDzScreen extends StatefulWidget {
  const SettingsDzScreen({super.key});
  @override
  State<SettingsDzScreen> createState() => _SettingsDzScreenState();
}

class _SettingsDzScreenState extends State<SettingsDzScreen> {
  Map<String, Map<String, String>> _index = {};
  bool _loadingIndex = true;

  // اختيارات المستخدم
  String _major = dzMajorsLabels.keys.first;
  String _year = dzYears.first;          // L1
  String _semester = dzSemesters.first;  // S1

  String? _lastLoadedTitle;
  String? _lastLoadedFile;

  // بحث داخلي
  final _searchCtrl = TextEditingController();
  List<_BuiltInHit> _hits = [];

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIndex() async {
    try {
      final idx = await dzLoadIndex(context);
      setState(() {
        _index = idx;
        _loadingIndex = false;
      });
    } catch (e) {
      setState(() => _loadingIndex = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تحميل الفهرس: $e')));
      }
    }
  }

  Future<void> _loadBuiltIn() async {
    if (_loadingIndex) return;
    final key = dzBuildIndexKey(_year, _semester); // مثل L1_S1
    final files = _index[_major];
    if (files == null || !files.containsKey(key)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('لا يوجد قالب: ${dzMajorsLabels[_major]} • $_year $_semester')));
      return;
    }
    final file = files[key]!;
    try {
      final t = await dzLoadBuiltInTemplateByFile(context, file);
      final list = dzTemplateToCalculatorModel(t);
      await CalculatorSubjectsIO.setSubjects(list, threshold: t.successThreshold);
      setState(() {
        _lastLoadedTitle = t.title.isNotEmpty ? t.title : '${dzMajorsLabels[_major]} • $_year $_semester';
        _lastLoadedFile = file;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحميل القالب إلى الحاسبة')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل القالب: $e')));
    }
  }

  Future<void> _saveAsCustom() async {
    final subjects = await CalculatorSubjectsIO.getSubjects();
    final threshold = await CalculatorSubjectsIO.getThreshold() ?? 10.0;
    if (subjects == null || subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد مواد محمّلة في الحاسبة لحفظها كقالب')));
      return;
    }

    final nameCtrl = TextEditingController(
        text: _lastLoadedTitle ?? '${dzMajorsLabels[_major]} • $_year $_semester');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حفظ كقالب مخصّص'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'اسم القالب'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;

    // تحويل subjects (شكل الحاسبة) إلى DzTemplate
    final dzSubs = subjects.map((m) {
      final Map<String, double> weights =
          (m['weights'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
          <String, double>{
            if (m.containsKey('td')) 'TD': 30,
            if (m.containsKey('tp')) 'TP': 40,
            if (m.containsKey('cc')) 'CC': 40,
            if (m.containsKey('exam')) 'EXAM': 60,
          };
      return DzSubject(
        name: (m['name'] as String?) ?? 'مادة',
        coef: ((m['coef'] as num?) ?? 1).toDouble(),
        weights: weights,
      );
    }).toList();

    final t = DzTemplate(
      title: nameCtrl.text.trim(),
      successThreshold: threshold,
      subjects: dzSubs,
    );

    await DzCustomTemplatesStore.saveCustom(t, name: t.title);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ كقالب مخصّص')));
  }

  Future<void> _exportCustomTemplate(Map<String, dynamic> entry) async {
    final tMap = entry['template'] as Map<String, dynamic>;
    final name = (entry['name'] as String).replaceAll(RegExp(r'[^\w\-\s]'), '_');
    final jsonStr = const JsonEncoder.withIndent('  ').convert(tMap);

    final path = await getSaveLocation(suggestedName: '$name.json');
    final loc = await getSaveLocation(suggestedName: '$name.json');
    if (loc == null) return;

    final file = File(loc.path);
    await file.writeAsString(jsonStr);

   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('تم حفظ القالب بنجاح ✅')),
     );
   }

    }
  }

  Future<void> _importCustomTemplate() async {
    final x = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'json', extensions: ['json'])
    ]);
    if (x == null) return;
    try {
      final txt = await x.readAsString();
      final m = jsonDecode(txt) as Map<String, dynamic>;
      final t = DzTemplate.fromMap(m);
      await DzCustomTemplatesStore.saveCustom(t, name: t.title);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد القالب وتخزينه')));
      setState(() {}); // لتحديث القائمة
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستيراد: $e')));
      }
    }
  }

  Future<void> _applyCustomToCalculator(Map<String, dynamic> entry) async {
    final t = DzTemplate.fromMap(entry['template'] as Map<String, dynamic>);
    final list = dzTemplateToCalculatorModel(t);
    await CalculatorSubjectsIO.setSubjects(list, threshold: t.successThreshold);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق القالب على الحاسبة')));
    }
  }

  Future<void> _deleteCustom(String name) async {
    await DzCustomTemplatesStore.deleteCustomByName(name);
    if (mounted) setState(() {});
  }

  // بحث داخلي
  void _runSearch(String q) {
    q = q.trim().toLowerCase();
    if (q.isEmpty || _index.isEmpty) {
      setState(() => _hits = []);
      return;
    }
    final out = <_BuiltInHit>[];
    dzMajorsLabels.forEach((mKey, mLabel) {
      final sems = _index[mKey] ?? {};
      sems.forEach((k, file) {
        // k = L1_S1, L2_S2 ...
        final parts = k.split('_');
        final year = parts.first;
        final sem = parts.last;
        final label = '${mLabel} • $year $sem';
        final hay = (label + ' ' + mKey + ' ' + file).toLowerCase();
        if (hay.contains(q)) out.add(_BuiltInHit(mKey, label, file, year, sem));
      });
    });
    setState(() => _hits = out.take(20).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات Fachub (DZ)')),
      body: _loadingIndex
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                // -------------------- كارد القوالب الجاهزة + البحث --------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('اختيار التخصص والسداسي (قوالب جاهزة)',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        // بحث داخلي
                        TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'بحث في القوالب (مثال: إعلام آلي L2 S1 أو informatique L3 S2)',
                          ),
                          onChanged: _runSearch,
                        ),
                        const SizedBox(height: 10),
                        if (_hits.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('نتائج البحث', style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                ..._hits.map((h) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.description_outlined),
                                  title: Text(h.label),
                                  trailing: TextButton(
                                    child: const Text('تحميل'),
                                    onPressed: () async {
                                      try {
                                        final t = await dzLoadBuiltInTemplateByFile(context, h.file);
                                        final list = dzTemplateToCalculatorModel(t);
                                        await CalculatorSubjectsIO.setSubjects(list, threshold: t.successThreshold);
                                        setState(() { _lastLoadedTitle = t.title; _lastLoadedFile = h.file; });
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحميل القالب من البحث')));
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                                      }
                                    },
                                  ),
                                )),
                              ],
                            ),
                          ),

                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _majorDropdown()),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _yearDropdown()),
                          const SizedBox(width: 8),
                          Expanded(child: _semesterDropdown()),
                        ]),
                        const SizedBox(height: 10),
                        // السابق / تحميل / التالي (تحويل تلقائي بين السداسيات)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                final r = dzPrevSem(_year, _semester).split('|');
                                setState(() { _year = r[0]; _semester = r[1]; });
                                _loadBuiltIn(); // تحميل تلقائي
                              },
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('السابق'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _loadBuiltIn,
                              icon: const Icon(Icons.download),
                              label: const Text('تحميل القالب'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final r = dzNextSem(_year, _semester).split('|');
                                setState(() { _year = r[0]; _semester = r[1]; });
                                _loadBuiltIn(); // تحميل تلقائي
                              },
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('التالي'),
                            ),
                          ],
                        ),
                        if (_lastLoadedTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _lastLoadedTitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_lastLoadedFile != null)
                          Text('الملف: $_lastLoadedFile',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // -------------------- كارد القوالب المخصّصة + مزامنة --------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('قوالبي المخصّصة',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _saveAsCustom,
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ القالب الحالي'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _importCustomTemplate,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('استيراد JSON'),
                            ),
                            // مزامنة Firestore
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await DzCustomTemplatesSync.uploadAllCustom();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع القوالب إلى السحابة')));
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
                                }
                              },
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('رفع إلى السحابة'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await DzCustomTemplatesSync.downloadAllToLocal();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم سحب القوالب إلى الجهاز')));
                                  }
                                  setState(() {});
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل السحب: $e')));
                                }
                              },
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('سحب من السحابة'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: DzCustomTemplatesStore.listCustom(),
                          builder: (context, snap) {
                            final list = snap.data ?? const [];
                            if (list.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text('لا توجد قوالب محفوظة بعد.'),
                              );
                            }
                            return Column(
                              children: list.map((e) {
                                final name = e['name'] as String? ?? 'بدون اسم';
                                final savedAt = e['saved_at'] as String? ?? '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.bookmarks_outlined),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(savedAt, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      IconButton(
                                        tooltip: 'تطبيق على الحاسبة',
                                        onPressed: () => _applyCustomToCalculator(e),
                                        icon: const Icon(Icons.playlist_add_check_circle_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'تصدير JSON',
                                        onPressed: () => _exportCustomTemplate(e),
                                        icon: const Icon(Icons.download_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'حذف',
                                        onPressed: () => _deleteCustom(name),
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // -------------------- كارد بيانات شهادة PDF (اسم/جامعة/شعار) --------------------
                _certificateCard(),
              ],
            ),
    );
  }

  // DropDowns
  Widget _majorDropdown() {
    return DropdownButtonFormField<String>(
      value: _major,
      items: dzMajorsLabels.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) => setState(() => _major = v ?? _major),
      decoration: const InputDecoration(labelText: 'التخصص'),
    );
  }

  Widget _yearDropdown() {
    return DropdownButtonFormField<String>(
      value: _year,
      items: dzYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
      onChanged: (v) => setState(() => _year = v ?? _year),
      decoration: const InputDecoration(labelText: 'السنة'),
    );
  }

  Widget _semesterDropdown() {
    return DropdownButtonFormField<String>(
      value: _semester,
      items: dzSemesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _semester = v ?? _semester),
      decoration: const InputDecoration(labelText: 'السداسي'),
    );
  }

  // كارد إعدادات الشهادة (اسم/جامعة/شعار)
  Card _certificateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder(
          future: Future.wait([
            CertificateIdentityStore.getName(),
            CertificateIdentityStore.getUniversity(),
            CertificateIdentityStore.getLogoBytes(),
          ]),
          builder: (context, snap) {
            String name = (snap.data is List && snap.data!.length >= 1 && snap.data![0] != null)
                ? (snap.data![0] as String) : '';
            String uni  = (snap.data is List && snap.data!.length >= 2 && snap.data![1] != null)
                ? (snap.data![1] as String) : '';
            Uint8List? logo = (snap.data is List && snap.data!.length >= 3)
                ? (snap.data![2] as Uint8List?) : null;

            final nameCtrl = TextEditingController(text: name);
            final uniCtrl  = TextEditingController(text: uni);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('شهادة PDF — معلومات الهوية',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطالب (اختياري)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: uniCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الجامعة/الكلية (اختياري)',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final x = await openFile(acceptedTypeGroups: [
                          const XTypeGroup(label: 'images', extensions: ['png','jpg','jpeg'])
                        ]);
                        if (x == null) return;
                        final bytes = await x.readAsBytes();
                        await CertificateIdentityStore.saveLogoBytes(bytes);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حفظ الشعار')),
                          );
                          (context as Element).markNeedsBuild();
                        }
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('اختيار الشعار'),
                    ),
                    const SizedBox(width: 8),
                    if (logo != null)
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: MemoryImage(logo), fit: BoxFit.cover),
                        ),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () async {
                        await CertificateIdentityStore.saveName(nameCtrl.text.trim());
                        await CertificateIdentityStore.saveUniversity(uniCtrl.text.trim());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حفظ بيانات الشهادة')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ البيانات'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    await CertificateIdentityStore.saveLogoBytes(null);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إزالة الشعار')),
                      );
                      (context as Element).markNeedsBuild();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('إزالة الشعار', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// كلاس نتيجة البحث
class _BuiltInHit {
  final String majorKey;
  final String label; // "إعلام آلي • L2 S1"
  final String file;
  final String year;
  final String sem;
  _BuiltInHit(this.majorKey, this.label, this.file, this.year, this.sem);
}

// ============================================================================
// يتبع في PART 3/5:
// - شاشة الحاسبة (DZ) الموصولة بالقوالب + زر شهادة PDF (شعار/اسم/جامعة/QR).
// - مع أزرار: تحميل/حفظ/إعادة ضبط.
// ============================================================================
// ============================================================================
// PART 3/5 — Calculator DZ + PDF Certificate
// ============================================================================

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // المواد بنفس الشكل الناتج من dzTemplateToCalculatorModel
  List<Map<String, dynamic>> subjects = [];
  double successThreshold = 10.0; // عتبة النجاح

  @override
  void initState() {
    super.initState();
    _loadFromStore();
  }

  // تحميل القالب/المواد من التخزين المحلي
  Future<void> _loadFromStore() async {
    final loaded = await CalculatorSubjectsIO.getSubjects();
    final thr = await CalculatorSubjectsIO.getThreshold();
    setState(() {
      subjects = loaded ?? _sampleSubjects();
      successThreshold = thr ?? 10.0;
    });
  }

  // حفظ المواد الحالية للتخزين
  Future<void> _saveToStore() async {
    await CalculatorSubjectsIO.setSubjects(subjects, threshold: successThreshold);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ إلى التخزين')));
  }

  // إعادة ضبط للعينات الافتراضية
  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة ضبط'),
        content: const Text('سيتم مسح المواد المحفوظة وإعادة القيم الافتراضية. المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      subjects = _sampleSubjects();
      successThreshold = 10.0;
    });
    await CalculatorSubjectsIO.setSubjects(subjects, threshold: successThreshold);
  }

  // عينة افتراضية إن لم يُحمَّل قالب
  List<Map<String, dynamic>> _sampleSubjects() => [
        {
          'name': 'رياضيات 1',
          'coef': 4.0,
          'weights': {'TD': 30.0, 'EXAM': 70.0},
          'td': 0.0,
          'exam': 0.0,
        },
        {
          'name': 'أسس الإعلام الآلي',
          'coef': 3.0,
          'weights': {'TP': 40.0, 'EXAM': 60.0},
          'tp': 0.0,
          'exam': 0.0,
        },
        {
          'name': 'لغة أجنبية',
          'coef': 1.0,
          'weights': {'CC': 40.0, 'EXAM': 60.0},
          'cc': 0.0,
          'exam': 0.0,
        },
      ];

  // حساب علامة مادة واحدة بأخذ الأوزان بعين الاعتبار
  double _calcGrade(Map s) {
    final weightsAny = s['weights'];
    if (weightsAny is Map) {
      final Map<String, double> w = weightsAny.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
      double sum = 0, wsum = 0;
      void add(String keyField, String weightKey) {
        if (s.containsKey(keyField) && w.containsKey(weightKey)) {
          final val = (s[keyField] as num?)?.toDouble() ?? 0.0;
          final ww = w[weightKey]!;
          sum += val * ww;
          wsum += ww;
        }
      }

      add('td', 'TD');
      add('tp', 'TP');
      add('cc', 'CC');
      add('exam', 'EXAM');

      if (wsum > 0) return sum / wsum; // لأن الأوزان مئوية (≈ 100)
    }

    // بديل بسيط في حالة عدم وجود weights
    if (s.containsKey('td') && s.containsKey('exam')) {
      return ((s['td'] as num?)?.toDouble() ?? 0) * 0.3 +
          ((s['exam'] as num?)?.toDouble() ?? 0) * 0.7;
    }
    if (s.containsKey('tp') && s.containsKey('exam')) {
      return ((s['tp'] as num?)?.toDouble() ?? 0) * 0.4 +
          ((s['exam'] as num?)?.toDouble() ?? 0) * 0.6;
    }
    if (s.containsKey('cc') && s.containsKey('exam')) {
      return ((s['cc'] as num?)?.toDouble() ?? 0) * 0.4 +
          ((s['exam'] as num?)?.toDouble() ?? 0) * 0.6;
    }
    return ((s['exam'] as num?)?.toDouble() ?? 0);
  }

  // معدل السداسي
  double _termAverage() {
    double sum = 0, coefSum = 0;
    for (final s in subjects) {
      final coef = ((s['coef'] as num?) ?? 1).toDouble();
      sum += _calcGrade(s) * coef;
      coefSum += coef;
    }
    if (coefSum == 0) return 0;
    return sum / coefSum;
  }

  void _updateScore(int index, String keyField, String v) {
    final val = double.tryParse(v) ?? 0.0;
    setState(() => subjects[index][keyField] = val.clamp(0, 20));
  }

  // --------------------------- PDF Certificate -------------------------------
  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Student';
    final avg = _termAverage();
    final pass = avg >= successThreshold;

    // هوية الشهادة
    final studentName = (await CertificateIdentityStore.getName()) ?? '';
    final uniName     = (await CertificateIdentityStore.getUniversity()) ?? '';
    final logoBytes   = await CertificateIdentityStore.getLogoBytes();
    pw.ImageProvider? logoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      logoImage = pw.MemoryImage(logoBytes);
    }

    // QR Payload (بسيط)
    final qrPayload = jsonEncode({
      'type': 'FachubCertificate',
      'student': studentName.isNotEmpty ? studentName : email,
      'university': uniName,
      'avg': double.parse(avg.toStringAsFixed(2)),
      'threshold': double.parse(successThreshold.toStringAsFixed(1)),
      'timestamp': DateTime.now().toIso8601String(),
    });

    final tableHeaders = ['المادة', 'المعامل', 'الأوزان', 'العلامة'];
    final tableData = subjects.map((s) {
      final name = (s['name'] as String?) ?? 'مادة';
      final coef = ((s['coef'] as num?) ?? 1).toString();
      final w = (s['weights'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      final weightsStr = (w == null || w.isEmpty)
          ? '—'
          : [
              if (w.containsKey('TD')) 'TD ${w['TD']!.toStringAsFixed(0)}%',
              if (w.containsKey('TP')) 'TP ${w['TP']!.toStringAsFixed(0)}%',
              if (w.containsKey('CC')) 'CC ${w['CC']!.toStringAsFixed(0)}%',
              if (w.containsKey('EXAM')) 'EXAM ${w['EXAM']!.toStringAsFixed(0)}%',
            ].join(' / ');
      final grade = _calcGrade(s).toStringAsFixed(2);
      return [name, coef, weightsStr, grade];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          // رأس الشهادة: شعار + عنوان + QR
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 60, height: 60,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 8, verticalRadius: 8,
                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                  ),
                )
              else
                pw.Container(width: 60, height: 60),

              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Fachub — شهادة نتيجة السداسي',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  if (uniName.isNotEmpty)
                    pw.Text(uniName, style: const pw.TextStyle(fontSize: 12)),
                ],
              ),

              pw.SizedBox(
                width: 60, height: 60,
                child: pw.BarcodeWidget(
                  data: qrPayload,
                  barcode: pw.Barcode.qrCode(),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                (studentName.isNotEmpty ? 'الطالب: $studentName' : 'الطالب: $email'),
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(DateTime.now().toString().substring(0, 16),
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Divider(),
          pw.SizedBox(height: 6),

          pw.Text('عتبة النجاح: ${successThreshold.toStringAsFixed(1)}'),
          pw.SizedBox(height: 8),

          pw.Table.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.2),
            },
          ),

          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: pass ? PdfColors.lightGreen100 : PdfColors.amber100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('المعدل العام: ${avg.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold,
                        color: pass ? PdfColors.green800 : PdfColors.orange800)),
                pw.Text(pass ? 'النتيجة: ناجح' : 'النتيجة: دون العتبة',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: pass ? PdfColors.green800 : PdfColors.orange800)),
              ],
            ),
          ),

          pw.SizedBox(height: 10),
          pw.Text(
            'ملاحظة: رمز QR يحتوي بيانات التحقق (Student/University/Avg/Threshold/Timestamp).',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Fachub — www.fachub.app',
                style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _sharePdfCertificate() async {
    try {
      final bytes = await _buildPdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: 'Fachub_Certificate.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء PDF: $e')));
      }
    }
  }

  // --------------------------- UI ---------------------------
  @override
  Widget build(BuildContext context) {
    final avg = _termAverage();
    final pass = avg >= successThreshold;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fachub • الحاسبة (DZ)'),
        actions: [
          IconButton(
            tooltip: 'شهادة PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _sharePdfCertificate,
          ),
          IconButton(
            tooltip: 'إعدادات القوالب (DZ)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsDzScreen()),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          // بطاقة المتوسط
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('متوسط السداسي',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        avg.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: pass ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pass ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pass ? 'ناجح (≥ ${successThreshold.toStringAsFixed(1)})'
                               : 'دون العتبة (${successThreshold.toStringAsFixed(1)})',
                          style: TextStyle(
                            color: pass ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          initialValue: successThreshold.toStringAsFixed(1),
                          decoration: const InputDecoration(
                              labelText: 'عتبة النجاح', isDense: true),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => setState(() {
                            successThreshold = double.tryParse(v) ?? successThreshold;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loadFromStore,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحميل من التخزين'),
                      ),
                      FilledButton.icon(
                        onPressed: _saveToStore,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ إلى التخزين'),
                      ),
                      TextButton.icon(
                        onPressed: _resetAll,
                        icon: const Icon(Icons.restore),
                        label: const Text('إعادة ضبط'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // قائمة المواد
          ...List.generate(subjects.length, (i) => _subjectCard(i)),
        ],
      ),
    );
  }

  Widget _subjectCard(int i) {
    final s = subjects[i];
    final name = (s['name'] as String?) ?? 'مادة';
    final coef = ((s['coef'] as num?) ?? 1).toDouble();
    final hasTD = s.containsKey('td');
    final hasTP = s.containsKey('tp');
    final hasCC = s.containsKey('cc');
    final hasEX = s.containsKey('exam');
    final grade = _calcGrade(s);

    String weightsLabel() {
      final w = (s['weights'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      if (w == null || w.isEmpty) return '—';
      final parts = <String>[];
      if (w.containsKey('TD')) parts.add('TD ${w['TD']!.toStringAsFixed(0)}%');
      if (w.containsKey('TP')) parts.add('TP ${w['TP']!.toStringAsFixed(0)}%');
      if (w.containsKey('CC')) parts.add('CC ${w['CC']!.toStringAsFixed(0)}%');
      if (w.containsKey('EXAM')) parts.add('EXAM ${w['EXAM']!.toStringAsFixed(0)}%');
      return parts.join(' • ');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Coeff ${coef.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.black54)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                grade.toStringAsFixed(2),
                style: const TextStyle(
                    color: kFachubBlue, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('الأوزان: ${weightsLabel()}',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasTD) _scoreField(i, 'td', 'TD'),
              if (hasTP) _scoreField(i, 'tp', 'TP'),
              if (hasCC) _scoreField(i, 'cc', 'CC'),
              if (hasEX) _scoreField(i, 'exam', 'EXAM'),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _scoreField(int index, String keyField, String label) {
    final current =
        ((subjects[index][keyField] as num?) ?? 0).toDouble().toStringAsFixed(1);
    return SizedBox(
      width: 110,
      child: TextFormField(
        initialValue: current,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => _updateScore(index, keyField, v),
      ),
    );
  }
}
// ============================================================================
// PART 4/5 — HomeTabs + ChatScreen + Community (Reddit-like)
// ============================================================================

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int index = 0;

  final tabs = const [
    CalculatorScreen(),
    ChatScreen(),
    SettingsDzScreen(),
    CommunityScreen(isOnline: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: tabs[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'حاسبة'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'شات'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'إعدادات DZ'),
          NavigationDestination(icon: Icon(Icons.dynamic_feed_outlined), label: 'مجتمع'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ChatScreen — Firebase chat + emoji picker + image upload
// ---------------------------------------------------------------------------
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgCtrl = TextEditingController();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _sending = false;

  Future<void> _pickFile() async {
    final x = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'images', extensions: ['png','jpg','jpeg','gif']),
      const XTypeGroup(label: 'docs', extensions: ['pdf'])
    ]);
    if (x == null) return;
    setState(() {
      _pickedImage = x;
    });
    // حاول قراءة bytes للمعاينة لو صورة
    final ext = x.name.toLowerCase();
    if (ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.gif')) {
      _pickedImageBytes = await x.readAsBytes();
      setState(() {});
    } else {
      _pickedImageBytes = null;
    }
  }

  void _insertEmoji(String e) {
    final t = msgCtrl.text;
    final sel = msgCtrl.selection;
    final newText = t.replaceRange(
      sel.isValid ? sel.start : t.length,
      sel.isValid ? sel.end : t.length,
      e,
    );
    setState(() {
      msgCtrl.text = newText;
      msgCtrl.selection = TextSelection.fromPosition(TextPosition(offset: (sel.isValid ? sel.start : t.length) + e.length));
    });
  }

  Future<String?> _uploadPickedIfAny() async {
    if (_pickedImage == null) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final ext = _pickedImage!.name.split('.').last;
    final ref = FirebaseStorage.instance
        .ref('chat_uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(await _pickedImage!.readAsBytes());
    return await ref.getDownloadURL();
  }

  Future<void> _send() async {
    if (_sending) return;
    final txt = msgCtrl.text.trim();
    if (txt.isEmpty && _pickedImage == null) return;
    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final url = await _uploadPickedIfAny();
      await FirebaseFirestore.instance.collection('messages').add({
        'senderUid': user?.uid,
        'sender': user?.email ?? 'Guest',
        'message': txt,
        'fileUrl': url,
        'time': FieldValue.serverTimestamp(),
      });
      msgCtrl.clear();
      setState(() {
        _pickedImage = null;
        _pickedImageBytes = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الإرسال: $e')));
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fachub • الشات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'تسجيل الخروج',
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('ابدأ المحادثة ✨'));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    final isMe = (m['senderUid'] == user?.uid);
                    final hasFile = (m['fileUrl'] as String?)?.isNotEmpty == true;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: isMe ? kFachubBlue.withOpacity(0.1) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['sender'] ?? 'مجهول',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if ((m['message'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(m['message'] ?? ''),
                            ],
                            if (hasFile) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async => await Printing.layoutPdf(
                                  onLayout: (_) async {
                                    // مجرد فتح رابط عبر printing ليس مباشراً، فعليًا يمكنك فتحه بlaunchUrl
                                    // هنا فقط نعرض Placeholder — يمكنك فتحه عبر url_launcher إن رغبت لاحقًا.
                                    final pdf = pw.Document()
                                      ..addPage(pw.Page(build: (c) => pw.Center(
                                        child: pw.Text('تم رفع ملف: ${m['fileUrl']}'),
                                      )));
                                    return pdf.save();
                                  }),
                                child: Text(
                                  '📎 ملف مرفوع',
                                  style: TextStyle(color: kFachubBlue, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // معاينة الملف المختار
          if (_pickedImage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade100),
              child: Row(
                children: [
                  if (_pickedImageBytes != null)
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(image: MemoryImage(_pickedImageBytes!), fit: BoxFit.cover),
                      ),
                    )
                  else
                    const Icon(Icons.insert_drive_file_outlined, size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_pickedImage!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    onPressed: () => setState(() { _pickedImage = null; _pickedImageBytes = null; }),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
            ),

          // شريط الإدخال
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => _EmojiSheet(onPick: _insertEmoji),
                      );
                    },
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  IconButton(
                    tooltip: 'إرفاق',
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      decoration: const InputDecoration(
                        hintText: "اكتب رسالة...",
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('إرسال'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _EmojiSheet extends StatelessWidget {
  final void Function(String) onPick;
  const _EmojiSheet({required this.onPick, super.key});
  @override
  Widget build(BuildContext context) {
    const emojis = [
      '😀','😁','😂','🤣','😊','😍','😘','😎','🤩','😇',
      '👍','👌','🙏','👏','💪','🔥','✨','🎉','✅','❌',
    ];
    return SafeArea(
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(12),
        shrinkWrap: true,
        children: emojis.map((e) => InkWell(
          onTap: () { onPick(e); Navigator.pop(context); },
          child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
        )).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CommunityScreen — Reddit-like feed: posts + likes + comments + tags + drafts
// ---------------------------------------------------------------------------
class CommunityScreen extends StatefulWidget {
  final bool isOnline;
  const CommunityScreen({super.key, required this.isOnline});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final postCtrl = TextEditingController();
  final tagCtrl = TextEditingController();
  List<XFile> _pickedImgs = [];
  List<Uint8List> _pickedImgBytes = [];

  String _tab = 'new'; // new | top
  String _searchTag = '';

  // مسوّدات محليًا
  static const _draftKey = 'community_drafts_v1';

  @override
  void dispose() {
    postCtrl.dispose();
    tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPostImages() async {
    final xs = await openFiles(acceptedTypeGroups: [
      const XTypeGroup(label: 'images', extensions: ['png','jpg','jpeg'])
    ]);
    if (xs == null || xs.isEmpty) return;
    _pickedImgs = xs;
    _pickedImgBytes = [];
    for (final x in xs) {
      try { _pickedImgBytes.add(await x.readAsBytes()); } catch (_) {}
    }
    setState(() {});
  }

  Future<List<String>> _uploadPostImages(String uid) async {
    final out = <String>[];
    for (final x in _pickedImgs) {
      final ext = x.name.split('.').last;
      final ref = FirebaseStorage.instance.ref('posts/$uid/${DateTime.now().millisecondsSinceEpoch}_${x.name}');
      await ref.putData(await x.readAsBytes(), SettableMetadata(contentType: 'image/$ext'));
      out.add(await ref.getDownloadURL());
    }
    return out;
  }

  List<String> _extractTags(String text, String manual) {
    final all = <String>{};
    final rx = RegExp(r'#([A-Za-z0-9_\u0600-\u06FF]+)');
    for (final m in rx.allMatches(text)) {
      all.add(m.group(1)!.toLowerCase());
    }
    if (manual.trim().isNotEmpty) {
      for (final part in manual.split(RegExp(r'[,\s]+'))) {
        final p = part.trim();
        if (p.isNotEmpty) all.add(p.replaceAll('#','').toLowerCase());
      }
    }
    return all.toList();
  }

  Future<void> _createPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولًا')));
      return;
    }
    final text = postCtrl.text.trim();
    if (text.isEmpty && _pickedImgs.isEmpty) return;

    try {
      final tags = _extractTags(text, tagCtrl.text);
      final images = await _uploadPostImages(user.uid);
      await FirebaseFirestore.instance.collection('posts').add({
        'authorUid': user.uid,
        'author': user.email ?? 'Guest',
        'text': text,
        'images': images,
        'tags': tags,
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      postCtrl.clear();
      tagCtrl.clear();
      _pickedImgs = [];
      _pickedImgBytes = [];
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر المنشور ✅')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر النشر: $e')));
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = prefs.getStringList(_draftKey) ?? <String>[];
    final m = {
      'text': postCtrl.text,
      'tags': tagCtrl.text,
      'time': DateTime.now().toIso8601String(),
    };
    drafts.add(jsonEncode(m));
    await prefs.setStringList(_draftKey, drafts);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المسودة')));
  }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = prefs.getStringList(_draftKey) ?? <String>[];
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد مسودات')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: drafts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = jsonDecode(drafts[i]) as Map<String, dynamic>;
              return ListTile(
                title: Text(((m['text'] ?? '') as String).takeSafe(80)),
                subtitle: Text(m['time'] ?? ''),
                trailing: Text((m['tags'] ?? '').toString()),
                onTap: () {
                  postCtrl.text = (m['text'] ?? '').toString();
                  tagCtrl.text = (m['tags'] ?? '').toString();
                  Navigator.pop(context);
                  setState(() {});
                },
              );
            },
          ),
        );
      },
    );
  }

  Query _buildQuery() {
    final col = FirebaseFirestore.instance.collection('posts');
    if (_tab == 'top') {
      return (_searchTag.isEmpty)
          ? col.orderBy('likesCount', descending: true).limit(50)
          : col.where('tags', arrayContains: _searchTag.toLowerCase())
               .orderBy('likesCount', descending: true).limit(50);
    }
    // new
    return (_searchTag.isEmpty)
        ? col.orderBy('createdAt', descending: true).limit(50)
        : col.where('tags', arrayContains: _searchTag.toLowerCase())
             .orderBy('createdAt', descending: true).limit(50);
  }

  Future<void> _toggleLike(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final postRef = doc.reference;
    final likeRef = postRef.collection('likes').doc(user.uid);
    final likeSnap = await likeRef.get();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final fresh = await tx.get(postRef);
      int likes = (fresh.data() as Map<String, dynamic>)['likesCount'] ?? 0;
      if (likeSnap.exists) {
        // إزالة إعجاب
        tx.delete(likeRef);
        tx.update(postRef, {'likesCount': (likes - 1).clamp(0, 1<<31)});
      } else {
        // إعجاب
        tx.set(likeRef, {'uid': user.uid, 'at': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likesCount': likes + 1});
      }
    });
  }

  Future<void> _addComment(DocumentSnapshot doc, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final postRef = doc.reference;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(postRef.collection('comments').doc(), {
        'uid': user.uid,
        'author': user.email ?? 'Guest',
        'text': text.trim(),
        'at': FieldValue.serverTimestamp(),
      });
      final fresh = await tx.get(postRef);
      final cc = (fresh.data() as Map<String, dynamic>)['commentsCount'] ?? 0;
      tx.update(postRef, {'commentsCount': cc + 1});
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fachub • المجتمع'),
        actions: [
          IconButton(
            tooltip: 'مسودات',
            onPressed: _loadDrafts,
            icon: const Icon(Icons.drafts_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // إنشاء منشور
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('أنشئ منشورًا', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: postCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اكتب سؤالك/فكرتك… استخدم #وسوم و @منشن',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: tagCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'وسوم إضافية (مفصولة بمسافات أو فواصل)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickPostImages,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('صور'),
                  ),
                ]),
                if (_pickedImgBytes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pickedImgBytes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(_pickedImgBytes[i], width: 74, height: 74, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _createPost,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('نشر'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ كمسودة'),
                    ),
                  ],
                ),
              ]),
            ),
          ),

          // فلاتر
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'new', label: Text('الأحدث'), icon: Icon(Icons.fiber_new)),
                  ButtonSegment(value: 'top', label: Text('الأكثر إعجابًا'), icon: Icon(Icons.trending_up)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث بالهاشتاغ (مثال: #رياضيات)',
                    isDense: true, border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => setState(() => _searchTag = v.replaceAll('#','').trim()),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snap.data!.docs;
                if (posts.isEmpty) {
                  return const Center(child: Text('لا توجد منشورات بعد.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => _postCard(posts[i], currentUid: user?.uid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(DocumentSnapshot doc, {String? currentUid}) {
    final m = doc.data() as Map<String, dynamic>;
    final text = (m['text'] ?? '').toString();
    final images = ((m['images'] ?? []) as List).cast<String>();
    final tags = ((m['tags'] ?? []) as List).cast<String>();
    final likes = (m['likesCount'] ?? 0) as int;
    final comments = (m['commentsCount'] ?? 0) as int;
    final author = (m['author'] ?? 'مجهول').toString();

    // تمييز @mentions
    InlineSpan _buildRich(String s) {
      final spans = <TextSpan>[];
      final rxMention = RegExp(r'@([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})');
      int idx = 0;
      for (final m in rxMention.allMatches(s)) {
        if (m.start > idx) spans.add(TextSpan(text: s.substring(idx, m.start)));
        spans.add(TextSpan(
          text: m.group(0)!,
          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
        ));
        idx = m.end;
      }
      if (idx < s.length) spans.add(TextSpan(text: s.substring(idx)));
      return TextSpan(children: spans, style: const TextStyle(color: Colors.black87));
    }

    final commentCtrl = TextEditingController();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(author, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: () => _toggleLike(doc),
                icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                label: Text(likes.toString()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(text: _buildRich(text)),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(images[i], width: 180, height: 140, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: tags.map((t) => Chip(label: Text('#$t'))).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.comment_outlined, size: 18),
              const SizedBox(width: 6),
              Text('$comments تعليق'),
              const Spacer(),
              IconButton(
                tooltip: 'عرض التعليقات',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _CommentsSheet(
                      postDoc: doc,
                      onAdd: (txt) => _addComment(doc, txt),
                    ),
                  );
                },
                icon: const Icon(Icons.expand_more),
              )
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'اكتب تعليقًا…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  await _addComment(doc, commentCtrl.text);
                  commentCtrl.clear();
                },
                child: const Text('تعليق'),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _CommentsSheet extends StatelessWidget {
  final DocumentSnapshot postDoc;
  final Future<void> Function(String) onAdd;
  const _CommentsSheet({super.key, required this.postDoc, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final commentsCol = postDoc.reference.collection('comments')
        .orderBy('at', descending: true);
    final ctrl = TextEditingController();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, __) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: Colors.grey.shade400, borderRadius: BorderRadius.circular(99),
                  )),
                  const SizedBox(height: 8),
                  const Text('التعليقات', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: commentsCol.snapshots(),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final cs = snap.data!.docs;
                        if (cs.isEmpty) {
                          return const Center(child: Text('لا تعليقات بعد.'));
                        }
                        return ListView.separated(
                          itemCount: cs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = cs[i].data() as Map<String, dynamic>;
                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(m['author'] ?? 'مجهول'),
                              subtitle: Text(m['text'] ?? ''),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            isDense: true, hintText: 'اكتب تعليقًا…', border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          await onAdd(ctrl.text);
                          ctrl.clear();
                        },
                        child: const Text('إرسال'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
// ============================================================================
// PART 5/5 — Helpers + Notes
// ============================================================================

// امتداد صغير لقصّ النص بأمان (استُخدم في مسودات المجتمع)
extension StringPreview on String {
  String takeSafe(int n) => (length <= n) ? this : substring(0, n);
}

// ودجت حالة فارغة (إن احتجتها مستقبلًا)
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

// ملاحظة: في CommunityScreen استخدمنا takeSafe بدلاً من take:
/// داخل _loadDrafts() في الجزء 4/5، إن أردت دقّة كاملة، استبدل:
///   title: Text((m['text'] as String?)?.take(80) ?? ''),
/// بـ:
///   title: Text(((m['text'] ?? '') as String).toString().takeSafe(80)),

// ---------------------------------------------------------------------------
// ملاحظات إعداد Firestore/Storage (مرجعية سريعة):
// ---------------------------------------------------------------------------
//
// 1) القواعد (Rules) — مثال مناسب للاختبار (عدّلها للإنتاج):
//
// Firestore:
// rules_version = '2';
// service cloud.firestore {
//   match /databases/{database}/documents {
//     function authed() { return request.auth != null; }
//     match /users/{uid}/dz_custom_templates/{doc} {
//       allow read, write: if authed() && uid == request.auth.uid;
//     }
//     match /messages/{doc} {
//       allow read: if authed();
//       allow create: if authed();
//       allow update, delete: if false;
//     }
//     match /posts/{doc} {
//       allow read: if authed();
//       allow create: if authed();
//       allow update: if false;
//       allow delete: if false;
//       match /likes/{likeId} {
//         allow read, write: if authed();
//       }
//       match /comments/{c} {
//         allow read, write: if authed();
//       }
//     }
//   }
// }
//
// Storage:
// rules_version = '2';
// service firebase.storage {
//   match /b/{bucket}/o {
//     function authed() { return request.auth != null; }
//     match /chat_uploads/{uid}/{file} {
//       allow read, write: if authed() && uid == request.auth.uid;
//     }
//     match /posts/{uid}/{file} {
//       allow read: if authed();
//       allow write: if authed() && uid == request.auth.uid;
//     }
//   }
// }
//
// 2) المسارات المستخدمة:
//    - رسائل الشات:        collection('messages')
//    - منشورات المجتمع:    collection('posts') + subcollections('likes','comments')
//    - قوالبك المخصّصة:    users/{uid}/dz_custom_templates
//    - رفع ملفات الشات:    storage path: chat_uploads/{uid}/timestamp.ext
//    - صور المنشورات:      storage path: posts/{uid}/timestamp_filename.ext
//
// 3) الأصول (Assets):
//    ضع كامل محتويات القوالب الموسّعة داخل: assets/templates_dz/  (مع index.json)
//    وتأكد من إضافة:
//    flutter:
//      assets:
//        - assets/templates_dz/
//
// 4) الحزم في pubspec.yaml (تذكير):
//    firebase_core, cloud_firestore, firebase_auth, firebase_storage,
//    shared_preferences, file_selector, pdf, printing
//
// 5) Firebase initialization:
//    استعملت import 'firebase_options.dart'; الناتج من أمر flutterfire.
//    تأكد من تشغيل: flutterfire configure
//
// 6) الألوان وهوية الواجهة:
//    الأخضر والأزرق مستخدمان (kFachubGreen, kFachubBlue). يمكنك ضبط ThemeData إن رغبت.
//
// ============================== END OF main.dart =============================
