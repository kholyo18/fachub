// ======================= Fachub (main.dart) — FULL with Offline→Online Sync (Part 1/3) =======================

// ------------------------------- IMPORTS -------------------------------------
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase (يشتغل فقط إذا فعلت flutterfire ووجد firebase_options.dart)
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ------------------------------- CONSTS --------------------------------------
const kFachubGreen = Color(0xFF16A34A);
const kFachubBlue  = Color(0xFF2563EB);

// ------------------------------- ENTRY ---------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseOK = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseOK = true;
  } catch (_) {
    firebaseOK = false; // يشتغل Offline تلقائياً
  }
  runApp(FachubApp(isOnline: firebaseOK));
}

class FachubApp extends StatelessWidget {
  final bool isOnline;
  const FachubApp({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(seedColor: kFachubBlue, brightness: Brightness.light);
    return MaterialApp(
      title: 'Fachub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: base,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.2,
        ),
      ),
      home: HomeShell(isOnline: isOnline),
    );
  }
}

// ----------------------------- DATA MODELS -----------------------------------
class TermSystem {
  final double passThreshold;
  final bool hasResit;
  final int roundTo;
  const TermSystem({required this.passThreshold, required this.hasResit, required this.roundTo});

  TermSystem copyWith({double? passThreshold, bool? hasResit, int? roundTo}) => TermSystem(
    passThreshold: passThreshold ?? this.passThreshold,
    hasResit: hasResit ?? this.hasResit,
    roundTo: roundTo ?? this.roundTo,
  );
}

class SubjectPart {
  String label;
  double weight; // 0..1
  double score;  // 0..20
  SubjectPart({required this.label, required this.weight, required this.score});

  Map<String, dynamic> toMap() => {'label': label, 'weight': weight, 'score': score};
  factory SubjectPart.fromMap(Map<String, dynamic> m) => SubjectPart(
    label: m['label'] ?? '',
    weight: (m['weight'] ?? 0).toDouble(),
    score: (m['score'] ?? 0).toDouble(),
  );
}

class Subject {
  String id;
  String name;
  int coeff;
  bool eliminatory;
  double eliminatoryThreshold;
  List<SubjectPart> parts;

  Subject({
    required this.id,
    required this.name,
    required this.coeff,
    required this.eliminatory,
    this.eliminatoryThreshold = 0.0,
    required this.parts,
  });

  double average() {
    double s = 0;
    for (final p in parts) {
      s += p.weight * p.score;
    }
    return s;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'coeff': coeff,
    'eliminatory': eliminatory,
    'eliminatoryThreshold': eliminatoryThreshold,
    'parts': parts.map((e) => e.toMap()).toList(),
  };

  factory Subject.fromMap(Map<String, dynamic> m) => Subject(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    coeff: (m['coeff'] ?? 0).toInt(),
    eliminatory: (m['eliminatory'] ?? false) as bool,
    eliminatoryThreshold: (m['eliminatoryThreshold'] ?? 0).toDouble(),
    parts: (m['parts'] as List? ?? const []).map((e) => SubjectPart.fromMap(Map<String, dynamic>.from(e))).toList(),
  );
}

class TermData {
  String label;
  TermSystem system;
  List<Subject> subjects;

  TermData({required this.label, required this.system, required this.subjects});

  TermData copy() => TermData(
    label: label,
    system: TermSystem(passThreshold: system.passThreshold, hasResit: system.hasResit, roundTo: system.roundTo),
    subjects: subjects.map((s) => Subject(
      id: s.id,
      name: s.name,
      coeff: s.coeff,
      eliminatory: s.eliminatory,
      eliminatoryThreshold: s.eliminatoryThreshold,
      parts: s.parts.map((p) => SubjectPart(label: p.label, weight: p.weight, score: p.score)).toList(),
    )).toList(),
  );
}

// ترميز/فك JSON للحفظ/التبادل
Map<String, dynamic> encodeTerm(TermData t) => {
  'label': t.label,
  'system': {'passThreshold': t.system.passThreshold, 'hasResit': t.system.hasResit, 'roundTo': t.system.roundTo},
  'subjects': t.subjects.map((s) => s.toMap()).toList(),
};

