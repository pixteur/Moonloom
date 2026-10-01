/// Giving a story its pictures, and making them look like one book.
///
/// The first version drew each picture from words alone, and Mia's stories
/// came back with a different fox in every one. That is not a prompt that
/// needs improving: "a small white fox" describes a thousand foxes, and the
/// model picks a new one each time it is asked. Two things fix it, and both
/// are about deciding something **once** and then repeating it exactly.
///
///   * **A character sheet.** Each character is drawn once — three views,
///     plain background, even light — and that drawing is handed back to the
///     model as a reference every time they appear. The picture is the
///     specification; the description is only the brief for it.
///   * **A world style guide.** One paragraph of art direction, written from
///     the world's own premise by the model that writes the stories, then
///     repeated verbatim in every prompt. It keeps twenty episodes in one
///     hand.
///
/// Order matters: sheets, then the cover, then the chapters. The cover is the
/// first picture of the cast together, and the chapters are drawn against the
/// same references the cover used — so the cover is not a special case, it is
/// simply the first thing drawn after the cast exists.
///
/// Deliberately not part of `StoryEngine`: a picture costs more than the whole
/// story it illustrates — 4,4 centimes against 2,6 for a mini — so it is never
/// something a turn does on its own. See `docs/story-images.md`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../adapters/images/picture_store.dart';
import '../adapters/images/story_illustrator.dart';
import '../adapters/storage/storage_repo.dart';
import 'cast_line.dart';
import 'models/beat.dart';
import 'models/series.dart';
import 'models/story_character.dart';
import 'models/story_image.dart';
import 'models/world.dart';
import 'picture_prompt.dart';

class IllustrationService {
  IllustrationService({
    required StoryIllustrator illustrator,
    required PictureStore pictures,
    required StorageRepo repo,
    Uuid? uuid,
  }) : _illustrator = illustrator, // ignore: prefer_initializing_formals
       _pictures = pictures, // ignore: prefer_initializing_formals
       _repo = repo, // ignore: prefer_initializing_formals
       _uuid = uuid ?? const Uuid();

  final StoryIllustrator _illustrator;
  final PictureStore _pictures;
  final StorageRepo _repo;
  final Uuid _uuid;

  /// At most this many references travel with one picture.
  ///
  /// Gemini accepts two comfortably; beyond that the prompt has to say "the
  /// fourth reference image", which is more bookkeeping than steering. Two
  /// also happens to be how many characters a bedtime scene usually holds.
  static const int maxReferences = 2;

  Future<List<StoryImage>> forSeries(String seriesId) =>
      _repo.loadImages(seriesId);

  // ── The world's look ─────────────────────────────────────────────

  /// The world's style guide, writing one first if it has none.
  ///
  /// [writeGuide] is the story model: it already knows the arc, the setting
  /// and the mood, which is exactly the brief an art director works from, so
  /// it writes the art direction rather than a second model guessing from a
  /// title. Saved on the world, so every future episode inherits it and the
  /// series stays in one hand.
  Future<World> ensureStyleGuide(
    World world, {
    required Future<String> Function(String brief) writeGuide,
  }) async {
    if (world.styleGuide.trim().isNotEmpty) return world;
    final brief = styleGuideBrief(
      worldName: world.name,
      premise: world.premise.trim().isEmpty
          ? 'A gentle world for bedtime stories.'
          : world.premise.trim(),
      themes: world.allThemes.map((t) => t.name).join(', '),
    );
    final guide = (await writeGuide(brief)).trim();
    if (guide.isEmpty) return world;
    final updated = world.copyWith(styleGuide: guide);
    await _repo.saveWorld(updated);
    return updated;
  }

  // ── The cast ─────────────────────────────────────────────────────

  /// Every character in the world has a reference drawing, drawing any that
  /// are missing. Returns them in the order they were given.
  ///
  /// A sheet is drawn once and then belongs to the world, not to a story —
  /// which is the whole point. The tenth episode gets the same fox as the
  /// first without paying for it again.
  Future<List<StoryCharacter>> ensureSheets(
    World world,
    List<StoryCharacter> cast, {
    void Function(String name)? onDrawing,
  }) async {
    final out = <StoryCharacter>[];
    for (final character in cast) {
      if (character.sheetFileKey.isNotEmpty &&
          await _pictures.has(character.sheetFileKey)) {
        out.add(character);
        continue;
      }
      onDrawing?.call(character.name);
      try {
        final prompt = characterSheetPrompt(
          character.name,
          character.description,
          styleGuide: world.styleGuide,
        );
        final drawn = await _illustrator.draw(
          prompt,
          kind: StoryImageKind.characterSheet,
        );
        final key = 'sheet-${_hash('${world.id}|${character.id}|$prompt')}.png';
        await _pictures.write(key, drawn.bytes);
        final updated = character.copyWith(sheetFileKey: key);
        await _repo.saveCharacter(updated);
        out.add(updated);
      } catch (e) {
        // A character with no sheet still appears, just without a reference —
        // a slightly less consistent picture beats no picture at all. Said out
        // loud, though: a silent failure here quietly undoes the whole point
        // of having sheets.
        onDrawing?.call('could not draw ${character.name}: $e');
        out.add(character);
      }
    }
    return out;
  }

