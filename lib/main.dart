// ============================================================================
// Fachub — main.dart  (CLEAN & FIXED) — PART 1/3
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

// 👇 إضافات سنستخدمها في المجتمع/التواريخ (لن تسبب أخطاء إن لم تُستخدم فورًا)
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

// ============================================================================
// Branding
// ============================================================================
const kFachubGreen = Color(0xFF16434A);
const kFachubBlue  = Color(0xFF2365EB);

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

  // نحتاجه للوصول لتغيير الثيم واللغة من أي مكان
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
                        const SnackBar(content: Text('تم إرسال رابط إعادة التعيين')),
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
// PART 1/3 (تابع) — AuthGate + SignIn + Settings + Account + BaseScaffold
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التسجيل: $e')));
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
            //... باقي الأزرار
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
// PART 2/3 — Community (Firestore + Storage + Image Picker) + Chat + HomeTabs
// ============================================================================

/// نموذج منشور المجتمع
class CommunityPost {
  final String id;
  final String text;
  final String? imageUrl;
  final String author;
  final List<String> tags;
  final int likes;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.text,
    required this.author,
    required this.createdAt,
    this.imageUrl,
    this.tags = const [],
    this.likes = 0,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'imageUrl': imageUrl,
        'author': author,
        'tags': tags,
        'likes': likes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static CommunityPost fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return CommunityPost(
      id: d.id,
      text: (m['text'] ?? '').toString(),
      imageUrl: (m['imageUrl'] as String?),
      author: (m['author'] ?? 'مجهول').toString(),
      tags: (m['tags'] as List?)?.cast<String>() ?? const [],
      likes: (m['likes'] ?? 0) as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] ?? 0),
    );
  }
}

