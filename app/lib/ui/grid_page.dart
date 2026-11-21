/// The round at a glance: every logo, filters, and the ways onward.
library;

import 'package:design_system/design_system.dart';
import 'package:kuhy_credit/kuhy_credit.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/compare_page.dart';
import 'package:logo_review/ui/ideas_page.dart';
import 'package:logo_review/ui/review_page.dart';
import 'package:logo_review/ui/services.dart';
import 'package:logo_review/ui/share.dart';
import 'package:logo_review/ui/share_button.dart';
import 'package:logo_review/ui/tile.dart';
import 'package:logo_review/ui/type_bar.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

const List<(String, IconData, String)> _verdicts = [
  ('all', Icons.grid_view, 'All logos'),
  ('none', Icons.radio_button_unchecked, 'Not judged yet'),
  ('approve', Icons.check, 'Approved'),
  ('improve', Icons.edit_outlined, 'Needs improvement'),
  ('reject', Icons.close, 'Rejected'),
];

/// The grid of the round's logos.
class GridPage extends StatefulWidget {
  /// Shows the session [c].
  const new(this.c, this.services, {super.key});

  /// The session.
  final ReviewController c;

  /// Share sheet and gallery.
  final Services services;

  @override
  State<GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  ReviewController get c => widget.c;

  @override
  void initState() {
    super.initState();
    // Every type has its finalist: go straight on to choosing the winner.
    if (winnerWaits(c.manifest, c.state)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _compare('*'));
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _compare(String type) => _push(ComparePage(c, widget.services, type));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = c.visible;
    const gap = SizedBox(width: 6);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                spacing: 6,
                children: [
                  Row(
                    children: [
                      IconToggle(
                        key: const ValueKey('tool-all'),
                        label: 'All tools',
                        icon: Icons.grid_view,
                        selected: c.tool == 'all',
                        onTap: () => c.filter(tool: 'all'),
                      ),
                      for (final t in c.manifest.tools) ...[
                        gap,
                        IconToggle(
                          key: ValueKey('tool-$t'),
                          label: '$t only',
                          selected: c.tool == t,
                          onTap: () => c.filter(tool: t),
                          child: sizedLogo(
                            c.pictures,
                            '/img/$t/${c.manifest.ids.lastWhere((id) => c.manifest.draws(t, id))}-c.png',
                            34,
                            radius: 0.12,
                          ),
                        ),
                      ],
                      const Spacer(),
                      ShareButton(
                        key: const ValueKey('share-all'),
                        label: 'Share every logo as one picture',
                        services: widget.services,
                        render: () => galleryPicture(c),
                      ),
                      gap,
                      Badge(
                        isLabelVisible: c.state.ideas.isNotEmpty,
                        label: Text('${c.state.ideas.length}'),
                        backgroundColor: scheme.primary,
                        textColor: AppPalette.onFill,
                        child: IconToggle(
                          key: const ValueKey('ideas'),
                          label: 'Suggest a new direction',
                          icon: Icons.lightbulb_outline,
                          onTap: () => _push(IdeasPage(c, widget.services)),
                        ),
                      ),
                      gap,
                      // The shared credit: logo only; a tap opens its panel.
                      const KuhyCredit(size: 34, below: true),
                    ],
                  ),
                  Row(
                    children: [
                      for (final (id, icon, label) in _verdicts) ...[
                        IconToggle(
                          key: ValueKey('show-$id'),
                          label: label,
                          icon: icon,
                          selected: c.verdict == id,
                          onTap: () => c.filter(verdict: id),
                        ),
                        gap,
                      ],
                      const Spacer(),
                      Text(
                        '${visible.length}',
                        key: const ValueKey('shown'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SavedDot(dirty: c.dirty),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TypeBar(c, current: null, onPick: _compare),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Icon(
                      Icons.search_off,
                      key: const ValueKey('empty'),
                      size: 96,
                      color: scheme.onSurfaceVariant,
                    )
                  : FitGrid(
                      key: ValueKey('grid-${c.tool}-${c.verdict}'),
                      itemCount: visible.length,
                      labelHeight: tileLabel,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      itemBuilder: (context, i) => LogoTile(
                        c,
                        visible[i],
                        key: ValueKey('tile-${visible[i]}'),
                        onOpen: () =>
                            _push(ReviewPage(c, widget.services, visible[i])),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green dot when everything is saved, an accent square while a change waits.
class SavedDot extends StatelessWidget {
  /// Shows the [dirty] state.
  const new({required this.dirty, super.key});

  /// Whether a change waits to be saved.
  final bool dirty;

  @override
  Widget build(BuildContext context) => Semantics(
    label: dirty ? 'Saving' : 'Saved',
    child: Container(
      key: ValueKey(dirty ? 'unsaved' : 'saved'),
      width: 14,
      height: 14,
      decoration: dirty
          ? BoxDecoration(
              border: Border.all(color: AppPalette.accent, width: 3),
              borderRadius: BorderRadius.circular(2),
            )
          : const BoxDecoration(color: likeColor, shape: BoxShape.circle),
    ),
  );
}
