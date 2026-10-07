import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/provider_exceptions.dart';
import '../../adapters/tts/gemini_voice_designer.dart';
import '../../app_providers.dart';
import '../common/error_banner.dart';

/// Describe a voice, hear it, keep it.
///
/// Used for a world's storyteller and for a character's own voice. The
/// grown-up writes (or picks) a description, the voice service designs it and
/// hands back a sample, and nothing is used until they have heard that sample
/// and chosen to keep it — a voice is a taste, and the description is only a
/// guess at it.
///
/// Returns the designed voice, or null when cancelled.
Future<DesignedVoice?> showVoiceDesignDialog(
  BuildContext context, {
  required String title,
  required String name,
  required String prompt,
  Map<String, String> ideas = const {},
}) => showDialog<DesignedVoice>(
  context: context,
  builder: (_) => _VoiceDesignDialog(
    title: title,
    name: name,
    prompt: prompt,
    ideas: ideas,
  ),
);

class _VoiceDesignDialog extends ConsumerStatefulWidget {
  const _VoiceDesignDialog({
    required this.title,
    required this.name,
    required this.prompt,
    required this.ideas,
  });

  final String title;
  final String name;
  final String prompt;
  final Map<String, String> ideas;

  @override
  ConsumerState<_VoiceDesignDialog> createState() => _VoiceDesignDialogState();
}

class _VoiceDesignDialogState extends ConsumerState<_VoiceDesignDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _prompt = TextEditingController(text: widget.prompt);
  final _player = AudioPlayer();
  DesignedVoice? _designed;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _design() async {
    setState(() {
      _busy = true;
      _error = null;
      _designed = null;
    });
    try {
      final voice = await ref
          .read(voiceDesignerProvider)
          .design(name: _name.text.trim(), prompt: _prompt.text.trim());
      if (!mounted) return;
      setState(() => _designed = voice);
      await _listen();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyProviderError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listen() async {
    final sample = _designed?.preview;
    if (sample == null) return;
    await _player.stop();
    await _player.play(BytesSource(sample, mimeType: 'audio/wav'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready =
        _name.text.trim().isNotEmpty && _prompt.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (widget.ideas.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final idea in widget.ideas.entries)
                      ActionChip(
                        label: Text(idea.key),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _prompt.text = idea.value;
                                if (_name.text.trim().isEmpty) {
                                  _name.text = idea.key;
                                }
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _prompt,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'How should they sound?',
                  helperText:
                      'Who they are — age, warmth, accent, pace — rather '
                      'than a mood. Describe a grown-up performer: the voice '
                      "service won't make a child's voice.",
                  helperMaxLines: 3,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              if (_busy)
                const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Designing the voice…'),
                  ],
                ),
              if (_designed != null)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Here it is.')),
                    TextButton.icon(
                      onPressed: _listen,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen again'),
                    ),
                  ],
                ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_designed == null)
          FilledButton(
            onPressed: _busy || !ready ? null : _design,
            child: const Text('Design it'),
          )
        else ...[
          TextButton(
            onPressed: _busy || !ready ? null : _design,
            child: const Text('Try again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _designed),
            child: const Text('Use this voice'),
          ),
        ],
      ],
    );
  }
}

/// Choose one of the voices already designed, hearing each first.
///
/// A designed voice is reused rather than designed again: it costs nothing
/// more, and Pip's voice from one world is still Pip's voice in another.
/// Returns the chosen voice, or null when cancelled.
Future<DesignedVoice?> showDesignedVoicePicker(
  BuildContext context, {
  required String title,
  required List<DesignedVoice> voices,
  String current = '',
}) => showDialog<DesignedVoice>(
  context: context,
  builder: (_) =>
      _DesignedVoicePicker(title: title, voices: voices, current: current),
);

class _DesignedVoicePicker extends ConsumerStatefulWidget {
  const _DesignedVoicePicker({
    required this.title,
    required this.voices,
    required this.current,
  });

  final String title;
  final List<DesignedVoice> voices;
  final String current;

  @override
  ConsumerState<_DesignedVoicePicker> createState() =>
      _DesignedVoicePickerState();
}

class _DesignedVoicePickerState extends ConsumerState<_DesignedVoicePicker> {
  String? _playing;

  /// Read a line in the voice. Through the same reader as any narration, so
  /// it is cached afterwards and hearing it twice costs once.
  Future<void> _hear(DesignedVoice voice) async {
    setState(() => _playing = voice.id);
    try {
      await ref
          .read(voicePreviewProvider(voice.id))
          .speak(
            // Dialogue rather than narration, because that is what a
            // character's voice will be asked to say — and no "he" or "she",
            // because characters are not all one or the other.
            '"Look! The moon is wearing a hat tonight. Shall we follow it?"',
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final voice in widget.voices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconButton(
                  tooltip: 'Hear ${voice.name}',
                  onPressed: _playing == null ? () => _hear(voice) : null,
                  icon: _playing == voice.id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline_rounded),
                ),
                title: Text(voice.name),
                subtitle: voice.prompt.isEmpty
                    ? null
                    : Text(
                        voice.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: voice.id == widget.current
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, voice),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
