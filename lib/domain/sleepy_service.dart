import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../adapters/export/cover_image.dart';
import '../adapters/export/lunii_pack.dart';
import '../adapters/export/sleepy_codec.dart';
import '../adapters/lunii/device_writer.dart';
import '../adapters/lunii/lunii_transfer.dart';
import '../adapters/storage/library_paths.dart';
import '../adapters/storage/storage_repo.dart';
import '../adapters/tts/audio_cache.dart';
import '../adapters/tts/narrated_chunks.dart';
import '../adapters/tts/tts_provider.dart';
import '../adapters/tts/tts_synthesizer.dart';
import 'models/beat.dart';
import 'models/narration.dart';
import 'models/series.dart';
import 'spoken_labels.dart';
import 'models/story_character.dart';
import 'models/world.dart';

/// Exports/imports a story as a `.sleepy` file (text + audio + metadata). Audio
/// is pulled from the on-disk cache on export and written back on import (keyed
/// by the voice it was made with), so an imported story replays offline with no
/// API calls when the same voice is used. See `docs/data-model.md`.
class SleepyService {
  SleepyService(this._repo, this._cache, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final AudioCache _cache;
  final Uuid _uuid;

  /// v2 carries a chapter's narration as the *chunks* playback actually caches,
  /// plus the narration notes needed to recompute their keys on import. v1
  /// files (one blob per chapter, no notes) still import — see [_restoreAudio].
  static const int _formatVersion = 2;

  /// Cached narration for a piece of text, in playback order, or null if any
  /// part of it is missing — half a chapter would export as a story that stops
  /// mid-sentence, which is worse than telling the grown-up to download it.
  ///
  /// Goes through `chapterAudioKeys` rather than building a key by hand; that
  /// is the whole point of that function existing.
  Future<List<Uint8List>?> _clipChunks(
    String text,
    String voiceSignature,
    String language, {
    NarrationNotes notes = const NarrationNotes(),
  }) async {
    final keys = chapterAudioKeys(
      voiceSignature: voiceSignature,
      language: language,
      text: text,
      notes: notes,
    );
    if (keys.isEmpty) return null;
    final parts = <Uint8List>[];
    for (final key in keys) {
      final bytes = await _cache.get(key);
      if (bytes == null || bytes.isEmpty) return null;
      parts.add(bytes);
    }
    return parts;
  }

  /// A chapter's narration, in the asked-for voice if it has one and in any
  /// [alsoTry] voice if it does not.
  ///
  /// Narration is keyed by voice, so changing voice makes every downloaded
  /// chapter look undownloaded. Nothing is deleted — the app just stops asking
  /// for it — and an export that refused on those grounds would be telling a
  /// grown-up their audio is gone when it is on the disk in front of them.
  Future<List<Uint8List>?> _chapterChunks(
    Beat beat,
    String voiceSignature,
    String language, {
    List<String> alsoTry = const [],
  }) async {
    for (final voice in [voiceSignature, ...alsoTry]) {
      if (voice.trim().isEmpty) continue;
      final chunks = await _clipChunks(
        beat.text,
        voice,
        language,
        notes: beat.narration,
      );
      if (chunks != null) return chunks;
    }
    return null;
  }

  /// One chapter as a single playable file: its chunks joined, WAV headers
  /// reconciled.
  Uint8List _joinChapter(List<Uint8List> parts, String mimeType) =>
      mimeType.toLowerCase().contains('wav')
      ? _concatWav(parts)
      : _concatBytes(parts);

  // ── Export ──────────────────────────────────────────────────────
  /// Bundle a story as `.sleepy` bytes. With [includeAudio] false it's a small
  /// text-only bundle (for sending by message/email) — the recipient's app
  /// re-synthesizes narration with their own preferred voice on import.
  Future<Uint8List> exportBytes(
    Series series, {
    required String language,
    required String voiceSignature,
    List<String> alsoTryVoices = const [],
    bool includeAudio = true,
  }) async {
    final beats = await _repo.loadBeats(series.id);
    final world = series.worldId == null
        ? null
        : await _repo.loadWorldById(series.worldId!);
    final characters = series.worldId == null
        ? const <StoryCharacter>[]
        : await _repo.loadCharacters(series.worldId!);

    final audio = <String, Uint8List>{};
    final chapters = <Map<String, dynamic>>[];
    for (final b in beats) {
      // Chunks travel separately, not joined: the recipient's playback looks
      // for one cache entry per chunk, so a joined chapter would import as
      // audio nobody ever asks for.
      final parts = includeAudio
          ? await _chapterChunks(
              b,
              voiceSignature,
              language,
              alsoTry: alsoTryVoices,
            )
          : null;
      final names = <String>[];
      for (var i = 0; i < (parts?.length ?? 0); i++) {
        final name = 'audio/ch${b.seq}-${i.toString().padLeft(2, '0')}.bin';
        audio[name] = parts![i];
        names.add(name);
      }
      chapters.add({
        'seq': b.seq,
        'text': b.text,
        'summary': b.summary,
        'rating': b.rating.name,
        'setting': b.setting,
        'intent': b.intent.name,
        'isFinal': b.isFinal,
        // The cue is part of a chunk's cache key, so the notes have to travel
        // with the audio or the recipient can't work out where to put it.
        'narration': b.narration.toJson(),
        'audio': names,
      });
    }

    final manifest = <String, dynamic>{
      'format': 'sleepy',
      'version': _formatVersion,
      'language': language,
      'voiceSignature': voiceSignature,
      'world': world == null
          ? null
          : {
              'name': world.name,
              'premise': world.premise,
              'theme': world.theme.name,
            },
      'characters': [
        for (final c in characters)
          {'name': c.name, 'description': c.description},
      ],
      'story': {
        'title': series.title,
        'theme': series.theme.name,
        'heroMode': series.heroMode.name,
        'heroName': series.heroName,
        'seedSummary': series.seedSummary,
        'storyBible': series.storyBible,
      },
      'chapters': chapters,
    };
    return encodeSleepy(SleepyArchive(manifest: manifest, audio: audio));
  }

  /// Write a `.sleepy` into the app's shareable exports folder; returns its path.
  Future<String> exportToFile(
    Series series, {
    required String language,
    required String voiceSignature,
    List<String> alsoTryVoices = const [],
    bool includeAudio = true,
  }) async {
    final bytes = await exportBytes(
      series,
      language: language,
      voiceSignature: voiceSignature,
      alsoTryVoices: alsoTryVoices,
      includeAudio: includeAudio,
    );
    final dir = await exportsDir();
    final suffix = includeAudio ? '' : '-text';
    final file = File(
      p.join(dir.path, '${_safeName(series.title)}$suffix.sleepy'),
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Export the whole story as a single-file **audiobook** (all chapters joined)
  /// with a metadata sidecar (title, author, source). Saved in the library so it
  /// can be copied to Dropbox / iCloud / Drive. Requires the audio to be cached
  /// (play or pre-warm the story first). Returns the audiobook file path.
  Future<String> exportAudiobook(
    Series series, {
    required String language,
    required String voiceSignature,
    required String mimeType,
    required String author,
    List<String> alsoTryVoices = const [],
  }) async {
    final beats = await _repo.loadBeats(series.id);
    final parts = <Uint8List>[];
    var chaptersFound = 0;
    for (final b in beats) {
      final chunks = await _chapterChunks(
        b,
        voiceSignature,
        language,
        alsoTry: alsoTryVoices,
      );
      if (chunks == null) continue;
      parts.addAll(chunks); // every chunk of every chapter, in order
      chaptersFound++;
    }
    if (parts.isEmpty) {
      throw StateError(
        'No narration saved yet — play or pre-warm the story first.',
      );
    }
    final isWav = mimeType.toLowerCase().contains('wav');
    final joined = _joinChapter(parts, mimeType);
    final ext = isWav ? 'wav' : 'mp3';
    final dir = await LibraryPaths.audiobooks();
    final base = _safeName(series.title);
    final file = File(p.join(dir.path, '$base.$ext'));
    await file.writeAsBytes(joined);

    final meta = {
      'title': series.title,
      'author': author,
      'source': 'Generated with MoonloomApp',
      'language': language,
      'voice': voiceSignature,
      'chapters': chaptersFound,
      'format': ext,
    };
    await File(
      p.join(dir.path, '$base.audiobook.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(meta));
    return file.path;
  }

  /// Join WAV chapters into one: strip each 44-byte header, concatenate PCM, and
  /// re-wrap with a single header (sample rate read from the first chapter).
  Uint8List _concatWav(List<Uint8List> wavs) {
    final pcm = BytesBuilder();
    var rate = 24000;
    for (var i = 0; i < wavs.length; i++) {
      final w = wavs[i];
      if (i == 0 && w.length >= 28) {
        rate = w[24] | (w[25] << 8) | (w[26] << 16) | (w[27] << 24);
      }
      if (w.length > 44) pcm.add(w.sublist(44));
    }
    return pcmToWav(pcm.toBytes(), sampleRate: rate == 0 ? 24000 : rate);
  }

  Uint8List _concatBytes(List<Uint8List> parts) {
    final b = BytesBuilder();
    for (final part in parts) {
      b.add(part);
    }
    return b.toBytes();
  }

  /// Export the story as a **Lunii story pack** — a STUdio archive zip the
  /// grown-up opens in STUdio and transfers onto the storyteller, so the child
  /// can listen away from the app. Needs the narration cached (play or download
  /// the story first). Returns the pack's path.
  Future<String> exportLuniiPack(
    Series series, {
    required String language,
    required String voiceSignature,
    required String mimeType,
    List<String> alsoTryVoices = const [],
  }) async {
    final beats = await _repo.loadBeats(series.id);
    final chapters = <LuniiChapter>[];
    for (final b in beats) {
      // One node per chapter on the device, so a chapter's chunks are joined
      // into a single asset here.
      final chunks = await _chapterChunks(
        b,
        voiceSignature,
        language,
        alsoTry: alsoTryVoices,
      );
      if (chunks == null) continue;
      chapters.add(
        LuniiChapter(
          name: 'Chapter ${b.seq + 1}',
          audio: _joinChapter(chunks, mimeType),
          mimeType: mimeType,
        ),
      );
    }
    if (chapters.isEmpty) {
      throw StateError(
        'No narration saved yet — play or download the story first.',
      );
    }
    final bytes = encodeLuniiPack(
      title: series.title,
      description: series.storyBible.trim(),
      chapters: chapters,
      cover: nightSkyCover(seed: series.title),
    );
    final dir = await LibraryPaths.luniiPacks();
    final file = File(p.join(dir.path, '${_safeName(series.title)}.zip'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Storytellers plugged in right now, by drive root. Empty when there is
  /// none, which is how the menu decides whether to offer sending.
  List<String> attachedLuniiDevices() => findLuniiDevices();

  /// Write the story straight onto an attached storyteller — the same pack the
  /// STUdio zip describes, but installed directly, so no grown-up has to run a
  /// second program.
  ///
  /// A chapter whose narration is not fully downloaded is left out rather than
  /// sent half-finished, and the count comes back so the caller can say so.
  /// The heavy part runs off the UI isolate; see `lunii_transfer.dart`.
  Future<LuniiTransfer> sendToLunii(
    Series series, {
    required String language,
    required String voiceSignature,
    LuniiCoverMotif motif = LuniiCoverMotif.nightSky,
    String? drive,
    String? backupDirectory,
    TtsProvider? voice,
    Uint8List? coverImage,
    List<String> alsoTryVoices = const [],
  }) async {
    final devices = attachedLuniiDevices();
    final target = drive ?? (devices.isEmpty ? null : devices.first);
    if (target == null) {
      throw StateError(
        'No storyteller found. Plug the Lunii in with its USB cable and try '
        'again.',
      );
    }

    final beats = await _repo.loadBeats(series.id);
    final chapterChunks = <List<Uint8List>>[];
    final included = <Beat>[];
    var skipped = 0;
    for (final beat in beats) {
      final chunks = await _chapterChunks(
        beat,
        voiceSignature,
        language,
        alsoTry: alsoTryVoices,
      );
      if (chunks == null) {
        skipped++;
        continue;
      }
      chapterChunks.add(chunks);
      included.add(beat);
    }
    if (chapterChunks.isEmpty) {
      throw StateError(
        'No narration saved yet — play or download the story first.',
      );
    }

    // The device navigates by ear, so the cover says the story's name. Best
    // effort: a voice that refuses (no key, quota spent) leaves the cover
    // silent, which is how every pack we have written so far behaves — not a
    // reason to refuse the transfer.
    List<Uint8List>? titleChunks;
    List<List<Uint8List>?>? announceChunks;
    if (voice != null) {
      final title = spokenTitleFor(series);
      if (title.isNotEmpty) {
        try {
          await voice.preload(title, language: language);
          titleChunks = await _clipChunks(title, voiceSignature, language);
        } catch (_) {
          titleChunks = null;
        }
      }
      // And one clip per chapter, so the wheel can be browsed by ear. All or
      // nothing: the pack builder drops the menu unless every chapter has one.
      try {
        final spoken = <List<Uint8List>?>[];
        for (final beat in included) {
          final line = spokenChapterFor(beat, language);
          await voice.preload(line, language: language);
          spoken.add(await _clipChunks(line, voiceSignature, language));
        }
        announceChunks = spoken;
      } catch (_) {
        announceChunks = null;
      }
    }

    // Injectable so a test can point it at a temp folder; the app always uses
    // the library, which needs platform channels a unit test does not have.
    final backup = backupDirectory ?? (await LibraryPaths.deviceBackups()).path;
    return sendStoryToLunii(
      LuniiTransferRequest(
        drive: target,
        backupDirectory: backup,
        title: series.title,
        chapterChunks: chapterChunks,
        titleChunks: titleChunks,
        announceChunks: announceChunks,
        // A portrait drawn for this story when it has one. The world picture
        // below is the fallback, not the first choice: it is seeded on the
        // world's name, so a shelf of episodes from one world was a shelf of
        // identical pictures.
        coverImage: coverImage,
        worldName: series.worldId == null
            ? null
            : (await _repo.loadWorldById(series.worldId!))?.name,
        skipped: skipped,
        motif: motif,
      ),
    );
  }

  Future<Directory> exportsDir() => LibraryPaths.stories();

  /// The `.sleepy` files currently sitting in the exports folder (importable).
  Future<List<File>> listSleepyFiles() async {
    final dir = await exportsDir();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.sleepy'))
        .toList();
  }

  // ── Import ──────────────────────────────────────────────────────
  Future<Series> importFile(String path, String childId) async {
    final bytes = await File(path).readAsBytes();
    return importBytes(bytes, childId);
  }

  Future<Series> importBytes(Uint8List bytes, String childId) async {
    final data = decodeSleepy(bytes);
    final m = data.manifest;
    final lang = m['language'] as String? ?? 'en';
    final voiceSig = m['voiceSignature'] as String? ?? 'device';

    String? worldId;
    final wm = m['world'] as Map<String, dynamic>?;
    if (wm != null) {
      final world = World(
        id: _uuid.v4(),
        childId: childId,
        name: wm['name'] as String? ?? 'Imported world',
        premise: wm['premise'] as String? ?? '',
        theme: _enum(StoryTheme.values, wm['theme'], StoryTheme.cozy),
      );
      await _repo.saveWorld(world);
      worldId = world.id;
      for (final c in (m['characters'] as List? ?? const [])) {
        final cm = c as Map<String, dynamic>;
        await _repo.saveCharacter(
          StoryCharacter(
            id: _uuid.v4(),
            worldId: worldId,
            name: cm['name'] as String? ?? '',
            description: cm['description'] as String? ?? '',
          ),
        );
      }
    }

    final sm = m['story'] as Map<String, dynamic>;
    final series = Series(
      id: _uuid.v4(),
      childId: childId,
      worldId: worldId,
      title: sm['title'] as String? ?? 'Imported story',
      theme: _enum(StoryTheme.values, sm['theme'], StoryTheme.cozy),
      heroMode: _enum(HeroMode.values, sm['heroMode'], HeroMode.surprise),
      heroName: sm['heroName'] as String?,
      seedSummary: sm['seedSummary'] as String? ?? '',
      storyBible: sm['storyBible'] as String? ?? '',
    );
    await _repo.saveSeries(series);

    for (final c in (m['chapters'] as List? ?? const [])) {
      final cm = c as Map<String, dynamic>;
      final text = cm['text'] as String? ?? '';
      final narration = _notesFrom(cm['narration']);
      await _repo.saveBeat(
        Beat(
          id: _uuid.v4(),
          seriesId: series.id,
          childId: childId,
          seq: cm['seq'] as int? ?? 0,
          intent: _enum(StoryIntent.values, cm['intent'], StoryIntent.dice),
          text: text,
          summary: cm['summary'] as String? ?? '',
          rating: _enum(AgeRating.values, cm['rating'], AgeRating.tiny),
          setting: cm['setting'] as String? ?? '',
          language: lang,
          isFinal: cm['isFinal'] as bool? ?? false,
          narration: narration,
        ),
      );
      await _restoreAudio(cm, data, text, narration, voiceSig, lang);
    }
    return series;
  }

  /// Put an imported chapter's narration back where *this* device's playback
  /// will look for it: one cache entry per chunk, keyed from the text and the
  /// cue. A v1 file carries a single blob for the whole chapter, which is only
  /// placeable when the chapter is one chunk — otherwise it is dropped and the
  /// chapter re-synthesizes on first play.
  Future<void> _restoreAudio(
    Map<String, dynamic> chapter,
    SleepyArchive data,
    String text,
    NarrationNotes narration,
    String voiceSig,
    String lang,
  ) async {
    final raw = chapter['audio'];
    final names = switch (raw) {
      String name => [name],
      List<dynamic> list => list.map((e) => e.toString()).toList(),
      _ => const <String>[],
    };
    if (names.isEmpty) return;
    final keys = chapterAudioKeys(
      voiceSignature: voiceSig,
      language: lang,
      text: text,
      notes: narration,
    );
    if (keys.length != names.length) return; // can't place it safely
    for (var i = 0; i < keys.length; i++) {
      final bytes = data.audio[names[i]];
      if (bytes != null && bytes.isNotEmpty) await _cache.put(keys[i], bytes);
    }
  }

  NarrationNotes _notesFrom(Object? json) {
    if (json is! Map<String, dynamic>) return const NarrationNotes();
    try {
      return NarrationNotes.fromJson(json);
    } catch (_) {
      return const NarrationNotes(); // a bad blob just means no direction
    }
  }

  T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  String _safeName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return cleaned.isEmpty ? 'story' : cleaned;
  }
}
