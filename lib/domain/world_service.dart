import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/beat.dart';
import 'models/series.dart';
import 'models/story_character.dart';
import 'models/world.dart';

/// Manages a child's story "universes" (the bookshelf). Each [World] holds a
/// premise + characters and spawns many episodes. See `docs/data-model.md`.
class WorldService {
  WorldService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  Future<List<World>> forChild(String childId) => _repo.loadWorlds(childId);

  Future<World> create({
    required String childId,
    required String name,
    String premise = '',
    StoryTheme theme = StoryTheme.cozy,
    List<StoryTheme> extraThemes = const [],
    String voiceName = '',
  }) async {
    final world = World(
      id: _uuid.v4(),
      childId: childId,
      name: name,
      premise: premise,
      theme: theme,
      extraThemes: extraThemes,
      voiceName: voiceName,
    );
    await _repo.saveWorld(world);
    return world;
  }

  Future<void> update(World world) => _repo.saveWorld(world);

  /// Promote a standalone story into a world of its own, so it can keep
  /// spawning episodes. The story becomes the world's first episode, its
  /// flavours carry over, its recap seeds the premise, and the people in it
  /// become the saved cast. The grown-up polishes all of that afterwards in
  /// "Edit world". See `docs/ui-ux.md`.
  Future<World> fromSeries(Series series, {String? name}) async {
    final beats = await _repo.loadBeats(series.id);
    final world = World(
      id: _uuid.v4(),
      childId: series.childId,
      name: (name ?? series.title).trim().isEmpty
          ? series.title
          : (name ?? series.title).trim(),
      premise: _premiseFrom(series, beats),
      theme: series.theme,
      extraThemes: series.extraThemes,
    );
    await _repo.saveWorld(world);

    // Straight to the repo, not CharacterService: these people are already in
    // the story, so there is nobody to introduce in the next one.
    for (final name in _castFrom(beats)) {
      await _repo.saveCharacter(
        StoryCharacter(id: _uuid.v4(), worldId: world.id, name: name),
      );
    }

    await _repo.saveSeries(series.copyWith(worldId: world.id));
    return world;
  }

  /// A premise built from the story's own recap, capped so it stays cheap to
  /// inject into every future episode's prompt.
  static String _premiseFrom(Series series, List<Beat> beats) {
    final recap = series.storyBible.trim().isNotEmpty
        ? series.storyBible.trim()
        : beats
              .map((b) => b.summary.trim())
              .where((s) => s.isNotEmpty)
              .join(' ');
    final opening = 'The world of "${series.title}".';
    if (recap.isEmpty) return opening;
    return '$opening ${_clip(recap, 400)}';
  }

  /// Trim to [max] characters, preferring to stop at a sentence end.
  static String _clip(String text, int max) {
    if (text.length <= max) return text;
    final cut = text.substring(0, max);
    final stop = cut.lastIndexOf(RegExp(r'[.!?]'));
    return stop > max ~/ 2 ? cut.substring(0, stop + 1) : '$cut…';
  }

  /// The recurring people in a story: names the model reported per chapter,
  /// ranked by how often they came up (one-scene walk-ons don't earn a slot in
  /// the permanent cast), capped so the world doesn't start out crowded.
  static List<String> _castFrom(List<Beat> beats) {
    final counts = <String, int>{};
    for (final beat in beats) {
      for (final raw in beat.characters) {
        final name = raw.trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names.take(6).toList();
  }

  /// Delete a world and (via FK cascade) its characters + episodes.
  Future<void> delete(String id) => _repo.deleteWorld(id);
}
