import 'package:moonloom/adapters/storage/storage_repo.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/interest.dart';
import 'package:moonloom/domain/models/learned_profile.dart';
import 'package:moonloom/domain/models/quiz_result.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/story_image.dart';
import 'package:moonloom/domain/models/world.dart';

/// A pure-Dart [StorageRepo] for tests — no Drift, no native sqlite, no
/// platform channels. The real DriftStorageRepo is exercised at app runtime.
class InMemoryStorageRepo implements StorageRepo {
  final Map<String, ChildProfile> _profiles = {};
  final Map<String, List<QuizResult>> _quiz = {};
  final Map<String, Interest> _interests = {};
  final Map<String, LearnedProfile> _learned = {};

  @override
  Future<List<ChildProfile>> loadProfiles() async => _profiles.values.toList();

  @override
  Future<ChildProfile?> loadProfile(String id) async => _profiles[id];

  @override
  Future<void> saveProfile(ChildProfile profile) async =>
      _profiles[profile.id] = profile;

  @override
  Future<void> deleteProfile(String id) async => _profiles.remove(id);

  @override
  Future<void> saveQuizResult(QuizResult result) async =>
      (_quiz[result.childId] ??= []).add(result);

  @override
  Future<QuizResult?> latestQuizResult(String childId) async {
    final list = _quiz[childId];
    return (list == null || list.isEmpty) ? null : list.last;
  }

  @override
  Future<List<Interest>> loadInterests(String childId) async =>
      _interests.values.where((i) => i.childId == childId).toList();

  @override
  Future<void> saveInterest(Interest interest) async =>
      _interests[interest.id] = interest;

  @override
  Future<void> deleteInterest(String id) async => _interests.remove(id);

  @override
  Future<LearnedProfile?> loadLearnedProfile(String childId) async =>
      _learned[childId];

  @override
  Future<void> saveLearnedProfile(LearnedProfile profile) async =>
      _learned[profile.childId] = profile;

  final Map<String, World> _worlds = {};
  final Map<String, StoryCharacter> _characters = {};

  @override
  Future<List<World>> loadWorlds(String childId) async =>
      _worlds.values.where((w) => w.childId == childId).toList();

  @override
  Future<World?> loadWorldById(String id) async => _worlds[id];

  @override
  Future<void> saveWorld(World world) async => _worlds[world.id] = world;

  @override
  Future<void> deleteWorld(String id) async {
    _worlds.remove(id);
    _characters.removeWhere((_, c) => c.worldId == id);
    _series.removeWhere((_, s) => s.worldId == id);
  }

  @override
  Future<List<StoryCharacter>> loadCharacters(String worldId) async =>
      _characters.values.where((c) => c.worldId == worldId).toList();

  @override
  Future<void> saveCharacter(StoryCharacter character) async =>
      _characters[character.id] = character;

  @override
  Future<void> deleteCharacter(String id) async => _characters.remove(id);

  final Map<String, Series> _series = {};
  final Map<String, List<Beat>> _beats = {};

  @override
  Future<List<Series>> loadSeries(String childId) async =>
      _series.values.where((s) => s.childId == childId).toList();

  @override
  Future<Series?> loadSeriesById(String id) async => _series[id];

  @override
  Future<void> saveSeries(Series series) async => _series[series.id] = series;

  @override
  Future<void> deleteSeries(String id) async {
    _series.remove(id);
    _beats.remove(id);
  }

  @override
  Future<List<Beat>> loadBeats(String seriesId) async {
    final list = [...?_beats[seriesId]]..sort((a, b) => a.seq.compareTo(b.seq));
    return list;
  }

  @override
  Future<void> saveBeat(Beat beat) async {
    final list = _beats[beat.seriesId] ??= [];
    list.removeWhere((b) => b.id == beat.id); // upsert by id
    list.add(beat);
  }

  @override
  Future<void> deleteBeat(String id) async {
    for (final list in _beats.values) {
      list.removeWhere((b) => b.id == id);
    }
  }

  // ── Pictures ────────────────────────────────────────────────────
  final Map<String, List<StoryImage>> _images = {};

  @override
  Future<List<StoryImage>> loadImages(String seriesId) async =>
      List.unmodifiable(_images[seriesId] ?? const []);

  @override
  Future<void> saveImage(StoryImage image) async {
    final list = _images.putIfAbsent(image.seriesId, () => []);
    list.removeWhere((i) => i.id == image.id);
    list.add(image);
  }

  @override
  Future<void> deleteImage(String id) async {
    for (final list in _images.values) {
      list.removeWhere((i) => i.id == id);
    }
  }
}
