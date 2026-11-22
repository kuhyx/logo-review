/// Small shared pieces: the icon toggle and a picture from the server.
library;

import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:logo_review/pictures.dart';
import 'package:material_ui/material_ui.dart';

/// Green for "like" and approved.
const Color likeColor = Color(0xFF4F9A3C);

/// Red for "dislike" and rejected.
const Color dislikeColor = AppPalette.danger;

/// The colour of a verdict.
Color verdictColor(String? verdict) => switch (verdict) {
  'approve' => likeColor,
  'reject' => dislikeColor,
  _ => AppPalette.accent,
};

/// The icon of a verdict.
IconData verdictIcon(String? verdict) => switch (verdict) {
  'approve' => Icons.check,
  'reject' => Icons.close,
  _ => Icons.edit_outlined,
};

/// A square icon button that fills with the accent while [selected].
class IconToggle extends StatelessWidget {
  /// Creates the button; [label] is for screen readers only.
  const new({
    required this.label,
    required this.onTap,
    this.icon,
    this.child,
    this.selected = false,
    this.fill = AppPalette.accent,
    this.size = 44,
    this.tooltip,
    super.key,
  });

  /// What a screen reader says.
  final String label;

  /// Called on tap; null disables the button.
  final VoidCallback? onTap;

  /// The icon, unless [child] is given.
  final IconData? icon;

  /// Shown instead of [icon].
  final Widget? child;

  /// Whether the button is on.
  final bool selected;

  /// The fill while on.
  final Color fill;

  /// Side length.
  final double size;

  /// One word shown on hover or long-press; screen readers keep [label].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = selected ? AppPalette.onFill : scheme.onSurface;
    final button = Semantics(
      label: label,
      button: true,
      selected: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Material(
          color: selected ? fill : scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: selected ? fill : scheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: ink, size: 24),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                    child: child ?? Icon(icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null
        ? button
        : Tooltip(message: tip, excludeFromSemantics: true, child: button);
  }
}

/// A picture from the server, square by default.
class LogoImage extends StatefulWidget {
  /// Shows the picture at [path]; [pixels] decodes it at that size and
  /// shows it pixel for pixel (the 20 px avatar, enlarged).
  const new(
    this.pictures,
    this.path, {
    this.size,
    this.pixels,
    this.radius = 0,
    super.key,
  });

  /// The picture source.
  final PictureCache pictures;

  /// The server path.
  final String path;

  /// Side length; null fills the parent.
  final double? size;

  /// Decode size for the pixel-for-pixel view.
  final int? pixels;

  /// Corner radius as a fraction of the side (0.5 is a circle).
  final double radius;

  @override
  State<LogoImage> createState() => _LogoImageState();
}

class _LogoImageState extends State<LogoImage> {
  late Future<Uint8List> _bytes = widget.pictures.bytes(widget.path);

  @override
  void didUpdateWidget(LogoImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _bytes = widget.pictures.bytes(widget.path);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, box) => ClipRRect(
        borderRadius: BorderRadius.circular(box.maxWidth * widget.radius),
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snap) => snap.hasData
              ? Image.memory(
                  snap.data!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  cacheWidth: widget.pixels,
                  cacheHeight: widget.pixels,
                  filterQuality: widget.pixels == null
                      ? FilterQuality.medium
                      : FilterQuality.none,
                )
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: snap.hasError
                      ? const Icon(Icons.broken_image_outlined)
                      : null,
                ),
        ),
      ),
    ),
  );
}

/// [LogoImage] at a fixed [size].
Widget sizedLogo(
  PictureCache pictures,
  String path,
  double size, {
  double radius = 0,
}) => SizedBox.square(
  dimension: size,
  child: LogoImage(pictures, path, radius: radius),
);
