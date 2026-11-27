/// The phone's copy of the round and the reference pictures waiting to go
/// up, on top of a `LocalStore`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logo_review/local.dart';
import 'package:logo_review/models.dart';

/// A reference picture not yet on the server, for the idea made `at`.
typedef PendingRef = ({String at, String mime});

/// Reads and writes the kept round and the picture queue. Writes run one at
/// a time in order, so the last one asked for is the one on disk.
class Keeper {
  /// Keeps everything in [local]; a failed write goes to [onError].
  new(this.local, {this.onError});

  /// The files.
  final LocalStore local;

  /// Told when the phone refused a write.
  final void Function(Object error, StackTrace stack)? onError;

  static const _round = 'round.json';
  static const _refs = 'refs.json';
  static String _ref(String at) => 'ref:$at';

  Future<void> _writes = Future.value();

  Future<void> _queue(Future<void> Function() write) => _writes = _writes
      .then((_) => write())
      .onError<Object>((e, stack) => onError?.call(e, stack));

  Future<Object?> _json(String name) async {
    final bytes = await local.read(name);
    if (bytes == null) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null; // a damaged copy is as good as none
    }
  }

  Future<void> _write(String name, Object json) =>
      local.write(name, Uint8List.fromList(utf8.encode(jsonEncode(json))));

  /// The kept round (`manifest`, `state`, `history`, `claude`, `dirty`), or
  /// null when nothing was kept.
  Future<Json?> round() async {
    await _writes;
    final j = await _json(_round);
    return j is Map ? asObject(j) : null;
  }

  /// Keeps [round]; it is encoded now, so later changes are not in it.
  Future<void> keepRound(Json round) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(round)));
    return _queue(() => local.write(_round, bytes));
  }

  /// The pictures waiting, oldest first.
  Future<List<PendingRef>> refs() async {
    await _writes;
    return await _readRefs();
  }

  Future<List<PendingRef>> _readRefs() async => [
    for (final r in asList<Map<dynamic, dynamic>>(await _json(_refs)))
      (at: '${r['at']}', mime: '${r['mime']}'),
  ];

  /// Rewrites the queue as [change] makes it, inside the write order, so
  /// two changes never read the same old queue.
  Future<void> _changeRefs(
    List<PendingRef> Function(List<PendingRef> waiting) change,
  ) => _queue(
    () async => await _write(_refs, [
      for (final r in change(await _readRefs())) {'at': r.at, 'mime': r.mime},
    ]),
  );

  /// The bytes of the picture for the idea made [at], or null.
  Future<Uint8List?> refBytes(String at) => local.read(_ref(at));

  /// Queues [bytes] as the picture of the idea made [at].
  Future<void> addRef(String at, Uint8List bytes, String mime) async {
    await _queue(() => local.write(_ref(at), bytes));
    await _changeRefs((waiting) => [...waiting, (at: at, mime: mime)]);
  }

  /// Takes the picture of the idea made [at] off the queue.
  Future<void> dropRef(String at) async {
    await _changeRefs((waiting) => [...waiting.where((r) => r.at != at)]);
    await _queue(() => local.delete(_ref(at)));
  }
}
