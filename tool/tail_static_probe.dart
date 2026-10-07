/// Read-only: what is in the last second of a Gemini voice clip, after the
/// last word?
///
/// Reported: "gemini 3.8 flash lite test voices, even in the API settings,
/// have the static at the end." Heard in Google's own playground, so it is in
/// the model's output rather than anything the app does — and it is not the
/// shape the de-click looks for. The de-click repairs *steps*: one sample
/// jumping thousands of units next to silence. A burst of hiss after the last
/// word is many small samples, none of them a step, so it passes straight
/// through — and the polish deliberately keeps whatever trails the last word.
///
/// So this synthesizes one line on each 3.8 model and maps the tail in 20 ms
/// windows: loudness, and zero-crossing rate, which is the tell for noise —
/// speech crosses zero a few hundred times a second, hiss thousands. Then it
/// does the same after the polish, so "fixed" is a number.
///
///     dart run tool/tail_static_probe.dart
///
/// Writes the clips to the desktop. Costs two short syntheses.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/tts/audio_polish.dart';

const _line =
    'The moon rose softly over the sleeping sea. Goodnight, little one.';

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

Future<Uint8List> _speak(http.Client c, String key, String model) async {
  final r = await c.post(
    Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
    headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
    body: jsonEncode({
      'model': model,
      'input': [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': _line},
          ],
        },
      ],
      'response_format': {'type': 'audio'},
      'generation_config': {
        'speech_config': [
          {'voice': 'Sulafat'},
        ],
      },
    }),
  );
  if (r.statusCode != 200) throw StateError('${r.statusCode} ${r.body}');
  for (final s in ((jsonDecode(r.body) as Map)['steps'] as List).cast<Map>()) {
    for (final p in (s['content'] as List? ?? []).cast<Map>()) {
      if (p['type'] == 'audio') return base64.decode(p['data'] as String);
    }
  }
  throw StateError('no audio');
}

Int16List _samples(Uint8List wav) {
  final v = ByteData.sublistView(wav);
  final n = (wav.length - 44) ~/ 2;
  return Int16List.fromList([
    for (var i = 0; i < n; i++) v.getInt16(44 + i * 2, Endian.little),
  ]);
}

double _dbfs(Int16List s, int a, int b) {
  var sum = 0.0;
  for (var i = a; i < b; i++) {
    final x = s[i] / 32768;
    sum += x * x;
  }
  final rms = sqrt(sum / max(1, b - a));
  return rms < 1e-7 ? -140 : 20 * log(rms) / ln10;
}

/// Zero crossings per second. Speech: a few hundred. Hiss: thousands.
int _zcr(Int16List s, int a, int b, int rate) {
  var n = 0;
  for (var i = a + 1; i < b; i++) {
    if ((s[i - 1] < 0) != (s[i] < 0)) n++;
  }
  return (n * rate / max(1, b - a)).round();
}

void _report(String label, Uint8List wav) {
  final s = _samples(wav);
  const rate = 24000;
  const win = 480; // 20 ms
  // The last window loud enough to be speech.
  var lastSpeech = 0;
  for (var i = 0; i + win <= s.length; i += win) {
    if (_dbfs(s, i, i + win) > -45) lastSpeech = i + win;
  }
  final tail = s.length - lastSpeech;
  stdout.writeln(
    '\n$label  ${(s.length / rate).toStringAsFixed(2)} s, '
    'tail after the last word ${(tail / rate * 1000).round()} ms',
  );
  if (tail < win) {
    stdout.writeln('  (no tail)');
    return;
  }
  final level = _dbfs(s, lastSpeech, s.length);
  final zcr = _zcr(s, lastSpeech, s.length, rate);
  var peak = 0;
  for (var i = lastSpeech; i < s.length; i++) {
    peak = max(peak, s[i].abs());
  }
  stdout.writeln(
    '  tail: ${level.toStringAsFixed(1)} dBFS, peak $peak, '
    '$zcr zero crossings/s'
    '${level > -70 && zcr > 2000 ? '   <- NOISE, not silence' : ''}',
  );
  // The tail, window by window, so a burst shows where it is.
  final map = StringBuffer('  ');
  for (var i = lastSpeech; i + win <= s.length; i += win) {
    final d = _dbfs(s, i, i + win);
    map.write(
      d < -90
          ? '.'
          : d < -70
          ? '-'
          : d < -55
          ? '='
          : '#',
    );
  }
  stdout.writeln('$map   (. silent  - faint  = audible hiss  # loud)');
}

Future<void> main() async {
  final key = await _key();
  final c = http.Client();
  final out = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\moonloom-voices',
  )..createSync(recursive: true);
  for (final model in ['gemini-3.8-flash-lite-tts', 'gemini-3.8-flash-tts']) {
    final raw = await _speak(c, key, model);
    File('${out.path}\\tail - $model raw.wav').writeAsBytesSync(raw);
    _report('$model, as returned', raw);
    final polished = polishNarration(raw);
    File('${out.path}\\tail - $model polished.wav').writeAsBytesSync(polished);
    _report('$model, after the polish', polished);
  }
  c.close();
}
