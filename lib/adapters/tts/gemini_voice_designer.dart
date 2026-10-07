/// Designing voices from a description, with Gemini's Voice Design API.
///
/// A designed voice is described in plain words — "a warm, gentle bedtime
/// storyteller with a soft British accent" — and saved in the parent's Google
/// project as a `voice_…` id, which the 3.8 voices then accept anywhere a
/// prebuilt name goes. That is how a world gets a storyteller of its own and a
/// character gets a voice of their own.
///
/// Two rules learned against the real API, and kept here so nobody relearns
/// them (`tool/expressive_tts_probe.dart`):
///
///   * **A voice that sounds like a child is refused** — "Voice prompt was
///     blocked by safety policies" — so a character is always described as an
///     adult voice actor performing them, which is how animation casts these
///     parts anyway. [characterPrompt] writes that framing.
///   * **The preview audio is a Gemini WAV**, and Gemini's WAVs end with a C2PA
///     manifest that plays as static if read naively. It goes through
///     [plainWav] like every other reply.
///
/// Stored voices are kept by Google for a year and a project holds 200.
/// See `docs/voice-tts.md`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../ai/provider_exceptions.dart';
import '../ai/story_segment_codec.dart';
import '../audio/wav.dart';
import '../secrets/secret_store.dart';

/// One designed voice in the parent's project.
class DesignedVoice {
  const DesignedVoice({
    required this.id,
    required this.name,
    this.prompt = '',
    this.preview,
  });

  /// The `voice_…` id the voice models take.
  final String id;

  /// The name it was saved under, e.g. "Moonloom Pip".
  final String name;

  /// The description it was designed from, when the service says.
  final String prompt;

  /// A short sample of the voice, as a plain WAV — present right after
  /// designing, and when asked for one voice by id.
  final Uint8List? preview;
}

class GeminiVoiceDesigner {
  GeminiVoiceDesigner({required SecretStore secrets, http.Client? httpClient})
    : _secrets = secrets, // ignore: prefer_initializing_formals
      _http = httpClient ?? http.Client();

  static const String _api = 'https://generativelanguage.googleapis.com/v1beta';

  /// Voices this app designs carry this in their name, so its own voices can
  /// be told from anything else in the parent's project.
  static const String namePrefix = 'Moonloom ';

  /// Designed against this model; the guide says both 3.8 voices accept it.
  static const String designModel = 'gemini-3.8-flash-tts';

  final SecretStore _secrets;
  final http.Client _http;

  Future<String> _key() async {
    final key = await _secrets.readKey('gemini');
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }
    return key;
  }

  /// The description for a character's voice: an adult performing them.
  ///
  /// Never the character as a child, because that is refused — and because the
  /// app should not be making a child's voice in the first place.
  static String characterPrompt(String name, String description) {
    final who = description.trim().isEmpty
        ? 'a friendly character called $name'
        : '$name, ${description.trim()}';
    return 'An adult voice actor performing $who, in an animated bedtime '
        'series for young children. Warm, expressive and kind, with a '
        'playful lilt; gentle enough for bedtime, never shrill or harsh.';
  }

  /// Bedtime storytellers to start from, so a parent is not asked to write a
  /// voice description from nothing.
  static const narratorIdeas = {
    'Gentle grandmother':
        'A warm, gentle grandmother in her late sixties telling bedtime '
        'stories. Soft, slow and soothing, with a smile in her voice and a '
        'calm, safe warmth.',
    'Cosy storyteller':
        'A cosy, soft-spoken storyteller in his forties. Low, warm and '
        'unhurried, the voice of a parent reading at the bedside.',
    'Twinkly fairy-tale teller':
        'A bright, twinkly fairy-tale narrator in her thirties with a light '
        'British accent. Gentle wonder and quiet delight, never loud.',
  };

  /// Design and save a voice. Returns it with a preview to play.
  Future<DesignedVoice> design({
    required String name,
    required String prompt,
    String languageCode = 'en-GB',
  }) async {
    final key = await _key();
    final response = await _http.post(
      Uri.parse('$_api/voices'),
      headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
      body: jsonEncode({
        'store': true,
        'voice': {
          'model': designModel,
          'type': 'prompted',
          'display_name': '$namePrefix$name',
          'language_code': languageCode,
          'prompted': {'input': prompt},
        },
      }),
    );
    if (response.statusCode != 200) {
      final why = extractApiError(response.body);
      throw ProviderRequestException(
        response.statusCode,
        why.contains('safety')
            ? 'That description was refused by the voice service ($why). '
                  'Describe a grown-up performer rather than a child.'
            : why,
      );
    }
    return _voiceFrom(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// The voices this app has designed in the parent's project.
  Future<List<DesignedVoice>> list() async {
    final key = await _key();
    final response = await _http.get(
      Uri.parse('$_api/voices?type=prompted&page_size=200'),
      headers: {'x-goog-api-key': key},
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    final voices =
        (jsonDecode(response.body) as Map<String, dynamic>)['voices']
            as List? ??
        const [];
    return [
      for (final v in voices.cast<Map<String, dynamic>>())
        if ((v['display_name'] as String? ?? '').startsWith(namePrefix))
          _voiceFrom(v),
    ];
  }

  /// One voice by id, with its preview.
  Future<DesignedVoice> get(String id) async {
    final key = await _key();
    final response = await _http.get(
      Uri.parse('$_api/voices/$id'),
      headers: {'x-goog-api-key': key},
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    return _voiceFrom(jsonDecode(response.body) as Map<String, dynamic>);
  }

  DesignedVoice _voiceFrom(Map<String, dynamic> v) {
    final rawId = (v['name'] ?? v['id'] ?? '').toString();
    final display = (v['display_name'] as String?) ?? rawId;
    final sample = (v['sample_audio'] as Map?)?['data'] as String?;
    return DesignedVoice(
      id: rawId.split('/').last,
      name: display.startsWith(namePrefix)
          ? display.substring(namePrefix.length)
          : display,
      prompt: ((v['prompted'] as Map?)?['input'] as String?) ?? '',
      preview: sample == null ? null : plainWav(base64.decode(sample)),
    );
  }
}

/// Whether a voice id is a designed voice rather than a prebuilt name.
bool isDesignedVoice(String voice) => voice.startsWith('voice_');
