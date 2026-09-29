/// Will the image model draw the *same* character twice?
///
/// The pictures in Mia's stories came back with a different fox in each one,
/// which is the failure text prompts alone cannot fix: "a small white fox"
/// describes a thousand foxes. The proposed cure is a character sheet drawn
/// once and handed back as a reference, and that only works if the API accepts
/// an image as input at all.
///
/// So this asks three things in order, because each one only matters if the
/// last was true:
///
///   1. Does a request with an input image succeed?
///   2. With TWO reference images — two characters in one scene?
///   3. Does the result actually look like the reference, or merely like the
///      words? Answered by eye, which is why the files are written out.
///
///     dart run tool/reference_probe.dart
///
/// Writes PNGs to the Desktop. Costs roughly 0,45 EUR.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';
const _model = 'gemini-3.1-flash-image';

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

Future<List<int>?> _draw(
  http.Client client,
  String key,
  String prompt, {
  List<List<int>> references = const [],
  String aspect = '4:3',
  String size = '2K',
}) async {
  final response = await client.post(
    Uri.parse('$_base/$_model:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            // References first, then the instruction — the instruction reads
            // as being about the pictures above it.
            for (final bytes in references)
              {
                'inline_data': {
                  'mime_type': 'image/png',
                  'data': base64.encode(bytes),
                },
              },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE'],
        'imageConfig': {'aspectRatio': aspect, 'imageSize': size},
      },
    }),
  );
  if (response.statusCode != 200) {
    final flat = response.body.replaceAll(RegExp(r'\s+'), ' ');
    stdout.writeln(
      '   ${response.statusCode}: '
      '${flat.length > 220 ? flat.substring(0, 220) : flat}',
    );
    return null;
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final candidates = decoded['candidates'] as List?;
  if (candidates == null || candidates.isEmpty) {
    stdout.writeln('   refused — no candidate came back');
    return null;
  }
  final parts = ((candidates.first as Map)['content'] as Map)['parts'] as List;
  for (final p in parts) {
    final data = ((p as Map)['inlineData'] as Map?)?['data'] as String?;
    if (data == null) continue;
    return base64.decode(data);
  }
  return null;
}

/// A character sheet: one character, plainly lit, from a few angles, on a flat
/// background. Drawn to be *referred to* rather than looked at — the point is
/// that nothing in it competes with the character.
const _sheetStyle =
    'A character reference sheet for a children\'s picture book. The same '
    'character shown three times against a plain flat cream background: '
    'front view, three-quarter view, and side view, standing, evenly lit, '
    'full body, neutral expression. Consistent colours and proportions across '
    'all three. Soft painterly children\'s book style, clean and uncluttered. '
    'No text, labels, letters or writing anywhere.';

Future<void> main() async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();
  final out = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\moonloom-reference-test',
  );
  if (!out.existsSync()) out.createSync(recursive: true);
  stdout.writeln('model: $_model');
  stdout.writeln('out:   ${out.path}\n');

  stdout.writeln('── 1. two character sheets ──');
  stdout.write('Crystal (white fox)     ');
  final crystal = await _draw(
    client,
    key,
    '$_sheetStyle The character is Crystal: a small white fox with amber '
    'eyes, a cream-tipped tail, and a soft blue scarf.',
    aspect: '4:3',
  );
  if (crystal == null) {
    client.close();
    return;
  }
  await File('${out.path}\\sheet-crystal.png').writeAsBytes(crystal);
  stdout.writeln('${(crystal.length / 1024).toStringAsFixed(0)} KB');

  stdout.write('Bolt (copper robot)     ');
  final bolt = await _draw(
    client,
    key,
    '$_sheetStyle The character is Bolt: a small round copper robot with one '
    'big glowing blue screen for a face and stubby legs.',
    aspect: '4:3',
  );
  if (bolt == null) {
    client.close();
    return;
  }
  await File('${out.path}\\sheet-bolt.png').writeAsBytes(bolt);
  stdout.writeln('${(bolt.length / 1024).toStringAsFixed(0)} KB');

  stdout.writeln('\n── 2. a scene from ONE reference ──');
  stdout.write('Crystal in the forest   ');
  final one = await _draw(
    client,
    key,
    'Using the character in the reference image exactly as drawn — same '
    'colours, same markings, same proportions — illustrate this scene: '
    'Crystal kneels in thick green moss in a hush-lit forest at dusk, '
    'both paws cupped around a small brass lantern glowing warm gold. '
    'Soft painterly children\'s book style, calm bedtime mood. No text.',
    references: [crystal],
  );
  if (one != null) {
    await File('${out.path}\\scene-one-reference.png').writeAsBytes(one);
    stdout.writeln('${(one.length / 1024).toStringAsFixed(0)} KB');
  }

  stdout.writeln('\n── 3. a scene from TWO references ──');
  stdout.write('Crystal and Bolt        ');
  final two = await _draw(
    client,
    key,
    'The first reference image is Crystal; the second is Bolt. Draw both of '
    'them exactly as shown — same colours, same markings, same '
    'proportions — together in this scene: Crystal holds the brass '
    'lantern up while Bolt peers at a wooden tag hanging from its handle, '
    'in a hush-lit forest at dusk. Soft painterly children\'s book style, '
    'calm bedtime mood. No text.',
    references: [crystal, bolt],
  );
  if (two != null) {
    await File('${out.path}\\scene-two-references.png').writeAsBytes(two);
    stdout.writeln('${(two.length / 1024).toStringAsFixed(0)} KB');
  }

  stdout.writeln('\n── 4. the same pair again, a different scene ──');
  stdout.write('later that night        ');
  final again = await _draw(
    client,
    key,
    'The first reference image is Crystal; the second is Bolt. Draw both of '
    'them exactly as shown, together in this scene: Crystal and Bolt sit '
    'on a mossy stump under the stars, the lantern dimmed to a soft ember '
    'between them, both looking sleepy. Soft painterly children\'s book '
    'style, calm bedtime mood. No text.',
    references: [crystal, bolt],
  );
  if (again != null) {
    await File(
      '${out.path}\\scene-two-references-later.png',
    ).writeAsBytes(again);
    stdout.writeln('${(again.length / 1024).toStringAsFixed(0)} KB');
  }

  stdout.writeln(
    '\nCompare sheet-crystal.png against the three scenes: same fox, or three '
    'different foxes?',
  );
  client.close();
}
