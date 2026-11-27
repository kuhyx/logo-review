/// The review session: loads the round, holds the feedback, saves changes.
///
/// Offline-first: the round is shown from the phone's copy before the
/// server answers, every change is kept on the phone at once, and what waits
/// is sent by itself, retried until the server takes it.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/keeper.dart';
import 'package:logo_review/local.dart';
import 'package:logo_review/logic.dart' as logic;
import 'package:logo_review/models.dart';
import 'package:logo_review/outbox.dart';
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
class ReviewController extends ChangeNotifier with Outbox {
  /// Talks through [api], keeps the key in [store] and the round in
  /// [local], reports to [onError].
  new(
    this.api,
    this.store, {
    required this.local,
    this.onError,
    this.saveDelay = const Duration(milliseconds: 350),
    this.retryDelay = const Duration(seconds: 5),
  });

  @override
  final ReviewApi api;

  /// The key store.
  final TokenStore store;

  @override
  final void Function(Object error, StackTrace stack)? onError;

  /// The phone's files.
  final LocalStore local;

  /// The round's pictures.
  late final PictureCache pictures = PictureCache(api.picture, local);

  @override
  late final Keeper keeper = Keeper(local, onError: onError);

  @override
  final Duration saveDelay;

  @override
  final Duration retryDelay;

  /// Where the session stands.
  Phase phase = Phase.loading;

  /// The round on show.
  Manifest manifest = Manifest.fromJson(const {});

  @override
  ReviewState state = ReviewState();

  /// Earlier rounds.
  History history = History();

  /// The designer's words.
  Designer designer = Designer();

  /// Tool filter (`all` or a tool).
  String tool = 'all';

  /// Verdict filter (`all`, `none`, or a verdict).
  String verdict = 'all';

  /// Whether the last pairing code was refused.
  bool codeRefused = false;

  Json _raw = {};

  static const _paths = {
    'manifest': '/api/manifest',
    'state': '/api/state',
    'history': '/api/history',
    'claude': '/api/claude',
  };

  /// The logos that pass the filters.
  List<String> get visible =>
      logic.visibleKeys(manifest, state, tool: tool, verdict: verdict);

  /// Reads the key and loads the round.
  Future<void> start() async {
    api.token = await store.read();
    await load();
  }

  /// Loads the round with the current key: the kept copy first, then the
  /// server's. Changes not yet sent win over the server's feedback.
  Future<void> load() async {
    if (api.token.isEmpty) return _to(Phase.unpaired);
    final shown = phase == Phase.ready || await _showKept();
    if (!shown) _to(Phase.loading);
    try {
      final live = {
        for (final e in _paths.entries) e.key: await api.getJson(e.value),
      };
      if (dirty) live['state'] = state.toJson();
      _show(live);
      keep();
      _to(Phase.ready);
    } on ApiException catch (e, stack) {
      if (!e.refused) onError?.call(e, stack);
      if (e.refused) return _to(Phase.unpaired);
      if (!shown) _to(Phase.offline);
    } on Exception {
      if (!shown) _to(Phase.offline);
    }
    unawaited(sync());
  }

  Future<bool> _showKept() async {
    final kept = await keeper.round();
    if (kept == null) return false;
    _show(kept);
    dirty = kept['dirty'] == true;
    _to(Phase.ready);
    return true;
  }

  void _show(Json j) {
    _raw = {...j}..remove('dirty');
    manifest = Manifest.fromJson(asObject(j['manifest']));
    state = ReviewState.fromJson(asObject(j['state']));
    history = History.fromJson(asObject(j['history']));
    designer = Designer.fromJson(asObject(j['claude']));
  }

  @override
  void keep() => unawaited(
    keeper.keepRound({..._raw, 'state': state.toJson(), 'dirty': dirty}),
  );

  void _to(Phase next) {
    phase = next;
    notify();
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
    notify();
  }

  /// The app is back on screen: send what waits, or try the round again.
  Future<void> resume() async {
    if (phase == Phase.offline) {
      await load();
    } else if (phase == Phase.ready) {
      await sync();
    }
  }

  /// Fetches answers written since the round was loaded.
  Future<void> refreshAnswers() async {
    try {
      designer = Designer.fromJson(
        _raw['claude'] = await api.getJson('/api/claude'),
      );
      keep();
      notify();
    } on Exception {
      // The answers on screen stay; the next opening tries again.
    }
  }
}
