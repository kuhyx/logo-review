/// Draws the reviewer's marks over a logo.
library;

import 'dart:math' as math;

import 'package:logo_review/models.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Paints [marks] (numbered) and an unfinished [draft] over a square logo.
/// A disliked part is dashed as well as red: never colour alone.
class MarksPainter extends CustomPainter {
  /// [card] and [ink] colour the number discs.
  new(
    this.marks, {
    required this.card,
    required this.ink,
    this.draft,
    this.disc = 22,
  });

  /// The finished marks.
  final List<Mark> marks;

  /// The mark being drawn.
  final Mark? draft;

  /// Number disc fill.
  final Color card;

  /// Number colour.
  final Color ink;

  /// Disc radius, in thousandths of the logo's side.
  final double disc;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 1000;
    for (final (i, mark) in marks.indexed) {
      _shape(canvas, size, mark);
      final centre = Offset(mark.x1 * size.width, mark.y1 * size.height);
      final colour = mark.like ? likeColor : dislikeColor;
      canvas
        ..drawCircle(centre, disc * u, Paint()..color = card)
        ..drawCircle(
          centre,
          disc * u,
          Paint()
            ..color = colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * u,
        );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: ink,
            fontSize: 26 * u * disc / 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, centre - text.size.center(Offset.zero));
    }
    if (draft case final d?) _shape(canvas, size, d);
  }

  void _shape(Canvas canvas, Size size, Mark m) {
    final u = size.width / 1000;
    final a = Offset(m.x1 * size.width, m.y1 * size.height);
    final b = Offset(m.x2 * size.width, m.y2 * size.height);
    final colour = m.like ? likeColor : dislikeColor;
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * u;
    final path = Path();
    switch (m.kind) {
      case 'rect':
        path.addRect(Rect.fromPoints(a, b));
      case 'ellipse':
        path.addOval(Rect.fromPoints(a, b));
      case 'arrow':
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
        final angle = (b - a).direction;
        Offset wing(double turn) =>
            b - Offset.fromDirection(angle + turn, 30 * u);
        canvas.drawPath(
          Path()..addPolygon([b, wing(0.5), wing(-0.5)], true),
          Paint()..color = colour,
        );
      default:
        canvas.drawCircle(a, 6 * u, stroke);
        return;
    }
    canvas.drawPath(m.like ? path : dashed(path, 18 * u, 10 * u), stroke);
  }

  @override
  bool shouldRepaint(MarksPainter old) => true;
}

/// [source] cut into dashes of length [on] with gaps of [off].
Path dashed(Path source, double on, double off) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    for (var at = 0.0; at < metric.length; at += on + off) {
      out.addPath(
        metric.extractPath(at, math.min(at + on, metric.length)),
        Offset.zero,
      );
    }
  }
  return out;
}
