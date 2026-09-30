// models.dart — plain data classes for inventory, risk, and recommendations.
import 'moment_shim.dart';

class Medicine {
  final String key;
  final String name;
  final String strength;
  final String category;
  int stock;
  int reorderLevel;
  double avgDailyUse;
  RiskScore? risk;

  Medicine({
    required this.key,
    required this.name,
    required this.strength,
    required this.category,
    required this.stock,
    required this.reorderLevel,
    required this.avgDailyUse,
    this.risk,
  });

  static String prettyKey(String key) => key.replaceAll('_', ' ').replaceAll('-', ' ');

  String get prettyName => Medicine.prettyKey(key);

  String updatedAgo() => risk == null ? '' : fmtMinutes(risk!.ageMs());
}

class RiskScore {
  final double risk; // 0-100
  final double daysOfCover;
  final int forecast7d;
  final String source; // vertex | local-ensemble
  final int updatedAtMs;

  RiskScore({
    required this.risk,
    required this.daysOfCover,
    required this.forecast7d,
    required this.source,
    required this.updatedAtMs,
  });

  int ageMs() => DateTime.now().millisecondsSinceEpoch - updatedAtMs;
}

class Recommendation {
  final String id;
  final String medicine;
  final String fromPhc;
  final String toPhc;
  final int quantity;
  final String status;

  Recommendation({
    required this.id,
    required this.medicine,
    required this.fromPhc,
    required this.toPhc,
    required this.quantity,
    required this.status,
  });
}

enum AlertChannel { fcm, whatsapp }

/// Highest risk in a facility's medicine set — the DHO's triage key.
class MaxRisk {
  static double of(Map<String, Medicine> meds) {
    var m = 0.0;
    for (final med in meds.values) {
      final r = med.risk?.risk ?? 0;
      if (r > m) m = r;
    }
    return m;
  }
}

/// Mock Firebase for demo mode — same read/write contract as RTDB so the UI
/// never knows the difference. Seeded with the 3-PHC story for the demo video.
class MockData {
  // non-final so tests can reset() the singleton to a fresh demo story
  static MockData instance = MockData._();
  MockData._() {
    _seed();
  }

  /// Reset to the canonical demo story (used by tests and re-runs).
  static void reset() {
    instance = MockData._();
  }

  final Map<String, Map<String, Medicine>> inventory = {};
  final Map<String, Map<String, RiskScore>> riskScores = {};
  final List<Recommendation> recommendations = [];

  /// Human-readable facility names, matched to PHC_PROFILES in main.py so the
  /// demo and the synthetic dataset tell the same story.
  static const facilityNames = <String, String>{
    'PHC-001': 'Thiruvallur Main',
    'PHC-002': 'Ponneri',
    'PHC-003': 'Gummidipoondi',
    'PHC-004': 'Uthukottai',
    'PHC-005': 'Pallipattu',
    'PHC-006': 'Tiruttani',
    'PHC-007': 'R.K. Pet',
    'PHC-008': 'Sholinghar',
  };

  /// Roster order doubles as the road-distance proxy, mirroring the
  /// DONOR_REACH constraint in impact_sim.py's sensitivity sweep.
  static const roster = <String>[
    'PHC-001', 'PHC-002', 'PHC-003', 'PHC-004',
    'PHC-005', 'PHC-006', 'PHC-007', 'PHC-008',
  ];

  String nameOf(String phc) => facilityNames[phc] ?? phc;

  /// Every PHC x medicine row in the district, for the network table.
  List<({String phc, String medKey, Medicine med})> allRows() {
    final rows = <({String phc, String medKey, Medicine med})>[];
    inventory.forEach((phc, meds) {
      meds.forEach((k, m) => rows.add((phc: phc, medKey: k, med: m)));
    });
    return rows;
  }

  /// Facilities ordered by worst-case risk — the DHO's actual triage order.
  List<String> facilitiesByUrgency() {
    final list = inventory.keys.toList();
    list.sort((a, b) =>
        MaxRisk.of(inventory[b]!).compareTo(MaxRisk.of(inventory[a]!)));
    return list;
  }

