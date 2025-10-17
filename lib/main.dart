// ============================================================================
// Fachub — main.dart  (CLEAN & FIXED) — PART 1/4
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
                    MaterialPageRoute(builder: (_) => CalculatorScreen()));
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
// PART 2/4 — AuthGate + SignIn + Settings + Account + Calculator (Basic)
// ============================================================================

// بوابة المصادقة
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
// شاشة تسجيل الدخول
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
// شاشة الإعدادات
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

// ============================================================================
// شاشة الحساب الشخصي
// ============================================================================
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
// PART 3/4 — Community + Chat + HomeTabs (NavigationBar)
// ============================================================================

// واجهة المجتمع (محلية مبسّطة)
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final postCtrl = TextEditingController();
  final posts = <String>[];

  void _addPost() {
    final txt = postCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      posts.insert(0, txt);
      postCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'المجتمع',
      fab: FloatingActionButton(onPressed: _addPost, child: const Icon(Icons.send)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: postCtrl,
            decoration: const InputDecoration(
              hintText: 'اكتب منشورًا جديدًا...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('🗒️ لا توجد منشورات بعد'),
              ),
            )
          else
            ...posts.map((p) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(p),
                  ),
                )),
        ],
      ),
    );
  }
}

// ============================================================================
// واجهة الشات (محلية مبسّطة)
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
// PART 4/4 — Utilities & Helpers
// ============================================================================

// ويدجت خفيف لعرض حالة فارغة
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
// PART 4/4 — الدراسة (الكليات → التخصصات → الفروع → جدول المعدل)
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

// ============================================================================
// واجهة عرض الكليات
// ============================================================================
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

// ============================================================================
// واجهة عرض التخصصات لكل كلية
// ============================================================================
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

// ============================================================================
// واجهة عرض الفروع (التخصصات الفرعية)
// ============================================================================
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
                    builder: (_) => SemesterTableCalculatorScreen(
                      title: t,
                    ),
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
// جدول حساب المعدل داخل الفرع المحدد
// ============================================================================
class SemesterTableCalculatorScreen extends StatefulWidget {
  final String title;
  const SemesterTableCalculatorScreen({super.key, required this.title});

  @override
  State<SemesterTableCalculatorScreen> createState() =>
      _SemesterTableCalculatorScreenState();
}

class _SemesterTableCalculatorScreenState
    extends State<SemesterTableCalculatorScreen> {
  final subjects = <Map<String, dynamic>>[];
  double threshold = 10;
  double avg = 0;

  void _addRow() {
    setState(() {
      subjects.add({'name': '', 'coef': 1.0, 'grade': 0.0});
    });
  }

  void _removeRow(int i) {
    setState(() {
      subjects.removeAt(i);
    });
  }

  void _calc() {
    double sum = 0, coefSum = 0;
    for (final s in subjects) {
      final c = (s['coef'] ?? 1).toDouble();
      final g = (s['grade'] ?? 0).toDouble();
      sum += g * c;
      coefSum += c;
    }
    setState(() {
      avg = coefSum == 0 ? 0 : sum / coefSum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: widget.title,
      fab: FloatingActionButton(
        onPressed: _addRow,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 8),
          ...subjects.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'المادة'),
                        onChanged: (v) => s['name'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'المعامل'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => s['coef'] = double.tryParse(v) ?? 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'العلامة'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => s['grade'] = double.tryParse(v) ?? 0.0,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeRow(i),
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'عتبة النجاح'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => threshold = double.tryParse(v) ?? 10,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _calc,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب المعدل'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'معدلك: ${avg.toStringAsFixed(2)} — ${avg >= threshold ? "✅ ناجح" : "❌ راسب"}',
              style: TextStyle(
                color: avg >= threshold ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// نهاية الملف ✅
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
