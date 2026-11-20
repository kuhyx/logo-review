/// One type's variants side by side, each as the smallest avatar: pick one
/// per type, then the winner among the finalists.
library;

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart' as logic;
import 'package:logo_review/ui/services.dart';
import 'package:logo_review/ui/share.dart';
import 'package:logo_review/ui/share_button.dart';
import 'package:logo_review/ui/type_bar.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The line-up of one type (`*`: the finalists), one logo per page.
class ComparePage extends StatefulWidget {
  /// Opens on the line-up of [type].
  const new(this.c, this.services, this.type, {super.key});

  /// The session.
  final ReviewController c;

  /// The share sheet.
  final Services services;

  /// The type to open on.
  final String type;

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  late String _type = widget.type;

  ReviewController get c => widget.c;

  void _pick(String key) => c.edit(
    (s) => setState(() => _type = logic.pick(c.manifest, s, _type, key)),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final cols = logic.lineUp(c.manifest, c.state, c.history, _type);
      final chosen = _type == '*' ? c.state.winner : c.state.picks[_type];
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              spacing: AppSpacing.sm,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    spacing: 6,
                    children: [
                      Expanded(
                        child: TypeBar(
                          c,
                          current: _type,
                          onPick: (t) => setState(() => _type = t),
                        ),
                      ),
                      ShareButton(
                        key: const ValueKey('share-line-up'),
                        label: 'Share this line-up as one picture',
                        services: widget.services,
                        render: () => lineUpPicture(c, _type),
                      ),
                      IconToggle(
                        key: const ValueKey('close'),
                        label: 'Close',
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    key: ValueKey('line-up-$_type'),
                    controller: PageController(viewportFraction: 0.86),
                    children: [
                      for (final col in cols)
                        _Column(
                          c,
                          col,
                          final_: _type == '*',
                          picked: col.key != null && col.key == chosen,
                          onPick: col.key == null
                              ? null
                              : () => _pick(col.key!),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Column extends StatelessWidget {
  const new(
    this.c,
    this.col, {
    required this.final_,
    required this.picked,
    required this.onPick,
  });

  final ReviewController c;
  final logic.Entrant col;
  final bool final_;
  final bool picked;
  final VoidCallback? onPick;

  Widget _sizes(Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        for (final size in const [20.0, 32.0, 48.0])
          sizedLogo(c.pictures, col.path, size, radius: 0.5),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final before = col.key == null; // last round's finalist: to compare only
    return Container(
      key: ValueKey('col-${col.key ?? col.name}'),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: before ? null : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: picked ? likeColor : scheme.outline,
          width: picked ? 3 : 1,
        ),
      ),
      child: Column(
        spacing: AppSpacing.sm,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.md,
            children: [
              Text(
                col.name,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (onPick != null)
                IconToggle(
                  key: ValueKey('pick-${col.key}'),
                  label: '${final_ ? 'Winner:' : 'Pick'} ${col.name}',
                  icon: final_
                      ? Icons.emoji_events_outlined
                      : Icons.star_border,
                  fill: likeColor,
                  selected: picked,
                  size: final_ ? 56 : 44,
                  onTap: onPick,
                ),
            ],
          ),
          Expanded(
            flex: 3,
            child: LogoImage(c.pictures, col.path, radius: 0.03),
          ),
          // The 20 px avatar, enlarged pixel for pixel: what 20 px really hold.
          Expanded(
            flex: 2,
            child: LogoImage(c.pictures, col.path, pixels: 20, radius: 0.5),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                _sizes(AppPalette.paper),
                _sizes(const Color(0xFF0D1117)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