TermData decodeTerm(Map<String, dynamic> m) => TermData(
  label: m['label'] ?? 'Term',
  system: TermSystem(
    passThreshold: (m['system']?['passThreshold'] ?? 10).toDouble(),
    hasResit: (m['system']?['hasResit'] ?? true) as bool,
    roundTo: (m['system']?['roundTo'] ?? 2).toInt(),
  ),
  subjects: (m['subjects'] as List? ?? const []).map((e) => Subject.fromMap(Map<String, dynamic>.from(e))).toList(),
);

// ----------------------------- GPA FUNCTIONS ---------------------------------
double subjectWeighted(Subject s) => s.average() * s.coeff;

double termAverage(TermData t) {
  // شرط الإقصاء
  for (final s in t.subjects) {
    if (s.eliminatory && s.average() < s.eliminatoryThreshold) {
      return 0.0;
    }
  }
  final coeffSum = t.subjects.fold<int>(0, (a, b) => a + b.coeff);
  if (coeffSum == 0) return 0.0;
  final sum = t.subjects.fold<double>(0, (a, b) => a + subjectWeighted(b));
  final avg = sum / coeffSum;
  final factor = math.pow(10, t.system.roundTo).toDouble();
  return (avg * factor).round() / factor;
}

// ------------------------------ SAMPLE TERM ----------------------------------
TermData sampleTerm() => TermData(
  label: "Sample S1",
  system: const TermSystem(passThreshold: 10.0, hasResit: true, roundTo: 2),
  subjects: [
    Subject(
      id: "math",
      name: "Mathematics",
      coeff: 4,
      eliminatory: true,
      eliminatoryThreshold: 7.0,
      parts: [
        SubjectPart(label: "TD", weight: 0.3, score: 0),
        SubjectPart(label: "EXAM", weight: 0.7, score: 0),
      ],
    ),
    Subject(
      id: "cs",
      name: "Computer Science",
      coeff: 3,
      eliminatory: false,
      parts: [
        SubjectPart(label: "TP", weight: 0.4, score: 0),
        SubjectPart(label: "EXAM", weight: 0.6, score: 0),
      ],
    ),
    Subject(
      id: "eng",
      name: "English",
      coeff: 1,
      eliminatory: false,
      parts: [
        SubjectPart(label: "CC", weight: 0.4, score: 0),
        SubjectPart(label: "EXAM", weight: 0.6, score: 0),
      ],
    ),
  ],
);

// ------------------------------ STORAGE LAYER --------------------------------
abstract class IDataStore {
  // chat
  Stream<List<ChatChannel>> channels();
  Future<ChatChannel> createChannel(String name, {bool isDM = false});
  Future<void> renameChannel(String id, String newName);
  Future<void> deleteChannel(String id);
  Stream<List<ChatMessage>> messages(String channelId);
  Future<void> sendMessage(String channelId, String text, {required String sender});

  // term
  Future<void> saveTerm(TermData t);
  Future<TermData> loadTerm();
}

// ------------------------------ CHAT MODELS ----------------------------------
class ChatChannel {
  final String id;
  final String name;
  final bool isDM;
  const ChatChannel({required this.id, required this.name, required this.isDM});
  ChatChannel copy() => ChatChannel(id: id, name: name, isDM: isDM);
}

class ChatMessage {
  final String id;
  final String channelId;
  final String sender;
  final String text;
  final DateTime time;
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.sender,
    required this.text,
    required this.time,
  });
}

// ------------------------------ PENDING QUEUE ---------------------------------
// تخزين الرسائل غير المرسلة محلياً حتى تتوفر الشبكة ثم نرفعها لـ Firebase
class PendingMessage {
  final String channelId;
  final String sender;
  final String text;
  final DateTime time;

  PendingMessage({
    required this.channelId,
    required this.sender,
    required this.text,
    required this.time,
  });

