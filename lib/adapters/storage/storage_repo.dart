import '../../domain/models/beat.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/learned_profile.dart';
import '../../domain/models/quiz_result.dart';
import '../../domain/models/series.dart';
import '../../domain/models/story_character.dart';
import '../../domain/models/story_image.dart';
import '../../domain/models/world.dart';

/// Local-only persistence at launch; the same interface backs optional cloud
/// sync later. Backed by Drift (SQLite). Series/Beats are added in Phase 2.
/// Domain code depends on this port, never on Drift directly.
/// See `docs/data-model.md`.
abstract class StorageRepo {
  // ── Child profiles ──────────────────────────────────────────────
  Future<List<ChildProfile>> loadProfiles();
  Future<ChildProfile?> loadProfile(String id);
  Future<void> saveProfile(ChildProfile profile);
  Future<void> deleteProfile(String id);

  // ── Quiz results ────────────────────────────────────────────────
  Future<void> saveQuizResult(QuizResult result);
  Future<QuizResult?> latestQuizResult(String childId);

  // ── Interests ───────────────────────────────────────────────────
  Future<List<Interest>> loadInterests(String childId);
  Future<void> saveInterest(Interest interest);
  Future<void> deleteInterest(String id);

  // ── Learned profile ─────────────────────────────────────────────
  Future<LearnedProfile?> loadLearnedProfile(String childId);
  Future<void> saveLearnedProfile(LearnedProfile profile);

  // ── Worlds (the bookshelf) ──────────────────────────────────────
  Future<List<World>> loadWorlds(String childId);
  Future<World?> loadWorldById(String id);
  Future<void> saveWorld(World world);
  Future<void> deleteWorld(String id);

  // ── Characters ──────────────────────────────────────────────────
  Future<List<StoryCharacter>> loadCharacters(String worldId);
  Future<void> saveCharacter(StoryCharacter character);
  Future<void> deleteCharacter(String id);

  // ── Series ──────────────────────────────────────────────────────
  Future<List<Series>> loadSeries(String childId);
  Future<Series?> loadSeriesById(String id);
  Future<void> saveSeries(Series series);
  Future<void> deleteSeries(String id);

  // ── Beats ───────────────────────────────────────────────────────
  /// All beats for a series, ordered by `seq` ascending.
  Future<List<Beat>> loadBeats(String seriesId);
  Future<void> saveBeat(Beat beat);
  Future<void> deleteBeat(String id);

  // ── Pictures ────────────────────────────────────────────────────
  /// Every picture for a story, covers first then chapters in order.
  Future<List<StoryImage>> loadImages(String seriesId);
  Future<void> saveImage(StoryImage image);
  Future<void> deleteImage(String id);
}
