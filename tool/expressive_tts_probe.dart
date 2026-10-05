/// Does Gemini 3.8 TTS's expressive markup survive contact with a child?
///
/// The 3.8 guide says the transcript is now read verbatim *except* inline
/// `<tags>`, and that direction travels separately in `speech_metadata.style`.
/// This app has been burnt by that exact promise before: stage directions sent
/// with the text were recited aloud, which is why the synthesizer currently
/// sends prose and nothing else. CLAUDE.md: anything a voice reads is spoken
/// literally. So nothing here is built on the guide's word — it is built on
/// what comes out of the speaker.
///
/// Designs a narrator voice and a Pip voice, synthesizes a line with direction
/// and vocal tags on both TTS models, then a two-voice scene, transcribes every
/// result, and reports whether a tag or a direction word was *spoken*. Audio is
/// written to the desktop to be listened to, because "performed" is a thing an
/// ear judges and a transcript cannot.
///
///     dart run tool/expressive_tts_probe.dart
///
/// Creates two stored voices in the Google project (reused on later runs, by
/// display name) and costs a handful of short syntheses and transcriptions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';

const _api = 'https://generativelanguage.googleapis.com/v1beta';
const _reader = 'gemini-3.8-flash';

const _narratorName = 'Moonloom Narrator';
const _narratorPrompt =
    'A warm, gentle bedtime storyteller in her fifties with a soft British '
    'accent. Low, soothing, unhurried voice with a smile in it; the kind of '
    'voice that makes a small child feel safe and sleepy.';

const _pipName = 'Moonloom Pip';

/// Pip as a cartoon character performed by an adult, never as a child.
///
/// The first prompt said "a bright, slightly squeaky young voice" and Voice
/// Design refused it: "Voice prompt was blocked by safety policies." Designing
/// a voice that sounds like a child is what the filter stops, and it is right
/// to — an app for children has no business synthesising one. Animation casts
/// these parts with adult performers, and the prompt now says so.
const _pipPrompt =
    'An adult voice actor performing a small, cheerful cartoon axolotl '
    'character in an animated bedtime series. Light, bright, playful tenor '
    'with a bubbly, friendly lilt; curious and kind, quick to laugh, never '
    'shrill.';

/// The line. Every tag is from the guide's recommended list.
const _line =
    'Pip stretched his little arms <yawn> and blinked up at the moon. '
    '<giggle> "One more story," he whispered. <short pause> "Just one."';

const _style = 'soft, sleepy, cosy bedtime reading';

/// Words that exist only in the markup or the direction. If any of these is
/// in the transcript, the child heard the machinery.
const _tells = [
  'yawn',
  'giggle',
  'short pause',
  'pause',
  'sleepy',
  'cosy',
  'bedtime reading',
  'style',
];

Future<String> _key() async {
  final prefs =
      jsonDecode(
            await File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  return dpapiUnprotect(
    base64.decode(prefs['flutter.enckey_gemini'] as String),
  );
}

/// A stored designed voice by display name, creating it if absent. Reused so
/// re-running this does not pile voices up against the project's 200 limit.
Future<String?> _voice(
  http.Client c,
  String key,
  String name,
  String prompt,
  Directory out,
) async {
  final listed = await c.get(
    Uri.parse('$_api/voices?type=prompted&page_size=200'),
    headers: {'x-goog-api-key': key},
  );
  if (listed.statusCode == 200) {
    final voices = (jsonDecode(listed.body) as Map)['voices'] as List? ?? [];
    for (final v in voices.cast<Map>()) {
      if (v['display_name'] == name) {
        stdout.writeln('  reusing $name  ${v['name'] ?? v['id']}');
        return (v['name'] ?? v['id']).toString().split('/').last;
      }
    }
  }
  final made = await c.post(
    Uri.parse('$_api/voices'),
    headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
    body: jsonEncode({
      'store': true,
      'voice': {
        'model': 'gemini-3.8-flash-tts',
        'type': 'prompted',
        'display_name': name,
        'language_code': 'en-GB',
        'prompted': {'input': prompt},
      },
    }),
  );
  if (made.statusCode != 200) {
    stdout.writeln(
      '  designing $name FAILED ${made.statusCode}: '
      '${made.body.substring(0, made.body.length.clamp(0, 300))}',
    );
    return null;
  }
  final body = jsonDecode(made.body) as Map;
  final id = (body['name'] ?? body['id'] ?? (body['voice'] as Map?)?['name'])
      .toString()
      .split('/')
      .last;
  final sample = (body['sample_audio'] as Map?)?['data'] as String?;
  if (sample != null) {
    File(
      '${out.path}\\$name preview.wav',
    ).writeAsBytesSync(base64.decode(sample));
  }
  stdout.writeln('  designed $name  $id');
  return id;
}

/// One /interactions TTS call; returns the WAV bytes or an error string.
Future<(List<int>?, String)> _speak(
  http.Client c,
  String key,
  Map<String, Object?> body,
) async {
  final r = await c.post(
    Uri.parse('$_api/interactions'),
    headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
    body: jsonEncode(body),
  );
  if (r.statusCode != 200) {
    return (
      null,
      '${r.statusCode} ${r.body.substring(0, r.body.length.clamp(0, 300))}',
    );
  }
  final steps = (jsonDecode(r.body) as Map)['steps'] as List? ?? [];
  String? data;
  for (final s in steps.cast<Map>()) {
    if (s['type'] != 'model_output') continue;
    for (final part in (s['content'] as List? ?? []).cast<Map>()) {
      if (part['type'] == 'audio') data = part['data'] as String?;
    }
  }
  return data == null ? (null, 'no audio in reply') : (base64.decode(data), '');
}

Future<String> _transcribe(http.Client c, String key, List<int> wav) async {
  final r = await c.post(
    Uri.parse('$_api/models/$_reader:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Transcribe only the words that are spoken in this audio, '
                  'word for word. Do not describe or mark non-speech sounds '
                  'such as laughter, yawns, breaths or pauses. Output only '
                  'the spoken words.',
            },
            {
              'inline_data': {
                'mime_type': 'audio/wav',
                'data': base64.encode(wav),
              },
            },
          ],
        },
      ],
    }),
  );
  if (r.statusCode != 200) return '[transcription ${r.statusCode}]';
  final parts =
      ((((jsonDecode(r.body) as Map)['candidates'] as List).first
                  as Map)['content']
              as Map)['parts']
          as List;
  return parts.map((p) => (p as Map)['text'] ?? '').join().trim();
}