  void _seed() {
    // Eight PHCs across one district. PHC-001 (starved), PHC-005 (surplus) and
    // PHC-007 (borderline) carry the demo story; the rest give the Command
    // Center a realistic spread so sorting and filtering have something to do.
    // Each value is [stock, reorderLevel, avgDailyUse, risk, cover, fc7d, src]
    final seed = <String, Map<String, Object>>{
      'PHC-001': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [40, 200, 24.0, 91.0, 1.7, 168, 'local-ensemble'],
          'Amoxicillin_500mg': [10, 150, 18.0, 96.0, 0.6, 120, 'local-ensemble'],
          'ORS_Low-Osmolarity': [600, 100, 12.0, 8.0, 50.0, 95, 'local-ensemble'],
          'Metformin_500mg': [450, 120, 10.0, 22.0, 45.0, 70, 'local-ensemble'],
          'Amlodipine_5mg': [320, 90, 8.0, 18.0, 40.0, 60, 'local-ensemble'],
          'Salbutamol_100mcg': [85, 110, 9.0, 41.0, 9.4, 63, 'local-ensemble'],
          'Cetirizine_10mg': [260, 80, 6.0, 11.0, 43.3, 42, 'local-ensemble'],
          'Iron-Folic-Syrup': [410, 130, 11.0, 27.0, 37.3, 77, 'local-ensemble'],
        }
      },
      'PHC-002': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [180, 160, 14.0, 34.0, 12.9, 98, 'local-ensemble'],
          'Amoxicillin_500mg': [95, 130, 12.0, 58.0, 7.9, 84, 'local-ensemble'],
          'ORS_Low-Osmolarity': [520, 100, 10.0, 9.0, 52.0, 70, 'local-ensemble'],
          'Metformin_500mg': [400, 120, 9.0, 19.0, 44.4, 63, 'local-ensemble'],
          'Amlodipine_5mg': [290, 90, 7.0, 16.0, 41.4, 49, 'local-ensemble'],
          'Salbutamol_100mcg': [120, 110, 8.0, 24.0, 15.0, 56, 'local-ensemble'],
          'Cetirizine_10mg': [310, 80, 6.0, 8.0, 51.7, 42, 'local-ensemble'],
          'Iron-Folic-Syrup': [380, 130, 10.0, 22.0, 38.0, 70, 'local-ensemble'],
        }
      },
      'PHC-003': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [260, 150, 11.0, 21.0, 23.6, 77, 'local-ensemble'],
          'Amoxicillin_500mg': [140, 120, 10.0, 29.0, 14.0, 70, 'local-ensemble'],
          'ORS_Low-Osmolarity': [470, 100, 9.0, 12.0, 52.2, 63, 'local-ensemble'],
          'Metformin_500mg': [360, 115, 8.0, 24.0, 45.0, 56, 'local-ensemble'],
          'Amlodipine_5mg': [270, 88, 7.0, 14.0, 38.6, 49, 'local-ensemble'],
          'Salbutamol_100mcg': [105, 105, 7.0, 31.0, 15.0, 49, 'local-ensemble'],
          'Cetirizine_10mg': [295, 78, 5.0, 10.0, 59.0, 35, 'local-ensemble'],
          'Iron-Folic-Syrup': [350, 125, 9.0, 26.0, 38.9, 63, 'local-ensemble'],
        }
      },
      'PHC-004': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [320, 140, 9.0, 16.0, 35.6, 63, 'local-ensemble'],
          'Amoxicillin_500mg': [165, 115, 9.0, 23.0, 18.3, 63, 'local-ensemble'],
          'ORS_Low-Osmolarity': [500, 98, 8.0, 10.0, 62.5, 56, 'local-ensemble'],
          'Metformin_500mg': [410, 112, 8.0, 18.0, 51.3, 56, 'local-ensemble'],
          'Amlodipine_5mg': [300, 86, 6.0, 12.0, 50.0, 42, 'local-ensemble'],
          'Salbutamol_100mcg': [130, 102, 6.0, 20.0, 21.7, 42, 'local-ensemble'],
          'Cetirizine_10mg': [330, 76, 5.0, 8.0, 66.0, 35, 'local-ensemble'],
          'Iron-Folic-Syrup': [395, 122, 8.0, 19.0, 49.4, 56, 'local-ensemble'],
        }
      },
      'PHC-005': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [900, 150, 10.0, 8.0, 90.0, 88, 'local-ensemble'],
          'Amoxicillin_500mg': [750, 120, 9.0, 6.0, 83.0, 87, 'local-ensemble'],
          'ORS_Low-Osmolarity': [400, 90, 8.0, 15.0, 50.0, 75, 'local-ensemble'],
          'Metformin_500mg': [500, 100, 9.0, 10.0, 55.0, 55, 'local-ensemble'],
          'Amlodipine_5mg': [380, 80, 7.0, 12.0, 47.0, 50, 'local-ensemble'],
          'Salbutamol_100mcg': [260, 100, 7.0, 11.0, 37.1, 49, 'local-ensemble'],
          'Cetirizine_10mg': [420, 75, 5.0, 7.0, 84.0, 35, 'local-ensemble'],
          'Iron-Folic-Syrup': [610, 120, 9.0, 9.0, 67.8, 63, 'local-ensemble'],
        }
      },
      'PHC-006': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [210, 155, 13.0, 29.0, 16.2, 91, 'local-ensemble'],
          'Amoxicillin_500mg': [110, 128, 11.0, 47.0, 10.0, 77, 'local-ensemble'],
          'ORS_Low-Osmolarity': [540, 100, 10.0, 8.0, 54.0, 70, 'local-ensemble'],
          'Metformin_500mg': [430, 118, 9.0, 17.0, 47.8, 63, 'local-ensemble'],
          'Amlodipine_5mg': [305, 89, 7.0, 13.0, 43.6, 49, 'local-ensemble'],
          'Salbutamol_100mcg': [140, 108, 8.0, 19.0, 17.5, 56, 'local-ensemble'],
          'Cetirizine_10mg': [340, 79, 6.0, 9.0, 56.7, 42, 'local-ensemble'],
          'Iron-Folic-Syrup': [420, 128, 10.0, 20.0, 42.0, 70, 'local-ensemble'],
        }
      },
      'PHC-007': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [220, 120, 16.0, 55.0, 13.7, 82, 'local-ensemble'],
          'Amoxicillin_500mg': [180, 100, 14.0, 62.0, 12.8, 75, 'local-ensemble'],
          'ORS_Low-Osmolarity': [150, 80, 10.0, 45.0, 15.0, 65, 'local-ensemble'],
          'Metformin_500mg': [210, 90, 9.0, 30.0, 23.0, 45, 'local-ensemble'],
          'Amlodipine_5mg': [190, 70, 7.0, 25.0, 27.0, 40, 'local-ensemble'],
          'Salbutamol_100mcg': [95, 95, 7.0, 38.0, 13.6, 49, 'local-ensemble'],
          'Cetirizine_10mg': [200, 70, 5.0, 18.0, 40.0, 35, 'local-ensemble'],
          'Iron-Folic-Syrup': [250, 110, 9.0, 33.0, 27.8, 63, 'local-ensemble'],
        }
      },
      'PHC-008': {
        'meds': <String, List<Object>>{
          'Paracetamol_500mg': [360, 145, 10.0, 18.0, 36.0, 70, 'local-ensemble'],
          'Amoxicillin_500mg': [175, 118, 9.0, 27.0, 19.4, 63, 'local-ensemble'],
          'ORS_Low-Osmolarity': [510, 99, 8.0, 11.0, 63.8, 56, 'local-ensemble'],
          'Metformin_500mg': [425, 115, 8.0, 16.0, 53.1, 56, 'local-ensemble'],
          'Amlodipine_5mg': [310, 87, 7.0, 15.0, 44.3, 49, 'local-ensemble'],
          'Salbutamol_100mcg': [135, 104, 7.0, 23.0, 19.3, 49, 'local-ensemble'],
          'Cetirizine_10mg': [345, 77, 5.0, 9.0, 69.0, 35, 'local-ensemble'],
          'Iron-Folic-Syrup': [405, 124, 8.0, 21.0, 50.6, 56, 'local-ensemble'],
        }
      },
    };

    final now = DateTime.now().millisecondsSinceEpoch;
    seed.forEach((phc, data) {
      inventory[phc] = {};
      riskScores[phc] = {};
      // heterogeneous int/double, so the literal infers List<Object>
      (data['meds'] as Map<String, List<Object>>).forEach((key, v) {
        final stock = (v[0] as num).toInt();
        final reorder = (v[1] as num).toInt();
        final avgDaily = (v[2] as num).toDouble();
        final riskVal = (v[3] as num).toDouble();
        final cover = (v[4] as num).toDouble();
        final fc = (v[5] as num).toInt();
        inventory[phc]![key] = Medicine(
          key: key,
          name: Medicine.prettyKey(key),
          strength: '',
          category: '',
          stock: stock,
          reorderLevel: reorder,
          avgDailyUse: avgDaily,
          risk: RiskScore(
            risk: riskVal,
            daysOfCover: cover,
            forecast7d: fc,
            source: v[6] as String,
            updatedAtMs: now,
          ),
        );
        riskScores[phc]![key] = inventory[phc]![key]!.risk!;
      });
    });
  }

  List<Recommendation> computeRecommendations() {
    final recs = <Recommendation>[];
    inventory.forEach((phc, meds) {
      meds.forEach((key, med) {
        final r = med.risk;
        if (r == null || r.risk < 70) return;
        for (final entry in inventory.entries) {
          if (entry.key == phc) continue;
          final donor = entry.value[key];
          if (donor == null) continue;
          final dr = donor.risk;
          if (dr == null || dr.risk > 30) continue;
          final surplus = donor.stock - donor.reorderLevel;
          if (surplus <= 0) continue;
          recs.add(Recommendation(
            id: 'mock-$phc-$key-${entry.key}',
            medicine: key,
            fromPhc: entry.key,
            toPhc: phc,
            quantity: surplus.clamp(0, (r.forecast7d - med.stock).clamp(1, 1 << 30)).toInt(),
            status: 'proposed',
          ));
          break;
        }
      });
    });
    recs.sort((a, b) => b.quantity.compareTo(a.quantity));
    return recs.take(10).toList();
  }

  void applyDispense(String phc, String medKey, int qty) {
    final med = inventory[phc]?[medKey];
    if (med == null) return;
    med.stock = (med.stock - qty).clamp(0, 1 << 30);
    _recomputeRisk(phc, medKey, med);
  }

  void _recomputeRisk(String phc, String medKey, Medicine med) {
    final r = med.risk;
    final newCover = med.avgDailyUse > 0 ? med.stock / med.avgDailyUse : 14.0;
    // same composite shape as the Cloud Function: coverage dominates (0.6),
    // 7-day deficit pushes it up (0.3), reorder-buffer urgency adds (0.1)
    final total7d = med.avgDailyUse * 7;
    final deficit = (total7d - med.stock).clamp(0, 1 << 30).toDouble();
    final deficitRatio = total7d > 0 ? deficit / total7d : 0.0;
    final reorder = med.reorderLevel > 0 ? med.reorderLevel : (total7d * 1.5).round();
    final riskVal = 100 *
        (0.6 * (1 - newCover / 14).clamp(0.0, 1.0) +
            0.3 * deficitRatio +
            0.1 * (1 - med.stock / reorder).clamp(0.0, 1.0));
    med.risk = RiskScore(
      risk: riskVal.clamp(0, 100).toDouble(),
      daysOfCover: newCover,
      forecast7d: total7d.round(),
      source: r?.source ?? 'local-ensemble',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    riskScores[phc]![medKey] = med.risk!;
  }
}
