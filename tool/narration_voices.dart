/// Read-only: which voice each story's narration is saved in.
///
/// Written after "the story audio from last week is missing". Nothing had been
/// deleted — 600 MB of it was still on disk — but narration is keyed by the
/// voice that spoke it, and the voice had changed, so the app stopped asking
/// for the old recordings. This shows what is actually there and under which
/// voice, which is the difference between "gone" and "not being asked for".
///
///     dart run tool/narration_voices.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:sqlite3/sqlite3.dart';

/// Every voice signature worth trying: the ones the app has recorded, plus
/// what the stored settings imply for each engine.
List<String> _candidates(Map<String, dynamic> prefs) {
  final out = <String>{
    for (final v in (prefs['flutter.known_voice_signatures'] as List? ?? []))
      v.toString(),
  };
  void consider(String engine, String defaultModel, String defaultVoice) {
    final voice =
        (prefs['flutter.voicename_$engine'] as String?) ?? defaultVoice;
    final model = (prefs['flutter.voicemodel_$engine'] as String?) ?? '';
    out.add('$engine/${model.isEmpty ? defaultModel : model}/$voice');
    out.add('$engine/$defaultModel/$voice');
  }

  consider('gemini', 'gemini-2.5-flash-preview-tts', 'Kore');
  consider('openai', 'gpt-4o-mini-tts', 'nova');
  consider('elevenlabs', 'eleven_v3', '21m00Tcm4TlvDq8ikWAM');
  return out.toList();
}

void main() {
  final home = Platform.environment['USERPROFILE'];
  final audioDir = Directory('$home\\Documents\\Moonloom\\audio');
  final prefs =
      jsonDecode(
            File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  final onDisk = audioDir.existsSync()
      ? audioDir.listSync().whereType<File>().length
      : 0;
  final voices = _candidates(prefs);
  stdout
    ..writeln('$onDisk files in ${audioDir.path}')
    ..writeln('voices tried: ${voices.length}\n');

  final db = sqlite3.open(
    '$home\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );
  for (final s in db.select('select id, title, base_language from series')) {
    final language = (s['base_language'] as String?) ?? 'en';
    final beats = db.select(
      'select story_text, narration_json from beats where series_id = ? '
      'order by seq',
      [s['id']],
    );
    if (beats.isEmpty) continue;

    // Per voice, how many of this story's chapters are complete in it.
    final held = <String, int>{};
    for (final b in beats) {
      for (final voice in voices) {
        final keys = chapterAudioKeys(
          voiceSignature: voice,
          language: language,
          text: b['story_text'] as String,
          notes: _notes(b['narration_json'] as String?),
        );
        if (keys.isNotEmpty &&
            keys.every((k) => File('${audioDir.path}\\$k').existsSync())) {
          held[voice] = (held[voice] ?? 0) + 1;
        }
      }
    }
    stdout.writeln('${s['title']}  (${beats.length} chapters)');
    if (held.isEmpty) {
      stdout.writeln('  no narration saved in any voice');
    }
    for (final e in held.entries) {
      stdout.writeln('  ${e.value}/${beats.length}  ${e.key}');
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
