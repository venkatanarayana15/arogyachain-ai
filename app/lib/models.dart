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
  final String source; // vertex | local-gbm
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

  void _seed() {
    final seed = {
      'PHC-001': {
        'name': 'Thiruvallur Main',
        'meds': {
          'Paracetamol_500mg': [40, 200, 24.0, 91.0, 1.7, 168, 'local-gbm'],
          'Amoxicillin_500mg': [10, 150, 18.0, 96.0, 0.6, 120, 'local-gbm'],
          'ORS_Low-Osmolarity': [600, 100, 12.0, 8.0, 50.0, 95, 'local-gbm'],
          'Metformin_500mg': [450, 120, 10.0, 22.0, 45.0, 70, 'local-gbm'],
          'Amlodipine_5mg': [320, 90, 8.0, 18.0, 40.0, 60, 'local-gbm'],
        },
      },
      'PHC-005': {
        'name': 'Pallipattu',
        'meds': {
          'Paracetamol_500mg': [900, 150, 10.0, 8.0, 90.0, 88, 'local-gbm'],
          'Amoxicillin_500mg': [750, 120, 9.0, 6.0, 83.0, 87, 'local-gbm'],
          'ORS_Low-Osmolarity': [400, 90, 8.0, 15.0, 50.0, 75, 'local-gbm'],
          'Metformin_500mg': [500, 100, 9.0, 10.0, 55.0, 55, 'local-gbm'],
          'Amlodipine_5mg': [380, 80, 7.0, 12.0, 47.0, 50, 'local-gbm'],
        },
      },
      'PHC-007': {
        'name': 'R.K. Pet',
        'meds': {
          'Paracetamol_500mg': [220, 120, 16.0, 55.0, 13.7, 82, 'local-gbm'],
          'Amoxicillin_500mg': [180, 100, 14.0, 62.0, 12.8, 75, 'local-gbm'],
          'ORS_Low-Osmolarity': [150, 80, 10.0, 45.0, 15.0, 65, 'local-gbm'],
          'Metformin_500mg': [210, 90, 9.0, 30.0, 23.0, 45, 'local-gbm'],
          'Amlodipine_5mg': [190, 70, 7.0, 25.0, 27.0, 40, 'local-gbm'],
        },
      },
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    seed.forEach((phc, data) {
      inventory[phc] = {};
      riskScores[phc] = {};
      (data['meds'] as Map<String, List>).forEach((key, v) {
        inventory[phc]![key] = Medicine(
          key: key,
          name: Medicine.prettyKey(key),
          strength: '',
          category: '',
          stock: v[0] as int,
          reorderLevel: v[1] as int,
          avgDailyUse: (v[2] as num).toDouble(),
          risk: RiskScore(
            risk: (v[3] as num).toDouble(),
            daysOfCover: (v[4] as num).toDouble(),
            forecast7d: v[5] as int,
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
      source: r?.source ?? 'local-gbm',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    riskScores[phc]![medKey] = med.risk!;
  }
}
