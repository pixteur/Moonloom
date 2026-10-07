import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../../domain/models/story_character.dart';
import '../../domain/models/world.dart';
import '../../adapters/tts/gemini_voice_designer.dart';
import '../../domain/cast_line.dart';
import '../common/confirm_destructive.dart';
import '../common/error_banner.dart';
import 'voice_design_dialog.dart';
import 'theme_picker.dart';
import 'world_voice_picker.dart';

/// The grown-up's workshop for a world: its name, what it's about, the flavours
/// every future episode inherits, and the cast. Everything here changes the
/// stories that come next, which is why it lives behind an edit button rather
/// than on the world page a child sees. See `docs/ui-ux.md`.
class WorldEditScreen extends ConsumerStatefulWidget {
  const WorldEditScreen({super.key, required this.world});

  final World world;

  @override
  ConsumerState<WorldEditScreen> createState() => _WorldEditScreenState();
}

class _WorldEditScreenState extends ConsumerState<WorldEditScreen> {
  late final _name = TextEditingController(text: widget.world.name);
  late final _premise = TextEditingController(text: widget.world.premise);
  late String _voice = widget.world.voiceName;
  late List<StoryTheme> _themes = widget.world.allThemes;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _premise.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.world.copyWith(
      name: name,
      premise: _premise.text.trim(),
      theme: _themes.first,
      extraThemes: _themes.skip(1).toList(),
      voiceName: _voice,
    );
    await ref.read(worldServiceProvider).update(updated);
    ref.read(activeWorldProvider.notifier).select(updated);
    ref.invalidate(worldsForChildProvider(updated.childId));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final world = widget.world;
    final characters = ref.watch(charactersForWorldProvider(world.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit world'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete world',
            onPressed: _deleteWorld,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'World name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _premise,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What is this world about?',
              helperText: 'Every episode is written to fit this',
            ),
          ),

          const SizedBox(height: 24),
          Text('Who tells the stories?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          WorldVoicePicker(
            value: _voice,
            onChanged: (v) => setState(() => _voice = v),
          ),
          VoiceChangeNote(from: widget.world.voiceName, to: _voice),

