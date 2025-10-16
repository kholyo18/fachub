// ======================= Fachub (main.dart) — FULL (Part 1/3) =======================
// Features in this build:
// - Brand (Green #16A34A, Blue #2563EB), Theming, Models, GPA logic
// - Storage abstraction with graceful Firebase bootstrap (falls back to LocalStore)
// - Anonymous Auth (optional) + Firestore Chat when Firebase is available
// - SharedPreferences autosave for TermData
// - UI Shell: BottomNav (Calculator / Chat / SettingsPro)
// - Part 2 adds: Firestore-powered Chat UI + local fallback details
// - Part 3 adds: Advanced Settings, Templates, JSON Import/Export, optional PDF export

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ===== Optional deps (enable after adding packages to pubspec) =====
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// If you already generated firebase_options.dart using FlutterFire CLI, import it here.
// Otherwise, we will use a placeholder options block.
// import 'firebase_options.dart';

// --------------------------------- Branding ----------------------------------

const kFachubGreen = Color(0xFF16A34A);
const kFachubBlue  = Color(0xFF2563EB);
const kSurface     = Color(0xFFF7F8FA);
const kTextDark    = Color(0xFF0F172A);

ThemeData buildFachubTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    primaryColor: kFachubGreen,
    scaffoldBackgroundColor: kSurface,
    colorScheme: base.colorScheme.copyWith(
      primary: kFachubGreen,
      secondary: kFachubBlue,
      surface: kSurface,
      onSurface: kTextDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0.6,
      foregroundColor: kTextDark,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kFachubBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kFachubGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kFachubBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: kFachubBlue.withOpacity(.12),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      labelStyle: const TextStyle(color: kTextDark),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// --------------------------------- Models ------------------------------------

class SubjectPart {
  final String label;     // e.g., TD, TP, EXAM
  final double weight;    // 0..1
  double? score;          // 0..20
  double? resitScore;     // optional resit for this part
  SubjectPart({
    required this.label,
    required this.weight,
    this.score,
    this.resitScore,
  });
  SubjectPart copyWith({String? label, double? weight, double? score, double? resitScore}) {
    return SubjectPart(
      label: label ?? this.label,
      weight: weight ?? this.weight,
      score: score ?? this.score,
      resitScore: resitScore ?? this.resitScore,
    );
  }
}

class Subject {
  final String id;
  String name;
  double coeff;
  bool eliminatory;
  double eliminatoryThreshold;  // default 7.0/20
  List<SubjectPart> parts;
  Subject({
    required this.id,
    required this.name,
    required this.coeff,
    required this.parts,
    this.eliminatory = false,
    this.eliminatoryThreshold = 7.0,
  });
  Subject copy() => Subject(
    id: id,
    name: name,
    coeff: coeff,
    parts: parts.map((p) => p.copyWith()).toList(),
    eliminatory: eliminatory,
    eliminatoryThreshold: eliminatoryThreshold,
  );
}

class TermSystem {
  final double passThreshold; // e.g., 10/20
  final bool hasResit;
  final int roundTo;
  const TermSystem({this.passThreshold = 10.0, this.hasResit = true, this.roundTo = 2});
  TermSystem copyWith({double? passThreshold, bool? hasResit, int? roundTo}) =>
      TermSystem(
        passThreshold: passThreshold ?? this.passThreshold,
        hasResit: hasResit ?? this.hasResit,
        roundTo: roundTo ?? this.roundTo,
      );
}

class TermData {
  String label; // e.g., "S1 2025/2026"
  TermSystem system;
  List<Subject> subjects;
  TermData({required this.label, required this.system, required this.subjects});
  TermData copy() => TermData(
        label: label,
        system: system.copyWith(),
        subjects: subjects.map((s) => s.copy()).toList(),
      );
}

// ------------------------------ GPA Logic ------------------------------------

double _roundTo(double value, int dec) {
  final factor = List.filled(dec, 0).fold(1.0, (p, _) => p * 10.0);
  return (value * factor).round() / factor;
}

double subjectAverage(Subject s, {required TermSystem sys}) {
  double total = 0.0;
  for (final p in s.parts) {
    final base = (p.score ?? 0.0).clamp(0.0, 20.0);
    if (sys.hasResit && p.resitScore != null) {
      final resit = (p.resitScore ?? 0.0).clamp(0.0, 20.0);
      total += (base > resit ? base : resit) * p.weight;
    } else {
      total += base * p.weight;
    }
  }
  return _roundTo(total, sys.roundTo);
}

bool isSubjectEliminated(Subject s, {required TermSystem sys}) {
  if (!s.eliminatory) return false;
  final avg = subjectAverage(s, sys: sys);
  return avg < s.eliminatoryThreshold;
}

double termAverage(TermData term) {
  for (final s in term.subjects) {
    if (isSubjectEliminated(s, sys: term.system)) {
      return 0.0; // mark failed due to eliminatory subject
    }
  }
  double weightedSum = 0.0;
  double coeffSum = 0.0;
  for (final s in term.subjects) {
    final avg = subjectAverage(s, sys: term.system);
    weightedSum += avg * s.coeff;
    coeffSum += s.coeff;
  }
  if (coeffSum == 0) return 0.0;
  return _roundTo(weightedSum / coeffSum, term.system.roundTo);
}

bool termPassed(TermData term) => termAverage(term) >= term.system.passThreshold;

// ---------------------- Encode / Decode (for local save) ---------------------

Map<String, dynamic> _encodePart(SubjectPart p) => {
  'label': p.label, 'weight': p.weight, 'score': p.score, 'resitScore': p.resitScore,
};
SubjectPart _decodePart(Map<String, dynamic> m) => SubjectPart(
  label: (m['label'] ?? '') as String,
  weight: (m['weight'] ?? 0).toDouble(),
  score: m['score'] == null ? null : (m['score']).toDouble(),
  resitScore: m['resitScore'] == null ? null : (m['resitScore']).toDouble(),
);

Map<String, dynamic> _encodeSubject(Subject s) => {
  'id': s.id,
  'name': s.name,
  'coeff': s.coeff,
  'eliminatory': s.eliminatory,
  'eliminatoryThreshold': s.eliminatoryThreshold,
  'parts': s.parts.map(_encodePart).toList(),
};
Subject _decodeSubject(Map<String, dynamic> m) => Subject(
  id: (m['id'] ?? UniqueKey().toString()) as String,
  name: (m['name'] ?? 'Subject') as String,
  coeff: (m['coeff'] ?? 1).toDouble(),
  eliminatory: (m['eliminatory'] ?? false) as bool,
  eliminatoryThreshold: (m['eliminatoryThreshold'] ?? 7.0).toDouble(),
  parts: (m['parts'] as List<dynamic>? ?? []).map((e) => _decodePart(e as Map<String, dynamic>)).toList(),
);

Map<String, dynamic> encodeTerm(TermData t) => {
  'label': t.label, 'system': {
    'passThreshold': t.system.passThreshold,
    'hasResit': t.system.hasResit,
    'roundTo': t.system.roundTo,
  }, 'subjects': t.subjects.map(_encodeSubject).toList(),
};
TermData decodeTerm(Map<String, dynamic> m) => TermData(
  label: (m['label'] ?? 'S1') as String,
  system: TermSystem(
    passThreshold: (m['system']?['passThreshold'] ?? 10.0).toDouble(),
    hasResit: (m['system']?['hasResit'] ?? true) as bool,
    roundTo: (m['system']?['roundTo'] ?? 2).toInt(),
  ),
  subjects: (m['subjects'] as List<dynamic>? ?? []).map((e) => _decodeSubject(e as Map<String, dynamic>)).toList(),
);

// ----------------------------- Sample / Templates ----------------------------

TermData sampleTerm() => TermData(
  label: "S1 2025/2026",
  system: const TermSystem(passThreshold: 10.0, hasResit: true, roundTo: 2),
  subjects: [
    Subject(
      id: "s_math",
      name: "Mathematics 2",
      coeff: 4,
      eliminatory: false,
      parts: [
        SubjectPart(label: "TD", weight: 0.3, score: 12),
        SubjectPart(label: "TP", weight: 0.2, score: 14),
        SubjectPart(label: "EXAM", weight: 0.5, score: 8, resitScore: 13),
      ],
    ),
    Subject(
      id: "s_algo",
      name: "Algorithms",
      coeff: 3,
      eliminatory: true,
      eliminatoryThreshold: 7.0,
      parts: [
        SubjectPart(label: "TD", weight: 0.4, score: 11),
        SubjectPart(label: "EXAM", weight: 0.6, score: 9),
      ],
    ),
    Subject(
      id: "s_arch",
      name: "Computer Architecture",
      coeff: 2,
      eliminatory: false,
      parts: [
        SubjectPart(label: "TD", weight: 0.4, score: 15),
        SubjectPart(label: "EXAM", weight: 0.6, score: 10),
      ],
    ),
  ],
);

// ------------------------------- Data Store ----------------------------------
// Abstraction so we can run in Local mode if Firebase init fails.

abstract class IDataStore {
  // Term persistence (local fallback uses SharedPreferences)
  Future<TermData?> loadTerm();
  Future<void> saveTerm(TermData term);

  // Chat
  Stream<List<ChatChannel>> channels();
  Future<ChatChannel> createChannel(String name, {bool isDM = false});
  Future<void> renameChannel(String id, String newName);
  Future<void> deleteChannel(String id);

  Stream<List<ChatMessage>> messages(String channelId);
  Future<void> sendMessage(String channelId, String text, {String sender = "Khaled"});
}

// ------------------------------ Local Store ----------------------------------

class LocalStore implements IDataStore {
  static const _kPrefKey = "fachub_term_json";
  final List<ChatChannel> _chs = [
    ChatChannel(id: "c_general", name: "general"),
    ChatChannel(id: "c_promo2cs", name: "promo-2CS"),
    ChatChannel(id: "c_math2", name: "math2"),
    ChatChannel(id: "dm_aya", name: "Aya", isDM: true),
  ];
  final Map<String, List<ChatMessage>> _msgs = {
    "c_general": [
      ChatMessage(id: "m1", sender: "Aya", text: "Welcome to Fachub 👋", time: DateTime.now().subtract(const Duration(minutes: 8))),
      ChatMessage(id: "m2", sender: "Khaled", text: "نجرب الشات المحلي. تمام! ✅", time: DateTime.now().subtract(const Duration(minutes: 7))),
    ],
    "c_promo2cs": [ChatMessage(id: "m3", sender: "Farid", text: "قروب 2CS هنا؟", time: DateTime.now().subtract(const Duration(minutes: 6)))],
    "c_math2": [ChatMessage(id: "m4", sender: "Aya", text: "نقاش TD الأسبوع القادم.", time: DateTime.now().subtract(const Duration(minutes: 5)))],
    "dm_aya": [ChatMessage(id: "m5", sender: "Aya", text: "سلام خالد! 🌿", time: DateTime.now().subtract(const Duration(minutes: 4)))],
  };

  @override
  Future<TermData?> loadTerm() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kPrefKey);
    if (s == null) return sampleTerm();
    try {
      final m = json.decode(s) as Map<String, dynamic>;
      return decodeTerm(m);
    } catch (_) {
      return sampleTerm();
    }
  }

  @override
  Future<void> saveTerm(TermData term) async {
    final sp = await SharedPreferences.getInstance();
    final s = json.encode(encodeTerm(term));
    await sp.setString(_kPrefKey, s);
  }

  @override
  Stream<List<ChatChannel>> channels() async* {
    yield _chs.map((c) => c.copy()).toList();
  }

  @override
  Future<ChatChannel> createChannel(String name, {bool isDM = false}) async {
    final id = (isDM ? "dm_" : "c_") + name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toLowerCase();
    final c = ChatChannel(id: id, name: name, isDM: isDM);
    _chs.add(c);
    _msgs[id] = [
      ChatMessage(id: UniqueKey().toString(), sender: "System", text: "تم إنشاء القناة $name", time: DateTime.now()),
    ];
    return c;
  }

  @override
  Future<void> renameChannel(String id, String newName) async {
    final idx = _chs.indexWhere((e) => e.id == id);
    if (idx != -1) _chs[idx] = _chs[idx].copyWithName(newName);
  }

  @override
  Future<void> deleteChannel(String id) async {
    _chs.removeWhere((e) => e.id == id);
    _msgs.remove(id);
  }

  @override
  Stream<List<ChatMessage>> messages(String channelId) async* {
    yield (_msgs[channelId] ?? []).toList();
  }

  @override
  Future<void> sendMessage(String channelId, String text, {String sender = "Khaled"}) async {
    final list = _msgs[channelId] ??= [];
    list.add(ChatMessage(id: UniqueKey().toString(), sender: sender, text: text.trim(), time: DateTime.now()));
  }
}

