import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/beat.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/quiz_result.dart';
import '../../domain/models/series.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────
// @DataClassName keeps Drift's generated row classes from colliding with our
// hand-written pure-Dart domain models of the same name.

@DataClassName('ChildProfileRow')
class ChildProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  IntColumn get age => integer()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  IntColumn get detailLevel => intEnum<DetailLevel>()();
  IntColumn get themeColor =>
      integer().withDefault(const Constant(0xFF6750A4))();
  TextColumn get parentBrief => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('QuizResultRow')
class QuizResults extends Table {
  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  IntColumn get kind => intEnum<QuizKind>()();
  TextColumn get answers => text().map(const _StringMapConverter())();
  TextColumn get seedSummary => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InterestRow')
class Interests extends Table {
  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  IntColumn get weight => integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get source => intEnum<InterestSource>()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LearnedProfileRow')
class LearnedProfiles extends Table {
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {childId};
}

@DataClassName('WorldRow')
class Worlds extends Table {
  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get premise => text().withDefault(const Constant(''))();
  IntColumn get theme => intEnum<StoryTheme>()();

  /// Up to two extra themes blended with [theme], as comma-separated enum names.
  TextColumn get extraThemes => text().withDefault(const Constant(''))();

  /// The voice that tells every story in this world; empty means the parent's
  /// setting. Only the voice name, never the engine — see World.voiceName.
  TextColumn get voiceName => text().withDefault(const Constant(''))();

  /// Cast edits (arrivals/departures) the next story must acknowledge, as JSON.
  TextColumn get castChanges => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CharacterRow')
class StoryCharacters extends Table {
  @override
  String get tableName => 'characters';

  TextColumn get id => text()();
  TextColumn get worldId =>
      text().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SeriesRow')
class SeriesTable extends Table {
  @override
  String get tableName => 'series';

  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get worldId =>
      text().nullable().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get theme => intEnum<StoryTheme>()();

  /// Up to two extra themes blended with [theme], as comma-separated enum names.
  TextColumn get extraThemes => text().withDefault(const Constant(''))();

  /// True while [title] is a placeholder awaiting a model-suggested title.
  BoolColumn get autoTitle => boolean().withDefault(const Constant(false))();
  TextColumn get customTheme => text().nullable()();
  IntColumn get heroMode => intEnum<HeroMode>()();
  TextColumn get heroName => text().nullable()();
  BoolColumn get bilingualEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get secondaryLanguage => text().nullable()();
  IntColumn get bilingualBlend => intEnum<BilingualBlend>().nullable()();
  TextColumn get seedSummary => text().withDefault(const Constant(''))();
  TextColumn get storyBible => text().withDefault(const Constant(''))();
  TextColumn get branchedFromBeatId => text().nullable()();
  IntColumn get status => intEnum<SeriesStatus>()();

  /// The language this story is told in, overriding the child's own. Null
  /// means "whatever the child is set to" — the case for every story written
  /// before a bilingual household needed two.
  TextColumn get baseLanguage => text().nullable()();

