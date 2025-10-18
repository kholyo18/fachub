// ============================================================================
// Fachub — main.dart  (FULL, FIXED & ENHANCED) — PART 1/3
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
// App root (Theme + Locale)  — ثابت ويعمل: تبديل اللغة/الثيم + حفظ التفضيلات
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

  static const _kTheme  = 'pref_themeMode';
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
// PART 1/3 (تابع) — AuthGate + SignIn + BaseScaffold + Settings + Account
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

// BaseScaffold — يضمن endDrawer في كل شاشة
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
// يتبع في PART 2/3: المجتمع (كاملاً مع صور/وسوم/إعجابات) + الشات + HomeTabs
// ============================================================================
// ============================================================================
// Fachub — main.dart  (FULL, FIXED & ENHANCED) — PART 2/3
// ============================================================================

// ----------------------------- نموذج منشور مجتمع -----------------------------
class CommunityPost {
  final String id;
  final String text;
  final String? imagePath; // على الموبايل فقط من ImagePicker
  final DateTime createdAt;
  int likes;
  final List<String> tags;

  CommunityPost({
    required this.id,
    required this.text,
    this.imagePath,
    required this.createdAt,
    this.likes = 0,
    this.tags = const [],
  });
}

// ------------------------------- مجتمع الطلبة -------------------------------
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final postCtrl = TextEditingController();
  final tagCtrl  = TextEditingController();
  final List<CommunityPost> _posts = [];
  String? _pickedImagePath; // محلي من ImagePicker
  String? _activeTag;       // للتصفية

  // إضافة منشور
  void _addPost() {
    final txt = postCtrl.text.trim();
    final rawTags = tagCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (txt.isEmpty && _pickedImagePath == null) return;

    setState(() {
      _posts.insert(
        0,
        CommunityPost(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: txt,
          imagePath: _pickedImagePath,
          createdAt: DateTime.now(),
          likes: 0,
          tags: rawTags,
        ),
      );
      postCtrl.clear();
      tagCtrl.clear();
      _pickedImagePath = null;
    });
  }

  // التقط صورة (موبايل فقط)
  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التقاط الصور غير مدعوم على الويب في هذا المثال')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (img != null) {
        setState(() => _pickedImagePath = img.path);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر اختيار الصورة')),
      );
    }
  }

  void _toggleLike(CommunityPost p) {
    setState(() => p.likes += 1);
  }

  List<CommunityPost> get _filtered {
    if (_activeTag == null) return _posts;
    return _posts.where((p) => p.tags.contains(_activeTag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'المجتمع',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // صندوق إنشاء منشور
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: postCtrl,
                    decoration: const InputDecoration(
                      hintText: 'شارك سؤالًا أو تجربة أو معلومة...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'وسوم مفصولة بفاصلة (مثال: L1, اقتصاد)',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'إرفاق صورة',
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined),
                      ),
                      FilledButton.icon(
                        onPressed: _addPost,
                        icon: const Icon(Icons.send),
                        label: const Text('نشر'),
                      ),
                    ],
                  ),
                  if (_pickedImagePath != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_pickedImagePath!), height: 140, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // شريط التصفية بالوسوم
          if (_posts.expand((p) => p.tags).isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: _activeTag == null,
                  onSelected: (_) => setState(() => _activeTag = null),
                ),
                ..._uniqueTags().map((t) => ChoiceChip(
                      label: Text('#$t'),
                      selected: _activeTag == t,
                      onSelected: (_) => setState(() => _activeTag = t),
                    )),
              ],
            ),
            const SizedBox(height: 12),
          ],

          if (_filtered.isEmpty)
            EmptyHint(
              icon: Icons.hourglass_empty_outlined,
              title: 'لا توجد منشورات بعد',
              subtitle: 'كن أول من يشارك منشورًا!',
            )
          else
            ..._filtered.map(_postCard),
        ],
      ),
    );
  }

  Set<String> _uniqueTags() {
    final tags = <String>{};
    for (final p in _posts) {
      tags.addAll(p.tags);
    }
    return tags;
  }

  Widget _postCard(CommunityPost p) {
    final time = DateFormat('yyyy/MM/dd • HH:mm').format(p.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'طالب مجهول',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            // نص
            if (p.text.isNotEmpty) Text(p.text),
            // صورة
            if (p.imagePath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(p.imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 8),
            // وسوم
            if (p.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                children: p.tags
                    .map((t) => InkWell(
                          onTap: () => setState(() => _activeTag = t),
                          child: Chip(
                            label: Text('#$t'),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ))
                    .toList(),
              ),
            // أزرار
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _toggleLike(p),
                  icon: const Icon(Icons.favorite_border),
                ),
                Text('${p.likes} إعجاب'),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ميزة التعليقات ستُضاف لاحقاً')),
                    );
                  },
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ رابط المنشور (وهمي)')),
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------- الشات -----------------------------------
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
                    subtitle: 'أرسل أول رسالة الآن',
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

// ------------------------------ الواجهة الرئيسية ------------------------------
class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

  final pages = const [
    // سيتم تعريف CalculatorScreen في PART 3/3
    Placeholder(), // مؤقتاً حتى يصل الجزء 3/3
    CommunityScreen(),
    ChatScreen(),
    SettingsScreen(),
    AccountScreen(),
  ];

  final labels = const ['الحاسبة', 'المجتمع', 'الشات', 'الإعدادات', 'الحساب'];
  final icons = const [
    Icons.calculate_outlined,
    Icons.public_outlined,
    Icons.chat_bubble_outline,
    Icons.settings_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppEndDrawer(),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}
// ============================================================================
// Fachub — main.dart  (FULL, FIXED & ENHANCED) — PART 3/3
// ============================================================================

// ----------------------- بيانات هوية الشهادة (محلياً) ------------------------
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

// --------------------------- شاشة الحاسبة المتقدّمة --------------------------
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final subjects = <Map<String, dynamic>>[];
  double threshold = 10;
  double avg = 0;

  // إضافة مادة
  void _add() {
    setState(() {
      subjects.add({'name': 'مادة جديدة', 'coef': 1.0, 'grade': 0.0});
    });
  }

  // حذف مادة
  void _removeAt(int i) {
    setState(() => subjects.removeAt(i));
  }

  // حساب المعدّل
  void _calc() {
    double total = 0, coefs = 0;
    for (final s in subjects) {
      final c = (s['coef'] ?? 1).toDouble();
      final g = (s['grade'] ?? 0).toDouble();
      total += g * c;
      coefs += c;
    }
    setState(() {
      avg = coefs == 0 ? 0 : total / coefs;
    });
  }

  // تصدير إلى PDF (شهادة)
  Future<void> _exportPDF() async {
    final info = await CertificateIdentity.load();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('شهادة حساب المعدل',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  )),
              pw.SizedBox(height: 8),
              if ((info['name'] ?? '').isNotEmpty) pw.Text('الطالب: ${info['name']}'),
              if ((info['uni'] ?? '').isNotEmpty) pw.Text('الجامعة: ${info['uni']}'),
              pw.SizedBox(height: 16),
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
              pw.SizedBox(height: 16),
              pw.Text(
                'المعدل العام: ${avg.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: avg >= threshold ? PdfColors.green : PdfColors.red,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('عتبة النجاح: ${threshold.toStringAsFixed(2)}'),
              pw.SizedBox(height: 12),
              pw.Text(
                avg >= threshold ? '✅ ناجح' : '❌ راسب',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: avg >= threshold ? PdfColors.green600 : PdfColors.red600,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'fachub_result.pdf',
    );
  }

  // بطاقة إدخال اسم/جامعة للشهادة
  Widget _identityCard() {
    final nameCtrl = TextEditingController();
    final uniCtrl = TextEditingController();

    return FutureBuilder<Map<String, String>>(
      future: CertificateIdentity.load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final data = snap.data ?? {};
        nameCtrl.text = data['name'] ?? '';
        uniCtrl.text  = data['uni'] ?? '';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('معلومات الشهادة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الطالب'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: uniCtrl,
                  decoration: const InputDecoration(labelText: 'الجامعة / الكلية'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await CertificateIdentity.save(
                          nameCtrl.text.trim(),
                          uniCtrl.text.trim(),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ بيانات الشهادة ✅')),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _exportPDF,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('توليد الشهادة (PDF)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'حاسبة المعدل + شهادة PDF',
      actions: [
        IconButton(
          tooltip: 'تصدير PDF',
          onPressed: _exportPDF,
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
              child: Column(
                children: [
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
                        child: Row(
                          children: [
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
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مادة'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _calc,
                        icon: const Icon(Icons.calculate),
                        label: const Text('احسب المعدل'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: threshold.toString(),
                          onChanged: (v) => threshold = double.tryParse(v) ?? 10,
                          decoration: const InputDecoration(labelText: 'عتبة النجاح'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
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
// الدراسة (كليات → تخصّصات → مسارات → جدول مطابق للصورة)
// ============================================================================

// نماذج تفصيلية لبرنامج دراسي
class ProgramComponent {
  final String label;   // TD / TP / EXAM / CC ...
  final double weight;  // نسبة مئوية (من 100)
  ProgramComponent(this.label, this.weight);
}

class ProgramModule {
  final String name;
  final int coef;       // المعامل
  final int credits;    // الأرصدة
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
  final String name; // مثال: علوم التسيير
  final List<ProgramSemester> semesters; // S1, S2
  ProgramTrack({required this.name, required this.semesters});
}

class ProgramMajor {
  final String name; // مثال: علوم الاقتصاد
  final List<ProgramTrack> tracks;
  ProgramMajor({required this.name, required this.tracks});
}

class ProgramFaculty {
  final String name; // مثال: كلية العلوم الاقتصادية
  final List<ProgramMajor> majors;
  ProgramFaculty({required this.name, required this.majors});
}

// مثال بيانات (يمكن توسعته لاحقًا)
final demoFaculties = <ProgramFaculty>[
  ProgramFaculty(
    name: 'كلية العلوم الاقتصادية',
    majors: [
      ProgramMajor(
        name: 'علوم الاقتصاد',
        tracks: [
          ProgramTrack(
            name: 'علوم التسيير',
            semesters: [
              ProgramSemester(
                label: 'S1',
                modules: [
                  ProgramModule(
                    name: 'Analyse 1',
                    coef: 4, credits: 6,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algèbre 1',
                    coef: 3, credits: 5,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algorithmique et structure de données 1',
                    coef: 2, credits: 4,
                    components: [
                      ProgramComponent('TP', 20),
                      ProgramComponent('TD', 20),
                      ProgramComponent('EXAM', 60),
                    ],
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
                    name: 'Analyse 2',
                    coef: 4, credits: 6,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algèbre 2',
                    coef: 2, credits: 4,
                    components: [ProgramComponent('TD', 30), ProgramComponent('EXAM', 70)],
                  ),
                  ProgramModule(
                    name: 'Algorithmique et structure de données 2',
                    coef: 2, credits: 4,
                    components: [
                      ProgramComponent('TP', 20),
                      ProgramComponent('TD', 20),
                      ProgramComponent('EXAM', 60),
                    ],
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

// ------------------------------ الكليات ------------------------------
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

// ---------------------------- تخصّصات الكلية ----------------------------
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

// -------------------------- المسارات داخل التخصّص --------------------------
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

// ------------------------- جدول حساب المعدّل (S1/S2) -------------------------
class SemesterTableCalculatorScreen extends StatefulWidget {
  final ProgramTrack track;
  const SemesterTableCalculatorScreen({super.key, required this.track});

  @override
  State<SemesterTableCalculatorScreen> createState() => _SemesterTableCalculatorScreenState();
}

class _SemesterTableCalculatorScreenState extends State<SemesterTableCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // نخزّن قيم الإدخال لكل (فصل/مادة/مكوّن) بالمفتاح: sem|moduleIndex|label
  final Map<String, TextEditingController> _inputs = {};

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
    // مطابق للصورة: أعمدة Modules | Coef | Cred | Note | Moyenne module | Cred Mod
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
              // صف الموديل الرئيسي
              DataRow(cells: [
                DataCell(Text(sem.modules[i].name)),
                DataCell(Text(sem.modules[i].coef.toString())),
                DataCell(Text(sem.modules[i].credits.toString())),
                const DataCell(Text('')),
                DataCell(Text(_moduleAverage(sem.modules[i], semKey, i).toStringAsFixed(2))),
                DataCell(Text(sem.modules[i].credits.toStringAsFixed(0))),
              ]),
              // صفوف المكوّنات (TD/TP/EXAM/...)
              for (final comp in sem.modules[i].components)
                DataRow(cells: [
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(comp.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
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
// ============================================================================
// ويدجت EmptyHint لعرض رسالة فارغة
// ============================================================================
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
