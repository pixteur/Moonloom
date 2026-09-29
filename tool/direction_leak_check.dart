/// Is the narration direction being spoken to the child?
///
/// The Gemini adapter sends direction as a sentence before the prose —
/// "Read this warmly and unhurriedly... Voice the characters: Crystal, gentle
/// and curious" — separated by a blank line, on the assumption the model
/// treats it as instruction. `tool/two_voice_test.dart` produced 72,2 seconds
/// of audio for a passage that the same model read in 55,0 seconds without
/// that prefix, and the prefix is about seventeen seconds of speech. That is
/// the shape of a leak, not proof of one.
///
/// This settles it the only way available without listening: synthesize the
/// same prose three times — bare, with a short direction, with a long one —
/// and compare durations. If the audio grows by roughly the length of the
/// direction, the direction is being read out.
///
///     dart run tool/direction_leak_check.dart
///
/// Costs three short syntheses.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

/// Short enough that the direction is a large fraction of the whole, so a
/// leak is unmissable rather than a rounding error.
const _prose =
    'Crystal knelt in the moss and cupped both hands around the glass. '
    'The light shone straight through her fingers, steady as ever.';

const _shortDirection = 'Read this warmly and unhurriedly.';

const _longDirection =
    'Read this warmly and unhurriedly, as a bedtime story for a child of six. '
    'Voice the characters: Crystal, gentle and curious; Bolt, low and '
    'rumbling with a soft metallic edge. For this passage: slow, hushed, '
    'wistful. Linger on the last line.';

Future<String?> _key() async {
  final file = File(
    '${Platform.environment['APPDATA']}'
    r'\com.pixteur\moonloom\shared_preferences.json',
  );
  if (!file.existsSync()) return null;
  final prefs = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final stored = prefs['flutter.enckey_gemini'] as String?;
  if (stored == null) return null;
  try {
    return dpapiUnprotect(base64.decode(stored));
  } catch (_) {
    return null;
  }
}

Future<double> _seconds(
  http.Client client,
  String key,
  String model,
  String text, {
  String? system,
}) async {
  final response = await client.post(
    Uri.parse('$_base/$model:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      if (system != null)
        'system_instruction': {
          'parts': [
            {'text': system},
          ],
        },
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
            'prebuiltVoiceConfig': {'voiceName': 'Sulafat'},
          },
        },
      },
    }),
  );
  if (response.statusCode != 200) {
    final flat = response.body.replaceAll(RegExp(r'\s+'), ' ');
    stdout.writeln(
      '  ${response.statusCode}: '
      '${flat.length > 200 ? flat.substring(0, 200) : flat}',
    );
    return -1;
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final usage = decoded['usageMetadata'] as Map<String, dynamic>? ?? const {};
  // 25 audio tokens per second of audio, per Google's own pricing note.
  return ((usage['candidatesTokenCount'] as int?) ?? 0) / 25;
}

Future<void> main(List<String> args) async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();
  final model = GeminiTtsSynthesizer.defaultModel;
  stdout.writeln('model: $model\n');

  final bare = await _seconds(client, key, model, _prose);
  final short = await _seconds(
    client,
    key,
    model,
    '$_shortDirection\n\n$_prose',
  );
  final long = await _seconds(client, key, model, '$_longDirection\n\n$_prose');

  stdout.writeln('prose alone                 ${bare.toStringAsFixed(1)} s');
  stdout.writeln(
    'with a short direction      ${short.toStringAsFixed(1)} s  '
    '(+${(short - bare).toStringAsFixed(1)})',
  );
  stdout.writeln(
    'with a long direction       ${long.toStringAsFixed(1)} s  '
    '(+${(long - bare).toStringAsFixed(1)})',
  );

  // A direction read aloud costs about a second every three words.
  final longWords = _longDirection.split(RegExp(r'\s+')).length;
  final expectedIfSpoken = longWords / 2.6;
  stdout.writeln(
    '\nthe long direction is $longWords words — about '
    '${expectedIfSpoken.toStringAsFixed(0)} s if read aloud',
  );
  stdout.writeln(
    (long - bare) > expectedIfSpoken * 0.6
        ? 'VERDICT: the direction is being SPOKEN. It must not enter the text.'
        : 'VERDICT: the direction is being obeyed, not read.',
  );

  // Which shape does the model treat as instruction rather than script?
  // Anything close to the bare duration is being obeyed; anything much
  // longer is being recited.
  stdout.writeln('\n── other ways to say it ──');
  final shapes = <String, Future<double> Function()>{
    'direction: prose  (the documented form)': () =>
        _seconds(client, key, model, '$_longDirection $_prose'),
    'system_instruction, prose alone': () =>
        _seconds(client, key, model, _prose, system: _longDirection),
    'system_instruction + "TTS the following"': () => _seconds(
      client,
      key,
      model,
      'TTS the following:\n$_prose',
      system: _longDirection,
    ),
  };
  for (final entry in shapes.entries) {
    final s = await entry.value();
    final over = s - bare;
    stdout.writeln(
      '${entry.key.padRight(44)} ${s.toStringAsFixed(1)} s  '
      '(+${over.toStringAsFixed(1)})  '
      '${over < expectedIfSpoken * 0.4 ? 'OBEYED' : 'recited'}',
    );
  }
  client.close();
}
