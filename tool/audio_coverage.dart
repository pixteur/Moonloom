/// Read-only: which stories have narration, and which are still silent?
///
/// Rewriting a story throws away chapters a child may already have heard. The
/// safe ones to redo are the ones nobody has listened to — no cached audio
/// means nothing was ever read aloud from them.
///
/// Checked across **every voice this device has used**, not just the current
/// one. Narration is keyed by voice, so asking about one voice would call a
/// story silent when it is merely recorded in a voice you have since changed —
/// the same trap that once made 600 MB of audio look deleted.
///
///     dart run tool/audio_coverage.dart [--child Mia]
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:sqlite3/sqlite3.dart';

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

/// Every voice signature this device has recorded in.
List<String> _voices(String appData) {
  final file = File(
    '$appData'
    r'\com.pixteur\Moonloom\shared_preferences.json',
  );
  final out = <String>{};
  if (!file.existsSync()) return out.toList();
  final prefs = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  for (final v in (prefs['flutter.known_voice_signatures'] as List? ?? [])) {
    out.add(v.toString());
  }
  for (final engine in ['gemini', 'openai', 'elevenlabs']) {
    final voice = prefs['flutter.voicename_$engine'] as String?;
    final model = prefs['flutter.voicemodel_$engine'] as String?;
    if (voice == null) continue;
    if (model != null && model.isNotEmpty) out.add('$engine/$model/$voice');
  }
  return out.toList();
}

void main(List<String> args) {
  final home = Platform.environment['USERPROFILE'] ?? '';
  final appData = Platform.environment['APPDATA'] ?? '';
  final audio = Directory(
    '$home'
    r'\Documents\Moonloom\audio',
  );
  final have = audio.existsSync()
      ? audio
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .toSet()
      : <String>{};
  final voices = _voices(appData);
  final db = sqlite3.open(
    '$home'
    r'\Documents\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );
  final want = _opt(args, '--child');

  stdout.writeln(
    '${have.length} cached audio files, ${voices.length} known voices\n',
  );

  for (final kid in db.select('select id, display_name from child_profiles')) {
    final name = kid['display_name'] as String;
    if (want != null && name.toLowerCase() != want.toLowerCase()) continue;
    stdout.writeln(name);
    final series = db.select(
      'select id, title from series where child_id = ? order by created_at',
      [kid['id']],
    );
    for (final s in series) {
      final beats = db.select(
        'select story_text, narration_json, language from beats '
        'where series_id = ? order by seq',
        [s['id']],
      );
      if (beats.isEmpty) continue;
      var voiced = 0;
      for (final b in beats) {
        final notes = NarrationNotes.fromJson(
          jsonDecode((b['narration_json'] as String?) ?? '{}')
              as Map<String, dynamic>,
        );
        final lang = (b['language'] as String?) ?? 'en';
        final anyVoice = voices.any((sig) {
          final keys = chapterAudioKeys(
            voiceSignature: sig,
            language: lang,
            text: (b['story_text'] as String?) ?? '',
            notes: notes,
          );
          return keys.isNotEmpty && keys.every(have.contains);
        });
        if (anyVoice) voiced++;
      }
      stdout.writeln(
        '  ${(s['title'] as String).padRight(32)}'
        '${beats.length.toString().padLeft(3)} ch'
        '${voiced.toString().padLeft(5)} voiced'
        '${voiced == 0 ? '   <- silent' : ''}',
      );
    }
    stdout.writeln();
  }
  db.close();
}
