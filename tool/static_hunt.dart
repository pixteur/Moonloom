/// Read-only: find stretches inside a story's narration that are data, not
/// voice — wherever they are, not only at the end of a clip.
///
/// "The last story you repaired still has static in a few places." The repair
/// found Gemini's C2PA manifest by its text, at the end of each clip. A
/// manifest whose level the polish changed has no text left to find, and one
/// that the polish split with inserted pauses is no longer only at the end.
///
/// The tell does not depend on either. In speech, even a sharp "s", each
/// sample is close to the one before it. Data read as samples is not: one
/// byte pair has nothing to do with the next, so neighbouring samples differ
/// by about as much as the samples are loud. The ratio of the two —
/// mean |s[i] − s[i−1]| over mean |s[i]| — sits well under 1 for a voice and
/// near 1.4 for random bytes. Loud windows above the line are reported, with
/// where they are.
///
///     dart run tool/static_hunt.dart "The Whispering Caves"
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:sqlite3/sqlite3.dart';

const int _window = 240; // 10 ms at 24 kHz

/// How rough a window is: 0 for a smooth wave, ~1.4 for random data.
double _roughness(Int16List s, int from, int to) {
  var diff = 0.0, level = 0.0;
  for (var i = from + 1; i < to; i++) {
    diff += (s[i] - s[i - 1]).abs();
    level += s[i].abs();
  }
  return level == 0 ? 0 : diff / level;
}

double _dbfs(Int16List s, int from, int to) {
  var sum = 0.0;
  for (var i = from; i < to; i++) {
    final x = s[i] / 32768;
    sum += x * x;
  }
  final rms = sqrt(sum / max(1, to - from));
  return rms < 1e-7 ? -140 : 20 * log(rms) / ln10;
}

void main(List<String> args) {
  final title = args.isEmpty ? 'The Whispering Caves' : args.first;
  final home = Platform.environment['USERPROFILE'];
  final audio = '$home\\Documents\\Moonloom\\audio';
  final prefs =
      jsonDecode(
            File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final voices = [
    for (final v in (prefs['flutter.known_voice_signatures'] as List? ?? []))
      v.toString(),
  ];

  final db = sqlite3.open(
    '$home\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );
  final series = db.select(
    'select id, base_language from series where title = ?',
    [title],
  );
  if (series.isEmpty) {
    stdout.writeln('No story called "$title".');
    return;
  }
  final language = (series.first['base_language'] as String?) ?? 'en';
  final beats = db.select(
    'select seq, story_text, narration_json from beats where series_id = ? '
    'order by seq',
    [series.first['id']],
  );

  var clips = 0, flaggedClips = 0;
  for (final b in beats) {
    final raw = (b['narration_json'] as String?)?.trim() ?? '';
    final notes = NarrationNotes.fromJson(
      jsonDecode(raw.isEmpty ? '{}' : raw) as Map<String, dynamic>,
    );
    // Whichever voice actually holds this chapter.
    List<String>? keys;
    for (final v in voices) {
      final k = chapterAudioKeys(
        voiceSignature: v,
        language: language,
        text: b['story_text'] as String,
        notes: notes,
      );
      if (k.isNotEmpty && k.every((x) => File('$audio\\$x').existsSync())) {
        keys = k;
        break;
      }
    }
    if (keys == null) {
      stdout.writeln('chapter ${(b['seq'] as int) + 1}: no recording');
      continue;
    }
    for (var c = 0; c < keys.length; c++) {
      final wav = decompressAudio(File('$audio\\${keys[c]}').readAsBytesSync());
      final v = ByteData.sublistView(wav);
      final s = Int16List((wav.length - 44) ~/ 2);
      for (var i = 0; i < s.length; i++) {
        s[i] = v.getInt16(44 + i * 2, Endian.little);
      }
      clips++;
      final hits = <String>[];
      var worst = 0.0;
      for (var i = 0; i + _window <= s.length; i += _window) {
        final level = _dbfs(s, i, i + _window);
        if (level < -40) continue; // only what can be heard
        final rough = _roughness(s, i, i + _window);
        worst = max(worst, rough);
        if (rough > 1.0) {
          hits.add(
            '${(i / 24000).toStringAsFixed(2)}s '
            '(${level.toStringAsFixed(0)} dB, ${rough.toStringAsFixed(2)})',
          );
        }
      }
      final secs = (s.length / 24000).toStringAsFixed(1);
      if (hits.isNotEmpty) flaggedClips++;
      stdout.writeln(
        'chapter ${(b['seq'] as int) + 1} clip ${c + 1}  ${keys[c]}  $secs s  '
        'roughest ${worst.toStringAsFixed(2)}'
        '${hits.isEmpty ? '' : '  DATA-LIKE at: ${hits.take(6).join(', ')}'}',
      );
    }
  }
  stdout.writeln(
    '\n$flaggedClips of $clips clips have loud stretches that are data, '
    'not voice',
  );
  db.dispose();
}
