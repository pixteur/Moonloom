/// Render the same passage three ways so two voices can be judged by ear.
///
/// Gemini's multi-speaker mode is capped at exactly two voices (measured in
/// `tool/multispeaker_probe.dart`), which forces a real choice on a story that
/// has a narrator and more than one character. There is no arrangement that
/// gives all three their own voice, so this produces the arrangements that do
/// exist and leaves the judgement where it belongs — with somebody listening.
///
///   one    what the app does today: a single narrator doing the voices
///   A      narrator + one character; the other character shares the narrator
///   B      two characters; the narration rides on the first one's voice
///
/// Each is written through `polishNarration`, so what you hear is what the app
/// would actually save — paragraph pauses lengthened, slow drift flattened.
///
///     dart run tool/two_voice_test.dart
///     dart run tool/two_voice_test.dart --model gemini-3.8-flash-tts
///
/// Costs three short syntheses. Writes WAV files to the Desktop.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sleepytime/adapters/secrets/dpapi.dart';
import 'package:sleepytime/adapters/tts/audio_polish.dart';
import 'package:sleepytime/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:sleepytime/adapters/tts/voice_catalog.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

/// Two paragraphs of real bedtime prose: narration, then both characters
/// speaking, so every arrangement has something to show.
const _lines = <(String, String)>[
  (
    'Narrator',
    'Crystal loved the quietest corners of the Whispering Woods, where the '
        'moss grew thick as velvet cushions. Tonight the evening air smelled '
        'of damp pine needles and sleepy clover, and a small brass lantern '
        'sat glowing in a hollow stump, with no candle inside and no switch '
        'to be found.',
  ),
  ('Crystal', 'It is warm, but it is not burning. What keeps it alight?'),
  (
    'Bolt',
    'We usually turn lanterns down when the stars come out. This one does '
        'not want to sleep.',
  ),
  (
    'Narrator',
    'Crystal knelt in the moss and cupped both hands around the glass. The '
        'light shone straight through her fingers, steady as ever, and '
        'somewhere behind them the crickets began again.',
  ),
  ('Crystal', 'Then we shall have to sing it a lullaby of its own.'),
];

Future<String?> _key() async {
  final file = File(
    '${Platform.environment['APPDATA']}'
    r'\com.pixteur\sleepytime\shared_preferences.json',
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

/// Gemini returns raw PCM; the adapter wraps it, and so must we.
Uint8List _wav(List<int> pcm, {int rate = 24000}) {
  final out = BytesBuilder();
  void str(String s) => out.add(s.codeUnits);
  void u32(int v) =>
      out.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void u16(int v) => out.add([v & 0xFF, (v >> 8) & 0xFF]);
  str('RIFF');
  u32(36 + pcm.length);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(pcm.length);
  out.add(pcm);
  return out.toBytes();
}

Future<void> _render(
  http.Client client,
  String key,
  String model,
  String label,
  Map<String, dynamic> speechConfig,
  List<Map<String, dynamic>> parts,
  Directory outDir,
) async {
  stdout.write('${label.padRight(46)} ');
  final response = await client.post(
    Uri.parse('$_base/$model:generateContent'),
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
    stdout.writeln(response.statusCode.toString());
    stdout.writeln(
      '   ${flat.length > 200 ? '${flat.substring(0, 200)}…' : flat}',
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

  final raw = _wav(base64.decode(b64));
  final polished = polishNarration(Uint8List.fromList(raw));
  final file = File('${outDir.path}\\$label.wav');
  await file.writeAsBytes(polished);

  final tokens = (usage['candidatesTokenCount'] as int?) ?? 0;
  stdout.writeln(
    'ok  ${(tokens / 25).toStringAsFixed(1)} s  '
    '${(polished.length / 1024).toStringAsFixed(0)} KB  '
    '-> ${file.path.split(r'\').last}',
  );
}

Future<void> main(List<String> args) async {
  final at = args.indexOf('--model');
  final model = at >= 0 && at + 1 < args.length
      ? args[at + 1]
      : GeminiTtsSynthesizer.defaultModel;
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();

  final outDir = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\sleepytime-voice-test',
  );
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  stdout.writeln('model: $model');
  stdout.writeln('out:   ${outDir.path}\n');

  // Voices, in the friendly names the picker now shows.
  const narratorId = 'Sulafat'; // Honey — warm
  const crystalId = 'Vindemiatrix'; // Willow — gentle
  const boltId = 'Algenib'; // Boulder — gravelly

  Map<String, dynamic> speakers(
    (String, String) first,
    (String, String) second,
  ) => {
    'multiSpeakerVoiceConfig': {
      'speakerVoiceConfigs': [
        for (final s in [first, second])
          {
            'speaker': s.$1,
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': s.$2},
            },
          },
      ],
    },
  };

  // What the app used to send: the direction ahead of the prose. Kept so the
  // bug is audible — the narrator reads its own stage directions to the child
  // before the story starts.
  await _render(
    client,
    key,
    model,
    '0-BEFORE-direction-spoken-aloud',
    {
      'voiceConfig': {
        'prebuiltVoiceConfig': {'voiceName': narratorId},
      },
    },
    [
      {
        'text':
            'Read this warmly and unhurriedly, as a bedtime story. Voice the '
            'characters: Crystal, gentle and curious; Bolt, low and rumbling '
            'with a soft metallic edge.\n\n'
            '${_lines.map((l) => l.$2).join('\n\n')}',
      },
    ],
    outDir,
  );

  // What it sends now: the prose and nothing else.
  await _render(
    client,
    key,
    model,
    '1-AFTER-one-voice-prose-only',
    {
      'voiceConfig': {
        'prebuiltVoiceConfig': {'voiceName': narratorId},
      },
    },
    [
      {'text': _lines.map((l) => l.$2).join('\n\n')},
    ],
    outDir,
  );

  // A: the narrator gets their own voice, Bolt gets the second, and Crystal
  // shares the narrator's. Natural for a story where one character is "the"
  // character of the chapter.
  await _render(
    client,
    key,
    model,
    '2-A-narrator-plus-Bolt',
    speakers(('Narrator', narratorId), ('Bolt', boltId)),
    [
      for (final line in _lines)
        {
          'text': line.$2,
          'speech_metadata': {
            'speaker': line.$1 == 'Bolt' ? 'Bolt' : 'Narrator',
          },
        },
    ],
    outDir,
  );

  // B: both characters get their own voice, and the narration rides on
  // Crystal's. Two characters really are distinct; the narrator is not.
  await _render(
    client,
    key,
    model,
    '3-B-Crystal-and-Bolt',
    speakers(('Crystal', crystalId), ('Bolt', boltId)),
    [
      for (final line in _lines)
        {
          'text': line.$2,
          'speech_metadata': {
            'speaker': line.$1 == 'Bolt' ? 'Bolt' : 'Crystal',
          },
        },
    ],
    outDir,
  );

  stdout.writeln('\nvoices used');
  for (final id in [narratorId, crystalId, boltId]) {
    stdout.writeln(
      '  ${voiceLabel(id).padRight(10)} ${id.padRight(14)} '
      '${voiceCharacter(id)}',
    );
  }
  client.close();
}
