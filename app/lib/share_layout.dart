/// Where things go in the "every logo" share picture, free of drawing code.
library;

import 'package:logo_review/models.dart';

/// One category of the picture: its title and its logos (colour versions).
typedef Section = ({String title, List<String> keys});

/// A run of one section's logos inside a row, starting at cell `at`.
typedef RowPart = ({Section section, List<String> keys, bool first, int at});

/// The categories to show: the manifest's groups, else one per type.
List<Section> gallerySections(Manifest m) {
  final groups = m.groups.isNotEmpty
      ? m.groups
      : [
          for (final t in m.types.keys)
            (title: t, ids: m.ids.where((id) => id.startsWith(t)).toList()),
        ];
  return [
    for (final g in groups)
      (
        title: g.title,
        keys: [
          for (final id in g.ids)
            for (final tool in m.tools)
              if (m.draws(tool, id)) '$tool/$id-c',
        ],
      ),
  ].where((s) => s.keys.isNotEmpty).toList();
}

/// Packs [sections] into rows of [perRow] cells. Small categories share a
/// row (one empty cell between them holds the next title); a big one takes
/// rows of its own.
List<List<RowPart>> galleryRows(List<Section> sections, {int perRow = 7}) {
  final rows = <List<RowPart>>[];
  var used = 0;
  for (final section in sections) {
    final n = section.keys.length;
    if (rows.isNotEmpty && n < perRow && used + n + 1 <= perRow) {
      rows.last.add((
        section: section,
        keys: section.keys,
        first: true,
        at: used + 1,
      ));
      used += n + 1;
      continue;
    }
    for (var i = 0; i < n; i += perRow) {
      final keys = section.keys.sublist(i, i + perRow > n ? n : i + perRow);
      rows.add([(section: section, keys: keys, first: i == 0, at: 0)]);
      used = keys.length;
    }
  }
  return rows;
}
