// main.dart � ArogyaChain AI
//
// Product shell with four views:
//   Command Center  district-wide risk + approval queue (District Health Officer)
//   Facility        voice capture + medicine table (PHC pharmacist)
//   Transfers       bulk approval workflow + execution log
//   Evidence        model validation + disclosed limits
//
// Live mode uses Firebase RTDB; demo mode uses MockData with the identical
// read/write contract, so the recorded demo never depends on network or billing.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'models.dart';
import 'shell.dart';
import 'theme.dart';
import 'views/command_center.dart';
import 'views/evidence_view.dart';
import 'views/facility_view.dart';
import 'views/transfers_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArogyaChainApp());
}

class ArogyaChainApp extends StatelessWidget {
  const ArogyaChainApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ArogyaChain AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Workspace(),
      );
}
// Backend abstraction: live RTDB or mock (demo mode)
// ---------------------------------------------------------------------------

class RiskEntry {
  final double risk;
  final double daysOfCover;
  final int forecast7d;
  final String source;
  final int updatedAtMs;
  RiskEntry({
    required this.risk,
    required this.daysOfCover,
    required this.forecast7d,
    required this.source,
    required this.updatedAtMs,
  });

  static RiskEntry? fromMap(Object? v) {
    if (v is! Map) return null;
    final r = (v['risk'] as num?)?.toDouble();
    if (r == null) return null;
    return RiskEntry(
      risk: r,
      daysOfCover: (v['daysOfCover'] as num?)?.toDouble() ?? 0,
      forecast7d: (v['forecast7d'] as num?)?.toInt() ?? 0,
      source: (v['forecastSource'] as String?) ?? 'local-ensemble',
      updatedAtMs: (v['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockBackend {
  bool get isDemo => _demo;
  final bool _demo;
  StockBackend({required bool demo}) : _demo = demo;

  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Public accessor: FacilityView needs the SpeechToText instance to call
  /// listen(). Kept private to the backend so callers cannot swap it out.
  stt.SpeechToText get speech => _speech;

  // live mode streams
  Stream<DatabaseEvent>? _invStream;
  Stream<DatabaseEvent>? _riskStream;
  DatabaseReference? _db;

  Future<bool> initSpeech() => _speech.initialize();

  Future<bool> checkFirebase() async {
    if (_demo) return false;
    try {
      await Firebase.initializeApp();
      _db = FirebaseDatabase.instance.ref();
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<DatabaseEvent>? inventoryEvents() {
    if (_demo || _db == null) return null;
    _invStream ??= _db!.child('inventory').onValue;
    return _invStream;
  }

  Stream<DatabaseEvent>? riskEvents() {
    if (_demo || _db == null) return null;
    _riskStream ??= _db!.child('riskScores').onValue;
    return _riskStream;
  }

  /// Write a transaction (live mode). Offline: queued by RTDB persistence.
  Future<void> pushTransaction(String phcId, Map<String, Object?> tx) async {
    if (_demo || _db == null) return;
    await _db!.child('transactions').child(phcId).push().set(tx);
  }

  Future<void> executeTransfer(String recId) async {
    if (_demo || _db == null) return;
    final uri = Uri.parse(
        'https://us-central1-arogyachain-ai.cloudfunctions.net/executeTransfer');
    await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'recommendationId': recId}));
  }

  Future<Map<String, dynamic>?> parseVoiceRemote(String text, String phc) async {
    if (_demo || _db == null) return null;
    final uri = Uri.parse(
        'https://us-central1-arogyachain-ai.cloudfunctions.net/parseVoiceCommand');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'phcId': phc, 'lang': 'ta'}));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ---------------------------------------------------------------------------
// Local regex fallback parser (mirrors functions/lib/voiceParser.js)
// ---------------------------------------------------------------------------

const Map<String, List<String>> kSynonyms = {
  'Paracetamol_500mg': ['paracetamol', 'dolo', 'crocin', 'பாராசிட்டமால்', 'पैरासिटामोल'],
  'Amoxicillin_500mg': ['amoxicillin', 'amox', 'அமாக்சிசிலின்', 'एमोक्सिसिलिन'],
  'ORS_Low-Osmolarity': ['ors', 'electral', 'ஓஆர்எஸ்', 'ओआरएस'],
  'Metformin_500mg': ['metformin', 'மெட்ஃபார்மின்', 'मेटफॉर्मिन'],
  'Amlodipine_5mg': ['amlodipine', 'amlo', 'அம்லோடிபின்', 'अम्लोडिपिन'],
  'Salbutamol_100mcg': ['salbutamol', 'asthalin', 'inhaler', 'साल्बुटामोल'],
  'Cetirizine_10mg': ['cetirizine', 'செட்டிரிசின்', 'सेट्रिजिन'],
  'Diclofenac_50mg': ['diclofenac', 'voveran', 'டைக்ளோஃபினாக்', 'डाइक्लोफेनाक'],
  'Ondansetron_4mg': ['ondansetron', 'emeset', 'ஒண்டான்செட்ரான்', 'ओन्डानसेट्रोन'],
  'Ferrous-Sulphate_60mg': ['ferrous', 'iron', 'இரும்பு', 'आयरन'],
};

const Map<String, int> kWordNumbers = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
  'eight': 8, 'nine': 9, 'ten': 10, 'twenty': 20, 'thirty': 30, 'forty': 40,
  'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  'hundred': 100,
  'onru': 1, 'rendu': 2, 'moonu': 3, 'naalu': 4, 'anju': 5, 'aaru': 6,
  'ezhu': 7, 'ettu': 8, 'onbadu': 9, 'pathu': 10, 'irupathu': 20,
  'muppathu': 30, 'naarpattu': 40, 'aimpattu': 50, 'arupattu': 60,
  'ezhupattu': 70, 'enbathu': 80, 'nooru': 100,
  'ஒன்று': 1, 'இரண்டு': 2, 'ஐந்து': 5, 'பத்து': 10, 'இருபது': 20,
  'ஐம்பது': 50, 'நூறு': 100,
  'ek': 1, 'do': 2, 'teen': 3, 'chaar': 4, 'paanch': 5, 'panch': 5, 'chah': 6,
  'saat': 7, 'aath': 8, 'nau': 9, 'das': 10, 'bees': 20, 'tees': 30,
  'chalis': 40, 'pachaas': 50, 'saath': 70, 'assi': 80, 'nabbe': 100,
  'पचास': 50, 'दस': 10, 'बीस': 20, 'सौ': 100,
};

class ParsedCommand {
  final String? medicineKey;
  final int? quantity;
  final String? error;
  ParsedCommand({this.medicineKey, this.quantity, this.error});
}

ParsedCommand parseLocal(String text) {
  final lower = text.toLowerCase();
  String? medKey;
  int bestLen = 0;
  kSynonyms.forEach((key, syns) {
    for (final s in syns) {
      if (lower.contains(s) && s.length > bestLen) {
        medKey = key;
        bestLen = s.length;
      }
    }
  });
  if (medKey == null) {
    return ParsedCommand(error: 'Medicine not recognized. Try "Paracetamol 50".');
  }
  int? qty;
  final digits = RegExp(r'\d+').firstMatch(text);
  if (digits != null) {
    qty = int.tryParse(digits.group(0)!);
  } else {
    for (final w in lower.split(RegExp(r'[\s,]+'))) {
      final v = kWordNumbers[w];
      if (v != null && (qty == null || v > qty)) qty = v;
    }
  }
  if (qty == null) {
    return ParsedCommand(error: 'Quantity not found. Say a number, e.g. "Paracetamol fifty".');
  }
  return ParsedCommand(medicineKey: medKey, quantity: qty);
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Workspace: owns state, routes views
// ---------------------------------------------------------------------------

class Workspace extends StatefulWidget {
  const Workspace({super.key});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  late StockBackend backend;
  bool demoMode = true;
  bool ready = false;
  String phcId = 'PHC-001';
  // Land on Facility: that is the pharmacist's screen and the demo story
  // (voice -> risk spike -> transfer) starts there.
  AppView view = AppView.facility;

  Map<String, Map<String, dynamic>> inventory = {};
  Map<String, Map<String, dynamic>> riskScores = {};
  StreamSubscription? invSub;
  StreamSubscription? riskSub;

  final List<String> approved = [];
  String lastStatus = '';

  @override
  void initState() {
    super.initState();
    // Default to demo so the video never blocks on billing. Attempt live with:
    //   flutter run -d chrome --dart-define=DEMO=false
    const forceDemo = bool.fromEnvironment('DEMO', defaultValue: true);
    backend = StockBackend(demo: forceDemo);
    _boot();
  }

  Future<void> _boot() async {
    final live = await backend.checkFirebase();
    if (!mounted) return;
    setState(() {
      demoMode = !live;
      ready = true;
    });
    if (live) {
      invSub = backend.inventoryEvents()?.listen(_onInventory);
      riskSub = backend.riskEvents()?.listen(_onRisk);
    }
  }

  void _onInventory(DatabaseEvent ev) {
    final v = ev.snapshot.value;
    if (v is! Map) return;
    setState(() => inventory = _decode(v));
  }

  void _onRisk(DatabaseEvent ev) {
    final v = ev.snapshot.value;
    if (v is! Map) return;
    setState(() => riskScores = _decode(v));
  }

  Map<String, Map<String, dynamic>> _decode(Map v) => v.map(
        (k, val) => MapEntry(k as String, (val as Map).cast<String, dynamic>()),
      );

  @override
  void dispose() {
    invSub?.cancel();
    riskSub?.cancel();
    super.dispose();
  }

  List<Recommendation> get _recs => MockData.instance.computeRecommendations();

  int get _critical {
    var n = 0;
    for (final r in MockData.instance.allRows()) {
      if ((r.med.risk?.risk ?? 0) >= 80) n++;
    }
    return n;
  }

  int get _watch {
    var n = 0;
    for (final r in MockData.instance.allRows()) {
      final v = r.med.risk?.risk ?? 0;
      if (v >= 30 && v < 80) n++;
    }
    return n;
  }

  Future<void> _handle(String text) async {
    setState(() => lastStatus = 'Heard: "$text"');

    // 1) Gemini-backed Cloud Function (live mode only)
    Map<String, dynamic>? remote;
    try {
      remote = await backend.parseVoiceRemote(text, phcId).timeout(
            const Duration(seconds: 6),
            onTimeout: () => null,
          );
    } catch (_) {}
    String? medKey;
    int? qty;
    if (remote != null && remote['ok'] == true) {
      medKey = remote['medicineKey'] as String?;
      qty = (remote['quantity'] as num?)?.toInt();
    }
    // 2) local regex fallback (mirrors functions/lib/voiceParser.js)
    if (medKey == null || qty == null) {
      final p = parseLocal(text);
      if (p.medicineKey != null && p.quantity != null) {
        medKey = p.medicineKey;
        qty = p.quantity;
      }
    }
    if (medKey == null || qty == null) {
      _toast('Could not parse. Use manual entry below.');
      return;
    }

    if (demoMode) {
      MockData.instance.applyDispense(phcId, medKey, qty);
      setState(() => lastStatus =
          '$phcId: -$qty ${Medicine.prettyKey(medKey!)} � demo sync ?');
    } else {
      await backend.pushTransaction(phcId, {
        'medicine': medKey,
        'type': 'dispense',
        'quantity': qty,
        'timestamp': ServerValue.timestamp,
      });
      setState(() => lastStatus =
          '$phcId: -$qty ${Medicine.prettyKey(medKey!)} ? queued to Firebase ?');
    }
  }

  void _approve(Recommendation rec) {
    if (demoMode) {
      MockData.instance.applyDispense(rec.fromPhc, rec.medicine, rec.quantity);
      MockData.instance.applyDispense(rec.toPhc, rec.medicine, -rec.quantity);
    } else {
      backend.executeTransfer(rec.id);
    }
    setState(() => approved.add(rec.id));
    _toast('Transfer approved ?');
  }

  void _approveMany(List<Recommendation> recs) {
    for (final r in recs) {
      if (demoMode) {
        MockData.instance.applyDispense(r.fromPhc, r.medicine, r.quantity);
        MockData.instance.applyDispense(r.toPhc, r.medicine, -r.quantity);
      } else {
        backend.executeTransfer(r.id);
      }
    }
    setState(() => approved.addAll(recs.map((r) => r.id)));
    _toast('${recs.length} transfers approved ?');
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _openFacility(String phc) => setState(() {
        phcId = phc;
        view = AppView.facility;
      });

  void _switcher() {
    final data = MockData.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: ViewHeader(
                title: 'Select facility',
                subtitle: 'Thiruvallur district � 8 Primary Health Centres',
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: MockData.roster.length,
                itemBuilder: (c, i) {
                  final phc = MockData.roster[i];
                  final meds = data.inventory[phc]?.values ?? const <Medicine>[];
                  return ListTile(
                    leading:
                        SizedBox(width: 70, child: Text(phc, style: AppText.numeric)),
                    title: Text(data.nameOf(phc), style: AppText.body),
                    subtitle:
                        Text('${meds.length} medicine pairs', style: AppText.caption),
                    trailing: StatusPill.severity(MaxRisk.of(data.inventory[phc]!), dense: true),
                    selected: phc == phcId,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFacility(phc);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
              width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }

    final data = MockData.instance;
    final body = switch (view) {
      AppView.command => CommandCenter(
          data: data,
          selectedPhc: phcId,
          onOpenFacility: _openFacility,
          recommendations: _recs,
          criticalCount: _critical,
          watchCount: _watch,
          onApprove: _approve),
      AppView.facility => FacilityView(
          data: data,
          phc: phcId,
          initSpeech: backend.initSpeech,
          speech: backend.speech,
          onResult: _handle),
      AppView.transfers => TransfersView(
          data: data,
          recommendations: _recs,
          onApproveOne: _approve,
          onApproveMany: _approveMany,
          approvedIds: approved),
      AppView.evidence => const EvidenceView(),
    };

    return AppShell(
      view: view,
      onView: (v) => setState(() => view = v),
      body: body,
      facilityLabel: '$phcId � ${data.nameOf(phcId)}',
      demoMode: demoMode,
      onFacilitySwitch: _switcher,
      actions: [
        if (lastStatus.isNotEmpty && view == AppView.facility)
          Tooltip(
            message: lastStatus,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 230),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.healthyBg,
                  borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle,
                    size: 13, color: AppColors.healthy),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(lastStatus,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.healthy,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
