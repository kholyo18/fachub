// ============================================================================
// Fachub — main.dart  (FULL MERGED FILE) — PART 1/3
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

            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('حاسبة المعدل'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CalculatorScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('المجتمع'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CommunityScreen()));
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
// Auth Gate + Sign in
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
                const Icon(Icons.school_rounded,
                    color: kFachubBlue, size: 64),
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
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
// Base Scaffold
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
// Empty hint + helpers
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
// Community + Chat + HomeTabs
// ============================================================================

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _postCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  String? _queryTag;

  // نموذج مبسّط للمنشور (محلي)
  final List<Map<String, dynamic>> _posts = [];

  void _createPost() {
    final txt = _postCtrl.text.trim();
    final tagText = _tagCtrl.text.trim();
    if (txt.isEmpty) return;

    final tags = tagText.isEmpty
        ? <String>[]
        : tagText.split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty).toList();

    setState(() {
      _posts.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'author': 'طالب مجهول',
        'text': txt,
        'tags': tags,
        'likes': 0,
        'createdAt': DateTime.now(),
        'comments': <Map<String, String>>[],
      });
      _postCtrl.clear();
      _tagCtrl.clear();
    });
  }

  void _toggleLike(Map<String, dynamic> p) {
    setState(() => p['likes'] = (p['likes'] as int) + 1);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_queryTag == null || _queryTag!.isEmpty) return _posts;
    return _posts.where((p) => (p['tags'] as List).contains(_queryTag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'المجتمع',
      fab: FloatingActionButton(
        onPressed: _createPost,
        child: const Icon(Icons.send),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // منشئ منشور
          Card(
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'وسوم مفصولة بمسافة/فاصلة...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _createPost,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('نشر'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // شرائح الوسوم (تجميع تلقائي من كل المنشورات)
          if (_uniqueTags().isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: -6,
              children: _uniqueTags()
                  .map(
                    (t) => FilterChip(
                      label: Text('#$t'),
                      selected: _queryTag == t,
                      onSelected: (_) => setState(() {
                        _queryTag = _queryTag == t ? null : t;
                      }),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 8),

          if (_filtered.isEmpty)
            const EmptyHint(
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

  Widget _postCard(Map<String, dynamic> d) {
    final dt = d['createdAt'] as DateTime;
    final tags = (d['tags'] as List).cast<String>();
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['author'],
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • '
                        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}',
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'share', child: Text('مشاركة')),
                    PopupMenuItem(value: 'report', child: Text('تبليغ')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // النص
            Text(d['text']),

            // الوسوم
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: tags
                    .map((t) => ActionChip(
                          label: Text('#$t'),
                          onPressed: () => setState(() => _queryTag = t),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: () => _toggleLike(d),
                  icon: const Icon(Icons.favorite_border),
                ),
                Text('${d['likes']} إعجاب'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    _openComments(d);
                  },
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('تعليقات (${(d['comments'] as List).length})'),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openComments(Map<String, dynamic> post) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('التعليقات', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ListView(
                  children: (post['comments'] as List<Map<String, String>>)
                      .map((c) => ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(c['text']!),
                            subtitle: Text(c['by'] ?? 'مستخدم'),
                          ))
                      .toList(),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: 'أضف تعليقًا...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final t = ctrl.text.trim();
                      if (t.isEmpty) return;
                      setState(() {
                        (post['comments'] as List).add({'text': t, 'by': 'طالب'});
                      });
                      ctrl.clear();
                      Navigator.pop(ctx);
                      _openComments(post);
                    },
                    child: const Text('إرسال'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<String> _uniqueTags() {
    final tags = <String>{};
    for (final p in _posts) {
      tags.addAll((p['tags'] as List).cast<String>());
    }
    return tags;
  }
}

// ----------------------------------------------------------------------------

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final List<String> msgs = [];

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      msgs.insert(0, t);
      _ctrl.clear();
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
                ? const EmptyHint(
                    icon: Icons.forum_outlined,
                    title: 'ابدأ المحادثة ✨',
                    subtitle: 'أكتب أول رسالة الآن.',
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
                      controller: _ctrl,
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

// ----------------------------------------------------------------------------

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
          NavigationDestination(
              icon: Icon(Icons.public_outlined), label: 'المجتمع'),
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
// Faculties → Majors → Tracks → Semester Table (L1MI-like)
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

// ----------------------------------------------------------------------------
// نموذج المقرر/الوحدة والمواد
class ModuleRow {
  ModuleRow({
    required this.moduleName,
    required this.coef,
    required this.credits,
  });

  final String moduleName;
  int coef;
  int credits;

  // درجات
  double td = 0;
  double tp = 0;
  double exam = 0;

  // أوزان افتراضية (TD=30%, EXAM=70%)، TP للاختياري
  int tdPercent = 30;
  int tpPercent = 0;
  int examPercent = 70;

  double get moyenne {
    final total = tdPercent + tpPercent + examPercent;
    if (total == 0) return 0;
    final w = (td * tdPercent + tp * tpPercent + exam * examPercent) / total;
    return double.parse(w.toStringAsFixed(2));
  }
}

class SemesterData {
  SemesterData({required this.title, required this.rows});

  final String title;
  final List<ModuleRow> rows;

  double get moyenne {
    if (rows.isEmpty) return 0;
    double sum = 0;
    int coefSum = 0;
    for (final r in rows) {
      sum += r.moyenne * r.coef;
      coefSum += r.coef;
    }
    return coefSum == 0 ? 0 : double.parse((sum / coefSum).toStringAsFixed(2));
  }

  int get creditsValidated {
    int c = 0;
    for (final r in rows) {
      if (r.moyenne >= 10) c += r.credits;
    }
    return c;
  }
}
// ============================================================================
// Semester Table Calculator (شكل L1MI) + CalculatorScreen placeholder
// ============================================================================

class SemesterTableCalculatorScreen extends StatefulWidget {
  final String title;
  const SemesterTableCalculatorScreen({super.key, required this.title});

  @override
  State<SemesterTableCalculatorScreen> createState() =>
      _SemesterTableCalculatorScreenState();
}

class _SemesterTableCalculatorScreenState
    extends State<SemesterTableCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // نحضّر بيانات S1 و S2 كنموذج قريب من الصورة
  late SemesterData s1;
  late SemesterData s2;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    s1 = SemesterData(title: 'SEMESTER 1', rows: [
      ModuleRow(moduleName: 'Analyse 1', coef: 4, credits: 6),
      ModuleRow(moduleName: 'Algèbre 1', coef: 3, credits: 5),
      ModuleRow(moduleName: 'Algorithmique et\nstructures de données 1', coef: 3, credits: 5)
        ..tpPercent = 20
        ..tdPercent = 30
        ..examPercent = 50,
      ModuleRow(moduleName: 'Structure machine 1', coef: 3, credits: 5),
      ModuleRow(moduleName: 'Terminologie scientifique\net expression écrite', coef: 2, credits: 2)
        ..tdPercent = 30
        ..examPercent = 70,
      ModuleRow(moduleName: 'Langue Étrangère 1', coef: 1, credits: 1)
        ..tdPercent = 40
        ..examPercent = 60,
      ModuleRow(moduleName: 'Physique 1', coef: 2, credits: 4),
      ModuleRow(moduleName: 'Unité Découverte 1', coef: 2, credits: 2)
        ..tdPercent = 0
        ..examPercent = 100,
    ]);

    s2 = SemesterData(title: 'SEMESTER 2', rows: [
      ModuleRow(moduleName: 'Analyse 2', coef: 4, credits: 6),
      ModuleRow(moduleName: 'Algèbre 2', coef: 2, credits: 4),
      ModuleRow(moduleName: 'Algorithmique et\nstructures de données 2', coef: 2, credits: 6)
        ..tpPercent = 20
        ..tdPercent = 30
        ..examPercent = 50,
      ModuleRow(moduleName: 'Structure machine 2', coef: 2, credits: 2),
      ModuleRow(moduleName: 'Introduction aux probabilités\net statistique descriptive', coef: 3, credits: 3)
        ..tdPercent = 30
        ..examPercent = 70,
      ModuleRow(moduleName: 'Technologie de l’information\net de la Communication', coef: 1, credits: 2)
        ..tdPercent = 0
        ..examPercent = 100,
      ModuleRow(moduleName: 'Outils de programmation\npour les mathématiques', coef: 1, credits: 2)
        ..tpPercent = 40
        ..tdPercent = 0
        ..examPercent = 60,
      ModuleRow(moduleName: 'Unité Méthodologique', coef: 2, credits: 2)
        ..tdPercent = 100
        ..examPercent = 0,
      ModuleRow(moduleName: 'Physique 2', coef: 3, credits: 3),
      ModuleRow(moduleName: 'Unité Découverte 2', coef: 2, credits: 2)
        ..tdPercent = 0
        ..examPercent = 100,
    ]);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearAvg =
        double.parse(((s1.moyenne + s2.moyenne) / 2).toStringAsFixed(2));
    final yearCred = s1.creditsValidated + s2.creditsValidated;

    return Scaffold(
      appBar: AppBar(
        title: Text('L1MI • ${widget.title}'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
        actions: const [SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 18),
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
          _semesterView(s1, other: s2, yearAvg: yearAvg, yearCred: yearCred),
          _semesterView(s2, other: s1, yearAvg: yearAvg, yearCred: yearCred),
        ],
      ),
    );
  }

  // واجهة سيمستر واحدة
  Widget _semesterView(SemesterData sem,
      {required SemesterData other, required double yearAvg, required int yearCred}) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _semesterHeader(sem.title),
        const SizedBox(height: 8),
        _moduleTable(sem),
        const SizedBox(height: 12),
        _summaryCard(sem, other, yearAvg, yearCred),
        const SizedBox(height: 24),
      ],
    );
  }

  // عنوان السيمستر
  Widget _semesterHeader(String title) {
    return Row(
      children: [
        const Icon(Icons.table_chart_outlined),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // الجدول (قابل للتمرير أفقيًا)
  Widget _moduleTable(SemesterData sem) {
    // عرض أعمدة ثابت لتجنّب الـ overflow
    const wMod = 220.0;
    const wNum = 70.0;
    const wNote = 320.0; // يحتوي حقول الإدخال TD/TP/EXAM مع نسبها

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 600),
            child: Column(
              children: [
                // رأس الجدول
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    border: Border(
                      bottom:
                          BorderSide(color: Colors.grey.withOpacity(.3), width: .5),
                    ),
                  ),
                  child: Row(
                    children: const [
                      _HeaderCell('Modules', width: wMod),
                      _HeaderCell('Coef', width: wNum, center: true),
                      _HeaderCell('Cred', width: wNum, center: true),
                      _HeaderCell('Note', width: wNote, center: true),
                      _HeaderCell('Moyenne\nmodule', width: wNum + 10, center: true),
                    ],
                  ),
                ),

                // صفوف المواد
                ...sem.rows.map((r) => _moduleRow(sem, r)).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moduleRow(SemesterData sem, ModuleRow r) {
    const wMod = 220.0;
    const wNum = 70.0;
    const wNote = 320.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(.2), width: .5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(
            width: wMod,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(r.moduleName),
            ),
          ),
          _Cell(
            width: wNum,
            center: true,
            child: Text(r.coef.toString()),
          ),
          _Cell(
            width: wNum,
            center: true,
            child: Text(r.credits.toString()),
          ),
          _Cell(
            width: wNote,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _noteLine(
                    title: 'TD',
                    percent: r.tdPercent,
                    value: r.td,
                    onChanged: (v) => setState(() => r.td = v),
                    onPercentChanged: (p) =>
                        setState(() => r.tdPercent = p.clamp(0, 100)),
                  ),
                  if (r.tpPercent > 0 || r.tp > 0) ...[
                    const SizedBox(height: 6),
                    _noteLine(
                      title: 'TP',
                      percent: r.tpPercent,
                      value: r.tp,
                      onChanged: (v) => setState(() => r.tp = v),
                      onPercentChanged: (p) =>
                          setState(() => r.tpPercent = p.clamp(0, 100)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _noteLine(
                    title: 'EXAM',
                    percent: r.examPercent,
                    value: r.exam,
                    onChanged: (v) => setState(() => r.exam = v),
                    onPercentChanged: (p) =>
                        setState(() => r.examPercent = p.clamp(0, 100)),
                  ),
                ],
              ),
            ),
          ),
          _Cell(
            width: wNum + 10,
            center: true,
            child: Text(r.moyenne.toStringAsFixed(2)),
          ),
        ],
      ),
    );
  }

  // صف إدخال درجة مع النسبة
  Widget _noteLine({
    required String title,
    required int percent,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<int> onPercentChanged,
  }) {
    final pCtrl = TextEditingController(text: percent.toString());
    final nCtrl = TextEditingController(text: value == 0 ? '' : value.toString());

    return Row(
      children: [
        SizedBox(width: 46, child: Text(title, textAlign: TextAlign.start)),
        SizedBox(
          width: 56,
          child: TextField(
            controller: pCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final p = int.tryParse(v) ?? percent;
              onPercentChanged(p);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: nCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '0 - 20',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final x = double.tryParse(v.replaceAll(',', '.')) ?? value;
              onChanged(x.clamp(0, 20));
            },
          ),
        ),
      ],
    );
  }

  // ملخص السيمستر والسنة (أسفل الجدول)
  Widget _summaryCard(
      SemesterData sem, SemesterData other, double yearAvg, int yearCred) {
    final sAvg = sem.moyenne.toStringAsFixed(2);
    final oAvg = other.moyenne.toStringAsFixed(2);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: const [
                Expanded(
                    child: Text('Semestre/année',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 100, child: Text('Moyenne', textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text('Crédits', textAlign: TextAlign.center)),
              ],
            ),
            const Divider(),
            _summaryRow('semestre1', _tab.index == 0 ? sAvg : oAvg,
                (_tab.index == 0 ? sem.creditsValidated : other.creditsValidated).toString()),
            _summaryRow('semestre2', _tab.index == 1 ? sAvg : oAvg,
                (_tab.index == 1 ? sem.creditsValidated : other.creditsValidated).toString()),
            const Divider(),
            _summaryRow('Année', yearAvg.toStringAsFixed(2), yearCred.toString()),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String a, String b, String c) {
    return Row(
      children: [
        Expanded(child: Text(a, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 100, child: Text('', textAlign: TextAlign.center)),
        SizedBox(width: 100, child: Text(b, textAlign: TextAlign.center)),
        SizedBox(width: 100, child: Text(c, textAlign: TextAlign.center)),
      ],
    );
  }
}

// ====== عناصر خلية/رأس بسيطة للجدول =========================================

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final bool center;
  const _HeaderCell(this.text, {required this.width, this.center = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  final bool center;
  const _Cell({required this.width, required this.child, this.center = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Align(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// CalculatorScreen (placeholder)
// ============================================================================

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة المعدل')),
      endDrawer: const AppEndDrawer(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'هذه نسخة مختصرة من الحاسبة.\nيمكنك الدخول إلى "الدراسة → الكليات → التخصصات → جدول" لرؤية جدول L1MI المفصل.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FacultiesScreen(faculties: demoFaculties),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('افتح دليل الدراسة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// النهاية ✅
// ============================================================================
