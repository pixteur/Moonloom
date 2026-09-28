import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/provider_exceptions.dart';
import '../../adapters/tts/voice_catalog.dart';
import '../../app_providers.dart';
import '../common/error_banner.dart';

/// Choose the storyteller for a world.
///
/// Every engine names its voices after nothing in particular — Kore, Puck,
/// nova — which tells a six-year-old precisely nothing, and I am not going to
/// invent descriptions of how each one sounds. So the control is a row of
/// names you tap to **hear**, and the child picks the one they like. A preview
/// is about three seconds of speech, a fraction of a centime, and cached
/// afterwards like any other narration, so playing with it is free after the
/// first time.
///
/// The engine is deliberately not offered here: engines need a key and a
/// consent, which belong to a grown-up in settings. See `docs/voice-tts.md`.
class WorldVoicePicker extends ConsumerStatefulWidget {
  const WorldVoicePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.previewLine,
  });

  /// The chosen voice name; empty means "whatever settings says".
  final String value;
  final ValueChanged<String> onChanged;

  /// What the preview reads. Defaults to a line of bedtime narration, because
  /// a voice reading "hello" tells you nothing about a voice reading a story.
  final String? previewLine;

  @override
  ConsumerState<WorldVoicePicker> createState() => _WorldVoicePickerState();
}

class _WorldVoicePickerState extends ConsumerState<WorldVoicePicker> {
  String? _playing;

  Future<void> _preview(String voice) async {
    final cfg = ref.read(voiceConfigProvider);
    if (cfg.engine == VoiceEngine.device) return;
    setState(() => _playing = voice);
    try {
      await ref
          .read(voicePreviewProvider(voice))
          .speak(
            widget.previewLine ??
                'Once upon a time, in a place where the stars came down '
                    'to listen, a story was waiting for you.',
          );
    } catch (e) {
      if (mounted) showErrorBanner(context, friendlyProviderError(e));
    } finally {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = ref.watch(voiceConfigProvider).engine;
    final voices = voicesFor(engine);

    if (engine == VoiceEngine.device || voices.isEmpty) {
      return Text(
        'Stories here are read by the voice built into this device. '
        'Add a storyteller voice in Settings to choose one per world.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap a name to hear it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _VoiceChip(
              label: 'Same as settings',
              selected: widget.value.isEmpty,
              onTap: () => widget.onChanged(''),
            ),
            for (final voice in voices)
              _VoiceChip(
                label: voiceLabel(voice),
                character: voiceCharacter(voice),
                selected: widget.value == voice,
                busy: _playing == voice,
                onTap: () {
                  widget.onChanged(voice);
                  _preview(voice);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.character = '',
    this.busy = false,
  });

  final String label;

  /// Google's own word for how this voice sounds, shown small beside the
  /// friendly name so the name is never a claim I made up.
  final String character;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ] else if (selected) ...[
            const Icon(Icons.volume_up_rounded, size: 16),
            const SizedBox(width: 6),
          ],
          Text(label),
          if (character.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              character,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// A line telling a grown-up what changing the voice costs. Shown only when it
/// is actually changing, because the answer for a brand-new world is "nothing".
class VoiceChangeNote extends StatelessWidget {
  const VoiceChangeNote({super.key, required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    if (from == to) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Chapters already recorded keep the voice they were read in. '
        'New ones will use this voice, and are recorded the first time '
        'they are played.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
