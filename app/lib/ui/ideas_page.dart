/// Suggest new directions: words, an optional link, an optional picture.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/logic.dart';
import 'package:logo_review/ui/services.dart';
import 'package:logo_review/ui/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The list of suggestions and the form for a new one.
class IdeasPage extends StatefulWidget {
  /// Creates the page.
  const new(this.c, this.services, {super.key});

  /// The session.
  final ReviewController c;

  /// The gallery.
  final Services services;

  @override
  State<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends State<IdeasPage> {
  final _text = TextEditingController();
  final _ref = TextEditingController();
  PickedImage? _image;

  ReviewController get c => widget.c;

  @override
  void dispose() {
    _text.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final picked = _image;
    // The picture's server name comes once it is up; any mark counts here.
    final idea = ideaFrom(
      _text.text,
      _ref.text,
      picked == null ? '' : picked.mime,
      DateTime.now(),
    );
    if (idea == null) return;
    _text.clear();
    _ref.clear();
    await c.addIdea(idea, picked);
    if (mounted) setState(() => _image = null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final ideas = c.state.ideas;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              spacing: 6,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: scheme.primary),
                    const Spacer(),
                    IconToggle(
                      key: const ValueKey('close'),
                      label: 'Close',
                      tooltip: 'Back',
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: ideas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                if (ideas[i].text.isNotEmpty)
                                  Text(ideas[i].text),
                                if (ideas[i].ref.isNotEmpty)
                                  Text(
                                    ideas[i].ref,
                                    style: TextStyle(color: scheme.primary),
                                  ),
                                if (ideas[i].image.isNotEmpty)
                                  sizedLogo(
                                    c.pictures,
                                    '/ref/${ideas[i].image}',
                                    96,
                                    radius: 0.06,
                                  ),
                              ],
                            ),
                          ),
                          IconToggle(
                            key: ValueKey('idea-delete-$i'),
                            label: 'Delete suggestion ${i + 1}',
                            tooltip: 'Delete',
                            icon: Icons.close,
                            size: 36,
                            onTap: () => c.edit((s) => s.ideas.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Semantics(
                  label: 'Describe the direction or style',
                  child: TextField(
                    key: const ValueKey('idea-text'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
                Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Reference link (optional)',
                        child: TextField(
                          key: const ValueKey('idea-ref'),
                          controller: _ref,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            isDense: true,
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                      ),
                    ),
                    IconToggle(
                      key: const ValueKey('idea-image'),
                      label: 'Reference picture (optional)',
                      tooltip: 'Picture',
                      selected: _image != null,
                      onTap: () async {
                        final picked = await widget.services.pickImage();
                        if (mounted) setState(() => _image = picked);
                      },
                      child: _image == null
                          ? const Icon(Icons.image_outlined)
                          : Image.memory(_image!.bytes, width: 36, height: 36),
                    ),
                    IconToggle(
                      key: const ValueKey('idea-add'),
                      label: 'Add suggestion',
                      tooltip: 'Add',
                      icon: Icons.add,
                      onTap: () => unawaited(_add()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
