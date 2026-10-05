import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/narration.dart';
import '../../domain/performance.dart';
import '../ai/provider_exceptions.dart';
import '../ai/story_segment_codec.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// OpenAI TTS (`/v1/audio/speech`, `gpt-4o-mini-tts`) — warm, natural, and
/// steerable via `instructions`. Reuses the parent's OpenAI key.
/// See `docs/voice-tts.md`.
class OpenAiTtsSynthesizer implements TtsSynthesizer {
  OpenAiTtsSynthesizer({
    required SecretStore secrets,
    http.Client? httpClient,
    this.voiceName = 'nova',
    this.model = defaultModel,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  /// Used when the grown-up hasn't chosen one in Voice setup.
  static const String defaultModel = 'gpt-4o-mini-tts';

  static const String keyName = 'openai';
  static const String _endpoint = 'https://api.openai.com/v1/audio/speech';
  static const List<String> voices = [
    'nova',
    'shimmer',
    'fable',
    'alloy',
    'echo',
    'onyx',
    'coral',
    'sage',
  ];

  final SecretStore _secrets;
  final http.Client _http;
  final String voiceName;
  final String model;

  @override
  String get mimeType => 'audio/mpeg';

  @override
  String get voiceSignature => 'openai/$model/$voiceName';

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
      throw const ProviderNotConfigured('No OpenAI API key configured.');
    }
    final response = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'authorization': 'Bearer $key',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'voice': voiceName,
        'input': text,
        'response_format': 'mp3',
        // The bedtime baseline always applies; the story's own direction is
        // added after it, so a cue colours the reading rather than replacing
        // the register a child is being settled with.
        'instructions': [
          'Read in a warm, gentle, soothing bedtime-storyteller voice for a '
              'young child. Unhurried and calming.',
          narrationDirection(standingDirection, cue),
        ].where((s) => s.isNotEmpty).join(' '),
      }),
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    return response.bodyBytes;
  }
}
