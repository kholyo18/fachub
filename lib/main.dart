// ============================================================================
// Fachub — main.dart (FULL, FIXED & ENHANCED) — PART 1/3
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Local
import 'package:shared_preferences/shared_preferences.dart';

// PDF / Printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Media & utils
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

// ============================================================================
// Branding
// ============================================================================
const kFachubGreen = Color(0xFF16434A);
const kFachubBlue = Color(0xFF2365EB);

// ============================================================================
// Bootstrap
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FachubApp());
}

// ============================================================================
// App root (Theme + Locale) — ثابت ويعمل: تبديل اللغة/الثيم + حفظ التفضيلات
// ============================================================================
class FachubApp extends StatefulWidget {
  const FachubApp({super.key});

  // للوصول للإعدادات من أي مكان (Drawer/Settings)
  static _FachubAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_FachubAppState>()!;

  @override
  State<FachubApp> createState() => _FachubAppState();
}

class _FachubAppState extends State<FachubApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar');

  static const _kTheme = 'pref_themeMode';
  static const _kLocale = 'pref_locale';

  @override
  void initState() {
    super.initState();
    _restorePrefs();
  }

  Future<void> _restorePrefs() async {
    final p = await SharedPreferences.getInstance();
    final themeIdx = p.getInt(_kTheme);
    final lang = p.getString(_kLocale);
    if (themeIdx != null && themeIdx >= 0 && themeIdx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIdx];
    }
    if (lang != null && lang.isNotEmpty) {
      _locale = Locale(lang);
    }
    if (mounted) setState(() {});
  }

  Future<void> setThemeMode(ThemeMode m) async {
    setState(() => _themeMode = m);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTheme, m.index);
  }

  Future<void> setLocale(Locale l) async {
    setState(() => _locale = l);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocale, l.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: kFachubBlue,
      fontFamily: 'Roboto',
    );

    return MaterialApp(
      title: 'Fachub',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(brightness: Brightness.light),
      darkTheme: base.copyWith(brightness: Brightness.dark),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

// ============================================================================
// Global End Drawer (يظهر بكل الشاشات الرئيسية)
// ============================================================================
class AppEndDrawer extends StatelessWidget {
  const AppEndDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final app = FachubApp.of(context);

    return SafeArea(
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [kFachubBlue, kFachubGreen]),
              ),
              accountName: Text(
                user?.email?.split('@').first ?? 'Guest',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              accountEmail: Text(user?.email ?? 'غير مسجّل'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: kFachubBlue, size: 36),
              ),
            ),

            // ---------------- التنقّل العام ----------------
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('حاسبة المعدل'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalculatorScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('المجتمع'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('الشات'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('الدراسة (كليّات → تخصّصات → جدول)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FacultiesScreen(faculties: demoFaculties),
                  ),
                );
              },
            ),

            const Divider(height: 24),

            // ---------------- المظهر واللغة ----------------
            ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: const Text('تغيير المظهر'),
              subtitle: Text(
                app._themeMode == ThemeMode.light
                    ? 'الوضع الفاتح'
                    : app._themeMode == ThemeMode.dark
                        ? 'الوضع الداكن'
                        : 'حسب النظام',
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _ThemeModeSheet(app: app),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('تغيير اللغة'),
              subtitle: Text(_langName(app._locale.languageCode)),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _LanguageSheet(app: app),
                );
              },
            ),

            const Divider(height: 24),

            // ---------------- الحساب ----------------
            if (user != null) ...[
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('إعادة تعيين كلمة المرور'),
                subtitle: const Text('إرسال رابط لبريدك'),
                onTap: () async {
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: user.email!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرسال رابط إعادة التعيين')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذّر الإرسال: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (_) => false,
                  );
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('تسجيل الدخول'),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
              ),
            ],

            const Divider(height: 24),

            // ---------------- حول ----------------
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('حول التطبيق'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Fachub',
                applicationVersion: '1.0.0',
                applicationIcon: const CircleAvatar(
                  backgroundColor: kFachubBlue,
                  child: Icon(Icons.school, color: Colors.white),
                ),
                children: const [
                  Text('منصة لحساب المعدل الجامعي ومجتمع للطلبة.'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('سياسة الخصوصية'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('سياسة الخصوصية'),
                    content: Text(
                      'Fachub لا يجمع بيانات شخصية خارج Firebase. جميع البيانات آمنة.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                'Fachub © ${DateTime.now().year}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _langName(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      default:
        return 'العربية';
    }
  }
}

class _ThemeModeSheet extends StatelessWidget {
  final _FachubAppState app;
  const _ThemeModeSheet({required this.app});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('اختر المظهر')),
        RadioListTile<ThemeMode>(
          value: ThemeMode.light,
          groupValue: app._themeMode,
          title: const Text('فاتح'),
          onChanged: (v) => _apply(context, v!),
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.dark,
          groupValue: app._themeMode,
          title: const Text('داكن'),
          onChanged: (v) => _apply(context, v!),
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.system,
          groupValue: app._themeMode,
          title: const Text('حسب النظام'),
          onChanged: (v) => _apply(context, v!),
        ),
      ]),
    );
  }

  void _apply(BuildContext context, ThemeMode m) {
    app.setThemeMode(m);
    Navigator.pop(context);
  }
}

