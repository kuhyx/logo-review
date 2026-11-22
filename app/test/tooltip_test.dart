// Every icon-only control names itself in one word on long-press; screen
// readers keep the full label.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

final RegExp _oneWord = RegExp(r'^[A-Za-z0-9-]{1,20}$');

String? tipOf(WidgetTester tester, String key) {
  final tips = find.descendant(of: k(key), matching: find.byType(Tooltip));
  if (tips.evaluate().isEmpty) return null;
  return tester.widget<Tooltip>(tips.first).message;
}

void expectTips(WidgetTester tester, Map<String, String> want) {
  for (final MapEntry(:key, :value) in want.entries) {
    expect(tipOf(tester, key), value, reason: key);
    expect(_oneWord.hasMatch(value), isTrue, reason: key);
  }
}

void main() {
  testWidgets('grid and review icons carry one-word tooltips', (tester) async {
    await pumpApp(tester, FakeServer());
    expectTips(tester, {
      'tool-all': 'All',
      'show-all': 'All',
      'show-none': 'Unjudged',
      'show-approve': 'Approved',
      'show-improve': 'Improve',
      'show-reject': 'Rejected',
      'share-all': 'Share',
      'ideas': 'Ideas',
      'type-*': 'Finalists',
    });
    // The screen-reader label stays the full one, not the tooltip word.
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Suggest a new direction'), findsOneWidget);
    expect(find.bySemanticsLabel('Ideas'), findsNothing);
    handle.dispose();

    await tester.longPress(k('ideas'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ideas'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(k('tile-css/A1-c'));
    await settle(tester, 8);
    expectTips(tester, {
      'prev': 'Previous',
      'next': 'Next',
      'close': 'Back',
      'verdict-approve': 'Approve',
      'verdict-improve': 'Improve',
      'verdict-reject': 'Reject',
      'shape-point': 'Point',
      'shape-rect': 'Rectangle',
      'shape-ellipse': 'Circle',
      'shape-arrow': 'Arrow',
      'like': 'Like',
      'dislike': 'Dislike',
      'tab-0': 'Notes',
      'tab-1': 'Discussion',
      'tab-2': 'Previews',
      'tab-3': 'History',
    });
    expect(tester.takeException(), isNull);
  });
}