  Map<String, dynamic> toMap() => {
        'channelId': channelId,
        'sender': sender,
        'text': text,
        'time': time.toIso8601String(),
      };

  factory PendingMessage.fromMap(Map<String, dynamic> m) => PendingMessage(
        channelId: (m['channelId'] ?? '') as String,
        sender: (m['sender'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        time: DateTime.tryParse((m['time'] ?? '') as String) ?? DateTime.now(),
      );
}

class PendingQueue {
  static const _key = 'fachub_pending_msgs_v1';

  // أضف رسالة إلى قائمة الانتظار
  static Future<void> push(PendingMessage msg) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List list = raw == null ? [] : (json.decode(raw) as List);
    list.add(msg.toMap());
    await prefs.setString(_key, json.encode(list));
  }

  // استرجاع كل الرسائل المعلقة
  static Future<List<PendingMessage>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final List list = json.decode(raw) as List;
      return list.map((e) => PendingMessage.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  // تفريغ (بعد الرفع)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // عدد الرسائل المعلقة (اختياري للواجهة)
  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return 0;
    try {
      final List list = json.decode(raw) as List;
      return list.length;
    } catch (_) {
      return 0;
    }
  }
}

// ------------------------------ LOCAL STORE ----------------------------------
class LocalStore implements IDataStore {
  final _chs = <ChatChannel>[
    const ChatChannel(id: "general", name: "General", isDM: false),
    const ChatChannel(id: "dm_alice", name: "Alice", isDM: true),
  ];
  final Map<String, List<ChatMessage>> _msgs = {
    "general": [
      ChatMessage(id: "m1", channelId: "general", sender: "System", text: "مرحبًا بك في Fachub (Offline).", time: DateTime.now()),
    ]
  };

  // term local (SharedPreferences)
  static const _prefsKey = "fachub_term_v1";

  @override
  Stream<List<ChatChannel>> channels() async* {
    yield _chs.map((c) => c).toList().cast<ChatChannel>();
  }

  @override
  Future<ChatChannel> createChannel(String name, {bool isDM = false}) async {
    final id = (isDM ? "dm_" : "c_") + name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toLowerCase();
    final c = ChatChannel(id: id, name: name, isDM: isDM);
    _chs.add(c);
    _msgs.putIfAbsent(id, () => []);
    return c;
  }

  @override
  Future<void> renameChannel(String id, String newName) async {
    final i = _chs.indexWhere((e) => e.id == id);
    if (i >= 0) _chs[i] = ChatChannel(id: _chs[i].id, name: newName, isDM: _chs[i].isDM);
  }

  @override
  Future<void> deleteChannel(String id) async {
    _chs.removeWhere((e) => e.id == id);
    _msgs.remove(id);
  }

  @override
  Stream<List<ChatMessage>> messages(String channelId) async* {
    yield _msgs[channelId]?.toList() ?? const <ChatMessage>[];
  }

  // ✅ تعديل: إضافة الرسالة للواجهة + تخزين نسخة معلّقة لرفعها عند الاتصال
  @override
  Future<void> sendMessage(String channelId, String text, {required String sender}) async {
    final list = _msgs.putIfAbsent(channelId, () => []);
    final now = DateTime.now();
    final msg = ChatMessage(
      id: now.millisecondsSinceEpoch.toString(),
      channelId: channelId,
      sender: sender,
      text: text,
      time: now,
    );
    list.add(msg);

    // خزّن نسخة معلّقة لرفعها لاحقاً إلى Firebase
    await PendingQueue.push(PendingMessage(
      channelId: channelId,
      sender: sender,
      text: text,
      time: now,
    ));
  }

  @override
  Future<void> saveTerm(TermData t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(encodeTerm(t)));
  }

  @override
  Future<TermData> loadTerm() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return sampleTerm();
    try {
      return decodeTerm(jsonDecode(raw));
    } catch (_) {
      return sampleTerm();
    }
  }
}

