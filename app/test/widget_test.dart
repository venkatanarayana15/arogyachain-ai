import 'package:flutter_test/flutter_test.dart';
import 'package:arogyachain_app/main.dart';

void main() {
  testWidgets('Dashboard renders demo risk cards', (tester) async {
    await tester.pumpWidget(const ArogyaChainApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ArogyaChain AI'), findsOneWidget);
    expect(find.textContaining('Stock-Out Risk'), findsOneWidget);
  });
}
