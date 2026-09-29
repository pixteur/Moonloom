/// Put a story from the library onto an attached storyteller.
///
/// **Dry run unless `--write` is given.** Without it this reports exactly what
/// would change and touches nothing, which is how any first attempt against a
/// device should start.
///
///     dart run tool/lunii_write.dart --drive F: --series <id> --cover velo
///     dart run tool/lunii_write.dart --drive F: --series <id> --write
///     dart run tool/lunii_write.dart --drive F: --remove CE4D1B54 --write
///
/// Chapters come from the library database and their narration from the app's
/// audio cache, joined per chapter and re-encoded to the 44.1 kHz mono MP3 the
/// device plays. Cache keys come from `chapterAudioKeys` — never built here by
/// hand, because playback keys per chunk with the narration cue mixed in.
///
/// Take a manifest snapshot either side of a real write; that is what proves
/// nothing else moved:
///
///     dart run tool/lunii_manifest.dart snapshot F: before.json
///     …write…
///     dart run tool/lunii_manifest.dart snapshot F: after.json
///     dart run tool/lunii_manifest.dart diff before.json after.json
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/audio/mp3_encoder.dart';
import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/export/cover_image.dart';
import 'package:moonloom/adapters/export/world_cover.dart';
import 'package:moonloom/adapters/image/bmp_rle4.dart';
import 'package:moonloom/adapters/lunii/device_pack.dart';
import 'package:moonloom/adapters/lunii/device_writer.dart';
import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:moonloom/domain/spoken_labels.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final drive = _option(args, '--drive') ?? 'F:';
  final live = args.contains('--write');
  final home = Platform.environment['USERPROFILE'];
  final backupDir = '$home\\Documents\\Moonloom\\device-backup';

  final device = LuniiDevice.open(drive);
  stdout.writeln(
    'Device $drive  firmware "${device.firmware}"  '
    '${device.packIds.length} packs installed',
  );

  final remove = _option(args, '--remove');
  if (remove != null) {
    final target = device.packIds.cast<Uint8List?>().firstWhere(
      (id) => _directoryName(id!) == remove.toUpperCase(),
      orElse: () => null,
    );
    if (target == null) {
      stderr.writeln('$remove is not installed on $drive');
      exitCode = 1;
      return;
    }
    if (!live) {
      stdout.writeln('\nDRY RUN — would unlist $remove and delete its files.');
      return;
    }
    final gone = removePack(device, target, backupDirectory: backupDir);
    stdout.writeln(
      'Removed $remove ($gone files). '
      '${device.packIds.length} packs → ${LuniiDevice.open(drive).packIds.length}',
    );
    return;
  }

  final seriesId = _option(args, '--series');
  if (seriesId == null) {
    stderr.writeln('--series <id> is required (or --remove <PACK>)');
    exitCode = 2;
    return;
  }
  if (!canEncodeMp3) {
    stderr.writeln('No MP3 encoder on this platform — see docs/lunii-sync.md');
    exitCode = 1;
    return;
  }

  final voice =
      _option(args, '--voice') ?? 'gemini/gemini-2.5-flash-preview-tts/Aoede';
  final language = _option(args, '--language') ?? 'en';
  final audioDir = '$home\\Documents\\Moonloom\\audio';

  final db = sqlite3.open(
    '$home\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );
  final series = db.select('select * from series where id = ?', [seriesId]);
  if (series.isEmpty) {
    stderr.writeln('No series $seriesId');
    exitCode = 1;
    return;
  }
  final title = series.first['title'] as String? ?? 'A story';
  final beats = db.select(
    'select seq, story_text, narration_json, chapter_title from beats '
    'where series_id = ? order by seq',
    [seriesId],
  );
  stdout.writeln('\n"$title" — ${beats.length} chapters');

  final chapters = <DevicePackChapter>[];
  for (final beat in beats) {
    // The one place a chapter maps to its cache entries. Never by hand: the
    // keys are per chunk with the narration cue mixed in.
    final keys = chapterAudioKeys(
      voiceSignature: voice,
      language: language,
      text: beat['story_text'] as String,
      notes: _notes(beat['narration_json'] as String?),
    );
    final parts = <WavAudio>[];
    var missing = 0;
    for (final key in keys) {
      final file = File('$audioDir\\$key');
      if (!file.existsSync()) {
        missing++;
        continue;
      }
      // Trim per chunk, not just per chapter: a provider glitch can leave a
      // hole in the middle of a story as easily as at its end.
      parts.add(
        trimTrailingSilence(decodeWav(decompressAudio(file.readAsBytesSync()))),
      );
    }
    final label = beat['chapter_title'] as String? ?? 'Chapter ${beat['seq']}';
    if (missing > 0 || parts.isEmpty) {
      // A half-cached chapter would play as a story that stops mid-sentence.
      stdout.writeln(
        '  SKIP  $label — $missing of ${keys.length} chunks not downloaded',
      );
      continue;
    }
    final joined = joinWav(parts);
    final mp3 = encodePcmToLuniiMp3(joined);
    // The spoken chapter name, if the app has cached one. All chapters need
    // one or the builder drops the menu, which is the intended behaviour.
    final spoken = _cachedClip(
      spokenChapterFor(
        Beat(
          id: '',
          seriesId: '',
          childId: '',
          seq: beat['seq'] as int,
          intent: StoryIntent.dice,
          text: '',
          summary: '',
          title: (beat['chapter_title'] as String?) ?? '',
          rating: AgeRating.tiny,
        ),
        language,
      ),
      voice,
      language,
      audioDir,
    );
    chapters.add(DevicePackChapter(audio: mp3, announce: spoken));
    stdout.writeln(
      '  ${chapters.length.toString().padLeft(2)}. $label — '
      '${keys.length} chunks, ${joined.duration.inSeconds}s, '
      '${(mp3.length / 1024).round()} kB',
    );
  }
  // A world has a picture of its own, derived from its name, so every episode
  // of it looks like the same place. --cover only applies to a standalone
  // story, which has no world to take a look from.
  final worldName = series.first['world_id'] == null
      ? null
      : db.select('select name from worlds where id = ?', [
              series.first['world_id'],
            ]).firstOrNull?['name']
            as String?;
  db.close();

  if (chapters.isEmpty) {
    stderr.writeln('No narration cached for this story.');
    exitCode = 1;
    return;
  }

  final motif = _option(args, '--cover') ?? 'nightsky';
  final IndexedImage cover;
  if (worldName != null && worldName.trim().isNotEmpty) {
    cover = worldCoverIndexed(seed: worldName);
    stdout.writeln(
      'Cover art: "$worldName" — ${worldCoverDescription(worldName)}',
    );
  } else {
    cover = motif == 'velo'
        ? veloCoverIndexed(seed: title)
        : nightSkyCoverIndexed(seed: title);
    stdout.writeln('Cover art: $motif (standalone story)');
  }

  // The spoken title, if the app has already cached it. The tool never calls a
  // voice provider itself — it reads what is on disk — so a title that has not
  // been synthesized just leaves the cover silent.
  final titleMp3 = _cachedClip(title, voice, language, audioDir);
  stdout.writeln(
    titleMp3 == null
        ? '\nCover: silent (no spoken title cached)'
        : '\nCover: says the title '
              '(${(titleMp3.length / 1024).round()} kB)',
  );

  final named = chapters.where((c) => c.announce != null).length;
  stdout.writeln(
    named == chapters.length
        ? 'Menu: the wheel offers all $named chapters by name'
        : 'Menu: none ($named of ${chapters.length} chapters have a spoken '
              'name cached)',
  );

  final pack = buildDevicePack(
    chapters: chapters,
    deviceKey: device.deviceKey,
    cover: cover,
    titleAudio: titleMp3,
  );
  final plan = planWrite(device, pack);
  stdout.writeln('\nPack ${pack.directoryName}  cover: $motif');
  stdout.writeln(plan.describe());

  if (!live) {
    stdout.writeln('\nDRY RUN — nothing written. Add --write to install.');
    return;
  }

  stdout.writeln('\nBacking up .pi and .md to $backupDir');
  final written = writePack(device, pack, backupDirectory: backupDir);
  stdout.writeln(
    'Wrote ${written.length} files. ${device.packIds.length} packs → '
    '${LuniiDevice.open(drive).packIds.length}',
  );
}

