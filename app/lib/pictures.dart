/// The round's pictures, fetched once each and kept for the session.
library;

import 'dart:typed_data';

/// Caches picture bytes by server path.
class PictureCache {
  /// Fetches through [fetch] (the API's `picture`).
  new(this.fetch);

  /// Gets the bytes of a path from the server.
  final Future<Uint8List> Function(String path) fetch;

  final _bytes = <String, Future<Uint8List>>{};

  /// The bytes at [path]; a failed fetch is forgotten, so the next ask
  /// tries again.
  Future<Uint8List> bytes(String path) =>
      _bytes[path] ??= fetch(path).onError<Object>((error, stack) {
        _bytes.remove(path)?.ignore();
        return Future.error(error, stack);
      });
}
