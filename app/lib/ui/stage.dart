/// The opened logo, large, with the marks on it; a finger draws a new one.
library;

import 'package:logo_review/controller.dart';
import 'package:logo_review/models.dart';
import 'package:logo_review/ui/marks_painter.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The logo [logoKey] with its marks. While [onMark] is set, dragging draws a
/// shape of [kind]; a shape with no size is a slip, unless it is a point.
class Stage extends StatefulWidget {
  /// Creates the stage.
  const new(
    this.c,
    this.logoKey, {
    required this.kind,
    required this.like,
    this.onMark,
    super.key,
  });

  /// The session.
  final ReviewController c;

  /// The logo on show.
  final String logoKey;

  /// The shape tool.
  final String kind;

  /// Whether new marks are "like".
  final bool like;

  /// Receives a finished mark.
  final ValueChanged<Mark>? onMark;

  @override
  State<Stage> createState() => _StageState();
}

class _StageState extends State<Stage> {
  Mark? _draft;

  static double _unit(double v, double side) =>
      ((v / side).clamp(0, 1) * 1000).round() / 1000;

  void _down(PointerDownEvent e, double side) {
    final x = _unit(e.localPosition.dx, side);
    final y = _unit(e.localPosition.dy, side);
    setState(
      () => _draft = Mark(
        kind: widget.kind,
        like: widget.like,
        x1: x,
        y1: y,
        x2: x,
        y2: y,
      ),
    );
  }

  void _move(PointerMoveEvent e, double side) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      draft
        ..x2 = _unit(e.localPosition.dx, side)
        ..y2 = _unit(e.localPosition.dy, side);
    });
  }

  void _up() {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _draft = null);
    final tiny =
        (Offset(draft.x2, draft.y2) - Offset(draft.x1, draft.y1)).distance <
        0.015;
    if (draft.kind == 'point' || !tiny) widget.onMark?.call(draft);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marks = widget.c.state.logos[widget.logoKey]?.marks ?? const <Mark>[];
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final overlay = CustomPaint(
            key: const ValueKey('overlay'),
            painter: MarksPainter(
              marks,
              draft: _draft,
              card: scheme.surfaceContainerHighest,
              ink: scheme.onSurface,
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              LogoImage(
                widget.c.pictures,
                '/img/${widget.logoKey}.png',
                radius: 0.02,
              ),
              if (widget.onMark == null)
                overlay
              else
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _down(e, box.maxWidth),
                  onPointerMove: (e) => _move(e, box.maxWidth),
                  onPointerUp: (_) => _up(),
                  onPointerCancel: (_) => setState(() => _draft = null),
                  child: overlay,
                ),
            ],
          );
        },
      ),
    );
  }
}
