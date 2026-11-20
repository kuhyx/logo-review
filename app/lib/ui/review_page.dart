/// One logo, full screen: judge it, draw on it, talk about it.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/contexts_tab.dart';
import 'package:logo_review/ui/history_tab.dart';
import 'package:logo_review/ui/marks_tab.dart';
import 'package:logo_review/ui/services.dart';
import 'package:logo_review/ui/stage.dart';
import 'package:logo_review/ui/talk_tab.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

const List<(String, IconData, String)> _shapes = [
  ('point', Icons.fiber_manual_record, 'Point'),
  ('rect', Icons.crop_square, 'Rectangle'),
  ('ellipse', Icons.circle_outlined, 'Circle'),
  ('arrow', Icons.north_east, 'Arrow'),
];
const List<(IconData, String)> _tabs = [
  (Icons.edit_note, 'Note and marks'),
  (Icons.chat_bubble_outline, 'Discussion'),
  (Icons.devices, 'Where this logo will be shown'),
  (Icons.history, 'History of this design'),
];
const _verdicts = [
  ('approve', 'Approve'),
  ('improve', 'Request improvement'),
  ('reject', 'Reject'),
];

/// The review of one logo; the arrows step through the filtered logos.
class ReviewPage extends StatefulWidget {
  /// Opens on [first].
  const new(this.c, this.services, this.first, {super.key});

  /// The session.
  final ReviewController c;

  /// Share sheet and gallery.
  final Services services;

  /// The logo to open on.
  final String first;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late String _key = widget.first;
  var _kind = 'point';
  var _like = true;
  var _tab = 0;

  ReviewController get c => widget.c;

  @override
  void initState() {
    super.initState();
    unawaited(c.refreshAnswers()); // answers written since the round loaded
  }

  void _step(int delta) {
    final visible = c.visible;
    final list = visible.contains(_key) ? visible : c.manifest.keys;
    setState(() => _key = stepKey(list, _key, delta));
    unawaited(c.refreshAnswers());
  }

  void _verdict(String v) => c.edit((s) {
    final e = s.entry(_key);
    e.verdict = e.verdict == v ? null : v; // a second tap clears it
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final k = parseKey(_key);
      final verdict = c.state.logos[_key]?.verdict;
      final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: LayoutBuilder(
              builder: (context, box) {
                // The tab area keeps at least 190 px; while typing, the logo
                // shrinks to a thumbnail so the keyboard covers nothing.
                final most = box.maxHeight - 3 * 44 - 4 * 6 - 190;
                final side = typing
                    ? most.clamp(0.0, 140.0)
                    : most.clamp(120.0, box.maxWidth);
                return Column(
                  spacing: 6,
                  children: [
                    Row(
                      spacing: 6,
                      children: [
                        IconToggle(
                          key: const ValueKey('prev'),
                          label: 'Previous logo',
                          icon: Icons.chevron_left,
                          onTap: () => _step(-1),
                        ),
                        Expanded(
                          child: Text(
                            '${k.id} ${k.tool}',
                            key: const ValueKey('logo-id'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconToggle(
                          key: const ValueKey('next'),
                          label: 'Next logo',
                          icon: Icons.chevron_right,
                          onTap: () => _step(1),
                        ),
                        for (final (id, label) in _verdicts)
                          IconToggle(
                            key: ValueKey('verdict-$id'),
                            label: label,
                            icon: verdictIcon(id),
                            fill: verdictColor(id),
                            selected: verdict == id,
                            onTap: () => _verdict(id),
                          ),
                        IconToggle(
                          key: const ValueKey('close'),
                          label: 'Close',
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    if (side >= 60)
                      SizedBox.square(
                        dimension: side,
                        child: Stage(
                          c,
                          _key,
                          kind: _kind,
                          like: _like,
                          onMark: typing
                              ? null
                              : (m) => c.edit((s) {
                                  s.entry(_key).marks.add(m);
                                  _tab = 0;
                                }),
                        ),
                      ),
                    if (!typing)
                      Row(
                        spacing: 6,
                        children: [
                          for (final (id, icon, label) in _shapes)
                            IconToggle(
                              key: ValueKey('shape-$id'),
                              label: label,
                              icon: icon,
                              selected: _kind == id,
                              onTap: () => setState(() => _kind = id),
                            ),
                          const Spacer(),
                          IconToggle(
                            key: const ValueKey('like'),
                            label: 'I like this part',
                            icon: Icons.add,
                            fill: likeColor,
                            selected: _like,
                            onTap: () => setState(() => _like = true),
                          ),
                          IconToggle(
                            key: const ValueKey('dislike'),
                            label: 'I dislike this part',
                            icon: Icons.remove,
                            fill: dislikeColor,
                            selected: !_like,
                            onTap: () => setState(() => _like = false),
                          ),
                        ],
                      ),
                    Row(
                      spacing: 6,
                      children: [
                        for (final (i, (icon, label)) in _tabs.indexed)
                          Expanded(
                            child: IconToggle(
                              key: ValueKey('tab-$i'),
                              label: label,
                              icon: icon,
                              selected: _tab == i,
                              onTap: () => setState(() => _tab = i),
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: switch (_tab) {
                        0 => MarksTab(c, _key, key: ValueKey('marks-$_key')),
                        1 => TalkTab(c, _key, key: ValueKey('talk-$_key')),
                        2 => ContextsTab(c, _key),
                        _ => HistoryTab(c, _key),
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
