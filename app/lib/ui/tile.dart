/// One logo in the grid: picture, id, and what was said about it.
library;

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Height of the caption under a tile's picture.
const double tileLabel = 22;

/// A grid tile for the logo [logoKey].
class LogoTile extends StatelessWidget {
  /// Opens the logo through [onOpen].
  const new(this.c, this.logoKey, {required this.onOpen, super.key});

  /// The session.
  final ReviewController c;

  /// The logo.
  final String logoKey;

  /// Called on tap.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = c.state.logos[logoKey];
    final verdict = entry?.verdict;
    final talked = answered(c.state, c.designer, logoKey);
    final name = caption(c.manifest, logoKey);
    return Semantics(
      label: 'Review $name',
      button: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: LayoutBuilder(
            builder: (context, box) {
              final side = box.maxHeight - tileLabel < box.maxWidth
                  ? box.maxHeight - tileLabel
                  : box.maxWidth;
              return Column(
                children: [
                  SizedBox.square(
                    dimension: side,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: verdict == 'reject' ? 0.35 : 1,
                          child: LogoImage(c.pictures, '/img/$logoKey.png'),
                        ),
                        if (verdict != null)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              key: ValueKey('badge-$verdict'),
                              radius: 12,
                              backgroundColor: scheme.surface,
                              child: Icon(
                                verdictIcon(verdict),
                                size: 16,
                                color: verdictColor(verdict),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          if (talked != null)
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 12,
                              color: talked
                                  ? scheme.onSurfaceVariant
                                  : scheme.primary,
                            ),
                          if (entry != null && entry.marks.isNotEmpty)
                            Text(
                              ' ${entry.marks.length}',
                              textScaler: TextScaler.noScaling,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
