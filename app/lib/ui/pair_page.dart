/// First run: type the six digits the computer shows.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:logo_review/controller.dart';
import 'package:material_ui/material_ui.dart';

/// Asks for the pairing code and pairs as soon as it is complete.
class PairPage extends StatefulWidget {
  /// Pairs through [controller].
  const new(this.controller, {super.key});

  /// The session.
  final ReviewController controller;

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _changed(String value) {
    if (value.length < 6) return;
    _code.clear();
    unawaited(widget.controller.pair(value));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final refused = widget.controller.codeRefused;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.computer, size: 56, color: scheme.onSurface),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      refused ? Icons.link_off : Icons.link,
                      key: ValueKey(refused ? 'refused' : 'waiting'),
                      size: 40,
                      color: refused ? scheme.error : scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.smartphone, size: 56, color: scheme.onSurface),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: 260,
                  child: Semantics(
                    label: 'Pairing code from the computer',
                    child: TextField(
                      key: const ValueKey('pair-code'),
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppTextSize.display,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(hintText: '······'),
                      onChanged: _changed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
