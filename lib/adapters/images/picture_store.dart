/// Where a story's pictures live.
///
/// Same shape as the narration cache, for the same reasons: content-addressed
/// so identical bytes are stored once, on disk rather than in the database
/// because these are megabytes, and outside the backed-up tree because they
/// are large and re-fetchable in principle.
///
/// With one difference that matters. Narration can always be re-synthesised;
/// a picture cannot. The image model does not reproduce a picture from its
/// prompt and seed — measured, not assumed — so **these files are the only
/// copy there will ever be**. Nothing here deletes on a whim, and nothing
/// prunes by age. See `docs/story-images.md`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// A place to put pictures and get them back.
abstract class PictureStore {
  /// The bytes for [key], or null when they are not here.
  Future<Uint8List?> read(String key);

  /// Where [key] lives on disk, whether or not it exists yet. Flutter's
  /// `Image.file` wants a path, not bytes.
  Future<File> fileFor(String key);

  Future<void> write(String key, Uint8List bytes);

  Future<bool> has(String key);
}

/// Files under the library directory, beside the narration cache.
class FilePictureStore implements PictureStore {
  /// Either a [root] directory, or a [resolve] that finds one when it is first
  /// needed. The app passes the second — the library path needs Flutter — and
  /// a `tool/` script passes the first, which is what keeps this file clear of
  /// path_provider and therefore runnable outside Flutter at all.
  FilePictureStore({Directory? root, Future<Directory> Function()? resolve})
    : _root = root, // ignore: prefer_initializing_formals
      _resolve = resolve; // ignore: prefer_initializing_formals

  final Directory? _root;
  final Future<Directory> Function()? _resolve;
  Directory? _resolved;

  /// Resolved lazily rather than in the constructor, so this can be built from
  /// a synchronous provider. A `tool/` script passes [root] explicitly and the
  /// Flutter-only default below never runs.
  Future<Directory> _dir() async {
    if (_resolved != null) return _resolved!;
    final dir =
        _root ??
        await (_resolve?.call() ??
            (throw StateError('FilePictureStore needs a root or a resolver')));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _resolved = dir;
  }

  @override
  Future<File> fileFor(String key) async =>
      File(p.join((await _dir()).path, key));

  @override
  Future<Uint8List?> read(String key) async {
    final file = await fileFor(key);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> has(String key) async => (await fileFor(key)).existsSync();

  @override
  Future<void> write(String key, Uint8List bytes) async {
    // Written to a temporary name and renamed, so a half-downloaded picture
    // is never visible under its real key — the rename is atomic, the write
    // is not, and a truncated PNG would look like a corrupt memory rather
    // than a missing one.
    final target = await fileFor(key);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  }
}
