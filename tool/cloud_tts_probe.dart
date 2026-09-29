/// Read-mostly: can the saved Gemini key also reach Google Cloud Text-to-Speech,
/// and what French voices does it offer?
///
/// This matters because Cloud TTS and Gemini TTS are different products at very
/// different prices — WaveNet is billed at $4 per million characters against
/// Gemini Flash TTS's effective $18.81 — and narration is 85% of what a story
/// costs. Whether that saving is a drop-in or needs a whole new Google Cloud
/// setup depends on one thing: whether the key we already hold is accepted.
///
///     dart run tool/cloud_tts_probe.dart            # list French voices
///     dart run tool/cloud_tts_probe.dart --speak    # also synthesize a line
///
/// The voice list is free. --speak costs one short synthesis.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';

const _base = 'https://texttospeech.googleapis.com/v1';

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

Future<void> main(List<String> args) async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();

  final listed = await client.get(
    Uri.parse('$_base/voices?languageCode=fr-FR&key=$key'),
  );
  if (listed.statusCode != 200) {
    stdout.writeln('Cloud TTS refused the key: ${listed.statusCode}');
    stdout.writeln(
      listed.body.replaceAll(RegExp(r'\s+'), ' ').substring(0, 400),
    );
    stdout.writeln(
      '\nThat means Cloud TTS is a separate setup: enable the API on the '
      'project and use a key scoped to it.',
    );
    client.close();
    return;
  }

  final voices =
      (jsonDecode(listed.body) as Map<String, dynamic>)['voices'] as List;
  final byFamily = <String, List<String>>{};
  for (final v in voices.cast<Map<String, dynamic>>()) {
    final name = v['name'] as String;
    final family = name.split('-').length > 2 ? name.split('-')[2] : 'other';
    byFamily.putIfAbsent(family, () => []).add('$name (${v['ssmlGender']})');
  }

  stdout.writeln('The saved key reaches Cloud TTS.\n');
  stdout.writeln('French voices, by family:');
  for (final entry in byFamily.entries) {
    stdout.writeln('  ${entry.key.padRight(12)} ${entry.value.length}');
    for (final v in entry.value.take(3)) {
      stdout.writeln('      $v');
    }
  }

  if (args.contains('--speak')) {
    stdout.writeln('\nSynthesizing one line on the cheapest family…');
    final wavenet = byFamily['Wavenet']?.first.split(' ').first;
    if (wavenet == null) {
      stdout.writeln('  no WaveNet voice offered for fr-FR');
    } else {
      final said = await client.post(
        Uri.parse('$_base/text:synthesize?key=$key'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          // SSML, not plain text: the narration cues can render to prosody
          // and breaks here, which is how direction survives on an engine
          // that takes no natural-language prompt. Marked as SSML so the
          // tags are parsed rather than read out to a child.
          'input': {
            'ssml':
                '<speak><prosody rate="slow">Crystal souleva sa lanterne, '
                '<break time="400ms"/> et toute la prairie devint dorée.'
                '</prosody></speak>',
          },
          'voice': {'languageCode': 'fr-FR', 'name': wavenet},
          'audioConfig': {'audioEncoding': 'MP3'},
        }),
      );
      if (said.statusCode != 200) {
        stdout.writeln('  ${said.statusCode}: ${said.body.substring(0, 200)}');
      } else {
        final audio =
            (jsonDecode(said.body) as Map<String, dynamic>)['audioContent']
                as String;
        final bytes = base64.decode(audio);
        stdout.writeln(
          '  $wavenet ok — ${(bytes.length / 1024).toStringAsFixed(0)} KB MP3, '
          'SSML accepted',
        );
      }
    }
  }
  client.close();
}
