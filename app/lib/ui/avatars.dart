/// The places a logo shows up as an avatar, with each platform's real sizes.
library;

import 'package:material_ui/material_ui.dart';

/// One place a logo shows up as an avatar. `id` names the service whose logo
/// the server keeps (`/services/<id>.png`); empty for the square app icon.
typedef Avatar = ({
  String id,
  String chip,
  String name,
  Color color,
  List<double> sizes,
  double radius,
});

/// The avatar places, as on the page (`AVATARS` in index.html). Chip colours
/// of the first four predate the logos; the rest are simple-icons' hex.
const List<Avatar> avatars = [
  (
    id: 'linkedin',
    chip: 'in',
    name: 'LinkedIn',
    color: Color(0xFF0A66C2),
    sizes: [200, 100, 48, 32],
    radius: 0.5,
  ),
  (
    id: 'facebook',
    chip: 'f',
    name: 'Facebook',
    color: Color(0xFF1877F2),
    sizes: [168, 40, 32],
    radius: 0.5,
  ),
  (
    id: 'discord',
    chip: 'D',
    name: 'Discord',
    color: Color(0xFF5865F2),
    sizes: [80, 40, 32],
    radius: 0.5,
  ),
  (
    id: 'github',
    chip: 'GH',
    name: 'GitHub',
    color: Color(0xFF6E7781),
    sizes: [260, 40, 20],
    radius: 0.5,
  ),
  (
    id: 'signal',
    chip: 'S',
    name: 'Signal',
    color: Color(0xFF3B45FD),
    sizes: [96, 48, 28],
    radius: 0.5,
  ),
  (
    id: 'steam',
    chip: 'St',
    name: 'Steam',
    color: Color(0xFF000000),
    sizes: [184, 64, 32],
    radius: 0.22,
  ),
  (
    id: 'whatsapp',
    chip: 'W',
    name: 'WhatsApp',
    color: Color(0xFF25D366),
    sizes: [192, 49, 40],
    radius: 0.5,
  ),
  (
    id: 'telegram',
    chip: 'T',
    name: 'Telegram',
    color: Color(0xFF26A5E4),
    sizes: [160, 54, 42],
    radius: 0.5,
  ),
  (
    id: 'instagram',
    chip: 'IG',
    name: 'Instagram',
    color: Color(0xFFFF0069),
    sizes: [150, 56, 32],
    radius: 0.5,
  ),
  (
    id: 'x',
    chip: 'X',
    name: 'X',
    color: Color(0xFF000000),
    sizes: [200, 48, 32],
    radius: 0.5,
  ),
  (
    id: 'reddit',
    chip: 'R',
    name: 'Reddit',
    color: Color(0xFFFF4500),
    sizes: [80, 32, 24],
    radius: 0.5,
  ),
  (
    id: 'youtube',
    chip: 'YT',
    name: 'YouTube',
    color: Color(0xFFFF0000),
    sizes: [176, 36, 24],
    radius: 0.5,
  ),
  (
    id: 'slack',
    chip: 'Sl',
    name: 'Slack',
    color: Color(0xFF4A154B),
    sizes: [72, 36, 20],
    radius: 0.22,
  ),
  (
    id: 'gmail',
    chip: 'G',
    name: 'Gmail',
    color: Color(0xFFEA4335),
    sizes: [96, 40, 32],
    radius: 0.5,
  ),
  (
    id: '',
    chip: '□',
    name: 'Square app icon',
    color: Color(0xFF70625B),
    sizes: [180, 64, 32],
    radius: 0.22,
  ),
];
