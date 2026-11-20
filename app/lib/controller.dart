/// The review session: loads the round, holds the feedback, saves changes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/logic.dart' as logic;
import 'package:logo_review/models.dart';
import 'package:logo_review/past.dart';
import 'package:logo_review/pictures.dart';
import 'package:logo_review/store.dart';

/// Where the session stands.
enum Phase {
  /// Reading the saved key or the round.
  loading,

  /// No key, or the server refused it: ask for a pairing code.
  unpaired,

  /// The round is on screen.
  ready,

  /// The server could not be reached.
  offline,
}

/// Holds everything the screens show and notifies them on change.
class ReviewController extends ChangeNotifier {
  /// Talks through [api], keeps the key in [store], reports to [onError].
  new(
    this.api,
    this.store, {
    this.onError,
    this.saveDelay = const Duration(milliseconds: 350),
  });

  /// The server.
  final ReviewApi api;

  /// The key store.
  final TokenStore store;

  /// Told about failures that are not "offline" or "unpaired".
  final void Function(Object error, StackTrace stack)? onError;

  /// The round's pictures.
  late final PictureCache pictures = PictureCache(api.picture);

  /// How long to gather changes before one save.
  final Duration saveDelay;

  /// Where the session stands.
  Phase phase = Phase.loading;

  /// The round on show.
  Manifest manifest = Manifest.fromJson(const {});

  /// The feedback.
  ReviewState state = ReviewState();

  /// Earlier rounds.
  History history = History();

  /// The designer's words.
  Designer designer = Designer();

  /// Tool filter (`all` or a tool).
  String tool = 'all';

  /// Verdict filter (`all`, `none`, or a verdict).
  String verdict = 'all';

  /// Whether a change waits to be saved.
  bool dirty = false;

  /// Whether the last pairing code was refused.
  bool codeRefused = false;

  Timer? _timer;

  /// The logos that pass the filters.
  List<String> get visible =>
      logic.visibleKeys(manifest, state, tool: tool, verdict: verdict);

  /// Reads the key and loads the round.
  Future<void> start() async {
    api.token = await store.read();
    await load();
  }

  /// Loads the round with the current key.
  Future<void> load() async {
    if (api.token.isEmpty) return _to(Phase.unpaired);
    _to(Phase.loading);
    try {
      manifest = await api.manifest();
      state = await api.state();
      history = await api.history();
      designer = await api.designer();
      _to(Phase.ready);
    } on ApiException catch (e, stack) {
      if (!e.refused) onError?.call(e, stack);
      _to(e.refused ? Phase.unpaired : Phase.offline);
    } on Exception {
      _to(Phase.offline);
    }
  }

  void _to(Phase next) {
    phase = next;
    notifyListeners();
  }

  /// Pairs with the [code] shown on the computer, then loads the round.
  Future<void> pair(String code) async {
    codeRefused = false;
    try {
      await store.write(await api.pair(code));
    } on ApiException catch (e) {
      codeRefused = e.refused;
      return _to(e.refused ? Phase.unpaired : Phase.offline);
    } on Exception {
      return _to(Phase.offline);
    }
    await load();
  }

  /// Sets the filters.
  void filter({String? tool, String? verdict}) {
    this.tool = tool ?? this.tool;
    this.verdict = verdict ?? this.verdict;
    notifyListeners();
  }

  /// Applies [change] to the feedback and schedules a save.
  void edit(void Function(ReviewState state) change) {
    change(state);
    dirty = true;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(saveDelay, () => unawaited(save()));
  }

  /// Saves now. A failure keeps the change marked as unsaved.
  Future<void> save() async {
    _timer?.cancel();
    try {
      await api.save(state);
      dirty = false;
    } on Exception catch (e, stack) {
      if (e is ApiException) onError?.call(e, stack);
    }
    notifyListeners();
  }

  /// Fetches answers written since the round was loaded.
  Future<void> refreshAnswers() async {
    try {
      designer = await api.designer();
      notifyListeners();
    } on Exception {
      // The answers on screen stay; the next opening tries again.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