class _LanguageSheet extends StatelessWidget {
  final _FachubAppState app;
  const _LanguageSheet({required this.app});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('اختر اللغة')),
        RadioListTile<String>(
          value: 'ar',
          groupValue: app._locale.languageCode,
          title: const Text('العربية'),
          onChanged: (_) => _apply(context, const Locale('ar')),
        ),
        RadioListTile<String>(
          value: 'fr',
          groupValue: app._locale.languageCode,
          title: const Text('Français'),
          onChanged: (_) => _apply(context, const Locale('fr')),
        ),
        RadioListTile<String>(
          value: 'en',
          groupValue: app._locale.languageCode,
          title: const Text('English'),
          onChanged: (_) => _apply(context, const Locale('en')),
        ),
      ]),
    );
  }

  void _apply(BuildContext context, Locale l) {
    app.setLocale(l);
    Navigator.pop(context);
  }
}

// ============================================================================
// AuthGate + SignIn + BaseScaffold + Settings + Account
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
        email: email.text.trim(),
        password: password.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _register() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل التسجيل: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.school_rounded, color: kFachubBlue, size: 64),
                const SizedBox(height: 12),
                const Text("مرحبًا بك في Fachub",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined),
                    labelText: "البريد الإلكتروني",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    labelText: "كلمة المرور",
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  FilledButton.icon(
                    onPressed: loading ? null : _login,
                    icon: const Icon(Icons.login),
                    label: const Text("دخول"),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _register,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text("تسجيل"),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final FloatingActionButton? fab;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      endDrawer: const AppEndDrawer(),
      body: body,
      floatingActionButton: fab,
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = FachubApp.of(context);
    return BaseScaffold(
      title: 'الإعدادات',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('المظهر واللغة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
              ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
              ButtonSegment(value: ThemeMode.system, label: Text('النظام')),
            ],
            selected: {app._themeMode},
            onSelectionChanged: (s) => app.setThemeMode(s.first),
          ),
          const SizedBox(height: 16),
          const Text('اللغة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          RadioListTile<String>(
            value: 'ar',
            groupValue: app._locale.languageCode,
            title: const Text('العربية'),
            onChanged: (_) => app.setLocale(const Locale('ar')),
          ),
          RadioListTile<String>(
            value: 'fr',
            groupValue: app._locale.languageCode,
            title: const Text('Français'),
            onChanged: (_) => app.setLocale(const Locale('fr')),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: app._locale.languageCode,
            title: const Text('English'),
            onChanged: (_) => app.setLocale(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return BaseScaffold(
      title: 'الحساب',
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, size: 48, color: kFachubBlue),
            ),
            const SizedBox(height: 16),
            Text(user?.email ?? 'غير مسجّل الدخول',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            if (user != null)
              FilledButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            const Spacer(),
            const Text('Fachub © 2025', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// شاشات المجتمع + الشات + التنقل السفلي + عناصر مشتركة
// ============================================================================

/// حالة فارغة قابلة لإعادة الاستخدام (لا تُنشأ بـ const في الأماكن الديناميكية)
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyHint({super.key, required this.icon, required this.title, this.subtitle});

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

// امتداد آمن للسلاسل
extension SafeStringExt on String {
  String ellipsize(int max, {String ellipsis = '…'}) {
    if (length <= max) return this;
    if (max <= 0) return '';
    return substring(0, max) + ellipsis;
  }
}

// ============================================================================
// مجتمع (إصدار مطوّر يشبه Reddit) — الجزء الأول من الواجهة
// ============================================================================

enum PostSort { newest, top }

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with AutomaticKeepAliveClientMixin {
  final _postCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _picked;
  String? _pickedType; // 'image' | 'video'

  PostSort _sort = PostSort.newest;
  String? _queryTag;
  String? _queryText;

  bool _sending = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _postCtrl.dispose();
    _tagCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img != null) {
      setState(() {
        _picked = img;
        _pickedType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final vid = await _picker.pickVideo(source: ImageSource.gallery);
    if (vid != null) {
      setState(() {
        _picked = vid;
        _pickedType = 'video';
      });
    }
  }

  Future<String?> _uploadPicked() async {
    if (_picked == null) return null;
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_picked!.name}';
    final ref = FirebaseStorage.instance.ref('community/$name');
    final data = await _picked!.readAsBytes();
    final meta = SettableMetadata(
      contentType: _pickedType == 'video' ? 'video/mp4' : 'image/jpeg',
    );
    await ref.putData(Uint8List.fromList(data), meta);
    return await ref.getDownloadURL();
  }

  Future<void> _sendPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty && _picked == null) return;

    setState(() => _sending = true);
    try {
      String? mediaUrl;
      if (_picked != null) {
        mediaUrl = await _uploadPicked();
      }

      final user = FirebaseAuth.instance.currentUser;
      final tags = _tagCtrl.text
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('posts').add({
        'text': text,
        'mediaUrl': mediaUrl,
        'mediaType': _pickedType, // image | video | null
        'tags': tags,
        'likes': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': user?.uid,
        'author': user?.email?.split('@').first ?? 'طالب مجهول',
      });

      _postCtrl.clear();
      _tagCtrl.clear();
      setState(() {
        _picked = null;
        _pickedType = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر النشر: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('posts');

    if (_queryText != null && _queryText!.isNotEmpty) {
      q = q.where('text', isGreaterThanOrEqualTo: _queryText)
          .where('text', isLessThan: '${_queryText!}~'); // prefix search
    }
    if (_queryTag != null && _queryTag!.isNotEmpty) {
      q = q.where('tags', arrayContains: _queryTag);
    }

    if (_sort == PostSort.newest) {
      q = q.orderBy('createdAt', descending: true);
    } else {
      q = q.orderBy('likes', descending: true).orderBy('createdAt', descending: true);
    }
    return q.limit(50);
  }

  Future<void> _toggleLike(DocumentSnapshot d) async {
    final doc = d.reference;
    await FirebaseFirestore.instance.runTransaction((trx) async {
      final snap = await trx.get(doc);
      final likes = (snap['likes'] ?? 0) as int;
      trx.update(doc, {'likes': likes + 1});
    });
  }

  Future<void> _addComment(DocumentReference postRef, String text) async {
    if (text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    await postRef.collection('comments').add({
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'author': user?.email?.split('@').first ?? 'طالب مجهول',
      'uid': user?.uid,
    });
  }

  void _openComments(DocumentSnapshot post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(
        post: post,
        onSend: (t) => _addComment(post.reference, t),
      ),
    );
  }

  Set<String> _uniqueTags(AsyncSnapshot<QuerySnapshot> snap) {
    final tags = <String>{};
    for (final d in snap.data!.docs) {
      final list = (d['tags'] ?? []) as List;
      tags.addAll(list.map((e) => e.toString()));
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BaseScaffold(
      title: 'المجتمع',
      body: StreamBuilder<QuerySnapshot>(
        stream: _query().snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          final tags = _uniqueTags(snap);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
            children: [
              // محرّر المنشور
              _Composer(
                postCtrl: _postCtrl,
                tagCtrl: _tagCtrl,
                sending: _sending,
                picked: _picked,
                pickedType: _pickedType,
                onPickImage: _pickImage,
                onPickVideo: _pickVideo,
                onClearPick: () => setState(() {
                  _picked = null;
                  _pickedType = null;
                }),
                onSend: _sendPost,
              ),

              const SizedBox(height: 12),

              // بحث + فرز
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _queryText = v.trim().isEmpty ? null : v.trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'بحث في المنشورات...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<PostSort>(
                    segments: const [
                      ButtonSegment(value: PostSort.newest, icon: Icon(Icons.fiber_new), label: Text('الأحدث')),
                      ButtonSegment(value: PostSort.top, icon: Icon(Icons.trending_up), label: Text('الأكثر إعجابًا')),
                    ],
                    selected: {_sort},
                    onSelectionChanged: (s) => setState(() => _sort = s.first),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // وسوم شبيهة بالـ subreddits (فلترة)
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((t) {
                    final selected = _queryTag == t;
                    return ChoiceChip(
                      label: Text('#$t'),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _queryTag = selected ? null : t;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],

              if (docs.isEmpty)
                EmptyHint(
                  icon: Icons.hourglass_empty_outlined,
                  title: 'لا توجد منشورات بعد',
                  subtitle: 'كن أوّل من يشارك منشورًا!',
                )
              else
                ...docs.map((d) => _PostCard(
                      data: d,
                      onLike: () => _toggleLike(d),
                      onComments: () => _openComments(d),
                    )),
            ],
          );
        },
      ),
    );
  }
}
// ============================================================================
// Fachub — main.dart (FULL, FIXED & ENHANCED) — PART 2/3
// (يتبع من الجزء 1/3)
// ============================================================================

// ---------------- بطاقة منشور (عرض يشبه Reddit) ----------------
class _PostCard extends StatelessWidget {
  final DocumentSnapshot data;
  final VoidCallback onLike;
  final VoidCallback onComments;

  const _PostCard({
    required this.data,
    required this.onLike,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    final d = data.data() as Map<String, dynamic>;
    final text = (d['text'] ?? '') as String;
    final author = (d['author'] ?? 'طالب مجهول') as String;
    final likes = (d['likes'] ?? 0) as int;
    final ts = (d['createdAt'] as Timestamp?);
    final when = ts != null ? DateFormat('HH:mm • yyyy/MM/dd').format(ts.toDate()) : '—';
    final mediaUrl = d['mediaUrl'] as String?;
    final mediaType = d['mediaType'] as String?;
    final tags = (d['tags'] ?? []) as List;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة: معلومات الكاتب والتاريخ
            Row(
              children: [
                const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(author, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(when, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(text, style: const TextStyle(fontSize: 15)),
            ],

            if (mediaUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: mediaType == 'video'
                    ? _VideoThumb(url: mediaUrl)
                    : Image.network(mediaUrl, fit: BoxFit.cover),
              ),
            ],

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map<Widget>((t) {
                  return Chip(
                    label: Text('#$t'),
                    // لا يوجد onPressed للـ Chip الحديثة؛ استخدم onSelected في ChoiceChip عند الحاجة
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: const Icon(Icons.favorite_border),
                ),
                Text('إعجاب $likes'),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onComments,
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                const Text('تعليقات'),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    final dRef = data.reference;
                    dRef.delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف المنشور')),
                    );
                  },
                  icon: const Icon(Icons.more_horiz),
                  tooltip: 'حذف (للتجربة)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// صورة معاينة للفيديو (ثابتة بسيطة: نستخدم أيقونة تشغيل فوق صورة مصغرة من الشبكة إن كانت mp4)
// يمكنك لاحقًا استبداله بمشغّل فيديو (video_player) إن رغبت.
class _VideoThumb extends StatelessWidget {
  final String url;
  const _VideoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black12,
            child: const Center(child: Icon(Icons.ondemand_video, size: 64)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
        ),
      ],
    );
  }
}

// محرّر المنشور (Composer)
class _Composer extends StatelessWidget {
  final TextEditingController postCtrl;
  final TextEditingController tagCtrl;
  final bool sending;
  final XFile? picked;
  final String? pickedType;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onClearPick;
  final VoidCallback onSend;

  const _Composer({
    required this.postCtrl,
    required this.tagCtrl,
    required this.sending,
    required this.picked,
    required this.pickedType,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onClearPick,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: postCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'شارك سؤالًا أو تجربة أو معلومة...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: sending ? null : onSend,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('نشر'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: sending ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('صورة'),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: sending ? null : onPickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('فيديو'),
                ),
                const Spacer(),
                if (picked != null)
                  Text(
                    picked!.name.ellipsize(30),
                    style: const TextStyle(fontSize: 12),
                  ),
                if (picked != null)
                  IconButton(
                    onPressed: onClearPick,
                    icon: const Icon(Icons.close),
                    tooltip: 'إزالة الوسائط',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tagCtrl,
              decoration: const InputDecoration(
                hintText: 'وسوم مفصولة بمسافة أو فاصلة…',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- التعليقات ----------------
class _CommentsSheet extends StatefulWidget {
  final DocumentSnapshot post;
  final Future<void> Function(String) onSend;
  const _CommentsSheet({required this.post, required this.onSend});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(_ctrl.text.trim());
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.post.reference.collection('comments').orderBy('createdAt', descending: true);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          builder: (context, controller) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 10),
                const Text('التعليقات', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: ref.snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return EmptyHint(
                          icon: Icons.forum_outlined,
                          title: 'ابدأ المحادثة ✨',
                          subtitle: 'أضف أول تعليق الآن.',
                        );
                      }
                      return ListView.builder(
                        controller: controller,
                        reverse: false,
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i].data() as Map<String, dynamic>;
                          final text = (d['text'] ?? '') as String;
                          final author = (d['author'] ?? 'طالب') as String;
                          final ts = d['createdAt'] as Timestamp?;
                          final when = ts != null ? DateFormat('HH:mm • yyyy/MM/dd').format(ts.toDate()) : '';
                          return ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(text),
                            subtitle: Text('$author • $when'),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            decoration: const InputDecoration(
                              hintText: 'اكتب تعليقًا…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _sending ? null : _send,
                          child: const Text('إرسال'),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- الشات البسيط (محلي) ----------------
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgCtrl = TextEditingController();
  final msgs = <String>[];

  void _send() {
    final txt = msgCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      msgs.insert(0, txt);
      msgCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'الشات',
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? EmptyHint(
                    icon: Icons.forum_outlined,
                    title: 'ابدأ المحادثة ✨',
                    subtitle: 'أضف أول رسالة الآن.',
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(msgs[i]),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _send, child: const Text('إرسال')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- الواجهة الرئيسية (NavigationBar) ----------------
class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 1; // المجتمع واجهة رئيسية افتراضيًا

  final pages = const [
    CalculatorScreen(),
    CommunityScreen(),
    ChatScreen(),
    SettingsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppEndDrawer(),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate_outlined), label: 'الحاسبة'),
          NavigationDestination(icon: Icon(Icons.public_outlined), label: 'المجتمع'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'الشات'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'الحساب'),
        ],
      ),
    );
  }
}

// ============================================================================
// الدراسة (الكليات → التخصصات → الفروع)
// ============================================================================

// نموذج تمثيلي للبيانات
final demoFaculties = [
  Faculty(
    name: 'كلية العلوم الاقتصادية والتجارية وعلوم التسيير',
    majors: [
      Major(
        name: 'علوم التسيير',
        tracks: [
          'تسيير الموارد البشرية',
          'تسويق',
          'مالية ومحاسبة',
          'إدارة الأعمال',
        ],
      ),
      Major(
        name: 'العلوم الاقتصادية',
        tracks: [
          'اقتصاد دولي',
          'اقتصاد نقدي ومالي',
          'اقتصاد وتسيير المؤسسات',
        ],
      ),
    ],
  ),
  Faculty(
    name: 'كلية التكنولوجيا',
    majors: [
      Major(
        name: 'هندسة مدنية',
        tracks: ['منشآت', 'طرق وجسور', 'هندسة معمارية'],
      ),
      Major(
        name: 'هندسة كهربائية',
        tracks: ['الكترونيك', 'كهرباء صناعية', 'طاقة'],
      ),
    ],
  ),
];

// نماذج البيانات
class Faculty {
  final String name;
  final List<Major> majors;
  Faculty({required this.name, required this.majors});
}

class Major {
  final String name;
  final List<String> tracks;
  Major({required this.name, required this.tracks});
}

// واجهة عرض الكليات
class FacultiesScreen extends StatelessWidget {
  final List<Faculty> faculties;
  const FacultiesScreen({super.key, required this.faculties});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'الكليات',
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: faculties.length,
        itemBuilder: (_, i) {
          final f = faculties[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text(f.name),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacultyMajorsScreen(faculty: f),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// واجهة عرض التخصصات لكل كلية
class FacultyMajorsScreen extends StatelessWidget {
  final Faculty faculty;
  const FacultyMajorsScreen({super.key, required this.faculty});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: faculty.name,
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: faculty.majors.length,
        itemBuilder: (_, i) {
          final m = faculty.majors[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(m.name),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MajorTracksScreen(major: m),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// واجهة عرض الفروع
class MajorTracksScreen extends StatelessWidget {
  final Major major;
  const MajorTracksScreen({super.key, required this.major});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: major.name,
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: major.tracks.length,
        itemBuilder: (_, i) {
          final t = major.tracks[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(t),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SemesterTableCalculatorScreen(title: t),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
// ============================================================================
// Fachub — main.dart (FULL, FIXED & ENHANCED) — PART 3/3
// (تكملة من الجزء 2/3)
// ============================================================================

class SemesterTableCalculatorScreen extends StatefulWidget {
  final String title; // اسم الفرع (مثلاً: تسويق)
  const SemesterTableCalculatorScreen({super.key, required this.title});

  @override
  State<SemesterTableCalculatorScreen> createState() =>
      _SemesterTableCalculatorScreenState();
}

// إعدادات موديول (اسم+معامل+رصيد+نِسَب TD/TP/EXAM)
class _ModuleCfg {
  String name;
  int coef;
  int cred;
  double tdW;   // 0..1
  double tpW;   // 0..1
  double examW; // 0..1

  // العلامات
  double td = 0;
  double tp = 0;
  double exam = 0;

  _ModuleCfg({
    required this.name,
    required this.coef,
    required this.cred,
    this.tdW = 0.3,
    this.tpW = 0.0,
    this.examW = 0.7,
  });

  double get moyenne {
    final totalW = tdW + tpW + examW;
    if (totalW <= 0) return 0;
    return (td * tdW + tp * tpW + exam * examW) / totalW;
  }
}

class _SemesterCfg {
  final String name; // S1 أو S2
  final List<_ModuleCfg> modules;
  _SemesterCfg(this.name, this.modules);

  double get avg {
    if (modules.isEmpty) return 0;
    double wSum = 0, s = 0;
    for (final m in modules) {
      wSum += m.coef.toDouble();
      s += m.moyenne * m.coef;
    }
    return wSum == 0 ? 0 : s / wSum;
  }

  int get creditsValidated {
    int c = 0;
    for (final m in modules) {
      if (m.moyenne >= 10) c += m.cred;
    }
    return c;
  }

  int get totalCredits => modules.fold(0, (p, m) => p + m.cred);
}

// تكوين افتراضي مطابق للصورة (شكل عام L1MI)
_SemesterCfg _buildS1() {
  return _SemesterCfg('SEMESTER 1', [
    _ModuleCfg(name: 'Analyse 1',      coef: 4, cred: 6, tdW: .3, tpW: 0,   examW: .7),
    _ModuleCfg(name: 'Algèbre 1',      coef: 3, cred: 5, tdW: .3, tpW: 0,   examW: .7),
    _ModuleCfg(name: 'Algorithmique 1',coef: 4, cred: 6, tdW: .2, tpW: .2, examW: .6),
    _ModuleCfg(name: 'Structure machine 1', coef: 3, cred: 4, tdW: .3, tpW: 0, examW: .7),
    _ModuleCfg(name: 'Terminologie scientifique', coef: 1, cred: 2, tdW: 0, tpW: 0, examW: 1),
    _ModuleCfg(name: 'Langue Étrangère 1',       coef: 1, cred: 2, tdW: 0, tpW: 0, examW: 1),
    _ModuleCfg(name: 'Physique 1',     coef: 2, cred: 4, tdW: .2, tpW: 0,   examW: .8),
    _ModuleCfg(name: 'Unité Découverte', coef: 2, cred: 2, tdW: 0, tpW: 0, examW: 1),
  ]);
}

_SemesterCfg _buildS2() {
  return _SemesterCfg('SEMESTER 2', [
    _ModuleCfg(name: 'Analyse 2',            coef: 4, cred: 6, tdW: .3, tpW: 0,   examW: .7),
    _ModuleCfg(name: 'Algèbre 2',            coef: 2, cred: 4, tdW: .3, tpW: 0,   examW: .7),
    _ModuleCfg(name: 'Algorithmique 2',      coef: 4, cred: 6, tdW: .2, tpW: .2, examW: .6),
    _ModuleCfg(name: 'Structure machine 2',  coef: 2, cred: 2, tdW: 0,  tpW: .4, examW: .6),
    _ModuleCfg(name: 'Proba & Stat Descr.',  coef: 3, cred: 3, tdW: .3, tpW: 0,   examW: .7),
    _ModuleCfg(name: 'TIC',                  coef: 1, cred: 2, tdW: 0,  tpW: 0,   examW: 1),
    _ModuleCfg(name: 'Outils Prog. Maths',   coef: 1, cred: 2, tdW: 0,  tpW: .4, examW: .6),
    _ModuleCfg(name: 'Physique 2',           coef: 3, cred: 3, tdW: .3, tpW: 0,   examW: .7),
    _ModuleCfg(name: 'Unité Découverte',     coef: 2, cred: 2, tdW: 0,  tpW: 0,   examW: 1),
  ]);
}

class _SemesterTableCalculatorScreenState
    extends State<SemesterTableCalculatorScreen> with TickerProviderStateMixin {
  late final TabController _tab;
  late _SemesterCfg s1;
  late _SemesterCfg s2;

  @override
  void initState() {
    super.initState();
    s1 = _buildS1();
    s2 = _buildS2();
    _tab = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('L1MI • ${widget.title}'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'SEMESTER 1'),
            Tab(text: 'SEMESTER 2'),
          ],
        ),
      ),
      endDrawer: const AppEndDrawer(),
      body: TabBarView(
        controller: _tab,
        children: [
          _SemesterView(sem: s1, other: s2, tab: _tab),
          _SemesterView(sem: s2, other: s1, tab: _tab),
        ],
      ),
    );
  }
}

// واجهة فصل واحد + الخلاصة السفلية
class _SemesterView extends StatefulWidget {
  final _SemesterCfg sem;
  final _SemesterCfg other; // للفصل الآخر لحساب السنة
  final TabController tab;
  const _SemesterView({required this.sem, required this.other, required this.tab});

  @override
  State<_SemesterView> createState() => _SemesterViewState();
}

class _SemesterViewState extends State<_SemesterView> {
  @override
  Widget build(BuildContext context) {
    final sem = widget.sem;
    final other = widget.other;

    final sAvg = sem.avg;
    final oAvg = other.avg;

    final yearAvg = (sAvg + oAvg) / 2;
    final yearCred = sem.creditsValidated + other.creditsValidated;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // عنوان الفصل (مطابق للصورة)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            sem.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),

        // رأس الجدول
        _headerRow(),

        const SizedBox(height: 8),

        // كل موديول في بطاقة تشبه صف الجدول
        ...sem.modules.map((m) => _moduleCard(m)).toList(),

        const SizedBox(height: 14),

        // الخلاصة السفليّة
        _summaryCard(
          sem,
          other,
          sAvg: sAvg,
          oAvg: oAvg,
          yearAvg: yearAvg,
          yearCred: yearCred,
        ),
      ],
    );
  }

  Widget _headerRow() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: const [
            Expanded(flex: 5, child: Text('Modules', style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: 10),
            SizedBox(width: 40, child: Text('Coef', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: 50, child: Text('Cred', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: 120, child: Text('Moyenne module', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(_ModuleCfg m) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          children: [
            // السطر العلوي (اسم، coef، cred، moyenne)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(width: 10),
                SizedBox(width: 40, child: Text('${m.coef}', textAlign: TextAlign.center)),
                SizedBox(width: 50, child: Text('${m.cred}', textAlign: TextAlign.center)),
                SizedBox(
                  width: 120,
                  child: Text(
                    m.moyenne.toStringAsFixed(2),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // أسطر TD/TP/EXAM مع النِّسَب وحقول إدخال العلامات
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  _componentLine(
                    label: 'TD',
                    weightPct: (m.tdW * 100).round(),
                    value: m.td,
                    onChanged: (v) => setState(() => m.td = v),
                  ),
                  if (m.tpW > 0)
                    _componentLine(
                      label: 'TP',
                      weightPct: (m.tpW * 100).round(),
                      value: m.tp,
                      onChanged: (v) => setState(() => m.tp = v),
                    ),
                  _componentLine(
                    label: 'EXAM',
                    weightPct: (m.examW * 100).round(),
                    value: m.exam,
                    onChanged: (v) => setState(() => m.exam = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _componentLine({
    required String label,
    required int weightPct,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        // % في اليسار
        SizedBox(
          width: 60,
          child: Text(
            '$weightPct%',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        // اسم المكوّن
        SizedBox(width: 60, child: Text(label)),
        const Spacer(),
        // حقل علامة 0..20
        SizedBox(
          width: 80,
          child: TextField(
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '0..20',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: value == 0 ? '' : value.toString()),
            onSubmitted: (t) {
              final v = double.tryParse(t.replaceAll(',', '.')) ?? 0;
              final clamped = v.clamp(0, 20);
              onChanged(clamped.toDouble());
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    _SemesterCfg sem,
    _SemesterCfg other, {
    required double sAvg,
    required double oAvg,
    required double yearAvg,
    required int yearCred,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // رأس صغير
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'Semestre/année',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 100, child: Text('Moyenne', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 80, child: Text('Crédits', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            _summaryRow(
              'semestre1',
              (widget.tab.index == 0 ? sAvg : oAvg).toStringAsFixed(2),
              (widget.tab.index == 0 ? sem.creditsValidated : other.creditsValidated).toString(),
            ),
            _summaryRow(
              'semestre2',
              (widget.tab.index == 1 ? sAvg : oAvg).toStringAsFixed(2),
              (widget.tab.index == 1 ? sem.creditsValidated : other.creditsValidated).toString(),
            ),
            const Divider(),
            _summaryRow('Année', yearAvg.toStringAsFixed(2), yearCred.toString()),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String a, String b, String c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(a, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 100, child: SizedBox()),
          SizedBox(
            width: 100,
            child: Text(b, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 80,
            child: Text(c, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الحاسبة العامة (واجهة بسيطة مؤقتة)
// ============================================================================
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'حاسبة المعدل',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calculate_outlined, size: 64, color: kFachubBlue),
              const SizedBox(height: 12),
              const Text(
                'هذه نسخة مبسطة — انتقل إلى "الدراسة" لاستخدام جدول الفصول المفصّل.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FacultiesScreen(faculties: demoFaculties),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('فتح مسار الدراسة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// عناصر مساعدة عامة (قد تكون معرفة سابقًا)
// ============================================================================



// ============================================================================
// نهاية الملف ✅
// ============================================================================
