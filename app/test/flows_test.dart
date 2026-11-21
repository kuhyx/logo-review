// Core flows 3-5: compare and pick, suggest, share; and failure states.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuhy_credit/kuhy_credit.dart';
import 'package:logo_review/errors.dart';
import 'package:logo_review/ui/app.dart';
import 'package:logo_review/ui/tile.dart';
import 'package:logo_review/ui/widgets.dart';

import 'fakes.dart';

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(k(key));
  await settle(tester, 8);
}

void main() {
  testWidgets(
    'compare: pick one per type, then the winner; share the line-up',
    (tester) async {
      final server = FakeServer();
      final services = FakeServices();
      await pumpApp(tester, server, services: services);
      await tap(tester, 'type-A');
      expect(
        k('col-2 · A1'),
        findsOneWidget,
        reason: "last round's version, to compare",
      );
      // The second page is half off screen in a test view: press it directly.
      tester.widget<IconToggle>(k('pick-css/A1-c')).onTap!();
      await settle(tester, 8);
      await tap(tester, 'type-B');
      await tap(tester, 'pick-css/B1-c');
      expect(
        k('line-up-*'),
        findsOneWidget,
        reason: 'every type picked: the final opens',
      );
      await tap(tester, 'pick-css/A1-c');
      await settle(tester);
      expect(server.state['picks'], {'A': 'css/A1-c', 'B': 'css/B1-c'});
      expect(server.state['winner'], 'css/A1-c');

      await tester.tap(k('share-line-up'));
      await settle(tester, 10);
      expect(services.shared, hasLength(1));
      expect(services.shared.single.sublist(1, 4), 'PNG'.codeUnits);
      await tester.pump(const Duration(seconds: 3));
      await tap(tester, 'close');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a round whose finalists are all picked opens on the final', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeServer(
        state: {
          'logos': <String, dynamic>{},
          'picks': {'A': 'css/A1-c', 'B': 'css/B1-c'},
        },
      ),
    );
    expect(k('line-up-*'), findsOneWidget);
  });

  testWidgets(
    'share every logo; a picture that cannot be made turns the button red',
    (tester) async {
      final server = FakeServer();
      final services = FakeServices();
      await pumpApp(tester, server, services: services);
      await tester.tap(k('share-all'));
      await settle(tester, 12);
      expect(services.shared, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
      services.failShare = true;
      await tester.tap(k('share-all'));
      await settle(tester, 12);
      expect(
        find.byIcon(const IconData(0xe16a, fontFamily: 'MaterialIcons')),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(services.shared, hasLength(1));
    },
  );

  testWidgets('ideas: add words, a link and a picture; delete one', (
    tester,
  ) async {
    final server = FakeServer();
    final services = FakeServices()..picked = (bytes: png, mime: 'image/png');
    await pumpApp(tester, server, services: services);
    await tap(tester, 'ideas');
    await tap(tester, 'idea-add');
    expect(server.state['ideas'], isEmpty);
    await tester.enterText(k('idea-text'), 'try a fox');
    await tester.enterText(k('idea-ref'), 'https://example.org/fox');
    await tap(tester, 'idea-image');
    await tap(tester, 'idea-add');
    await settle(tester);
    final idea = (server.state['ideas'] as List).single as Map;
    expect(
      (idea['text'], idea['ref'], idea['image']),
      ('try a fox', 'https://example.org/fox', 'abc.png'),
    );
    expect(find.text('try a fox'), findsOneWidget);
    await tap(tester, 'idea-delete-0');
    await settle(tester);
    expect(server.state['ideas'], isEmpty);
    await tap(tester, 'close');
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline shows a retry; an error stays on screen until tapped', (
    tester,
  ) async {
    final server = FakeServer()..down = true;
    await usePixel(tester);
    final errors = ErrorReporter((_) async {});
    await tester.pumpWidget(
      LogoReviewApp(
        controller: controllerFor(server),
        services: FakeServices().services,
        errors: errors,
      ),
    );
    await settle(tester);
    expect(find.byType(KuhyCredit), findsOneWidget);
    expect(k('retry'), findsOneWidget);
    server.down = false;
    await tap(tester, 'retry');
    await settle(tester);
    expect(find.byType(LogoTile), findsNWidgets(4));
    errors.report('it broke', null);
    await tester.pump();
    expect(find.text('it broke'), findsOneWidget);
    await tap(tester, 'error-bar');
    expect(find.text('it broke'), findsNothing);
  });
}
