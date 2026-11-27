/// What the app keeps on the phone (offline-first): the last round it
/// pulled, feedback and pictures not yet sent, and every picture it saw, so
/// the round reads offline and after a restart.
library;

import 'dart:io';
import 'dart:typed_data';

/// Named files of bytes that outlive the app.
abstract interface class LocalStore {
  /// The bytes saved as [name], or null.
  Future<Uint8List?> read(String name);

  /// Saves [bytes] as [name], replacing what was there.
  Future<void> write(String name, Uint8List bytes);

  /// Forgets [name].
  Future<void> delete(String name);
}

/// A store for tests and previews: gone with the app.
class MemoryLocalStore implements LocalStore {
  /// Files by name.
  final Map<String, Uint8List> files = {};

  @override
  Future<Uint8List?> read(String name) async => files[name];

  @override
  Future<void> write(String name, Uint8List bytes) async => files[name] = bytes;

  @override
  Future<void> delete(String name) async => files.remove(name);
}

/// Bytes of pictures kept at most; the least recently used go first.
const int kPictureBudget = 128 << 20;

/// Files in [dir], one per name. Pictures (names that are server paths,
/// starting with `/`) share [budget]; the round and the queue are never
/// evicted.
class FileLocalStore implements LocalStore {
  /// Keeps files in [dir], made on first use.
  new(this.dir, {this.budget = kPictureBudget});

  /// Where the files live.
  final Future<Directory> dir;

  /// Bytes of pictures kept at most.
  final int budget;

  var _tmp = 0;

  static const _picture = '%2F';

  Future<File> _file(String name) async =>
      File('${(await dir).path}/${Uri.encodeComponent(name)}');

  @override
  Future<Uint8List?> read(String name) async {
    final file = await _file(name);
    if (!file.existsSync()) return null;
    // Reading counts as use, so a picture on screen is the last to go.
    file.setLastModifiedSync(DateTime.now());
    return await file.readAsBytes();
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final file = await _file(name);
    await file.parent.create(recursive: true);
    // Written aside and renamed, so a killed app never leaves half a file.
    final tmp = File('${file.path}.${_tmp++}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    if (name.startsWith('/')) await _evict(file.path);
  }

  @override
  Future<void> delete(String name) async {
    final file = await _file(name);
    if (file.existsSync()) await file.delete();
  }

  Future<void> _evict(String keep) async {
    final pictures = [
      for (final f in (await dir).listSync().whereType<File>())
        if (f.path.split('/').last.startsWith(_picture) &&
            !f.path.endsWith('.tmp'))
          (file: f, stat: f.statSync()),
    ]..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    var total = pictures.fold(0, (sum, p) => sum + p.stat.size);
    for (final p in pictures) {
      if (total <= budget) break;
      if (p.file.path == keep) continue;
      await p.file.delete();
      total -= p.stat.size;
    }
  }
}
