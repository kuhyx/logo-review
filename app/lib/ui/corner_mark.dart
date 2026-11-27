/// The corner mark a service draws over an avatar: a status dot, or Google's
/// edit pencil. Always on, so a logo whose corner it covers shows that in
/// review.
library;

import 'package:material_ui/material_ui.dart';

/// Where one mark sits on an avatar: centre, diameter and the cut-out ring
/// around it, as fractions of the avatar's side.
typedef MarkAt = ({double cx, double cy, double d, double ring});

/// One service's mark: its one-word tooltip, colour, whether it is the
/// pencil, and where it sits at each listed avatar size.
typedef CornerMark = ({
  String tip,
  Color color,
  bool pencil,
  Map<int, MarkAt> at,
});

const MarkAt _gmail = (cx: 0.86, cy: 0.8, d: 0.39, ring: 0.04);

/// The marks, as on the page (the `#overlays` block in index.html, which
/// says where each value was measured).
const Map<String, CornerMark> cornerMarks = {
  'discord': (
    tip: 'Online',
    color: Color(0xFF23A55A),
    pencil: false,
    at: {
      80: (cx: 0.85, cy: 0.85, d: 0.2, ring: 0.075),
      40: (cx: 0.85, cy: 0.85, d: 0.3, ring: 0.075),
      32: (cx: 0.84375, cy: 0.84375, d: 0.3125, ring: 0.09375),
    },
  ),
  'facebook': (
    tip: 'Online',
    color: Color(0xFF31A24C),
    pencil: false,
    at: {
      168: (cx: 0.86, cy: 0.86, d: 0.15, ring: 0.03),
      40: (cx: 0.85, cy: 0.85, d: 0.3, ring: 0.05),
      32: (cx: 0.85, cy: 0.85, d: 0.32, ring: 0.0625),
    },
  ),
  'telegram': (
    tip: 'Online',
    color: Color(0xFF0AC630),
    pencil: false,
    at: {
      160: (cx: 0.86, cy: 0.86, d: 0.15, ring: 0.03),
      54: (cx: 0.86, cy: 0.86, d: 0.26, ring: 0.05),
      42: (cx: 0.86, cy: 0.86, d: 0.28, ring: 0.05),
    },
  ),
  'slack': (
    tip: 'Online',
    color: Color(0xFF2BAC76),
    pencil: false,
    at: {
      72: (cx: 0.9, cy: 0.9, d: 0.22, ring: 0.05),
      36: (cx: 0.9, cy: 0.9, d: 0.3, ring: 0.08),
      20: (cx: 0.9, cy: 0.9, d: 0.4, ring: 0.1),
    },
  ),
  'gmail': (
    tip: 'Edit',
    color: Color(0xFF3C4043),
    pencil: true,
    at: {96: _gmail, 40: _gmail, 32: _gmail},
  ),
};

/// [avatar] (a [size] square) with service [id]'s mark over its corner; the
/// ring is drawn in [ring], the colour behind the avatar. Unchanged when the
/// service has no mark at that size.
Widget markedAvatar(
  Widget avatar,
  String id,
  double size, {
  required Color ring,
}) {
  final mark = cornerMarks[id];
  final at = mark?.at[size.round()];
  if (mark == null || at == null) return avatar;
  final d = at.d * size;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      avatar,
      Positioned(
        left: at.cx * size - d / 2,
        top: at.cy * size - d / 2,
        width: d,
        height: d,
        child: Tooltip(
          message: mark.tip,
          child: Container(
            key: ValueKey('mark-$id-${size.round()}'),
            decoration: BoxDecoration(
              color: mark.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: ring,
                width: at.ring * size,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: mark.pencil
                ? Icon(
                    Icons.edit,
                    size: d * 0.58,
                    color: const Color(0xFFE8EAED),
                  )
                : null,
          ),
        ),
      ),
    ],
  );
}
