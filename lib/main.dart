// ============================================================================
// Fachub — main.dart (FULL)
// ============================================================================

import 'dart:typed_data';
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

// Media picker
import 'package:image_picker/image_picker.dart';

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
// App root (Theme + Locale)
// ============================================================================
class FachubApp extends StatefulWidget {
  const FachubApp({super.key});

  // لنداء تغيير الثيم/اللغة من أي مكان
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
    if (themeIdx != null &&
        themeIdx >= 0 &&
        themeIdx < ThemeMode.values.length) {
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
// Global End Drawer (appears in all main screens)
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
              accountName: Text(user?.email?.split('@').first ?? 'Guest',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              accountEmail: Text(user?.email ?? 'غير مسجّل'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: kFachubBlue, size: 36),
              ),
            ),

            // تنقّل رئيسي
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('حاسبة المعدل'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalculatorScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('المجتمع'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CommunityScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('الشات'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()));
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

            // المظهر واللغة
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

            // الحساب
            if (user != null) ...[
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('إعادة تعيين كلمة المرور'),
                onTap: () async {
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: user.email!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم إرسال رابط إعادة التعيين')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذر الإرسال: $e')),
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

            // حول
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
// AuthGate + SignIn
// ============================================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
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

// ============================================================================
// Base Scaffold (هيكل عام ثابت مع Drawer)
// ============================================================================
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

// ============================================================================
// Settings + Account
// ============================================================================
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
// Community (PRO) — نص/صورة/وسوم + إعجاب + تعليقات + فرز + بحث
// ============================================================================
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _postCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  XFile? _picked;
  bool _asAnon = true;
  String _order = 'latest'; // latest | top
  String _queryTag = '';

  Future<void> _pickImage() async {
    try {
      final p = ImagePicker();
      final img =
          await p.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (img != null) setState(() => _picked = img);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر اختيار صورة: $e')),
      );
    }
  }

  Future<void> _createPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty && _picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب شيئًا أو أرفق صورة')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? imageUrl;
    if (_picked != null) {
      final bytes = await _picked!.readAsBytes();
      final path =
          'posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      imageUrl = await ref.getDownloadURL();
    }

