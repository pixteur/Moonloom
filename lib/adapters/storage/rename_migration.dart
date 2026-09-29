/// Carrying a family's library across the app's change of name.
///
/// The app was called Sleepytime and is now called Moonloom, and on Windows
/// the name is not only a label — it decides where the data lives.
/// `getApplicationSupportDirectory()` is built from the executable's
/// CompanyName and ProductName, so renaming the app silently points it at an
/// empty folder: no saved API keys, no narration, no settings. The library in
/// Documents is named too, and so is the database file.
///
/// A rename that loses a child's stories is not a rename, it is a deletion
/// with a nice name. So this runs once, before anything is opened, and carries
/// the old install across.
///
/// Three rules it keeps:
///
///   * **Copy, never move.** If anything here goes wrong the old install is
///     still sitting there intact, and a parent can be talked through it.
///     Disk is cheap; a year of bedtime stories is not.
///   * **Never overwrite.** Anything already present under the new name wins.
///     Running twice must do nothing the second time, and a family who has
///     already used Moonloom must not have it replaced by an older Sleepytime.
///   * **Best effort, never fatal.** A locked file or a missing folder leaves
///     the app starting empty rather than not starting at all.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the old install kept things, and where the new one looks.
class RenamePaths {
  const RenamePaths({
    required this.oldSupport,
    required this.newSupport,
    required this.documents,
    this.oldLibrary = 'Sleepytime',
    this.newLibrary = 'Moonloom',
    this.oldDatabase = 'sleepytime.sqlite',
    this.newDatabase = 'moonloom.sqlite',
  });

  /// `%APPDATA%\<company>\<product>` — prefs (including the encrypted API
  /// keys) and the narration cache.
  final Directory oldSupport;
  final Directory newSupport;

  /// The Documents folder, holding the library directory and the database.
  final Directory documents;

  final String oldLibrary;
  final String newLibrary;
  final String oldDatabase;
  final String newDatabase;
}

/// What the migration did, so it can be logged and tested.
class RenameOutcome {
  const RenameOutcome({
    required this.filesCopied,
    required this.bytesCopied,
    required this.skipped,
  });

  final int filesCopied;
  final int bytesCopied;

  /// Why nothing happened, when nothing happened.
  final String? skipped;

  bool get didAnything => filesCopied > 0;

  @override
  String toString() => skipped != null
      ? 'nothing to carry over: $skipped'
      : 'carried $filesCopied files '
            '(${(bytesCopied / 1024 / 1024).toStringAsFixed(1)} MB)';
}

/// Carry a Sleepytime install into Moonloom. Safe to call on every start.
Future<RenameOutcome> carryOverFromOldName(RenamePaths paths) async {
  var files = 0;
  var bytes = 0;

  // The database first: it is the thing whose absence is most obvious, and
  // everything else is only useful alongside it.
  final oldDb = File(p.join(paths.documents.path, paths.oldDatabase));
  final newDb = File(p.join(paths.documents.path, paths.newDatabase));
  if (!oldDb.existsSync() && !_hasAnything(paths.oldSupport)) {
    return const RenameOutcome(
      filesCopied: 0,
      bytesCopied: 0,
      skipped: 'no earlier install found',
    );
  }
  if (oldDb.existsSync() && !newDb.existsSync()) {
    try {
      await oldDb.copy(newDb.path);
      files++;
      bytes += oldDb.lengthSync();
    } catch (_) {
      // A locked database means the old app is running. Leaving it is right:
      // copying a database mid-write produces a file that opens and is wrong.
    }
  }

  // The library: stories, audiobooks, pictures, Lunii packs.
  final copiedLibrary = await _copyTree(
    Directory(p.join(paths.documents.path, paths.oldLibrary)),
    Directory(p.join(paths.documents.path, paths.newLibrary)),
  );
  files += copiedLibrary.$1;
  bytes += copiedLibrary.$2;

  // Settings and the narration cache. The prefs file carries the DPAPI-sealed
  // provider keys, which are the one thing a parent cannot simply recreate
  // from memory — they would have to go and find them again.
  final copiedSupport = await _copyTree(paths.oldSupport, paths.newSupport);
  files += copiedSupport.$1;
  bytes += copiedSupport.$2;

  return RenameOutcome(filesCopied: files, bytesCopied: bytes, skipped: null);
}

bool _hasAnything(Directory dir) {
  try {
    return dir.existsSync() && dir.listSync().isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Copy everything under [from] into [to], skipping anything already there.
Future<(int, int)> _copyTree(Directory from, Directory to) async {
  if (!from.existsSync()) return (0, 0);
  var files = 0;
  var bytes = 0;
  try {
    if (!to.existsSync()) await to.create(recursive: true);
    await for (final entity in from.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: from.path);
      final target = File(p.join(to.path, relative));
      // Already there: the new install wins, always.
      if (target.existsSync()) continue;
      try {
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
        files++;
        bytes += entity.lengthSync();
      } catch (_) {
        // One unreadable file should not stop the other six hundred.
      }
    }
  } catch (_) {
    // Nor should an unreadable folder stop the app from starting.
  }
  return (files, bytes);
}

/// The concrete paths on this machine.
///
/// The old support directory has to be named by hand: `path_provider` will
/// only ever tell us where the *current* app keeps things, and the whole
/// problem is that the current app has a different name. So the old one is
/// spelled out, and the new one is asked for.
Future<RenamePaths> windowsRenamePaths() async {
  final documents = await getApplicationDocumentsDirectory();
  final newSupport = await getApplicationSupportDirectory();
  final appData = Platform.environment['APPDATA'];
  return RenamePaths(
    oldSupport: Directory(
      p.join(appData ?? newSupport.parent.path, 'com.pixteur', 'sleepytime'),
    ),
    newSupport: newSupport,
    documents: documents,
  );
}