// ------------------------------ FIREBASE STORE -------------------------------
class FirebaseStore implements IDataStore {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  Stream<List<ChatChannel>> channels() {
    return db.collection('channels').orderBy('name').snapshots().map((snap) {
      return snap.docs.map((d) {
        final m = d.data();
        return ChatChannel(id: d.id, name: (m['name'] ?? d.id).toString(), isDM: (m['isDM'] ?? false) as bool);
      }).toList();
    });
  }

  @override
  Future<ChatChannel> createChannel(String name, {bool isDM = false}) async {
    final doc = await db.collection('channels').add({
      'name': name,
      'isDM': isDM,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ChatChannel(id: doc.id, name: name, isDM: isDM);
  }

  @override
  Future<void> renameChannel(String id, String newName) async {
    await db.collection('channels').doc(id).update({'name': newName});
  }

  @override
  Future<void> deleteChannel(String id) async {
    await db.collection('channels').doc(id).delete();
  }

  @override
  Stream<List<ChatMessage>> messages(String channelId) {
    return db.collection('messages')
      .where('channelId', isEqualTo: channelId)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final m = d.data();
            return ChatMessage(
              id: d.id,
              channelId: (m['channelId'] ?? '') as String,
              sender: (m['sender'] ?? 'Unknown') as String,
              text: (m['text'] ?? '') as String,
              time: (m['createdAt'] is Timestamp)
                  ? (m['createdAt'] as Timestamp).toDate()
                  : DateTime.now(),
            );
          }).toList());
  }

  @override
  Future<void> sendMessage(String channelId, String text, {required String sender}) async {
    await db.collection('messages').add({
      'channelId': channelId,
      'sender': sender,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveTerm(TermData t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LocalStore._prefsKey, jsonEncode(encodeTerm(t)));
  }

  @override
  Future<TermData> loadTerm() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LocalStore._prefsKey);
    if (raw == null) return sampleTerm();
    try {
      return decodeTerm(jsonDecode(raw));
    } catch (_) {
      return sampleTerm();
    }
  }
}
// ======================= Fachub (main.dart) — FULL with Offline→Online Sync (Part 2/3) =======================

// ------------------------------ SYNC MANAGER ----------------------------------
// يقرأ الرسائل المعلقة من SharedPreferences ويرفعها لـ Firestore عند الاتصال
class SyncManager {
  final FirebaseStore firebase;

  SyncManager({required this.firebase});

  Future<int> flushPending() async {
    final pending = await PendingQueue.all();
    if (pending.isEmpty) return 0;

    for (final p in pending) {
      await firebase.sendMessage(p.channelId, p.text, sender: p.sender);
      // وقت الرسالة في Firestore سيكون serverTimestamp (مناسب للترتيب)
    }
    await PendingQueue.clear();
    return pending.length;
  }
}

// ------------------------------ HOME SHELL -----------------------------------
class HomeShell extends StatefulWidget {
  final bool isOnline;
  const HomeShell({super.key, required this.isOnline});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final IDataStore store;
  int _tab = 0;
  TermData _term = sampleTerm();

