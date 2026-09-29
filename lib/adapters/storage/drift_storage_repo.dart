import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/beat.dart';
import '../../domain/models/cast_changes.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/learned_profile.dart';
import '../../domain/models/narration.dart';
import '../../domain/models/quiz_result.dart';
import '../../domain/models/series.dart';
import '../../domain/models/story_character.dart';
import '../../domain/models/story_image.dart';
import '../../domain/models/world.dart';
import 'app_database.dart';
import 'storage_repo.dart';

/// Narration direction off a beat row. Anything unreadable degrades to "no
/// direction" — a chapter should still be readable aloud if this blob is from
/// an older build or was written badly.
NarrationNotes _narrationFrom(String json) {
  if (json.trim().isEmpty) return const NarrationNotes();
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return const NarrationNotes();
    return NarrationNotes.fromJson(decoded);
  } catch (_) {
    return const NarrationNotes();
  }
}

/// Drift-backed implementation of [StorageRepo]. All row↔domain mapping lives
/// here so the rest of the app stays free of Drift types. See `docs/data-model.md`.
class DriftStorageRepo implements StorageRepo {
  DriftStorageRepo(this._db);

  final AppDatabase _db;

  // ── Child profiles ──────────────────────────────────────────────
  @override
  Future<List<ChildProfile>> loadProfiles() async {
    final rows = await _db.select(_db.childProfiles).get();
    return rows.map(_toProfile).toList();
  }

