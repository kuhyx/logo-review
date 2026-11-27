/// What waits to reach the server: feedback changes and the ideas' pictures.
/// Every change is kept on the phone at once; sending runs by itself and a
/// failure is tried again later, so nothing waits on the network.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/keeper.dart';
import 'package:logo_review/models.dart';

/// A picture from the gallery and its type.
typedef Picture = ({Uint8List bytes, String mime});

/// The sending half of the review session.
mixin Outbox on ChangeNotifier {
  /// The server.
  ReviewApi get api;

  /// The kept round and the pictures waiting to go up.
  Keeper get keeper;

  /// The feedback.
  ReviewState get state;

  /// How long to gather changes before one save.
  Duration get saveDelay;

  /// The first wait before a failed send is tried again; it doubles with
  /// each failure, up to 64 times.
  Duration get retryDelay;

  /// Told about failures that are not "offline" or "unpaired".
  void Function(Object error, StackTrace stack)? get onError;

  /// Keeps the round and the feedback as they are now on the phone.
  void keep();

  /// Whether a change waits to be saved.
  bool dirty = false;

  Timer? _timer;
  Future<void> _sending = Future.value();
  var _edits = 0;
  var _failures = 0;
  var _disposed = false;

  /// Tells the screens, unless the session is over.
  void notify() {
    if (!_disposed) notifyListeners();
  }

  /// Applies [change] to the feedback, keeps it on the phone and schedules
  /// a save.
  void edit(void Function(ReviewState state) change) {
    change(state);
    _changed();
    notify();
    _later(saveDelay);
  }

  void _changed() {
    dirty = true;
    _edits++;
    keep();
  }

  void _later(Duration wait) {
    _timer?.cancel();
    if (!_disposed) _timer = Timer(wait, () => unawaited(sync()));
  }

  /// Adds [idea]; its [picture] waits on the phone and goes up with the
  /// next send, and the idea gets the server's name for it then.
  Future<void> addIdea(Idea idea, Picture? picture) async {
    if (picture != null) {
      await keeper.addRef(idea.at, picture.bytes, picture.mime);
    }
    edit(
      (s) => s.ideas.add(
        picture == null
            ? idea
            : (text: idea.text, ref: idea.ref, image: '', at: idea.at),
      ),
    );
  }

  /// Saves now.
  Future<void> save() {
    _timer?.cancel();
    return sync();
  }

  /// Sends what waits, one send at a time: the ideas' pictures, then the
  /// feedback. A failure keeps it all and tries again later by itself; a
  /// server error is reported once per run of failures.
  Future<void> sync() => _sending = _sending.then((_) => _send());

  Future<void> _send() async {
    if (_disposed || api.token.isEmpty) return;
    try {
      await _sendRefs();
      if (dirty) {
        final edits = _edits;
        await api.save(state);
        // An edit made while this one was on its way still waits.
        if (edits == _edits) {
          dirty = false;
          keep();
        }
      }
      _failures = 0;
    } on Object catch (e, stack) {
      // Offline is expected and only waits; a server error or a bug is told.
      final told = e is ApiException || e is Error;
      if (told && _failures == 0) onError?.call(e, stack);
      _later(retryDelay * pow(2, min(_failures++, 6)));
    }
    notify();
  }

  Future<void> _sendRefs() async {
    for (final r in await keeper.refs()) {
      final bytes = await keeper.refBytes(r.at);
      final file = bytes == null ? '' : await api.uploadRef(bytes, r.mime);
      final i = state.ideas.indexWhere((idea) => idea.at == r.at);
      if (i >= 0 && file.isNotEmpty) {
        final idea = state.ideas[i];
        state.ideas[i] = (
          text: idea.text,
          ref: idea.ref,
          image: file,
          at: idea.at,
        );
        _changed();
      }
      await keeper.dropRef(r.at);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
