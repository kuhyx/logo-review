// The frame badge of each avatar place: the service's real logo from the
// server, white on dark, its chip when the server has no logo.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logo_review/api.dart';
import 'package:logo_review/pictures.dart';
import 'package:logo_review/ui/avatars.dart';
import 'package:logo_review/ui/service_badge.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

Avatar place(String id) => avatars.firstWhere((a) => a.id == id);

void main() {
  test('every service the server knows is a place, plus the square icon', () {
    expect(avatars.map((a) => a.id), [
      'linkedin', 'facebook', 'discord', 'github', 'signal', 'steam', //
      'whatsapp', 'telegram', 'instagram', 'x', 'reddit', 'youtube', //
      'slack', 'gmail', '',
    ]);
  });

  for (final dark in [false, true]) {
    testWidgets('badges ${dark ? 'on dark' : 'on light'}', (tester) async {
      final server = FakeServer()..missingLogos.add('gmail');
      final api = ReviewApi(server.client, base: 'http://test')
        ..token = server.token;
      final pictures = PictureCache(api.picture);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              for (final id in ['signal', 'gmail', ''])
                ServiceBadge(pictures, place(id), dark: dark),
            ],
          ),
        ),
      );
      await settle(tester);
      expect(server.requests, contains('GET /services/signal.png'));
      expect(k('badge-signal'), findsOneWidget);
      expect(k('chip-signal'), findsNothing);
      final logo = tester.widget<Image>(
        find.descendant(of: k('badge-signal'), matching: find.byType(Image)),
      );
      expect(logo.color, dark ? Colors.white : null);
      expect(tester.getSize(k('badge-signal')), const Size(20, 20));
      expect(k('chip-gmail'), findsOneWidget, reason: 'no logo: the chip');
      expect(k('chip-'), findsOneWidget, reason: 'the square icon');
      expect(server.requests.where((r) => r.contains('/services/')).length, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
