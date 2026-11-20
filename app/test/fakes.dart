// A review server in memory, for every test: the same routes as server.py.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/store.dart';
import 'package:logo_review/ui/app.dart';
import 'package:logo_review/ui/services.dart';

/// A 1x1 PNG.
final Uint8List png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
  ),
);

Map<String, dynamic> manifestJson() => {
  'round': 3,
  'tools': ['css', 'rough'],
  'modes': {
    'css': ['c'],
    'rough': ['c'],
  },
  'ids': ['A1', 'A2', 'B1'],
  'names': {'A1': 'a', 'A2': 'b', 'B1': 'c'},
  'types': {'A': 'letter A', 'B': 'letter B'},
  'skip': {
    'rough': ['A2', 'B1'],
  },
};

class FakeServer {
  FakeServer({this.token = 'device-key', Map<String, dynamic>? state})
    : state = state ?? {'logos': <String, dynamic>{}, 'ideas': <dynamic>[]};

  final String token;
  String code = '123456';
  Map<String, dynamic> state;
  Map<String, dynamic> manifest = manifestJson();
  Map<String, dynamic> history = {
    'steps': {
      'A1': [
        {'round': 1, 'id': 'a1', 'text': 'first try'},
        {'round': 2, 'id': 'A1', 'text': 'made bolder'},
        {'round': 3, 'id': 'A1', 'text': 'now flat'},
      ],
    },
    'said': {
      '2': {
        'css/A1-c': {
          'verdict': 'improve',
          'note': 'too thin',
          'marks': [
            {
              'kind': 'rect',
              'like': false,
              'x1': .1,
              'y1': .1,
              'x2': .5,
              'y2': .5,
              'text': 'this arm',
            },
          ],
        },
      },
    },
    'tools': {
      '1': <String>[],
      '2': ['css'],
    },
  };
  Map<String, dynamic> claude = {
    'rationale': {
      'designs': {'A1': 'Why A1 looks like this.'},
      'tools': {'css': 'Drawn with CSS.'},
    },
    'answers': <String, dynamic>{},
  };
  int saves = 0;
  int failWith = 0;
  bool down = false;
  final errors = <Map<String, dynamic>>[];
  final refs = <String>[];
  final requests = <String>[];

  /// Services whose logo the server has not fetched (404).
  final missingLogos = <String>{};

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path;
    requests.add('${r.method} $path');
    if (down) throw http.ClientException('down');
    if (failWith != 0) return http.Response('', failWith);
    http.Response json(Object v) => http.Response.bytes(
      utf8.encode(jsonEncode(v)),
      200,
      headers: {'content-type': 'application/json'},
    );
    if (path == '/api/pair') {
      final offered = (jsonDecode(r.body) as Map)['code'];
      return offered == code ? json({'token': token}) : http.Response('', 403);
    }
    if (r.headers['Authorization'] != 'Bearer $token') {
      return http.Response('', 403);
    }
    switch (path) {
      case '/api/manifest':
        return json(manifest);
      case '/api/state':
        if (r.method == 'PUT') {
          state = jsonDecode(r.body) as Map<String, dynamic>;
          saves++;
          return json({});
        }
        return json(state);
      case '/api/history':
        return json(history);
      case '/api/claude':
        return json(claude);
      case '/api/ref':
        refs.add(r.headers['Content-Type']!);
        return json({'file': 'abc.png'});
      case '/api/error':
        errors.add(jsonDecode(r.body) as Map<String, dynamic>);
        return json({});
    }
    if (missingLogos.any((id) => path == '/services/$id.png')) {
      return http.Response('', 404);
    }
    if (path.endsWith('missing.png')) return http.Response('', 404);
    if (path.endsWith('.png')) return http.Response.bytes(png, 200);
    return http.Response('', 404);
  }
}

class FakeServices {
  final shared = <Uint8List>[];
  PickedImage? picked;
  bool failShare = false;

  Services get services => Services(
    share: (bytes) async {
      if (failShare) throw Exception('no share');
      shared.add(bytes);
    },
    pickImage: () async => picked,
  );
}

ReviewController controllerFor(
  FakeServer server, {
  String token = 'device-key',
  void Function(Object, StackTrace)? onError,
}) => ReviewController(
  ReviewApi(server.client, base: 'http://test'),
  MemoryTokenStore(token),
  onError: onError,
  saveDelay: const Duration(milliseconds: 10),
);

/// Pixel 6a: 1080 x 2400 at 2.625.
Future<void> usePixel(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Starts the app on a paired device and waits for the grid.
Future<ReviewController> pumpApp(
  WidgetTester tester,
  FakeServer server, {
  FakeServices? services,
  String token = 'device-key',
}) async {
  await usePixel(tester);
  final c = controllerFor(server, token: token);
  await tester.pumpWidget(
    LogoReviewApp(
      controller: c,
      services: (services ?? FakeServices()).services,
    ),
  );
  await settle(tester);
  return c;
}

/// Lets fake network answers and picture decodes land.
Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder k(String key) => find.byKey(ValueKey(key));