          const SizedBox(height: 24),
          ThemePicker(
            selected: _themes,
            onToggle: (t) =>
                setState(() => _themes = ThemePicker.toggled(_themes, t)),
          ),
          const SizedBox(height: 4),
          Text(
            'Changing the flavours steers the next episode onward — the ones '
            'already written stay as they are.',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Text('Characters', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editCharacter(world.id),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          Text(
            'Everyone here appears in future episodes. A new face is introduced '
            'in the next story; someone you remove gets a warm goodbye first.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          characters.when(
            loading: () =>
                const Padding(padding: EdgeInsets.all(8), child: Text('…')),
            error: (e, _) => Text('Could not load characters: $e'),
            data: (list) => list.isEmpty
                ? Text(
                    'No saved characters yet. Add one so every episode keeps '
                    'them consistent.',
                    style: theme.textTheme.bodySmall,
                  )
                // Condensed: one compact row each, no cards.
                : Column(
                    children: [
                      for (final c in list)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: c.hasVoice
                              ? Icon(
                                  Icons.record_voice_over_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : const Icon(Icons.person_outline),
                          title: Text(c.name),
                          subtitle: c.description.trim().isEmpty
                              ? null
                              : Text(
                                  c.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => _editCharacter(world.id, c),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  c.hasVoice
                                      ? Icons.record_voice_over_rounded
                                      : Icons.mic_none_rounded,
                                ),
                                tooltip: c.hasVoice
                                    ? "${c.name}'s voice"
                                    : 'Give ${c.name} a voice',
                                onPressed: () => _characterVoice(c, list),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: 'Write ${c.name} out',
                                onPressed: () => _removeCharacter(c),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Save changes'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editCharacter(
    String worldId, [
    StoryCharacter? existing,
  ]) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add character' : 'Edit character'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descC,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (who are they?)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || nameC.text.trim().isEmpty) return;
    final svc = ref.read(characterServiceProvider);
    if (existing == null) {
      await svc.create(
        worldId: worldId,
        name: nameC.text.trim(),
        description: descC.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${nameC.text.trim()} joins the story in the next episode.',
            ),
          ),
        );
      }
    } else {
      await svc.update(
        existing.copyWith(
          name: nameC.text.trim(),
          description: descC.text.trim(),
        ),
      );
    }
    ref.invalidate(charactersForWorldProvider(worldId));
  }

  /// Give a character a voice of their own, or take it back.
  ///
  /// One character per world: a voice request holds two speakers, the
  /// narrator and one other, so a second voiced character could never be
  /// heard. Giving Pip a voice therefore hands the role over from whoever had
  /// it. The child is never given one — the narrator reads their lines; the
  /// voice service refuses to design a child's voice, and the app should not
  /// want one.
  Future<void> _characterVoice(
    StoryCharacter c,
    List<StoryCharacter> cast,
  ) async {
    if (ref.read(voiceConfigProvider).engine != VoiceEngine.gemini) {
      showErrorBanner(
        context,
        'Character voices need the Gemini storyteller — choose it in '
        'Settings → Voice.',
      );
      return;
    }
    final child = ref.read(activeChildProvider);
    if (child != null && foldedName(child.displayName) == foldedName(c.name)) {
      showErrorBanner(
        context,
        "The storyteller reads ${c.name}'s lines. The app never makes a "
        "voice for a child.",
      );
      return;
    }
    final svc = ref.read(characterServiceProvider);

    // The voices already designed, so one can be reused rather than paid for
    // again — Pip's voice from one world is still Pip's voice in another. A
    // list that will not load (offline) just means only "design" is offered.
    var designed = const <DesignedVoice>[];
    try {
      designed = await ref.read(designedVoicesProvider.future);
    } catch (_) {}
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(c.hasVoice ? "${c.name}'s voice" : 'A voice for ${c.name}'),
        children: [
          if (designed.isNotEmpty)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'reuse'),
              child: const Text('Use a voice you designed'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'design'),
            child: Text(
              c.hasVoice ? 'Design a different voice' : 'Design a new voice',
            ),
          ),
          if (c.hasVoice)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'narrator'),
              child: Text('Let the storyteller play ${c.name} again'),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'narrator') {
      await svc.update(c.copyWith(voiceId: ''));
      ref.invalidate(charactersForWorldProvider(c.worldId));
      return;
    }

    final DesignedVoice? voice;
    if (choice == 'reuse') {
      voice = await showDesignedVoicePicker(
        context,
        title: 'A voice for ${c.name}',
        voices: designed,
        current: c.voiceId,
      );
    } else {
      voice = await showVoiceDesignDialog(
        context,
        title: 'A voice for ${c.name}',
        name: c.name,
        prompt: GeminiVoiceDesigner.characterPrompt(c.name, c.description),
      );
    }
    if (voice == null) return;
    await _giveVoice(c, cast, voice.id);
  }

  /// [c] speaks in [voiceId] from now on.
  ///
  /// Hands the role over: whoever had a voice in this world goes back to the
  /// storyteller, because only one of them could ever be heard.
  Future<void> _giveVoice(
    StoryCharacter c,
    List<StoryCharacter> cast,
    String voiceId,
  ) async {
    final svc = ref.read(characterServiceProvider);
    final updated = castWithVoice(cast, c.id, voiceId);
    for (var i = 0; i < cast.length; i++) {
      if (updated[i].voiceId != cast[i].voiceId) await svc.update(updated[i]);
    }
    ref.invalidate(charactersForWorldProvider(c.worldId));
    ref.invalidate(designedVoicesProvider);
    if (mounted) {
      showErrorBanner(
        context,
        '${c.name} now speaks in their own voice, from the next chapter '
        'recorded.',
      );
    }
  }

  /// Remove a character from the world. They aren't simply deleted: the next
  /// story writes them out with a gentle goodbye, so a child isn't left
  /// wondering where a friend went.
  Future<void> _removeCharacter(StoryCharacter c) async {
    final ok = await confirmDestructive(
      context,
      title: 'Write ${c.name} out?',
      message:
          '${c.name} will leave the story in the next episode — with a warm, '
          'happy goodbye — and won\'t appear after that.',
      confirmLabel: 'Say goodbye',
      doubleCheck: 'Really write ${c.name} out of this world for good?',
    );
    if (!ok) return;
    await ref.read(characterServiceProvider).delete(c);
    ref.invalidate(charactersForWorldProvider(c.worldId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${c.name} will be given a proper send-off in the next story.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteWorld() async {
    final world = widget.world;
    final ok = await confirmDestructive(
      context,
      title: 'Delete world?',
      message:
          'This deletes "${world.name}", its characters, and ALL its episodes. '
          'This can\'t be undone.',
      confirmLabel: 'Delete world',
      doubleCheck:
          'Every story in "${world.name}" will be gone forever. Delete it?',
    );
    if (!ok) return;
    await ref.read(worldServiceProvider).delete(world.id);
    ref.invalidate(worldsForChildProvider(world.childId));
    ref.invalidate(seriesForChildProvider(world.childId));
    if (!mounted) return;
    // Pop the editor and the world page beneath it — the world is gone.
    Navigator.pop(context);
    Navigator.pop(context);
  }
}
