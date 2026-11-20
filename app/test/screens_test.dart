// Core flows 2-5: review a logo, compare and pick, suggest, share.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
    'grid: filters narrow the logos; nothing left shows the empty sign',
    (tester) async {
      final server = FakeServer(
        state: {
          'logos': {
            'css/A1-c': {
              'verdict': 'reject',
              'marks': [
                {'kind': 'point', 'x1': .5, 'y1': .5, 'x2': .5, 'y2': .5},
              ],
              'thread': [
                {'text': 'why?', 'at': '1'},
              ],
            },
          },
          'ideas': [
            {'text': 'more round'},
          ],
        },
      );
      await pumpApp(tester, server);
      expect(k('badge-reject'), findsOneWidget);
      await tap(tester, 'tool-rough');
      expect(find.byType(LogoTile), findsOneWidget);
      await tap(tester, 'tool-all');
      await tap(tester, 'show-reject');
      expect(find.byType(LogoTile), findsOneWidget);
      await tap(tester, 'show-none');
      expect(find.byType(LogoTile), findsNWidgets(3));
      await tap(tester, 'show-approve');
      expect(k('empty'), findsOneWidget);
      await tap(tester, 'show-improve');
      await tap(tester, 'show-all');
      expect(find.byType(LogoTile), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review: draw marks, comment, delete, judge, step, talk', (
    tester,
  ) async {
    final server = FakeServer();
    await pumpApp(tester, server);
    await tap(tester, 'tile-css/A1-c');
    expect(tester.widget<Text>(k('logo-id')).data, 'A1 css');

    // A point, then a disliked rectangle; a tiny rectangle is a slip.
    final stage = tester.getRect(k('overlay'));
    await tester.tapAt(stage.center);
    await tap(tester, 'shape-rect');
    await tap(tester, 'dislike');
    await tester.dragFrom(
      stage.topLeft + const Offset(40, 40),
      const Offset(100, 80),
    );
    await tester.tapAt(stage.center + const Offset(50, 50));
    await tap(tester, 'shape-ellipse');
    await tap(tester, 'like');
    await tester.dragFrom(stage.center, const Offset(60, 60));
    await tap(tester, 'shape-arrow');
    await tester.dragFrom(stage.center, const Offset(-60, 60));
    await tap(tester, 'shape-point');
    await settle(tester);
    var marks = server.state['logos']['css/A1-c']['marks'] as List;
    expect(marks.map((m) => (m as Map)['kind']), [
      'point',
      'rect',
      'ellipse',
      'arrow',
    ]);
    expect(marks[1]['like'], isFalse);
    expect(marks[0]['x1'], closeTo(0.5, 0.01));

    await tester.enterText(k('mark-text-1'), 'too sharp');
    await tester.enterText(k('note-css/A1-c'), 'close');
    await tap(tester, 'mark-delete-0');
    await settle(tester);
    marks = server.state['logos']['css/A1-c']['marks'] as List;
    expect(marks, hasLength(3));
    expect(marks[0]['text'], 'too sharp');
    expect(server.state['logos']['css/A1-c']['note'], 'close');

    await tap(tester, 'verdict-improve');
    await tap(tester, 'verdict-improve');
    await tap(tester, 'verdict-reject');
    await settle(tester);
    expect(server.state['logos']['css/A1-c']['verdict'], 'reject');

    // Talk: the rationale is there; a question stays open until answered.
    await tap(tester, 'tab-1');
    expect(find.textContaining('Why A1 looks like this.'), findsOneWidget);
    await tap(tester, 'send');
    await tester.enterText(k('ask'), 'why round?');
    await tap(tester, 'send');
    expect(k('msg-open'), findsOneWidget);
    server.claude['answers'] = {
      'css/A1-c': [
        {'text': 'softer', 'at': '9999'},
      ],
    };
    await tap(tester, 'next');
    expect(tester.widget<Text>(k('logo-id')).data, 'A2 css');
    await tap(tester, 'prev');
    expect(find.text('softer'), findsOneWidget);
    expect(k('msg-open'), findsNothing);

    // Previews and history.
    await tap(tester, 'tab-2');
    expect(k('ctx-light'), findsOneWidget);
    await tap(tester, 'ctx-scheme');
    expect(k('ctx-dark'), findsOneWidget);
    await tester.drag(k('ctx-dark'), const Offset(-300, 0));
    await settle(tester, 8);
    await tap(tester, 'tab-3');
    expect(find.text('3 · A1'), findsOneWidget);
    await tester.drag(k('history-css/A1-c'), const Offset(300, 0));
    await settle(tester, 8);
    expect(find.text('1. this arm\ntoo thin'), findsOneWidget);
    await tap(tester, 'next');
    expect(k('no-history'), findsOneWidget);
    await tap(tester, 'close');
    expect(find.byType(LogoTile), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: with a filter on, the arrows stay inside it', (
    tester,
  ) async {
    await pumpApp(tester, FakeServer());
    await tap(tester, 'tool-rough');
    await tap(tester, 'tile-rough/A1-c');
    await tap(tester, 'next');
    expect(tester.widget<Text>(k('logo-id')).data, 'A1 rough');
    // Judging it takes it out of a "not judged" filter; the arrows still work.
    expect(tester.takeException(), isNull);
  });
}
