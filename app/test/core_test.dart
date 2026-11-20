import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/errors.dart';
import 'package:logo_review/pictures.dart';
import 'package:logo_review/store.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('api', () {
    test('pairs with a code and then reads the round', () async {
      final server = FakeServer();
      final api = ReviewApi(server.client, base: 'http://test');
      expect(api.headers, isEmpty);
      await expectLater(
        api.manifest(),
        throwsA(
          isA<ApiException>().having((e) => e.refused, 'refused', isTrue),
        ),
      );
      await expectLater(api.pair('999999'), throwsA(isA<ApiException>()));
      expect(await api.pair('123456'), 'device-key');
      expect((await api.manifest()).round, 3);
      expect((await api.history()).steps['A1'], hasLength(3));
      expect((await api.designer()).designs['A1'], contains('Why'));
      expect(await api.picture('/img/css/A1-c.png'), png);
      expect(await api.uploadRef(Uint8List(3), 'image/png'), 'abc.png');
      expect(server.refs, ['image/png']);
      await api.report({'error': 'x'});
      expect(server.errors.single['error'], 'x');
      final state = await api.state()
        ..entry('css/A1-c').note = 'hi';
      await api.save(state);
      expect(server.state['logos']['css/A1-c']['note'], 'hi');
      expect(const ApiException(500, '/x').refused, isFalse);
      expect('${const ApiException(500, '/x')}', 'ApiException(500 /x)');
      expect(defaultBase, startsWith('https://'));
    });
  });

  group('store', () {
    test('the keystore keeps the key', () async {
      FlutterSecureStorage.setMockInitialValues({});
      // Not const: the constructor must run for the coverage gate to see it.
      final storage = [const FlutterSecureStorage()].first;
      final store = SecureTokenStore(storage);
      expect(await store.read(), '');
      await store.write('k');
      expect(await store.read(), 'k');
    });
  });

  group('pictures', () {
    test('a picture is fetched once; a failure is retried', () async {
      var calls = 0;
      var fail = true;
      final cache = PictureCache((path) async {
        calls++;
        if (fail) throw Exception('no');
        return png;
      });
      await expectLater(cache.bytes('/a'), throwsException);
      fail = false;
      expect(await cache.bytes('/a'), png);
      expect(await cache.bytes('/a'), png);
      expect(calls, 2);
    });
  });

  group('errors', () {
    test('an error is shown and reported once a minute', () async {
      var now = DateTime.utc(2026);
      final sent = <Map<String, dynamic>>[];
      final reporter = ErrorReporter((e) async => sent.add(e), now: () => now);
      reporter
        ..report('boom', StackTrace.fromString('a\nb'))
        ..report('boom', null);
      expect(reporter.last.value, 'boom');
      expect(sent, hasLength(1));
      expect(sent.single['stack'], ['a', 'b']);
      expect(sent.single['mark'], 'package:logo_review/');
      now = now.add(const Duration(minutes: 2));
      reporter.report('boom', null);
      expect(sent, hasLength(2));
    });

    test(
      'uncaught errors reach the reporter, and a failed send is swallowed',
      () async {
        final kinds = <Object?>[];
        final reporter = ErrorReporter((e) async {
          kinds.add(e['kind']);
          throw Exception('offline');
        });
        final before = FlutterError.onError;
        final beforePlatform = PlatformDispatcher.instance.onError;
        addTearDown(() {
          FlutterError.onError = before;
          PlatformDispatcher.instance.onError = beforePlatform;
        });
        reporter.install();
        FlutterError.onError!(FlutterErrorDetails(exception: 'a'));
        expect(
          PlatformDispatcher.instance.onError!('b', StackTrace.empty),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        expect(kinds, ['uncaught.flutter', 'uncaught.flutter']);
        expect(ErrorReporter((_) async {}).now().year, greaterThan(2025));
      },
    );
  });

  group('controller', () {
    test('without a key it asks to pair; a refused code says so', () async {
      final server = FakeServer();
      final c = controllerFor(server, token: '');
      await c.start();
      expect(c.phase, Phase.unpaired);
      await c.pair('000000');
      expect((c.phase, c.codeRefused), (Phase.unpaired, true));
      await c.pair('123456');
      expect((c.phase, c.codeRefused), (Phase.ready, false));
      expect(await c.store.read(), 'device-key');
      expect(c.visible, hasLength(4));
      c.filter(tool: 'rough');
      expect(c.visible, ['rough/A1-c']);
      c.filter(verdict: 'approve');
      expect(c.tool, 'rough');
      expect(c.visible, isEmpty);
      c.dispose();
    });

    test('a key the server no longer knows means pairing again', () async {
      final c = controllerFor(FakeServer(), token: 'old-key');
      await c.start();
      expect(c.phase, Phase.unpaired);
    });

    test(
      'an unreachable or broken server is "offline", and reported when broken',
      () async {
        final server = FakeServer()..down = true;
        final seen = <Object>[];
        final c = controllerFor(server, onError: (e, _) => seen.add(e));
        await c.start();
        expect(c.phase, Phase.offline);
        expect(seen, isEmpty);
        server
          ..down = false
          ..failWith = 500;
        await c.load();
        expect(c.phase, Phase.offline);
        expect(seen.single, isA<ApiException>());
        final pairing = controllerFor(server, token: '');
        await pairing.pair('123456');
        expect((pairing.phase, pairing.codeRefused), (Phase.offline, false));
        server
          ..failWith = 0
          ..down = true;
        await pairing.pair('123456');
        expect(pairing.phase, Phase.offline);
      },
    );

    test(
      'edits are gathered into one save; a failed save stays unsaved',
      () async {
        final server = FakeServer();
        final seen = <Object>[];
        final c = controllerFor(server, onError: (e, _) => seen.add(e));
        await c.start();
        c
          ..edit((s) => s.entry('css/A1-c').note = 'a')
          ..edit((s) => s.entry('css/A1-c').note = 'ab');
        expect(c.dirty, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect((c.dirty, server.saves), (false, 1));
        expect(server.state['logos']['css/A1-c']['note'], 'ab');
        server.failWith = 500;
        c.edit((s) => s.entry('css/A1-c').note = 'abc');
        await c.save();
        expect(c.dirty, isTrue);
        expect(seen, hasLength(1));
        server
          ..failWith = 0
          ..down = true;
        await c.save();
        expect((c.dirty, seen.length), (true, 1));
      },
    );

    test(
      'new answers are fetched on demand; a failure keeps the old ones',
      () async {
        final server = FakeServer();
        final c = controllerFor(server);
        await c.start();
        server.claude = {
          'answers': {
            'css/A1-c': [
              {'text': 'because', 'at': '2'},
            ],
          },
        };
        await c.refreshAnswers();
        expect(c.designer.answers['css/A1-c']!.single.text, 'because');
        server.down = true;
        await c.refreshAnswers();
        expect(c.designer.answers, isNotEmpty);
      },
    );
  });
}
