/// Read-mostly: does Gemini TTS actually do more than one voice in a request,
/// and what does it cost when it does?
///
/// `NarrationNotes.characterVoices` currently travels as direction to a single
/// narrator — "Leo, precise and warm with a soft metallic edge" — on the
/// reasoning that one narrator shifting tone works on every engine and is
/// gentler at bedtime than hard voice switches. That reasoning was never
/// tested against the API. This tests it: what the endpoint accepts, how many
/// speakers, and whether the text has to be marked up (which would be a
/// problem, since markup in a chapter is markup a voice can read aloud).
///
///     dart run tool/multispeaker_probe.dart
///
/// Costs two short syntheses.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

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

Future<void> _try(
  http.Client client,
  String key,
  String label,
  Map<String, dynamic> speechConfig,
  Object text,
) async {
  stdout.write('${label.padRight(38)} ');
  // A plain string is one part; a list of (speaker, line) pairs becomes one
  // part each carrying speech_metadata. The attribution travels as structure
  // rather than inside the prose, which is the only shape that is safe here:
  // anything written into the text itself is text a voice can read out.
  final parts = text is String
      ? [
          {'text': text},
        ]
      : [
          for (final line in text as List<(String, String)>)
            {
              'text': line.$2,
              'speech_metadata': {'speaker': line.$1},
            },
        ];
  final response = await client.post(
    Uri.parse('$_base/${GeminiTtsSynthesizer.defaultModel}:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': speechConfig,
      },
    }),
  );
  if (response.statusCode != 200) {
    final flat = response.body.replaceAll(RegExp(r'\s+'), ' ');
    stdout.writeln('${response.statusCode}');
    stdout.writeln(
      '   ${flat.length > 220 ? '${flat.substring(0, 220)}…' : flat}',
    );
    return;
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final usage = decoded['usageMetadata'] as Map<String, dynamic>? ?? const {};
  final b64 =
      ((((decoded['candidates'] as List).first as Map)['content']
                  as Map)['parts']
              as List)
          .map((p) => ((p as Map)['inlineData'] as Map?)?['data'])
          .whereType<String>()
          .join();
  final bytes = base64.decode(b64).length;
  final audioTokens = (usage['candidatesTokenCount'] as int?) ?? 0;
  stdout.writeln(
    'ok  ${(bytes / 1024).toStringAsFixed(0)} KB  '
    '$audioTokens audio tokens  '
    '(${(audioTokens / 25).toStringAsFixed(1)} s)',
  );
}

Future<void> main() async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();
  stdout.writeln('model: ${GeminiTtsSynthesizer.defaultModel}\n');

  // What the app does today: one voice, direction in prose.
  await _try(
    client,
    key,
    'one voice, direction in prose',
    {
      'voiceConfig': {
        'prebuiltVoiceConfig': {'voiceName': 'Kore'},
      },
    },
    'Read warmly, voicing Bolt with a soft metallic edge: '
        'Crystal lifted the lantern. "Are we nearly there?" asked Bolt.',
  );

  // Two named speakers, the text tagged with who says what.
  await _try(
    client,
    key,
    'two speakers, multiSpeakerVoiceConfig',
    {
      'multiSpeakerVoiceConfig': {
        'speakerVoiceConfigs': [
          {
            'speaker': 'Narrator',
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Kore'},
            },
          },
          {
            'speaker': 'Bolt',
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Puck'},
            },
          },
        ],
      },
    },
    const [
      ('Narrator', 'Crystal lifted the lantern high above the ferns.'),
      ('Bolt', 'Are we nearly there?'),
      ('Narrator', 'The crickets went quiet for a moment.'),
    ],
  );

  // Three, to find the ceiling.
  await _try(
    client,
    key,
    'three speakers — is there a limit?',
    {
      'multiSpeakerVoiceConfig': {
        'speakerVoiceConfigs': [
          for (final v in [
            ('Narrator', 'Kore'),
            ('Bolt', 'Puck'),
            ('Crystal', 'Aoede'),
          ])
            {
              'speaker': v.$1,
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': v.$2},
              },
            },
        ],
      },
    },
    const [
      ('Narrator', 'The lantern would not go out.'),
      ('Bolt', 'Perhaps it is not tired.'),
      ('Crystal', 'Then we shall sing it to sleep.'),
    ],
  );

  client.close();
}