// helper copyWithName for ChatChannel
extension _ChatChannelX on ChatChannel {
  ChatChannel copyWithName(String name) => ChatChannel(id: id, name: name, isDM: isDM);
}

// ----------------------------- Firebase Store --------------------------------

class FirebaseStore implements IDataStore {
  final FirebaseFirestore db;
  final fba.FirebaseAuth auth;
  FirebaseStore(this.db, this.auth);

  static const _termDoc = "user_term"; // one doc per user for simplicity

  String get uid => auth.currentUser!.uid;

  @override
  Future<TermData?> loadTerm() async {
    final doc = await db.collection('users').doc(uid).collection('terms').doc(_termDoc).get();
    if (!doc.exists) return sampleTerm();
    final m = doc.data()!;
    return decodeTerm(Map<String, dynamic>.from(m['term'] as Map));
  }

  @override
  Future<void> saveTerm(TermData term) async {
    await db.collection('users').doc(uid).collection('terms').doc(_termDoc).set({
      'term': encodeTerm(term),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<ChatChannel>> channels() {
    return db.collection('channels').snapshots().map((snap) {
      return snap.docs.map((d) {
        final m = d.data();
        return ChatChannel(
          id: d.id,
          name: (m['name'] ?? 'channel') as String,
          isDM: (m['isDM'] ?? false) as bool,
        );
      }).toList();
    });
  }

  @override
  Future<ChatChannel> createChannel(String name, {bool isDM = false}) async {
    final ref = await db.collection('channels').add({
      'name': name,
      'isDM': isDM,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ChatChannel(id: ref.id, name: name, isDM: isDM);
  }

  @override
  Future<void> renameChannel(String id, String newName) async {
    await db.collection('channels').doc(id).update({'name': newName});
  }

  @override
  Future<void> deleteChannel(String id) async {
    // delete channel doc (messages cascade delete via rules/functions if configured)
    await db.collection('channels').doc(id).delete();
  }

  @override
  Stream<List<ChatMessage>> messages(String channelId) {
    return db
        .collection('messages')
        .where('channelId', isEqualTo: channelId)
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              final ts = m['createdAt'];
              return ChatMessage(
                id: d.id,
                sender: (m['sender'] ?? 'User') as String,
                text: (m['text'] ?? '') as String,
                time: (ts is Timestamp) ? ts.toDate() : DateTime.now(),
              );
            }).toList());
  }

  @override
  Future<void> sendMessage(String channelId, String text, {String sender = "Khaled"}) async {
    await db.collection('messages').add({
      'channelId': channelId,
      'sender': sender,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// --------------------------------- Chat Types --------------------------------

class ChatMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime time;
  ChatMessage({required this.id, required this.sender, required this.text, required this.time});
}

class ChatChannel {
  final String id;
  String name;
  final bool isDM;
  ChatChannel({required this.id, required this.name, this.isDM = false});
}

// ----------------------------- Bootstrap Service -----------------------------

class BootstrapResult {
  final IDataStore store;
  final bool firebaseReady;
  final String? modeNote;
  BootstrapResult({required this.store, required this.firebaseReady, this.modeNote});
}

/// Attempts Firebase init; if fails or misconfigured, falls back to LocalStore.
Future<BootstrapResult> bootstrapApp() async {
  // Request notification permission early (safe even if Firebase fails).
  try {
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      // Show a simple log; UI will snack later when context available.
      debugPrint("FCM message: ${msg.notification?.title ?? ''} ${msg.notification?.body ?? ''}");
    });
  } catch (_) {}

  bool fbOk = false;
  try {
    // If you have firebase_options.dart, prefer:
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Minimal init (requires google-services setup on Android/iOS). If not set, this will throw.
    await Firebase.initializeApp();
    // Anonymous sign-in for quick testing
    if (fba.FirebaseAuth.instance.currentUser == null) {
      await fba.FirebaseAuth.instance.signInAnonymously();
    }
    fbOk = true;
  } catch (e) {
    debugPrint("Firebase init failed, switching to LocalStore. Reason: $e");
  }

  if (fbOk) {
    final store = FirebaseStore(FirebaseFirestore.instance, fba.FirebaseAuth.instance);
    return BootstrapResult(store: store, firebaseReady: true, modeNote: "Online: Firebase");
  } else {
    final store = LocalStore();
    return BootstrapResult(store: store, firebaseReady: false, modeNote: "Offline: Local mode");
  }
}

// ----------------------------------- App -------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = await bootstrapApp();
  runApp(FachubApp(boot: boot));
}

class FachubApp extends StatelessWidget {
  final BootstrapResult boot;
  const FachubApp({super.key, required this.boot});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fachub',
      debugShowCheckedModeBanner: false,
      theme: buildFachubTheme(),
      home: FachubHome(boot: boot),
    );
  }
}

