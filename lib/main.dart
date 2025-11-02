// ============================================================================
// Fachub — main.dart (UPDATED: BottomBar + Notes + Reddit-like Community + Table)
// PART 1/3
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const kNoteYellow  = Color(0xFFFFF3C4);

// ============================================================================
// Bootstrap
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FachubApp());
}

// ============================================================================
// App root (Theme + Locale)  — مع حفظ التفضيلات
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
// Global End Drawer — يعمل فعليًا (مظهر/لغة/إعادة كلمة السر/روابط)
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

            // تنقّل سريع
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('الصفحة الرئيسية'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeShell()),
                  (_) => false,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('حاسبة المعدل'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalculatorHubScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('الدراسة (كليّات → تخصّصات → جدول)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FacultiesScreen(faculties: demoFaculties),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('مجتمع Fachub'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CommunityScreen()));
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
                  Text('منصة لحساب المعدل الجامعي ومجتمع للطلبة، مع تدوين ملاحظات.'),
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
                        'Fachub لا يجمع بيانات شخصية خارج Firebase. جميع البيانات آمنة.'),
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
// Auth Gate + SignIn
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
// HomeShell — الشريط السفلي الجديد + سحب/انزلاق بين الصفحات
// ============================================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  // 0 = Home(الكليات), 1 = Community, 2 = Notes
  int _current = 0;
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _current = i);
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppEndDrawer(),
      body: PageView(
        controller: _page,
        onPageChanged: (i) => setState(() => _current = i),
        children: const [
          // الصفحة الرئيسية: كروت كليات + زر يدخل للدراسة الكاملة
          HomeLandingScreen(),
          // المجتمع بأسلوب Reddit
          CommunityScreen(),
          // الملاحظات الاحترافية
          NotesScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _current,
        onTap: _go,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _NoteFab(onTap: () => _go(2)),
    );
  }
}

// زر الملاحظات في المنتصف
class _NoteFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NoteFab({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      elevation: 2,
      onPressed: onTap,
      child: const Icon(Icons.note_alt_outlined, size: 30),
    );
  }
}

