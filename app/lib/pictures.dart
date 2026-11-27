/// The round's pictures: kept on the phone, so they show offline and after a
/// restart, and fetched again in the background so a redrawn one catches up.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logo_review/local.dart';

/// Caches picture bytes by server path, in memory and in [disk].
class PictureCache {
  /// Fetches through [fetch] (the API's `picture`) and keeps in [disk].
  new(this.fetch, [LocalStore? disk]) : disk = disk ?? MemoryLocalStore();

  /// Gets the bytes of a path from the server.
  final Future<Uint8List> Function(String path) fetch;

  /// Where the pictures outlive the app.
  final LocalStore disk;

  final _bytes = <String, Future<Uint8List>>{};

  /// The bytes at [path]: the kept copy at once when there is one, else the
  /// server's. A failed fetch is forgotten, so the next ask tries again.
  Future<Uint8List> bytes(String path) => _bytes[path] ??= _load(path);

  Future<Uint8List> _load(String path) async {
    final kept = await disk.read(path);
    if (kept != null) {
      unawaited(_refresh(path, kept));
      return kept;
    }
    try {
      final got = await fetch(path);
      await disk.write(path, got);
      return got;
    } on Object {
      _bytes.remove(path)?.ignore();
      rethrow;
    }
  }

  /// Fetches [path] again; a changed picture replaces the kept one.
  Future<void> _refresh(String path, Uint8List kept) async {
    try {
      final got = await fetch(path);
      if (listEquals(got, kept)) return;
      await disk.write(path, got);
      _bytes[path] = Future.value(got);
    } on Exception {
      // Offline: the kept copy stays.
    }
  }
}
