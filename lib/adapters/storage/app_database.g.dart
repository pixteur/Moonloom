// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChildProfilesTable extends ChildProfiles
    with TableInfo<$ChildProfilesTable, ChildProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChildProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DetailLevel, int> detailLevel =
      GeneratedColumn<int>(
        'detail_level',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DetailLevel>($ChildProfilesTable.$converterdetailLevel);
  static const VerificationMeta _themeColorMeta = const VerificationMeta(
    'themeColor',
  );
  @override
  late final GeneratedColumn<int> themeColor = GeneratedColumn<int>(
    'theme_color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF6750A4),
  );
  static const VerificationMeta _parentBriefMeta = const VerificationMeta(
    'parentBrief',
  );
  @override
  late final GeneratedColumn<String> parentBrief = GeneratedColumn<String>(
    'parent_brief',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    age,
    language,
    detailLevel,
    themeColor,
    parentBrief,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'child_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChildProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('theme_color')) {
      context.handle(
        _themeColorMeta,
        themeColor.isAcceptableOrUnknown(data['theme_color']!, _themeColorMeta),
      );
    }
    if (data.containsKey('parent_brief')) {
      context.handle(
        _parentBriefMeta,
        parentBrief.isAcceptableOrUnknown(
          data['parent_brief']!,
          _parentBriefMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChildProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChildProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      detailLevel: $ChildProfilesTable.$converterdetailLevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}detail_level'],
        )!,
      ),
      themeColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}theme_color'],
      )!,
      parentBrief: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_brief'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChildProfilesTable createAlias(String alias) {
    return $ChildProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DetailLevel, int, int> $converterdetailLevel =
      const EnumIndexConverter<DetailLevel>(DetailLevel.values);
}

