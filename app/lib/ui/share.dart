/// The finished pictures to paste into a chat, drawn off screen.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/share_layout.dart';
import 'package:material_ui/material_ui.dart';

const _back = Color(0xFF3A3532);

Future<ui.Image> _decode(Uint8List bytes, {int? side}) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: side,
    targetHeight: side,
  );
  return (await codec.getNextFrame()).image;
}

class _Pen {
  factory(double width, double height) =>
      _Pen._(width, height, ui.PictureRecorder());

  new _(this.width, this.height, this._recorder) : canvas = Canvas(_recorder) {
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = _back);
  }

  final ui.PictureRecorder _recorder;
  final double width;
  final double height;
  final Canvas canvas;

  void image(ui.Image img, Rect to, {bool round = false, bool crisp = false}) {
    canvas.save();
    if (round) canvas.clipPath(Path()..addOval(to));
    canvas
      ..drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        to,
        Paint()
          ..filterQuality = crisp ? FilterQuality.none : FilterQuality.high,
      )
      ..restore();
  }

  void text(
    String s,
    Offset centreLeft,
    double size,
    Color c, {
    bool centred = false,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(
      canvas,
      centreLeft - Offset(centred ? p.width / 2 : 0, p.height / 2),
    );
  }

  Future<Uint8List> png() async {
    final img = await _recorder.endRecording().toImage(
      width.round(),
      height.round(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// The line-up of [type] as one picture. Per logo: its name, the logo big,
/// its 20 px round avatar enlarged pixel for pixel, and the avatar at 64, 48,
/// 32 and 20 px on a dark and a light strip.
Future<Uint8List> lineUpPicture(ReviewController c, String type) async {
  const pad = 28.0;
  const col = 384.0;
  const label = 76.0;
  const zoom = 240.0;
  const strip = 84.0;
  const zoomTop = label + col + pad;
  const stripTop = zoomTop + zoom + pad;
  final cols = lineUp(c.manifest, c.state, c.history, type);
  final pen = _Pen(
    pad + cols.length * (col + pad),
    stripTop + 2 * (strip + 12) + pad,
  );
  for (final (i, column) in cols.indexed) {
    final x = pad + i * (col + pad);
    final bytes = await c.pictures.bytes(column.path);
    final img = await _decode(bytes);
    // In the final one letter per logo is enough to vote with.
    final name = type == '*' ? column.name[0] : column.name;
    pen
      ..text(
        name,
        Offset(x + col / 2, label / 2),
        52,
        Colors.white,
        centred: true,
      )
      ..image(img, Rect.fromLTWH(x, label, col, col))
      ..image(
        await _decode(bytes, side: 20),
        Rect.fromLTWH(x + (col - zoom) / 2, zoomTop, zoom, zoom),
        round: true,
        crisp: true,
      );
    for (final (row, bg) in const [
      Color(0xFF313338),
      Color(0xFFF6F4F3),
    ].indexed) {
      final y = stripTop + row * (strip + 12);
      pen.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, col, strip),
          const Radius.circular(14),
        ),
        Paint()..color = bg,
      );
      var cx = x + 40;
      for (final size in const [64.0, 48.0, 32.0, 20.0]) {
        pen.image(
          img,
          Rect.fromLTWH(cx, y + (strip - size) / 2, size, size),
          round: true,
        );
        cx += size + 36;
      }
    }
  }
  return await pen.png();
}

/// Every logo of the round as one picture, for people to vote on. Per logo:
/// its label, the logo, its 20 px round avatar enlarged and at real size.
Future<Uint8List> galleryPicture(ReviewController c) async {
  const pad = 24.0;
  const logo = 200.0;
  const zoom = 100.0;
  const label = 40.0;
  const cell = logo + 12 + zoom;
  const rowH = label + logo;
  const head = 90.0;
  const perRow = 7;
  final rows = galleryRows(gallerySections(c.manifest));
  final pen = _Pen(
    head + perRow * (cell + pad) + pad,
    pad + rows.length * (rowH + pad),
  );
  for (final (r, row) in rows.indexed) {
    final y = pad + r * (rowH + pad);
    for (final part in row) {
      final x0 = head + part.at * (cell + pad);
      if (part.first) {
        pen.text(
          part.section.title,
          Offset(
            part.at == 0 ? head / 2 : x0 - (cell + pad) / 2 + pad,
            y + label + logo / 2,
          ),
          72,
          const Color(0xFFE0BC6E),
          centred: true,
        );
      }
      for (final (i, key) in part.keys.indexed) {
        final x = x0 + pad + i * (cell + pad);
        final bytes = await c.pictures.bytes('/img/$key.png');
        final img = await _decode(bytes);
        pen
          ..text(
            caption(c.manifest, key),
            Offset(x, y + label / 2),
            26,
            Colors.white,
          )
          ..image(img, Rect.fromLTWH(x, y + label, logo, logo))
          ..image(
            await _decode(bytes, side: 20),
            Rect.fromLTWH(x + logo + 12, y + label, zoom, zoom),
            round: true,
            crisp: true,
          );
        var cx = x + logo + 12;
        for (final size in const [20.0, 32.0]) {
          pen.image(
            img,
            Rect.fromLTWH(
              cx,
              y + label + zoom + 24 + (32 - size) / 2,
              size,
              size,
            ),
            round: true,
          );
          cx += size + 16;
        }
      }
    }
  }
  return await pen.png();
}
