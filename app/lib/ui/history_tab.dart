/// The same design in earlier rounds, ending with the one on show.
library;

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/marks_painter.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// One page per round of the design behind [logoKey]; opens on the newest.
/// Each page: the picture with the marks made then, what the reviewer said
/// (accent edge) and what changed for that round.
class HistoryTab extends StatelessWidget {
  /// Creates the tab.
  const new(this.c, this.logoKey, {super.key});

  /// The session.
  final ReviewController c;

  /// The logo.
  final String logoKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = pastOf(c.manifest, c.history, logoKey);
    if (steps.isEmpty) {
      return Icon(
        Icons.history_toggle_off,
        key: const ValueKey('no-history'),
        size: 64,
        color: scheme.onSurfaceVariant,
      );
    }
    return PageView(
      key: ValueKey('history-$logoKey'),
      controller: PageController(
        initialPage: steps.length - 1,
        viewportFraction: 0.94,
      ),
      children: [
        for (final step in steps)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    spacing: 6,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              '${step.round} · ${step.id.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (step.verdict != null)
                            Icon(
                              verdictIcon(step.verdict),
                              size: 20,
                              color: verdictColor(step.verdict),
                            ),
                        ],
                      ),
                      Flexible(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            foregroundPainter: MarksPainter(
                              step.marks,
                              card: scheme.surfaceContainerHighest,
                              ink: scheme.onSurface,
                              disc: 30,
                            ),
                            child: LogoImage(
                              c.pictures,
                              step.path,
                              radius: 0.03,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 6,
                      children: [
                        if (step.said.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              border: Border(
                                left: BorderSide(
                                  color: scheme.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(step.said),
                          ),
                        Text(step.changed),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