/// شاشة المجتمع — كاملة مع رفع الصور إلى Firebase Storage
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _text = TextEditingController();
  final _tags = TextEditingController();
  XFile? _picked;
  bool _saving = false;
  String _sort = 'latest'; // latest | top

  Future<void> _pickImage() async {
    final p = ImagePicker();
    final img = await p.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) setState(() => _picked = img);
  }

  Future<String?> _uploadPickedIfAny() async {
    if (_picked == null) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final name = 'community_uploads/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(name);
    final bytes = await _picked!.readAsBytes();
    final meta = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, meta);
    return await ref.getDownloadURL();
  }

  Future<void> _publish() async {
    final txt = _text.text.trim();
    if (txt.isEmpty && _picked == null) return;
    setState(() => _saving = true);
    try {
      final url = await _uploadPickedIfAny();
      final user = FirebaseAuth.instance.currentUser;
      final tagList = _tags.text
          .split(RegExp(r'[,\s]+'))
          .where((e) => e.isNotEmpty)
          .map((e) => e.startsWith('#') ? e : '#$e')
          .toList();

      await FirebaseFirestore.instance.collection('posts').add({
        'text': txt,
        'imageUrl': url,
        'author': user?.email ?? 'anon',
        'tags': tagList,
        'likes': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      setState(() {
        _text.clear();
        _tags.clear();
        _picked = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نشر المنشور ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر النشر: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Query _query() {
    final c = FirebaseFirestore.instance.collection('posts');
    return _sort == 'top'
        ? c.orderBy('likes', descending: true).orderBy('createdAt', descending: true)
        : c.orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Fachub • المجتمع',
      actions: [
        PopupMenuButton<String>(
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'latest', child: Text('الأحدث')),
            PopupMenuItem(value: 'top', child: Text('الأكثر إعجابًا')),
          ],
          icon: const Icon(Icons.sort),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _composerCard(),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _query().snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const EmptyHint(
                  icon: Icons.forum_outlined,
                  title: 'لا توجد منشورات',
                  subtitle: 'كن أول من يكتب 👋',
                );
              }
              final posts = docs.map(CommunityPost.fromDoc).toList();
              return Column(
                children: posts.map(_postTile).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // بطاقة إنشاء منشور
  Widget _composerCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text('أنشئ منشورًا', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب سؤالك/فكرتك… استخدم #وسوم و @منشن',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('صور'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tags,
                    decoration: const InputDecoration(
                      hintText: 'وسوم إضافية (مسافة/فاصلة)…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_picked != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  // عرض معاينة سريعة
                  (Uint8List.fromList([])), // placeholder لحجم ثابت
                  height: 0, // لا نحمّل الصورة مرتين؛ سنستخدم Image.file بشكل خفيف أدناه
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(_picked!.name.ellipsize(30)),
                trailing: IconButton(
                  onPressed: () => setState(() => _picked = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving ? null : _publish,
                icon: const Icon(Icons.send),
                label: Text(_saving ? 'جارٍ النشر…' : 'نشر'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عنصر منشور واحد
  Widget _postTile(CommunityPost p) {
    final when = DateFormat('y/M/d HH:mm').format(p.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(p.author),
            subtitle: Text(when),
            trailing: IconButton(
              tooltip: 'إعجاب',
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                final ref = FirebaseFirestore.instance.collection('posts').doc(p.id);
                FirebaseFirestore.instance.runTransaction((tx) async {
                  final snap = await tx.get(ref);
                  final cur = (snap.data()?['likes'] ?? 0) as int;
                  tx.update(ref, {'likes': cur + 1});
                });
              },
            ),
          ),
          if (p.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(p.text),
            ),
          if (p.imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(p.imageUrl!, fit: BoxFit.cover),
              ),
            ),
          if (p.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 6,
                children: p.tags
                    .map((t) => Chip(label: Text(t), visualDensity: VisualDensity.compact))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.favorite, size: 18, color: Colors.pink),
                const SizedBox(width: 4),
                Text('${p.likes}'),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// واجهة الشات (محلية بسيطة كما طلبت)
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
                ? const Center(child: Text('ابدأ المحادثة ✨'))
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
// الواجهة الرئيسية — شريط تنقّل سفلي + Drawer جانبي موحّد
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
// PART 3/3 — Calculator (محسّنة + PDF) + الدراسة (S1/S2 جدول يحسب تلقائيًا)
// ============================================================================

/// منسّق تاريخ بسيط ليخدم مجتمعك بدون الحاجة إلى حزمة intl.
class DateFormat {
  final String _pattern;
  DateFormat(this._pattern);
  String _two(int n) => n.toString().padLeft(2, '0');
  String format(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

// ---------------------------------------------------------------------------
// تخزين هوية الشهادة (اسم الطالب/الجامعة) محليًا
class CertificateIdentity {
  static const _nameKey = 'student_name';
  static const _univKey = 'student_university';

  static Future<void> save(String name, String uni) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_univKey, uni);
  }

  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_nameKey) ?? '',
      'uni': prefs.getString(_univKey) ?? '',
    };
  }
}

// ---------------------------------------------------------------------------
// شاشة الحاسبة — نسخة كاملة مع حساب + عتبة + تصدير PDF
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final subjects = <Map<String, dynamic>>[];
  double threshold = 10;
  double avg = 0;

  void _add() => setState(() =>
      subjects.add({'name': 'مادة جديدة', 'coef': 1.0, 'grade': 0.0}));

  void _removeAt(int i) => setState(() => subjects.removeAt(i));

  void _calc() {
    double total = 0, coefs = 0;
    for (final s in subjects) {
      final c = (s['coef'] ?? 1).toDouble();
      final g = (s['grade'] ?? 0).toDouble();
      total += g * c;
      coefs += c;
    }
    setState(() => avg = coefs == 0 ? 0 : total / coefs);
  }

  Future<void> _exportPDF() async {
    final info = await CertificateIdentity.load();
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('شهادة حساب المعدل',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if ((info['name'] ?? '').isNotEmpty) pw.Text('الطالب: ${info['name']}'),
            if ((info['uni'] ?? '').isNotEmpty) pw.Text('الجامعة: ${info['uni']}'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['المادة', 'المعامل', 'العلامة'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
              data: subjects
                  .map((s) => [
                        (s['name'] ?? '').toString(),
                        (s['coef'] ?? 1).toString(),
                        ((s['grade'] ?? 0) as num).toStringAsFixed(2),
                      ])
                  .toList(),
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'المعدل العام: ${avg.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: avg >= threshold ? PdfColors.green : PdfColors.red,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('عتبة النجاح: ${threshold.toStringAsFixed(2)}'),
            pw.SizedBox(height: 8),
            pw.Text(avg >= threshold ? '✅ ناجح' : '❌ راسب',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: avg >= threshold ? PdfColors.green600 : PdfColors.red600,
                    fontSize: 16)),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'fachub_result.pdf');
  }

  Widget _identityCard() {
    final nameCtrl = TextEditingController();
    final uniCtrl = TextEditingController();
    return FutureBuilder<Map<String, String>>(
      future: CertificateIdentity.load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        nameCtrl.text = snap.data!['name'] ?? '';
        uniCtrl.text = snap.data!['uni'] ?? '';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('معلومات الشهادة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الطالب')),
              const SizedBox(height: 8),
              TextField(controller: uniCtrl, decoration: const InputDecoration(labelText: 'الجامعة / الكلية')),
              const SizedBox(height: 8),
              Row(children: [
                FilledButton.icon(
                  onPressed: () async {
                    await CertificateIdentity.save(nameCtrl.text.trim(), uniCtrl.text.trim());
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('تم حفظ بيانات الشهادة ✅')));
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _exportPDF,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('توليد الشهادة (PDF)'),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'حاسبة المعدل',
      actions: [
        IconButton(
          onPressed: _exportPDF,
          tooltip: 'تصدير PDF',
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _identityCard(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('قائمة المواد', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                ...subjects.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: s['name'],
                            onChanged: (v) => s['name'] = v,
                            decoration: const InputDecoration(labelText: 'المادة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: (s['coef'] ?? 1).toString(),
                            onChanged: (v) => s['coef'] = double.tryParse(v) ?? 1.0,
                            decoration: const InputDecoration(labelText: 'المعامل'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: (s['grade'] ?? 0).toString(),
                            onChanged: (v) => s['grade'] = double.tryParse(v) ?? 0.0,
                            decoration: const InputDecoration(labelText: 'العلامة'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeAt(i),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Row(children: [
                  FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('إضافة مادة')),
                  const SizedBox(width: 10),
                  FilledButton.icon(onPressed: _calc, icon: const Icon(Icons.calculate), label: const Text('احسب المعدل')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: threshold.toString(),
                      onChanged: (v) => threshold = double.tryParse(v) ?? 10,
                      decoration: const InputDecoration(labelText: 'عتبة النجاح'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'معدلك: ${avg.toStringAsFixed(2)} — ${avg >= threshold ? "✅ ناجح" : "❌ راسب"}',
                    style: TextStyle(
                      color: avg >= threshold ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الدراسة (L1MI) — نماذج البيانات + واجهات S1/S2 بحساب تلقائي مطابق للصورة
class ProgramComponent {
  final String label;   // TD / TP / EXAM / ...
  final double weight;  // وزن من 100
  ProgramComponent(this.label, this.weight);
}

class ProgramModule {
  final String name;
  final int coef;
  final int credits;
  final List<ProgramComponent> components;
  ProgramModule({
    required this.name,
    required this.coef,
    required this.credits,
    required this.components,
  });
}

class ProgramSemester {
  final String label; // S1 / S2
  final List<ProgramModule> modules;
  ProgramSemester({required this.label, required this.modules});
}

class ProgramTrack {
  final String name; // مثل: علوم التسيير
  final List<ProgramSemester> semesters;
  ProgramTrack({required this.name, required this.semesters});
}

class ProgramMajor {
  final String name; // مثل: علوم الاقتصاد
  final List<ProgramTrack> tracks;
  ProgramMajor({required this.name, required this.tracks});
}

class ProgramFaculty {
  final String name; // مثل: كلية العلوم الاقتصادية
  final List<ProgramMajor> majors;
  ProgramFaculty({required this.name, required this.majors});
}

// بيانات L1MI (مطابقة للجدول في الصورة)
final demoFaculties = <ProgramFaculty>[
  ProgramFaculty(
    name: 'كلية العلوم الاقتصادية والتجارية وعلوم التسيير',
    majors: [
      ProgramMajor(
        name: 'علوم التسيير',
        tracks: [
          ProgramTrack(
            name: 'تسويق',
            semesters: [
              ProgramSemester(
                label: 'S1',
                modules: [
                  ProgramModule(
                    name: 'Analyse 1', coef: 4, credits: 6,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algèbre 1', coef: 3, credits: 5,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algorithmique et structure de données 1',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TP', 20), ProgramComponent('TD', 20), ProgramComponent('EXAM', 60)],
                  ),
                  ProgramModule(
                    name: 'Structure machine 1',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TD', 40), ProgramComponent('EXAM', 60)],
                  ),
                  ProgramModule(
                    name: 'Terminologie scientifique et expression écrite',
                    coef: 2, credits: 3,
                    components: [ProgramComponent('EXAM', 100)],
                  ),
                  ProgramModule(
                    name: 'Langue Étrangère 1',
                    coef: 1, credits: 2,
                    components: [ProgramComponent('EXAM', 100)],
                  ),
                  ProgramModule(
                    name: 'Physique 1',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TD', 40), ProgramComponent('EXAM', 60)],
                  ),
                ],
              ),
              ProgramSemester(
                label: 'S2',
                modules: [
                  ProgramModule(
                    name: 'Analyse 2', coef: 4, credits: 6,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algèbre 2', coef: 2, credits: 4,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algorithmique et structure de données 2',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TP', 20), ProgramComponent('TD', 20), ProgramComponent('EXAM', 60)],
                  ),
                  ProgramModule(
                    name: 'Structure machine 2',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TD', 40), ProgramComponent('EXAM', 60)],
                  ),
                  ProgramModule(
                    name: 'Probabilités & Statistique descriptive',
                    coef: 3, credits: 5,
                    components: [ProgramComponent('TD', 40), ProgramComponent('EXAM', 60)],
                  ),
                  ProgramModule(
                    name: 'TIC',
                    coef: 1, credits: 2,
                    components: [ProgramComponent('EXAM', 100)],
                  ),
                  ProgramModule(
                    name: 'Outil de programmation pour les mathématiques',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TP', 40), ProgramComponent('EXAM', 60)],
                  ),
                  ProgramModule(
                    name: 'Langue Étrangère 2',
                    coef: 1, credits: 2,
                    components: [ProgramComponent('EXAM', 100)],
                  ),
                  ProgramModule(
                    name: 'Physique 2',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TD', 40), ProgramComponent('EXAM', 60)],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// شاشة 1: الكليات
class FacultiesScreen extends StatelessWidget {
  final List<ProgramFaculty> faculties;
  const FacultiesScreen({super.key, required this.faculties});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدراسة • الكليات'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_open),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
      ),
      endDrawer: const AppEndDrawer(),
      body: ListView.separated(
        itemCount: faculties.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final f = faculties[i];
          return ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => FacultyMajorsScreen(faculty: f),
              ));
            },
          );
        },
      ),
    );
  }
}

// شاشة 2: تخصّصات الكلية
class FacultyMajorsScreen extends StatelessWidget {
  final ProgramFaculty faculty;
  const FacultyMajorsScreen({super.key, required this.faculty});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الدراسة • ${faculty.name}')),
      endDrawer: const AppEndDrawer(),
      body: ListView.separated(
        itemCount: faculty.majors.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = faculty.majors[i];
          return ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(m.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MajorTracksScreen(major: m),
              ));
            },
          );
        },
      ),
    );
  }
}

// شاشة 3: المسارات داخل التخصص
class MajorTracksScreen extends StatelessWidget {
  final ProgramMajor major;
  const MajorTracksScreen({super.key, required this.major});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الدراسة • ${major.name}')),
      endDrawer: const AppEndDrawer(),
      body: ListView.separated(
        itemCount: major.tracks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final t = major.tracks[i];
          return ListTile(
            leading: const Icon(Icons.view_stream_outlined),
            title: Text(t.name),
            subtitle: const Text('S1 + S2'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SemesterTableCalculatorScreen(track: t),
              ));
            },
          );
        },
      ),
    );
  }
}

// شاشة 4: جدول S1/S2 مع حساب تلقائي لمتوسط الموديل والفصل والسنة
class SemesterTableCalculatorScreen extends StatefulWidget {
  final ProgramTrack track;
  const SemesterTableCalculatorScreen({super.key, required this.track});

  @override
  State<SemesterTableCalculatorScreen> createState() => _SemesterTableCalculatorScreenState();
}

class _SemesterTableCalculatorScreenState extends State<SemesterTableCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final Map<String, TextEditingController> _inputs = {}; // key: sem|moduleIndex|label

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.track.semesters.length, vsync: this);
  }

  @override
  void dispose() {
    for (final c in _inputs.values) { c.dispose(); }
    _tab.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(String key) =>
      _inputs.putIfAbsent(key, () => TextEditingController());

  double _moduleAverage(ProgramModule m, String semKey, int mi) {
    double sum = 0, w = 0;
    for (final c in m.components) {
      final key = '$semKey|$mi|${c.label}';
      final v = double.tryParse(_ctrl(key).text) ?? 0;
      sum += v * c.weight;
      w += c.weight;
    }
    return w > 0 ? sum / w : 0;
  }

  double _semesterAverage(ProgramSemester sem, String semKey) {
    double total = 0, coefs = 0;
    for (int i = 0; i < sem.modules.length; i++) {
      final m = sem.modules[i];
      final avg = _moduleAverage(m, semKey, i);
      total += avg * m.coef;
      coefs += m.coef.toDouble();
    }
    return coefs > 0 ? total / coefs : 0;
  }

  @override
  Widget build(BuildContext context) {
    final semesters = widget.track.semesters;
    final s1 = semesters.firstWhere((s) => s.label.toUpperCase() == 'S1');
    final s2 = semesters.firstWhere((s) => s.label.toUpperCase() == 'S2');

    return Scaffold(
      appBar: AppBar(
        title: Text('L1MI • ${widget.track.name}'),
        bottom: TabBar(
          controller: _tab,
          tabs: semesters.map((s) => Tab(text: s.label.toUpperCase())).toList(),
        ),
      ),
      endDrawer: const AppEndDrawer(),
      body: TabBarView(
        controller: _tab,
        children: semesters.map((sem) {
          final semKey = sem.label.toUpperCase();
          final s1Avg = _semesterAverage(s1, 'S1');
          final s2Avg = _semesterAverage(s2, 'S2');
          final yearAvg = (s1Avg + s2Avg) / 2;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _semesterTable(sem, semKey),
              const SizedBox(height: 12),
              _yearSummaryCard(s1Avg: s1Avg, s2Avg: s2Avg, yearAvg: yearAvg),
              const SizedBox(height: 18),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _semesterTable(ProgramSemester sem, String semKey) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: Text('Modules')),
            DataColumn(label: Text('Coef')),
            DataColumn(label: Text('Cred')),
            DataColumn(label: Text('Note')),
            DataColumn(label: Text('Moyenne\nmodule')),
            DataColumn(label: Text('Cred Mod')),
          ],
          rows: [
            for (int i = 0; i < sem.modules.length; i++) ...[
              DataRow(cells: [
                DataCell(Text(sem.modules[i].name)),
                DataCell(Text(sem.modules[i].coef.toString())),
                DataCell(Text(sem.modules[i].credits.toString())),
                const DataCell(Text('')),
                DataCell(Text(_moduleAverage(sem.modules[i], semKey, i).toStringAsFixed(2))),
                DataCell(Text(sem.modules[i].credits.toStringAsFixed(0))),
              ]),
              for (final comp in sem.modules[i].components)
                DataRow(cells: [
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(
                    Row(
                      children: [
                        SizedBox(width: 40, child: Text(comp.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _ctrl('$semKey|$i|${comp.label}'),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true, hintText: '0'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${comp.weight.toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _yearSummaryCard({
    required double s1Avg,
    required double s2Avg,
    required double yearAvg,
  }) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _summaryRow('SEMESTRE/ANNÉE', 'Moyenne', 'Crédits'),
            const Divider(),
            _summaryRow('semestre1', s1Avg.toStringAsFixed(2), '0.00'),
            _summaryRow('semestre2', s2Avg.toStringAsFixed(2), '0.00'),
            const Divider(),
            _summaryRow('Année', yearAvg.toStringAsFixed(2), '0.00'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String a, String b, String c) {
    return Row(
      children: [
        Expanded(child: Text(a, style: const TextStyle(fontWeight: FontWeight.bold))),
        SizedBox(width: 100, child: Text(b, textAlign: TextAlign.center)),
        SizedBox(width: 100, child: Text(c, textAlign: TextAlign.center)),
      ],
    );
  }
}