  /// The reference bytes for whichever of [cast] this beat actually mentions,
  /// most-mentioned first, capped at [maxReferences].
  ///
  /// Picking by mention rather than taking the first two matters: a scene
  /// between the fox and the owl should carry the fox and the owl, not the
  /// fox and whoever happens to be first in the world's cast list.
  Future<(List<Uint8List>, List<String>)> _referencesFor(
    Beat beat,
    List<StoryCharacter> cast,
  ) async {
    final haystack =
        '${beat.characters.join(' ')} ${beat.summary} '
                '${beat.title}'
            .toLowerCase();
    final mentioned = cast
        .where((c) => c.sheetFileKey.isNotEmpty)
        .where((c) => haystack.contains(c.name.toLowerCase()))
        .take(maxReferences)
        .toList();
    final bytes = <Uint8List>[];
    final names = <String>[];
    for (final c in mentioned) {
      final data = await _pictures.read(c.sheetFileKey);
      if (data == null) continue;
      bytes.add(data);
      names.add(c.name);
    }
    return (bytes, names);
  }

  // ── Drawing ──────────────────────────────────────────────────────

  /// Draw one picture and keep it.
  ///
  /// The file key is content-addressed over the prompt and the kind rather
  /// than the bytes, so asking twice for the same picture of the same chapter
  /// overwrites rather than accumulating.
  Future<StoryImage> drawOne({
    required Series series,
    required Beat beat,
    required StoryImageKind kind,
    List<String> cast = const [],
    List<StoryCharacter> sheets = const [],
    String? styleGuide,
    int? seed,
  }) async {
    final (references, names) = await _referencesFor(beat, sheets);
    final prompt = picturePromptFor(
      kind,
      series,
      beat,
      cast: cast,
      references: names,
      styleGuide: styleGuide,
    );
    final drawn = await _illustrator.draw(
      prompt,
      kind: kind,
      seed: seed,
      references: references,
    );
    final key = '${_hash('${kind.name}|${series.id}|${beat.id}|$prompt')}.png';
    await _pictures.write(key, drawn.bytes);

    // A chapter has one picture and a story has one cover, so drawing again
    // replaces rather than accumulates. Without this, illustrating a story a
    // second time — to recover a cover lost to a busy server, say — left the
    // first attempt's rows behind pointing at the same files, and the reader
    // picked one of them at random.
    for (final old in await _repo.loadImages(series.id)) {
      if (old.kind == kind && old.beatId == _slotFor(kind, beat)) {
        await _repo.deleteImage(old.id);
      }
    }

    final image = StoryImage(
      id: _uuid.v4(),
      seriesId: series.id,
      beatId: _slotFor(kind, beat),
      kind: kind,
      fileKey: key,
      prompt: drawn.prompt,
      seed: drawn.seed,
      model: drawn.model,
      size: drawn.size,
      aspect: drawn.aspect,
    );
    await _repo.saveImage(image);
    return image;
  }

  /// Illustrate a whole story: the cast designed first, then the cover, then
  /// the chapters that earn a picture.
  ///
  /// A refusal on one picture does not abandon the rest — a chapter whose
  /// image trips a safety filter simply has no picture, which is a story that
  /// looks slightly plainer rather than a button that did nothing.
  Future<List<StoryImage>> illustrate({
    required Series series,
    required List<Beat> beats,
    World? world,
    List<StoryCharacter> cast = const [],
    bool cover = true,
    void Function(int done, int total)? onProgress,
    void Function(String what)? onStep,
  }) async {
    if (beats.isEmpty) return const [];

    final sheets = world == null
        ? const <StoryCharacter>[]
        : await ensureSheets(
            world,
            cast,
            onDrawing: (name) => onStep?.call('designing $name'),
          );
    final lines = [for (final c in sheets) c.promptLine];

    final wanted = chaptersToIllustrate(beats.length);
    final total = wanted.length + (cover ? 1 : 0);
    final made = <StoryImage>[];

    Future<void> attempt(Beat beat, StoryImageKind kind) async {
      try {
        made.add(
          await drawOne(
            series: series,
            beat: beat,
            kind: kind,
            cast: lines,
            sheets: sheets,
            styleGuide: world?.styleGuide,
          ),
        );
      } catch (e) {
        // One picture failing must not abandon the rest — a chapter whose
        // image trips a safety filter is a story that looks plainer, not a
        // button that did nothing. But it is reported: the first version
        // swallowed this silently, and a cover that never appeared looked
        // exactly like a cover nobody had asked for.
        onStep?.call('could not draw the ${kind.name}: $e');
      }
      onProgress?.call(made.length, total);
    }

    if (cover) {
      onStep?.call('drawing the cover');
      await attempt(beats.first, StoryImageKind.cover);
    }
    for (final index in wanted) {
      onStep?.call('drawing chapter ${index + 1}');
      await attempt(beats[index], StoryImageKind.chapter);
    }
    return made;
  }

