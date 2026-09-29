/// One picture per slot: remove rows that pre-date that rule.
///
/// Illustrating a story twice used to leave the first attempt's rows behind,
/// pointing at the same files, and the reader picked one of them at random.
/// The service enforces it now; this clears what was written before it did.
///
///     dart run tool/dedupe_images.dart            # show what would go
///     dart run tool/dedupe_images.dart --write
library;

import 'dart:io';

import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final db = AppDatabase.openIn(
    r''
    '${Platform.environment['USERPROFILE']}'
    r'\Documents',
  );
  final repo = DriftStorageRepo(db);

  var removed = 0;
  for (final child in await repo.loadProfiles()) {
    for (final series in await repo.loadSeries(child.id)) {
      final images = await repo.loadImages(series.id);
      final seen = <String>{};
      // Newest wins: loadImages orders by creation, so walking backwards keeps
      // the most recent picture for each slot.
      for (final image in images.reversed) {
        final slot = '${image.kind.name}|${image.beatId ?? 'cover'}';
        if (seen.add(slot)) continue;
        stdout.writeln(
          '  ${series.title.padRight(30)} ${slot.padRight(20)} '
          '${image.fileKey}',
        );
        removed++;
        if (write) await repo.deleteImage(image.id);
      }
    }
  }

  stdout.writeln(
    removed == 0
        ? 'Nothing duplicated.'
        : write
        ? '\nRemoved $removed duplicate rows. Files were left alone — they are '
              'content-addressed and still referenced by the row that stayed.'
        : '\n$removed duplicate rows. Re-run with --write.',
  );
  await db.close();
}
