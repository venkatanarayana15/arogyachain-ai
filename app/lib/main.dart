// main.dart — ArogyaChain AI (Day 2+3+7 combined build)
// Voice-first inventory app: Firebase RTDB live mode with a full demo-mode
// fallback so the hackathon video never depends on network or billing.
//
// Demo story (matches plan.md §5): PHC-001 is starved, PHC-005 is overstocked,
// voice-dispense 50 Paracetamol → risk spikes → transfer recommendation appears.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArogyaChainApp());
}

class ArogyaChainApp extends StatelessWidget {
  const ArogyaChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArogyaChain AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DashboardPage(),
    );
  }
}

// ---------------------------------------------------------------------------
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
      source: (v['forecastSource'] as String?) ?? 'local-gbm',
      updatedAtMs: (v['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockBackend {
  bool get isDemo => _demo;
  final bool _demo;
  StockBackend({required bool demo}) : _demo = demo;

  final stt.SpeechToText _speech = stt.SpeechToText();

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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late StockBackend backend;
  bool demoMode = true;
  bool ready = false;
  String phcId = 'PHC-001';

  // state
  Map<String, Map<String, dynamic>> inventory = {}; // phc -> medKey -> data
  Map<String, Map<String, dynamic>> riskScores = {};
  StreamSubscription? invSub;
  StreamSubscription? riskSub;

  // voice
  bool listening = false;
  String lastHeard = '';
  String lastStatus = '';

  final List<String> phcList = const [
    'PHC-001', 'PHC-002', 'PHC-003', 'PHC-004',
    'PHC-005', 'PHC-006', 'PHC-007', 'PHC-008'
  ];

  @override
  void initState() {
    super.initState();
    // Demo unless firebase-options provided; on failure we fall back silently.
    backend = StockBackend(demo: true);
    _boot();
  }

  Future<void> _boot() async {
    // Try live Firebase if firebase_options.dart is generated (Day 1 step 2).
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

  // ----------------------------- voice -------------------------------------

  Future<void> _toggleVoice() async {
    if (listening) {
      await backend._speech.stop();
      setState(() => listening = false);
      return;
    }
    final ok = await backend.initSpeech();
    if (!ok) {
      _toast('Speech recognition unavailable on this device.');
      return;
    }
    setState(() => listening = true);
    backend._speech.listen(
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        localeId: 'ta_IN', // switch to 'hi_IN' / 'en_IN' per worker
      ),
      onResult: (r) async {
        setState(() => lastHeard = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          setState(() => listening = false);
          await _handleUtterance(r.recognizedWords.trim());
        }
      },
    );
  }

  Future<void> _handleUtterance(String text) async {
    setState(() => lastStatus = 'Heard: "$text"');
    // 1) try Gemini-backed Cloud Function (live mode only)
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
    // 2) local regex fallback
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
    await _applyDispense(medKey, qty);
  }

  Future<void> _applyDispense(String medKey, int qty) async {
    if (demoMode) {
      MockData.instance.applyDispense(phcId, medKey, qty);
      setState(() => lastStatus = '$phcId: -$qty ${medKey.replaceAll('_', ' ')} (demo sync ✓)');
    } else {
      await backend.pushTransaction(phcId, {
        'medicine': medKey,
        'type': 'dispense',
        'quantity': qty,
        'timestamp': ServerValue.timestamp,
      });
      setState(() => lastStatus = '$phcId: -$qty ${medKey.replaceAll('_', ' ')} → queued to Firebase ✓');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------------------------- derived data ---------------------------------

  List<MapEntry<String, RiskEntry>> get riskRows {
    if (demoMode) {
      return MockData.instance.riskScores[phcId]?.entries.map((e) {
            final r = e.value;
            return MapEntry(
              e.key,
              RiskEntry(
                risk: r.risk,
                daysOfCover: r.daysOfCover,
                forecast7d: r.forecast7d,
                source: r.source,
                updatedAtMs: r.updatedAtMs,
              ),
            );
          }).toList() ??
          [];
    }
    final phc = riskScores[phcId];
    if (phc == null) return [];
    return phc.entries.map((e) {
      final r = RiskEntry.fromMap(e.value);
      return r == null ? null : MapEntry(e.key, r);
    }).whereType<MapEntry<String, RiskEntry>>().toList();
  }

  List<Recommendation> get recommendations =>
      demoMode ? MockData.instance.computeRecommendations() : [];

  void sortRisk() {
    riskRows.sort((a, b) => b.value.risk.compareTo(a.value.risk));
  }

  // ------------------------------- UI ---------------------------------------

  @override
  Widget build(BuildContext context) {
    sortRisk();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ArogyaChain AI'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (demoMode)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  label: Text('DEMO MODE', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _phcSelector(),
                const SizedBox(height: 12),
                _voiceCard(),
                const SizedBox(height: 12),
                const Text('Stock-Out Risk (next 7 days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...riskRows.map(_riskCard),
                if (demoMode) ...[
                  const SizedBox(height: 12),
                  _transferCard(),
                ],
              ],
            ),
    );
  }

  Widget _phcSelector() => DropdownButtonFormField<String>(
        initialValue: phcId,
        decoration: const InputDecoration(
          labelText: 'Facility',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: phcList
            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
            .toList(),
        onChanged: (v) => setState(() => phcId = v ?? phcId),
      );

  Widget _voiceCard() => Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(listening ? Icons.mic : Icons.mic_none,
                      color: listening ? Colors.red : Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      listening ? 'Listening… speak now' : 'Tap mic, say e.g. "Paracetamol 50" (தமிழ்/हिंदी/English)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _toggleVoice,
                    icon: Icon(listening ? Icons.stop : Icons.mic),
                  ),
                ],
              ),
              if (lastHeard.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Heard: "$lastHeard"',
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
              if (lastStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(lastStatus,
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                ),
            ],
          ),
        ),
      );

  Widget _riskCard(MapEntry<String, RiskEntry> e) {
    final med = e.key;
    final r = e.value;
    final Color color = r.risk >= 80
        ? Colors.red
        : r.risk >= 50
            ? Colors.orange
            : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    med.replaceAll('_', ' ').replaceAll('-', ' '),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text('${r.risk.round()}%',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: r.risk / 100,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${r.daysOfCover.toStringAsFixed(1)} days of cover · '
              '7-day forecast: ${r.forecast7d} units · '
              'model: ${r.source == 'vertex' ? 'Vertex AI AutoML' : 'on-device GBM'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (r.daysOfCover < 14)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '⚠ Projected stock-out: ${DateFormat('EEE, MMM d').format(DateTime.now().add(Duration(days: r.daysOfCover.ceil())))}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: r.daysOfCover < 7 ? Colors.red : Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _transferCard() {
    final recs = recommendations;
    if (recs.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommended Transfers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...recs.map((rec) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                  title: Text(
                      'Transfer ${rec.quantity} × ${rec.medicine.replaceAll('_', ' ')}'),
                  subtitle: Text('${rec.fromPhc} → ${rec.toPhc}'),
                  trailing: FilledButton(
                    onPressed: () async {
                      if (demoMode) {
                        MockData.instance.applyDispense(rec.fromPhc, rec.medicine, rec.quantity);
                        if (rec.toPhc != phcId) {
                          MockData.instance.applyDispense(rec.toPhc, rec.medicine, -rec.quantity);
                        }
                      } else {
                        await backend.executeTransfer(rec.id);
                      }
                      _toast('Transfer approved ✓');
                      setState(() {});
                    },
                    child: const Text('Approve'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
