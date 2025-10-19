// ============================================================================
// Fachub — main.dart  (REDESIGN: Home+Notes+DragNav + Grid-like GPA Table)
// ============================================================================

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

// ألوان للواجهة الجديدة
const _homeBg     = Color(0xFFF6F7FB);
const _chipBg     = Color(0xFFEAEFFC);
const _chipText   = Color(0xFF23418E);
const _noteAccent = Color(0xFFFFC857);

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
// Auth Gate + Sign-in
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
        // الدخول إلى القشرة الجديدة
        return const HomeShell();
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

// ============================================================================
// القشرة الجديدة: Home • Notes • Community  (Drag/Press & Slide)
// ============================================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  late final PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: 0);
  }

  void _go(int i) {
    setState(() => _index = i);
    _page.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  // دعم السحب الأفقي على الشريط نفسه
  double _dragX = 0;
  int _dragStartIndex = 0;

  @override
  Widget build(BuildContext context) {
    final nav = _BottomDragBar(
      selected: _index,
      onTap: _go,
      onHorizontalDragStart: (dx) {
        _dragX = dx;
        _dragStartIndex = _index;
      },
      onHorizontalDragUpdate: (dx) {
        final delta = dx - _dragX;
        if (delta.abs() < 24) return;
        if (delta < 0 && _dragStartIndex < 2) _go(_dragStartIndex + 1);
        if (delta > 0 && _dragStartIndex > 0) _go(_dragStartIndex - 1);
        _dragX = dx;
        _dragStartIndex = _index;
      },
    );

    return Scaffold(
      backgroundColor: _homeBg,
      endDrawer: const AppEndDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // App bar بسيط
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                  const Spacer(),
                  const Text('Fachub', style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // الصفحات
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _HomeFacultiesPage(),
                  NotesScreen(),
                  CommunityScreen(),
                ],
              ),
            ),
            nav,
          ],
        ),
      ),
    );
  }
}

// شريط تنقّل سفلي يمكن الضغط والسحب عليه للتبديل
class _BottomDragBar extends StatelessWidget {
  final int selected;
  final void Function(int) onTap;
  final void Function(double dx)? onHorizontalDragStart;
  final void Function(double dx)? onHorizontalDragUpdate;

  const _BottomDragBar({
    required this.selected,
    required this.onTap,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'الرئيسية'),
      (Icons.note_alt_outlined, 'ملاحظات'),
      (Icons.public_outlined, 'المجتمع'),
    ];