// شريط سفلي مع شكل احترافي
class _BottomBar extends StatelessWidget {
  final int index;
  final void Function(int) onTap;
  const _BottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 68,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BarItem(
            icon: Icons.home_outlined,
            label: 'الرئيسية',
            selected: index == 0,
            onTap: () => onTap(0),
          ),
          const SizedBox(width: 40), // فراغ لفتحة زر الملاحظات
          _BarItem(
            icon: Icons.public_outlined,
            label: 'المجتمع',
            selected: index == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).hintColor;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: c, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ============================================================================
// Home Landing — كروت كليات احترافية + دخول إلى Navigator الدراسة
// ============================================================================
class HomeLandingScreen extends StatelessWidget {
  const HomeLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fachub • الرئيسية'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_open),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
      ),
      endDrawer: const AppEndDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          const _WelcomeHeader(),
          const SizedBox(height: 8),
          _FacultyGrid(faculties: demoFaculties.take(6).toList()),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FacultiesScreen(faculties: demoFaculties)),
              );
            },
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('استعراض كل الكليات'),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.school, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('مرحباً بك 👋', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('تصفح الكليات، احسب معدلك، شارك أفكارك، ودوّن ملاحظاتك بسهولة.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacultyGrid extends StatelessWidget {
  final List<ProgramFaculty> faculties;
  const _FacultyGrid({required this.faculties});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: faculties.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.2),
      itemBuilder: (_, i) {
        final f = faculties[i];
        return Card(
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                _,
                MaterialPageRoute(builder: (_) => FacultyMajorsScreen(faculty: f)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.apartment_outlined, size: 30),
                  const Spacer(),
                  Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Notes — واجهة ملاحظات احترافية (إنشاء/بحث/تثبيت/أرشفة)
// ============================================================================
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  final _notes = <_NoteModel>[
    _NoteModel('خطة مذاكرة S1', 'رياضيات، فيزياء، برمجة...', pinned: true),
  ];
  final _archived = <_NoteModel>[];

  void _create() async {
    final res = await showModalBottomSheet<_NoteModel>(
      isScrollControlled: true,
      context: context,
      builder: (_) => const _NoteEditor(),
    );
    if (res != null) setState(() => _notes.insert(0, res));
  }

  void _edit(_NoteModel m) async {
    final res = await showModalBottomSheet<_NoteModel>(
      isScrollControlled: true,
      context: context,
      builder: (_) => _NoteEditor(initial: m),
    );
    if (res != null) {
      setState(() {
        final i = _notes.indexOf(m);
        if (i != -1) _notes[i] = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final pinned = _notes.where((e) => e.pinned && (q.isEmpty || e.match(q))).toList();
    final others = _notes.where((e) => !e.pinned && (q.isEmpty || e.match(q))).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملاحظاتي'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add_task_outlined)),
        ],
      ),
      endDrawer: const AppEndDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث داخل الملاحظات…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          if (pinned.isNotEmpty) ...[
            const Text('مثبّتة', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...pinned.map((n) => _NoteTile(
              note: n,
              onTap: () => _edit(n),
              onPin: () => setState(() => n.pinned = !n.pinned),
              onArchive: () => setState(() { _notes.remove(n); _archived.add(n); }),
            )),
            const SizedBox(height: 10),
          ],
          if (others.isNotEmpty) ...[
            const Text('باقي الملاحظات', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...others.map((n) => _NoteTile(
              note: n,
              onTap: () => _edit(n),
              onPin: () => setState(() => n.pinned = !n.pinned),
              onArchive: () => setState(() { _notes.remove(n); _archived.add(n); }),
            )),
          ] else if (pinned.isEmpty)
            const _EmptyHint(icon: Icons.note_alt_outlined, title: 'لا توجد ملاحظات بعد'),
          const SizedBox(height: 12),
          if (_archived.isNotEmpty) ...[
            const Divider(),
            const Text('الأرشيف', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ..._archived.map((n) => _NoteTile(
              note: n,
              archived: true,
              onTap: () {},
              onPin: null,
              onArchive: () => setState(() { _archived.remove(n); _notes.add(n); }),
            )),
          ],
        ],
      ),
    );
  }
}

class _NoteModel {
  String title;
  String body;
  bool pinned;
  _NoteModel(this.title, this.body, {this.pinned = false});
  bool match(String q) => title.toLowerCase().contains(q) || body.toLowerCase().contains(q);
}

class _NoteTile extends StatelessWidget {
  final _NoteModel note;
  final bool archived;
  final VoidCallback? onTap;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  const _NoteTile({required this.note, this.archived = false, this.onTap, this.onPin, this.onArchive});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kNoteYellow.withOpacity(Theme.of(context).brightness == Brightness.dark ? .12 : .35),
      child: ListTile(
        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: onTap,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (onPin != null)
            IconButton(onPressed: onPin, icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined)),
          if (onArchive != null)
            IconButton(onPressed: onArchive, icon: Icon(archived ? Icons.unarchive : Icons.archive_outlined)),
        ]),
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  final _NoteModel? initial;
  const _NoteEditor({this.initial});
  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _t;
  late final TextEditingController _b;
  bool _pin = false;

  @override
  void initState() {
    super.initState();
    _t = TextEditingController(text: widget.initial?.title ?? '');
    _b = TextEditingController(text: widget.initial?.body ?? '');
    _pin = widget.initial?.pinned ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ملاحظة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _t,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _b,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'المحتوى'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _pin,
                onChanged: (v) => setState(() => _pin = v ?? false),
                title: const Text('تثبيت الملاحظة'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  if (_t.text.trim().isEmpty && _b.text.trim().isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context, _NoteModel(_t.text.trim(), _b.text.trim(), pinned: _pin));
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// عنصر EmptyHint (لازم لرسائل الفراغ)
// ============================================================================

// ============================================================================
// PART 2/3 — Community (Reddit-like) + Studies Navigator + Table Calculator
// ============================================================================

// ========================= Community (Reddit-like) ===========================
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final List<_Post> _posts = [
    _Post(
      author: 'student01',
      title: 'أفضل طريقة لمراجعة Analyse 1؟',
      body: 'شاركونا مصادر ومراجع قوية ✨',
      votes: 12,
      tags: const ['Analyse', 'L1', 'Math'],
    ),
    _Post(
      author: 'maria',
      title: 'ملخص خفيف لهيكلة الحاسوب',
      body: 'عملت ملخص PDF—حاولوا تراجعوا به قبل TD.',
      votes: 8,
      tags: const ['Machine', 'TD'],
      mediaUrl:
          'https://images.unsplash.com/photo-1518779578993-ec3579fee39f?w=900',
    ),
  ];

  void _newPost() async {
    final p = await showModalBottomSheet<_Post>(
      isScrollControlled: true,
      context: context,
      builder: (_) => const _CreatePostSheet(),
    );
    if (p != null) {
      setState(() => _posts.insert(0, p));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نشر منشورك ✅')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مجتمع Fachub'),
        actions: [
          IconButton(
            tooltip: 'منشور جديد',
            onPressed: _newPost,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      endDrawer: const AppEndDrawer(),
      body: _posts.isEmpty
          ? const _EmptyHint(
              icon: Icons.public_outlined, title: 'لا توجد منشورات بعد')
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _posts.length,
              itemBuilder: (_, i) => _PostCard(
                post: _posts[i],
                onVote: (delta) => setState(() => _posts[i].votes += delta),
                onComment: () async {
                  final txt = await showDialog<String>(
                    context: context,
                    builder: (_) => const _CommentDialog(),
                  );
                  if (txt != null && txt.trim().isNotEmpty) {
                    setState(() => _posts[i].comments.insert(
                        0, _Comment(author: 'you', text: txt.trim())));
                  }
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPost,
        icon: const Icon(Icons.edit_note),
        label: const Text('منشور'),
      ),
    );
  }
}

class _Post {
  final String author;
  final String title;
  final String body;
  final List<String> tags;
  final String? mediaUrl;
  int votes;
  final List<_Comment> comments;
  _Post({
    required this.author,
    required this.title,
    required this.body,
    this.tags = const [],
    this.mediaUrl,
    this.votes = 0,
    List<_Comment>? comments,
  }) : comments = comments ?? [];
}

class _Comment {
  final String author;
  final String text;
  _Comment({required this.author, required this.text});
}

class _PostCard extends StatelessWidget {
  final _Post post;
  final void Function(int delta) onVote;
  final VoidCallback onComment;
  const _PostCard(
      {required this.post, required this.onVote, required this.onComment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Text('u/${post.author}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              PopupMenuButton(
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share', child: Text('مشاركة')),
                  PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (post.body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(post.body),
          ],
          if (post.mediaUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                post.mediaUrl!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              runSpacing: -8,
              spacing: 6,
              children: post.tags
                  .map((t) => Chip(
                        label: Text(t),
                        backgroundColor: kChipGrey,
                        side: BorderSide.none,
                      ))
                  .toList(),
            )
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () => onVote(1),
                icon: const Icon(Icons.arrow_upward),
              ),
              Text('${post.votes}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => onVote(-1),
                icon: const Icon(Icons.arrow_downward),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.mode_comment_outlined),
                label: Text('تعليقات (${post.comments.length})'),
              ),
            ],
          ),
          if (post.comments.isNotEmpty) const Divider(),
          ...post.comments
              .take(4)
              .map((c) => ListTile(
                    leading: const Icon(Icons.comment, size: 20),
                    title: Text('u/${c.author}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(c.text),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ))
              .toList(),
        ]),
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet();
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _media = TextEditingController();
  final _tag = TextEditingController();
  final List<String> _tags = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('منشور جديد',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _body,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'المحتوى'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _media,
              decoration: const InputDecoration(
                  labelText: 'رابط صورة/فيديو (اختياري)'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tag,
                    decoration: const InputDecoration(labelText: 'وسم'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: () {
                      final t = _tag.text.trim();
                      if (t.isNotEmpty) {
                        setState(() {
                          _tags.add(t);
                          _tag.clear();
                        });
                      }
                    },
                    child: const Text('إضافة')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _tags
                  .map((t) => Chip(
                        label: Text(t),
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                if (_title.text.trim().isEmpty &&
                    _body.text.trim().isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(
                    context,
                    _Post(
                      author: 'you',
                      title: _title.text.trim(),
                      body: _body.text.trim(),
                      mediaUrl: _media.text.trim().isEmpty
                          ? null
                          : _media.text.trim(),
                      tags: _tags,
                      votes: 1,
                    ));
              },
              icon: const Icon(Icons.send),
              label: const Text('نشر'),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog();
  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعليق'),
      content: TextField(
        controller: _c,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'اكتب تعليقك…'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(context, _c.text.trim()),
            child: const Text('نشر')),
      ],
    );
  }
}

// =========================== Calculator Hub (Quick) ==========================
class CalculatorHubScreen extends StatelessWidget {
  const CalculatorHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة المعدل')),
      endDrawer: const AppEndDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('حساب سريع (مواد + معامل)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuickAverageScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('جدول مفصّل (S1/S2) مثل الصورة'),
              subtitle: const Text('مكوّنات TD/TP/EXAM وحساب آلي'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final track = demoFaculties.first.majors.first.tracks.first;
                final specs = createSemesterSpecsForTrack(track);
                final sem1 = _pickSemester(specs, 'S1');
                final sem2 = _pickSemester(specs, 'S2');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudiesTableScreen(
                      facultyName: demoFaculties.first.name,
                      programName:
                          '${demoFaculties.first.majors.first.name} • ${track.name}',
                      semester1Modules: sem1,
                      semester2Modules: sem2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAverageScreen extends StatefulWidget {
  const QuickAverageScreen({super.key});
  @override
  State<QuickAverageScreen> createState() => _QuickAverageScreenState();
}

class _QuickAverageScreenState extends State<QuickAverageScreen> {
  final subjects = <Map<String, dynamic>>[];
  double threshold = 10, avg = 0;

  void _add() => setState(
      () => subjects.add({'name': 'مادة', 'coef': 1.0, 'grade': 0.0}));
  void _calc() {
    double sum = 0, csum = 0;
    for (final s in subjects) {
      sum += (s['grade'] ?? 0) * (s['coef'] ?? 1);
      csum += (s['coef'] ?? 1);
    }
    setState(() => avg = csum == 0 ? 0 : sum / csum);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حساب سريع')),
      endDrawer: const AppEndDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ...subjects.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller:
                          TextEditingController(text: s['name'] ?? ''),
                      onChanged: (v) => s['name'] = v,
                      decoration:
                          const InputDecoration(labelText: 'المادة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                          text: (s['coef'] ?? 1).toString()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          s['coef'] = double.tryParse(v) ?? 1.0,
                      decoration:
                          const InputDecoration(labelText: 'المعامل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                          text: (s['grade'] ?? 0).toString()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          s['grade'] = double.tryParse(v) ?? 0.0,
                      decoration:
                          const InputDecoration(labelText: 'العلامة'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => subjects.removeAt(i)),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                  )
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة')),
              const SizedBox(width: 8),
              FilledButton.icon(
                  onPressed: _calc,
                  icon: const Icon(Icons.calculate),
                  label: const Text('احسب')),
              const Spacer(),
              SizedBox(
                width: 130,
                child: TextField(
                  decoration:
                      const InputDecoration(labelText: 'عتبة النجاح'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) =>
                      threshold = double.tryParse(v) ?? 10,
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'المعدل: ${avg.toStringAsFixed(2)} — ${avg >= threshold ? "✅ ناجح" : "❌ راسب"}',
            style: TextStyle(
              color: avg >= threshold ? Colors.green : Colors.red,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =================== Studies: Faculties → Majors → Tracks ====================
class ProgramComponent {
  final String label;   // TD / TP / EXAM / CC...
  final double weight;  // نسبة مئوية (0..100)
  const ProgramComponent(this.label, this.weight);
}

class ProgramModule {
  final String name;
  final int coef;
  final int credits;
  final List<ProgramComponent> components;
  const ProgramModule({
    required this.name,
    required this.coef,
    required this.credits,
    required this.components,
  });
}

class ProgramSemester {
  final String label; // S1 / S2
  final List<ProgramModule> modules;
  const ProgramSemester({required this.label, required this.modules});
}

class ProgramTrack {
  final String name;
  final List<ProgramSemester> semesters; // S1,S2
  const ProgramTrack({required this.name, required this.semesters});
}

class ProgramMajor {
  final String name;
  final List<ProgramTrack> tracks;
  const ProgramMajor({required this.name, required this.tracks});
}

class ProgramFaculty {
  final String name;
  final List<ProgramMajor> majors;
  const ProgramFaculty({required this.name, required this.majors});
}

// بيانات تجريبية
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
                    components: [
                      ProgramComponent('TD', 30),
                      ProgramComponent('EXAM', 70),
                    ],
                  ),
                  ProgramModule(
                    name: 'Algèbre 1',
                    coef: 3, credits: 5,
                    components: [
                      ProgramComponent('TD', 30),
                      ProgramComponent('EXAM', 70),
                    ],
                  ),
                  ProgramModule(
                    name: 'Algorithmique 1',
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
                    components: [
                      ProgramComponent('TD', 40),
                      ProgramComponent('EXAM', 60),
                    ],
                  ),
                  ProgramModule(
                    name: 'Terminologie scientifique',
                    coef: 2, credits: 3,
                    components: [ProgramComponent('EXAM', 100)],
                  ),
                ],
              ),
              ProgramSemester(
                label: 'S2',
                modules: [
                  ProgramModule(
                    name: 'Analyse 2',
                    coef: 4, credits: 6,
                    components: [
                      ProgramComponent('TD', 30),
                      ProgramComponent('EXAM', 70),
                    ],
                  ),
                  ProgramModule(
                    name: 'Algèbre 2',
                    coef: 2, credits: 4,
                    components: [
                      ProgramComponent('TD', 30),
                      ProgramComponent('EXAM', 70),
                    ],
                  ),
                  ProgramModule(
                    name: 'Algorithmique 2',
                    coef: 2, credits: 4,
                    components: [
                      ProgramComponent('TP', 20),
                      ProgramComponent('TD', 20),
                      ProgramComponent('EXAM', 60),
                    ],
                  ),
                  ProgramModule(
                    name: 'Probabilités & Stat.',
                    coef: 3, credits: 5,
                    components: [
                      ProgramComponent('TD', 40),
                      ProgramComponent('EXAM', 60),
                    ],
                  ),
                  ProgramModule(
                    name: 'Langue Étrangère',
                    coef: 1, credits: 2,
                    components: [ProgramComponent('EXAM', 100)],
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

// ===================== GPA Table Data Model (public) ========================
class EvalWeight {
  final String label;
  final double weight;
  const EvalWeight({required this.label, required this.weight});
}

class ModuleSpec {
  final String name;
  final double coef;
  final double credits;
  final List<EvalWeight> evalWeights;
  const ModuleSpec({
    required this.name,
    required this.coef,
    required this.credits,
    required this.evalWeights,
  });

  double get totalWeight =>
      evalWeights.fold<double>(0, (sum, item) => sum + item.weight);
}

class SemesterSpec {
  final String name;
  final List<ModuleSpec> modules;
  const SemesterSpec({required this.name, required this.modules});
}

List<SemesterSpec> createSemesterSpecsForTrack(ProgramTrack track) {
  return track.semesters
      .map(
        (sem) => SemesterSpec(
          name: sem.label,
          modules: sem.modules
              .map(
                (module) => ModuleSpec(
                  name: module.name,
                  coef: module.coef.toDouble(),
                  credits: module.credits.toDouble(),
                  evalWeights: _normalizeEvalWeights(module.components),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

List<SemesterSpec> demoL1GpaSpecs() {
  final track = demoFaculties.first.majors.first.tracks.first;
  return createSemesterSpecsForTrack(track);
}

List<EvalWeight> _normalizeEvalWeights(List<ProgramComponent> components) {
  final Map<String, double> weights = {
    'TD': 0,
    'TP': 0,
    'EXAM': 0,
  };
  for (final c in components) {
    final key = c.label.toUpperCase();
    if (weights.containsKey(key)) {
      weights[key] = c.weight;
    }
  }
  return [
    EvalWeight(label: 'TD', weight: weights['TD']!),
    EvalWeight(label: 'TP', weight: weights['TP']!),
    EvalWeight(label: 'EXAM', weight: weights['EXAM']!),
  ];
}

class ModuleModel {
  ModuleModel({
    required this.title,
    required this.coef,
    required this.credits,
    required this.tdWeight,
    required this.tpWeight,
    required this.examWeight,
  });

  final String title;
  final double coef;
  final double credits;
  final double tdWeight;
  final double tpWeight;
  final double examWeight;
  double? td;
  double? tp;
  double? exam;

  bool get hasTD => tdWeight > 0;
  bool get hasTP => tpWeight > 0;
}

class SemesterModel {
  SemesterModel({
    required this.name,
    required this.modules,
    required VoidCallback onChanged,
  }) : _onChanged = onChanged;

  factory SemesterModel.fromSpec(
    SemesterSpec spec, {
    required VoidCallback onChanged,
  }) {
    final modules = spec.modules.map((module) {
      double weightFor(String label) {
        return module.evalWeights
            .firstWhere(
              (w) => w.label.toUpperCase() == label,
              orElse: () => const EvalWeight(label: 'TMP', weight: 0),
            )
            .weight;
      }

      return ModuleModel(
        title: module.name,
        coef: module.coef,
        credits: module.credits,
        tdWeight: weightFor('TD'),
        tpWeight: weightFor('TP'),
        examWeight: weightFor('EXAM'),
      );
    }).toList(growable: false);

    return SemesterModel(name: spec.name, modules: modules, onChanged: onChanged);
  }

  final String name;
  final List<ModuleModel> modules;
  final VoidCallback _onChanged;

  void recompute() => _onChanged();

  double moduleAverage(ModuleModel module) {
    double total = 0;
    double weights = 0;

    void accumulate(double? value, double weight) {
      if (weight <= 0) return;
      final v = value ?? 0;
      total += v * weight;
      weights += weight;
    }

    accumulate(module.td, module.tdWeight);
    accumulate(module.tp, module.tpWeight);
    accumulate(module.exam, module.examWeight);

    if (weights == 0) {
      return 0;
    }
    return total / weights;
  }

  double moduleCreditsEarned(ModuleModel module) {
    final avg = moduleAverage(module);
    return avg >= 10 ? module.credits : 0;
  }

  double semesterAverage() {
    double weighted = 0;
    double coefs = 0;
    for (final module in modules) {
      weighted += moduleAverage(module) * module.coef;
      coefs += module.coef;
    }
    if (coefs == 0) {
      return 0;
    }
    return weighted / coefs;
  }

  double creditsEarned() {
    return modules.fold<double>(0, (sum, module) => sum + moduleCreditsEarned(module));
  }
}

// ---------- Table helpers ----------
class _NumField extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  const _NumField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: TextFormField(
        textAlign: TextAlign.center,
        initialValue: value == null
            ? ''
            : value!.toStringAsFixed(
                value!.truncateToDouble() == value ? 0 : 2,
              ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
        inputFormatters: [
          // allow 0..20 with optional decimals
          FilteringTextInputFormatter.allow(
            RegExp(r'^([0-1]?\d(\.\d{0,2})?|20(\.0{0,2})?)$'),
          ),
        ],
        onChanged: (s) => onChanged(
          s.isEmpty ? null : double.tryParse(s.replaceAll(',', '.')),
        ),
      ),
    );
  }
}

// Compact text widget that never wraps:
Widget _cell(String s, {bool bold = false, bool center = false}) => Text(
      s,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
    );
// -----------------------------------

SemesterSpec _pickSemester(List<SemesterSpec> specs, String label) {
  final normalizedLabel = label.toUpperCase();
  if (specs.isEmpty) {
    return const SemesterSpec(name: 'S?', modules: []);
  }
  return specs.firstWhere(
    (s) => s.name.toUpperCase() == normalizedLabel,
    orElse: () {
      if (normalizedLabel == 'S1') {
        return specs.first;
      }
      if (normalizedLabel == 'S2' && specs.length > 1) {
        return specs.last;
      }
      return specs.first;
    },
  );
}

// ================================ UI: Faculties ==============================
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
            title:
                Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => FacultyMajorsScreen(faculty: f)));
            },
          );
        },
      ),
    );
  }
}

// =============================== UI: Majors =================================
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MajorTracksScreen(
                    major: m,
                    faculty: faculty,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================== UI: Tracks =================================
class MajorTracksScreen extends StatelessWidget {
  final ProgramMajor major;
  final ProgramFaculty faculty;
  const MajorTracksScreen({super.key, required this.major, required this.faculty});

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
              final specs = createSemesterSpecsForTrack(t);
              final sem1 = _pickSemester(specs, 'S1');
              final sem2 = _pickSemester(specs, 'S2');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudiesTableScreen(
                    facultyName: faculty.name,
                    programName: '${major.name} • ${t.name}',
                    semester1Modules: sem1,
                    semester2Modules: sem2,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ========================== UI: Studies GPA Table ============================
class StudiesTableScreen extends StatefulWidget {
  final String facultyName;
  final String programName;
  final SemesterSpec semester1Modules;
  final SemesterSpec semester2Modules;

  const StudiesTableScreen({
    super.key,
    required this.facultyName,
    required this.programName,
    required this.semester1Modules,
    required this.semester2Modules,
  });

  @override
  State<StudiesTableScreen> createState() => _StudiesTableScreenState();
}

class _StudiesTableScreenState extends State<StudiesTableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late SemesterModel _semester1;
  late SemesterModel _semester2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSemesters();
  }

  void _initSemesters() {
    _semester1 = SemesterModel.fromSpec(
      widget.semester1Modules,
      onChanged: () => setState(() {}),
    );
    _semester2 = SemesterModel.fromSpec(
      widget.semester2Modules,
      onChanged: () => setState(() {}),
    );
  }

  @override
  void didUpdateWidget(covariant StudiesTableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.semester1Modules != widget.semester1Modules ||
        oldWidget.semester2Modules != widget.semester2Modules) {
      _initSemesters();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStickyHeader(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.textTheme.bodySmall?.color?.withOpacity(.7);
    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.programName,
              style:
                  theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.facultyName,
              style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sem1 = _semester1;
    final sem2 = _semester2;
    final s1Avg = sem1.semesterAverage();
    final s2Avg = sem2.semesterAverage();
    final yearAvg = (s1Avg + s2Avg) / 2;
    final totalCredits = sem1.creditsEarned() + sem2.creditsEarned();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facultyName),
      ),
      endDrawer: const AppEndDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildStickyHeader(context),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'S1'),
                  Tab(text: 'S2'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: buildSemesterTable(context, sem1),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: buildSemesterTable(context, sem2),
                  ),
                ],
              ),
            ),
            buildAnnualSummary(context, sem1, sem2),
          ],
        ),
      ),
    );
  }
}

Widget buildSemesterTable(BuildContext context, SemesterModel sem) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 760),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            horizontalMargin: 12,
            columnSpacing: 18,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
            columns: [
              DataColumn(label: _cell('Module', bold: true)),
              DataColumn(label: _cell('Coef', bold: true, center: true), numeric: true),
              DataColumn(label: _cell('Cred', bold: true, center: true), numeric: true),
              DataColumn(label: _cell('Notes (TD / TP / EXAM)', bold: true)),
              DataColumn(label: _cell('Moyenne module', bold: true, center: true), numeric: true),
              DataColumn(label: _cell('Cred Mod', bold: true, center: true), numeric: true),
            ],
            rows: sem.modules.map((m) {
              final noteCells = Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (m.hasTD)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                        child: _NumField(
                          value: m.td,
                          onChanged: (v) {
                            m.td = v;
                            sem.recompute();
                          },
                        ),
                      ),
                    if (m.hasTP)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                        child: _NumField(
                          value: m.tp,
                          onChanged: (v) {
                            m.tp = v;
                            sem.recompute();
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                      child: _NumField(
                        value: m.exam,
                        onChanged: (v) {
                          m.exam = v;
                          sem.recompute();
                        },
                      ),
                    ),
                  ],
                ),
              );

              return DataRow(
                cells: [
                  DataCell(_cell(m.title, bold: true)),
                  DataCell(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _cell('${m.coef}', center: true),
                    ),
                  ),
                  DataCell(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _cell('${m.credits}', center: true),
                    ),
                  ),
                  DataCell(noteCells),
                  DataCell(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _cell(sem.moduleAverage(m).toStringAsFixed(2), center: true),
                    ),
                  ),
                  DataCell(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _cell(sem.moduleCreditsEarned(m).toStringAsFixed(0), center: true),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

Widget buildAnnualSummary(BuildContext context, SemesterModel s1, SemesterModel s2) {
  final moy1 = s1.semesterAverage();
  final moy2 = s2.semesterAverage();
  final ann = (moy1 + moy2) / 2;
  final creds = s1.creditsEarned() + s2.creditsEarned();

  Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(value),
            ),
          ],
        ),
      );

  return Card(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text('Résumé annuel', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          row('Moyenne Semester 1', moy1.toStringAsFixed(2)),
          row('Moyenne Semester 2', moy2.toStringAsFixed(2)),
          const Divider(height: 20),
          row('Année', ann.toStringAsFixed(2)),
          row('Total Credits', creds.toStringAsFixed(0)),
        ],
      ),
    ),
  );
}
// ============================================================================
// PART 3/3 — Helpers, Colors, Studies helpers, Compatibility adapters
// ============================================================================

