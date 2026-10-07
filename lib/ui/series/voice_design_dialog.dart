import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/provider_exceptions.dart';
import '../../adapters/tts/gemini_voice_designer.dart';
import '../../app_providers.dart';

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
