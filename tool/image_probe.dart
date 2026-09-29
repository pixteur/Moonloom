/// What the image models actually do, before any of it is designed around.
///
/// Four questions the spec depends on, none of them answerable from the docs:
///
///   * Is a **seed honoured**? The whole "save the prompt and reprint it at
///     4K years later" idea collapses if the same prompt and seed give a
///     different picture — the book would not match the story the child grew
///     up with. ElevenLabs accepted a seed and ignored it; that is the shape
///     of failure to check for.
///   * Can it render **text in the image**? A movie-poster cover needs the
///     story's title in it, and image models have historically produced
///     plausible-looking gibberish.
///   * What does **2K cost against 1K**, really, per image?
///   * Can it be pushed toward something that survives the **Lunii's** 16
///     colours at 320×240, where fine detail turns to mush?
///
///     dart run tool/image_probe.dart
///
/// Writes PNGs to the Desktop. Costs roughly 0,40 EUR.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sleepytime/adapters/secrets/dpapi.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

/// Nano Banana 2.
const _model = 'gemini-3.1-flash-image';

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

/// FNV-1a over the bytes, so two renders can be compared without looking.
int _fingerprint(List<int> bytes) {
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h = ((h ^ b) * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

Future<(List<int>, String)?> _draw(
  http.Client client,
  String key,
  String prompt, {
  String size = '1K',
  String aspect = '4:3',
  int? seed,
}) async {
  final response = await client.post(
    Uri.parse('$_base/$_model:generateContent'),
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
        'responseModalities': ['IMAGE'],
        'imageConfig': {'aspectRatio': aspect, 'imageSize': size},
        'seed': ?seed,
      },
    }),
  );
  if (response.statusCode != 200) {
    final flat = response.body.replaceAll(RegExp(r'\s+'), ' ');
    return (<int>[], flat.length > 240 ? flat.substring(0, 240) : flat);
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final parts =
      (((decoded['candidates'] as List).first as Map)['content']
              as Map)['parts']
          as List;
  for (final p in parts) {
    final data = ((p as Map)['inlineData'] as Map?)?['data'] as String?;
    if (data == null) continue;
    return (base64.decode(data), '');
  }
  return (<int>[], 'no image in response');
}

Future<void> _case(
  http.Client client,
  String key,
  Directory out,
  String name,
  String prompt, {
  String size = '1K',
  String aspect = '4:3',
  int? seed,
}) async {
  stdout.write('${name.padRight(34)} ');
  final started = DateTime.now();
  final result = await _draw(
    client,
    key,
    prompt,
    size: size,
    aspect: aspect,
    seed: seed,
  );
  final ms = DateTime.now().difference(started).inMilliseconds;
  if (result == null || result.$1.isEmpty) {
    stdout.writeln('FAILED');
    if (result != null) stdout.writeln('   ${result.$2}');
    return;
  }
  final bytes = result.$1;
  await File('${out.path}\\$name.png').writeAsBytes(bytes);
  stdout.writeln(
    '${ms}ms  ${(bytes.length / 1024).toStringAsFixed(0)} KB  '
    'fingerprint ${_fingerprint(bytes).toRadixString(16)}',
  );
}

const _scene =
    'A gentle bedtime storybook illustration for a young child. A small '
    'white fox named Crystal kneels in thick green moss in a hush-lit forest '
    'at dusk, both paws cupped around a small brass lantern that glows warm '
    'gold. Beside her stands Pip, a little red fox with a bushy tail. Soft '
    'painterly style, warm colours, calm and safe, no text.';

Future<void> main() async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();
  final out = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\sleepytime-image-test',
  );
  if (!out.existsSync()) out.createSync(recursive: true);
  stdout.writeln('model: $_model');
  stdout.writeln('out:   ${out.path}\n');

  stdout.writeln('── a chapter picture, two sizes ──');
  await _case(client, key, out, '1K-chapter', _scene);
  await _case(client, key, out, '2K-chapter', _scene, size: '2K');

  stdout.writeln('\n── is a seed honoured? (same prompt, same seed, twice) ──');
  await _case(client, key, out, 'seed-4242-first', _scene, seed: 4242);
  await _case(client, key, out, 'seed-4242-second', _scene, seed: 4242);
  await _case(client, key, out, 'seed-9999-control', _scene, seed: 9999);

  stdout.writeln('\n── a cover, like a film poster, with the title in it ──');
  await _case(
    client,
    key,
    out,
    'cover-poster',
    'A children\'s storybook cover in the style of a warm film poster, '
        'portrait orientation. Two characters stand together in the centre: '
        'Crystal, a small white fox holding a glowing brass lantern, and '
        'Pip, a little red fox with a bushy tail. Behind them a hush-lit '
        'forest at dusk with fireflies. At the top, in clean rounded '
        'hand-lettered capitals, the title reads exactly: '
        'THE LANTERN THAT WOULD NOT SLEEP. Soft painterly children\'s book '
        'style, warm gold and deep blue, calm and inviting.',
    aspect: '3:4',
    size: '2K',
  );

  // The same poster, composed to be titled in vector afterwards. Crisp at any
  // print size, always spelled right, and the title can change language
  // without paying to redraw the picture.
  await _case(
    client,
    key,
    out,
    'cover-plain-for-overlay',
    'A children\'s storybook cover illustration in the style of a warm film '
        'poster, portrait orientation. Two characters stand together in the '
        'lower two thirds: Crystal, a small white fox holding a glowing '
        'brass lantern, and Pip, a little red fox with a bushy tail. Behind '
        'them a hush-lit forest at dusk with fireflies. The top third is '
        'calm, uncluttered sky with room for a title to be placed over it — '
        'leave it simple and free of detail. Absolutely no text, letters or '
        'writing anywhere in the image. Soft painterly children\'s book '
        'style, warm gold and deep blue.',
    aspect: '3:4',
    size: '2K',
  );

  stdout.writeln('\n── adapted for the Lunii: 16 colours at 320x240 ──');
  await _case(
    client,
    key,
    out,
    'lunii-adapted',
    'A bold, simple picture-book illustration designed to survive being '
        'reduced to 16 flat colours at very low resolution. Large simple '
        'shapes, thick clean outlines, high contrast, a limited palette of '
        'about six colours, no gradients, no fine detail, no texture, no '
        'small elements. A small white fox holding a glowing lantern beside '
        'a red fox, silhouetted against a deep blue dusk forest. Flat '
        'poster style, like a silkscreen print. No text.',
    aspect: '4:3',
  );

  client.close();
}
