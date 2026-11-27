import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/models.dart';
import 'package:logo_review/past.dart';
import 'package:logo_review/share_layout.dart';

import 'fakes.dart';

void main() {
  final manifest = Manifest.fromJson(manifestJson());

  test(
    'the manifest lists every drawn logo, skipping what a tool left out',
    () {
      expect(manifest.keys, ['css/A1-c', 'css/A2-c', 'css/B1-c', 'rough/A1-c']);
      final both = Manifest.fromJson({
        'tools': ['v'],
        'ids': ['A1'],
      });
      expect(both.keys, [
        'v/A1-m',
        'v/A1-c',
      ], reason: 'mono and colour by default');
      expect(both.round, 0);
      expect(
        Manifest.fromJson(const {'groups': 'junk', 'tools': 7}).keys,
        isEmpty,
      );
    },
  );

  test('keys parse into tool, id, mode and type', () {
    expect(parseKey('css/A1-c'), (tool: 'css', id: 'A1', mode: 'c', type: 'A'));
    expect(parseKey('x/a1'), (tool: 'x', id: 'a1', mode: 'c', type: 'a'));
    expect(parseKey('x/').type, '');
    expect(caption(manifest, 'css/A1-c'), 'A1');
    expect(caption(manifest, 'rough/A1-c'), 'A1 rough');
  });

  test('feedback round-trips and untouched entries are not stored', () {
    final state = ReviewState.fromJson({
      'logos': {
        'css/A1-c': {
          'verdict': 'approve',
          'note': 'n',
          'marks': [
            {
              'kind': 'arrow',
              'like': false,
              'x1': 0.1,
              'y1': 0.2,
              'x2': 0.3,
              'y2': 1,
              'text': 't',
            },
            {'x1': 'junk'},
          ],
          'thread': [
            {'text': 'why?', 'at': '2026-01-01'},
          ],
        },
        'css/A2-c': <String, dynamic>{},
      },
      'ideas': [
        {'text': 'i', 'ref': 'http://x', 'image': 'a.png', 'at': 't'},
      ],
      'picks': {'A': 'css/A1-c'},
      'winner': 'css/A1-c',
      'dropped': ['B'],
    });
    state.entry('css/B1-c');
    final json = state.toJson();
    expect((json['logos'] as Map).keys, ['css/A1-c']);
    final again = ReviewState.fromJson(json);
    final entry = again.logos['css/A1-c']!;
    expect(entry.marks.first.toJson(), {
      'kind': 'arrow',
      'like': false,
      'x1': 0.1,
      'y1': 0.2,
      'x2': 0.3,
      'y2': 1.0,
      'text': 't',
    });
    expect(entry.marks[1].kind, 'point');
    expect(entry.marks[1].like, isTrue);
    expect(entry.thread.single, (text: 'why?', at: '2026-01-01'));
    expect(again.ideas.single.ref, 'http://x');
    expect(again.winner, 'css/A1-c');
    expect(again.dropped, ['B']);
    expect(ReviewState.fromJson(const {}).toJson()['winner'], isNull);
    expect(Entry().touched, isFalse);
  });

  test('filters pass by tool and verdict; stepping wraps around', () {
    final state = ReviewState()
      ..entry('css/A1-c').verdict = 'approve'
      ..entry('css/A2-c').verdict = 'reject';
    expect(visibleKeys(manifest, state), hasLength(4));
    expect(visibleKeys(manifest, state, tool: 'rough'), ['rough/A1-c']);
    expect(visibleKeys(manifest, state, verdict: 'approve'), ['css/A1-c']);
    expect(visibleKeys(manifest, state, verdict: 'none'), [
      'css/B1-c',
      'rough/A1-c',
    ]);
    expect(stepKey(manifest.keys, 'css/A1-c', -1), 'rough/A1-c');
    expect(stepKey(manifest.keys, 'rough/A1-c', 1), 'css/A1-c');
  });

  test('a question is open until an answer comes after it', () {
    final state = ReviewState();
    final designer = Designer.fromJson({
      'rationale': {
        'designs': {'A1': 'why A1'},
        'tools': {'css': 'css tool'},
      },
      'answers': {
        'css/A1-c': [
          {'text': 'because', 'at': '2026-01-02'},
        ],
      },
    });
    expect(answered(state, designer, 'css/A1-c'), isNull);
    state.entry('css/A1-c').thread.add((text: 'q1', at: '2026-01-01'));
    expect(answered(state, designer, 'css/A1-c'), isTrue);
    state.entry('css/A1-c').thread.add((text: 'q2', at: '2026-01-03'));
    expect(answered(state, designer, 'css/A1-c'), isFalse);
    state.entry('css/A2-c').thread.add((text: 'q', at: '2026-01-03'));
    expect(answered(state, designer, 'css/A2-c'), isFalse);
    final talk = talkOf(state, designer, 'css/A1-c');
    expect(talk.map((t) => t.text), [
      'why A1\n\ncss tool',
      'q1',
      'because',
      'q2',
    ]);
    expect(talk.last, (text: 'q2', mine: true, open: true));
    expect(talk[1].open, isFalse);
    expect(talkOf(ReviewState(), Designer(), 'css/B1-c'), isEmpty);
  });

  test('picking: one finalist per type, then the winner', () {
    final state = ReviewState();
    expect(winnerWaits(manifest, state), isFalse);
    expect(pick(manifest, state, 'A', 'css/A1-c'), 'A');
    expect(
      pick(manifest, state, 'A', 'css/A1-c'),
      'A',
      reason: 'second tap clears',
    );
    expect(state.picks, isEmpty);
    pick(manifest, state, 'A', 'css/A1-c');
    expect(
      pick(manifest, state, 'B', 'css/B1-c'),
      '*',
      reason: 'all picked: on to the final',
    );
    expect(winnerWaits(manifest, state), isTrue);
    expect(pick(manifest, state, '*', 'css/A1-c'), '*');
    expect(state.winner, 'css/A1-c');
    expect(winnerWaits(manifest, state), isFalse);
    pick(manifest, state, 'A', 'css/A2-c');
    expect(state.winner, isNull, reason: 'the winner left the final');
    pick(manifest, state, '*', 'css/B1-c');
    pick(manifest, state, '*', 'css/B1-c');
    expect(state.winner, isNull);
    final dropped = ReviewState()..dropped = ['B'];
    expect(pick(manifest, dropped, 'A', 'css/A1-c'), '*');
    expect(winnerWaits(Manifest.fromJson(const {}), ReviewState()), isFalse);
  });

  test(
    'a line-up shows last round first, then this round, or the finalists',
    () {
      final history = History.fromJson({
        'steps': {
          'A1': [
            {'round': 2, 'id': 'A9', 'text': ''},
            {'round': 3, 'id': 'A1', 'text': ''},
          ],
        },
      });
      final state = ReviewState()..picks = {'B': 'css/B1-c'};
      expect(lineUp(manifest, state, history, 'A'), [
        (name: '2 · A9', path: '/old/2/A9-c.png', key: null),
        (name: 'A1', path: '/img/css/A1-c.png', key: 'css/A1-c'),
        (name: 'A2', path: '/img/css/A2-c.png', key: 'css/A2-c'),
        (name: 'A1 rough', path: '/img/rough/A1-c.png', key: 'rough/A1-c'),
      ]);
      expect(lineUp(manifest, state, history, '*'), [
        (name: 'B1', path: '/img/css/B1-c.png', key: 'css/B1-c'),
      ]);
    },
  );

  test('history carries what was said in each round', () {
    final history = History.fromJson(FakeServer().history);
    final past = pastOf(manifest, history, 'css/A1-c');
    expect(past.map((p) => p.path), [
      '/old/1/a1.png',
      '/old/2/A1-c.png',
      '/img/css/A1-c.png',
    ]);
    expect(past[1].verdict, 'improve');
    expect(past[1].said, '1. this arm\ntoo thin');
    expect(past[1].marks, hasLength(1));
    expect(past[0].said, '');
    expect(past[2].changed, 'now flat');
    expect(pastOf(manifest, History(), 'css/A1-c'), isEmpty);
  });

  test('history quotes the thread of an archived round too', () {
    final json = FakeServer().history;
    final said = (json['said'] as Map)['2'] as Map;
    final entry = <String, dynamic>{...said['css/A1-c'] as Map}
      ..['thread'] = [
        {'text': 'keep the corner free', 'at': '2026-11-27T10:00:00Z'},
      ];
    final history = History.fromJson({
      ...json,
      'said': {
        ...json['said'] as Map,
        '2': {...said, 'css/A1-c': entry},
      },
    });
    expect(
      pastOf(manifest, history, 'css/A1-c')[1].said,
      '1. this arm\ntoo thin\nkeep the corner free',
    );
  });

  test('an idea keeps only http links as references', () {
    final now = DateTime.utc(2026);
    expect(ideaFrom(' ', '', '', now), isNull);
    expect(ideaFrom('a', 'https://x.y', '', now)!.ref, 'https://x.y');
    final loose = ideaFrom('a', 'see x', 'p.png', now)!;
    expect((loose.text, loose.ref, loose.image), ('a\nsee x', '', 'p.png'));
    expect(loose.at, '2026-01-01T00:00:00.000Z');
  });
}