  @override
  void initState() {
    super.initState();
    store = widget.isOnline ? FirebaseStore() : LocalStore();
    _loadTerm();

    // ➜ لو Online حالياً، اعمل مزامنة للرسائل المعلقة
    if (widget.isOnline && store is FirebaseStore) {
      final sync = SyncManager(firebase: store as FirebaseStore);
      sync.flushPending().then((n) {
        if (n > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تمت مزامنة $n رسالة معلّقة إلى السحابة")),
          );
        }
      });
    }
  }

  Future<void> _loadTerm() async {
    _term = await store.loadTerm();
    if (mounted) setState(() {});
  }

  void _setTerm(TermData t) {
    setState(() => _term = t);
    store.saveTerm(t);
  }

  @override
  Widget build(BuildContext context) {
    final title = ["الحاسبة", "الشات", "الإعدادات"][_tab];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _BrandMark(size: 22),
            const SizedBox(width: 8),
            Text("Fachub • $title"),
          ],
        ),
      ),
      body: [
        GPAScreen(term: _term, onUpdate: _setTerm),
        ChatScreen(store: store, isOnline: widget.isOnline),
        SettingsScreenPro(term: _term, onApplyTerm: _setTerm),
      ][_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate_outlined), label: "حاسبة"),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: "شات"),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: "إعدادات"),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kFachubGreen, kFachubBlue]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.school, size: 16, color: Colors.white),
    );
  }
}

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

    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 240),
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
          decoration: const InputDecoration(labelText: "اسم القناة"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("حفظ")),
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
        content: Text("سيتم حذف \"${c.name}\" (والرسائل حسب المزوِّد)."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف"),
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
        // قنوات الشات
        SizedBox(
          height: 56,
          child: StreamBuilder<List<ChatChannel>>(
            stream: widget.store.channels(),
            builder: (context, snap) {
              final all = snap.data ?? const <ChatChannel>[];
              final list = _showOnlyDMs ? all.where((c) => c.isDM).toList() : all;

              if (_current == null && list.isNotEmpty) {
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
        // الرسائل
        Expanded(
          child: _current == null
              ? const Center(child: Text("لا توجد قنوات حالياً. أنشئ قناة جديدة."))
              : StreamBuilder<List<ChatMessage>>(
                  stream: widget.store.messages(_current!.id),
                  builder: (context, snap) {
                    final msgs = snap.data ?? const <ChatMessage>[];
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
        // محرّر الإرسال
        _ComposerBar(
          controller: _composer,
          onAttach: () {
            _composer.text = (_composer.text + (_composer.text.isEmpty ? "" : " ")) + "[attachment]";
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
                Text(
                  current == null ? "لا قناة" : ((current!.isDM ? "DM • " : "# ") + current!.name),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          FilterChip(label: const Text("DMs فقط"), selected: showOnlyDMs, onSelected: onToggleDMs),
          const SizedBox(width: 8),
          IconButton(tooltip: "قناة جديدة", onPressed: onNewChannel, icon: const Icon(Icons.add_circle_outline)),
          IconButton(tooltip: "إعادة تسمية", onPressed: onRename, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            tooltip: "حذف القناة",
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
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
            IconButton(tooltip: "إرفاق (تجريبي)", onPressed: onAttach, icon: const Icon(Icons.attach_file)),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "اكتب رسالة…",
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
            ElevatedButton(onPressed: onSend, child: const Text("إرسال")),
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
            decoration: const InputDecoration(labelText: "اسم القناة", hintText: "مثال: promo-2CS"),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: () {
            final nm = name.text.trim();
            if (nm.isEmpty) return;
            final id = (isDM ? "dm_" : "c_") + nm.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toLowerCase();
            Navigator.pop(context, ChatChannel(id: id, name: nm, isDM: isDM));
          },
          child: const Text("إنشاء"),
        ),
      ],
    );
  }
}
// ======================= Fachub (main.dart) — FULL with Offline→Online Sync (Part 3/3) =======================

// ------------------------------ GPA SCREEN -----------------------------------
class GPAScreen extends StatefulWidget {
  final TermData term;
  final ValueChanged<TermData> onUpdate;
  const GPAScreen({super.key, required this.term, required this.onUpdate});

  @override
  State<GPAScreen> createState() => _GPAScreenState();
}

class _GPAScreenState extends State<GPAScreen> {
  late TermData _term;

  @override
  void initState() {
    super.initState();
    _term = widget.term.copy();
  }

  void _updateSubject(Subject s, int partIndex, double newScore) {
    setState(() {
      s.parts[partIndex].score = newScore;
    });
    widget.onUpdate(_term.copy());
  }

  @override
  Widget build(BuildContext context) {
    final avg = termAverage(_term);
    final passed = avg >= _term.system.passThreshold;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          elevation: 0.2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined, color: kFachubBlue),
                    const SizedBox(width: 8),
                    Text(_term.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      "${avg.toStringAsFixed(_term.system.roundTo)} / 20",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: passed ? kFachubGreen : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._term.subjects.map((s) => _SubjectCard(s: s, onPartEdit: _updateSubject)).toList(),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject s;
  final void Function(Subject s, int partIndex, double newScore) onPartEdit;
  const _SubjectCard({required this.s, required this.onPartEdit});

  @override
  Widget build(BuildContext context) {
    final avg = s.average();
    final color = avg >= (s.eliminatory ? s.eliminatoryThreshold : 0)
        ? kFachubBlue
        : Colors.redAccent;
    return Card(
      elevation: 0.2,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("Coef ${s.coeff}"),
                const SizedBox(width: 12),
                Text(avg.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Column(
              children: List.generate(s.parts.length, (i) {
                final p = s.parts[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.label)),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: p.score.toStringAsFixed(1),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (v) {
                            final val = double.tryParse(v) ?? p.score;
                            onPartEdit(s, i, val.clamp(0, 20));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("x${(p.weight * 100).toInt()}%"),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------- SETTINGS & PRESETS ------------------------------
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
      const SnackBar(content: Text("تم تطبيق إعدادات النظام")),
    );
  }

  void _applyTemplate(TermData t) {
    setState(() => _local = t.copy());
    widget.onApplyTerm(_local.copy());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم تطبيق القالب: ${t.label}")),
    );
  }

  Future<void> _exportJSON() async {
    final map = encodeTerm(_local);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم نسخ JSON إلى الحافظة")),
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
            decoration: const InputDecoration(hintText: "ألصق JSON هنا…"),
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
          SnackBar(content: Text("JSON غير صالح: $e")),
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
                  spacing: 8,
                  runSpacing: 8,
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
                    Text("المتوسط الحالي: ${avg.toStringAsFixed(_local.system.roundTo)}"),
                    const Spacer(),
                    const Icon(Icons.check_circle, color: kFachubGreen),
                    const SizedBox(width: 6),
                    Text("النجاح ≥ ${_local.system.passThreshold.toStringAsFixed(1)}"),
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
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetButton(label: "CS (DZ) S1", onTap: () => _applyTemplate(templateDZ_CS_S1())),
                    _PresetButton(label: "Economics S1", onTap: () => _applyTemplate(templateEconomics_S1())),
                    _PresetButton(label: "Reset Sample", onTap: () => _applyTemplate(sampleTerm())),
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
                const Text("Backup / Restore", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap( // ✅ لتفادي overflow
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportJSON,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text("Export JSON"),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importJSON,
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text("Import JSON"),
                    ),
                  ],
                ),
              ],
            ),
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

// ------------------------------ TEMPLATES ------------------------------------
TermData templateDZ_CS_S1() => TermData(
  label: "S1 CS (DZ)",
  system: const TermSystem(passThreshold: 10, hasResit: true, roundTo: 2),
  subjects: [
    Subject(id: "math", name: "Math", coeff: 4, eliminatory: true, eliminatoryThreshold: 7, parts: [
      SubjectPart(label: "TD", weight: 0.3, score: 0),
      SubjectPart(label: "EXAM", weight: 0.7, score: 0),
    ]),
    Subject(id: "algo", name: "Algorithms", coeff: 3, eliminatory: true, eliminatoryThreshold: 7, parts: [
      SubjectPart(label: "TP", weight: 0.4, score: 0),
      SubjectPart(label: "EXAM", weight: 0.6, score: 0),
    ]),
  ],
);

TermData templateEconomics_S1() => TermData(
  label: "S1 Economics",
  system: const TermSystem(passThreshold: 10, hasResit: true, roundTo: 2),
  subjects: [
    Subject(id: "eco", name: "Microeconomics", coeff: 3, eliminatory: false, parts: [
      SubjectPart(label: "TD", weight: 0.4, score: 0),
      SubjectPart(label: "EXAM", weight: 0.6, score: 0),
    ]),
    Subject(id: "stat", name: "Statistics", coeff: 3, eliminatory: false, parts: [
      SubjectPart(label: "TD", weight: 0.5, score: 0),
      SubjectPart(label: "EXAM", weight: 0.5, score: 0),
    ]),
  ],
);
