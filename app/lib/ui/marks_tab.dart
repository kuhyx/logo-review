/// The note about the whole logo and one comment line per mark.
library;

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Note and mark comments for [logoKey].
class MarksTab extends StatelessWidget {
  /// Creates the tab.
  const new(this.c, this.logoKey, {super.key});

  /// The session.
  final ReviewController c;

  /// The logo.
  final String logoKey;

  @override
  Widget build(BuildContext context) {
    final entry = c.state.entry(logoKey);
    return Column(
      spacing: 6,
      children: [
        Semantics(
          label: 'Note about the whole logo',
          child: TextFormField(
            key: ValueKey('note-$logoKey'),
            initialValue: entry.note,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.notes),
            ),
            onChanged: (v) => c.edit((s) => s.entry(logoKey).note = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: entry.marks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final mark = entry.marks[i];
              final colour = mark.like ? likeColor : dislikeColor;
              return Row(
                key: ObjectKey(mark),
                spacing: 6,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colour, width: 3),
                    ),
                    child: Text(
                      '${i + 1}',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(mark.like ? Icons.add : Icons.remove, color: colour),
                  Expanded(
                    child: Semantics(
                      label: 'Comment on mark ${i + 1}',
                      child: TextFormField(
                        key: ValueKey('mark-text-$i'),
                        initialValue: mark.text,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) => c.edit((_) => mark.text = v),
                      ),
                    ),
                  ),
                  IconToggle(
                    key: ValueKey('mark-delete-$i'),
                    label: 'Delete mark ${i + 1}',
                    tooltip: 'Delete',
                    icon: Icons.close,
                    onTap: () =>
                        c.edit((s) => s.entry(logoKey).marks.remove(mark)),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
