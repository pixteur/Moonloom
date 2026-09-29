/// Read-only: does an export find the narration playback actually cached?
///
/// Both sides now go through `chapterAudioKeys`, so this should report the same
/// number twice. It is kept as a standing check because when they drifted apart
/// (playback keyed per chunk with the cue mixed in, exports keyed on the whole
/// chapter text) fully-downloaded stories exported as "no narration saved yet",
/// and only pre-cue chapters still worked. See `docs/lunii-export.md`.
///
///     dart run tool/export_keys_check.dart all
///     dart run tool/export_keys_check.dart <seriesId> [voiceSignature] [lang]
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final target = args.isNotEmpty ? args.first : 'all';
  final voiceSig = args.length > 1
      ? args[1]
      : 'gemini/gemini-2.5-flash-preview-tts/Aoede';
  final lang = args.length > 2 ? args[2] : 'en';
  final home = Platform.environment['USERPROFILE'];
  final audioDir = Directory('$home\\Documents\\Moonloom\\audio');

  final db = sqlite3.open(
    '$home\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );
  stdout.writeln('voice: $voiceSig   lang: $lang');
  stdout.writeln('cache: ${audioDir.path}\n');

  bool cached(String key) => File('${audioDir.path}\\$key').existsSync();

  List<String> keysFor(Row beat) => chapterAudioKeys(
    voiceSignature: voiceSig,
    language: lang,
    text: beat['story_text'] as String,
    notes: _notes(beat['narration_json'] as String?),
  );

  ResultSet beatsOf(Object? seriesId) => db.select(
    'select seq, story_text, narration_json from beats '
    'where series_id = ? order by seq',
    [seriesId],
  );

  if (target == 'all') {
    for (final s in db.select('select id, title from series')) {
      final beats = beatsOf(s['id']);
      var complete = 0;
      for (final b in beats) {
        final keys = keysFor(b);
        if (keys.isNotEmpty && keys.every(cached)) complete++;
      }
      stdout.writeln(
        '${(s['title'] as String).padRight(24)} chapters=${beats.length}  '
        'exportable=$complete',
      );
    }
    db.close();
    return;
  }

  for (final b in beatsOf(target)) {
    final keys = keysFor(b);
    final hits = keys.where(cached).length;
    stdout.writeln(
      'chapter ${(b['seq'] as int) + 1}: '
      '${keys.length} chunk(s), $hits cached'
      '${hits == keys.length ? "  → exportable" : "  → incomplete"}',
    );
    for (var i = 0; i < keys.length; i++) {
      stdout.writeln('  ${keys[i]}  ${cached(keys[i]) ? "HIT" : "miss"}');
    }
  }
  db.close();
}

NarrationNotes _notes(String? raw) {
  final json = (raw ?? '{}').trim();
  return NarrationNotes.fromJson(
    jsonDecode(json.isEmpty ? '{}' : json) as Map<String, dynamic>,
  );
}
