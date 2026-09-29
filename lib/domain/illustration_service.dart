/// Giving a story its pictures.
///
/// Draws, stores the bytes, and records what was asked for. Deliberately not
/// part of `StoryEngine`: a picture costs more than the whole story it
/// illustrates — 4,4 centimes against 2,6 for a mini episode — so it is never
/// something a turn does on its own. It happens when somebody asks.
///
/// See `docs/story-images.md`.
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../adapters/images/picture_store.dart';
import '../adapters/images/story_illustrator.dart';
import '../adapters/storage/storage_repo.dart';
import 'models/beat.dart';
import 'models/series.dart';
import 'models/story_image.dart';
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

  Future<List<StoryImage>> forSeries(String seriesId) =>
      _repo.loadImages(seriesId);

  /// Draw one picture and keep it.
  ///
  /// The file key is content-addressed over the prompt and the kind rather
  /// than the bytes, so asking twice for the same picture of the same chapter
  /// overwrites rather than accumulating — a child pressing the button twice
  /// should not fill the disk.
  Future<StoryImage> drawOne({
    required Series series,
    required Beat beat,
    required StoryImageKind kind,
    List<String> cast = const [],
    int? seed,
  }) async {
    final prompt = picturePromptFor(kind, series, beat, cast: cast);
    final drawn = await _illustrator.draw(prompt, kind: kind, seed: seed);
    final key = '${_hash('${kind.name}|${series.id}|${beat.id}|$prompt')}.png';
    await _pictures.write(key, drawn.bytes);

    final image = StoryImage(
      id: _uuid.v4(),
      seriesId: series.id,
      beatId: kind == StoryImageKind.cover ? null : beat.id,
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

  /// Illustrate a whole story: a cover, plus a picture on the chapters that
  /// earn one. [onProgress] reports pictures finished, for an indicator.
  ///
  /// A refusal on one picture does not abandon the rest — a chapter whose
  /// image trips a safety filter simply has no picture, which is a story that
  /// looks slightly plainer rather than a button that did nothing.
  Future<List<StoryImage>> illustrate({
    required Series series,
    required List<Beat> beats,
    List<String> cast = const [],
    bool cover = true,
    void Function(int done, int total)? onProgress,
  }) async {
    if (beats.isEmpty) return const [];
    final wanted = chaptersToIllustrate(beats.length);
    final total = wanted.length + (cover ? 1 : 0);
    final made = <StoryImage>[];

    Future<void> attempt(Beat beat, StoryImageKind kind) async {
      try {
        made.add(
          await drawOne(series: series, beat: beat, kind: kind, cast: cast),
        );
      } catch (_) {
        // Deliberately swallowed: see the doc comment above.
      }
      onProgress?.call(made.length, total);
    }

    if (cover) await attempt(beats.first, StoryImageKind.cover);
    for (final index in wanted) {
      await attempt(beats[index], StoryImageKind.chapter);
    }
    return made;
  }

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
