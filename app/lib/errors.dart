/// Errors are loud and land on the computer: every uncaught error becomes one
/// report in the app-errors spool there (utils `DOCS-app-errors.md`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logo_review/models.dart';

/// The app's version code, set by the build.
const int buildNumber = int.fromEnvironment('BUILD_NUMBER');

/// Sends error reports, each distinct error at most once a minute.
class ErrorReporter {
  /// Reports go out through [send]; [now] is the clock.
  new(this.send, {DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Delivers one report; failures are swallowed (the report is about a
  /// failure already, and must not start a loop).
  final Future<void> Function(Json entry) send;

  /// The clock.
  final DateTime Function() now;

  /// The last error, for the screen to show.
  final ValueNotifier<String?> last = ValueNotifier(null);

  final _sent = <String, DateTime>{};

  /// Reports [error] of [kind] with its [stack].
  void report(Object error, StackTrace? stack, {String kind = 'error'}) {
    final text = '$error';
    last.value = text;
    final at = now();
    final before = _sent[text];
    if (before != null && at.difference(before).inSeconds < 60) return;
    _sent[text] = at;
    unawaited(
      send({
        'at': at.toUtc().toIso8601String(),
        'kind': kind,
        'error': text,
        'stack': '${stack ?? ''}'.split('\n').take(30).toList(),
        'repo': 'kuhyx/logo-review',
        'mark': 'package:logo_review/',
        'build': buildNumber,
      }).catchError((Object _) {}),
    );
  }

  /// Hooks the framework's and the platform's uncaught-error handlers.
  void install() {
    FlutterError.onError = (details) =>
        report(details.exception, details.stack, kind: 'uncaught.flutter');
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, kind: 'uncaught.flutter');
      return true;
    };
  }
}
