/// The shell: pair, load, then the grid; an error is always on screen.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/errors.dart';
import 'package:logo_review/ui/grid_page.dart';
import 'package:logo_review/ui/pair_page.dart';
import 'package:logo_review/ui/services.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The application.
class LogoReviewApp extends StatefulWidget {
  /// Runs the session in [controller] with the phone's [services].
  const new({
    required this.controller,
    required this.services,
    this.errors,
    super.key,
  });

  /// The session.
  final ReviewController controller;

  /// Share sheet and gallery.
  final Services services;

  /// Where uncaught errors show up.
  final ErrorReporter? errors;

  @override
  State<LogoReviewApp> createState() => _LogoReviewAppState();
}

class _LogoReviewAppState extends State<LogoReviewApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.start());
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Logo review',
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    debugShowCheckedModeBanner: false,
    builder: (context, child) => Stack(
      children: [
        ?child,
        if (widget.errors case final errors?) _ErrorBar(errors),
      ],
    ),
    home: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => switch (widget.controller.phase) {
        Phase.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        Phase.unpaired => PairPage(widget.controller),
        Phase.offline => _Offline(widget.controller),
        Phase.ready => GridPage(widget.controller, widget.services),
      },
    ),
  );
}

class _Offline extends StatelessWidget {
  const new(this.controller);

  final ReviewController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 96,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          IconToggle(
            key: const ValueKey('retry'),
            label: 'Try again',
            tooltip: 'Retry',
            icon: Icons.refresh,
            size: 64,
            onTap: () => unawaited(
              controller.api.token.isEmpty
                  ? controller.start()
                  : controller.load(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The last uncaught error, at the bottom until tapped away. The error's own
/// words are shown on purpose: a failure must never be silent.
class _ErrorBar extends StatelessWidget {
  const new(this.errors);

  final ErrorReporter errors;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: errors.last,
    builder: (context, text, _) => text == null
        ? const SizedBox.shrink()
        : Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
            child: SafeArea(
              child: Material(
                color: AppPalette.danger,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  key: const ValueKey('error-bar'),
                  onTap: () => errors.last.value = null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppPalette.onFill,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppPalette.onFill),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}
