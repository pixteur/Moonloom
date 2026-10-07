import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/narration.dart';
import '../../domain/performance.dart';
import '../ai/provider_exceptions.dart';
import '../audio/wav.dart';
import '../ai/story_segment_codec.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';
import 'voice_catalog.dart';

/// Gemini TTS. Reuses the parent's Gemini key. See `docs/voice-tts.md`.
///
/// Two request shapes, because Gemini has two:
///
///   * **3.8 models** go through `/v1beta/interactions`, which takes a request
///     as a list of parts, each with its own speaker and its own delivery in
///     `speech_metadata`. The narrator reads, the hero speaks their own lines
///     in their own voice, and the narrator acts everyone else — one call,
///     one continuous recording. Voices may be prebuilt names or `voice_…`
///     ids designed from a description.
///   * **Older models** keep `generateContent` and are sent the prose alone;
///     see the comment in [_legacy] for why.
class GeminiTtsSynthesizer implements TtsSynthesizer {
  GeminiTtsSynthesizer({
    required SecretStore secrets,
    http.Client? httpClient,
    this.voiceName = 'Kore',
    this.model = defaultModel,
    this.heroName,
    this.heroVoice,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  /// Used when the grown-up hasn't chosen one in Voice setup.
  static const String defaultModel = 'gemini-3.8-flash-lite-tts';

  static const String keyName = 'gemini';
  static const String _api = 'https://generativelanguage.googleapis.com/v1beta';

  /// The speaker labels a conversational request uses. Labels, not names: the
  /// hero's name changes with every world, and these only have to match
  /// between the speaker list and each part.
  static const String narratorLabel = 'Narrator';
  static const String heroLabel = 'Hero';

  /// Every prebuilt voice Gemini offers, bedtime-suited first. The catalogue
  /// carries the friendly names; this is just the ids, in the same order.
  static List<String> get voices => [for (final v in geminiVoices) v.id];

  final SecretStore _secrets;
  final http.Client _http;

  /// The narrator: a prebuilt voice name, or a designed `voice_…` id.
  final String voiceName;
  final String model;

  /// Who has a voice of their own, and that voice. Both null when nobody does,
  /// which is always the case when the child is the hero.
  final String? heroName;
  final String? heroVoice;

  bool get _hasHero =>
      (heroName?.trim().isNotEmpty ?? false) &&
      (heroVoice?.trim().isNotEmpty ?? false);

  /// The 3.8 models take speaker and delivery per part. Earlier ones do not.
  bool get _expressive => model.startsWith('gemini-3.8');

  @override
  String get mimeType => 'audio/wav';

  /// The narrator's signature is unchanged from before heroes had voices, so
  /// every chapter already recorded is still found. A hero voice is added only
  /// when there is one — it changes whose voice a line is in, so a story read
  /// with Pip's voice and one read without it must not share recordings.
  @override
  String get voiceSignature => _hasHero
      ? 'gemini/$model/$voiceName+${heroName!.trim()}=${heroVoice!.trim()}'
      : 'gemini/$model/$voiceName';

  @override
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationCue cue = const NarrationCue(),
    String standingDirection = '',
    List<SpeechPart> parts = const [],
  }) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }
    if (!_expressive) return _legacy(key, text);

    final performance = parts.isNotEmpty
        ? parts
        : [
            SpeechPart(
              text,
              PartVoice.narrator,
              [
                if (standingDirection.trim().isNotEmpty)
                  standingDirection.trim(),
                if (!cue.isEmpty) cue.asDirection(),
              ].join('. '),
            ),
          ];
    // Two voices only when a hero voice exists AND the hero actually speaks
    // here. A chunk of pure narration stays a single-voice request.
    final conversational =
        _hasHero && performance.any((p) => p.voice == PartVoice.hero);

    final response = await _http.post(
      Uri.parse('$_api/interactions'),
      headers: {'content-type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'model': model,
        'input': [
          {
            'type': 'user_input',
            'content': [
              for (final part in performance)
                _part(part, conversational: conversational),
            ],
          },
        ],
        'response_format': {'type': 'audio'},
        'generation_config': {
          'speech_config': conversational
              ? {
                  'mode': 'conversational',
                  'speakers': [
                    {'speaker': narratorLabel, 'voice': voiceName},
                    {'speaker': heroLabel, 'voice': heroVoice},
                  ],
                }
              : [
                  {'voice': voiceName},
                ],
        },
      }),
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }

    String? data;
    final steps =
        (jsonDecode(response.body) as Map<String, dynamic>)['steps'] as List? ??
        const [];
    for (final step in steps.cast<Map<String, dynamic>>()) {
      if (step['type'] != 'model_output') continue;
      for (final c in (step['content'] as List? ?? const []).cast<Map>()) {
        if (c['type'] == 'audio') data = c['data'] as String?;
      }
    }
    if (data == null || data.isEmpty) {
      throw ProviderRequestException(
        200,
        'No audio returned. ${extractApiError(response.body)}',
      );
    }
    return _sound(base64.decode(data));
  }

  /// One part of the request. The text is the story's own words and nothing
  /// else; delivery and speaker travel in `speech_metadata`, which the voice
  /// acts on and never reads.
  Map<String, Object?> _part(SpeechPart part, {required bool conversational}) {
    final metadata = <String, Object?>{
      'type': 'speech_metadata',
      if (conversational)
        'speaker': part.voice == PartVoice.hero ? heroLabel : narratorLabel,
      if (part.style.trim().isNotEmpty) 'style': part.style.trim(),
    };
    return {
      'type': 'text',
      'text': spokenSafe(part.text),
      // An annotation with nothing in it is noise; a conversational part must
      // always name its speaker, so it always has one.
      if (metadata.length > 1) 'annotations': [metadata],
    };
  }

  /// The prose with every character the 3.8 transcript treats as markup
  /// removed: `<…>` is a vocal tag and `|…|` a listener's interjection. Story
  /// prose never means either, and a stray one would be performed rather than
  /// read. Vocal tags the app *does* want are added after this, from a fixed
  /// list, never from the story text.
  static String spokenSafe(String text) =>
      text.replaceAll(RegExp(r'[<>|]'), '');

  /// Older models: `generateContent`, prose only.
  Future<Uint8List> _legacy(String key, String text) async {
    // Only the prose. These models do not take direction — they RECITE it.
    //
    // This adapter used to send "Read this warmly and unhurriedly… For this
    // passage: slow, hushed, wistful" ahead of the chapter. Transcribing the
    // output (`tool/direction_transcribe.dart`) showed the words coming out of
    // the speaker, every time, in every shape, and `system_instruction` is
    // refused. The 3.8 models fixed this by giving direction a field of its
    // own (`speech_metadata.style`), which the path above uses — verified by
    // transcription in `tool/expressive_tts_probe.dart`.
    final response = await _http.post(
      Uri.parse('$_api/models/$model:generateContent'),
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
    final reply = base64.decode(data);
    // The 3.8 models answer even this endpoint with a complete WAV where the
    // older ones answered raw PCM. Wrapping that in a header of its own put a
    // whole WAV inside another — a tick of header at the start and Google's
    // C2PA manifest played as static at the end.
    return _isRiff(reply)
        ? _sound(reply)
        : pcmToWav(
            reply,
            sampleRate: _rateFrom(inline?['mimeType'] as String?),
          );
  }

  static bool _isRiff(Uint8List b) =>
      b.length > 4 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46;

  /// The sound Google sent, and nothing else.
  ///
  /// Every 3.8 WAV ends with a `C2PA` chunk: a ~6 KB signed Content
  /// Credentials manifest marking the audio as AI-made. A RIFF reader skips
  /// it; this app's polish did not, and played it as 126 ms of static at the
  /// end of every clip. It is dropped here, at the door, so nothing downstream
  /// can mistake it for sound. (The manifest signs the audio exactly as
  /// returned; the polish changes that audio, so the signature could not have
  /// survived anyway. The app says plainly elsewhere that stories and voices
  /// are AI-made.)
  static Uint8List _sound(Uint8List reply) =>
      _isRiff(reply) ? plainWav(reply) : pcmToWav(reply, sampleRate: 24000);

  /// Parse the sample rate from a mime type like `audio/L16;rate=24000`.
  int _rateFrom(String? mime) {
    if (mime == null) return 24000;
    final match = RegExp(r'rate=(\d+)').firstMatch(mime);
    return match != null ? int.parse(match.group(1)!) : 24000;
  }
}
