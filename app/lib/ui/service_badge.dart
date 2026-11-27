/// The frame badge of an avatar place: the service's real logo, or its chip.
library;

import 'dart:typed_data';

import 'package:logo_review/pictures.dart';
import 'package:logo_review/ui/avatars.dart';
import 'package:material_ui/material_ui.dart';

/// The logo of [avatar]'s service from the server, in its brand colour on
/// light and white on [dark]; the chip while it loads and when there is none.
/// The round's [pictures] cache keeps it on the phone, so it shows offline.
class ServiceBadge extends StatefulWidget {
  /// Creates the badge.
  const new(this.pictures, this.avatar, {required this.dark, super.key});

  /// The round's pictures.
  final PictureCache pictures;

  /// The place.
  final Avatar avatar;

  /// Whether it sits on the dark preview.
  final bool dark;

  @override
  State<ServiceBadge> createState() => _ServiceBadgeState();
}

class _ServiceBadgeState extends State<ServiceBadge> {
  late final Future<Uint8List>? _logo = widget.avatar.id.isEmpty
      ? null
      : widget.pictures.bytes('/services/${widget.avatar.id}.png');

  @override
  Widget build(BuildContext context) {
    final a = widget.avatar;
    return Semantics(
      label: a.name,
      child: FutureBuilder<Uint8List>(
        future: _logo,
        builder: (context, snap) => snap.hasData
            ? SizedBox.square(
                key: ValueKey('badge-${a.id}'),
                dimension: 20,
                child: Image.memory(
                  snap.data!,
                  // One file per service: the dark preview tints it white.
                  color: widget.dark ? Colors.white : null,
                  colorBlendMode: BlendMode.srcIn,
                ),
              )
            : Container(
                key: ValueKey('chip-${a.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: a.color,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  a.chip,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}
