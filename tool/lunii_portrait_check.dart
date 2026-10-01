/// Does a drawn portrait survive the storyteller's screen?
///
/// Tests cannot answer this. They can prove the reduction returns 320×240 with
/// at most sixteen colours — and it will do that for a picture that arrives as
/// an unreadable smear, because "legal" and "a face a child recognises" are
/// different properties and only one of them is checkable in code.
///
/// So this asks the real image model for real portraits of the real cast, puts
/// them through the real reduction, and writes both out to look at: the 2K PNG
/// and the sixteen-colour version blown back up to the size of a thumbnail, so
/// the two sit side by side. It also measures the things that *are* numbers —
/// how many of the sixteen colours got used, how far apart they are, and how
/// much of the frame the subject fills.
///
///     dart run tool/lunii_portrait_check.dart --child Mia
///     dart run tool/lunii_portrait_check.dart --child Mia --world "Pip's Adventures"
///     dart run tool/lunii_portrait_check.dart --child Mia --save
///
/// Leaves the library as it found it unless `--save`, which keeps each
/// portrait as the story's device picture the way a send would. A dry run
/// still *draws* — that is the only way to see anything — so it costs one
/// picture per story either way; it writes the files to the desktop and undoes
/// the rows it added.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:moonloom/adapters/export/lunii_portrait.dart';
import 'dart:typed_data';

import 'package:moonloom/adapters/image/bmp_rle4.dart';
import 'package:moonloom/adapters/images/picture_store.dart';
import 'package:moonloom/adapters/images/story_illustrator.dart';
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/cast_line.dart';
import 'package:moonloom/domain/illustration_service.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/story_image.dart';
import 'package:moonloom/domain/picture_prompt.dart';

