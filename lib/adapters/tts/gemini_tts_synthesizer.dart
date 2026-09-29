import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/narration.dart';
import '../ai/provider_exceptions.dart';
import '../ai/story_segment_codec.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';
import 'voice_catalog.dart';

/// Gemini TTS (`gemini-3.8-flash-lite-tts`, `responseModalities: [AUDIO]`).
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
  static const String defaultModel = 'gemini-3.8-flash-lite-tts';

  static const String keyName = 'gemini';
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Every prebuilt voice Gemini offers, bedtime-suited first. The catalogue
  /// carries the friendly names; this is just the ids, in the same order.
  static List<String> get voices => [for (final v in geminiVoices) v.id];

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
    // Only the prose. Gemini TTS does not take direction — it RECITES it.
    //
    // This adapter used to send "Read this warmly and unhurriedly… For this
    // passage: slow, hushed, wistful" ahead of the chapter, on the assumption
    // the model would treat it as instruction. It does not. Transcribing the
    // output (`tool/direction_transcribe.dart`) shows the words coming out of
    // the speaker, in front of the story, every time:
    //
    //   heard: "Read this warmly and unhurriedly, as a bedtime story for a
    //   child of six. For this passage, slow, hushed, wistful. Crystal knelt
    //   in the moss…"
    //
    // Every shape leaks, including the imperative form Google's own examples
    // use ("Say cheerfully: …"), and every TTS model leaks — 3.8 flash,
    // 3.8 flash-lite and 2.5 all recite some or all of it. There is no style
    // field on `speechConfig` for a prebuilt voice and `system_instruction` is
    // refused ("Developer instruction is not enabled for this model"), so
    // there is nowhere for direction to go.
    //
    // Which makes removing it a strict improvement rather than a loss: the
    // direction was never being obeyed, only read out. The cue still reaches
    // the engines that have somewhere to put it — OpenAI's `instructions`
    // field, ElevenLabs' audio tags — and still keys the cache, so a chapter
    // re-directed still re-records. This is the trap in CLAUDE.md, found
    // inside the app's own adapter: anything a voice is handed, it speaks.
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
              {'text': text},
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