  @override
  Future<ChildProfile?> loadProfile(String id) async {
    final row = await (_db.select(
      _db.childProfiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toProfile(row);
  }

  @override
  Future<void> saveProfile(ChildProfile profile) async {
    await _db
        .into(_db.childProfiles)
        .insertOnConflictUpdate(
          ChildProfilesCompanion.insert(
            id: profile.id,
            displayName: profile.displayName,
            age: profile.age,
            detailLevel: profile.detailLevel,
            language: Value(profile.language),
            themeColor: Value(profile.themeColor),
            parentBrief: Value(profile.parentBrief),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> deleteProfile(String id) async {
    await (_db.delete(_db.childProfiles)..where((t) => t.id.equals(id))).go();
  }

  ChildProfile _toProfile(ChildProfileRow r) => ChildProfile(
    id: r.id,
    displayName: r.displayName,
    age: r.age,
    language: r.language,
    detailLevel: r.detailLevel,
    themeColor: r.themeColor,
    parentBrief: r.parentBrief,
  );

  // ── Quiz results ────────────────────────────────────────────────
  @override
  Future<void> saveQuizResult(QuizResult result) async {
    await _db
        .into(_db.quizResults)
        .insertOnConflictUpdate(
          QuizResultsCompanion.insert(
            id: result.id,
            childId: result.childId,
            kind: result.kind,
            answers: result.answers,
            seedSummary: result.seedSummary,
            version: Value(result.version),
          ),
        );
  }

  @override
  Future<QuizResult?> latestQuizResult(String childId) async {
    final row =
        await (_db.select(_db.quizResults)
              ..where((t) => t.childId.equals(childId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return QuizResult(
      id: row.id,
      childId: row.childId,
      kind: row.kind,
      answers: row.answers,
      seedSummary: row.seedSummary,
      version: row.version,
    );
  }

  // ── Interests ───────────────────────────────────────────────────
  @override
  Future<List<Interest>> loadInterests(String childId) async {
    final rows = await (_db.select(
      _db.interests,
    )..where((t) => t.childId.equals(childId))).get();
    return rows
        .map(
          (r) => Interest(
            id: r.id,
            childId: r.childId,
            label: r.label,
            weight: r.weight,
            active: r.active,
            source: r.source,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveInterest(Interest interest) async {
    await _db
        .into(_db.interests)
        .insertOnConflictUpdate(
          InterestsCompanion.insert(
            id: interest.id,
            childId: interest.childId,
            label: interest.label,
            source: interest.source,
            weight: Value(interest.weight),
            active: Value(interest.active),
          ),
        );
  }

  @override
  Future<void> deleteInterest(String id) async {
    await (_db.delete(_db.interests)..where((t) => t.id.equals(id))).go();
  }

  // ── Learned profile ─────────────────────────────────────────────
  @override
  Future<LearnedProfile?> loadLearnedProfile(String childId) async {
    final row = await (_db.select(
      _db.learnedProfiles,
    )..where((t) => t.childId.equals(childId))).getSingleOrNull();
    if (row == null) return null;
    return _toLearned(childId, row.dataJson);
  }

  @override
  Future<void> saveLearnedProfile(LearnedProfile profile) async {
    await _db
        .into(_db.learnedProfiles)
        .insertOnConflictUpdate(
          LearnedProfilesCompanion.insert(
            childId: profile.childId,
            dataJson: Value(_learnedJson(profile)),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  LearnedProfile _toLearned(String childId, String dataJson) {
    final m = jsonDecode(dataJson) as Map<String, dynamic>;
    return LearnedProfile(
      childId: childId,
      twistAffinity:
          (m['twistAffinity'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          const {},
      favorites: (m['favorites'] as List?)?.cast<String>() ?? const [],
      inferredInterests:
          (m['inferredInterests'] as List?)?.cast<String>() ?? const [],
      observedTone: m['observedTone'] as String? ?? '',
    );
  }

  String _learnedJson(LearnedProfile p) => jsonEncode({
    'twistAffinity': p.twistAffinity,
    'favorites': p.favorites,
    'inferredInterests': p.inferredInterests,
    'observedTone': p.observedTone,
  });

  // ── Worlds ──────────────────────────────────────────────────────
  @override
  Future<List<World>> loadWorlds(String childId) async {
    final rows =
        await (_db.select(_db.worlds)
              ..where((t) => t.childId.equals(childId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(_toWorld).toList();
  }

  @override
  Future<World?> loadWorldById(String id) async {
    final row = await (_db.select(
      _db.worlds,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toWorld(row);
  }

  @override
  Future<void> saveWorld(World w) async {
    await _db
        .into(_db.worlds)
        .insertOnConflictUpdate(
          WorldsCompanion.insert(
            id: w.id,
            childId: w.childId,
            name: w.name,
            theme: w.theme,
            premise: Value(w.premise),
            extraThemes: Value(_encodeThemes(w.extraThemes)),
            voiceName: Value(w.voiceName),
            castChanges: Value(w.pendingCastChanges.encode()),
          ),
        );
  }

  @override
  Future<void> deleteWorld(String id) async {
    await (_db.delete(_db.worlds)..where((t) => t.id.equals(id))).go();
  }

  World _toWorld(WorldRow r) => World(
    id: r.id,
    childId: r.childId,
    name: r.name,
    premise: r.premise,
    theme: r.theme,
    extraThemes: _decodeThemes(r.extraThemes),
    voiceName: r.voiceName,
    pendingCastChanges: CastChanges.decode(r.castChanges),
  );

  // ── Characters ──────────────────────────────────────────────────
  @override
  Future<List<StoryCharacter>> loadCharacters(String worldId) async {
    final rows =
        await (_db.select(_db.storyCharacters)
              ..where((t) => t.worldId.equals(worldId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_toCharacter).toList();
  }

  @override
  Future<void> saveCharacter(StoryCharacter c) async {
    await _db
        .into(_db.storyCharacters)
        .insertOnConflictUpdate(
          StoryCharactersCompanion.insert(
            id: c.id,
            worldId: c.worldId,
            name: c.name,
            description: Value(c.description),
          ),
        );
  }

  @override
  Future<void> deleteCharacter(String id) async {
    await (_db.delete(_db.storyCharacters)..where((t) => t.id.equals(id))).go();
  }

  StoryCharacter _toCharacter(CharacterRow r) => StoryCharacter(
    id: r.id,
    worldId: r.worldId,
    name: r.name,
    description: r.description,
  );

  // ── Series ──────────────────────────────────────────────────────
  @override
  Future<List<Series>> loadSeries(String childId) async {
    final rows =
        await (_db.select(_db.seriesTable)
              ..where((t) => t.childId.equals(childId))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows.map(_toSeries).toList();
  }

  @override
  Future<Series?> loadSeriesById(String id) async {
    final row = await (_db.select(
      _db.seriesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toSeries(row);
  }

  @override
  Future<void> saveSeries(Series s) async {
    await _db
        .into(_db.seriesTable)
        .insertOnConflictUpdate(
          SeriesTableCompanion.insert(
            id: s.id,
            childId: s.childId,
            title: s.title,
            theme: s.theme,
            heroMode: s.heroMode,
            status: s.status,
            extraThemes: Value(_encodeThemes(s.extraThemes)),
            autoTitle: Value(s.autoTitle),
            worldId: Value(s.worldId),
            customTheme: Value(s.customTheme),
            heroName: Value(s.heroName),
            baseLanguage: Value(s.baseLanguage),
            bilingualEnabled: Value(s.bilingualEnabled),
            secondaryLanguage: Value(s.secondaryLanguage),
            bilingualBlend: Value(s.bilingualBlend),
            seedSummary: Value(s.seedSummary),
            storyBible: Value(s.storyBible),
            branchedFromBeatId: Value(s.branchedFromBeatId),
            lastReadSeq: Value(s.lastReadSeq),
            lastReadAt: Value(s.lastReadAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> deleteSeries(String id) async {
    await (_db.delete(_db.seriesTable)..where((t) => t.id.equals(id))).go();
  }

  Series _toSeries(SeriesRow r) => Series(
    id: r.id,
    childId: r.childId,
    title: r.title,
    theme: r.theme,
    extraThemes: _decodeThemes(r.extraThemes),
    autoTitle: r.autoTitle,
    worldId: r.worldId,
    customTheme: r.customTheme,
    heroMode: r.heroMode,
    heroName: r.heroName,
    baseLanguage: r.baseLanguage,
    bilingualEnabled: r.bilingualEnabled,
    secondaryLanguage: r.secondaryLanguage,
    bilingualBlend: r.bilingualBlend,
    seedSummary: r.seedSummary,
    storyBible: r.storyBible,
    branchedFromBeatId: r.branchedFromBeatId,
    status: r.status,
    lastReadSeq: r.lastReadSeq,
    lastReadAt: r.lastReadAt,
  );

  /// Extra themes ride in one column as comma-separated enum names.
  static String _encodeThemes(List<StoryTheme> themes) =>
      themes.map((t) => t.name).join(',');

  static List<StoryTheme> _decodeThemes(String raw) => [
    for (final name in raw.split(','))
      if (name.trim().isNotEmpty)
        for (final t in StoryTheme.values)
          if (t.name == name.trim()) t,
  ];

  // ── Beats ───────────────────────────────────────────────────────
  @override
  Future<List<Beat>> loadBeats(String seriesId) async {
    final rows =
        await (_db.select(_db.beats)
              ..where((t) => t.seriesId.equals(seriesId))
              ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
            .get();
    return rows.map(_toBeat).toList();
  }

  @override
  Future<void> saveBeat(Beat b) async {
    await _db
        .into(_db.beats)
        .insertOnConflictUpdate(
          BeatsCompanion.insert(
            id: b.id,
            seriesId: b.seriesId,
            childId: b.childId,
            seq: b.seq,
            intent: b.intent,
            storyText: b.text,
            summary: b.summary,
            chapterTitle: Value(b.title),
            narrationJson: Value(jsonEncode(b.narration.toJson())),
            rating: b.rating,
            characters: b.characters,
            openThreads: b.openThreads,
            chosenTwist: Value(b.chosenTwist),
            setting: Value(b.setting),
            language: Value(b.language),
            isFinal: Value(b.isFinal),
          ),
        );
  }

  @override
  Future<void> deleteBeat(String id) async {
    await (_db.delete(_db.beats)..where((t) => t.id.equals(id))).go();
  }

  // ── Pictures ────────────────────────────────────────────────────
  @override
  Future<List<StoryImage>> loadImages(String seriesId) async {
    final rows =
        await (_db.select(_db.storyImages)
              ..where((t) => t.seriesId.equals(seriesId))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    return rows.map(_toImage).toList();
  }

  @override
  Future<void> saveImage(StoryImage image) async {
    await _db
        .into(_db.storyImages)
        .insertOnConflictUpdate(
          StoryImagesCompanion.insert(
            id: image.id,
            seriesId: image.seriesId,
            beatId: Value(image.beatId),
            kind: image.kind,
            fileKey: image.fileKey,
            prompt: image.prompt,
            seed: Value(image.seed),
            model: Value(image.model),
            size: Value(image.size),
            aspect: Value(image.aspect),
          ),
        );
  }

  @override
  Future<void> deleteImage(String id) async {
    await (_db.delete(_db.storyImages)..where((t) => t.id.equals(id))).go();
  }

  StoryImage _toImage(StoryImageRow r) => StoryImage(
    id: r.id,
    seriesId: r.seriesId,
    beatId: r.beatId,
    kind: r.kind,
    fileKey: r.fileKey,
    prompt: r.prompt,
    seed: r.seed,
    model: r.model,
    size: r.size,
    aspect: r.aspect,
    createdAt: r.createdAt,
  );

  Beat _toBeat(BeatRow r) => Beat(
    id: r.id,
    seriesId: r.seriesId,
    childId: r.childId,
    seq: r.seq,
    intent: r.intent,
    text: r.storyText,
    summary: r.summary,
    title: r.chapterTitle,
    narration: _narrationFrom(r.narrationJson),
    rating: r.rating,
    setting: r.setting,
    chosenTwist: r.chosenTwist,
    characters: r.characters,
    openThreads: r.openThreads,
    language: r.language,
    isFinal: r.isFinal,
  );
}
