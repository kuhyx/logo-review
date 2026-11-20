/// The review rules, free of widgets: labels, filters, picks, history.
library;

import 'package:logo_review/models.dart';
import 'package:logo_review/past.dart';

/// The parts of a logo key `tool/id-mode`.
({String tool, String id, String mode, String type}) parseKey(String key) {
  final slash = key.indexOf('/');
  final name = key.substring(slash + 1);
  final dash = name.lastIndexOf('-');
  final id = dash < 0 ? name : name.substring(0, dash);
  return (
    tool: key.substring(0, slash),
    id: id,
    mode: dash < 0 ? 'c' : name.substring(dash + 1),
    type: id.isEmpty ? '' : id[0],
  );
}

/// The caption under a tile: the id, and the tool when it is not the first.
String caption(Manifest manifest, String key) {
  final k = parseKey(key);
  return k.tool == manifest.tools.first ? k.id : '${k.id} ${k.tool}';
}

/// Whether the last question about [key] has an answer; null with no question.
bool? answered(ReviewState state, Designer designer, String key) {
  final asked = state.logos[key]?.thread ?? const [];
  if (asked.isEmpty) return null;
  final replies = designer.answers[key] ?? const [];
  final lastReply = replies.isEmpty ? '' : replies.last.at;
  return lastReply.compareTo(asked.last.at) > 0;
}

/// The keys that pass the tool and verdict filters (`all` passes everything;
/// verdict `none` means not judged yet).
List<String> visibleKeys(
  Manifest manifest,
  ReviewState state, {
  String tool = 'all',
  String verdict = 'all',
}) => [
  for (final key in manifest.keys)
    if ((tool == 'all' || key.startsWith('$tool/')) &&
        (verdict == 'all' ||
            (verdict == 'none'
                ? state.logos[key]?.verdict == null
                : state.logos[key]?.verdict == verdict)))
      key,
];

/// The key [delta] steps from [current] in [visible], wrapping around.
String stepKey(List<String> visible, String current, int delta) {
  final i = visible.indexOf(current);
  return visible[(i + delta + visible.length) % visible.length];
}

/// Every type has its finalist (or is dropped) but the winner is still open.
bool winnerWaits(Manifest manifest, ReviewState state) =>
    manifest.types.isNotEmpty &&
    manifest.types.keys.every(
      (t) => state.picks.containsKey(t) || state.dropped.contains(t),
    ) &&
    state.picks.isNotEmpty &&
    state.winner == null;

/// Picks [key] in the line-up of [type] (`*` is the final). A second tap
/// clears it. Returns the line-up to show next: the final once every type has
/// its finalist.
String pick(Manifest manifest, ReviewState state, String type, String key) {
  if (type == '*') {
    state.winner = state.winner == key ? null : key;
    return type;
  }
  final before = state.picks[type];
  if (before != null && state.winner == before) state.winner = null;
  if (before == key) {
    state.picks.remove(type);
    return type;
  }
  state.picks[type] = key;
  return winnerWaits(manifest, state) ? '*' : type;
}

/// One column of a line-up.
typedef Entrant = ({String name, String path, String? key});

/// The columns of the line-up of [type]: last round's finalists first (to
/// compare only, no key), then this round's variants; for `*` the finalists.
List<Entrant> lineUp(
  Manifest manifest,
  ReviewState state,
  History history,
  String type,
) {
  if (type == '*') {
    return [
      for (final t in manifest.types.keys)
        if (state.picks[t] case final key?)
          (name: parseKey(key).id, path: '/img/$key.png', key: key),
    ];
  }
  final keys = [
    for (final k in manifest.keys)
      if (parseKey(k).type == type) k,
  ];
  final prev = manifest.round - 1;
  final before = <String>{
    for (final k in keys)
      for (final s in history.steps[parseKey(k).id] ?? const <Step>[])
        if (s.round == prev) s.id,
  }.toList()..sort();
  return [
    for (final id in before)
      (name: '$prev · $id', path: '/old/$prev/$id-c.png', key: null),
    for (final k in keys)
      (name: caption(manifest, k), path: '/img/$k.png', key: k),
  ];
}

/// One step of a design's history, ready to show.
typedef Past = ({
  int round,
  String id,
  String path,
  String changed,
  String? verdict,
  List<Mark> marks,
  String said,
});

/// The history of the design behind [key], oldest first, each step with what
/// the reviewer said about it then (gathered over that round's tools).
List<Past> pastOf(Manifest manifest, History history, String key) {
  final k = parseKey(key);
  return [
    for (final step in history.steps[k.id] ?? const <Step>[])
      _past(manifest, history, key, k.mode, step),
  ];
}

Past _past(Manifest m, History h, String key, String mode, Step step) {
  final now = step.round == m.round;
  final entries = now
      ? const <Entry>[]
      : [
          for (final t in h.tools['${step.round}'] ?? const <String>[])
            ?h.said['${step.round}']?['$t/${step.id}-$mode'],
        ];
  final marks = [for (final e in entries) ...e.marks];
  final lines = [
    for (final (i, mark) in marks.indexed)
      if (mark.text.isNotEmpty) '${i + 1}. ${mark.text}',
    ...{
      for (final e in entries)
        if (e.note.isNotEmpty) e.note,
    },
  ];
  return (
    round: step.round,
    id: step.id,
    path: now
        ? '/img/$key.png'
        : step.round == 1
        ? '/old/1/${step.id}.png'
        : '/old/${step.round}/${step.id}-$mode.png',
    changed: step.text,
    verdict: entries.map((e) => e.verdict).nonNulls.firstOrNull,
    marks: marks,
    said: lines.join('\n'),
  );
}

/// One line of the discussion about a logo, in time order.
typedef Talk = ({String text, bool mine, bool open});

/// The discussion about [key]: the design's rationale first, then questions
/// and answers by time. The last question is `open` while it has no answer.
List<Talk> talkOf(ReviewState state, Designer designer, String key) {
  final k = parseKey(key);
  final why = [?designer.designs[k.id], ?designer.tools[k.tool]].join('\n\n');
  final all = [
    for (final m in state.logos[key]?.thread ?? const <Message>[])
      (text: m.text, at: m.at, mine: true),
    for (final m in designer.answers[key] ?? const <Message>[])
      (text: m.text, at: m.at, mine: false),
  ]..sort((a, b) => a.at.compareTo(b.at));
  final open = answered(state, designer, key) == false;
  return [
    if (why.isNotEmpty) (text: why, mine: false, open: false),
    for (final (i, m) in all.indexed)
      (text: m.text, mine: m.mine, open: open && m.mine && i == all.length - 1),
  ];
}

/// A new idea from the form: only http(s) links become a reference; any other
/// text in the link field stays in the words. Null when everything is empty.
Idea? ideaFrom(String text, String ref, String image, DateTime now) {
  final words = text.trim();
  final link = ref.trim();
  if (words.isEmpty && link.isEmpty && image.isEmpty) return null;
  final isLink = RegExp('^https?://').hasMatch(link);
  return (
    text: isLink || link.isEmpty ? words : '$words\n$link'.trim(),
    ref: isLink ? link : '',
    image: image,
    at: now.toUtc().toIso8601String(),
  );
}