  /// Reading position: the chapter last opened and when, so the bookshelf can
  /// offer "Continue — Chapter 4".
  IntColumn get lastReadSeq => integer().nullable()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BeatRow')
class Beats extends Table {
  TextColumn get id => text()();
  TextColumn get seriesId =>
      text().references(SeriesTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get childId => text()();
  IntColumn get seq => integer()();
  IntColumn get intent => intEnum<StoryIntent>()();
  TextColumn get chosenTwist => text().nullable()();
  TextColumn get storyText => text()();
  TextColumn get summary => text()();
  TextColumn get chapterTitle => text().withDefault(const Constant(''))();

  /// Narration direction as JSON — see `NarrationNotes`. One blob rather than
  /// three columns: it is never queried, only handed to the voice.
  TextColumn get narrationJson => text().withDefault(const Constant('{}'))();
  IntColumn get rating => intEnum<AgeRating>()();
  TextColumn get setting => text().withDefault(const Constant(''))();
  TextColumn get characters => text().map(const _StringListConverter())();
  TextColumn get openThreads => text().map(const _StringListConverter())();
  TextColumn get language => text().withDefault(const Constant('en'))();
  BoolColumn get isFinal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─── Converters ───────────────────────────────────────────────────────

class _StringMapConverter extends TypeConverter<Map<String, String>, String> {
  const _StringMapConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}

class _StringListConverter extends TypeConverter<List<String>, String> {
  const _StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).map((e) => e.toString()).toList();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

// ─── Database ─────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    ChildProfiles,
    QuizResults,
    Interests,
    LearnedProfiles,
    Worlds,
    StoryCharacters,
    SeriesTable,
    Beats,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 10;

  /// The library's file name, under the user's documents folder.
  static const String fileName = 'sleepytime.sqlite';

  /// Opens the on-device database file. Foreign keys on.
  ///
  /// [directory] is the documents folder. The app passes it from
  /// path_provider; the read-only probes in `tool/` pass it themselves, which
  /// is the point — asking a Flutter plugin for it here would put all of
  /// Flutter behind a plain `dart run`.
  static AppDatabase openIn(String directory) {
    final executor = LazyDatabase(
      () async =>
          NativeDatabase.createInBackground(File(p.join(directory, fileName))),
    );
    return AppDatabase(executor);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v1 → v2: add Series + Beats (story engine).
      if (from < 2) {
        await m.createTable(seriesTable);
        await m.createTable(beats);
      }
      if (from < 3) {
        await m.addColumn(beats, beats.isFinal);
      }
      // v3 → v4: Worlds + Characters (the bookshelf), and episodes gain a
      // nullable worldId (existing stories stay standalone with worldId = null).
      if (from < 4) {
        await m.createTable(worlds);
        await m.createTable(storyCharacters);
        await m.addColumn(seriesTable, seriesTable.worldId);
      }
      // v4 → v5: multi-theme stories, model-suggested titles, and pending cast
      // changes on a world (so a removed character gets written out).
      if (from < 5) {
        await m.addColumn(seriesTable, seriesTable.extraThemes);
        await m.addColumn(seriesTable, seriesTable.autoTitle);
        await m.addColumn(worlds, worlds.extraThemes);
        await m.addColumn(worlds, worlds.castChanges);
      }
      // v5 → v6: reading position, so a part-heard story can be resumed.
      // Existing stories start with no position (null = never opened).
      if (from < 6) {
        await _addColumnIfMissing(
          // The SQL table is `series`; `seriesTable` is only the Dart name.
          'series',
          'last_read_seq',
          () => m.addColumn(seriesTable, seriesTable.lastReadSeq),
        );
        await _addColumnIfMissing(
          // The SQL table is `series`; `seriesTable` is only the Dart name.
          'series',
          'last_read_at',
          () => m.addColumn(seriesTable, seriesTable.lastReadAt),
        );
      }
      // v6 → v7: per-chapter titles. Chapters written before this keep the
      // empty default and simply show their number, as they always did.
      if (from < 7) {
        await _addColumnIfMissing(
          'beats',
          'chapter_title',
          () => m.addColumn(beats, beats.chapterTitle),
        );
      }
      // v7 → v8: narration direction for the voice.
      //
      // Every step from 6 on is guarded, because branches share the one
      // database in the documents folder and a branch that reuses a version
      // the database has already passed gets no upgrade callback at all — the
      // column is silently never added and the failure surfaces far away, as
      // a null-check crash when drift maps a row.
      if (from < 8) {
        await _addColumnIfMissing(
          'beats',
          'narration_json',
          () => m.addColumn(beats, beats.narrationJson),
        );
      }
      // v8 → v9: a story can be told in a language other than the child's, so
      // one child can have stories in both of theirs.
      if (from < 9) {
        await _addColumnIfMissing(
          // The SQL table is `series`; `seriesTable` is only the Dart name.
          'series',
          'base_language',
          () => m.addColumn(seriesTable, seriesTable.baseLanguage),
        );
      }
      // v9 → v10: a world keeps its own storyteller, so every episode in it
      // sounds like the same person.
      if (from < 10) {
        await _addColumnIfMissing(
          'worlds',
          'voice_name',
          () => m.addColumn(worlds, worlds.voiceName),
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Branches share the one database file in the documents folder, so a
      // database can reach a version number without having taken every step
      // that number implies — one branch stamps v8, another branch's v6 step
      // then never runs, because onUpgrade is skipped entirely once
      // `from == to`. The missing column surfaces far away and much later, as
      // a null-check crash on read or "no such column" on save.
      //
      // Reconciling on open costs a few pragma reads and is a no-op once
      // everything is present, which is cheaper than the debugging it saves.
      await _ensureColumn(
        // The SQL table is `series`; `seriesTable` is only the Dart name.
        'series',
        'last_read_seq',
        'INTEGER',
      );
      await _ensureColumn(
        // The SQL table is `series`; `seriesTable` is only the Dart name.
        'series',
        'last_read_at',
        'INTEGER',
      );
      await _ensureColumn('beats', 'chapter_title', "TEXT NOT NULL DEFAULT ''");
      await _ensureColumn(
        'beats',
        'narration_json',
        "TEXT NOT NULL DEFAULT '{}'",
      );
      await _ensureColumn(
        // The SQL table is `series`; `seriesTable` is only the Dart name.
        'series',
        'base_language',
        'TEXT',
      );
      await _ensureColumn('worlds', 'voice_name', "TEXT NOT NULL DEFAULT ''");
    },
  );

  /// Add a column straight to the table if it is missing, whatever the
  /// database's version number claims. Used by `beforeOpen` to heal a database
  /// that skipped a step by arriving at a version another branch had stamped.
  Future<void> _ensureColumn(String table, String column, String type) async {
    final info = await customSelect('PRAGMA table_info($table)').get();
    final present = info.any((row) => row.read<String>('name') == column);
    if (present) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
  }

  /// Add a column only when it isn't there already.
  ///
  /// A database created fresh on this branch got the column from `onCreate`
  /// and still reports the older version, so a plain `addColumn` would fail
  /// with "duplicate column name". Checking first makes the step safe to run
  /// against a database in either state.
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    Future<void> Function() add,
  ) async {
    final info = await customSelect('PRAGMA table_info($table)').get();
    final present = info.any((row) => row.read<String>('name') == column);
    if (!present) await add();
  }
}