void _report(String label, String transcript, int bytes) {
  final low = transcript.toLowerCase();
  final spoken = _tells.where(low.contains).toList();
  final secs = (bytes - 44) / 48000;
  stdout.writeln('\n$label  (${secs.toStringAsFixed(1)} s)');
  stdout.writeln('  heard: $transcript');
  stdout.writeln(
    spoken.isEmpty
        ? '  ✓ no tag or direction word was spoken'
        : '  ✗ SPOKEN ALOUD: ${spoken.join(', ')}',
  );
}

Future<void> main() async {
  final key = await _key();
  final c = http.Client();
  final out = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\moonloom-voices',
  )..createSync(recursive: true);

  stdout.writeln('voices');
  final narrator = await _voice(c, key, _narratorName, _narratorPrompt, out);
  final pip = await _voice(c, key, _pipName, _pipPrompt, out);

  for (final model in ['gemini-3.8-flash-lite-tts', 'gemini-3.8-flash-tts']) {
    for (final (label, voice) in [
      ('prebuilt Sulafat', 'Sulafat'),
      if (narrator != null) ('designed narrator', narrator),
    ]) {
      final (wav, err) = await _speak(c, key, {
        'model': model,
        'input': [
          {
            'type': 'user_input',
            'content': [
              {
                'type': 'text',
                'text': _line,
                'annotations': [
                  {'type': 'speech_metadata', 'style': _style},
                ],
              },
            ],
          },
        ],
        'response_format': {'type': 'audio'},
        'generation_config': {
          'speech_config': [
            {'voice': voice},
          ],
        },
      });
      final name = '$model - $label';
      if (wav == null) {
        stdout.writeln('\n$name\n  FAILED $err');
        continue;
      }
      File('${out.path}\\$name.wav').writeAsBytesSync(wav);
      _report(name, await _transcribe(c, key, wav), wav.length);
    }
  }

  // Narrator and Pip, two voices, one call.
  if (narrator != null && pip != null) {
    for (final model in ['gemini-3.8-flash-lite-tts', 'gemini-3.8-flash-tts']) {
      final (wav, err) = await _speak(c, key, {
        'model': model,
        'input': [
          {
            'type': 'user_input',
            'content': [
              {
                'type': 'text',
                'text':
                    'Pip swam up to the window and pressed his nose to the '
                    'glass. <breath>',
                'annotations': [
                  {
                    'type': 'speech_metadata',
                    'speaker': 'Narrator',
                    'style': 'gentle, hushed',
                  },
                ],
              },
              {
                'type': 'text',
                'text': '<giggle> Look! The moon is wearing a hat!',
                'annotations': [
                  {
                    'type': 'speech_metadata',
                    'speaker': 'Pip',
                    'style': 'delighted, whispering so as not to wake anyone',
                  },
                ],
              },
            ],
          },
        ],
        'response_format': {'type': 'audio'},
        'generation_config': {
          'speech_config': {
            'mode': 'conversational',
            'speakers': [
              {'speaker': 'Narrator', 'voice': narrator},
              {'speaker': 'Pip', 'voice': pip},
            ],
          },
        },
      });
      final name = '$model - narrator and Pip';
      if (wav == null) {
        stdout.writeln('\n$name\n  FAILED $err');
        continue;
      }
      File('${out.path}\\$name.wav').writeAsBytesSync(wav);
      _report(name, await _transcribe(c, key, wav), wav.length);
    }
  }

  stdout.writeln('\nListen: ${out.path}');
  c.close();
}