class ChildProfileRow extends DataClass implements Insertable<ChildProfileRow> {
  final String id;
  final String displayName;
  final int age;
  final String language;
  final DetailLevel detailLevel;
  final int themeColor;
  final String? parentBrief;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChildProfileRow({
    required this.id,
    required this.displayName,
    required this.age,
    required this.language,
    required this.detailLevel,
    required this.themeColor,
    this.parentBrief,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['age'] = Variable<int>(age);
    map['language'] = Variable<String>(language);
    {
      map['detail_level'] = Variable<int>(
        $ChildProfilesTable.$converterdetailLevel.toSql(detailLevel),
      );
    }
    map['theme_color'] = Variable<int>(themeColor);
    if (!nullToAbsent || parentBrief != null) {
      map['parent_brief'] = Variable<String>(parentBrief);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChildProfilesCompanion toCompanion(bool nullToAbsent) {
    return ChildProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      age: Value(age),
      language: Value(language),
      detailLevel: Value(detailLevel),
      themeColor: Value(themeColor),
      parentBrief: parentBrief == null && nullToAbsent
          ? const Value.absent()
          : Value(parentBrief),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChildProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChildProfileRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      age: serializer.fromJson<int>(json['age']),
      language: serializer.fromJson<String>(json['language']),
      detailLevel: $ChildProfilesTable.$converterdetailLevel.fromJson(
        serializer.fromJson<int>(json['detailLevel']),
      ),
      themeColor: serializer.fromJson<int>(json['themeColor']),
      parentBrief: serializer.fromJson<String?>(json['parentBrief']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'age': serializer.toJson<int>(age),
      'language': serializer.toJson<String>(language),
      'detailLevel': serializer.toJson<int>(
        $ChildProfilesTable.$converterdetailLevel.toJson(detailLevel),
      ),
      'themeColor': serializer.toJson<int>(themeColor),
      'parentBrief': serializer.toJson<String?>(parentBrief),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChildProfileRow copyWith({
    String? id,
    String? displayName,
    int? age,
    String? language,
    DetailLevel? detailLevel,
    int? themeColor,
    Value<String?> parentBrief = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChildProfileRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    age: age ?? this.age,
    language: language ?? this.language,
    detailLevel: detailLevel ?? this.detailLevel,
    themeColor: themeColor ?? this.themeColor,
    parentBrief: parentBrief.present ? parentBrief.value : this.parentBrief,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChildProfileRow copyWithCompanion(ChildProfilesCompanion data) {
    return ChildProfileRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      age: data.age.present ? data.age.value : this.age,
      language: data.language.present ? data.language.value : this.language,
      detailLevel: data.detailLevel.present
          ? data.detailLevel.value
          : this.detailLevel,
      themeColor: data.themeColor.present
          ? data.themeColor.value
          : this.themeColor,
      parentBrief: data.parentBrief.present
          ? data.parentBrief.value
          : this.parentBrief,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfileRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('age: $age, ')
          ..write('language: $language, ')
          ..write('detailLevel: $detailLevel, ')
          ..write('themeColor: $themeColor, ')
          ..write('parentBrief: $parentBrief, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    age,
    language,
    detailLevel,
    themeColor,
    parentBrief,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChildProfileRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.age == this.age &&
          other.language == this.language &&
          other.detailLevel == this.detailLevel &&
          other.themeColor == this.themeColor &&
          other.parentBrief == this.parentBrief &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChildProfilesCompanion extends UpdateCompanion<ChildProfileRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<int> age;
  final Value<String> language;
  final Value<DetailLevel> detailLevel;
  final Value<int> themeColor;
  final Value<String?> parentBrief;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChildProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.age = const Value.absent(),
    this.language = const Value.absent(),
    this.detailLevel = const Value.absent(),
    this.themeColor = const Value.absent(),
    this.parentBrief = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChildProfilesCompanion.insert({
    required String id,
    required String displayName,
    required int age,
    this.language = const Value.absent(),
    required DetailLevel detailLevel,
    this.themeColor = const Value.absent(),
    this.parentBrief = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       age = Value(age),
       detailLevel = Value(detailLevel);
  static Insertable<ChildProfileRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<int>? age,
    Expression<String>? language,
    Expression<int>? detailLevel,
    Expression<int>? themeColor,
    Expression<String>? parentBrief,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (age != null) 'age': age,
      if (language != null) 'language': language,
      if (detailLevel != null) 'detail_level': detailLevel,
      if (themeColor != null) 'theme_color': themeColor,
      if (parentBrief != null) 'parent_brief': parentBrief,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChildProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<int>? age,
    Value<String>? language,
    Value<DetailLevel>? detailLevel,
    Value<int>? themeColor,
    Value<String?>? parentBrief,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChildProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      language: language ?? this.language,
      detailLevel: detailLevel ?? this.detailLevel,
      themeColor: themeColor ?? this.themeColor,
      parentBrief: parentBrief ?? this.parentBrief,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (detailLevel.present) {
      map['detail_level'] = Variable<int>(
        $ChildProfilesTable.$converterdetailLevel.toSql(detailLevel.value),
      );
    }
    if (themeColor.present) {
      map['theme_color'] = Variable<int>(themeColor.value);
    }
    if (parentBrief.present) {
      map['parent_brief'] = Variable<String>(parentBrief.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('age: $age, ')
          ..write('language: $language, ')
          ..write('detailLevel: $detailLevel, ')
          ..write('themeColor: $themeColor, ')
          ..write('parentBrief: $parentBrief, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuizResultsTable extends QuizResults
    with TableInfo<$QuizResultsTable, QuizResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<QuizKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<QuizKind>($QuizResultsTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
  answers = GeneratedColumn<String>(
    'answers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Map<String, String>>($QuizResultsTable.$converteranswers);
  static const VerificationMeta _seedSummaryMeta = const VerificationMeta(
    'seedSummary',
  );
  @override
  late final GeneratedColumn<String> seedSummary = GeneratedColumn<String>(
    'seed_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    kind,
    answers,
    seedSummary,
    version,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('seed_summary')) {
      context.handle(
        _seedSummaryMeta,
        seedSummary.isAcceptableOrUnknown(
          data['seed_summary']!,
          _seedSummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seedSummaryMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizResultRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      kind: $QuizResultsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      answers: $QuizResultsTable.$converteranswers.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}answers'],
        )!,
      ),
      seedSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_summary'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $QuizResultsTable createAlias(String alias) {
    return $QuizResultsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<QuizKind, int, int> $converterkind =
      const EnumIndexConverter<QuizKind>(QuizKind.values);
  static TypeConverter<Map<String, String>, String> $converteranswers =
      const _StringMapConverter();
}

class QuizResultRow extends DataClass implements Insertable<QuizResultRow> {
  final String id;
  final String childId;
  final QuizKind kind;
  final Map<String, String> answers;
  final String seedSummary;
  final int version;
  final DateTime createdAt;
  const QuizResultRow({
    required this.id,
    required this.childId,
    required this.kind,
    required this.answers,
    required this.seedSummary,
    required this.version,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    {
      map['kind'] = Variable<int>($QuizResultsTable.$converterkind.toSql(kind));
    }
    {
      map['answers'] = Variable<String>(
        $QuizResultsTable.$converteranswers.toSql(answers),
      );
    }
    map['seed_summary'] = Variable<String>(seedSummary);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QuizResultsCompanion toCompanion(bool nullToAbsent) {
    return QuizResultsCompanion(
      id: Value(id),
      childId: Value(childId),
      kind: Value(kind),
      answers: Value(answers),
      seedSummary: Value(seedSummary),
      version: Value(version),
      createdAt: Value(createdAt),
    );
  }

  factory QuizResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizResultRow(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      kind: $QuizResultsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      answers: serializer.fromJson<Map<String, String>>(json['answers']),
      seedSummary: serializer.fromJson<String>(json['seedSummary']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'kind': serializer.toJson<int>(
        $QuizResultsTable.$converterkind.toJson(kind),
      ),
      'answers': serializer.toJson<Map<String, String>>(answers),
      'seedSummary': serializer.toJson<String>(seedSummary),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QuizResultRow copyWith({
    String? id,
    String? childId,
    QuizKind? kind,
    Map<String, String>? answers,
    String? seedSummary,
    int? version,
    DateTime? createdAt,
  }) => QuizResultRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    kind: kind ?? this.kind,
    answers: answers ?? this.answers,
    seedSummary: seedSummary ?? this.seedSummary,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
  );
  QuizResultRow copyWithCompanion(QuizResultsCompanion data) {
    return QuizResultRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      kind: data.kind.present ? data.kind.value : this.kind,
      answers: data.answers.present ? data.answers.value : this.answers,
      seedSummary: data.seedSummary.present
          ? data.seedSummary.value
          : this.seedSummary,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('kind: $kind, ')
          ..write('answers: $answers, ')
          ..write('seedSummary: $seedSummary, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, childId, kind, answers, seedSummary, version, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizResultRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.kind == this.kind &&
          other.answers == this.answers &&
          other.seedSummary == this.seedSummary &&
          other.version == this.version &&
          other.createdAt == this.createdAt);
}

class QuizResultsCompanion extends UpdateCompanion<QuizResultRow> {
  final Value<String> id;
  final Value<String> childId;
  final Value<QuizKind> kind;
  final Value<Map<String, String>> answers;
  final Value<String> seedSummary;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const QuizResultsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.kind = const Value.absent(),
    this.answers = const Value.absent(),
    this.seedSummary = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuizResultsCompanion.insert({
    required String id,
    required String childId,
    required QuizKind kind,
    required Map<String, String> answers,
    required String seedSummary,
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       kind = Value(kind),
       answers = Value(answers),
       seedSummary = Value(seedSummary);
  static Insertable<QuizResultRow> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<int>? kind,
    Expression<String>? answers,
    Expression<String>? seedSummary,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (kind != null) 'kind': kind,
      if (answers != null) 'answers': answers,
      if (seedSummary != null) 'seed_summary': seedSummary,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuizResultsCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<QuizKind>? kind,
    Value<Map<String, String>>? answers,
    Value<String>? seedSummary,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return QuizResultsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      kind: kind ?? this.kind,
      answers: answers ?? this.answers,
      seedSummary: seedSummary ?? this.seedSummary,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $QuizResultsTable.$converterkind.toSql(kind.value),
      );
    }
    if (answers.present) {
      map['answers'] = Variable<String>(
        $QuizResultsTable.$converteranswers.toSql(answers.value),
      );
    }
    if (seedSummary.present) {
      map['seed_summary'] = Variable<String>(seedSummary.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('kind: $kind, ')
          ..write('answers: $answers, ')
          ..write('seedSummary: $seedSummary, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InterestsTable extends Interests
    with TableInfo<$InterestsTable, InterestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InterestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InterestSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<InterestSource>($InterestsTable.$convertersource);
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    label,
    weight,
    active,
    source,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interests';
  @override
  VerificationContext validateIntegrity(
    Insertable<InterestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InterestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InterestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      source: $InterestsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $InterestsTable createAlias(String alias) {
    return $InterestsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InterestSource, int, int> $convertersource =
      const EnumIndexConverter<InterestSource>(InterestSource.values);
}

class InterestRow extends DataClass implements Insertable<InterestRow> {
  final String id;
  final String childId;
  final String label;
  final int weight;
  final bool active;
  final InterestSource source;
  final DateTime addedAt;
  const InterestRow({
    required this.id,
    required this.childId,
    required this.label,
    required this.weight,
    required this.active,
    required this.source,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    map['label'] = Variable<String>(label);
    map['weight'] = Variable<int>(weight);
    map['active'] = Variable<bool>(active);
    {
      map['source'] = Variable<int>(
        $InterestsTable.$convertersource.toSql(source),
      );
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  InterestsCompanion toCompanion(bool nullToAbsent) {
    return InterestsCompanion(
      id: Value(id),
      childId: Value(childId),
      label: Value(label),
      weight: Value(weight),
      active: Value(active),
      source: Value(source),
      addedAt: Value(addedAt),
    );
  }

  factory InterestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InterestRow(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      label: serializer.fromJson<String>(json['label']),
      weight: serializer.fromJson<int>(json['weight']),
      active: serializer.fromJson<bool>(json['active']),
      source: $InterestsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'label': serializer.toJson<String>(label),
      'weight': serializer.toJson<int>(weight),
      'active': serializer.toJson<bool>(active),
      'source': serializer.toJson<int>(
        $InterestsTable.$convertersource.toJson(source),
      ),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  InterestRow copyWith({
    String? id,
    String? childId,
    String? label,
    int? weight,
    bool? active,
    InterestSource? source,
    DateTime? addedAt,
  }) => InterestRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    label: label ?? this.label,
    weight: weight ?? this.weight,
    active: active ?? this.active,
    source: source ?? this.source,
    addedAt: addedAt ?? this.addedAt,
  );
  InterestRow copyWithCompanion(InterestsCompanion data) {
    return InterestRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      label: data.label.present ? data.label.value : this.label,
      weight: data.weight.present ? data.weight.value : this.weight,
      active: data.active.present ? data.active.value : this.active,
      source: data.source.present ? data.source.value : this.source,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InterestRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('label: $label, ')
          ..write('weight: $weight, ')
          ..write('active: $active, ')
          ..write('source: $source, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, childId, label, weight, active, source, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterestRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.label == this.label &&
          other.weight == this.weight &&
          other.active == this.active &&
          other.source == this.source &&
          other.addedAt == this.addedAt);
}

class InterestsCompanion extends UpdateCompanion<InterestRow> {
  final Value<String> id;
  final Value<String> childId;
  final Value<String> label;
  final Value<int> weight;
  final Value<bool> active;
  final Value<InterestSource> source;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const InterestsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.label = const Value.absent(),
    this.weight = const Value.absent(),
    this.active = const Value.absent(),
    this.source = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InterestsCompanion.insert({
    required String id,
    required String childId,
    required String label,
    this.weight = const Value.absent(),
    this.active = const Value.absent(),
    required InterestSource source,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       label = Value(label),
       source = Value(source);
  static Insertable<InterestRow> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<String>? label,
    Expression<int>? weight,
    Expression<bool>? active,
    Expression<int>? source,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (label != null) 'label': label,
      if (weight != null) 'weight': weight,
      if (active != null) 'active': active,
      if (source != null) 'source': source,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InterestsCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<String>? label,
    Value<int>? weight,
    Value<bool>? active,
    Value<InterestSource>? source,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return InterestsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      label: label ?? this.label,
      weight: weight ?? this.weight,
      active: active ?? this.active,
      source: source ?? this.source,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $InterestsTable.$convertersource.toSql(source.value),
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InterestsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('label: $label, ')
          ..write('weight: $weight, ')
          ..write('active: $active, ')
          ..write('source: $source, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearnedProfilesTable extends LearnedProfiles
    with TableInfo<$LearnedProfilesTable, LearnedProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [childId, dataJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learned_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnedProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {childId};
  @override
  LearnedProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnedProfileRow(
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LearnedProfilesTable createAlias(String alias) {
    return $LearnedProfilesTable(attachedDatabase, alias);
  }
}

class LearnedProfileRow extends DataClass
    implements Insertable<LearnedProfileRow> {
  final String childId;
  final String dataJson;
  final DateTime updatedAt;
  const LearnedProfileRow({
    required this.childId,
    required this.dataJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['child_id'] = Variable<String>(childId);
    map['data_json'] = Variable<String>(dataJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LearnedProfilesCompanion toCompanion(bool nullToAbsent) {
    return LearnedProfilesCompanion(
      childId: Value(childId),
      dataJson: Value(dataJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LearnedProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnedProfileRow(
      childId: serializer.fromJson<String>(json['childId']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'childId': serializer.toJson<String>(childId),
      'dataJson': serializer.toJson<String>(dataJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LearnedProfileRow copyWith({
    String? childId,
    String? dataJson,
    DateTime? updatedAt,
  }) => LearnedProfileRow(
    childId: childId ?? this.childId,
    dataJson: dataJson ?? this.dataJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LearnedProfileRow copyWithCompanion(LearnedProfilesCompanion data) {
    return LearnedProfileRow(
      childId: data.childId.present ? data.childId.value : this.childId,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnedProfileRow(')
          ..write('childId: $childId, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(childId, dataJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnedProfileRow &&
          other.childId == this.childId &&
          other.dataJson == this.dataJson &&
          other.updatedAt == this.updatedAt);
}

class LearnedProfilesCompanion extends UpdateCompanion<LearnedProfileRow> {
  final Value<String> childId;
  final Value<String> dataJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LearnedProfilesCompanion({
    this.childId = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearnedProfilesCompanion.insert({
    required String childId,
    this.dataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : childId = Value(childId);
  static Insertable<LearnedProfileRow> custom({
    Expression<String>? childId,
    Expression<String>? dataJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (childId != null) 'child_id': childId,
      if (dataJson != null) 'data_json': dataJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearnedProfilesCompanion copyWith({
    Value<String>? childId,
    Value<String>? dataJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LearnedProfilesCompanion(
      childId: childId ?? this.childId,
      dataJson: dataJson ?? this.dataJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnedProfilesCompanion(')
          ..write('childId: $childId, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorldsTable extends Worlds with TableInfo<$WorldsTable, WorldRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _premiseMeta = const VerificationMeta(
    'premise',
  );
  @override
  late final GeneratedColumn<String> premise = GeneratedColumn<String>(
    'premise',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<StoryTheme, int> theme =
      GeneratedColumn<int>(
        'theme',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<StoryTheme>($WorldsTable.$convertertheme);
  static const VerificationMeta _extraThemesMeta = const VerificationMeta(
    'extraThemes',
  );
  @override
  late final GeneratedColumn<String> extraThemes = GeneratedColumn<String>(
    'extra_themes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _voiceNameMeta = const VerificationMeta(
    'voiceName',
  );
  @override
  late final GeneratedColumn<String> voiceName = GeneratedColumn<String>(
    'voice_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _castChangesMeta = const VerificationMeta(
    'castChanges',
  );
  @override
  late final GeneratedColumn<String> castChanges = GeneratedColumn<String>(
    'cast_changes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    name,
    premise,
    theme,
    extraThemes,
    voiceName,
    castChanges,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worlds';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorldRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('premise')) {
      context.handle(
        _premiseMeta,
        premise.isAcceptableOrUnknown(data['premise']!, _premiseMeta),
      );
    }
    if (data.containsKey('extra_themes')) {
      context.handle(
        _extraThemesMeta,
        extraThemes.isAcceptableOrUnknown(
          data['extra_themes']!,
          _extraThemesMeta,
        ),
      );
    }
    if (data.containsKey('voice_name')) {
      context.handle(
        _voiceNameMeta,
        voiceName.isAcceptableOrUnknown(data['voice_name']!, _voiceNameMeta),
      );
    }
    if (data.containsKey('cast_changes')) {
      context.handle(
        _castChangesMeta,
        castChanges.isAcceptableOrUnknown(
          data['cast_changes']!,
          _castChangesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorldRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorldRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      premise: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}premise'],
      )!,
      theme: $WorldsTable.$convertertheme.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}theme'],
        )!,
      ),
      extraThemes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_themes'],
      )!,
      voiceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_name'],
      )!,
      castChanges: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_changes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorldsTable createAlias(String alias) {
    return $WorldsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StoryTheme, int, int> $convertertheme =
      const EnumIndexConverter<StoryTheme>(StoryTheme.values);
}

class WorldRow extends DataClass implements Insertable<WorldRow> {
  final String id;
  final String childId;
  final String name;
  final String premise;
  final StoryTheme theme;

  /// Up to two extra themes blended with [theme], as comma-separated enum names.
  final String extraThemes;

  /// The voice that tells every story in this world; empty means the parent's
  /// setting. Only the voice name, never the engine — see World.voiceName.
  final String voiceName;

  /// Cast edits (arrivals/departures) the next story must acknowledge, as JSON.
  final String castChanges;
  final DateTime createdAt;
  const WorldRow({
    required this.id,
    required this.childId,
    required this.name,
    required this.premise,
    required this.theme,
    required this.extraThemes,
    required this.voiceName,
    required this.castChanges,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    map['name'] = Variable<String>(name);
    map['premise'] = Variable<String>(premise);
    {
      map['theme'] = Variable<int>($WorldsTable.$convertertheme.toSql(theme));
    }
    map['extra_themes'] = Variable<String>(extraThemes);
    map['voice_name'] = Variable<String>(voiceName);
    map['cast_changes'] = Variable<String>(castChanges);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorldsCompanion toCompanion(bool nullToAbsent) {
    return WorldsCompanion(
      id: Value(id),
      childId: Value(childId),
      name: Value(name),
      premise: Value(premise),
      theme: Value(theme),
      extraThemes: Value(extraThemes),
      voiceName: Value(voiceName),
      castChanges: Value(castChanges),
      createdAt: Value(createdAt),
    );
  }

  factory WorldRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorldRow(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      name: serializer.fromJson<String>(json['name']),
      premise: serializer.fromJson<String>(json['premise']),
      theme: $WorldsTable.$convertertheme.fromJson(
        serializer.fromJson<int>(json['theme']),
      ),
      extraThemes: serializer.fromJson<String>(json['extraThemes']),
      voiceName: serializer.fromJson<String>(json['voiceName']),
      castChanges: serializer.fromJson<String>(json['castChanges']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'name': serializer.toJson<String>(name),
      'premise': serializer.toJson<String>(premise),
      'theme': serializer.toJson<int>(
        $WorldsTable.$convertertheme.toJson(theme),
      ),
      'extraThemes': serializer.toJson<String>(extraThemes),
      'voiceName': serializer.toJson<String>(voiceName),
      'castChanges': serializer.toJson<String>(castChanges),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorldRow copyWith({
    String? id,
    String? childId,
    String? name,
    String? premise,
    StoryTheme? theme,
    String? extraThemes,
    String? voiceName,
    String? castChanges,
    DateTime? createdAt,
  }) => WorldRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    name: name ?? this.name,
    premise: premise ?? this.premise,
    theme: theme ?? this.theme,
    extraThemes: extraThemes ?? this.extraThemes,
    voiceName: voiceName ?? this.voiceName,
    castChanges: castChanges ?? this.castChanges,
    createdAt: createdAt ?? this.createdAt,
  );
  WorldRow copyWithCompanion(WorldsCompanion data) {
    return WorldRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      name: data.name.present ? data.name.value : this.name,
      premise: data.premise.present ? data.premise.value : this.premise,
      theme: data.theme.present ? data.theme.value : this.theme,
      extraThemes: data.extraThemes.present
          ? data.extraThemes.value
          : this.extraThemes,
      voiceName: data.voiceName.present ? data.voiceName.value : this.voiceName,
      castChanges: data.castChanges.present
          ? data.castChanges.value
          : this.castChanges,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorldRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('name: $name, ')
          ..write('premise: $premise, ')
          ..write('theme: $theme, ')
          ..write('extraThemes: $extraThemes, ')
          ..write('voiceName: $voiceName, ')
          ..write('castChanges: $castChanges, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    childId,
    name,
    premise,
    theme,
    extraThemes,
    voiceName,
    castChanges,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorldRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.name == this.name &&
          other.premise == this.premise &&
          other.theme == this.theme &&
          other.extraThemes == this.extraThemes &&
          other.voiceName == this.voiceName &&
          other.castChanges == this.castChanges &&
          other.createdAt == this.createdAt);
}

class WorldsCompanion extends UpdateCompanion<WorldRow> {
  final Value<String> id;
  final Value<String> childId;
  final Value<String> name;
  final Value<String> premise;
  final Value<StoryTheme> theme;
  final Value<String> extraThemes;
  final Value<String> voiceName;
  final Value<String> castChanges;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorldsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.name = const Value.absent(),
    this.premise = const Value.absent(),
    this.theme = const Value.absent(),
    this.extraThemes = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.castChanges = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorldsCompanion.insert({
    required String id,
    required String childId,
    required String name,
    this.premise = const Value.absent(),
    required StoryTheme theme,
    this.extraThemes = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.castChanges = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       name = Value(name),
       theme = Value(theme);
  static Insertable<WorldRow> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<String>? name,
    Expression<String>? premise,
    Expression<int>? theme,
    Expression<String>? extraThemes,
    Expression<String>? voiceName,
    Expression<String>? castChanges,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (name != null) 'name': name,
      if (premise != null) 'premise': premise,
      if (theme != null) 'theme': theme,
      if (extraThemes != null) 'extra_themes': extraThemes,
      if (voiceName != null) 'voice_name': voiceName,
      if (castChanges != null) 'cast_changes': castChanges,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorldsCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<String>? name,
    Value<String>? premise,
    Value<StoryTheme>? theme,
    Value<String>? extraThemes,
    Value<String>? voiceName,
    Value<String>? castChanges,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorldsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      name: name ?? this.name,
      premise: premise ?? this.premise,
      theme: theme ?? this.theme,
      extraThemes: extraThemes ?? this.extraThemes,
      voiceName: voiceName ?? this.voiceName,
      castChanges: castChanges ?? this.castChanges,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (premise.present) {
      map['premise'] = Variable<String>(premise.value);
    }
    if (theme.present) {
      map['theme'] = Variable<int>(
        $WorldsTable.$convertertheme.toSql(theme.value),
      );
    }
    if (extraThemes.present) {
      map['extra_themes'] = Variable<String>(extraThemes.value);
    }
    if (voiceName.present) {
      map['voice_name'] = Variable<String>(voiceName.value);
    }
    if (castChanges.present) {
      map['cast_changes'] = Variable<String>(castChanges.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorldsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('name: $name, ')
          ..write('premise: $premise, ')
          ..write('theme: $theme, ')
          ..write('extraThemes: $extraThemes, ')
          ..write('voiceName: $voiceName, ')
          ..write('castChanges: $castChanges, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoryCharactersTable extends StoryCharacters
    with TableInfo<$StoryCharactersTable, CharacterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryCharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worldIdMeta = const VerificationMeta(
    'worldId',
  );
  @override
  late final GeneratedColumn<String> worldId = GeneratedColumn<String>(
    'world_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES worlds (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    worldId,
    name,
    description,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('world_id')) {
      context.handle(
        _worldIdMeta,
        worldId.isAcceptableOrUnknown(data['world_id']!, _worldIdMeta),
      );
    } else if (isInserting) {
      context.missing(_worldIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CharacterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      worldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}world_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StoryCharactersTable createAlias(String alias) {
    return $StoryCharactersTable(attachedDatabase, alias);
  }
}

class CharacterRow extends DataClass implements Insertable<CharacterRow> {
  final String id;
  final String worldId;
  final String name;
  final String description;
  final DateTime createdAt;
  const CharacterRow({
    required this.id,
    required this.worldId,
    required this.name,
    required this.description,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['world_id'] = Variable<String>(worldId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StoryCharactersCompanion toCompanion(bool nullToAbsent) {
    return StoryCharactersCompanion(
      id: Value(id),
      worldId: Value(worldId),
      name: Value(name),
      description: Value(description),
      createdAt: Value(createdAt),
    );
  }

  factory CharacterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterRow(
      id: serializer.fromJson<String>(json['id']),
      worldId: serializer.fromJson<String>(json['worldId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'worldId': serializer.toJson<String>(worldId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CharacterRow copyWith({
    String? id,
    String? worldId,
    String? name,
    String? description,
    DateTime? createdAt,
  }) => CharacterRow(
    id: id ?? this.id,
    worldId: worldId ?? this.worldId,
    name: name ?? this.name,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  CharacterRow copyWithCompanion(StoryCharactersCompanion data) {
    return CharacterRow(
      id: data.id.present ? data.id.value : this.id,
      worldId: data.worldId.present ? data.worldId.value : this.worldId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterRow(')
          ..write('id: $id, ')
          ..write('worldId: $worldId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, worldId, name, description, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterRow &&
          other.id == this.id &&
          other.worldId == this.worldId &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt);
}

class StoryCharactersCompanion extends UpdateCompanion<CharacterRow> {
  final Value<String> id;
  final Value<String> worldId;
  final Value<String> name;
  final Value<String> description;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StoryCharactersCompanion({
    this.id = const Value.absent(),
    this.worldId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoryCharactersCompanion.insert({
    required String id,
    required String worldId,
    required String name,
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       worldId = Value(worldId),
       name = Value(name);
  static Insertable<CharacterRow> custom({
    Expression<String>? id,
    Expression<String>? worldId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (worldId != null) 'world_id': worldId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoryCharactersCompanion copyWith({
    Value<String>? id,
    Value<String>? worldId,
    Value<String>? name,
    Value<String>? description,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StoryCharactersCompanion(
      id: id ?? this.id,
      worldId: worldId ?? this.worldId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (worldId.present) {
      map['world_id'] = Variable<String>(worldId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryCharactersCompanion(')
          ..write('id: $id, ')
          ..write('worldId: $worldId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesTableTable extends SeriesTable
    with TableInfo<$SeriesTableTable, SeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _worldIdMeta = const VerificationMeta(
    'worldId',
  );
  @override
  late final GeneratedColumn<String> worldId = GeneratedColumn<String>(
    'world_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES worlds (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StoryTheme, int> theme =
      GeneratedColumn<int>(
        'theme',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<StoryTheme>($SeriesTableTable.$convertertheme);
  static const VerificationMeta _extraThemesMeta = const VerificationMeta(
    'extraThemes',
  );
  @override
  late final GeneratedColumn<String> extraThemes = GeneratedColumn<String>(
    'extra_themes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _autoTitleMeta = const VerificationMeta(
    'autoTitle',
  );
  @override
  late final GeneratedColumn<bool> autoTitle = GeneratedColumn<bool>(
    'auto_title',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_title" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _customThemeMeta = const VerificationMeta(
    'customTheme',
  );
  @override
  late final GeneratedColumn<String> customTheme = GeneratedColumn<String>(
    'custom_theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<HeroMode, int> heroMode =
      GeneratedColumn<int>(
        'hero_mode',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<HeroMode>($SeriesTableTable.$converterheroMode);
  static const VerificationMeta _heroNameMeta = const VerificationMeta(
    'heroName',
  );
  @override
  late final GeneratedColumn<String> heroName = GeneratedColumn<String>(
    'hero_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bilingualEnabledMeta = const VerificationMeta(
    'bilingualEnabled',
  );
  @override
  late final GeneratedColumn<bool> bilingualEnabled = GeneratedColumn<bool>(
    'bilingual_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bilingual_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _secondaryLanguageMeta = const VerificationMeta(
    'secondaryLanguage',
  );
  @override
  late final GeneratedColumn<String> secondaryLanguage =
      GeneratedColumn<String>(
        'secondary_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<BilingualBlend?, int>
  bilingualBlend = GeneratedColumn<int>(
    'bilingual_blend',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<BilingualBlend?>($SeriesTableTable.$converterbilingualBlendn);
  static const VerificationMeta _seedSummaryMeta = const VerificationMeta(
    'seedSummary',
  );
  @override
  late final GeneratedColumn<String> seedSummary = GeneratedColumn<String>(
    'seed_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _storyBibleMeta = const VerificationMeta(
    'storyBible',
  );
  @override
  late final GeneratedColumn<String> storyBible = GeneratedColumn<String>(
    'story_bible',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _branchedFromBeatIdMeta =
      const VerificationMeta('branchedFromBeatId');
  @override
  late final GeneratedColumn<String> branchedFromBeatId =
      GeneratedColumn<String>(
        'branched_from_beat_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<SeriesStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SeriesStatus>($SeriesTableTable.$converterstatus);
  static const VerificationMeta _baseLanguageMeta = const VerificationMeta(
    'baseLanguage',
  );
  @override
  late final GeneratedColumn<String> baseLanguage = GeneratedColumn<String>(
    'base_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadSeqMeta = const VerificationMeta(
    'lastReadSeq',
  );
  @override
  late final GeneratedColumn<int> lastReadSeq = GeneratedColumn<int>(
    'last_read_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    worldId,
    title,
    theme,
    extraThemes,
    autoTitle,
    customTheme,
    heroMode,
    heroName,
    bilingualEnabled,
    secondaryLanguage,
    bilingualBlend,
    seedSummary,
    storyBible,
    branchedFromBeatId,
    status,
    baseLanguage,
    lastReadSeq,
    lastReadAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('world_id')) {
      context.handle(
        _worldIdMeta,
        worldId.isAcceptableOrUnknown(data['world_id']!, _worldIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('extra_themes')) {
      context.handle(
        _extraThemesMeta,
        extraThemes.isAcceptableOrUnknown(
          data['extra_themes']!,
          _extraThemesMeta,
        ),
      );
    }
    if (data.containsKey('auto_title')) {
      context.handle(
        _autoTitleMeta,
        autoTitle.isAcceptableOrUnknown(data['auto_title']!, _autoTitleMeta),
      );
    }
    if (data.containsKey('custom_theme')) {
      context.handle(
        _customThemeMeta,
        customTheme.isAcceptableOrUnknown(
          data['custom_theme']!,
          _customThemeMeta,
        ),
      );
    }
    if (data.containsKey('hero_name')) {
      context.handle(
        _heroNameMeta,
        heroName.isAcceptableOrUnknown(data['hero_name']!, _heroNameMeta),
      );
    }
    if (data.containsKey('bilingual_enabled')) {
      context.handle(
        _bilingualEnabledMeta,
        bilingualEnabled.isAcceptableOrUnknown(
          data['bilingual_enabled']!,
          _bilingualEnabledMeta,
        ),
      );
    }
    if (data.containsKey('secondary_language')) {
      context.handle(
        _secondaryLanguageMeta,
        secondaryLanguage.isAcceptableOrUnknown(
          data['secondary_language']!,
          _secondaryLanguageMeta,
        ),
      );
    }
    if (data.containsKey('seed_summary')) {
      context.handle(
        _seedSummaryMeta,
        seedSummary.isAcceptableOrUnknown(
          data['seed_summary']!,
          _seedSummaryMeta,
        ),
      );
    }
    if (data.containsKey('story_bible')) {
      context.handle(
        _storyBibleMeta,
        storyBible.isAcceptableOrUnknown(data['story_bible']!, _storyBibleMeta),
      );
    }
    if (data.containsKey('branched_from_beat_id')) {
      context.handle(
        _branchedFromBeatIdMeta,
        branchedFromBeatId.isAcceptableOrUnknown(
          data['branched_from_beat_id']!,
          _branchedFromBeatIdMeta,
        ),
      );
    }
    if (data.containsKey('base_language')) {
      context.handle(
        _baseLanguageMeta,
        baseLanguage.isAcceptableOrUnknown(
          data['base_language']!,
          _baseLanguageMeta,
        ),
      );
    }
    if (data.containsKey('last_read_seq')) {
      context.handle(
        _lastReadSeqMeta,
        lastReadSeq.isAcceptableOrUnknown(
          data['last_read_seq']!,
          _lastReadSeqMeta,
        ),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      worldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}world_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      theme: $SeriesTableTable.$convertertheme.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}theme'],
        )!,
      ),
      extraThemes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_themes'],
      )!,
      autoTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_title'],
      )!,
      customTheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_theme'],
      ),
      heroMode: $SeriesTableTable.$converterheroMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}hero_mode'],
        )!,
      ),
      heroName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hero_name'],
      ),
      bilingualEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bilingual_enabled'],
      )!,
      secondaryLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_language'],
      ),
      bilingualBlend: $SeriesTableTable.$converterbilingualBlendn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}bilingual_blend'],
        ),
      ),
      seedSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_summary'],
      )!,
      storyBible: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story_bible'],
      )!,
      branchedFromBeatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branched_from_beat_id'],
      ),
      status: $SeriesTableTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      baseLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_language'],
      ),
      lastReadSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_seq'],
      ),
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SeriesTableTable createAlias(String alias) {
    return $SeriesTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StoryTheme, int, int> $convertertheme =
      const EnumIndexConverter<StoryTheme>(StoryTheme.values);
  static JsonTypeConverter2<HeroMode, int, int> $converterheroMode =
      const EnumIndexConverter<HeroMode>(HeroMode.values);
  static JsonTypeConverter2<BilingualBlend, int, int> $converterbilingualBlend =
      const EnumIndexConverter<BilingualBlend>(BilingualBlend.values);
  static JsonTypeConverter2<BilingualBlend?, int?, int?>
  $converterbilingualBlendn = JsonTypeConverter2.asNullable(
    $converterbilingualBlend,
  );
  static JsonTypeConverter2<SeriesStatus, int, int> $converterstatus =
      const EnumIndexConverter<SeriesStatus>(SeriesStatus.values);
}

class SeriesRow extends DataClass implements Insertable<SeriesRow> {
  final String id;
  final String childId;
  final String? worldId;
  final String title;
  final StoryTheme theme;

  /// Up to two extra themes blended with [theme], as comma-separated enum names.
  final String extraThemes;

  /// True while [title] is a placeholder awaiting a model-suggested title.
  final bool autoTitle;
  final String? customTheme;
  final HeroMode heroMode;
  final String? heroName;
  final bool bilingualEnabled;
  final String? secondaryLanguage;
  final BilingualBlend? bilingualBlend;
  final String seedSummary;
  final String storyBible;
  final String? branchedFromBeatId;
  final SeriesStatus status;

  /// The language this story is told in, overriding the child's own. Null
  /// means "whatever the child is set to" — the case for every story written
  /// before a bilingual household needed two.
  final String? baseLanguage;

  /// Reading position: the chapter last opened and when, so the bookshelf can
  /// offer "Continue — Chapter 4".
  final int? lastReadSeq;
  final DateTime? lastReadAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SeriesRow({
    required this.id,
    required this.childId,
    this.worldId,
    required this.title,
    required this.theme,
    required this.extraThemes,
    required this.autoTitle,
    this.customTheme,
    required this.heroMode,
    this.heroName,
    required this.bilingualEnabled,
    this.secondaryLanguage,
    this.bilingualBlend,
    required this.seedSummary,
    required this.storyBible,
    this.branchedFromBeatId,
    required this.status,
    this.baseLanguage,
    this.lastReadSeq,
    this.lastReadAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    if (!nullToAbsent || worldId != null) {
      map['world_id'] = Variable<String>(worldId);
    }
    map['title'] = Variable<String>(title);
    {
      map['theme'] = Variable<int>(
        $SeriesTableTable.$convertertheme.toSql(theme),
      );
    }
    map['extra_themes'] = Variable<String>(extraThemes);
    map['auto_title'] = Variable<bool>(autoTitle);
    if (!nullToAbsent || customTheme != null) {
      map['custom_theme'] = Variable<String>(customTheme);
    }
    {
      map['hero_mode'] = Variable<int>(
        $SeriesTableTable.$converterheroMode.toSql(heroMode),
      );
    }
    if (!nullToAbsent || heroName != null) {
      map['hero_name'] = Variable<String>(heroName);
    }
    map['bilingual_enabled'] = Variable<bool>(bilingualEnabled);
    if (!nullToAbsent || secondaryLanguage != null) {
      map['secondary_language'] = Variable<String>(secondaryLanguage);
    }
    if (!nullToAbsent || bilingualBlend != null) {
      map['bilingual_blend'] = Variable<int>(
        $SeriesTableTable.$converterbilingualBlendn.toSql(bilingualBlend),
      );
    }
    map['seed_summary'] = Variable<String>(seedSummary);
    map['story_bible'] = Variable<String>(storyBible);
    if (!nullToAbsent || branchedFromBeatId != null) {
      map['branched_from_beat_id'] = Variable<String>(branchedFromBeatId);
    }
    {
      map['status'] = Variable<int>(
        $SeriesTableTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || baseLanguage != null) {
      map['base_language'] = Variable<String>(baseLanguage);
    }
    if (!nullToAbsent || lastReadSeq != null) {
      map['last_read_seq'] = Variable<int>(lastReadSeq);
    }
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SeriesTableCompanion toCompanion(bool nullToAbsent) {
    return SeriesTableCompanion(
      id: Value(id),
      childId: Value(childId),
      worldId: worldId == null && nullToAbsent
          ? const Value.absent()
          : Value(worldId),
      title: Value(title),
      theme: Value(theme),
      extraThemes: Value(extraThemes),
      autoTitle: Value(autoTitle),
      customTheme: customTheme == null && nullToAbsent
          ? const Value.absent()
          : Value(customTheme),
      heroMode: Value(heroMode),
      heroName: heroName == null && nullToAbsent
          ? const Value.absent()
          : Value(heroName),
      bilingualEnabled: Value(bilingualEnabled),
      secondaryLanguage: secondaryLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryLanguage),
      bilingualBlend: bilingualBlend == null && nullToAbsent
          ? const Value.absent()
          : Value(bilingualBlend),
      seedSummary: Value(seedSummary),
      storyBible: Value(storyBible),
      branchedFromBeatId: branchedFromBeatId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchedFromBeatId),
      status: Value(status),
      baseLanguage: baseLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(baseLanguage),
      lastReadSeq: lastReadSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadSeq),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRow(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      worldId: serializer.fromJson<String?>(json['worldId']),
      title: serializer.fromJson<String>(json['title']),
      theme: $SeriesTableTable.$convertertheme.fromJson(
        serializer.fromJson<int>(json['theme']),
      ),
      extraThemes: serializer.fromJson<String>(json['extraThemes']),
      autoTitle: serializer.fromJson<bool>(json['autoTitle']),
      customTheme: serializer.fromJson<String?>(json['customTheme']),
      heroMode: $SeriesTableTable.$converterheroMode.fromJson(
        serializer.fromJson<int>(json['heroMode']),
      ),
      heroName: serializer.fromJson<String?>(json['heroName']),
      bilingualEnabled: serializer.fromJson<bool>(json['bilingualEnabled']),
      secondaryLanguage: serializer.fromJson<String?>(
        json['secondaryLanguage'],
      ),
      bilingualBlend: $SeriesTableTable.$converterbilingualBlendn.fromJson(
        serializer.fromJson<int?>(json['bilingualBlend']),
      ),
      seedSummary: serializer.fromJson<String>(json['seedSummary']),
      storyBible: serializer.fromJson<String>(json['storyBible']),
      branchedFromBeatId: serializer.fromJson<String?>(
        json['branchedFromBeatId'],
      ),
      status: $SeriesTableTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      baseLanguage: serializer.fromJson<String?>(json['baseLanguage']),
      lastReadSeq: serializer.fromJson<int?>(json['lastReadSeq']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'worldId': serializer.toJson<String?>(worldId),
      'title': serializer.toJson<String>(title),
      'theme': serializer.toJson<int>(
        $SeriesTableTable.$convertertheme.toJson(theme),
      ),
      'extraThemes': serializer.toJson<String>(extraThemes),
      'autoTitle': serializer.toJson<bool>(autoTitle),
      'customTheme': serializer.toJson<String?>(customTheme),
      'heroMode': serializer.toJson<int>(
        $SeriesTableTable.$converterheroMode.toJson(heroMode),
      ),
      'heroName': serializer.toJson<String?>(heroName),
      'bilingualEnabled': serializer.toJson<bool>(bilingualEnabled),
      'secondaryLanguage': serializer.toJson<String?>(secondaryLanguage),
      'bilingualBlend': serializer.toJson<int?>(
        $SeriesTableTable.$converterbilingualBlendn.toJson(bilingualBlend),
      ),
      'seedSummary': serializer.toJson<String>(seedSummary),
      'storyBible': serializer.toJson<String>(storyBible),
      'branchedFromBeatId': serializer.toJson<String?>(branchedFromBeatId),
      'status': serializer.toJson<int>(
        $SeriesTableTable.$converterstatus.toJson(status),
      ),
      'baseLanguage': serializer.toJson<String?>(baseLanguage),
      'lastReadSeq': serializer.toJson<int?>(lastReadSeq),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SeriesRow copyWith({
    String? id,
    String? childId,
    Value<String?> worldId = const Value.absent(),
    String? title,
    StoryTheme? theme,
    String? extraThemes,
    bool? autoTitle,
    Value<String?> customTheme = const Value.absent(),
    HeroMode? heroMode,
    Value<String?> heroName = const Value.absent(),
    bool? bilingualEnabled,
    Value<String?> secondaryLanguage = const Value.absent(),
    Value<BilingualBlend?> bilingualBlend = const Value.absent(),
    String? seedSummary,
    String? storyBible,
    Value<String?> branchedFromBeatId = const Value.absent(),
    SeriesStatus? status,
    Value<String?> baseLanguage = const Value.absent(),
    Value<int?> lastReadSeq = const Value.absent(),
    Value<DateTime?> lastReadAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SeriesRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    worldId: worldId.present ? worldId.value : this.worldId,
    title: title ?? this.title,
    theme: theme ?? this.theme,
    extraThemes: extraThemes ?? this.extraThemes,
    autoTitle: autoTitle ?? this.autoTitle,
    customTheme: customTheme.present ? customTheme.value : this.customTheme,
    heroMode: heroMode ?? this.heroMode,
    heroName: heroName.present ? heroName.value : this.heroName,
    bilingualEnabled: bilingualEnabled ?? this.bilingualEnabled,
    secondaryLanguage: secondaryLanguage.present
        ? secondaryLanguage.value
        : this.secondaryLanguage,
    bilingualBlend: bilingualBlend.present
        ? bilingualBlend.value
        : this.bilingualBlend,
    seedSummary: seedSummary ?? this.seedSummary,
    storyBible: storyBible ?? this.storyBible,
    branchedFromBeatId: branchedFromBeatId.present
        ? branchedFromBeatId.value
        : this.branchedFromBeatId,
    status: status ?? this.status,
    baseLanguage: baseLanguage.present ? baseLanguage.value : this.baseLanguage,
    lastReadSeq: lastReadSeq.present ? lastReadSeq.value : this.lastReadSeq,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SeriesRow copyWithCompanion(SeriesTableCompanion data) {
    return SeriesRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      worldId: data.worldId.present ? data.worldId.value : this.worldId,
      title: data.title.present ? data.title.value : this.title,
      theme: data.theme.present ? data.theme.value : this.theme,
      extraThemes: data.extraThemes.present
          ? data.extraThemes.value
          : this.extraThemes,
      autoTitle: data.autoTitle.present ? data.autoTitle.value : this.autoTitle,
      customTheme: data.customTheme.present
          ? data.customTheme.value
          : this.customTheme,
      heroMode: data.heroMode.present ? data.heroMode.value : this.heroMode,
      heroName: data.heroName.present ? data.heroName.value : this.heroName,
      bilingualEnabled: data.bilingualEnabled.present
          ? data.bilingualEnabled.value
          : this.bilingualEnabled,
      secondaryLanguage: data.secondaryLanguage.present
          ? data.secondaryLanguage.value
          : this.secondaryLanguage,
      bilingualBlend: data.bilingualBlend.present
          ? data.bilingualBlend.value
          : this.bilingualBlend,
      seedSummary: data.seedSummary.present
          ? data.seedSummary.value
          : this.seedSummary,
      storyBible: data.storyBible.present
          ? data.storyBible.value
          : this.storyBible,
      branchedFromBeatId: data.branchedFromBeatId.present
          ? data.branchedFromBeatId.value
          : this.branchedFromBeatId,
      status: data.status.present ? data.status.value : this.status,
      baseLanguage: data.baseLanguage.present
          ? data.baseLanguage.value
          : this.baseLanguage,
      lastReadSeq: data.lastReadSeq.present
          ? data.lastReadSeq.value
          : this.lastReadSeq,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('worldId: $worldId, ')
          ..write('title: $title, ')
          ..write('theme: $theme, ')
          ..write('extraThemes: $extraThemes, ')
          ..write('autoTitle: $autoTitle, ')
          ..write('customTheme: $customTheme, ')
          ..write('heroMode: $heroMode, ')
          ..write('heroName: $heroName, ')
          ..write('bilingualEnabled: $bilingualEnabled, ')
          ..write('secondaryLanguage: $secondaryLanguage, ')
          ..write('bilingualBlend: $bilingualBlend, ')
          ..write('seedSummary: $seedSummary, ')
          ..write('storyBible: $storyBible, ')
          ..write('branchedFromBeatId: $branchedFromBeatId, ')
          ..write('status: $status, ')
          ..write('baseLanguage: $baseLanguage, ')
          ..write('lastReadSeq: $lastReadSeq, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    childId,
    worldId,
    title,
    theme,
    extraThemes,
    autoTitle,
    customTheme,
    heroMode,
    heroName,
    bilingualEnabled,
    secondaryLanguage,
    bilingualBlend,
    seedSummary,
    storyBible,
    branchedFromBeatId,
    status,
    baseLanguage,
    lastReadSeq,
    lastReadAt,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.worldId == this.worldId &&
          other.title == this.title &&
          other.theme == this.theme &&
          other.extraThemes == this.extraThemes &&
          other.autoTitle == this.autoTitle &&
          other.customTheme == this.customTheme &&
          other.heroMode == this.heroMode &&
          other.heroName == this.heroName &&
          other.bilingualEnabled == this.bilingualEnabled &&
          other.secondaryLanguage == this.secondaryLanguage &&
          other.bilingualBlend == this.bilingualBlend &&
          other.seedSummary == this.seedSummary &&
          other.storyBible == this.storyBible &&
          other.branchedFromBeatId == this.branchedFromBeatId &&
          other.status == this.status &&
          other.baseLanguage == this.baseLanguage &&
          other.lastReadSeq == this.lastReadSeq &&
          other.lastReadAt == this.lastReadAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SeriesTableCompanion extends UpdateCompanion<SeriesRow> {
  final Value<String> id;
  final Value<String> childId;
  final Value<String?> worldId;
  final Value<String> title;
  final Value<StoryTheme> theme;
  final Value<String> extraThemes;
  final Value<bool> autoTitle;
  final Value<String?> customTheme;
  final Value<HeroMode> heroMode;
  final Value<String?> heroName;
  final Value<bool> bilingualEnabled;
  final Value<String?> secondaryLanguage;
  final Value<BilingualBlend?> bilingualBlend;
  final Value<String> seedSummary;
  final Value<String> storyBible;
  final Value<String?> branchedFromBeatId;
  final Value<SeriesStatus> status;
  final Value<String?> baseLanguage;
  final Value<int?> lastReadSeq;
  final Value<DateTime?> lastReadAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SeriesTableCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.worldId = const Value.absent(),
    this.title = const Value.absent(),
    this.theme = const Value.absent(),
    this.extraThemes = const Value.absent(),
    this.autoTitle = const Value.absent(),
    this.customTheme = const Value.absent(),
    this.heroMode = const Value.absent(),
    this.heroName = const Value.absent(),
    this.bilingualEnabled = const Value.absent(),
    this.secondaryLanguage = const Value.absent(),
    this.bilingualBlend = const Value.absent(),
    this.seedSummary = const Value.absent(),
    this.storyBible = const Value.absent(),
    this.branchedFromBeatId = const Value.absent(),
    this.status = const Value.absent(),
    this.baseLanguage = const Value.absent(),
    this.lastReadSeq = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesTableCompanion.insert({
    required String id,
    required String childId,
    this.worldId = const Value.absent(),
    required String title,
    required StoryTheme theme,
    this.extraThemes = const Value.absent(),
    this.autoTitle = const Value.absent(),
    this.customTheme = const Value.absent(),
    required HeroMode heroMode,
    this.heroName = const Value.absent(),
    this.bilingualEnabled = const Value.absent(),
    this.secondaryLanguage = const Value.absent(),
    this.bilingualBlend = const Value.absent(),
    this.seedSummary = const Value.absent(),
    this.storyBible = const Value.absent(),
    this.branchedFromBeatId = const Value.absent(),
    required SeriesStatus status,
    this.baseLanguage = const Value.absent(),
    this.lastReadSeq = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       title = Value(title),
       theme = Value(theme),
       heroMode = Value(heroMode),
       status = Value(status);
  static Insertable<SeriesRow> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<String>? worldId,
    Expression<String>? title,
    Expression<int>? theme,
    Expression<String>? extraThemes,
    Expression<bool>? autoTitle,
    Expression<String>? customTheme,
    Expression<int>? heroMode,
    Expression<String>? heroName,
    Expression<bool>? bilingualEnabled,
    Expression<String>? secondaryLanguage,
    Expression<int>? bilingualBlend,
    Expression<String>? seedSummary,
    Expression<String>? storyBible,
    Expression<String>? branchedFromBeatId,
    Expression<int>? status,
    Expression<String>? baseLanguage,
    Expression<int>? lastReadSeq,
    Expression<DateTime>? lastReadAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (worldId != null) 'world_id': worldId,
      if (title != null) 'title': title,
      if (theme != null) 'theme': theme,
      if (extraThemes != null) 'extra_themes': extraThemes,
      if (autoTitle != null) 'auto_title': autoTitle,
      if (customTheme != null) 'custom_theme': customTheme,
      if (heroMode != null) 'hero_mode': heroMode,
      if (heroName != null) 'hero_name': heroName,
      if (bilingualEnabled != null) 'bilingual_enabled': bilingualEnabled,
      if (secondaryLanguage != null) 'secondary_language': secondaryLanguage,
      if (bilingualBlend != null) 'bilingual_blend': bilingualBlend,
      if (seedSummary != null) 'seed_summary': seedSummary,
      if (storyBible != null) 'story_bible': storyBible,
      if (branchedFromBeatId != null)
        'branched_from_beat_id': branchedFromBeatId,
      if (status != null) 'status': status,
      if (baseLanguage != null) 'base_language': baseLanguage,
      if (lastReadSeq != null) 'last_read_seq': lastReadSeq,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<String?>? worldId,
    Value<String>? title,
    Value<StoryTheme>? theme,
    Value<String>? extraThemes,
    Value<bool>? autoTitle,
    Value<String?>? customTheme,
    Value<HeroMode>? heroMode,
    Value<String?>? heroName,
    Value<bool>? bilingualEnabled,
    Value<String?>? secondaryLanguage,
    Value<BilingualBlend?>? bilingualBlend,
    Value<String>? seedSummary,
    Value<String>? storyBible,
    Value<String?>? branchedFromBeatId,
    Value<SeriesStatus>? status,
    Value<String?>? baseLanguage,
    Value<int?>? lastReadSeq,
    Value<DateTime?>? lastReadAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SeriesTableCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      worldId: worldId ?? this.worldId,
      title: title ?? this.title,
      theme: theme ?? this.theme,
      extraThemes: extraThemes ?? this.extraThemes,
      autoTitle: autoTitle ?? this.autoTitle,
      customTheme: customTheme ?? this.customTheme,
      heroMode: heroMode ?? this.heroMode,
      heroName: heroName ?? this.heroName,
      bilingualEnabled: bilingualEnabled ?? this.bilingualEnabled,
      secondaryLanguage: secondaryLanguage ?? this.secondaryLanguage,
      bilingualBlend: bilingualBlend ?? this.bilingualBlend,
      seedSummary: seedSummary ?? this.seedSummary,
      storyBible: storyBible ?? this.storyBible,
      branchedFromBeatId: branchedFromBeatId ?? this.branchedFromBeatId,
      status: status ?? this.status,
      baseLanguage: baseLanguage ?? this.baseLanguage,
      lastReadSeq: lastReadSeq ?? this.lastReadSeq,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (worldId.present) {
      map['world_id'] = Variable<String>(worldId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (theme.present) {
      map['theme'] = Variable<int>(
        $SeriesTableTable.$convertertheme.toSql(theme.value),
      );
    }
    if (extraThemes.present) {
      map['extra_themes'] = Variable<String>(extraThemes.value);
    }
    if (autoTitle.present) {
      map['auto_title'] = Variable<bool>(autoTitle.value);
    }
    if (customTheme.present) {
      map['custom_theme'] = Variable<String>(customTheme.value);
    }
    if (heroMode.present) {
      map['hero_mode'] = Variable<int>(
        $SeriesTableTable.$converterheroMode.toSql(heroMode.value),
      );
    }
    if (heroName.present) {
      map['hero_name'] = Variable<String>(heroName.value);
    }
    if (bilingualEnabled.present) {
      map['bilingual_enabled'] = Variable<bool>(bilingualEnabled.value);
    }
    if (secondaryLanguage.present) {
      map['secondary_language'] = Variable<String>(secondaryLanguage.value);
    }
    if (bilingualBlend.present) {
      map['bilingual_blend'] = Variable<int>(
        $SeriesTableTable.$converterbilingualBlendn.toSql(bilingualBlend.value),
      );
    }
    if (seedSummary.present) {
      map['seed_summary'] = Variable<String>(seedSummary.value);
    }
    if (storyBible.present) {
      map['story_bible'] = Variable<String>(storyBible.value);
    }
    if (branchedFromBeatId.present) {
      map['branched_from_beat_id'] = Variable<String>(branchedFromBeatId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $SeriesTableTable.$converterstatus.toSql(status.value),
      );
    }
    if (baseLanguage.present) {
      map['base_language'] = Variable<String>(baseLanguage.value);
    }
    if (lastReadSeq.present) {
      map['last_read_seq'] = Variable<int>(lastReadSeq.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesTableCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('worldId: $worldId, ')
          ..write('title: $title, ')
          ..write('theme: $theme, ')
          ..write('extraThemes: $extraThemes, ')
          ..write('autoTitle: $autoTitle, ')
          ..write('customTheme: $customTheme, ')
          ..write('heroMode: $heroMode, ')
          ..write('heroName: $heroName, ')
          ..write('bilingualEnabled: $bilingualEnabled, ')
          ..write('secondaryLanguage: $secondaryLanguage, ')
          ..write('bilingualBlend: $bilingualBlend, ')
          ..write('seedSummary: $seedSummary, ')
          ..write('storyBible: $storyBible, ')
          ..write('branchedFromBeatId: $branchedFromBeatId, ')
          ..write('status: $status, ')
          ..write('baseLanguage: $baseLanguage, ')
          ..write('lastReadSeq: $lastReadSeq, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BeatsTable extends Beats with TableInfo<$BeatsTable, BeatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StoryIntent, int> intent =
      GeneratedColumn<int>(
        'intent',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<StoryIntent>($BeatsTable.$converterintent);
  static const VerificationMeta _chosenTwistMeta = const VerificationMeta(
    'chosenTwist',
  );
  @override
  late final GeneratedColumn<String> chosenTwist = GeneratedColumn<String>(
    'chosen_twist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storyTextMeta = const VerificationMeta(
    'storyText',
  );
  @override
  late final GeneratedColumn<String> storyText = GeneratedColumn<String>(
    'story_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _narrationJsonMeta = const VerificationMeta(
    'narrationJson',
  );
  @override
  late final GeneratedColumn<String> narrationJson = GeneratedColumn<String>(
    'narration_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AgeRating, int> rating =
      GeneratedColumn<int>(
        'rating',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<AgeRating>($BeatsTable.$converterrating);
  static const VerificationMeta _settingMeta = const VerificationMeta(
    'setting',
  );
  @override
  late final GeneratedColumn<String> setting = GeneratedColumn<String>(
    'setting',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> characters =
      GeneratedColumn<String>(
        'characters',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($BeatsTable.$convertercharacters);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  openThreads = GeneratedColumn<String>(
    'open_threads',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($BeatsTable.$converteropenThreads);
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _isFinalMeta = const VerificationMeta(
    'isFinal',
  );
  @override
  late final GeneratedColumn<bool> isFinal = GeneratedColumn<bool>(
    'is_final',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_final" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    seriesId,
    childId,
    seq,
    intent,
    chosenTwist,
    storyText,
    summary,
    chapterTitle,
    narrationJson,
    rating,
    setting,
    characters,
    openThreads,
    language,
    isFinal,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beats';
  @override
  VerificationContext validateIntegrity(
    Insertable<BeatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('chosen_twist')) {
      context.handle(
        _chosenTwistMeta,
        chosenTwist.isAcceptableOrUnknown(
          data['chosen_twist']!,
          _chosenTwistMeta,
        ),
      );
    }
    if (data.containsKey('story_text')) {
      context.handle(
        _storyTextMeta,
        storyText.isAcceptableOrUnknown(data['story_text']!, _storyTextMeta),
      );
    } else if (isInserting) {
      context.missing(_storyTextMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('narration_json')) {
      context.handle(
        _narrationJsonMeta,
        narrationJson.isAcceptableOrUnknown(
          data['narration_json']!,
          _narrationJsonMeta,
        ),
      );
    }
    if (data.containsKey('setting')) {
      context.handle(
        _settingMeta,
        setting.isAcceptableOrUnknown(data['setting']!, _settingMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('is_final')) {
      context.handle(
        _isFinalMeta,
        isFinal.isAcceptableOrUnknown(data['is_final']!, _isFinalMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BeatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BeatRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      intent: $BeatsTable.$converterintent.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}intent'],
        )!,
      ),
      chosenTwist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen_twist'],
      ),
      storyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story_text'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      )!,
      narrationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narration_json'],
      )!,
      rating: $BeatsTable.$converterrating.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}rating'],
        )!,
      ),
      setting: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting'],
      )!,
      characters: $BeatsTable.$convertercharacters.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}characters'],
        )!,
      ),
      openThreads: $BeatsTable.$converteropenThreads.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}open_threads'],
        )!,
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      isFinal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_final'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BeatsTable createAlias(String alias) {
    return $BeatsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StoryIntent, int, int> $converterintent =
      const EnumIndexConverter<StoryIntent>(StoryIntent.values);
  static JsonTypeConverter2<AgeRating, int, int> $converterrating =
      const EnumIndexConverter<AgeRating>(AgeRating.values);
  static TypeConverter<List<String>, String> $convertercharacters =
      const _StringListConverter();
  static TypeConverter<List<String>, String> $converteropenThreads =
      const _StringListConverter();
}

class BeatRow extends DataClass implements Insertable<BeatRow> {
  final String id;
  final String seriesId;
  final String childId;
  final int seq;
  final StoryIntent intent;
  final String? chosenTwist;
  final String storyText;
  final String summary;
  final String chapterTitle;

  /// Narration direction as JSON — see `NarrationNotes`. One blob rather than
  /// three columns: it is never queried, only handed to the voice.
  final String narrationJson;
  final AgeRating rating;
  final String setting;
  final List<String> characters;
  final List<String> openThreads;
  final String language;
  final bool isFinal;
  final DateTime createdAt;
  const BeatRow({
    required this.id,
    required this.seriesId,
    required this.childId,
    required this.seq,
    required this.intent,
    this.chosenTwist,
    required this.storyText,
    required this.summary,
    required this.chapterTitle,
    required this.narrationJson,
    required this.rating,
    required this.setting,
    required this.characters,
    required this.openThreads,
    required this.language,
    required this.isFinal,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['series_id'] = Variable<String>(seriesId);
    map['child_id'] = Variable<String>(childId);
    map['seq'] = Variable<int>(seq);
    {
      map['intent'] = Variable<int>($BeatsTable.$converterintent.toSql(intent));
    }
    if (!nullToAbsent || chosenTwist != null) {
      map['chosen_twist'] = Variable<String>(chosenTwist);
    }
    map['story_text'] = Variable<String>(storyText);
    map['summary'] = Variable<String>(summary);
    map['chapter_title'] = Variable<String>(chapterTitle);
    map['narration_json'] = Variable<String>(narrationJson);
    {
      map['rating'] = Variable<int>($BeatsTable.$converterrating.toSql(rating));
    }
    map['setting'] = Variable<String>(setting);
    {
      map['characters'] = Variable<String>(
        $BeatsTable.$convertercharacters.toSql(characters),
      );
    }
    {
      map['open_threads'] = Variable<String>(
        $BeatsTable.$converteropenThreads.toSql(openThreads),
      );
    }
    map['language'] = Variable<String>(language);
    map['is_final'] = Variable<bool>(isFinal);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BeatsCompanion toCompanion(bool nullToAbsent) {
    return BeatsCompanion(
      id: Value(id),
      seriesId: Value(seriesId),
      childId: Value(childId),
      seq: Value(seq),
      intent: Value(intent),
      chosenTwist: chosenTwist == null && nullToAbsent
          ? const Value.absent()
          : Value(chosenTwist),
      storyText: Value(storyText),
      summary: Value(summary),
      chapterTitle: Value(chapterTitle),
      narrationJson: Value(narrationJson),
      rating: Value(rating),
      setting: Value(setting),
      characters: Value(characters),
      openThreads: Value(openThreads),
      language: Value(language),
      isFinal: Value(isFinal),
      createdAt: Value(createdAt),
    );
  }

  factory BeatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BeatRow(
      id: serializer.fromJson<String>(json['id']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      childId: serializer.fromJson<String>(json['childId']),
      seq: serializer.fromJson<int>(json['seq']),
      intent: $BeatsTable.$converterintent.fromJson(
        serializer.fromJson<int>(json['intent']),
      ),
      chosenTwist: serializer.fromJson<String?>(json['chosenTwist']),
      storyText: serializer.fromJson<String>(json['storyText']),
      summary: serializer.fromJson<String>(json['summary']),
      chapterTitle: serializer.fromJson<String>(json['chapterTitle']),
      narrationJson: serializer.fromJson<String>(json['narrationJson']),
      rating: $BeatsTable.$converterrating.fromJson(
        serializer.fromJson<int>(json['rating']),
      ),
      setting: serializer.fromJson<String>(json['setting']),
      characters: serializer.fromJson<List<String>>(json['characters']),
      openThreads: serializer.fromJson<List<String>>(json['openThreads']),
      language: serializer.fromJson<String>(json['language']),
      isFinal: serializer.fromJson<bool>(json['isFinal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'seriesId': serializer.toJson<String>(seriesId),
      'childId': serializer.toJson<String>(childId),
      'seq': serializer.toJson<int>(seq),
      'intent': serializer.toJson<int>(
        $BeatsTable.$converterintent.toJson(intent),
      ),
      'chosenTwist': serializer.toJson<String?>(chosenTwist),
      'storyText': serializer.toJson<String>(storyText),
      'summary': serializer.toJson<String>(summary),
      'chapterTitle': serializer.toJson<String>(chapterTitle),
      'narrationJson': serializer.toJson<String>(narrationJson),
      'rating': serializer.toJson<int>(
        $BeatsTable.$converterrating.toJson(rating),
      ),
      'setting': serializer.toJson<String>(setting),
      'characters': serializer.toJson<List<String>>(characters),
      'openThreads': serializer.toJson<List<String>>(openThreads),
      'language': serializer.toJson<String>(language),
      'isFinal': serializer.toJson<bool>(isFinal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BeatRow copyWith({
    String? id,
    String? seriesId,
    String? childId,
    int? seq,
    StoryIntent? intent,
    Value<String?> chosenTwist = const Value.absent(),
    String? storyText,
    String? summary,
    String? chapterTitle,
    String? narrationJson,
    AgeRating? rating,
    String? setting,
    List<String>? characters,
    List<String>? openThreads,
    String? language,
    bool? isFinal,
    DateTime? createdAt,
  }) => BeatRow(
    id: id ?? this.id,
    seriesId: seriesId ?? this.seriesId,
    childId: childId ?? this.childId,
    seq: seq ?? this.seq,
    intent: intent ?? this.intent,
    chosenTwist: chosenTwist.present ? chosenTwist.value : this.chosenTwist,
    storyText: storyText ?? this.storyText,
    summary: summary ?? this.summary,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    narrationJson: narrationJson ?? this.narrationJson,
    rating: rating ?? this.rating,
    setting: setting ?? this.setting,
    characters: characters ?? this.characters,
    openThreads: openThreads ?? this.openThreads,
    language: language ?? this.language,
    isFinal: isFinal ?? this.isFinal,
    createdAt: createdAt ?? this.createdAt,
  );
  BeatRow copyWithCompanion(BeatsCompanion data) {
    return BeatRow(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      childId: data.childId.present ? data.childId.value : this.childId,
      seq: data.seq.present ? data.seq.value : this.seq,
      intent: data.intent.present ? data.intent.value : this.intent,
      chosenTwist: data.chosenTwist.present
          ? data.chosenTwist.value
          : this.chosenTwist,
      storyText: data.storyText.present ? data.storyText.value : this.storyText,
      summary: data.summary.present ? data.summary.value : this.summary,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      narrationJson: data.narrationJson.present
          ? data.narrationJson.value
          : this.narrationJson,
      rating: data.rating.present ? data.rating.value : this.rating,
      setting: data.setting.present ? data.setting.value : this.setting,
      characters: data.characters.present
          ? data.characters.value
          : this.characters,
      openThreads: data.openThreads.present
          ? data.openThreads.value
          : this.openThreads,
      language: data.language.present ? data.language.value : this.language,
      isFinal: data.isFinal.present ? data.isFinal.value : this.isFinal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BeatRow(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('childId: $childId, ')
          ..write('seq: $seq, ')
          ..write('intent: $intent, ')
          ..write('chosenTwist: $chosenTwist, ')
          ..write('storyText: $storyText, ')
          ..write('summary: $summary, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('narrationJson: $narrationJson, ')
          ..write('rating: $rating, ')
          ..write('setting: $setting, ')
          ..write('characters: $characters, ')
          ..write('openThreads: $openThreads, ')
          ..write('language: $language, ')
          ..write('isFinal: $isFinal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    childId,
    seq,
    intent,
    chosenTwist,
    storyText,
    summary,
    chapterTitle,
    narrationJson,
    rating,
    setting,
    characters,
    openThreads,
    language,
    isFinal,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BeatRow &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.childId == this.childId &&
          other.seq == this.seq &&
          other.intent == this.intent &&
          other.chosenTwist == this.chosenTwist &&
          other.storyText == this.storyText &&
          other.summary == this.summary &&
          other.chapterTitle == this.chapterTitle &&
          other.narrationJson == this.narrationJson &&
          other.rating == this.rating &&
          other.setting == this.setting &&
          other.characters == this.characters &&
          other.openThreads == this.openThreads &&
          other.language == this.language &&
          other.isFinal == this.isFinal &&
          other.createdAt == this.createdAt);
}

class BeatsCompanion extends UpdateCompanion<BeatRow> {
  final Value<String> id;
  final Value<String> seriesId;
  final Value<String> childId;
  final Value<int> seq;
  final Value<StoryIntent> intent;
  final Value<String?> chosenTwist;
  final Value<String> storyText;
  final Value<String> summary;
  final Value<String> chapterTitle;
  final Value<String> narrationJson;
  final Value<AgeRating> rating;
  final Value<String> setting;
  final Value<List<String>> characters;
  final Value<List<String>> openThreads;
  final Value<String> language;
  final Value<bool> isFinal;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BeatsCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.childId = const Value.absent(),
    this.seq = const Value.absent(),
    this.intent = const Value.absent(),
    this.chosenTwist = const Value.absent(),
    this.storyText = const Value.absent(),
    this.summary = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.narrationJson = const Value.absent(),
    this.rating = const Value.absent(),
    this.setting = const Value.absent(),
    this.characters = const Value.absent(),
    this.openThreads = const Value.absent(),
    this.language = const Value.absent(),
    this.isFinal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BeatsCompanion.insert({
    required String id,
    required String seriesId,
    required String childId,
    required int seq,
    required StoryIntent intent,
    this.chosenTwist = const Value.absent(),
    required String storyText,
    required String summary,
    this.chapterTitle = const Value.absent(),
    this.narrationJson = const Value.absent(),
    required AgeRating rating,
    this.setting = const Value.absent(),
    required List<String> characters,
    required List<String> openThreads,
    this.language = const Value.absent(),
    this.isFinal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       seriesId = Value(seriesId),
       childId = Value(childId),
       seq = Value(seq),
       intent = Value(intent),
       storyText = Value(storyText),
       summary = Value(summary),
       rating = Value(rating),
       characters = Value(characters),
       openThreads = Value(openThreads);
  static Insertable<BeatRow> custom({
    Expression<String>? id,
    Expression<String>? seriesId,
    Expression<String>? childId,
    Expression<int>? seq,
    Expression<int>? intent,
    Expression<String>? chosenTwist,
    Expression<String>? storyText,
    Expression<String>? summary,
    Expression<String>? chapterTitle,
    Expression<String>? narrationJson,
    Expression<int>? rating,
    Expression<String>? setting,
    Expression<String>? characters,
    Expression<String>? openThreads,
    Expression<String>? language,
    Expression<bool>? isFinal,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (childId != null) 'child_id': childId,
      if (seq != null) 'seq': seq,
      if (intent != null) 'intent': intent,
      if (chosenTwist != null) 'chosen_twist': chosenTwist,
      if (storyText != null) 'story_text': storyText,
      if (summary != null) 'summary': summary,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (narrationJson != null) 'narration_json': narrationJson,
      if (rating != null) 'rating': rating,
      if (setting != null) 'setting': setting,
      if (characters != null) 'characters': characters,
      if (openThreads != null) 'open_threads': openThreads,
      if (language != null) 'language': language,
      if (isFinal != null) 'is_final': isFinal,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BeatsCompanion copyWith({
    Value<String>? id,
    Value<String>? seriesId,
    Value<String>? childId,
    Value<int>? seq,
    Value<StoryIntent>? intent,
    Value<String?>? chosenTwist,
    Value<String>? storyText,
    Value<String>? summary,
    Value<String>? chapterTitle,
    Value<String>? narrationJson,
    Value<AgeRating>? rating,
    Value<String>? setting,
    Value<List<String>>? characters,
    Value<List<String>>? openThreads,
    Value<String>? language,
    Value<bool>? isFinal,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BeatsCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      childId: childId ?? this.childId,
      seq: seq ?? this.seq,
      intent: intent ?? this.intent,
      chosenTwist: chosenTwist ?? this.chosenTwist,
      storyText: storyText ?? this.storyText,
      summary: summary ?? this.summary,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      narrationJson: narrationJson ?? this.narrationJson,
      rating: rating ?? this.rating,
      setting: setting ?? this.setting,
      characters: characters ?? this.characters,
      openThreads: openThreads ?? this.openThreads,
      language: language ?? this.language,
      isFinal: isFinal ?? this.isFinal,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (intent.present) {
      map['intent'] = Variable<int>(
        $BeatsTable.$converterintent.toSql(intent.value),
      );
    }
    if (chosenTwist.present) {
      map['chosen_twist'] = Variable<String>(chosenTwist.value);
    }
    if (storyText.present) {
      map['story_text'] = Variable<String>(storyText.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (narrationJson.present) {
      map['narration_json'] = Variable<String>(narrationJson.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(
        $BeatsTable.$converterrating.toSql(rating.value),
      );
    }
    if (setting.present) {
      map['setting'] = Variable<String>(setting.value);
    }
    if (characters.present) {
      map['characters'] = Variable<String>(
        $BeatsTable.$convertercharacters.toSql(characters.value),
      );
    }
    if (openThreads.present) {
      map['open_threads'] = Variable<String>(
        $BeatsTable.$converteropenThreads.toSql(openThreads.value),
      );
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (isFinal.present) {
      map['is_final'] = Variable<bool>(isFinal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeatsCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('childId: $childId, ')
          ..write('seq: $seq, ')
          ..write('intent: $intent, ')
          ..write('chosenTwist: $chosenTwist, ')
          ..write('storyText: $storyText, ')
          ..write('summary: $summary, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('narrationJson: $narrationJson, ')
          ..write('rating: $rating, ')
          ..write('setting: $setting, ')
          ..write('characters: $characters, ')
          ..write('openThreads: $openThreads, ')
          ..write('language: $language, ')
          ..write('isFinal: $isFinal, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoryImagesTable extends StoryImages
    with TableInfo<$StoryImagesTable, StoryImageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _beatIdMeta = const VerificationMeta('beatId');
  @override
  late final GeneratedColumn<String> beatId = GeneratedColumn<String>(
    'beat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StoryImageKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<StoryImageKind>($StoryImagesTable.$converterkind);
  static const VerificationMeta _fileKeyMeta = const VerificationMeta(
    'fileKey',
  );
  @override
  late final GeneratedColumn<String> fileKey = GeneratedColumn<String>(
    'file_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('2K'),
  );
  static const VerificationMeta _aspectMeta = const VerificationMeta('aspect');
  @override
  late final GeneratedColumn<String> aspect = GeneratedColumn<String>(
    'aspect',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('4:3'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    seriesId,
    beatId,
    kind,
    fileKey,
    prompt,
    seed,
    model,
    size,
    aspect,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'story_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoryImageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('beat_id')) {
      context.handle(
        _beatIdMeta,
        beatId.isAcceptableOrUnknown(data['beat_id']!, _beatIdMeta),
      );
    }
    if (data.containsKey('file_key')) {
      context.handle(
        _fileKeyMeta,
        fileKey.isAcceptableOrUnknown(data['file_key']!, _fileKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fileKeyMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('aspect')) {
      context.handle(
        _aspectMeta,
        aspect.isAcceptableOrUnknown(data['aspect']!, _aspectMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoryImageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoryImageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      beatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}beat_id'],
      ),
      kind: $StoryImagesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      fileKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_key'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size'],
      )!,
      aspect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aspect'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StoryImagesTable createAlias(String alias) {
    return $StoryImagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StoryImageKind, int, int> $converterkind =
      const EnumIndexConverter<StoryImageKind>(StoryImageKind.values);
}

class StoryImageRow extends DataClass implements Insertable<StoryImageRow> {
  final String id;
  final String seriesId;

  /// Null for a cover, which belongs to the story rather than a chapter.
  final String? beatId;
  final StoryImageKind kind;
  final String fileKey;
  final String prompt;
  final int? seed;
  final String model;
  final String size;
  final String aspect;
  final DateTime createdAt;
  const StoryImageRow({
    required this.id,
    required this.seriesId,
    this.beatId,
    required this.kind,
    required this.fileKey,
    required this.prompt,
    this.seed,
    required this.model,
    required this.size,
    required this.aspect,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['series_id'] = Variable<String>(seriesId);
    if (!nullToAbsent || beatId != null) {
      map['beat_id'] = Variable<String>(beatId);
    }
    {
      map['kind'] = Variable<int>($StoryImagesTable.$converterkind.toSql(kind));
    }
    map['file_key'] = Variable<String>(fileKey);
    map['prompt'] = Variable<String>(prompt);
    if (!nullToAbsent || seed != null) {
      map['seed'] = Variable<int>(seed);
    }
    map['model'] = Variable<String>(model);
    map['size'] = Variable<String>(size);
    map['aspect'] = Variable<String>(aspect);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StoryImagesCompanion toCompanion(bool nullToAbsent) {
    return StoryImagesCompanion(
      id: Value(id),
      seriesId: Value(seriesId),
      beatId: beatId == null && nullToAbsent
          ? const Value.absent()
          : Value(beatId),
      kind: Value(kind),
      fileKey: Value(fileKey),
      prompt: Value(prompt),
      seed: seed == null && nullToAbsent ? const Value.absent() : Value(seed),
      model: Value(model),
      size: Value(size),
      aspect: Value(aspect),
      createdAt: Value(createdAt),
    );
  }

  factory StoryImageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoryImageRow(
      id: serializer.fromJson<String>(json['id']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      beatId: serializer.fromJson<String?>(json['beatId']),
      kind: $StoryImagesTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      fileKey: serializer.fromJson<String>(json['fileKey']),
      prompt: serializer.fromJson<String>(json['prompt']),
      seed: serializer.fromJson<int?>(json['seed']),
      model: serializer.fromJson<String>(json['model']),
      size: serializer.fromJson<String>(json['size']),
      aspect: serializer.fromJson<String>(json['aspect']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'seriesId': serializer.toJson<String>(seriesId),
      'beatId': serializer.toJson<String?>(beatId),
      'kind': serializer.toJson<int>(
        $StoryImagesTable.$converterkind.toJson(kind),
      ),
      'fileKey': serializer.toJson<String>(fileKey),
      'prompt': serializer.toJson<String>(prompt),
      'seed': serializer.toJson<int?>(seed),
      'model': serializer.toJson<String>(model),
      'size': serializer.toJson<String>(size),
      'aspect': serializer.toJson<String>(aspect),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StoryImageRow copyWith({
    String? id,
    String? seriesId,
    Value<String?> beatId = const Value.absent(),
    StoryImageKind? kind,
    String? fileKey,
    String? prompt,
    Value<int?> seed = const Value.absent(),
    String? model,
    String? size,
    String? aspect,
    DateTime? createdAt,
  }) => StoryImageRow(
    id: id ?? this.id,
    seriesId: seriesId ?? this.seriesId,
    beatId: beatId.present ? beatId.value : this.beatId,
    kind: kind ?? this.kind,
    fileKey: fileKey ?? this.fileKey,
    prompt: prompt ?? this.prompt,
    seed: seed.present ? seed.value : this.seed,
    model: model ?? this.model,
    size: size ?? this.size,
    aspect: aspect ?? this.aspect,
    createdAt: createdAt ?? this.createdAt,
  );
  StoryImageRow copyWithCompanion(StoryImagesCompanion data) {
    return StoryImageRow(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      beatId: data.beatId.present ? data.beatId.value : this.beatId,
      kind: data.kind.present ? data.kind.value : this.kind,
      fileKey: data.fileKey.present ? data.fileKey.value : this.fileKey,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      seed: data.seed.present ? data.seed.value : this.seed,
      model: data.model.present ? data.model.value : this.model,
      size: data.size.present ? data.size.value : this.size,
      aspect: data.aspect.present ? data.aspect.value : this.aspect,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoryImageRow(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('beatId: $beatId, ')
          ..write('kind: $kind, ')
          ..write('fileKey: $fileKey, ')
          ..write('prompt: $prompt, ')
          ..write('seed: $seed, ')
          ..write('model: $model, ')
          ..write('size: $size, ')
          ..write('aspect: $aspect, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    beatId,
    kind,
    fileKey,
    prompt,
    seed,
    model,
    size,
    aspect,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryImageRow &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.beatId == this.beatId &&
          other.kind == this.kind &&
          other.fileKey == this.fileKey &&
          other.prompt == this.prompt &&
          other.seed == this.seed &&
          other.model == this.model &&
          other.size == this.size &&
          other.aspect == this.aspect &&
          other.createdAt == this.createdAt);
}

class StoryImagesCompanion extends UpdateCompanion<StoryImageRow> {
  final Value<String> id;
  final Value<String> seriesId;
  final Value<String?> beatId;
  final Value<StoryImageKind> kind;
  final Value<String> fileKey;
  final Value<String> prompt;
  final Value<int?> seed;
  final Value<String> model;
  final Value<String> size;
  final Value<String> aspect;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StoryImagesCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.beatId = const Value.absent(),
    this.kind = const Value.absent(),
    this.fileKey = const Value.absent(),
    this.prompt = const Value.absent(),
    this.seed = const Value.absent(),
    this.model = const Value.absent(),
    this.size = const Value.absent(),
    this.aspect = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoryImagesCompanion.insert({
    required String id,
    required String seriesId,
    this.beatId = const Value.absent(),
    required StoryImageKind kind,
    required String fileKey,
    required String prompt,
    this.seed = const Value.absent(),
    this.model = const Value.absent(),
    this.size = const Value.absent(),
    this.aspect = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       seriesId = Value(seriesId),
       kind = Value(kind),
       fileKey = Value(fileKey),
       prompt = Value(prompt);
  static Insertable<StoryImageRow> custom({
    Expression<String>? id,
    Expression<String>? seriesId,
    Expression<String>? beatId,
    Expression<int>? kind,
    Expression<String>? fileKey,
    Expression<String>? prompt,
    Expression<int>? seed,
    Expression<String>? model,
    Expression<String>? size,
    Expression<String>? aspect,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (beatId != null) 'beat_id': beatId,
      if (kind != null) 'kind': kind,
      if (fileKey != null) 'file_key': fileKey,
      if (prompt != null) 'prompt': prompt,
      if (seed != null) 'seed': seed,
      if (model != null) 'model': model,
      if (size != null) 'size': size,
      if (aspect != null) 'aspect': aspect,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoryImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? seriesId,
    Value<String?>? beatId,
    Value<StoryImageKind>? kind,
    Value<String>? fileKey,
    Value<String>? prompt,
    Value<int?>? seed,
    Value<String>? model,
    Value<String>? size,
    Value<String>? aspect,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StoryImagesCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      beatId: beatId ?? this.beatId,
      kind: kind ?? this.kind,
      fileKey: fileKey ?? this.fileKey,
      prompt: prompt ?? this.prompt,
      seed: seed ?? this.seed,
      model: model ?? this.model,
      size: size ?? this.size,
      aspect: aspect ?? this.aspect,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (beatId.present) {
      map['beat_id'] = Variable<String>(beatId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $StoryImagesTable.$converterkind.toSql(kind.value),
      );
    }
    if (fileKey.present) {
      map['file_key'] = Variable<String>(fileKey.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (aspect.present) {
      map['aspect'] = Variable<String>(aspect.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryImagesCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('beatId: $beatId, ')
          ..write('kind: $kind, ')
          ..write('fileKey: $fileKey, ')
          ..write('prompt: $prompt, ')
          ..write('seed: $seed, ')
          ..write('model: $model, ')
          ..write('size: $size, ')
          ..write('aspect: $aspect, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChildProfilesTable childProfiles = $ChildProfilesTable(this);
  late final $QuizResultsTable quizResults = $QuizResultsTable(this);
  late final $InterestsTable interests = $InterestsTable(this);
  late final $LearnedProfilesTable learnedProfiles = $LearnedProfilesTable(
    this,
  );
  late final $WorldsTable worlds = $WorldsTable(this);
  late final $StoryCharactersTable storyCharacters = $StoryCharactersTable(
    this,
  );
  late final $SeriesTableTable seriesTable = $SeriesTableTable(this);
  late final $BeatsTable beats = $BeatsTable(this);
  late final $StoryImagesTable storyImages = $StoryImagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    childProfiles,
    quizResults,
    interests,
    learnedProfiles,
    worlds,
    storyCharacters,
    seriesTable,
    beats,
    storyImages,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quiz_results', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('interests', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learned_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('worlds', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'worlds',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('characters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'worlds',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('beats', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('story_images', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ChildProfilesTableCreateCompanionBuilder =
    ChildProfilesCompanion Function({
      required String id,
      required String displayName,
      required int age,
      Value<String> language,
      required DetailLevel detailLevel,
      Value<int> themeColor,
      Value<String?> parentBrief,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ChildProfilesTableUpdateCompanionBuilder =
    ChildProfilesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<int> age,
      Value<String> language,
      Value<DetailLevel> detailLevel,
      Value<int> themeColor,
      Value<String?> parentBrief,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ChildProfilesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfileRow> {
  $$ChildProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$QuizResultsTable, List<QuizResultRow>>
  _quizResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.quizResults,
    aliasName: 'child_profiles__id__quiz_results__child_id',
  );

  $$QuizResultsTableProcessedTableManager get quizResultsRefs {
    final manager = $$QuizResultsTableTableManager(
      $_db,
      $_db.quizResults,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_quizResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InterestsTable, List<InterestRow>>
  _interestsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.interests,
    aliasName: 'child_profiles__id__interests__child_id',
  );

  $$InterestsTableProcessedTableManager get interestsRefs {
    final manager = $$InterestsTableTableManager(
      $_db,
      $_db.interests,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_interestsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearnedProfilesTable, List<LearnedProfileRow>>
  _learnedProfilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.learnedProfiles,
    aliasName: 'child_profiles__id__learned_profiles__child_id',
  );

  $$LearnedProfilesTableProcessedTableManager get learnedProfilesRefs {
    final manager = $$LearnedProfilesTableTableManager(
      $_db,
      $_db.learnedProfiles,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _learnedProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorldsTable, List<WorldRow>> _worldsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.worlds,
    aliasName: 'child_profiles__id__worlds__child_id',
  );

  $$WorldsTableProcessedTableManager get worldsRefs {
    final manager = $$WorldsTableTableManager(
      $_db,
      $_db.worlds,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_worldsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeriesTableTable, List<SeriesRow>>
  _seriesTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.seriesTable,
    aliasName: 'child_profiles__id__series__child_id',
  );

  $$SeriesTableTableProcessedTableManager get seriesTableRefs {
    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChildProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DetailLevel, DetailLevel, int>
  get detailLevel => $composableBuilder(
    column: $table.detailLevel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get themeColor => $composableBuilder(
    column: $table.themeColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentBrief => $composableBuilder(
    column: $table.parentBrief,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> quizResultsRefs(
    Expression<bool> Function($$QuizResultsTableFilterComposer f) f,
  ) {
    final $$QuizResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizResults,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizResultsTableFilterComposer(
            $db: $db,
            $table: $db.quizResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> interestsRefs(
    Expression<bool> Function($$InterestsTableFilterComposer f) f,
  ) {
    final $$InterestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interests,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterestsTableFilterComposer(
            $db: $db,
            $table: $db.interests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learnedProfilesRefs(
    Expression<bool> Function($$LearnedProfilesTableFilterComposer f) f,
  ) {
    final $$LearnedProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learnedProfiles,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnedProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> worldsRefs(
    Expression<bool> Function($$WorldsTableFilterComposer f) f,
  ) {
    final $$WorldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableFilterComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesTableRefs(
    Expression<bool> Function($$SeriesTableTableFilterComposer f) f,
  ) {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChildProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detailLevel => $composableBuilder(
    column: $table.detailLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get themeColor => $composableBuilder(
    column: $table.themeColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentBrief => $composableBuilder(
    column: $table.parentBrief,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChildProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DetailLevel, int> get detailLevel =>
      $composableBuilder(
        column: $table.detailLevel,
        builder: (column) => column,
      );

  GeneratedColumn<int> get themeColor => $composableBuilder(
    column: $table.themeColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentBrief => $composableBuilder(
    column: $table.parentBrief,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> quizResultsRefs<T extends Object>(
    Expression<T> Function($$QuizResultsTableAnnotationComposer a) f,
  ) {
    final $$QuizResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizResults,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.quizResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> interestsRefs<T extends Object>(
    Expression<T> Function($$InterestsTableAnnotationComposer a) f,
  ) {
    final $$InterestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interests,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterestsTableAnnotationComposer(
            $db: $db,
            $table: $db.interests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learnedProfilesRefs<T extends Object>(
    Expression<T> Function($$LearnedProfilesTableAnnotationComposer a) f,
  ) {
    final $$LearnedProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learnedProfiles,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnedProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> worldsRefs<T extends Object>(
    Expression<T> Function($$WorldsTableAnnotationComposer a) f,
  ) {
    final $$WorldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableAnnotationComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesTableRefs<T extends Object>(
    Expression<T> Function($$SeriesTableTableAnnotationComposer a) f,
  ) {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChildProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChildProfilesTable,
          ChildProfileRow,
          $$ChildProfilesTableFilterComposer,
          $$ChildProfilesTableOrderingComposer,
          $$ChildProfilesTableAnnotationComposer,
          $$ChildProfilesTableCreateCompanionBuilder,
          $$ChildProfilesTableUpdateCompanionBuilder,
          (ChildProfileRow, $$ChildProfilesTableReferences),
          ChildProfileRow,
          PrefetchHooks Function({
            bool quizResultsRefs,
            bool interestsRefs,
            bool learnedProfilesRefs,
            bool worldsRefs,
            bool seriesTableRefs,
          })
        > {
  $$ChildProfilesTableTableManager(_$AppDatabase db, $ChildProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChildProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChildProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChildProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<DetailLevel> detailLevel = const Value.absent(),
                Value<int> themeColor = const Value.absent(),
                Value<String?> parentBrief = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChildProfilesCompanion(
                id: id,
                displayName: displayName,
                age: age,
                language: language,
                detailLevel: detailLevel,
                themeColor: themeColor,
                parentBrief: parentBrief,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required int age,
                Value<String> language = const Value.absent(),
                required DetailLevel detailLevel,
                Value<int> themeColor = const Value.absent(),
                Value<String?> parentBrief = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChildProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                age: age,
                language: language,
                detailLevel: detailLevel,
                themeColor: themeColor,
                parentBrief: parentBrief,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChildProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                quizResultsRefs = false,
                interestsRefs = false,
                learnedProfilesRefs = false,
                worldsRefs = false,
                seriesTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (quizResultsRefs) db.quizResults,
                    if (interestsRefs) db.interests,
                    if (learnedProfilesRefs) db.learnedProfiles,
                    if (worldsRefs) db.worlds,
                    if (seriesTableRefs) db.seriesTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (quizResultsRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          QuizResultRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._quizResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).quizResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (interestsRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          InterestRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._interestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).interestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learnedProfilesRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          LearnedProfileRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._learnedProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).learnedProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (worldsRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          WorldRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._worldsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).worldsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesTableRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          SeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._seriesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChildProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChildProfilesTable,
      ChildProfileRow,
      $$ChildProfilesTableFilterComposer,
      $$ChildProfilesTableOrderingComposer,
      $$ChildProfilesTableAnnotationComposer,
      $$ChildProfilesTableCreateCompanionBuilder,
      $$ChildProfilesTableUpdateCompanionBuilder,
      (ChildProfileRow, $$ChildProfilesTableReferences),
      ChildProfileRow,
      PrefetchHooks Function({
        bool quizResultsRefs,
        bool interestsRefs,
        bool learnedProfilesRefs,
        bool worldsRefs,
        bool seriesTableRefs,
      })
    >;
typedef $$QuizResultsTableCreateCompanionBuilder =
    QuizResultsCompanion Function({
      required String id,
      required String childId,
      required QuizKind kind,
      required Map<String, String> answers,
      required String seedSummary,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$QuizResultsTableUpdateCompanionBuilder =
    QuizResultsCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<QuizKind> kind,
      Value<Map<String, String>> answers,
      Value<String> seedSummary,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$QuizResultsTableReferences
    extends BaseReferences<_$AppDatabase, $QuizResultsTable, QuizResultRow> {
  $$QuizResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('quiz_results__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuizResultsTableFilterComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<QuizKind, QuizKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<
    Map<String, String>,
    Map<String, String>,
    String
  >
  get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<QuizKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>, String> get answers =>
      $composableBuilder(column: $table.answers, builder: (column) => column);

  GeneratedColumn<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizResultsTable,
          QuizResultRow,
          $$QuizResultsTableFilterComposer,
          $$QuizResultsTableOrderingComposer,
          $$QuizResultsTableAnnotationComposer,
          $$QuizResultsTableCreateCompanionBuilder,
          $$QuizResultsTableUpdateCompanionBuilder,
          (QuizResultRow, $$QuizResultsTableReferences),
          QuizResultRow,
          PrefetchHooks Function({bool childId})
        > {
  $$QuizResultsTableTableManager(_$AppDatabase db, $QuizResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<QuizKind> kind = const Value.absent(),
                Value<Map<String, String>> answers = const Value.absent(),
                Value<String> seedSummary = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizResultsCompanion(
                id: id,
                childId: childId,
                kind: kind,
                answers: answers,
                seedSummary: seedSummary,
                version: version,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                required QuizKind kind,
                required Map<String, String> answers,
                required String seedSummary,
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizResultsCompanion.insert(
                id: id,
                childId: childId,
                kind: kind,
                answers: answers,
                seedSummary: seedSummary,
                version: version,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuizResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable: $$QuizResultsTableReferences
                                    ._childIdTable(db),
                                referencedColumn: $$QuizResultsTableReferences
                                    ._childIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$QuizResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizResultsTable,
      QuizResultRow,
      $$QuizResultsTableFilterComposer,
      $$QuizResultsTableOrderingComposer,
      $$QuizResultsTableAnnotationComposer,
      $$QuizResultsTableCreateCompanionBuilder,
      $$QuizResultsTableUpdateCompanionBuilder,
      (QuizResultRow, $$QuizResultsTableReferences),
      QuizResultRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$InterestsTableCreateCompanionBuilder =
    InterestsCompanion Function({
      required String id,
      required String childId,
      required String label,
      Value<int> weight,
      Value<bool> active,
      required InterestSource source,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$InterestsTableUpdateCompanionBuilder =
    InterestsCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<String> label,
      Value<int> weight,
      Value<bool> active,
      Value<InterestSource> source,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$InterestsTableReferences
    extends BaseReferences<_$AppDatabase, $InterestsTable, InterestRow> {
  $$InterestsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) =>
      db.childProfiles.createAlias('interests__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InterestsTableFilterComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InterestSource, InterestSource, int>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestsTableOrderingComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InterestSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InterestsTable,
          InterestRow,
          $$InterestsTableFilterComposer,
          $$InterestsTableOrderingComposer,
          $$InterestsTableAnnotationComposer,
          $$InterestsTableCreateCompanionBuilder,
          $$InterestsTableUpdateCompanionBuilder,
          (InterestRow, $$InterestsTableReferences),
          InterestRow,
          PrefetchHooks Function({bool childId})
        > {
  $$InterestsTableTableManager(_$AppDatabase db, $InterestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InterestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InterestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InterestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<InterestSource> source = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InterestsCompanion(
                id: id,
                childId: childId,
                label: label,
                weight: weight,
                active: active,
                source: source,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                required String label,
                Value<int> weight = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required InterestSource source,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InterestsCompanion.insert(
                id: id,
                childId: childId,
                label: label,
                weight: weight,
                active: active,
                source: source,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$InterestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable: $$InterestsTableReferences
                                    ._childIdTable(db),
                                referencedColumn: $$InterestsTableReferences
                                    ._childIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InterestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InterestsTable,
      InterestRow,
      $$InterestsTableFilterComposer,
      $$InterestsTableOrderingComposer,
      $$InterestsTableAnnotationComposer,
      $$InterestsTableCreateCompanionBuilder,
      $$InterestsTableUpdateCompanionBuilder,
      (InterestRow, $$InterestsTableReferences),
      InterestRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$LearnedProfilesTableCreateCompanionBuilder =
    LearnedProfilesCompanion Function({
      required String childId,
      Value<String> dataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LearnedProfilesTableUpdateCompanionBuilder =
    LearnedProfilesCompanion Function({
      Value<String> childId,
      Value<String> dataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LearnedProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LearnedProfilesTable,
          LearnedProfileRow
        > {
  $$LearnedProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('learned_profiles__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearnedProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LearnedProfilesTable> {
  $$LearnedProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnedProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LearnedProfilesTable> {
  $$LearnedProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnedProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearnedProfilesTable> {
  $$LearnedProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnedProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearnedProfilesTable,
          LearnedProfileRow,
          $$LearnedProfilesTableFilterComposer,
          $$LearnedProfilesTableOrderingComposer,
          $$LearnedProfilesTableAnnotationComposer,
          $$LearnedProfilesTableCreateCompanionBuilder,
          $$LearnedProfilesTableUpdateCompanionBuilder,
          (LearnedProfileRow, $$LearnedProfilesTableReferences),
          LearnedProfileRow,
          PrefetchHooks Function({bool childId})
        > {
  $$LearnedProfilesTableTableManager(
    _$AppDatabase db,
    $LearnedProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnedProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnedProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearnedProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> childId = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnedProfilesCompanion(
                childId: childId,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String childId,
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnedProfilesCompanion.insert(
                childId: childId,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearnedProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable:
                                    $$LearnedProfilesTableReferences
                                        ._childIdTable(db),
                                referencedColumn:
                                    $$LearnedProfilesTableReferences
                                        ._childIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearnedProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearnedProfilesTable,
      LearnedProfileRow,
      $$LearnedProfilesTableFilterComposer,
      $$LearnedProfilesTableOrderingComposer,
      $$LearnedProfilesTableAnnotationComposer,
      $$LearnedProfilesTableCreateCompanionBuilder,
      $$LearnedProfilesTableUpdateCompanionBuilder,
      (LearnedProfileRow, $$LearnedProfilesTableReferences),
      LearnedProfileRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$WorldsTableCreateCompanionBuilder =
    WorldsCompanion Function({
      required String id,
      required String childId,
      required String name,
      Value<String> premise,
      required StoryTheme theme,
      Value<String> extraThemes,
      Value<String> voiceName,
      Value<String> castChanges,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$WorldsTableUpdateCompanionBuilder =
    WorldsCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<String> name,
      Value<String> premise,
      Value<StoryTheme> theme,
      Value<String> extraThemes,
      Value<String> voiceName,
      Value<String> castChanges,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WorldsTableReferences
    extends BaseReferences<_$AppDatabase, $WorldsTable, WorldRow> {
  $$WorldsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) =>
      db.childProfiles.createAlias('worlds__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StoryCharactersTable, List<CharacterRow>>
  _storyCharactersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.storyCharacters,
    aliasName: 'worlds__id__characters__world_id',
  );

  $$StoryCharactersTableProcessedTableManager get storyCharactersRefs {
    final manager = $$StoryCharactersTableTableManager(
      $_db,
      $_db.storyCharacters,
    ).filter((f) => f.worldId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _storyCharactersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeriesTableTable, List<SeriesRow>>
  _seriesTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.seriesTable,
    aliasName: 'worlds__id__series__world_id',
  );

  $$SeriesTableTableProcessedTableManager get seriesTableRefs {
    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.worldId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorldsTableFilterComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get premise => $composableBuilder(
    column: $table.premise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StoryTheme, StoryTheme, int> get theme =>
      $composableBuilder(
        column: $table.theme,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get extraThemes => $composableBuilder(
    column: $table.extraThemes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceName => $composableBuilder(
    column: $table.voiceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castChanges => $composableBuilder(
    column: $table.castChanges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> storyCharactersRefs(
    Expression<bool> Function($$StoryCharactersTableFilterComposer f) f,
  ) {
    final $$StoryCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyCharacters,
      getReferencedColumn: (t) => t.worldId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryCharactersTableFilterComposer(
            $db: $db,
            $table: $db.storyCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesTableRefs(
    Expression<bool> Function($$SeriesTableTableFilterComposer f) f,
  ) {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.worldId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorldsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get premise => $composableBuilder(
    column: $table.premise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraThemes => $composableBuilder(
    column: $table.extraThemes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceName => $composableBuilder(
    column: $table.voiceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castChanges => $composableBuilder(
    column: $table.castChanges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get premise =>
      $composableBuilder(column: $table.premise, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StoryTheme, int> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get extraThemes => $composableBuilder(
    column: $table.extraThemes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceName =>
      $composableBuilder(column: $table.voiceName, builder: (column) => column);

  GeneratedColumn<String> get castChanges => $composableBuilder(
    column: $table.castChanges,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> storyCharactersRefs<T extends Object>(
    Expression<T> Function($$StoryCharactersTableAnnotationComposer a) f,
  ) {
    final $$StoryCharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyCharacters,
      getReferencedColumn: (t) => t.worldId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryCharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.storyCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesTableRefs<T extends Object>(
    Expression<T> Function($$SeriesTableTableAnnotationComposer a) f,
  ) {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.worldId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorldsTable,
          WorldRow,
          $$WorldsTableFilterComposer,
          $$WorldsTableOrderingComposer,
          $$WorldsTableAnnotationComposer,
          $$WorldsTableCreateCompanionBuilder,
          $$WorldsTableUpdateCompanionBuilder,
          (WorldRow, $$WorldsTableReferences),
          WorldRow,
          PrefetchHooks Function({
            bool childId,
            bool storyCharactersRefs,
            bool seriesTableRefs,
          })
        > {
  $$WorldsTableTableManager(_$AppDatabase db, $WorldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> premise = const Value.absent(),
                Value<StoryTheme> theme = const Value.absent(),
                Value<String> extraThemes = const Value.absent(),
                Value<String> voiceName = const Value.absent(),
                Value<String> castChanges = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldsCompanion(
                id: id,
                childId: childId,
                name: name,
                premise: premise,
                theme: theme,
                extraThemes: extraThemes,
                voiceName: voiceName,
                castChanges: castChanges,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                required String name,
                Value<String> premise = const Value.absent(),
                required StoryTheme theme,
                Value<String> extraThemes = const Value.absent(),
                Value<String> voiceName = const Value.absent(),
                Value<String> castChanges = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldsCompanion.insert(
                id: id,
                childId: childId,
                name: name,
                premise: premise,
                theme: theme,
                extraThemes: extraThemes,
                voiceName: voiceName,
                castChanges: castChanges,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$WorldsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                childId = false,
                storyCharactersRefs = false,
                seriesTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (storyCharactersRefs) db.storyCharacters,
                    if (seriesTableRefs) db.seriesTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (childId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.childId,
                                    referencedTable: $$WorldsTableReferences
                                        ._childIdTable(db),
                                    referencedColumn: $$WorldsTableReferences
                                        ._childIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (storyCharactersRefs)
                        await $_getPrefetchedData<
                          WorldRow,
                          $WorldsTable,
                          CharacterRow
                        >(
                          currentTable: table,
                          referencedTable: $$WorldsTableReferences
                              ._storyCharactersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorldsTableReferences(
                                db,
                                table,
                                p0,
                              ).storyCharactersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.worldId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesTableRefs)
                        await $_getPrefetchedData<
                          WorldRow,
                          $WorldsTable,
                          SeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$WorldsTableReferences
                              ._seriesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorldsTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.worldId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorldsTable,
      WorldRow,
      $$WorldsTableFilterComposer,
      $$WorldsTableOrderingComposer,
      $$WorldsTableAnnotationComposer,
      $$WorldsTableCreateCompanionBuilder,
      $$WorldsTableUpdateCompanionBuilder,
      (WorldRow, $$WorldsTableReferences),
      WorldRow,
      PrefetchHooks Function({
        bool childId,
        bool storyCharactersRefs,
        bool seriesTableRefs,
      })
    >;
typedef $$StoryCharactersTableCreateCompanionBuilder =
    StoryCharactersCompanion Function({
      required String id,
      required String worldId,
      required String name,
      Value<String> description,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$StoryCharactersTableUpdateCompanionBuilder =
    StoryCharactersCompanion Function({
      Value<String> id,
      Value<String> worldId,
      Value<String> name,
      Value<String> description,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$StoryCharactersTableReferences
    extends BaseReferences<_$AppDatabase, $StoryCharactersTable, CharacterRow> {
  $$StoryCharactersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorldsTable _worldIdTable(_$AppDatabase db) =>
      db.worlds.createAlias('characters__world_id__worlds__id');

  $$WorldsTableProcessedTableManager get worldId {
    final $_column = $_itemColumn<String>('world_id')!;

    final manager = $$WorldsTableTableManager(
      $_db,
      $_db.worlds,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_worldIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StoryCharactersTableFilterComposer
    extends Composer<_$AppDatabase, $StoryCharactersTable> {
  $$StoryCharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorldsTableFilterComposer get worldId {
    final $$WorldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableFilterComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryCharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $StoryCharactersTable> {
  $$StoryCharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorldsTableOrderingComposer get worldId {
    final $$WorldsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableOrderingComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryCharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoryCharactersTable> {
  $$StoryCharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WorldsTableAnnotationComposer get worldId {
    final $$WorldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableAnnotationComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryCharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoryCharactersTable,
          CharacterRow,
          $$StoryCharactersTableFilterComposer,
          $$StoryCharactersTableOrderingComposer,
          $$StoryCharactersTableAnnotationComposer,
          $$StoryCharactersTableCreateCompanionBuilder,
          $$StoryCharactersTableUpdateCompanionBuilder,
          (CharacterRow, $$StoryCharactersTableReferences),
          CharacterRow,
          PrefetchHooks Function({bool worldId})
        > {
  $$StoryCharactersTableTableManager(
    _$AppDatabase db,
    $StoryCharactersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryCharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryCharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryCharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> worldId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryCharactersCompanion(
                id: id,
                worldId: worldId,
                name: name,
                description: description,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String worldId,
                required String name,
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryCharactersCompanion.insert(
                id: id,
                worldId: worldId,
                name: name,
                description: description,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoryCharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({worldId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (worldId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.worldId,
                                referencedTable:
                                    $$StoryCharactersTableReferences
                                        ._worldIdTable(db),
                                referencedColumn:
                                    $$StoryCharactersTableReferences
                                        ._worldIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StoryCharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoryCharactersTable,
      CharacterRow,
      $$StoryCharactersTableFilterComposer,
      $$StoryCharactersTableOrderingComposer,
      $$StoryCharactersTableAnnotationComposer,
      $$StoryCharactersTableCreateCompanionBuilder,
      $$StoryCharactersTableUpdateCompanionBuilder,
      (CharacterRow, $$StoryCharactersTableReferences),
      CharacterRow,
      PrefetchHooks Function({bool worldId})
    >;
typedef $$SeriesTableTableCreateCompanionBuilder =
    SeriesTableCompanion Function({
      required String id,
      required String childId,
      Value<String?> worldId,
      required String title,
      required StoryTheme theme,
      Value<String> extraThemes,
      Value<bool> autoTitle,
      Value<String?> customTheme,
      required HeroMode heroMode,
      Value<String?> heroName,
      Value<bool> bilingualEnabled,
      Value<String?> secondaryLanguage,
      Value<BilingualBlend?> bilingualBlend,
      Value<String> seedSummary,
      Value<String> storyBible,
      Value<String?> branchedFromBeatId,
      required SeriesStatus status,
      Value<String?> baseLanguage,
      Value<int?> lastReadSeq,
      Value<DateTime?> lastReadAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SeriesTableTableUpdateCompanionBuilder =
    SeriesTableCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<String?> worldId,
      Value<String> title,
      Value<StoryTheme> theme,
      Value<String> extraThemes,
      Value<bool> autoTitle,
      Value<String?> customTheme,
      Value<HeroMode> heroMode,
      Value<String?> heroName,
      Value<bool> bilingualEnabled,
      Value<String?> secondaryLanguage,
      Value<BilingualBlend?> bilingualBlend,
      Value<String> seedSummary,
      Value<String> storyBible,
      Value<String?> branchedFromBeatId,
      Value<SeriesStatus> status,
      Value<String?> baseLanguage,
      Value<int?> lastReadSeq,
      Value<DateTime?> lastReadAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SeriesTableTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesTableTable, SeriesRow> {
  $$SeriesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) =>
      db.childProfiles.createAlias('series__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorldsTable _worldIdTable(_$AppDatabase db) =>
      db.worlds.createAlias('series__world_id__worlds__id');

  $$WorldsTableProcessedTableManager? get worldId {
    final $_column = $_itemColumn<String>('world_id');
    if ($_column == null) return null;
    final manager = $$WorldsTableTableManager(
      $_db,
      $_db.worlds,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_worldIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BeatsTable, List<BeatRow>> _beatsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.beats,
    aliasName: 'series__id__beats__series_id',
  );

  $$BeatsTableProcessedTableManager get beatsRefs {
    final manager = $$BeatsTableTableManager(
      $_db,
      $_db.beats,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_beatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StoryImagesTable, List<StoryImageRow>>
  _storyImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.storyImages,
    aliasName: 'series__id__story_images__series_id',
  );

  $$StoryImagesTableProcessedTableManager get storyImagesRefs {
    final manager = $$StoryImagesTableTableManager(
      $_db,
      $_db.storyImages,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_storyImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StoryTheme, StoryTheme, int> get theme =>
      $composableBuilder(
        column: $table.theme,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get extraThemes => $composableBuilder(
    column: $table.extraThemes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoTitle => $composableBuilder(
    column: $table.autoTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customTheme => $composableBuilder(
    column: $table.customTheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<HeroMode, HeroMode, int> get heroMode =>
      $composableBuilder(
        column: $table.heroMode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get heroName => $composableBuilder(
    column: $table.heroName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bilingualEnabled => $composableBuilder(
    column: $table.bilingualEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryLanguage => $composableBuilder(
    column: $table.secondaryLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BilingualBlend?, BilingualBlend, int>
  get bilingualBlend => $composableBuilder(
    column: $table.bilingualBlend,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storyBible => $composableBuilder(
    column: $table.storyBible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchedFromBeatId => $composableBuilder(
    column: $table.branchedFromBeatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SeriesStatus, SeriesStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get baseLanguage => $composableBuilder(
    column: $table.baseLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadSeq => $composableBuilder(
    column: $table.lastReadSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorldsTableFilterComposer get worldId {
    final $$WorldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableFilterComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> beatsRefs(
    Expression<bool> Function($$BeatsTableFilterComposer f) f,
  ) {
    final $$BeatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.beats,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeatsTableFilterComposer(
            $db: $db,
            $table: $db.beats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> storyImagesRefs(
    Expression<bool> Function($$StoryImagesTableFilterComposer f) f,
  ) {
    final $$StoryImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyImages,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryImagesTableFilterComposer(
            $db: $db,
            $table: $db.storyImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraThemes => $composableBuilder(
    column: $table.extraThemes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoTitle => $composableBuilder(
    column: $table.autoTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customTheme => $composableBuilder(
    column: $table.customTheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heroMode => $composableBuilder(
    column: $table.heroMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heroName => $composableBuilder(
    column: $table.heroName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bilingualEnabled => $composableBuilder(
    column: $table.bilingualEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryLanguage => $composableBuilder(
    column: $table.secondaryLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bilingualBlend => $composableBuilder(
    column: $table.bilingualBlend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storyBible => $composableBuilder(
    column: $table.storyBible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchedFromBeatId => $composableBuilder(
    column: $table.branchedFromBeatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseLanguage => $composableBuilder(
    column: $table.baseLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadSeq => $composableBuilder(
    column: $table.lastReadSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorldsTableOrderingComposer get worldId {
    final $$WorldsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableOrderingComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StoryTheme, int> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get extraThemes => $composableBuilder(
    column: $table.extraThemes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoTitle =>
      $composableBuilder(column: $table.autoTitle, builder: (column) => column);

  GeneratedColumn<String> get customTheme => $composableBuilder(
    column: $table.customTheme,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<HeroMode, int> get heroMode =>
      $composableBuilder(column: $table.heroMode, builder: (column) => column);

  GeneratedColumn<String> get heroName =>
      $composableBuilder(column: $table.heroName, builder: (column) => column);

  GeneratedColumn<bool> get bilingualEnabled => $composableBuilder(
    column: $table.bilingualEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryLanguage => $composableBuilder(
    column: $table.secondaryLanguage,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BilingualBlend?, int> get bilingualBlend =>
      $composableBuilder(
        column: $table.bilingualBlend,
        builder: (column) => column,
      );

  GeneratedColumn<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storyBible => $composableBuilder(
    column: $table.storyBible,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branchedFromBeatId => $composableBuilder(
    column: $table.branchedFromBeatId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SeriesStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get baseLanguage => $composableBuilder(
    column: $table.baseLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReadSeq => $composableBuilder(
    column: $table.lastReadSeq,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorldsTableAnnotationComposer get worldId {
    final $$WorldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableAnnotationComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> beatsRefs<T extends Object>(
    Expression<T> Function($$BeatsTableAnnotationComposer a) f,
  ) {
    final $$BeatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.beats,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeatsTableAnnotationComposer(
            $db: $db,
            $table: $db.beats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> storyImagesRefs<T extends Object>(
    Expression<T> Function($$StoryImagesTableAnnotationComposer a) f,
  ) {
    final $$StoryImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyImages,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.storyImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTableTable,
          SeriesRow,
          $$SeriesTableTableFilterComposer,
          $$SeriesTableTableOrderingComposer,
          $$SeriesTableTableAnnotationComposer,
          $$SeriesTableTableCreateCompanionBuilder,
          $$SeriesTableTableUpdateCompanionBuilder,
          (SeriesRow, $$SeriesTableTableReferences),
          SeriesRow,
          PrefetchHooks Function({
            bool childId,
            bool worldId,
            bool beatsRefs,
            bool storyImagesRefs,
          })
        > {
  $$SeriesTableTableTableManager(_$AppDatabase db, $SeriesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<String?> worldId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<StoryTheme> theme = const Value.absent(),
                Value<String> extraThemes = const Value.absent(),
                Value<bool> autoTitle = const Value.absent(),
                Value<String?> customTheme = const Value.absent(),
                Value<HeroMode> heroMode = const Value.absent(),
                Value<String?> heroName = const Value.absent(),
                Value<bool> bilingualEnabled = const Value.absent(),
                Value<String?> secondaryLanguage = const Value.absent(),
                Value<BilingualBlend?> bilingualBlend = const Value.absent(),
                Value<String> seedSummary = const Value.absent(),
                Value<String> storyBible = const Value.absent(),
                Value<String?> branchedFromBeatId = const Value.absent(),
                Value<SeriesStatus> status = const Value.absent(),
                Value<String?> baseLanguage = const Value.absent(),
                Value<int?> lastReadSeq = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesTableCompanion(
                id: id,
                childId: childId,
                worldId: worldId,
                title: title,
                theme: theme,
                extraThemes: extraThemes,
                autoTitle: autoTitle,
                customTheme: customTheme,
                heroMode: heroMode,
                heroName: heroName,
                bilingualEnabled: bilingualEnabled,
                secondaryLanguage: secondaryLanguage,
                bilingualBlend: bilingualBlend,
                seedSummary: seedSummary,
                storyBible: storyBible,
                branchedFromBeatId: branchedFromBeatId,
                status: status,
                baseLanguage: baseLanguage,
                lastReadSeq: lastReadSeq,
                lastReadAt: lastReadAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                Value<String?> worldId = const Value.absent(),
                required String title,
                required StoryTheme theme,
                Value<String> extraThemes = const Value.absent(),
                Value<bool> autoTitle = const Value.absent(),
                Value<String?> customTheme = const Value.absent(),
                required HeroMode heroMode,
                Value<String?> heroName = const Value.absent(),
                Value<bool> bilingualEnabled = const Value.absent(),
                Value<String?> secondaryLanguage = const Value.absent(),
                Value<BilingualBlend?> bilingualBlend = const Value.absent(),
                Value<String> seedSummary = const Value.absent(),
                Value<String> storyBible = const Value.absent(),
                Value<String?> branchedFromBeatId = const Value.absent(),
                required SeriesStatus status,
                Value<String?> baseLanguage = const Value.absent(),
                Value<int?> lastReadSeq = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesTableCompanion.insert(
                id: id,
                childId: childId,
                worldId: worldId,
                title: title,
                theme: theme,
                extraThemes: extraThemes,
                autoTitle: autoTitle,
                customTheme: customTheme,
                heroMode: heroMode,
                heroName: heroName,
                bilingualEnabled: bilingualEnabled,
                secondaryLanguage: secondaryLanguage,
                bilingualBlend: bilingualBlend,
                seedSummary: seedSummary,
                storyBible: storyBible,
                branchedFromBeatId: branchedFromBeatId,
                status: status,
                baseLanguage: baseLanguage,
                lastReadSeq: lastReadSeq,
                lastReadAt: lastReadAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SeriesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                childId = false,
                worldId = false,
                beatsRefs = false,
                storyImagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (beatsRefs) db.beats,
                    if (storyImagesRefs) db.storyImages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (childId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.childId,
                                    referencedTable:
                                        $$SeriesTableTableReferences
                                            ._childIdTable(db),
                                    referencedColumn:
                                        $$SeriesTableTableReferences
                                            ._childIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (worldId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.worldId,
                                    referencedTable:
                                        $$SeriesTableTableReferences
                                            ._worldIdTable(db),
                                    referencedColumn:
                                        $$SeriesTableTableReferences
                                            ._worldIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (beatsRefs)
                        await $_getPrefetchedData<
                          SeriesRow,
                          $SeriesTableTable,
                          BeatRow
                        >(
                          currentTable: table,
                          referencedTable: $$SeriesTableTableReferences
                              ._beatsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SeriesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).beatsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (storyImagesRefs)
                        await $_getPrefetchedData<
                          SeriesRow,
                          $SeriesTableTable,
                          StoryImageRow
                        >(
                          currentTable: table,
                          referencedTable: $$SeriesTableTableReferences
                              ._storyImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SeriesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).storyImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SeriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTableTable,
      SeriesRow,
      $$SeriesTableTableFilterComposer,
      $$SeriesTableTableOrderingComposer,
      $$SeriesTableTableAnnotationComposer,
      $$SeriesTableTableCreateCompanionBuilder,
      $$SeriesTableTableUpdateCompanionBuilder,
      (SeriesRow, $$SeriesTableTableReferences),
      SeriesRow,
      PrefetchHooks Function({
        bool childId,
        bool worldId,
        bool beatsRefs,
        bool storyImagesRefs,
      })
    >;
typedef $$BeatsTableCreateCompanionBuilder =
    BeatsCompanion Function({
      required String id,
      required String seriesId,
      required String childId,
      required int seq,
      required StoryIntent intent,
      Value<String?> chosenTwist,
      required String storyText,
      required String summary,
      Value<String> chapterTitle,
      Value<String> narrationJson,
      required AgeRating rating,
      Value<String> setting,
      required List<String> characters,
      required List<String> openThreads,
      Value<String> language,
      Value<bool> isFinal,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BeatsTableUpdateCompanionBuilder =
    BeatsCompanion Function({
      Value<String> id,
      Value<String> seriesId,
      Value<String> childId,
      Value<int> seq,
      Value<StoryIntent> intent,
      Value<String?> chosenTwist,
      Value<String> storyText,
      Value<String> summary,
      Value<String> chapterTitle,
      Value<String> narrationJson,
      Value<AgeRating> rating,
      Value<String> setting,
      Value<List<String>> characters,
      Value<List<String>> openThreads,
      Value<String> language,
      Value<bool> isFinal,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BeatsTableReferences
    extends BaseReferences<_$AppDatabase, $BeatsTable, BeatRow> {
  $$BeatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SeriesTableTable _seriesIdTable(_$AppDatabase db) =>
      db.seriesTable.createAlias('beats__series_id__series__id');

  $$SeriesTableTableProcessedTableManager get seriesId {
    final $_column = $_itemColumn<String>('series_id')!;

    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BeatsTableFilterComposer extends Composer<_$AppDatabase, $BeatsTable> {
  $$BeatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StoryIntent, StoryIntent, int> get intent =>
      $composableBuilder(
        column: $table.intent,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get chosenTwist => $composableBuilder(
    column: $table.chosenTwist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storyText => $composableBuilder(
    column: $table.storyText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrationJson => $composableBuilder(
    column: $table.narrationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AgeRating, AgeRating, int> get rating =>
      $composableBuilder(
        column: $table.rating,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get setting => $composableBuilder(
    column: $table.setting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get characters => $composableBuilder(
    column: $table.characters,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get openThreads => $composableBuilder(
    column: $table.openThreads,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinal => $composableBuilder(
    column: $table.isFinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SeriesTableTableFilterComposer get seriesId {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BeatsTableOrderingComposer
    extends Composer<_$AppDatabase, $BeatsTable> {
  $$BeatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intent => $composableBuilder(
    column: $table.intent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosenTwist => $composableBuilder(
    column: $table.chosenTwist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storyText => $composableBuilder(
    column: $table.storyText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrationJson => $composableBuilder(
    column: $table.narrationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setting => $composableBuilder(
    column: $table.setting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characters => $composableBuilder(
    column: $table.characters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openThreads => $composableBuilder(
    column: $table.openThreads,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinal => $composableBuilder(
    column: $table.isFinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeriesTableTableOrderingComposer get seriesId {
    final $$SeriesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableOrderingComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BeatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeatsTable> {
  $$BeatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get childId =>
      $composableBuilder(column: $table.childId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StoryIntent, int> get intent =>
      $composableBuilder(column: $table.intent, builder: (column) => column);

  GeneratedColumn<String> get chosenTwist => $composableBuilder(
    column: $table.chosenTwist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storyText =>
      $composableBuilder(column: $table.storyText, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get narrationJson => $composableBuilder(
    column: $table.narrationJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AgeRating, int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get setting =>
      $composableBuilder(column: $table.setting, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get characters =>
      $composableBuilder(
        column: $table.characters,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get openThreads =>
      $composableBuilder(
        column: $table.openThreads,
        builder: (column) => column,
      );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<bool> get isFinal =>
      $composableBuilder(column: $table.isFinal, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SeriesTableTableAnnotationComposer get seriesId {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BeatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BeatsTable,
          BeatRow,
          $$BeatsTableFilterComposer,
          $$BeatsTableOrderingComposer,
          $$BeatsTableAnnotationComposer,
          $$BeatsTableCreateCompanionBuilder,
          $$BeatsTableUpdateCompanionBuilder,
          (BeatRow, $$BeatsTableReferences),
          BeatRow,
          PrefetchHooks Function({bool seriesId})
        > {
  $$BeatsTableTableManager(_$AppDatabase db, $BeatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BeatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BeatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BeatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<StoryIntent> intent = const Value.absent(),
                Value<String?> chosenTwist = const Value.absent(),
                Value<String> storyText = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> chapterTitle = const Value.absent(),
                Value<String> narrationJson = const Value.absent(),
                Value<AgeRating> rating = const Value.absent(),
                Value<String> setting = const Value.absent(),
                Value<List<String>> characters = const Value.absent(),
                Value<List<String>> openThreads = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<bool> isFinal = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeatsCompanion(
                id: id,
                seriesId: seriesId,
                childId: childId,
                seq: seq,
                intent: intent,
                chosenTwist: chosenTwist,
                storyText: storyText,
                summary: summary,
                chapterTitle: chapterTitle,
                narrationJson: narrationJson,
                rating: rating,
                setting: setting,
                characters: characters,
                openThreads: openThreads,
                language: language,
                isFinal: isFinal,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String seriesId,
                required String childId,
                required int seq,
                required StoryIntent intent,
                Value<String?> chosenTwist = const Value.absent(),
                required String storyText,
                required String summary,
                Value<String> chapterTitle = const Value.absent(),
                Value<String> narrationJson = const Value.absent(),
                required AgeRating rating,
                Value<String> setting = const Value.absent(),
                required List<String> characters,
                required List<String> openThreads,
                Value<String> language = const Value.absent(),
                Value<bool> isFinal = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeatsCompanion.insert(
                id: id,
                seriesId: seriesId,
                childId: childId,
                seq: seq,
                intent: intent,
                chosenTwist: chosenTwist,
                storyText: storyText,
                summary: summary,
                chapterTitle: chapterTitle,
                narrationJson: narrationJson,
                rating: rating,
                setting: setting,
                characters: characters,
                openThreads: openThreads,
                language: language,
                isFinal: isFinal,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BeatsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({seriesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (seriesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.seriesId,
                                referencedTable: $$BeatsTableReferences
                                    ._seriesIdTable(db),
                                referencedColumn: $$BeatsTableReferences
                                    ._seriesIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BeatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BeatsTable,
      BeatRow,
      $$BeatsTableFilterComposer,
      $$BeatsTableOrderingComposer,
      $$BeatsTableAnnotationComposer,
      $$BeatsTableCreateCompanionBuilder,
      $$BeatsTableUpdateCompanionBuilder,
      (BeatRow, $$BeatsTableReferences),
      BeatRow,
      PrefetchHooks Function({bool seriesId})
    >;
typedef $$StoryImagesTableCreateCompanionBuilder =
    StoryImagesCompanion Function({
      required String id,
      required String seriesId,
      Value<String?> beatId,
      required StoryImageKind kind,
      required String fileKey,
      required String prompt,
      Value<int?> seed,
      Value<String> model,
      Value<String> size,
      Value<String> aspect,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$StoryImagesTableUpdateCompanionBuilder =
    StoryImagesCompanion Function({
      Value<String> id,
      Value<String> seriesId,
      Value<String?> beatId,
      Value<StoryImageKind> kind,
      Value<String> fileKey,
      Value<String> prompt,
      Value<int?> seed,
      Value<String> model,
      Value<String> size,
      Value<String> aspect,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$StoryImagesTableReferences
    extends BaseReferences<_$AppDatabase, $StoryImagesTable, StoryImageRow> {
  $$StoryImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SeriesTableTable _seriesIdTable(_$AppDatabase db) =>
      db.seriesTable.createAlias('story_images__series_id__series__id');

  $$SeriesTableTableProcessedTableManager get seriesId {
    final $_column = $_itemColumn<String>('series_id')!;

    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StoryImagesTableFilterComposer
    extends Composer<_$AppDatabase, $StoryImagesTable> {
  $$StoryImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beatId => $composableBuilder(
    column: $table.beatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StoryImageKind, StoryImageKind, int>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get fileKey => $composableBuilder(
    column: $table.fileKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SeriesTableTableFilterComposer get seriesId {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoryImagesTable> {
  $$StoryImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beatId => $composableBuilder(
    column: $table.beatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileKey => $composableBuilder(
    column: $table.fileKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeriesTableTableOrderingComposer get seriesId {
    final $$SeriesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableOrderingComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoryImagesTable> {
  $$StoryImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get beatId =>
      $composableBuilder(column: $table.beatId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StoryImageKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get fileKey =>
      $composableBuilder(column: $table.fileKey, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get aspect =>
      $composableBuilder(column: $table.aspect, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SeriesTableTableAnnotationComposer get seriesId {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoryImagesTable,
          StoryImageRow,
          $$StoryImagesTableFilterComposer,
          $$StoryImagesTableOrderingComposer,
          $$StoryImagesTableAnnotationComposer,
          $$StoryImagesTableCreateCompanionBuilder,
          $$StoryImagesTableUpdateCompanionBuilder,
          (StoryImageRow, $$StoryImagesTableReferences),
          StoryImageRow,
          PrefetchHooks Function({bool seriesId})
        > {
  $$StoryImagesTableTableManager(_$AppDatabase db, $StoryImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<String?> beatId = const Value.absent(),
                Value<StoryImageKind> kind = const Value.absent(),
                Value<String> fileKey = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<int?> seed = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> size = const Value.absent(),
                Value<String> aspect = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryImagesCompanion(
                id: id,
                seriesId: seriesId,
                beatId: beatId,
                kind: kind,
                fileKey: fileKey,
                prompt: prompt,
                seed: seed,
                model: model,
                size: size,
                aspect: aspect,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String seriesId,
                Value<String?> beatId = const Value.absent(),
                required StoryImageKind kind,
                required String fileKey,
                required String prompt,
                Value<int?> seed = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> size = const Value.absent(),
                Value<String> aspect = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryImagesCompanion.insert(
                id: id,
                seriesId: seriesId,
                beatId: beatId,
                kind: kind,
                fileKey: fileKey,
                prompt: prompt,
                seed: seed,
                model: model,
                size: size,
                aspect: aspect,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoryImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({seriesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (seriesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.seriesId,
                                referencedTable: $$StoryImagesTableReferences
                                    ._seriesIdTable(db),
                                referencedColumn: $$StoryImagesTableReferences
                                    ._seriesIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StoryImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoryImagesTable,
      StoryImageRow,
      $$StoryImagesTableFilterComposer,
      $$StoryImagesTableOrderingComposer,
      $$StoryImagesTableAnnotationComposer,
      $$StoryImagesTableCreateCompanionBuilder,
      $$StoryImagesTableUpdateCompanionBuilder,
      (StoryImageRow, $$StoryImagesTableReferences),
      StoryImageRow,
      PrefetchHooks Function({bool seriesId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChildProfilesTableTableManager get childProfiles =>
      $$ChildProfilesTableTableManager(_db, _db.childProfiles);
  $$QuizResultsTableTableManager get quizResults =>
      $$QuizResultsTableTableManager(_db, _db.quizResults);
  $$InterestsTableTableManager get interests =>
      $$InterestsTableTableManager(_db, _db.interests);
  $$LearnedProfilesTableTableManager get learnedProfiles =>
      $$LearnedProfilesTableTableManager(_db, _db.learnedProfiles);
  $$WorldsTableTableManager get worlds =>
      $$WorldsTableTableManager(_db, _db.worlds);
  $$StoryCharactersTableTableManager get storyCharacters =>
      $$StoryCharactersTableTableManager(_db, _db.storyCharacters);
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db, _db.seriesTable);
  $$BeatsTableTableManager get beats =>
      $$BeatsTableTableManager(_db, _db.beats);
  $$StoryImagesTableTableManager get storyImages =>
      $$StoryImagesTableTableManager(_db, _db.storyImages);
}