  // ── The storyteller's picture ────────────────────────────────────

  /// The portrait the storyteller device shows for this story, drawing one if
  /// it has none, and its bytes ready to be reduced.
  ///
  /// A separate picture from the cover, and worth the extra one: the device has
  /// a 320×240 screen with sixteen colours, which turns a painted cover into
  /// mud, and it is the picture a child points at to choose a story. So it is
  /// drawn flat and bold from the start, and of **one character's face** rather
  /// than a scene — see [luniiPicturePrompt].
  ///
  /// Who it is of varies by story and holds still within one: [portraitSubject]
  /// picks from the characters that story actually mentions. That is the part
  /// the procedural cover could not do at all, since it is seeded on the
  /// world's name and gave every episode the same picture.
  ///
  /// Drawn once and kept. Re-sending a pack must not cost another picture, and
  /// must not change the one on the shelf.
  Future<(StoryImage, Uint8List)?> ensureLuniiPortrait({
    required Series series,
    required List<Beat> beats,
    World? world,
    List<StoryCharacter> cast = const [],
  }) async {
    if (beats.isEmpty) return null;

    for (final existing in await _repo.loadImages(series.id)) {
      if (existing.kind != StoryImageKind.lunii) continue;
      final bytes = await _pictures.read(existing.fileKey);
      // A row whose file has gone — a cleared cache, a half-restored
      // backup — is not a picture. Falling through redraws it.
      if (bytes != null && bytes.isNotEmpty) return (existing, bytes);
    }

    final sheets = world == null
        ? const <StoryCharacter>[]
        : await ensureSheets(world, cast);
    final subject = portraitSubject(
      seriesId: series.id,
      cast: [for (final c in sheets) c.promptLine],
      beats: beats,
    );
    final name = subject == null ? '' : parseCastEntry(subject).$1;

    // The sheet of whoever was picked, as the reference. Without it the model
    // invents a face, and the device would show a character who appears
    // nowhere else in the story — the exact drift the sheets exist to stop.
    final chosen = sheets.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => const StoryCharacter(id: '', worldId: '', name: ''),
    );
    final reference = chosen.sheetFileKey.isEmpty
        ? null
        : await _pictures.read(chosen.sheetFileKey);

    final prompt = luniiPicturePrompt(
      series,
      beats.first,
      references: reference == null ? const [] : [chosen.name],
      subject: subject,
    );
    final drawn = await _illustrator.draw(
      prompt,
      kind: StoryImageKind.lunii,
      references: reference == null ? const [] : [reference],
    );
    final key = 'lunii-${_hash('${series.id}|$prompt')}.png';
    await _pictures.write(key, drawn.bytes);

    // A story has one device picture, so a redraw replaces rather than
    // accumulating — the same rule [drawOne] follows, and for the same reason.
    // Reaching here at all means the rows already present are stale (their
    // file was gone), and leaving them behind is how the library ended up with
    // two rows per story the first time this ran.
    for (final old in await _repo.loadImages(series.id)) {
      if (old.kind == StoryImageKind.lunii) await _repo.deleteImage(old.id);
    }

    final image = StoryImage(
      id: _uuid.v4(),
      seriesId: series.id,
      beatId: null,
      kind: StoryImageKind.lunii,
      fileKey: key,
      prompt: drawn.prompt,
      seed: drawn.seed,
      model: drawn.model,
      size: drawn.size,
      aspect: drawn.aspect,
    );
    await _repo.saveImage(image);
    return (image, drawn.bytes);
  }

  /// Which slot a picture of this kind occupies: a cover belongs to the story,
  /// everything else to its chapter.
  String? _slotFor(StoryImageKind kind, Beat beat) =>
      kind == StoryImageKind.cover ? null : beat.id;

  /// FNV-1a, the same stable hash the audio cache and world covers use.
  /// `String.hashCode` is not stable across runs, and a picture whose file
  /// name changed between launches would be a picture that vanished.
  String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
