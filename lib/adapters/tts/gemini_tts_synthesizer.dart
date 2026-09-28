import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/narration.dart';
import '../ai/provider_exceptions.dart';
import '../ai/story_segment_codec.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// Gemini TTS (`gemini-3.8-flash-tts`, `responseModalities: [AUDIO]`).
/// Returns raw 16-bit PCM which we wrap in a WAV container. Reuses the parent's
/// Gemini key. See `docs/voice-tts.md`.
class GeminiTtsSynthesizer implements TtsSynthesizer {
  GeminiTtsSynthesizer({
    required SecretStore secrets,
    http.Client? httpClient,
    this.voiceName = 'Kore',
    this.model = defaultModel,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  /// Used when the grown-up hasn't chosen one in Voice setup.
  static const String defaultModel = 'gemini-3.8-flash-tts';

  static const String keyName = 'gemini';
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const List<String> voices = [
    'Kore',
    'Aoede',
    'Puck',
    'Zephyr',
    'Charon',
    'Fenrir',
  ];

  final SecretStore _secrets;
  final http.Client _http;
  final String voiceName;
  final String model;

  @override
  String get mimeType => 'audio/wav';

  @override
  String get voiceSignature => 'gemini/$model/$voiceName';

  @override
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationCue cue = const NarrationCue(),
    String standingDirection = '',
  }) async {
    final key = await _secrets.readKey(keyName);
    // Gemini's TTS takes its style as plain language ahead of the text. The
    // direction is a separate sentence before a colon, never mixed into the
    // story, so none of it can be spoken as part of the chapter.
    final direction = narrationDirection(standingDirection, cue);
    final prompt = direction.isEmpty ? text : '$direction\n\n$text';
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }
    final response = await _http.post(
      Uri.parse('$_base/$model:generateContent'),
      headers: {'content-type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voiceName},
            },
          },
        },
      }),
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    // Surface content blocks / safety stops with a clear reason (the story
    // provider does this too) so a rejected chapter isn't a mystery "no audio".
    final blockReason =
        (decoded['promptFeedback'] as Map<String, dynamic>?)?['blockReason'];
    if (blockReason != null) {
      throw ProviderRefusal('Voice blocked this text: $blockReason');
    }
    final candidate =
        (decoded['candidates'] as List<dynamic>?)?.firstOrNull
            as Map<String, dynamic>?;
    final finish = candidate?['finishReason'];
    if (finish != null && finish != 'STOP') {
      throw ProviderRefusal('Voice stopped: $finish');
    }
    final parts =
        (candidate?['content'] as Map<String, dynamic>?)?['parts']
            as List<dynamic>?;
    final inline =
        (parts?.firstOrNull as Map<String, dynamic>?)?['inlineData']
            as Map<String, dynamic>?;
    final data = inline?['data'] as String?;
    if (data == null || data.isEmpty) {
      throw ProviderRequestException(
        200,
        'No audio returned. ${extractApiError(response.body)}',
      );
    }
    final pcm = base64.decode(data);
    return pcmToWav(pcm, sampleRate: _rateFrom(inline?['mimeType'] as String?));
  }

  /// Parse the sample rate from a mime type like `audio/L16;rate=24000`.
  int _rateFrom(String? mime) {
    if (mime == null) return 24000;
    final match = RegExp(r'rate=(\d+)').firstMatch(mime);
    return match != null ? int.parse(match.group(1)!) : 24000;
  }
}
