import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/models.dart';
import 'package:logo_review/past.dart';
import 'package:logo_review/share_layout.dart';

import 'fakes.dart';

void main() {
  final manifest = Manifest.fromJson(manifestJson());

  test('the share picture packs small categories into shared rows', () {
    final byType = gallerySections(manifest);
    expect(byType.map((s) => s.title), ['A', 'B']);
    expect(byType.first.keys, ['css/A1-c', 'rough/A1-c', 'css/A2-c']);
    final grouped = gallerySections(
      Manifest.fromJson({
        ...manifestJson(),
        'groups': [
          {
            'title': '1',
            'ids': ['A1', 'A2'],
          },
          {
            'title': '2',
            'ids': ['B1'],
          },
          {'title': '3', 'ids': <String>[]},
        ],
      }),
    );
    expect(grouped.map((s) => s.title), ['1', '2']);
    final rows = galleryRows(grouped);
    expect(rows, hasLength(1));
    expect(rows.single.map((p) => (p.at, p.first, p.keys.length)), [
      (0, true, 3),
      (4, true, 1),
    ]);
    final big = (title: 'x', keys: [for (var i = 0; i < 9; i++) 'k$i']);
    final wrapped = galleryRows([big, grouped.last, grouped.last], perRow: 4);
    expect(
      wrapped.map((r) => r.map((p) => (p.at, p.first, p.keys.length)).toList()),
      [
        [(0, true, 4)],
        [(0, false, 4)],
        [(0, false, 1), (2, true, 1)],
        [(0, true, 1)],
      ],
    );
  });
}