    final tags = _tagsCtrl.text
        .split(RegExp(r'[ ,#]+'))
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.toLowerCase())
        .toList();

    await FirebaseFirestore.instance.collection('posts').add({
      'text': text,
      'image': imageUrl,
      'tags': tags,
      'uid': user.uid,
      'author':
          _asAnon ? 'طالب مجهول' : (user.email?.split('@').first ?? 'طالب'),
      'created_at': FieldValue.serverTimestamp(),
      'likes': 0,
      'liked_by': <String>[],
      'comments': 0,
    });

    setState(() {
      _postCtrl.clear();
      _tagsCtrl.clear();
      _picked = null;
    });
  }

  Future<void> _toggleLike(String id, List likedBy, int likes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = FirebaseFirestore.instance.collection('posts').doc(id);
    final has = likedBy.contains(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final data = snap.data()!;
      final lb = List<String>.from(data['liked_by'] ?? []);
      if (lb.contains(uid)) {
        lb.remove(uid);
      } else {
        lb.add(uid);
      }
      final l = (data['likes'] ?? 0) + (has ? -1 : 1);
      tx.update(doc, {'liked_by': lb, 'likes': l});
    });
  }

  Future<void> _addComment(String postId) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'اكتب تعليقًا...',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final txt = ctrl.text.trim();
              if (txt.isEmpty) return;
              final col = FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('comments');
              await col.add({
                'text': txt,
                'uid': FirebaseAuth.instance.currentUser?.uid,
                'created_at': FieldValue.serverTimestamp(),
              });
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .update({'comments': FieldValue.increment(1)});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('إرسال'),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance.collection('posts');
    final base = _order == 'top'
        ? q.orderBy('likes', descending: true).orderBy('created_at', descending: true)
        : q.orderBy('created_at', descending: true);

    final stream = _queryTag.isEmpty
        ? base.snapshots()
        : base
            .where('tags', arrayContains: _queryTag.toLowerCase())
            .snapshots();

    return BaseScaffold(
      title: 'المجتمع',
      body: Column(
        children: [
          // صندوق إنشاء منشور
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _postCtrl,
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
                        Expanded(
                          child: TextField(
                            controller: _tagsCtrl,
                            decoration: const InputDecoration(
                              hintText: 'وسوم مفصولة بمسافة…',
                              prefixIcon: Icon(Icons.tag),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'صورة',
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: _asAnon,
                          onChanged: (v) => setState(() => _asAnon = v),
                        ),
                        const Text('مجهول'),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _createPost,
                          icon: const Icon(Icons.send),
                          label: const Text('نشر'),
                        ),
                      ],
                    ),
                    if (_picked != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.photo, size: 18),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_picked!.name)),
                          IconButton(
                            onPressed: () => setState(() => _picked = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // شريط أدوات (ترتيب/بحث بالوسم)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'latest', label: Text('الأحدث')),
                    ButtonSegment(value: 'top', label: Text('الأكثر إعجابًا')),
                  ],
                  selected: {_order},
                  onSelectionChanged: (s) => setState(() => _order = s.first),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث بوسم (بدون #)…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _queryTag = v.trim()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // قائمة المنشورات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return EmptyHint(
                    icon: Icons.hourglass_empty_outlined,
                    title: 'لا توجد منشورات بعد',
                    subtitle: 'كن أول من يشارك منشورًا!',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data()! as Map<String, dynamic>;
                    final id = docs[i].id;
                    final likedBy = List<String>.from(d['liked_by'] ?? []);
                    final mine = FirebaseAuth.instance.currentUser?.uid;
                    final hasLiked = mine != null && likedBy.contains(mine);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // رأس
                            Row(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d['author'] ?? 'طالب',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                        _formatDate(d['created_at']),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton(
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                        value: 'share',
                                        child: Text('مشاركة الرابط')),
                                  ],
                                  onSelected: (v) {
                                    if (v == 'share') {
                                      final url = 'https://fachub/post/$id';
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content:
                                                  Text('تم نسخ الرابط: $url')));
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if ((d['text'] ?? '').toString().isNotEmpty)
                              Text(d['text']),

                            if ((d['image'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(d['image'],
                                    fit: BoxFit.cover),
                              ),
                            ],

                            if ((d['tags'] ?? []).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: List<Widget>.from(
                                  (d['tags'] as List).map(
                                    (t) => ActionChip(
                                      label: Text('#$t'),
                                      onPressed: () =>
                                          setState(() => _queryTag = t),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _toggleLike(
                                      id, likedBy, d['likes'] ?? 0),
                                  icon: Icon(hasLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border),
                                ),
                                Text('${d['likes'] ?? 0} إعجاب'),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: () => _addComment(id),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                ),
                                Text('${d['comments'] ?? 0} تعليق'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '';
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} • ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// الشات (محلي مبسّط)
// ============================================================================
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
                    subtitle: 'اكتب أول رسالة الآن.',
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

// ============================================================================
// الواجهة الرئيسية — شريط تنقّل سفلي + Drawer جانبي
// ============================================================================
class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

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
          NavigationDestination(
              icon: Icon(Icons.calculate_outlined), label: 'الحاسبة'),
          NavigationDestination(icon: Icon(Icons.public_outlined), label: 'المجتمع'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'الشات'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'الحساب'),
        ],
      ),
    );
  }
}

// ============================================================================
// Utilities & Helpers
// ============================================================================

class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyHint(
      {super.key, required this.icon, required this.title, this.subtitle});

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
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

extension SafeStringExt on String {
  String ellipsize(int max, {String ellipsis = '…'}) {
    if (length <= max) return this;
    if (max <= 0) return '';
    return substring(0, max) + ellipsis;
  }
}

// ============================================================================
// الدراسة (الكليات → التخصصات → الفروع → جدول المعدل)
// ============================================================================
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
// جدول المعدّل (مطابق للصورة + ملخص)
// ============================================================================

class SemesterTableCalculatorScreen extends StatefulWidget {
  final String title;
  const SemesterTableCalculatorScreen({super.key, required this.title});

  @override
  State<SemesterTableCalculatorScreen> createState() =>
      _SemesterTableCalculatorScreenState();
}

