/// Pieces of the context previews: the avatar places, tab and og card.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_system/design_system.dart';
import 'package:logo_review/pictures.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// One place a logo shows up as an avatar.
typedef Avatar = ({
  String chip,
  String name,
  Color color,
  List<double> sizes,
  double radius,
});

/// The avatar places, with each platform's real sizes.
const List<Avatar> avatars = [
  (
    chip: 'in',
    name: 'LinkedIn',
    color: Color(0xFF0A66C2),
    sizes: [200, 100, 48, 32],
    radius: 0.5,
  ),
  (
    chip: 'f',
    name: 'Facebook',
    color: Color(0xFF1877F2),
    sizes: [168, 40, 32],
    radius: 0.5,
  ),
  (
    chip: 'D',
    name: 'Discord',
    color: Color(0xFF5865F2),
    sizes: [80, 40, 32],
    radius: 0.5,
  ),
  (
    chip: 'GH',
    name: 'GitHub',
    color: Color(0xFF6E7781),
    sizes: [260, 40, 20],
    radius: 0.5,
  ),
  (
    chip: '□',
    name: 'Square app icon',
    color: Color(0xFF70625B),
    sizes: [180, 64, 32],
    radius: 0.22,
  ),
];

/// The colour in the picture's corner: the og card is filled with the logo's
/// own background.
Future<Color> cornerColor(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final img = (await codec.getNextFrame()).image;
  final data = await img.toByteData();
  final at = ((6 % img.height) * img.width + 6 % img.width) * 4;
  return data == null
      ? AppPalette.ink
      : Color.fromARGB(
          255,
          data.getUint8(at),
          data.getUint8(at + 1),
          data.getUint8(at + 2),
        );
}

/// A browser tab or bookmark tile holding [children].
class BrowserTab extends StatelessWidget {
  /// Creates it.
  const new({
    required this.line,
    required this.fill,
    required this.width,
    required this.height,
    required this.children,
    super.key,
  });

  /// The line.
  final Color line;

  /// The fill.
  final Color fill;

  /// The width.
  final double width;

  /// The height.
  final double height;

  /// The children.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: fill,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: children,
    ),
  );
}

/// The link preview card (og:image, 1200 x 630) with a text stub under it.
class OgCard extends StatelessWidget {
  /// Creates it.
  const new(
    this.pictures,
    this.path, {
    required this.line,
    required this.fill,
    super.key,
  });

  /// The pictures.
  final PictureCache pictures;

  /// The path.
  final String path;

  /// The line.
  final Color line;

  /// The fill.
  final Color fill;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FutureBuilder<Color>(
        future: pictures.bytes(path).then(cornerColor),
        builder: (context, snap) => Container(
          key: const ValueKey('og-card'),
          width: 400,
          height: 210,
          color: snap.data ?? AppPalette.ink,
          alignment: Alignment.center,
          child: sizedLogo(pictures, path, 140),
        ),
      ),
      Container(
        width: 400,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Container(height: 8, color: line),
            Container(height: 8, width: 240, color: line),
          ],
        ),
      ),
    ],
  );
}
