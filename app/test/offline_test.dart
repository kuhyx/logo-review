// Offline-first (~/.claude/rules/offline-first.instructions.md): feedback
// lands on the phone first and is sent by itself; the round and its pictures
// read offline and after a restart.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/local.dart';

import 'fakes.dart';

const _logo = '/img/css/A1-c.png';

/// Lets timers and the fake network run.
Future<void> wait([int ms = 80]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Map<String, dynamic> note(FakeServer s) =>
    (s.state['logos'] as Map)['css/A1-c'] as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('feedback written offline survives a restart and is sent unasked '
      'once the server is back', () async {
    final server = FakeServer();
    final local = MemoryLocalStore();
    final first = controllerFor(server, local: local);
    await first.start();
    server.down = true;
    first.edit((s) => s.entry('css/A1-c').note = 'kept');
    expect(first.state.entry('css/A1-c').note, 'kept');
    await wait();
    expect(first.dirty, isTrue);
    first.dispose(); // the app is killed with the change unsent

    final second = controllerFor(server, local: local);
    await second.start();
    expect(second.phase, Phase.ready);
    expect(second.state.entry('css/A1-c').note, 'kept');
    expect(second.dirty, isTrue);
    server.down = false;
    await wait(200);
    expect(note(server)['note'], 'kept');
    expect(second.dirty, isFalse);
    second.dispose();
  });

  test('the round and its pictures read offline after a restart', () async {
    final server = FakeServer();
    final local = MemoryLocalStore();
    final first = controllerFor(server, local: local);
    await first.start();
    expect(await first.pictures.bytes(_logo), png);
    first.dispose();
    server.down = true;
    final second = controllerFor(server, local: local);
    await second.start();
    expect(second.phase, Phase.ready);
    expect(second.manifest.round, 3);
    expect(second.history.steps['A1'], hasLength(3));
    expect(second.designer.designs['A1'], 'Why A1 looks like this.');
    expect(await second.pictures.bytes(_logo), png);
    second.dispose();
  });

  // The kept copy answers first; a changed file replaces it on disk.
  test(
    'a kept picture shows at once and is refreshed from the server',
    () async {
      final server = FakeServer();
      final local = MemoryLocalStore();
      await local.write(_logo, Uint8List.fromList([1, 2]));
      final c = controllerFor(server, local: local);
      c.api.token = 'device-key';
      expect(await c.pictures.bytes(_logo), [1, 2]);
      await wait();
      expect(await local.read(_logo), png);
      expect(await c.pictures.bytes(_logo), png);
      server.down = true;
      await local.write('/img/x.png', png);
      expect(
        await c.pictures.bytes('/img/x.png'),
        png,
      ); // refresh fails quietly
      await wait();
      c.dispose();
    },
  );

  test(
    'an idea with a picture is kept offline; the picture goes up later',
    () async {
      final server = FakeServer();
      final local = MemoryLocalStore();
      final first = controllerFor(server, local: local);
      await first.start();
      server.down = true;
      final idea = (text: 'round', ref: '', image: '', at: '2026-11-27T10:00Z');
      await first.addIdea(idea, (bytes: png, mime: 'image/png'));
      expect(first.state.ideas.single.text, 'round');
      await wait();
      first.dispose();

      final second = controllerFor(server, local: local);
      await second.start();
      expect(second.state.ideas.single.text, 'round');
      server.down = false;
      await wait(200);
      final sent = (server.state['ideas'] as List).single as Map;
      expect((sent['text'], sent['image']), ('round', 'abc.png'));
      expect(server.refs, ['image/png']);
      expect(second.state.ideas.single.image, 'abc.png');
      second.dispose();
    },
  );

  test(
    'a broken server is reported once while the save keeps retrying',
    () async {
      final server = FakeServer();
      final seen = <Object>[];
      final c = controllerFor(server, onError: (e, _) => seen.add(e));
      await c.start();
      server.failWith = 500;
      c.edit((s) => s.entry('css/A1-c').note = 'x');
      await wait(150);
      expect(seen.whereType<ApiException>(), hasLength(1));
      server.failWith = 0;
      await wait(400);
      expect(note(server)['note'], 'x');
      c.dispose();
    },
  );

  test('an edit made while a save is in flight stays unsaved', () async {
    final server = FakeServer();
    final c = controllerFor(server);
    await c.start();
    await wait(30); // the send after loading has nothing to do
    c.edit((s) => s.entry('css/A1-c').note = 'a');
    server.onRequest = (r) {
      server.onRequest = null;
      c.edit((s) => s.entry('css/A1-c').note = 'ab'); // while 'a' is sent
    };
    await c.save();
    expect((c.dirty, note(server)['note']), (true, 'a'));
    await wait();
    expect((c.dirty, note(server)['note']), (false, 'ab'));
    c.dispose();
  });

  test('coming back to the app sends what waits', () async {
    final server = FakeServer();
    final c = controllerFor(server);
    await c.start();
    server.down = true;
    c.edit((s) => s.entry('css/A1-c').note = 'r');
    await wait(30);
    server.down = false;
    await c.resume();
    expect((c.dirty, note(server)['note']), (false, 'r'));
    c.dispose();
  });

  test('coming back while offline tries the round again', () async {
    final server = FakeServer()..down = true;
    final local = MemoryLocalStore();
    await local.write('round.json', Uint8List.fromList([1, 2, 3]));
    final c = controllerFor(server, local: local);
    await c.start();
    expect(c.phase, Phase.offline); // a damaged copy is as good as none
    server.down = false;
    await c.resume();
    expect(c.phase, Phase.ready);
    c.dispose();
  });

  group('files on the phone', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('logo-local'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('keep, read and forget by name', () async {
      final store = FileLocalStore(Future.value(Directory('${dir.path}/d')));
      expect(await store.read('snapshot'), isNull);
      await store.write('snapshot', Uint8List.fromList([7]));
      expect(await store.read('snapshot'), [7]);
      await store.delete('snapshot');
      await store.delete('snapshot');
      expect(await store.read('snapshot'), isNull);
    });

    test(
      'pictures share a budget, oldest out first; the round stays',
      () async {
        final store = FileLocalStore(Future.value(dir), budget: 10);
        await store.write('snapshot', Uint8List(40));
        await store.write('/a.png', Uint8List(6));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await store.write('/b.png', Uint8List(6));
        expect(await store.read('/a.png'), isNull);
        expect(await store.read('/b.png'), hasLength(6));
        expect(await store.read('snapshot'), hasLength(40));
        await store.write('/c.png', Uint8List(12)); // alone over budget: kept
        expect(await store.read('/c.png'), hasLength(12));
        expect(await store.read('/b.png'), isNull);
      },
    );
  });
}
