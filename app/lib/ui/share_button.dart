/// The button that makes a picture and opens the share sheet on it.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:logo_review/ui/services.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// A button that draws a picture and hands it to the share sheet. It turns
/// green when the picture went out and red when it could not be made.
class ShareButton extends StatefulWidget {
  /// Shares what [render] draws.
  const new({
    required this.label,
    required this.services,
    required this.render,
    super.key,
  });

  /// What a screen reader says.
  final String label;

  /// The share sheet.
  final Services services;

  /// Draws the picture.
  final Future<Uint8List> Function() render;

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  bool? _done;
  var _busy = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    bool ok;
    try {
      await widget.services.share(await widget.render());
      ok = true;
    } on Exception {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
    _reset = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _done = null);
    });
  }

  @override
  Widget build(BuildContext context) => IconToggle(
    label: widget.label,
    selected: _done != null,
    fill: _done ?? false ? likeColor : dislikeColor,
    onTap: _busy ? null : () => unawaited(_share()),
    child: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(switch (_done) {
            null => Icons.ios_share,
            true => Icons.check,
            false => Icons.close,
          }),
  );
}
