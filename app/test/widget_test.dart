// widget_test.dart — smoke tests: the app boots and renders on both a desktop
// and a phone viewport without overflowing. The full product walkthrough lives
// in e2e_demo_story_test.dart.

import 'package:arogyachain_app/main.dart';
import 'package:arogyachain_app/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots into the shell on a desktop viewport', (t) async {
    MockData.reset();
    t.view.physicalSize = const Size(1400, 1800);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.views.first.physicalSize = const Size(1400, 1800);
    t.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const ArogyaChainApp());
    await t.pumpAndSettle();

    expect(find.text('ArogyaChain AI'), findsOneWidget);
    expect(find.text('Voice capture'), findsOneWidget); // landing view
    expect(t.takeException(), isNull);
  });

  testWidgets('renders on a phone without overflow', (t) async {
    MockData.reset();
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.views.first.physicalSize = const Size(390, 1400);
    t.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const ArogyaChainApp());
    await t.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    // any RenderFlex overflow is recorded as a test exception
    expect(t.takeException(), isNull);
  });
}