class FachubHome extends StatefulWidget {
  final BootstrapResult boot;
  const FachubHome({super.key, required this.boot});

  @override
  State<FachubHome> createState() => _FachubHomeState();
}

class _FachubHomeState extends State<FachubHome> {
  int _index = 0;
  TermData? _term; // will load async
  late final IDataStore _store;
  String _mode = "";

  @override
  void initState() {
    super.initState();
    _store = widget.boot.store;
    _mode = widget.boot.modeNote ?? "";
    _loadTerm();
  }

  Future<void> _loadTerm() async {
    final t = await _store.loadTerm() ?? sampleTerm();
    setState(() => _term = t);
  }

  Future<void> _saveTerm(TermData t) async {
    await _store.saveTerm(t);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved")));
    }
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    if (_term == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Fachub")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      CalculatorScreen(
        term: _term!,
        onChanged: (t) {
          setState(() => _term = t);
          _saveTerm(t);
        },
      ),
      // Part 2: ChatScreen (Firestore if online, else local)
      ChatScreen(store: _store, isOnline: widget.boot.firebaseReady),
      // Part 3: SettingsScreenPro (templates + backup/restore)
      SettingsScreenPro(
        term: _term!,
        onApplyTerm: (t) {
          setState(() => _term = t);
          _saveTerm(t);
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fachub"),
        actions: [
          if (_mode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                child: Text(_mode, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
          const _BrandMark(),
        ],
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: "Calculator",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: "Chat",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

// --------------------------------- BrandMark ---------------------------------

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: const LinearGradient(
          colors: [kFachubGreen, kFachubBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        "Fachub",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// =========================== Calculator UI (base) ============================
// (Editors for term/subjects/parts — extended further in Part 2)

class CalculatorScreen extends StatefulWidget {
  final TermData term;
  final ValueChanged<TermData> onChanged;
  const CalculatorScreen({super.key, required this.term, required this.onChanged});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late TermData _term;

  @override
  void initState() {
    super.initState();
    _term = widget.term.copy();
  }

  void _notify() => widget.onChanged(_term.copy());

  void _addSubject() {
    setState(() {
      _term.subjects.add(
        Subject(
          id: UniqueKey().toString(),
          name: "New Subject",
          coeff: 1,
          eliminatory: false,
          eliminatoryThreshold: 7.0,
          parts: [SubjectPart(label: "EXAM", weight: 1.0, score: 0)],
        ),
      );
    });
    _notify();
  }

  void _removeSubject(String id) {
    setState(() => _term.subjects.removeWhere((s) => s.id == id));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final avg = termAverage(_term);
    final pass = termPassed(_term);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            _TermHeader(
              label: _term.label,
              avg: avg,
              pass: pass,
              threshold: _term.system.passThreshold,
              onChangeLabel: (v) {
                setState(() => _term.label = v);
                _notify();
              },
              onSaveNow: () => _notify(),
            ),
            const SizedBox(height: 8),
            _SystemChips(
              system: _term.system,
              onChanged: (sys) {
                setState(() => _term.system = sys);
                _notify();
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final s in _term.subjects)
                    _SubjectCard(
                      subject: s,
                      system: _term.system,
                      onChanged: (newSubj) {
                        setState(() {
                          final idx = _term.subjects.indexWhere((x) => x.id == s.id);
                          if (idx != -1) _term.subjects[idx] = newSubj;
                        });
                        _notify();
                      },
                      onDelete: () => _removeSubject(s.id),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addSubject,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Subject"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TermHeader extends StatelessWidget {
  final String label;
  final double avg;
  final bool pass;
  final double threshold;
  final ValueChanged<String> onChangeLabel;
  final VoidCallback onSaveNow;

  const _TermHeader({
    required this.label,
    required this.avg,
    required this.pass,
    required this.threshold,
    required this.onChangeLabel,
    required this.onSaveNow,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = pass ? kFachubGreen : Colors.redAccent;
    final statusText  = pass ? "Passed" : "Failed";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: label),
                    onChanged: onChangeLabel,
                    decoration: const InputDecoration(
                      labelText: "Term Label",
                      hintText: "e.g., S1 2025/2026",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [kFachubGreen, kFachubBlue]),
                  ),
                  child: Column(
                    children: [
                      const Text("Average", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        avg.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Save",
                  onPressed: onSaveNow,
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.verified, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  "$statusText  •  Threshold ${threshold.toStringAsFixed(1)}",
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemChips extends StatelessWidget {
  final TermSystem system;
  final ValueChanged<TermSystem> onChanged;
  const _SystemChips({required this.system, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: -8,
      children: [
        _ChipNumber(
          label: "Pass", value: system.passThreshold, min: 5, max: 20, step: 0.5,
          onChanged: (v) => onChanged(system.copyWith(passThreshold: v)),
        ),
        FilterChip(
          label: const Text("Resit Enabled"),
          selected: system.hasResit,
          onSelected: (v) => onChanged(system.copyWith(hasResit: v)),
        ),
        _ChipNumber(
          label: "Round", value: system.roundTo.toDouble(), min: 0, max: 3, step: 1, displayAsInt: true,
          onChanged: (v) => onChanged(system.copyWith(roundTo: v.toInt())),
        ),
      ],
    );
  }
}

class _ChipNumber extends StatelessWidget {
  final String label;
  final double value, min, max, step;
  final bool displayAsInt;
  final ValueChanged<double> onChanged;
  const _ChipNumber({
    required this.label, required this.value, required this.min, required this.max, required this.step,
    this.displayAsInt = false, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text("$label: ${displayAsInt ? value.toInt() : value.toStringAsFixed(1)}"),
      onPressed: () async {
        final v = await showDialog<double>(
          context: context,
          builder: (_) => _NumberPickerDialog(
            title: label, value: value, min: min, max: max, step: step, displayAsInt: displayAsInt,
          ),
        );
        if (v != null) onChanged(v);
      },
    );
  }
}

class _NumberPickerDialog extends StatefulWidget {
  final String title;
  final double value, min, max, step;
  final bool displayAsInt;
  const _NumberPickerDialog({
    required this.title, required this.value, required this.min, required this.max, required this.step, required this.displayAsInt,
  });
  @override
  State<_NumberPickerDialog> createState() => _NumberPickerDialogState();
}
class _NumberPickerDialogState extends State<_NumberPickerDialog> {
  late double v;
  @override
  void initState() { super.initState(); v = widget.value; }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.displayAsInt ? v.toInt().toString() : v.toStringAsFixed(1),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Slider(
          value: v, min: widget.min, max: widget.max,
          divisions: ((widget.max - widget.min) / widget.step).round(),
          onChanged: (nv) => setState(() => v = widget.displayAsInt ? nv.roundToDouble() : nv),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.pop(context, v), child: const Text("OK")),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final TermSystem system;
  final ValueChanged<Subject> onChanged;
  final VoidCallback onDelete;
  const _SubjectCard({required this.subject, required this.system, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final avg = subjectAverage(subject, sys: system);
    final eliminated = isSubjectEliminated(subject, sys: system);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _InlineTextField(initial: subject.name, label: "Subject Name",
                  onChanged: (v) => onChanged(subject.copy()..name = v))),
                const SizedBox(width: 12),
                _CoeffBadge(
                  coeff: subject.coeff,
                  onTap: () async {
                    final nv = await showDialog<double>(
                      context: context,
                      builder: (_) => _NumberPickerDialog(title: "Coeff", value: subject.coeff,
                        min: 1, max: 8, step: 1, displayAsInt: true),
                    );
                    if (nv != null) onChanged(subject.copy()..coeff = nv);
                  },
                ),
                const SizedBox(width: 6),
                IconButton(tooltip: "Delete", onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 8),
            _PartsEditor(subject: subject, system: system, onChanged: onChanged),
            const SizedBox(height: 8),
            Row(
              children: [
                _EliminatorySwitch(
                  value: subject.eliminatory,
                  threshold: subject.eliminatoryThreshold,
                  onChanged: (v, th) {
                    final s = subject.copy()
                      ..eliminatory = v
                      ..eliminatoryThreshold = th ?? subject.eliminatoryThreshold;
                    onChanged(s);
                  },
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: eliminated ? Colors.red.withOpacity(.1) : kFachubGreen.withOpacity(.1),
                    border: Border.all(color: eliminated ? Colors.redAccent : kFachubGreen),
                  ),
                  child: Row(
                    children: [
                      Icon(eliminated ? Icons.block : Icons.check_circle,
                          size: 18, color: eliminated ? Colors.redAccent : kFachubGreen),
                      const SizedBox(width: 6),
                      Text("Avg ${avg.toStringAsFixed(system.roundTo)}",
                          style: TextStyle(color: eliminated ? Colors.redAccent : kFachubGreen, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineTextField extends StatefulWidget {
  final String initial; final String label; final ValueChanged<String> onChanged;
  const _InlineTextField({required this.initial, required this.label, required this.onChanged});
  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}
class _InlineTextFieldState extends State<_InlineTextField> {
  late TextEditingController c;
  @override void initState() { super.initState(); c = TextEditingController(text: widget.initial); }
  @override void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return TextField(controller: c, onChanged: widget.onChanged, decoration: InputDecoration(labelText: widget.label));
  }
}

class _CoeffBadge extends StatelessWidget {
  final double coeff; final VoidCallback onTap;
  const _CoeffBadge({required this.coeff, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          color: Colors.white,
        ),
        child: Row(children: [
          const Icon(Icons.balance, size: 18, color: kFachubBlue),
          const SizedBox(width: 6),
          Text("Coeff ${coeff.toInt()}", style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _EliminatorySwitch extends StatelessWidget {
  final bool value; final double threshold; final void Function(bool, double?) onChanged;
  const _EliminatorySwitch({required this.value, required this.threshold, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Switch(value: value, activeColor: kFachubGreen, onChanged: (v) => onChanged(v, threshold)),
      const SizedBox(width: 8), const Text("Eliminatory"), const SizedBox(width: 10),
      if (value)
        ActionChip(
          label: Text("Min: ${threshold.toStringAsFixed(1)}"),
          onPressed: () async {
            final nv = await showDialog<double>(context: context, builder: (_) => const _ThresholdDialog());
            onChanged(true, nv ?? threshold);
          },
        ),
    ]);
  }
}

class _ThresholdDialog extends StatefulWidget { const _ThresholdDialog(); @override State<_ThresholdDialog> createState() => _ThresholdDialogState(); }
class _ThresholdDialogState extends State<_ThresholdDialog> {
  double th = 7.0;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Eliminatory Threshold"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(th.toStringAsFixed(1), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Slider(value: th, min: 0, max: 20, divisions: 40, onChanged: (v) => setState(() => th = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.pop(context, th), child: const Text("OK")),
      ],
    );
  }
}

class _PartsEditor extends StatelessWidget {
  final Subject subject; final TermSystem system; final ValueChanged<Subject> onChanged;
  const _PartsEditor({required this.subject, required this.system, required this.onChanged});

  void _addPart() {
    final s = subject.copy();
    s.parts.add(SubjectPart(label: "Part ${s.parts.length + 1}", weight: 0.2, score: 0));
    onChanged(s);
  }
  void _removePart(int index) {
    final s = subject.copy();
    if (s.parts.length <= 1) return;
    s.parts.removeAt(index);
    onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight = subject.parts.fold<double>(0, (p, e) => p + e.weight);
    return Column(
      children: [
        for (int i = 0; i < subject.parts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PartRow(
              part: subject.parts[i],
              hasResit: system.hasResit,
              onChanged: (p) {
                final s = subject.copy();
                s.parts[i] = p;
                onChanged(s);
              },
              onDelete: () => _removePart(i),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: totalWeight.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE5E7EB),
                color: kFachubBlue,
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Text("${(totalWeight * 100).toStringAsFixed(0)}%"),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: _addPart, icon: const Icon(Icons.add), label: const Text("Add Part")),
          ],
        ),
        if (totalWeight != 1.0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text("Weights sum is ${totalWeight.toStringAsFixed(2)} (should be 1.0)",
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  final SubjectPart part; final bool hasResit; final ValueChanged<SubjectPart> onChanged; final VoidCallback onDelete;
  const _PartRow({required this.part, required this.hasResit, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final labelC = TextEditingController(text: part.label);
    final weightC = TextEditingController(text: part.weight.toStringAsFixed(2));
    final scoreC  = TextEditingController(text: (part.score ?? 0).toString());
    final resitC  = TextEditingController(text: (part.resitScore ?? 0).toString());

    return Row(
      children: [
        Expanded(flex: 20, child: TextField(controller: labelC, decoration: const InputDecoration(labelText: "Label"),
            onChanged: (v) => onChanged(part.copyWith(label: v)))),
        const SizedBox(width: 8),
        Expanded(flex: 14, child: TextField(
          controller: weightC, decoration: const InputDecoration(labelText: "Weight"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(part.copyWith(weight: double.tryParse(v) ?? part.weight)),
        )),
        const SizedBox(width: 8),
        Expanded(flex: 14, child: TextField(
          controller: scoreC, decoration: const InputDecoration(labelText: "Score"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(part.copyWith(score: double.tryParse(v) ?? part.score ?? 0)),
        )),
        const SizedBox(width: 8),
        Expanded(flex: 14, child: TextField(
          enabled: hasResit, controller: resitC,
          decoration: InputDecoration(labelText: "Resit", hintText: hasResit ? "0..20" : "Disabled"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(part.copyWith(resitScore: double.tryParse(v))),
        )),
        const SizedBox(width: 8),
        IconButton(tooltip: "Remove", onPressed: onDelete,
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent)),
      ],
    );
  }
}

// ========================= Chat & Settings stubs in Part 2/3 =================
// ======================= Fachub (main.dart) — FULL (Part 2/3) =======================
// ChatScreen: unified UI over IDataStore (FirebaseStore | LocalStore)

import 'package:flutter/material.dart';

// ------------------------------ Chat Screen ----------------------------------

class ChatScreen extends StatefulWidget {
  final IDataStore store;
  final bool isOnline;
  const ChatScreen({super.key, required this.store, required this.isOnline});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatChannel? _current;
  bool _showOnlyDMs = false;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _switchChannel(ChatChannel c) {
    setState(() => _current = c);
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _current == null) return;
    await widget.store.sendMessage(_current!.id, text, sender: "Khaled");
    _composer.clear();
    // scroll to bottom (since reverse=false here)
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _createChannel() async {
    final res = await showDialog<ChatChannel>(
      context: context,
      builder: (_) => const _NewChannelDialog(),
    );
    if (res != null) {
      final created = await widget.store.createChannel(res.name, isDM: res.isDM);
      setState(() => _current = created);
    }
  }

  Future<void> _renameChannel() async {
    final c = _current;
    if (c == null) return;
    final ctrl = TextEditingController(text: c.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("إعادة تسمية القناة"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Channel name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );
    if (ok == true) {
      final newName = ctrl.text.trim();
      if (newName.isNotEmpty) {
        await widget.store.renameChannel(c.id, newName);
        setState(() => _current = ChatChannel(id: c.id, name: newName, isDM: c.isDM));
      }
    }
  }

  Future<void> _deleteChannel() async {
    final c = _current;
    if (c == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("حذف القناة؟"),
        content: Text("سيتم حذف \"${c.name}\" ورسائلها (حسب المزوّد)."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteChannel(c.id);
      setState(() => _current = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeaderBar(
          isOnline: widget.isOnline,
          current: _current,
          showOnlyDMs: _showOnlyDMs,
          onToggleDMs: (v) => setState(() => _showOnlyDMs = v),
          onNewChannel: _createChannel,
          onRename: _renameChannel,
          onDelete: _deleteChannel,
        ),
        // Channels row
        SizedBox(
          height: 56,
          child: StreamBuilder<List<ChatChannel>>(
            stream: widget.store.channels(),
            builder: (context, snap) {
              final all = snap.data ?? const <ChatChannel>[];
              final list = _showOnlyDMs ? all.where((c) => c.isDM).toList() : all;
              // pick default if none selected
              if (_current == null && list.isNotEmpty) {
                // delay setState to avoid build loop
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _current == null) setState(() => _current = list.first);
                });
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) {
                  final ch = list[i];
                  final selected = _current?.id == ch.id;
                  return ChoiceChip(
                    label: Text(ch.isDM ? "DM: ${ch.name}" : "# ${ch.name}"),
                    selected: selected,
                    onSelected: (_) => _switchChannel(ch),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: list.length,
              );
            },
          ),
        ),
        const Divider(height: 1),
        // Messages
        Expanded(
          child: _current == null
              ? const Center(child: Text("لا توجد قنوات. أنشئ قناة جديدة."))
              : StreamBuilder<List<ChatMessage>>(
                  stream: widget.store.messages(_current!.id),
                  builder: (context, snap) {
                    final msgs = (snap.data ?? const <ChatMessage>[]);
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _ChatBubble(msg: msgs[i]),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        // Composer
        _ComposerBar(
          controller: _composer,
          onAttach: () {
            // Placeholder attachment: add a tag in the text
            _composer.text = (_composer.text + ( _composer.text.isEmpty ? "" : " ")) + "[attachment]";
            _composer.selection = TextSelection.fromPosition(TextPosition(offset: _composer.text.length));
          },
          onSend: _send,
        ),
      ],
    );
  }
}

// ------------------------------ Chat Widgets ---------------------------------

class _ChatHeaderBar extends StatelessWidget {
  final bool isOnline;
  final ChatChannel? current;
  final bool showOnlyDMs;
  final ValueChanged<bool> onToggleDMs;
  final VoidCallback onNewChannel;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ChatHeaderBar({
    required this.isOnline,
    required this.current,
    required this.showOnlyDMs,
    required this.onToggleDMs,
    required this.onNewChannel,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isOnline ? "Online • Firebase" : "Offline • Local";
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Icon((current?.isDM ?? false) ? Icons.person : Icons.tag, color: kFachubBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(current == null ? "No channel" : ((current!.isDM ? "DM • " : "# ") + current!.name),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          FilterChip(label: const Text("DMs only"), selected: showOnlyDMs, onSelected: onToggleDMs),
          const SizedBox(width: 8),
          IconButton(tooltip: "Create channel", onPressed: onNewChannel, icon: const Icon(Icons.add_circle_outline)),
          IconButton(tooltip: "Rename channel", onPressed: onRename, icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: "Delete channel", onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  const _ComposerBar({required this.controller, required this.onSend, required this.onAttach});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(tooltip: "Attach (demo)", onPressed: onAttach, icon: const Icon(Icons.attach_file)),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1, maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Write a message…",
                  suffixIcon: IconButton(
                    onPressed: () {
                      controller.text = controller.text + " 😀";
                      controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                    },
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: onSend, child: const Text("Send")),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.sender == "Khaled";
    final bubbleColor = isMe ? kFachubBlue.withOpacity(.10) : Colors.grey.shade100;

    String timeLabel(DateTime d) {
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return "$hh:$mm";
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.sender, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(msg.text),
              const SizedBox(height: 4),
              Text(timeLabel(msg.time), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------- New Channel Dialog -------------------------------

class _NewChannelDialog extends StatefulWidget {
  const _NewChannelDialog();

  @override
  State<_NewChannelDialog> createState() => _NewChannelDialogState();
}

class _NewChannelDialogState extends State<_NewChannelDialog> {
  final TextEditingController name = TextEditingController();
  bool isDM = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("قناة جديدة"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: "Channel name", hintText: "e.g., promo-2CS"),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(value: isDM, activeColor: kFachubGreen, onChanged: (v) => setState(() => isDM = v)),
              const SizedBox(width: 8),
              const Text("Direct Message (DM)"),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "ملاحظة: عند الربط مع Firebase سيتم حفظ القناة والرسائل في السحابة.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            final nm = name.text.trim();
            if (nm.isEmpty) return;
            final id = (isDM ? "dm_" : "c_") + nm.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toLowerCase();
            Navigator.pop(context, ChatChannel(id: id, name: nm, isDM: isDM));
          },
          child: const Text("Create"),
        ),
      ],
    );
  }
}
// ======================= Fachub (main.dart) — FULL (Part 3/3) =======================
// Advanced Settings + Templates + JSON Export/Import (Clipboard)

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// ------------------------------ Templates ------------------------------------

TermData templateDZ_CS_S1() {
  return TermData(
    label: "S1 CS (DZ) 2025/2026",
    system: const TermSystem(passThreshold: 10.0, hasResit: true, roundTo: 2),
    subjects: [
      Subject(
        id: "cs_math",
        name: "Math Analysis",
        coeff: 4,
        eliminatory: false,
        parts: [
          SubjectPart(label: "TD",   weight: 0.3, score: 0),
          SubjectPart(label: "EXAM", weight: 0.7, score: 0),
        ],
      ),
      Subject(
        id: "cs_algo",
        name: "Algorithms",
        coeff: 3,
        eliminatory: true,
        eliminatoryThreshold: 7.0,
        parts: [
          SubjectPart(label: "TD",   weight: 0.4, score: 0),
          SubjectPart(label: "EXAM", weight: 0.6, score: 0),
        ],
      ),
      Subject(
        id: "cs_arch",
        name: "Computer Architecture",
        coeff: 2,
        eliminatory: false,
        parts: [
          SubjectPart(label: "TP",   weight: 0.4, score: 0),
          SubjectPart(label: "EXAM", weight: 0.6, score: 0),
        ],
      ),
      Subject(
        id: "cs_eng",
        name: "English",
        coeff: 1,
        eliminatory: false,
        parts: [
          SubjectPart(label: "CC",   weight: 0.4, score: 0),
          SubjectPart(label: "EXAM", weight: 0.6, score: 0),
        ],
      ),
    ],
  );
}

TermData templateEconomics_S1() {
  return TermData(
    label: "S1 Economics 2025/2026",
    system: const TermSystem(passThreshold: 10.0, hasResit: true, roundTo: 2),
    subjects: [
      Subject(
        id: "eco_micro",
        name: "Microeconomics",
        coeff: 3,
        eliminatory: false,
        parts: [
          SubjectPart(label: "TD",   weight: 0.3, score: 0),
          SubjectPart(label: "EXAM", weight: 0.7, score: 0),
        ],
      ),
      Subject(
        id: "eco_stat",
        name: "Statistics",
        coeff: 3,
        eliminatory: false,
        parts: [
          SubjectPart(label: "TD",   weight: 0.4, score: 0),
          SubjectPart(label: "EXAM", weight: 0.6, score: 0),
        ],
      ),
      Subject(
        id: "eco_acc",
        name: "Accounting",
        coeff: 2,
        eliminatory: false,
        parts: [
          SubjectPart(label: "TP",   weight: 0.5, score: 0),
          SubjectPart(label: "EXAM", weight: 0.5, score: 0),
        ],
      ),
      Subject(
        id: "eco_law",
        name: "Business Law",
        coeff: 2,
        eliminatory: false,
        parts: [
          SubjectPart(label: "CC",   weight: 0.4, score: 0),
          SubjectPart(label: "EXAM", weight: 0.6, score: 0),
        ],
      ),
    ],
  );
}

// --------------------------- Settings (Advanced) ------------------------------

class SettingsScreenPro extends StatefulWidget {
  final TermData term;
  final ValueChanged<TermData> onApplyTerm;

  const SettingsScreenPro({
    super.key,
    required this.term,
    required this.onApplyTerm,
  });

  @override
  State<SettingsScreenPro> createState() => _SettingsScreenProState();
}

class _SettingsScreenProState extends State<SettingsScreenPro> {
  late TermData _local;

  @override
  void initState() {
    super.initState();
    _local = widget.term.copy();
  }

  void _applySystemPreset(TermSystem sys) {
    setState(() => _local = _local..system = sys);
    widget.onApplyTerm(_local.copy());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("System preset applied")),
    );
  }

  void _applyTemplate(TermData t) {
    setState(() => _local = t.copy());
    widget.onApplyTerm(_local.copy());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Template applied: ${t.label}")),
    );
  }

  Future<void> _exportJSON() async {
    final map = encodeTerm(_local);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Export JSON"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(jsonStr)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(context);
            },
            child: const Text("Copy"),
          ),
        ],
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("JSON copied to clipboard")),
    );
  }

  Future<void> _importJSON() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Import JSON"),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(hintText: "Paste your JSON here…"),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Import")),
        ],
      ),
    );
    if (ok == true) {
      try {
        final map = json.decode(controller.text) as Map<String, dynamic>;
        final term = decodeTerm(map);
        _applyTemplate(term);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invalid JSON: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = termAverage(_local);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("System Presets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _PresetButton(
                      label: "DZ Default",
                      onTap: () => _applySystemPreset(_local.system.copyWith(passThreshold: 10.0, hasResit: true, roundTo: 2)),
                    ),
                    _PresetButton(
                      label: "Strict 12",
                      onTap: () => _applySystemPreset(_local.system.copyWith(passThreshold: 12.0, hasResit: false, roundTo: 2)),
                    ),
                    _PresetButton(
                      label: "Rounded 1dp",
                      onTap: () => _applySystemPreset(_local.system.copyWith(roundTo: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: kFachubBlue),
                    const SizedBox(width: 8),
                    Text("Current Avg: ${avg.toStringAsFixed(_local.system.roundTo)}"),
                    const Spacer(),
                    const Icon(Icons.check_circle, color: kFachubGreen),
                    const SizedBox(width: 6),
                    Text("Pass ≥ ${_local.system.passThreshold.toStringAsFixed(1)}"),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Templates", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _PresetButton(label: "CS (DZ) S1", onTap: () => _applyTemplate(templateDZ_CS_S1())),
                    _PresetButton(label: "Economics S1", onTap: () => _applyTemplate(templateEconomics_S1())),
                    _PresetButton(label: "Reset Sample", onTap: () => _applyTemplate(sampleTerm())),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "اختر قالب كبداية حسب تخصصك، ويمكنك تعديل المواد والمعاملات من شاشة الحاسبة.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Backup / Restore", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportJSON,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text("Export JSON"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _importJSON,
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text("Import JSON"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "التصدير/الاستيراد يتم عبر النسخ واللصق (Clipboard). لاحقًا نضيف تخزين ملفات أو سحابة.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text("About Fachub"),
            subtitle: const Text("حساب المعدّل + شات الطلاب • نسخة Firebase-ready"),
            trailing: const Icon(Icons.info_outline),
          ),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}