class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

  static Future<_StoredKeys> open() async {
    final file = File(
      '${Platform.environment['APPDATA']}'
      r'\com.pixteur\moonloom\shared_preferences.json',
    );
    if (!file.existsSync()) throw StateError('No prefs at ${file.path}');
    return _StoredKeys(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  final Map<String, dynamic> _prefs;

  @override
  Future<String?> readKey(String providerId) async {
    final stored = _prefs['flutter.enckey_$providerId'] as String?;
    if (stored == null) return null;
    try {
      return dpapiUnprotect(base64.decode(stored));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasKey(String id) async => _prefs['flutter.enckey_$id'] != null;
  @override
  Future<void> writeKey(String id, String key) async =>
      throw UnsupportedError('read-only');
  @override
  Future<void> deleteKey(String id) async =>
      throw UnsupportedError('read-only');
}

/// Writes into a folder on the desktop and nowhere the app reads, so looking at
/// these cannot disturb the library.
class _Scratch implements PictureStore {
  _Scratch(this.dir, this._real);

  final Directory dir;
  final PictureStore _real;

  /// Reads fall through to the real store: the character sheets this needs as
  /// references are already drawn and already paid for.
  @override
  Future<Uint8List?> read(String key) async =>
      await _real.read(key) ?? _localOf(key);
  @override
  Future<bool> has(String key) async =>
      await _real.has(key) || _file(key).existsSync();
  @override
  Future<void> write(String key, Uint8List bytes) async =>
      _file(key).writeAsBytesSync(bytes);
  @override
  Future<File> fileFor(String key) async => _file(key);

  File _file(String key) => File('${dir.path}\\$key');
  Uint8List? _localOf(String key) {
    final f = _file(key);
    return f.existsSync() ? f.readAsBytesSync() : null;
  }
}

String? _opt(List<String> args, String name) {
  final at = args.indexOf(name);
  return at >= 0 && at + 1 < args.length ? args[at + 1] : null;
}

/// The sixteen-colour version as a PNG, at four times the size with no
/// smoothing — the only honest way to look at a 320×240 picture on a monitor.
Uint8List _preview(IndexedImage reduced) {
  final out = img.Image(width: reduced.width, height: reduced.height);
  for (var y = 0; y < reduced.height; y++) {
    for (var x = 0; x < reduced.width; x++) {
      final c = reduced.palette[reduced.pixels[y * reduced.width + x]];
      out.setPixelRgb(x, y, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
    }
  }
  return Uint8List.fromList(
    img.encodePng(
      img.copyResize(
        out,
        width: reduced.width * 4,
        height: reduced.height * 4,
        interpolation: img.Interpolation.nearest,
      ),
    ),
  );
}

/// How far apart the palette's colours are: the mean distance between every
/// pair. A picture that reduced to sixteen near-identical browns is legal and
/// unreadable, and this is the number that tells them apart.
double _paletteSpread(IndexedImage image) {
  final colours = image.palette;
  if (colours.length < 2) return 0;
  var total = 0.0;
  var pairs = 0;
  for (var i = 0; i < colours.length; i++) {
    for (var j = i + 1; j < colours.length; j++) {
      final a = colours[i], b = colours[j];
      final dr = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF);
      final dg = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF);
      final db = (a & 0xFF) - (b & 0xFF);
      total += (dr * dr + dg * dg + db * db) / 3;
      pairs++;
    }
  }
  return total / pairs;
}

/// What fraction of the frame the most common colour takes.
///
/// The prompt asks for a plain single-colour background with the subject
/// filling most of the frame, which means one colour should be large but not
/// overwhelming. Nine tenths of the picture in one colour is a dot on a wall.
double _dominantShare(IndexedImage image) {
  final counts = List<int>.filled(image.palette.length, 0);
  for (final index in image.pixels) {
    counts[index]++;
  }
  return counts.reduce((a, b) => a > b ? a : b) / image.pixels.length;
}

Future<void> main(List<String> args) async {
  final save = args.contains('--save');
  final childName = _opt(args, '--child') ?? 'Mia';
  final worldName = _opt(args, '--world');
  final limit = int.tryParse(_opt(args, '--stories') ?? '') ?? 3;

  final db = AppDatabase.openIn(
    '${Platform.environment['USERPROFILE']}\\Documents',
  );
  final repo = DriftStorageRepo(db);
  final secrets = await _StoredKeys.open();
  final client = http.Client();

  final children = await repo.loadProfiles();
  final child = children.cast<ChildProfile?>().firstWhere(
    (c) => c!.displayName.toLowerCase() == childName.toLowerCase(),
    orElse: () => null,
  );
  if (child == null) {
    stdout.writeln('No child called $childName.');
    await db.close();
    return;
  }

  final worlds = await repo.loadWorlds(child.id);
  final chosen = worldName == null
      ? worlds
      : worlds
            .where((w) => w.name.toLowerCase() == worldName.toLowerCase())
            .toList();
  if (chosen.isEmpty) {
    stdout.writeln('No world of ${child.displayName}\'s matching $worldName.');
    await db.close();
    return;
  }

  final out = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\moonloom-lunii-portraits',
  )..createSync(recursive: true);
  final real = FilePictureStore(
    root: Directory(
      '${Platform.environment['USERPROFILE']}'
      r'\Documents\Moonloom\pictures',
    ),
  );
  final pictures = save ? real : _Scratch(out, real);
  final service = IllustrationService(
    illustrator: GeminiIllustrator(secrets: secrets, httpClient: client),
    pictures: pictures,
    repo: repo,
  );

  stdout.writeln('child:   ${child.displayName}');
  stdout.writeln('writing: ${out.path}');
  stdout.writeln(save ? 'saving:  as each story\'s device picture' : '');

  var drawn = 0;
  for (final world in chosen) {
    final cast = await repo.loadCharacters(world.id);
    final series = (await repo.loadSeries(
      child.id,
    )).where((s) => s.worldId == world.id).take(limit).toList();
    if (series.isEmpty) continue;

    stdout.writeln('\n${world.name}  (${cast.length} in the cast)');
    final faces = <String>[];
    for (final story in series) {
      final beats = await repo.loadBeats(story.id);
      if (beats.isEmpty) continue;

      // Said before drawing, because this is the property the whole change is
      // for: two stories in one world must not pick the same face.
      final subject = portraitSubject(
        seriesId: story.id,
        cast: [for (final c in cast) c.promptLine],
        beats: beats,
      );
      final who = subject == null ? '(nobody)' : parseCastEntry(subject).$1;
      faces.add(who);

      // What the library already holds for this story, so a dry run can put it
      // back. `ensureLuniiPortrait` saves a row as well as a file — it is the
      // real one, not a stand-in — and a dry run that left the row behind
      // pointing at a file on the desktop would be a tool that quietly broke
      // the thing it was written to check.
      final before = {
        for (final i in await repo.loadImages(story.id))
          if (i.kind == StoryImageKind.lunii) i.id,
      };

      try {
        final result = await service.ensureLuniiPortrait(
          series: story,
          beats: beats,
          world: world,
          cast: cast,
        );
        if (result == null) {
          stdout.writeln('  ${story.title.padRight(28)} nothing to draw');
          continue;
        }
        final (image, bytes) = result;
        final reduced = luniiImageFromBytes(bytes);
        if (reduced == null) {
          stdout.writeln(
            '  ${story.title.padRight(28)} $who — WOULD NOT REDUCE '
            '(the device would fall back to the world picture)',
          );
          continue;
        }

        // The device's own file, not a lookalike: the same encoder a pack is
        // built with. A picture that reduces but will not encode to RLE4 is
        // one the device never shows.
        final bmp = encodeBmpRle4(reduced);
        final stem = story.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
        File('${out.path}\\$stem-2k.png').writeAsBytesSync(bytes);
        File(
          '${out.path}\\$stem-device.png',
        ).writeAsBytesSync(_preview(reduced));
        File('${out.path}\\$stem-device.bmp').writeAsBytesSync(bmp);
        drawn++;

        stdout.writeln(
          '  ${story.title.padRight(28)} ${who.padRight(10)} '
          '${(bytes.length / 1024).round()} kB → '
          '${reduced.palette.length} colours, '
          'spread ${_paletteSpread(reduced).round()}, '
          'largest ${(_dominantShare(reduced) * 100).round()}%, '
          'bmp ${(bmp.length / 1024).toStringAsFixed(1)} kB'
          '${image.seed == null ? '' : ', seed ${image.seed}'}',
        );
      } catch (e) {
        stdout.writeln('  ${story.title.padRight(28)} $who — failed: $e');
      } finally {
        if (!save) {
          for (final i in await repo.loadImages(story.id)) {
            if (i.kind == StoryImageKind.lunii && !before.contains(i.id)) {
              await repo.deleteImage(i.id);
            }
          }
        }
      }
    }

    final distinct = faces.toSet().length;
    stdout.writeln(
      '  faces: ${faces.join(', ')} '
      '→ $distinct of ${faces.length} distinct'
      '${distinct == 1 && faces.length > 1 ? '   ** every episode wears one face **' : ''}',
    );
  }

  stdout.writeln(
    '\n$drawn portrait${drawn == 1 ? '' : 's'} written. Look at the '
    '*-device.png files: that is what the screen shows, four times up.',
  );
  if (!save) {
    stdout.writeln(
      'Nothing was saved to the library — re-run with --save to keep them.',
    );
  }
  client.close();
  await db.close();
}
