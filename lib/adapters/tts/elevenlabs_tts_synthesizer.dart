import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/narration.dart';
import '../../domain/performance.dart';
import '../ai/provider_exceptions.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// ElevenLabs TTS — the most expressive, best for distinct character voices.
/// Needs its own key. `voiceName` is an ElevenLabs voice id.
/// See `docs/voice-tts.md`.
class ElevenLabsTtsSynthesizer implements TtsSynthesizer {
  ElevenLabsTtsSynthesizer({
    required SecretStore secrets,
    http.Client? httpClient,
    this.voiceName = '21m00Tcm4TlvDq8ikWAM', // "Rachel"
    // v3 is the only ElevenLabs model that takes direction inline, so it is
    // the only one that can act on a narration cue at all. Older models still
    // work — they simply fall back to voice_settings, and `_directed` leaves
    // their text alone so no tag is ever spoken.
    this.model = defaultModel,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  static const String keyName = 'elevenlabs';
  static const String _base = 'https://api.elevenlabs.io/v1/text-to-speech';

  /// Friendly name → voice id for the Settings picker.
  static const Map<String, String> presets = {
    'Rachel (warm)': '21m00Tcm4TlvDq8ikWAM',
    'Bella (soft)': 'EXAVITQu4vr4xnSDxMaL',
    'Elli (young)': 'MF3mGyEYCl7XYWbV9V6O',
    'Antoni (male)': 'ErXwobaYiN019PkySvjV',
  };

  final SecretStore _secrets;
  final http.Client _http;
  final String voiceName;
  final String model;

  @override
  String get mimeType => 'audio/mpeg';

  @override
  String get voiceSignature => 'elevenlabs/$model/$voiceName';

  /// Used when the grown-up hasn't chosen one in Voice setup.
  static const String defaultModel = 'eleven_v3';

  /// Tags v3 understands, mapped from the cue's own words.
  ///
  /// A deliberately short whitelist. An unrecognised tag is not ignored — it
  /// is **spoken**, so a child would hear "bracket mischievously bracket" mid
  /// story. Anything not on this list is dropped rather than guessed at, and
  /// the sound-effect and experimental tags are left out entirely: a bedtime
  /// story has no use for [explosion], and the experimental ones are
  /// documented as inconsistent across voices.
  static const Map<String, String> _tags = {
    'whisper': '[whispers]',
    'hushed': '[whispers]',
    'excited': '[excited]',
    'delighted': '[excited]',
    'curious': '[curious]',
    'wistful': '[sighs]',
    'sleepy': '[sighs]',
    'tired': '[sighs]',
    'mischievous': '[mischievously]',
    'playful': '[mischievously]',
  };

  /// The passage with at most one leading audio tag.
  ///
  /// v3 takes its direction inline, so unlike the other engines the cue has to
  /// enter the text — but only here, at the moment of synthesis. The stored
  /// chapter is never touched, so nothing can leak into the screen, an export,
  /// or the Lunii pack. One tag at the front, never mid-sentence, because a
  /// tag inside a line reads as a stage direction and breaks the flow.
  String _directed(String text, NarrationCue cue) {
    // Only v3 understands audio tags; an older model reads them out loud.
    if (!model.startsWith('eleven_v3')) return text;
    for (final word in [cue.volume, cue.emotion]) {
      final tag = _tags[word.trim().toLowerCase()];
      if (tag != null) return '$tag $text';
    }
    return text;
  }

  @override
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationCue cue = const NarrationCue(),
    String standingDirection = '',
    // A single voice per request: the performance is read as one text.
    List<SpeechPart> parts = const [],
  }) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No ElevenLabs API key configured.');
    }
    final response = await _http.post(
      Uri.parse('$_base/$voiceName?output_format=mp3_44100_128'),
      headers: {
        'xi-api-key': key,
        'accept': 'audio/mpeg',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'text': _directed(text, cue),
        'model_id': model,
        if (!cue.isEmpty)
          'voice_settings': {
            // A cue carrying feeling wants a reading that moves; without one,
            // hold steady so a chapter keeps one voice throughout.
            'stability': cue.emotion.isEmpty ? 0.5 : 0.35,
            'similarity_boost': 0.75,
            'style': cue.emotion.isEmpty ? 0.0 : 0.35,
            'use_speaker_boost': true,
          },
      }),
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(response.statusCode, response.body);
    }
    return response.bodyBytes;
  }
}