class _SemesterTableCalculatorScreenState
    extends State<SemesterTableCalculatorScreen> with TickerProviderStateMixin {
  late final TabController _tab;

  final List<ModuleRow> s1 = [
    ModuleRow(name: 'Analyse 1', coef: 4, cred: 6, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Algèbre 1', coef: 3, cred: 5, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Algorithmique et structure de données 1', coef: 3, cred: 5,
        parts: [
          PartRow(label: 'TP', weight: 0.0),
          PartRow(label: 'TD', weight: 0.3),
          PartRow(label: 'EXAM', weight: 0.7),
        ]),
    ModuleRow(name: 'Structure machine 1', coef: 3, cred: 5, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Terminologie scientifique et expression écrite', coef: 1, cred: 2, parts: [
      PartRow(label: 'EXAM', weight: 1.0),
    ]),
    ModuleRow(name: 'Langue Étrangère 1', coef: 1, cred: 2, parts: [
      PartRow(label: 'EXAM', weight: 1.0),
    ]),
    ModuleRow(name: 'Physique 1', coef: 2, cred: 4, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
  ];

  final List<ModuleRow> s2 = [
    ModuleRow(name: 'Analyse 2', coef: 4, cred: 6, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Algèbre 2', coef: 2, cred: 4, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Algorithmique et structure de données 2', coef: 3, cred: 5,
        parts: [
          PartRow(label: 'TP', weight: 0.0),
          PartRow(label: 'TD', weight: 0.3),
          PartRow(label: 'EXAM', weight: 0.7),
        ]),
    ModuleRow(name: 'Structure machine 2', coef: 2, cred: 4, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Introduction aux probabilités…', coef: 3, cred: 5, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
    ModuleRow(name: 'Technologie de l’information et de la communication',
        coef: 1, cred: 2, parts: [
          PartRow(label: 'EXAM', weight: 1.0),
        ]),
    ModuleRow(
        name: 'Outils de programmation pour les mathématiques',
        coef: 1,
        cred: 2,
        parts: [
          PartRow(label: 'TP', weight: 0.0),
          PartRow(label: 'EXAM', weight: 1.0),
        ]),
    ModuleRow(name: 'Physique 2', coef: 2, cred: 4, parts: [
      PartRow(label: 'TD', weight: 0.3),
      PartRow(label: 'EXAM', weight: 0.7),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  double _weightedAvg(List<ModuleRow> mods) {
    double w = 0, c = 0;
    for (final m in mods) {
      final a = m.average;
      if (a != null) {
        w += a * m.coef;
        c += m.coef;
      }
    }
    return c == 0 ? 0 : w / c;
    }

  int _earnedCredits(List<ModuleRow> mods) {
    int sum = 0;
    for (final m in mods) {
      final a = m.average;
      if (a != null && a >= 10) sum += m.cred;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final s1Avg = _weightedAvg(s1);
    final s2Avg = _weightedAvg(s2);
    final yAvg = (s1Avg + s2Avg) / 2.0;

    final s1Cred = _earnedCredits(s1);
    final s2Cred = _earnedCredits(s2);
    final yCred = s1Cred + s2Cred;

    return BaseScaffold(
      title: '${widget.title} • L1MI',
      body: Column(
        children: [
          const SizedBox(height: 6),
          TabBar(
            controller: _tab,
            tabs: const [Tab(text: 'SEMESTER 2'), Tab(text: 'SEMESTER 1')],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _SemesterSheet(
                  title: 'SEMESTER 2',
                  modules: s2,
                  onChanged: () => setState(() {}),
                ),
                _SemesterSheet(
                  title: 'SEMESTER 1',
                  modules: s1,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Card(
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    _summaryHeader(),
                    const Divider(),
                    _summaryRow('semestre1', s1Avg.toStringAsFixed(2), '$s1Cred'),
                    _summaryRow('semestre2', s2Avg.toStringAsFixed(2), '$s2Cred'),
                    const Divider(),
                    _summaryRow('Année', yAvg.toStringAsFixed(2), '$yCred'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryHeader() => Row(
        children: const [
          Expanded(
              child: Text('Semestre/année',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(
              width: 100,
              child: Text('Moyenne', textAlign: TextAlign.center)),
          SizedBox(width: 100, child: Text('Crédits', textAlign: TextAlign.center)),
        ],
      );

  Widget _summaryRow(String a, String b, String c) => Row(
        children: [
          Expanded(child: Text(a)),
          SizedBox(width: 100, child: Text(b, textAlign: TextAlign.center)),
          SizedBox(width: 100, child: Text(c, textAlign: TextAlign.center)),
        ],
      );
}

class _SemesterSheet extends StatelessWidget {
  final String title;
  final List<ModuleRow> modules;
  final VoidCallback onChanged;
  const _SemesterSheet({
    required this.title,
    required this.modules,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const tableWidth = 740.0; // لثبات الأعمدة ومنع overflow

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Center(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: .5)),
            ),
            const SizedBox(height: 6),
            _TableHeader(),
            const SizedBox(height: 8),
            ...modules.map((m) => _ModuleBlock(module: m, onChanged: onChanged)),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: const [
            Expanded(flex: 4, child: _HeadCell('Modules')),
            Expanded(flex: 1, child: _HeadCell('Coef')),
            Expanded(flex: 1, child: _HeadCell('Cred')),
            Expanded(flex: 1, child: _HeadCell('Note')),
            Expanded(flex: 2, child: _HeadCell('Moyenne module')),
            Expanded(flex: 1, child: _HeadCell('Cred Mod')),
          ],
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  final String title;
  const _HeadCell(this.title);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ModuleBlock extends StatelessWidget {
  final ModuleRow module;
  final VoidCallback onChanged;
  const _ModuleBlock({required this.module, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final avg = module.average ?? 0;
    final earned = (module.average ?? 0) >= 10 ? module.cred : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(flex: 4, child: Text(module.name)),
                Expanded(flex: 1, child: Center(child: Text('${module.coef}'))),
                Expanded(flex: 1, child: Center(child: Text('${module.cred}'))),
                const Expanded(flex: 1, child: SizedBox()),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(avg.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text('$earned',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const Divider(),
            Column(
              children: module.parts.map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(flex: 4, child: SizedBox()),
                      const Expanded(flex: 1, child: SizedBox()),
                      const Expanded(flex: 1, child: SizedBox()),
                      Expanded(
                        flex: 1,
                        child: _NoteField(
                          label: p.label,
                          percent: (p.weight * 100).round(),
                          controller: p.ctrl,
                          onChanged: onChanged,
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox()),
                      const Expanded(flex: 1, child: SizedBox()),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final String label;
  final int percent;
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _NoteField({
    required this.label,
    required this.percent,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label)),
        SizedBox(width: 40, child: Text('$percent%')),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: const InputDecoration(
              isDense: true,
              suffixText: '20',
              border: UnderlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class ModuleRow {
  final String name;
  final int coef;
  final int cred;
  final List<PartRow> parts;

  ModuleRow({
    required this.name,
    required this.coef,
    required this.cred,
    required this.parts,
  });

  double? get average {
    double w = 0, sum = 0;
    for (final p in parts) {
      final v = double.tryParse(p.ctrl.text);
      if (p.weight > 0 && v == null) return null;
      sum += (v ?? 0) * p.weight;
      w += p.weight;
    }
    if (w == 0) return null;
    return sum;
  }
}

class PartRow {
  final String label; // TD/EXAM/TP
  final double weight; // 0.3 => 30%
  final TextEditingController ctrl = TextEditingController();
  PartRow({required this.label, required this.weight});
}

// ============================================================================
// Placeholder Calculator Screen (للمدخل من الـDrawer)
// ============================================================================
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة المعدل')),
      endDrawer: const AppEndDrawer(),
      body: const Center(
        child: Text('شاشة الحاسبة غير موجودة حاليًا. هذه نسخة مؤقتة.'),
      ),
    );
  }
}

// ============================================================================
// ملاحظات pubspec.yaml (ضعها عندك)
// ============================================================================
// dependencies:
//   image_picker: ^1.1.2
//   firebase_core: ^2.31.1
//   cloud_firestore: ^4.15.8
//   firebase_auth: ^4.17.9
//   firebase_storage: ^11.6.9
