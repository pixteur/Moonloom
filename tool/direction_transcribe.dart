/// Settle it by listening: transcribe the narration and look for the direction.
///
/// `tool/direction_leak_check.dart` showed the audio growing when direction is
/// prefixed, but duration cannot tell "the direction was recited" from "the
/// prose was read more slowly, as instructed" — and both are plausible, since
/// the direction says *unhurriedly*. Only the words settle it.
///
/// So this synthesizes each shape, hands the audio back to a Gemini text model
/// to transcribe, and reports whether the direction's own words come out of
/// the speaker. A transcript is evidence; a stopwatch is a hint.
///
///     dart run tool/direction_transcribe.dart
///
/// Costs one synthesis and one transcription per shape.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';
const _reader = 'gemini-3.8-flash';

const _prose =
    'Crystal knelt in the moss and cupped both hands around the glass. '
    'The light shone straight through her fingers, steady as ever.';

const _direction =
    'Read this warmly and unhurriedly, as a bedtime story for a child of six. '
    'For this passage: slow, hushed, wistful.';

/// Words that belong to the direction and appear nowhere in the prose. If any
/// of these is spoken, the direction reached the child.
const _tells = [
  'bedtime',
  'child of six',
  'hushed',
  'wistful',
  'passage',
  'warmly',
  'unhurriedly',
];

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

Future<String?> _speak(
  http.Client client,
  String key,
  String model,
  String text,
) async {
  final response = await client.post(
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
            'prebuiltVoiceConfig': {'voiceName': 'Sulafat'},
          },
        },
      },
    }),
  );
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return ((((decoded['candidates'] as List).first as Map)['content']
              as Map)['parts']
          as List)
      .map((p) => ((p as Map)['inlineData'] as Map?)?['data'])
      .whereType<String>()
      .join();
}

Future<String> _transcribe(
  http.Client client,
  String key,
  String pcmBase64,
) async {
  // Gemini TTS returns raw 16-bit PCM at 24 kHz; say so, since there is no
  // container to tell the reader.
  final response = await client.post(
    Uri.parse('$_base/$_reader:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Transcribe this audio word for word. Output only the '
                  'words spoken, nothing else.',
            },
            {
              'inline_data': {
                'mime_type': 'audio/L16; rate=24000',
                'data': pcmBase64,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'thinkingConfig': {'thinkingBudget': 0},
      },
    }),
  );
  if (response.statusCode != 200) {
    final flat = response.body.replaceAll(RegExp(r'\s+'), ' ');
    return '[${response.statusCode}] '
        '${flat.length > 200 ? flat.substring(0, 200) : flat}';
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return ((((decoded['candidates'] as List).first as Map)['content']
              as Map)['parts']
          as List)
      .map((p) => (p as Map)['text'] ?? '')
      .join()
      .trim();
}

Future<void> main(List<String> args) async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();
  final at = args.indexOf('--model');
  final model = at >= 0 && at + 1 < args.length
      ? args[at + 1]
      : GeminiTtsSynthesizer.defaultModel;
  stdout.writeln('speaking with: $model');
  stdout.writeln('transcribing with: $_reader\n');

  final shapes = <String, String>{
    'prose alone (control)': _prose,
    'direction, blank line, prose (what we send)': '$_direction\n\n$_prose',
    // The form Google's own examples use: one short imperative, a colon,
    // then the words. "Say cheerfully: Have a wonderful day!"
    'Say <how>: <prose>': 'Say warmly and unhurriedly: $_prose',
    'Read <how>: <prose>': 'Read in a slow, hushed, wistful voice: $_prose',
    // Same imperative, but carrying everything the cue holds, to find where
    // obedience turns back into recitation.
    'Say <everything the cue holds>: <prose>':
        'Say this warmly and unhurriedly, slow and hushed and wistful, as a '
        'bedtime story for a child of six: $_prose',
  };

  for (final entry in shapes.entries) {
    stdout.writeln('── ${entry.key} ──');
    final audio = await _speak(client, key, model, entry.value);
    if (audio == null) {
      stdout.writeln('  synthesis failed\n');
      continue;
    }
    final said = await _transcribe(client, key, audio);
    final leaked = _tells.where((t) => said.toLowerCase().contains(t)).toList();
    stdout.writeln('  heard: ${said.replaceAll('\n', ' ')}');
    stdout.writeln(
      leaked.isEmpty
          ? '  CLEAN — no direction words spoken'
          : '  LEAKED — spoke: ${leaked.join(', ')}',
    );
    stdout.writeln();
  }
  client.close();
}
