import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's on-device **story library** — one folder tree under the user's
/// Documents so all story assets live together and are easy to find, back up,
/// or share:
///
/// ```
/// <Documents>/Sleepytime/
///   ├── audio/     cached narration (one file per voice + chapter)
///   ├── stories/   exported .sleepy files (text + audio bundles)
///   └── images/    story covers / character art (future)
/// ```
///
/// The Drift database (`sleepytime.sqlite`) stays at the Documents root.
/// See `docs/storage-layout.md`.
class LibraryPaths {
  static const String rootName = 'Sleepytime';

  static Future<Directory> _sub(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, rootName, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Cached narration audio.
  static Future<Directory> audio() => _sub('audio');

  /// Exported `.sleepy` story bundles.
  static Future<Directory> stories() => _sub('stories');

  /// Exported single-file audiobooks (whole story joined into one audio file).
  static Future<Directory> audiobooks() => _sub('audiobooks');

  /// Story pictures. Kept in the library rather than a cache, because unlike
  /// narration a picture cannot be regenerated — the model does not reproduce
  /// one from its prompt, so these files are the only copy there is.
  static Future<Directory> pictures() => _sub('pictures');

  /// Exported Lunii story packs (STUdio archive zips).
  static Future<Directory> luniiPacks() => _sub('lunii');

  /// Story cover / character art (reserved for future use).
  static Future<Directory> images() => _sub('images');

  /// Copies of a storyteller's `.pi` and `.md`, taken before anything is
  /// written to it. Small, and the only way back if a transfer goes wrong.
  static Future<Directory> deviceBackups() => _sub('device-backup');
}
