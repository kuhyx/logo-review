/// The discussion about one logo: the designer left, the reviewer right.
library;

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The thread of [logoKey] and a field to ask something.
class TalkTab extends StatefulWidget {
  /// Creates the tab.
  const new(this.c, this.logoKey, {super.key});

  /// The session.
  final ReviewController c;

  /// The logo.
  final String logoKey;

  @override
  State<TalkTab> createState() => _TalkTabState();
}

class _TalkTabState extends State<TalkTab> {
  final _ask = TextEditingController();

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ask.text.trim();
    if (text.isEmpty) return;
    _ask.clear();
    widget.c.edit(
      (s) => s.entry(widget.logoKey).thread.add((
        text: text,
        at: DateTime.now().toUtc().toIso8601String(),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final talk = talkOf(widget.c.state, widget.c.designer, widget.logoKey);
    return Column(
      spacing: 6,
      children: [
        Expanded(
          child: ListView.separated(
            reverse: true,
            itemCount: talk.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final m = talk[talk.length - 1 - i];
              return Align(
                alignment: m.mine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.92,
                  alignment: m.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    key: ValueKey(
                      m.open ? 'msg-open' : (m.mine ? 'msg-mine' : 'msg'),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: m.mine ? scheme.primary : scheme.outline,
                        // Asked, not answered yet: a heavier accent edge.
                        width: m.open ? 2.5 : 1,
                      ),
                    ),
                    child: Text(m.text),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 6,
          children: [
            Expanded(
              child: Semantics(
                label: 'Ask or say something about this logo',
                child: TextField(
                  key: const ValueKey('ask'),
                  controller: _ask,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ),
            IconToggle(
              key: const ValueKey('send'),
              label: 'Send',
              tooltip: 'Send',
              icon: Icons.send,
              onTap: _send,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
