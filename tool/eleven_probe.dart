/// Read-mostly: find out what the ElevenLabs endpoint actually accepts, so a
/// recommendation about it is grounded in a reply rather than in memory.
///
/// Three things we currently do not send, each one a candidate for a livelier
/// reading: the chapter's standing direction as a prompt, the neighbouring
/// chunks as `previous_text`/`next_text` (so a chunk's intonation continues
/// the one before instead of restarting), and per-request `seed`. An endpoint
/// that rejects a field says so; one that ignores it still returns 200, so
/// this reports status codes and lets the caller judge.
///
///     dart run tool/eleven_probe.dart
///
/// Costs a few seconds of synthesis per case. Writes nothing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';

const _voice = '21m00Tcm4TlvDq8ikWAM';
const _model = 'eleven_v3';
const _line = 'and the whole meadow turned gold.';

Future<String?> _key() async {
  final file = File(
    '${Platform.environment['APPDATA']}'
    r'\com.pixteur\moonloom\shared_preferences.json',
  );
  if (!file.existsSync()) return null;
  final prefs = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final stored = prefs['flutter.enckey_elevenlabs'] as String?;
  if (stored == null) return null;
  try {
    return dpapiUnprotect(base64.decode(stored));
  } catch (_) {
    return null;
  }
}

Future<void> main() async {
  final key = await _key();
  if (key == null) {
    stdout.writeln('No ElevenLabs key saved — nothing to ask.');
    return;
  }
  final client = http.Client();

  final cases = <String, Map<String, dynamic>>{
    'what we send today': {'text': _line, 'model_id': _model},
    'with previous_text/next_text (chunk continuity)': {
      'text': _line,
      'model_id': _model,
      'previous_text': 'Crystal lifted the lantern high above the ferns,',
      'next_text': 'Pip blinked, and the crickets began again.',
    },
    'with a deterministic seed': {
      'text': _line,
      'model_id': _model,
      'seed': 4242,
    },
    'with an invented field (control — proves rejection is visible)': {
      'text': _line,
      'model_id': _model,
      'definitely_not_a_real_field': 'x',
    },
  };

  for (final entry in cases.entries) {
    stdout.write('${entry.key.padRight(56)} ');
    try {
      final response = await client.post(
        Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/$_voice'
          '?output_format=mp3_44100_128',
        ),
        headers: {
          'xi-api-key': key,
          'accept': 'audio/mpeg',
          'content-type': 'application/json',
        },
        body: jsonEncode(entry.value),
      );
      final size = (response.bodyBytes.length / 1024).toStringAsFixed(0);
      stdout.writeln(
        '${response.statusCode}  '
        '${response.statusCode == 200 ? '$size KB audio' : _why(response.body)}',
      );
    } catch (e) {
      stdout.writeln('threw: $e');
    }
  }
  // A 200 is not evidence a field did anything — the control above proves the
  // endpoint accepts nonsense without complaint. The only way to know whether
  // `seed` is honoured is to ask twice and compare the bytes.
  stdout.write('\nis seed honoured (same seed twice, byte-identical?)  ');
  final first = await _say(client, key, {
    'text': _line,
    'model_id': _model,
    'seed': 4242,
  });
  final second = await _say(client, key, {
    'text': _line,
    'model_id': _model,
    'seed': 4242,
  });
  final free = await _say(client, key, {'text': _line, 'model_id': _model});
  stdout.writeln(
    first == second
        ? 'yes — identical (${first == free ? 'but so is an unseeded call, so '
                    'this voice may just be deterministic' : 'and an unseeded call '
                    'differs, so the seed is doing the work'})'
        : 'no — same seed gave different audio',
  );
  client.close();
}

/// One synthesis, reduced to a hash of the audio so runs can be compared.
Future<int> _say(
  http.Client client,
  String key,
  Map<String, dynamic> body,
) async {
  final response = await client.post(
    Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$_voice'
      '?output_format=mp3_44100_128',
    ),
    headers: {
      'xi-api-key': key,
      'accept': 'audio/mpeg',
      'content-type': 'application/json',
    },
    body: jsonEncode(body),
  );
  var hash = 0x811c9dc5;
  for (final b in response.bodyBytes) {
    hash = ((hash ^ b) * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

String _why(String body) {
  final flat = body.replaceAll(RegExp(r'\s+'), ' ');
  return flat.length > 160 ? '${flat.substring(0, 160)}…' : flat;
}