// لون خفيف للوسوم/الشرائح في المجتمع
const kChipGrey = Color(0xFFE9ECF1);

// ويدجت حالة فارغة (مخصص للمجتمع وغيره)
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyHint({required this.icon, required this.title, this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.outline),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// امتداد آمن للسلاسل (إن لم يكن موجوداً في أجزاء سابقة)
extension SafeStringExt on String {
  String ellipsize(int max, {String ellipsis = '…'}) {
    if (length <= max) return this;
    if (max <= 0) return '';
    return substring(0, max) + ellipsis;
  }
}

// دالة تأخذك مباشرةً إلى واجهة “الدراسة”
void openStudiesNavigator(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FacultiesScreen(faculties: demoFaculties)),
  );
}

// زر اختصار يفتح الدراسة (للاستخدام داخل AppBar.actions)
class StudiesActionButton extends StatelessWidget {
  const StudiesActionButton({super.key});
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'الدراسة (كليات → تخصّصات → مسارات → جدول)',
      icon: const Icon(Icons.menu_book_outlined),
      onPressed: () => openStudiesNavigator(context),
    );
  }
}

// ---------------------------------------------------------------------------
// توافقية: بعض الأقسام القديمة كانت تستدعي CalculatorScreen بالاسم القديم.
// حتى لا ينكسر أي استدعاء، نوفّر كلاس بنفس الاسم يشير إلى الشاشة الجديدة.
// ---------------------------------------------------------------------------
class CalculatorScreen extends CalculatorHubScreen {
  const CalculatorScreen({super.key});
}

// ============================================================================
// END OF FILE — Fachub
// ============================================================================
