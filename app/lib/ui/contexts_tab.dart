/// The logo where people will really meet it: avatars at their real sizes,
/// the browser tab, the site header and the link preview card.
library;

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/ui/contexts_parts.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The previews of [logoKey], one place per page, light or dark.
class ContextsTab extends StatefulWidget {
  /// Creates the tab.
  const new(this.c, this.logoKey, {super.key});

  /// The session.
  final ReviewController c;

  /// The logo.
  final String logoKey;

  @override
  State<ContextsTab> createState() => _ContextsTabState();
}

class _ContextsTabState extends State<ContextsTab> {
  var _dark = false;
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final path = '/img/${widget.logoKey}.png';
    final pictures = widget.c.pictures;
    final line = _dark ? AppPalette.lineDark : AppPalette.lineLight;
    final ui = _dark ? AppPalette.inkRaised1 : AppPalette.paperRaised;
    final ink = _dark ? AppPalette.mutedOnDark : AppPalette.mutedOnLight;
    Widget px(String s) => Text(
      s,
      textScaler: TextScaler.noScaling,
      style: TextStyle(fontSize: 11, color: ink),
    );
    Widget bar(double width) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            spacing: 16,
            children: [
              sizedLogo(pictures, path, 28),
              for (var i = 0; i < 2; i++)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ],
          ),
        ),
        px('${width.round()}'),
      ],
    );
    final pages = <Widget>[
      for (final a in avatars)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Semantics(
              label: a.name,
              child: Container(
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
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 10,
              children: [
                for (final size in a.sizes)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      sizedLogo(pictures, path, size, radius: a.radius),
                      px('${size.round()}'),
                    ],
                  ),
              ],
            ),
          ],
        ),
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 10,
            children: [
              BrowserTab(
                line: line,
                fill: ui,
                width: 190,
                height: 34,
                children: [
                  sizedLogo(pictures, path, 16),
                  Expanded(child: Container(height: 8, color: line)),
                  Icon(Icons.close, size: 14, color: ink),
                ],
              ),
              BrowserTab(
                line: line,
                fill: ui,
                width: 72,
                height: 48,
                children: [sizedLogo(pictures, path, 32)],
              ),
            ],
          ),
          px('16 · 32'),
          bar(360),
        ],
      ),
      bar(720),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OgCard(pictures, path, line: line, fill: ui),
          px('1200 × 630'),
        ],
      ),
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            key: ValueKey(_dark ? 'ctx-dark' : 'ctx-light'),
            decoration: BoxDecoration(
              color: _dark ? AppPalette.ink : AppPalette.paper,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
            child: PageView(
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final page in pages)
                  FittedBox(fit: BoxFit.scaleDown, child: page),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < pages.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? AppPalette.accent : line,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconToggle(
            key: const ValueKey('ctx-scheme'),
            label: 'Light or dark background',
            icon: _dark ? Icons.light_mode : Icons.dark_mode,
            size: 36,
            onTap: () => setState(() => _dark = !_dark),
          ),
        ),
      ],
    );
  }
}
