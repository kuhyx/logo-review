// R7: every screen fits a Pixel 6a without scrolling or overflow, with the
// system bars' insets, and the keyboard never covers a field or a control.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _insets = FakeViewPadding(top: 118, bottom: 63);
const _keyboard = FakeViewPadding(bottom: 800);

Future<void> _open(WidgetTester tester, {String? token}) async {
  await pumpApp(tester, FakeServer(), token: token ?? 'device-key');
  tester.view
    ..padding = _insets
    ..viewPadding = _insets;
  await settle(tester, 8);
}

void _keyboardUp(WidgetTester tester) => tester.view.viewInsets = _keyboard;

/// The keyboard's top edge, in logical pixels.
double _keyboardTop(WidgetTester tester) =>
    (2400 - 800) / tester.view.devicePixelRatio;

void main() {
  testWidgets('pairing: the code field stays above the keyboard', (
    tester,
  ) async {
    await _open(tester, token: '');
    _keyboardUp(tester);
    await settle(tester, 8);
    expect(
      tester.getRect(k('pair-code')).bottom,
      lessThanOrEqualTo(_keyboardTop(tester)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid: bars and tiles sit inside the safe area', (tester) async {
    await _open(tester);
    expect(
      tester.getRect(k('tool-all')).top,
      greaterThanOrEqualTo(118 / 2.625),
    );
    expect(
      tester.getRect(k('tile-css/A1-c')).bottom,
      lessThan((2400 - 63) / 2.625),
    );
    expect(tester.takeException(), isNull);
  });

  for (final (tab, field) in [(0, 'note-css/A1-c'), (1, 'ask')]) {
    testWidgets('review tab $tab: while typing nothing is under the keyboard', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(k('tile-css/A1-c'));
      await settle(tester, 8);
      final full = tester.getRect(k('overlay')).width;
      expect(
        full,
        greaterThan(300),
        reason: 'the logo is large when not typing',
      );
      await tester.tap(k('tab-$tab'));
      await settle(tester, 8);
      _keyboardUp(tester);
      await settle(tester, 8);
      final top = _keyboardTop(tester);
      expect(tester.getRect(k(field)).bottom, lessThanOrEqualTo(top));
      expect(tester.getRect(k('tab-3')).bottom, lessThanOrEqualTo(top));
      expect(tester.getRect(k('overlay')).width, lessThan(141));
      expect(
        k('shape-rect'),
        findsNothing,
        reason: 'drawing tools make room while typing',
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });
  }

  testWidgets('ideas: the form stays above the keyboard', (tester) async {
    await _open(tester);
    await tester.tap(k('ideas'));
    await settle(tester, 8);
    _keyboardUp(tester);
    await settle(tester, 8);
    expect(
      tester.getRect(k('idea-add')).bottom,
      lessThanOrEqualTo(_keyboardTop(tester)),
    );
    expect(tester.getRect(k('idea-text')).top, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compare: the whole column fits the screen', (tester) async {
    await _open(tester);
    await tester.tap(k('type-A'));
    await settle(tester, 8);
    expect(
      tester.getRect(k('col-css/A1-c')).bottom,
      lessThan((2400 - 63) / 2.625),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a small phone (360 x 640) still has no overflow', (
    tester,
  ) async {
    await pumpApp(tester, FakeServer());
    tester.view
      ..physicalSize = const Size(720, 1280)
      ..devicePixelRatio = 2;
    await settle(tester, 8);
    await tester.tap(k('tile-css/A1-c'));
    await settle(tester, 8);
    for (final tab in [1, 2, 3, 0]) {
      await tester.tap(k('tab-$tab'));
      await settle(tester, 8);
    }
    await tester.tap(k('close'));
    await settle(tester, 8);
    await tester.tap(k('type-A'));
    await settle(tester, 8);
    expect(tester.takeException(), isNull);
  });
}
