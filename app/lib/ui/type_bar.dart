/// One button per type of logo, and the star for the final line-up.
library;

import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The row of type buttons. A picked type is underlined in green; the star
/// pulses in the accent while the winner is still open.
class TypeBar extends StatelessWidget {
  /// [current] is the line-up on show, if any; [onPick] opens one.
  const new(this.c, {required this.current, required this.onPick, super.key});

  /// The session.
  final ReviewController c;

  /// The line-up on show.
  final String? current;

  /// Opens the line-up of a type (`*` for the final).
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final waits = winnerWaits(c.manifest, c.state);
    Widget picked(Widget child, {required bool on}) => Stack(
      alignment: Alignment.bottomCenter,
      children: [
        child,
        if (on)
          const IgnorePointer(
            child: SizedBox(
              width: 44,
              height: 3,
              child: ColoredBox(color: likeColor),
            ),
          ),
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 6,
        children: [
          for (final t in c.manifest.types.keys)
            picked(
              IconToggle(
                key: ValueKey('type-$t'),
                label: 'Compare the ${c.manifest.types[t]} variants',
                selected: current == t,
                onTap: () => onPick(t),
                child: Text(t),
              ),
              on: c.state.picks.containsKey(t),
            ),
          picked(
            IconToggle(
              key: const ValueKey('type-*'),
              label: 'Compare the picked finalists',
              tooltip: 'Finalists',
              icon: waits ? Icons.star : Icons.star_border,
              selected: current == '*' || waits,
              onTap: c.state.picks.isEmpty ? null : () => onPick('*'),
            ),
            on: c.state.winner != null,
          ),
        ],
      ),
    );
  }
}