    return GestureDetector(
      onHorizontalDragStart: (d) => onHorizontalDragStart?.call(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => onHorizontalDragUpdate?.call(d.localPosition.dx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final (icon, label) = items[i];
            final sel = i == selected;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? _chipBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 24, color: sel ? _chipText : null),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _chipText : null,
                      )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ============================================================================
// صفحة الرئيسية: قائمة الكليات (قابلة للتمرير) بشكل احترافي
// ============================================================================
class _HomeFacultiesPage extends StatelessWidget {
  const _HomeFacultiesPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const SizedBox(height: 6),
        const Text('اختر الكلية', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 10),
        ...demoFaculties.map((f) => _FacultyCard(f: f)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FacultyCard extends StatelessWidget {
  final Faculty f;
  const _FacultyCard({required this.f});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FacultyMajorsScreen(faculty: f),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _chipBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance, color: _chipText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: -6,
                      children: f.majors.take(3).map((m) =>
                        Chip(
                          label: Text(m.name, style: const TextStyle(fontSize: 12)),
                          backgroundColor: _chipBg, side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        )
                      ).toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// شاشة الملاحظات (احترافية، محلية — لاحقًا يمكن ربطها بـ Firestore)
// ============================================================================
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _notes = <_Note>[];
  final _ctrl = TextEditingController();

  void _addNoteDialog() {
    _ctrl.clear();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
          left: 12, right: 12, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ملاحظة جديدة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl, maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب ملاحظتك هنا...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    if (_ctrl.text.trim().isEmpty) return;
                    setState(() {
                      _notes.insert(0, _Note(_ctrl.text.trim(), DateTime.now()));
                    });
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _homeBg,
      endDrawer: const AppEndDrawer(),
      appBar: AppBar(
        title: const Text('ملاحظات'),
        actions: [
          IconButton(onPressed: _addNoteDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: _notes.isEmpty
          ? const EmptyHint(
              icon: Icons.note_alt_outlined,
              title: 'لا توجد ملاحظات بعد',
              subtitle: 'دوّن أفكارك وخلاصة الدروس هنا ✨',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _notes.length,
              itemBuilder: (_, i) {
                final n = _notes[i];
                return Dismissible(
                  key: ValueKey(n.created),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => setState(() => _notes.removeAt(i)),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _noteAccent, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.push_pin, color: Colors.black87),
                      ),
                      title: Text(n.text),
                      subtitle: Text(
                        '${n.created.year}/${n.created.month.toString().padLeft(2,'0')}/${n.created.day.toString().padLeft(2,'0')} '
                        '${n.created.hour.toString().padLeft(2,'0')}:${n.created.minute.toString().padLeft(2,'0')}'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Note {
  final String text;
  final DateTime created;
  _Note(this.text, this.created);
}
// ============================================================================
// Community (Firestore)
// ============================================================================
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _text = TextEditingController();
  final _tagCtrl = TextEditingController();
  bool _posting = false;

  Future<void> _post() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'text': _text.text.trim(),
        'tags': _parseTags(_tagCtrl.text),
        'likes': 0,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'ts': FieldValue.serverTimestamp(),
      });
      _text.clear();
      _tagCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر النشر: $e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  List<String> _parseTags(String s) {
    return s
        .split(RegExp(r'[,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('ts', descending: true);

    return Scaffold(
      backgroundColor: _homeBg,
      endDrawer: const AppEndDrawer(),
      appBar: AppBar(title: const Text('المجتمع')),
      body: Column(
        children: [
          // Composer
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _text,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'شارك سؤالاً أو تجربة أو معلومة...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'وسوم مفصولة بمسافة أو فاصلة...',
                            prefixIcon: Icon(Icons.sell_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _posting ? null : _post,
                        icon: const Icon(Icons.send_rounded),
                        label: _posting
                            ? const Text('جاري...')
                            : const Text('نشر'),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return EmptyHint(
                    icon: Icons.hourglass_empty_outlined,
                    title: 'لا توجد منشورات بعد',
                    subtitle: 'كن أول من يشارك منشورًا!',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final id = docs[i].id;
                    final text = d['text'] as String? ?? '';
                    final likes = (d['likes'] ?? 0) as int;
                    final tags = (d['tags'] as List?)?.cast<String>() ?? [];

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  d['uid'] != null ? 'طالب' : 'مجهول',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(id)
                                        .delete();
                                  },
                                  icon: const Icon(Icons.more_horiz),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(text),
                            const SizedBox(height: 8),
                            if (tags.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: tags
                                    .map((t) => Chip(
                                          label:
                                              Text('#$t', style: const TextStyle(fontSize: 12)),
                                          backgroundColor: _chipBg,
                                          side: BorderSide.none,
                                        ))
                                    .toList(),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(id)
                                        .update({'likes': likes + 1});
                                  },
                                  icon: const Icon(Icons.favorite_border),
                                ),
                                Text('$likes إعجاب'),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.share_outlined),
                                ),
                              ],
                            )
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
}

// ============================================================================
// Chat (Firestore)
// ============================================================================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msg = TextEditingController();

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('chat').add({
      'text': _msg.text.trim(),
      'uid': user?.uid,
      'ts': FieldValue.serverTimestamp(),
    });
    _msg.clear();
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('chat')
        .orderBy('ts', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('الشات')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return EmptyHint(
                    icon: Icons.forum_outlined,
                    title: 'ابدأ المحادثة!',
                    subtitle: 'أضف أول رسالة الآن.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(d['text'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _msg,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Faculties → Majors → Curriculum (grid-like GPA table)
// ============================================================================

class Faculty {
  final String name;
  final List<Major> majors;
  Faculty({required this.name, required this.majors});
}

class Major {
  final String name;
  final List<ModuleRow> sem1;
  final List<ModuleRow> sem2;
  Major({required this.name, required this.sem1, required this.sem2});
}

// صف في الجدول
class ModuleRow {
  final String module;
  int coef;
  int cred;
  // درجات TD/EXAM أو أي ملاحظات
  double td;
  double exam;

  ModuleRow({
    required this.module,
    required this.coef,
    required this.cred,
    this.td = 0,
    this.exam = 0,
  });

  double get moyenne => ((td * 0.3) + (exam * 0.7));
  int get credMod => moyenne >= 10 ? cred : 0;
}

final demoFaculties = <Faculty>[
  Faculty(
    name: 'كلية العلوم الإقتصادية',
    majors: [
      Major(
        name: 'علوم التسيير',
        sem1: [
          ModuleRow(module: 'Analyse 1', coef: 4, cred: 6),
          ModuleRow(module: 'Algèbre 1', coef: 3, cred: 5),
          ModuleRow(module: 'Algorithmique 1', coef: 4, cred: 6),
          ModuleRow(module: 'Structure machine 1', coef: 3, cred: 5),
          ModuleRow(module: 'Terminologie', coef: 2, cred: 2),
          ModuleRow(module: 'Physique 1', coef: 2, cred: 4),
          ModuleRow(module: 'Langue', coef: 1, cred: 2),
          ModuleRow(module: 'Découverte', coef: 2, cred: 4),
        ],
        sem2: [
          ModuleRow(module: 'Analyse 2', coef: 4, cred: 6),
          ModuleRow(module: 'Algèbre 2', coef: 2, cred: 4),
          ModuleRow(module: 'Algorithmique 2', coef: 4, cred: 6),
          ModuleRow(module: 'Structure machine 2', coef: 2, cred: 4),
          ModuleRow(module: 'Proba/Stats', coef: 3, cred: 5),
          ModuleRow(module: 'TIC', coef: 1, cred: 2),
          ModuleRow(module: 'Programmation', coef: 2, cred: 4),
          ModuleRow(module: 'Physique 2', coef: 3, cred: 5),
          ModuleRow(module: 'Découverte', coef: 2, cred: 4),
        ],
      ),
      Major(
        name: 'علوم تجارية',
        sem1: [
          ModuleRow(module: 'Economie 1', coef: 3, cred: 5),
          ModuleRow(module: 'Gestion 1', coef: 3, cred: 5),
        ],
        sem2: [
          ModuleRow(module: 'Economie 2', coef: 3, cred: 5),
          ModuleRow(module: 'Gestion 2', coef: 3, cred: 5),
        ],
      ),
    ],
  ),
  Faculty(
    name: 'كلية الحقوق',
    majors: [
      Major(
        name: 'قانون عام',
        sem1: [ModuleRow(module: 'مدخل قانون', coef: 2, cred: 3)],
        sem2: [ModuleRow(module: 'دستوري', coef: 2, cred: 3)],
      ),
    ],
  ),
];

class FacultiesScreen extends StatelessWidget {
  final List<Faculty> faculties;
  const FacultiesScreen({super.key, required this.faculties});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكليات')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: faculties.length,
        itemBuilder: (_, i) {
          final f = faculties[i];
          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FacultyMajorsScreen(faculty: f),
                ),
              ),
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
    return Scaffold(
      appBar: AppBar(title: Text(faculty.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: faculty.majors.length,
        itemBuilder: (_, i) {
          final m = faculty.majors[i];
          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CurriculumScreen(major: m, title: m.name),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// شاشة المنهاج/الجدول: جدول شبكي بحدود وخلايا + ملخص Sem1/Sem2/Année
// ============================================================================
class CurriculumScreen extends StatefulWidget {
  final Major major;
  final String title;
  const CurriculumScreen({super.key, required this.major, required this.title});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  double _avg(List<ModuleRow> rows) =>
      rows.isEmpty ? 0 : rows.map((e) => e.moyenne).reduce((a, b) => a + b) / rows.length;

  int _creditsValidated(List<ModuleRow> rows) =>
      rows.fold(0, (p, e) => p + e.credMod);

  @override
  Widget build(BuildContext context) {
    final sem1 = widget.major.sem1;
    final sem2 = widget.major.sem2;

    final s1Avg = _avg(sem1);
    final s2Avg = _avg(sem2);
    final yAvg = (s1Avg + s2Avg) / 2.0;

    final s1Cred = _creditsValidated(sem1);
    final s2Cred = _creditsValidated(sem2);
    final yCred = s1Cred + s2Cred;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'SEMESTER 1'),
            Tab(text: 'SEMESTER 2'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _SemesterGrid(
                  rows: sem1,
                  onChange: () => setState(() {}),
                ),
                _SemesterGrid(
                  rows: sem2,
                  onChange: () => setState(() {}),
                ),
              ],
            ),
          ),

          // ملخص سفلي مثل الصورة
          Padding(
            padding: const EdgeInsets.all(12),
            child: _SummaryTable(
              sem1Avg: s1Avg,
              sem2Avg: s2Avg,
              sem1Cred: s1Cred,
              sem2Cred: s2Cred,
              yearAvg: yAvg,
              yearCred: yCred,
            ),
          ),
        ],
      ),
    );
  }
}

// جدول فصل واحد (Grid مع حدود)
class _SemesterGrid extends StatelessWidget {
  final List<ModuleRow> rows;
  final VoidCallback onChange;
  const _SemesterGrid({required this.rows, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                MaterialStatePropertyAll(Colors.grey.shade300),
            columns: const [
              DataColumn(label: Text('Modules')),
              DataColumn(label: Text('Coef')),
              DataColumn(label: Text('Cred')),
              DataColumn(label: Text('Note')),
              DataColumn(label: Text('Moyenne module')),
              DataColumn(label: Text('Cred Mod')),
            ],
            rows: rows.map((r) {
              return DataRow(cells: [
                DataCell(Text(r.module)),
                DataCell(_IntEditable(
                  value: r.coef,
                  onChanged: (v) { r.coef = v; onChange(); },
                )),
                DataCell(_IntEditable(
                  value: r.cred,
                  onChanged: (v) { r.cred = v; onChange(); },
                )),
                DataCell(_NoteCell(
                  td: r.td, exam: r.exam,
                  onChanged: (td, ex) { r.td = td; r.exam = ex; onChange(); },
                )),
                DataCell(Text(r.moyenne.toStringAsFixed(2))),
                DataCell(Text(r.credMod.toString())),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// خلية إدخال رقم صحيح
class _IntEditable extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _IntEditable({required this.value, required this.onChanged});
  @override
  State<_IntEditable> createState() => _IntEditableState();
}
class _IntEditableState extends State<_IntEditable> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value.toString());
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
        onChanged: (v) {
          final n = int.tryParse(v) ?? widget.value;
          widget.onChanged(n);
        },
      ),
    );
  }
}

// خلية إدخال (TD/EXAM 30%/70%) مع منزلقات
class _NoteCell extends StatefulWidget {
  final double td;
  final double exam;
  final void Function(double td, double exam) onChanged;
  const _NoteCell({required this.td, required this.exam, required this.onChanged});
  @override
  State<_NoteCell> createState() => _NoteCellState();
}

class _NoteCellState extends State<_NoteCell> {
  late double _td = widget.td;
  late double _ex = widget.exam;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Text('30% TD'),
              Expanded(
                child: Slider(
                  value: _td, min: 0, max: 20, divisions: 40,
                  label: _td.toStringAsFixed(1),
                  onChanged: (v) => setState(() { _td = v; widget.onChanged(_td, _ex); }),
                ),
              ),
              SizedBox(width: 32, child: Text(_td.toStringAsFixed(1), textAlign: TextAlign.end)),
            ],
          ),
          Row(
            children: [
              const Text('70% EXAM'),
              Expanded(
                child: Slider(
                  value: _ex, min: 0, max: 20, divisions: 40,
                  label: _ex.toStringAsFixed(1),
                  onChanged: (v) => setState(() { _ex = v; widget.onChanged(_td, _ex); }),
                ),
              ),
              SizedBox(width: 32, child: Text(_ex.toStringAsFixed(1), textAlign: TextAlign.end)),
            ],
          ),
        ],
      ),
    );
  }
}

// ملخص سفلي مطابق لفكرة الصورة (ثلاثة صفوف)
class _SummaryTable extends StatelessWidget {
  final double sem1Avg, sem2Avg, yearAvg;
  final int sem1Cred, sem2Cred, yearCred;
  const _SummaryTable({
    required this.sem1Avg,
    required this.sem2Avg,
    required this.yearAvg,
    required this.sem1Cred,
    required this.sem2Cred,
    required this.yearCred,
  });

  @override
  Widget build(BuildContext context) {
    final border = TableBorder.all(color: Colors.black26, width: 1);
    Text _cell(String s, {bool head = false}) => Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: head ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Table(
        border: border,
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade300),
            children: [
              Padding(padding: const EdgeInsets.all(8), child: _cell('Semestre/année', head: true)),
              Padding(padding: const EdgeInsets.all(8), child: _cell('Moyenne', head: true)),
              Padding(padding: const EdgeInsets.all(8), child: _cell('Crédits', head: true)),
            ],
          ),
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(8), child: _cell('semestre1')),
            Padding(padding: const EdgeInsets.all(8), child: _cell(sem1Avg.toStringAsFixed(2))),
            Padding(padding: const EdgeInsets.all(8), child: _cell(sem1Cred.toString())),
          ]),
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(8), child: _cell('semestre2')),
            Padding(padding: const EdgeInsets.all(8), child: _cell(sem2Avg.toStringAsFixed(2))),
            Padding(padding: const EdgeInsets.all(8), child: _cell(sem2Cred.toString())),
          ]),
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(8), child: _cell('Année')),
            Padding(padding: const EdgeInsets.all(8), child: _cell(yearAvg.toStringAsFixed(2))),
            Padding(padding: const EdgeInsets.all(8), child: _cell(yearCred.toString())),
          ]),
        ],
      ),
    );
  }
}

// ============================================================================
// Calculator (يدخلك إلى نفس الجدول عبر اختيار تخصّص تجريبي بسرعة)
// ============================================================================
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = demoFaculties.first;
    final m = f.majors.first;
    return CurriculumScreen(major: m, title: '${f.name} • ${m.name}');
  }
}
// ============================================================================
// Helpers & styling (safe to append; no duplicate classes here)
// ============================================================================

// خلفية هادئة للـ Home/Community


// لون خلفية للوسوم (Chip) – يمكن تعديله بحرية


// (اختياري) فواصل صغنونة متسقة
Widget vgap([double h = 8]) => SizedBox(height: h);
Widget hgap([double w = 8]) => SizedBox(width: w);

// (اختياري) نمط نص صغير رمادي
TextStyle get _muted =>
    const TextStyle(fontSize: 12, color: Colors.black54);

// ============================================================================
// انتهى الملف ✅
// ============================================================================
// ويدجت خفيفة لعرض حالة فارغة (مُعاد تعريفها هنا مرة واحدة فقط)
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
