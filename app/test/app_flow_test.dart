// Core flow 1: pair with the computer's code, see the round, judge a logo.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/ui/pair_page.dart';
import 'package:logo_review/ui/tile.dart';

import 'fakes.dart';

void main() {
  testWidgets('pair, see the grid, approve a logo, and it is saved', (
    tester,
  ) async {
    final server = FakeServer();
    await pumpApp(tester, server, token: '');
    expect(find.byType(PairPage), findsOneWidget);

    await tester.enterText(k('pair-code'), '000000');
    await settle(tester);
    expect(k('refused'), findsOneWidget, reason: 'a wrong code is refused');

    await tester.enterText(k('pair-code'), '123456');
    await settle(tester);
    expect(find.byType(LogoTile), findsNWidgets(4));
    expect(tester.widget<Text>(k('shown')).data, '4');

    await tester.tap(k('tile-css/A1-c'));
    await settle(tester);
    await tester.tap(k('verdict-approve'));
    await settle(tester);
    expect(server.state['logos']['css/A1-c']['verdict'], 'approve');
    await tester.tap(k('close'));
    await settle(tester);
    expect(k('badge-approve'), findsOneWidget);
    expect(k('saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
