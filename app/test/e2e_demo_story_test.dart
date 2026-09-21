// e2e_demo_story_test.dart — full demo-story walk-through through the real UI.
// Exercises: dashboard render → risk cards → parse pipeline (Tamil) → manual
// entry dispense → risk spike → transfer recommendation → Approve → stock moved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arogyachain_app/main.dart';
import 'package:arogyachain_app/models.dart';

void _bigSurface(WidgetTester tester) {
  // Lazy ListView children below the fold are never built at 800x600;
  // give the test a huge surface so every demo widget exists to find.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.views.first.physicalSize = const Size(1200, 4000);
  tester.platformDispatcher.views.first.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E demo story (plan.md §5 wow moment)', () {
    testWidgets('voice-less path: manual Tamil entry → risk spike → transfer → approve',
        (tester) async {
      _bigSurface(tester);
      MockData.reset();
      await tester.pumpWidget(const ArogyaChainApp());
      await tester.pumpAndSettle();

      // 1) Dashboard renders with demo story
      expect(find.text('ArogyaChain AI'), findsOneWidget);
      expect(find.text('DEMO MODE'), findsOneWidget);
      expect(find.textContaining('Stock-Out Risk'), findsOneWidget);
      // PHC-001 seeded: Paracetamol risk 91, Amoxicillin risk 96
      expect(find.textContaining('Paracetamol 500mg'), findsWidgets);

      // 2) Tamil manual entry "பாராசிட்டமால் ஐம்பது" → parse → dispense 50
      final tf = find.byType(TextField);
      expect(tf, findsOneWidget);
      await tester.enterText(tf, 'பாராசிட்டமால் ஐம்பது');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // mock state actually mutated: stock 40 - 50 → clamped at 0, risk recomputed
      final med = MockData.instance.inventory['PHC-001']!['Paracetamol_500mg']!;
      expect(med.stock, 0);
      // cover = 0 days → coverage component maxed; risk strictly increased vs 91
      expect(med.risk!.risk, greaterThan(91));
      // risk card reflects the recomputed score
      expect(find.textContaining('${med.risk!.risk.round()}%'), findsWidgets);
      // projected stock-out date row appears (cover < 14)
      expect(find.textContaining('Projected stock-out'), findsWidgets);

      // 3) Transfer recommendation exists: PHC-005 → PHC-001
      expect(find.textContaining('Recommended Transfers'), findsOneWidget);
      expect(find.textContaining('PHC-005'), findsWidgets);

      // 4) Approve the top transfer → donor stock drops, receiver gains
      final donorBefore =
          MockData.instance.inventory['PHC-005']!['Paracetamol_500mg']!.stock;
      await tester.tap(find.text('Approve').first);
      await tester.pumpAndSettle();
      final donorAfter =
          MockData.instance.inventory['PHC-005']!['Paracetamol_500mg']!.stock;
      final receiverAfter =
          MockData.instance.inventory['PHC-001']!['Paracetamol_500mg']!.stock;
      expect(donorAfter, lessThan(donorBefore));
      expect(receiverAfter, greaterThan(0));
      expect(find.text('Transfer approved ✓'), findsOneWidget);
    });

    testWidgets('rejected utterance surfaces manual fallback message', (tester) async {
      _bigSurface(tester);
      MockData.reset();
      await tester.pumpWidget(const ArogyaChainApp());
      await tester.pumpAndSettle();

      final tf = find.byType(TextField);
      await tester.enterText(tf, 'Aspirin 30'); // not in the 30-drug corpus
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not parse'), findsOneWidget);
    });
  });
}
