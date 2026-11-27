// The corner mark a service draws over an avatar (a status dot, Google's
// pencil): on the five services that have one, at every listed size, over the
// bottom-right corner, the same table as the page's #overlays block.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/ui/avatars.dart';
import 'package:logo_review/ui/corner_mark.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

const marked = {
  'discord': 'Online',
  'gmail': 'Edit',
  'slack': 'Online',
  'telegram': 'Online',
  'facebook': 'Online',
};

Map<String, dynamic> pageTable() {
  final html = File('../index.html').readAsStringSync();
  final body = RegExp(
    '<script type="application/json" id="overlays">(.*?)</script>',
    dotAll: true,
  ).firstMatch(html)!.group(1)!;
  return jsonDecode(body) as Map<String, dynamic>;
}

void main() {
  test("the table is the page's, mark for mark", () {
    final page = pageTable();
    expect(cornerMarks.keys.toSet(), marked.keys.toSet());
    for (final MapEntry(key: id, value: mark) in cornerMarks.entries) {
      final want = page[id] as Map<String, dynamic>;
      expect(mark.tip, want['tip'], reason: id);
      expect(mark.pencil, want['kind'] == 'pencil', reason: id);
      final at = want['at'] as Map<String, dynamic>;
      expect(mark.at.keys.map((s) => '$s').toSet(), at.keys.toSet());
      for (final MapEntry(key: size, value: g) in mark.at.entries) {
        final w = (at['$size'] as List).cast<num>();
        expect(
          [g.cx, g.cy, g.d, g.ring],
          w.map((n) => n.toDouble()),
          reason: '$id $size',
        );
      }
    }
  });

  for (final a in avatars) {
    testWidgets('marks on ${a.id.isEmpty ? 'square' : a.id}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 20,
              children: [
                for (final size in a.sizes)
                  markedAvatar(
                    SizedBox.square(key: ValueKey('av-$size'), dimension: size),
                    a.id,
                    size,
                    ring: Colors.black,
                  ),
              ],
            ),
          ),
        ),
      );
      final tip = marked[a.id];
      for (final size in a.sizes) {
        final mark = k('mark-${a.id}-${size.round()}');
        if (tip == null) {
          expect(mark, findsNothing);
          continue;
        }
        expect(mark, findsOneWidget, reason: '${a.id} at $size');
        final av = tester.getRect(k('av-$size'));
        final r = tester.getRect(mark);
        expect(r.left, greaterThanOrEqualTo(av.center.dx), reason: '$size');
        expect(r.top, greaterThanOrEqualTo(av.center.dy), reason: '$size');
        expect(r.left, lessThan(av.right));
        expect(r.top, lessThan(av.bottom));
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: mark, matching: find.byType(Tooltip)),
        );
        expect(tooltip.message, tip);
      }
      expect(
        find.byType(Tooltip),
        tip == null ? findsNothing : findsNWidgets(a.sizes.length),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