/// A short cue-less clip from the audio cache, encoded for the device, or null
/// if it was never synthesized.
Uint8List? _cachedClip(
  String text,
  String voice,
  String language,
  String audioDir,
) {
  final keys = chapterAudioKeys(
    voiceSignature: voice,
    language: language,
    text: text,
  );
  final parts = <WavAudio>[];
  for (final key in keys) {
    final file = File('$audioDir\\$key');
    if (!file.existsSync()) return null;
    parts.add(
      trimTrailingSilence(decodeWav(decompressAudio(file.readAsBytesSync()))),
    );
  }
  if (parts.isEmpty) return null;
  return encodePcmToLuniiMp3(joinWav(parts));
}

/// Narration cues, as `chapterAudioKeys` needs them — the cue is mixed into
/// each chunk's key, so leaving it out would look up the wrong audio.
NarrationNotes _notes(String? raw) {
  final json = (raw ?? '{}').trim();
  return NarrationNotes.fromJson(
    jsonDecode(json.isEmpty ? '{}' : json) as Map<String, dynamic>,
  );
}

String _directoryName(Uint8List uuid) => uuid
    .sublist(uuid.length - 4)
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join();

String? _option(List<String> args, String name) {
  final at = args.indexOf(name);
  return at >= 0 && at + 1 < args.length ? args[at + 1] : null;
}
