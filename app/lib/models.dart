/// What the review server sends and stores, as typed values.
///
/// The shapes are the server's (see `server.py` and the web page): this app
/// and the page read and write the same `feedback.json`.
library;

/// A JSON object.
typedef Json = Map<String, dynamic>;

/// [v] as a JSON object; empty when it is not one.
Json asObject(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// The [T]s in [v]; empty when it is not a list.
List<T> asList<T>(Object? v) => v is List ? v.whereType<T>().toList() : <T>[];

/// [v] as a map of string lists.
Map<String, List<String>> asLists(Object? v) =>
    asObject(v).map((k, v) => MapEntry(k, asList<String>(v)));

/// The round on show: its tools, designs and how they are grouped.
class Manifest {
  /// Reads the server's manifest.
  new fromJson(Json j)
    : round = j['round'] is int ? j['round'] as int : 0,
      tools = asList<String>(j['tools']),
      ids = asList<String>(j['ids']),
      modes = asLists(j['modes']),
      skip = asLists(j['skip']),
      types = asObject(j['types']).map((k, v) => MapEntry(k, '$v')),
      groups = [
        for (final g in asList<Map<dynamic, dynamic>>(j['groups']))
          (title: '${g['title']}', ids: asList<String>(g['ids'])),
      ];

  /// The round's number.
  final int round;

  /// The tools that drew this round, in order.
  final List<String> tools;

  /// The design ids, such as `O1`.
  final List<String> ids;

  /// Per tool, the versions it made (`m` mono, `c` colour); both by default.
  final Map<String, List<String>> modes;

  /// Per tool, the designs it did not draw.
  final Map<String, List<String>> skip;

  /// Type letter to its description.
  final Map<String, String> types;

  /// Numbered categories for the share picture; empty means one per type.
  final List<({String title, List<String> ids})> groups;

  /// Whether [tool] drew design [id].
  bool draws(String tool, String id) => !(skip[tool] ?? const []).contains(id);

  /// Every logo of the round as `tool/id-mode`, in display order.
  late final List<String> keys = [
    for (final tool in tools)
      for (final id in ids)
        for (final m in modes[tool] ?? const ['m', 'c'])
          if (draws(tool, id)) '$tool/$id-$m',
  ];
}

/// One shape drawn on a logo; coordinates are 0..1 of the logo's side.
class Mark {
  /// Creates a mark.
  new({
    required this.kind,
    required this.like,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.text = '',
  });

  /// Reads a stored mark.
  new fromJson(Json j)
    : kind = '${j['kind'] ?? 'point'}',
      like = j['like'] != false,
      x1 = _num(j['x1']),
      y1 = _num(j['y1']),
      x2 = _num(j['x2']),
      y2 = _num(j['y2']),
      text = '${j['text'] ?? ''}';

  static double _num(Object? v) => v is num ? v.toDouble() : 0;

  /// `point`, `rect`, `ellipse` or `arrow`.
  final String kind;

  /// Whether the reviewer likes this part.
  final bool like;

  /// Start, x.
  final double x1;

  /// Start, y.
  final double y1;

  /// End, x.
  double x2;

  /// End, y.
  double y2;

  /// The comment on this mark.
  String text;

  /// The stored form.
  Json toJson() => {
    'kind': kind,
    'like': like,
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'text': text,
  };
}

/// One line of a discussion.
typedef Message = ({String text, String at});

/// [v] as discussion lines.
List<Message> asMessages(Object? v) => [
  for (final m in asList<Map<dynamic, dynamic>>(v))
    (text: '${m['text'] ?? ''}', at: '${m['at'] ?? ''}'),
];

/// The reviewer's feedback on one logo.
class Entry {
  /// An untouched entry.
  new();

  /// Reads a stored entry.
  new fromJson(Json j)
    : verdict = j['verdict'] is String ? j['verdict'] as String : null,
      note = '${j['note'] ?? ''}',
      marks = [
        for (final m in asList<Map<dynamic, dynamic>>(j['marks']))
          Mark.fromJson(m.cast()),
      ],
      thread = asMessages(j['thread']);

  /// `approve`, `improve`, `reject` or none.
  String? verdict;

  /// The note about the whole logo.
  String note = '';

  /// The shapes drawn on it.
  List<Mark> marks = [];

  /// The reviewer's questions.
  List<Message> thread = [];

  /// Whether there is anything to keep.
  bool get touched =>
      verdict != null ||
      note.isNotEmpty ||
      marks.isNotEmpty ||
      thread.isNotEmpty;

  /// The stored form.
  Json toJson() => {
    'verdict': verdict,
    'note': note,
    'marks': [for (final m in marks) m.toJson()],
    'thread': [
      for (final m in thread) {'text': m.text, 'at': m.at},
    ],
  };
}

/// A suggested new direction.
typedef Idea = ({String text, String ref, String image, String at});

/// Everything the reviewer has said about the round.
class ReviewState {
  /// Empty feedback.
  new();

  /// Reads `feedback.json`.
  new fromJson(Json j)
    : logos = asObject(j['logos'])
          .map((k, v) => MapEntry(k, Entry.fromJson(asObject(v)))),
      ideas = [
        for (final i in asList<Map<dynamic, dynamic>>(j['ideas']))
          (
            text: '${i['text'] ?? ''}',
            ref: '${i['ref'] ?? ''}',
            image: '${i['image'] ?? ''}',
            at: '${i['at'] ?? ''}',
          ),
      ],
      picks = asObject(j['picks']).map((k, v) => MapEntry(k, '$v')),
      winner = j['winner'] is String ? j['winner'] as String : null,
      dropped = asList<String>(j['dropped']);

  /// Feedback per logo key.
  Map<String, Entry> logos = {};

  /// Suggested directions.
  List<Idea> ideas = [];

  /// The finalist picked per type.
  Map<String, String> picks = {};

  /// The winner among the finalists.
  String? winner;

  /// Types taken out of the final.
  List<String> dropped = [];

  /// The entry for [key], made on first use.
  Entry entry(String key) => logos.putIfAbsent(key, Entry.new);

  /// The stored form; untouched entries are left out.
  Json toJson() => {
    'logos': {
      for (final e in logos.entries)
        if (e.value.touched) e.key: e.value.toJson(),
    },
    'ideas': [
      for (final i in ideas)
        {'text': i.text, 'ref': i.ref, 'image': i.image, 'at': i.at},
    ],
    'picks': picks,
    'winner': winner,
    'dropped': dropped,
  };
}
