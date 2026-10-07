/// Cut Gemini's C2PA manifest out of narration that was saved with it inside.
///
/// Every 3.8 WAV ends with a `C2PA` chunk — about 6 KB of signed Content
/// Credentials. The polish used to read "everything after byte 44" as sound,
/// wrote the manifest back *into the audio*, and it played as ~126 ms of loud
/// noise: the pop of static at the end of paragraphs and in the Lunii
/// navigation. New audio is cleaned at the door now; this repairs what was
/// saved before.
///
/// **Found by correlation with a genuine manifest, not by its text.** The
/// first version looked for the manifest's text ("C2PA", "jumb") and missed
/// clips where none survived: the polish changes levels, and the de-click
/// reshapes exactly what a manifest is full of — sudden jumps next to runs of
/// zeros — so the text went while the noise stayed. "The last story you
/// repaired still has static in a few places." A genuine manifest is taken
/// from one fresh reply; most of it is Google's signing certificate chain,
/// identical in every reply. Normalised correlation ignores any level change,
/// needs no text, and cannot match speech. A clip where blocks of that
/// manifest line up near its end is cut where the manifest begins, and the
/// new end faded to silence.
///
///     dart run tool/strip_c2pa.dart            # report only
///     dart run tool/strip_c2pa.dart --write    # repair, originals backed up
///
/// Cache keys are untouched: each file is rewritten under its own name. Costs
/// one very short synthesis, for the reference. Spread across every core.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/tts/audio_compression.dart';

/// Correlated blocks of the reference, in samples.
const int _block = 128;

/// How far from the end of a clip to look. The manifest was appended last
/// and is ~126 ms; the polish may have pushed it back behind a lengthened
/// pause, so this allows well beyond that.
const int _searchSamples = 24000 * 2;

/// A block counts as found above this correlation. Speech against a
/// certificate never comes near it; the real thing scores 0.95 to 1.000.
const double _match = 0.9;

/// A C2PA chunk, header included, as 16-bit samples — from an untouched raw
/// reply saved on disk when there is one (the probes save them to the
/// desktop), otherwise from one fresh reply.
Future<Int16List> _reference() async {
  final saved = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\moonloom-voices',
  );
  if (saved.existsSync()) {
    for (final f in saved.listSync().whereType<File>()) {
      if (!f.path.endsWith('raw.wav')) continue;
      final found = _chunkOf(f.readAsBytesSync());
      if (found != null) return found;
    }
  }
  return _freshReference();
}

/// The C2PA chunk of [wav] as samples, or null.
Int16List? _chunkOf(Uint8List wav) {
  final v = ByteData.sublistView(wav);
  var at = 12;
  while (at + 8 <= wav.length) {
    final id = String.fromCharCodes(wav, at, at + 4);
    final size = v.getUint32(at + 4, Endian.little);
    if (id == 'C2PA') {
      final n = (8 + size) ~/ 2;
      return Int16List.fromList([
        for (var i = 0; i < n; i++) v.getInt16(at + i * 2, Endian.little),
      ]);
    }
    at += 8 + size + (size & 1);
  }
  return null;
}

Future<Int16List> _freshReference() async {
  final prefs =
      jsonDecode(
            await File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  final key = dpapiUnprotect(
    base64.decode(prefs['flutter.enckey_gemini'] as String),
  );
  final r = await http.post(
    Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
    headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
    body: jsonEncode({
      'model': 'gemini-3.8-flash-lite-tts',
      'input': [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'Goodnight.'},
          ],
        },
      ],
      'response_format': {'type': 'audio'},
      'generation_config': {
        'speech_config': [
          {'voice': 'Sulafat'},
        ],
      },
    }),
  );
  if (r.statusCode != 200) throw StateError('reference: ${r.statusCode}');
  late Uint8List wav;
  for (final s in ((jsonDecode(r.body) as Map)['steps'] as List).cast<Map>()) {
    for (final p in (s['content'] as List? ?? []).cast<Map>()) {
      if (p['type'] == 'audio') wav = base64.decode(p['data'] as String);
    }
  }
  final v = ByteData.sublistView(wav);
  var at = 12;
  while (at + 8 <= wav.length) {
    final id = String.fromCharCodes(wav, at, at + 4);
    final size = v.getUint32(at + 4, Endian.little);
    if (id == 'C2PA') {
      final n = (8 + size) ~/ 2;
      return Int16List.fromList([
        for (var i = 0; i < n; i++) v.getInt16(at + i * 2, Endian.little),
      ]);
    }
    at += 8 + size + (size & 1);
  }
  throw StateError('the reply carried no C2PA chunk to use as a reference');
}

double _ncc(Int16List a, int ai, Int16List b, int bi) {
  var ab = 0.0, aa = 0.0, bb = 0.0;
  for (var k = 0; k < _block; k++) {
    final x = a[ai + k].toDouble(), y = b[bi + k].toDouble();
    ab += x * y;
    aa += x * x;
    bb += y * y;
  }
  return aa == 0 || bb == 0 ? 0 : ab / sqrt(aa * bb);
}

/// Where the manifest starts in [s], or null if it is not there.
///
/// Each block of the reference that is found implies a start (its position
/// minus its offset in the manifest). Two blocks agreeing on that start is
/// proof; the earliest agreed start is where the cut goes.
int? _manifestStart(Int16List s, Int16List ref) {
  final from = max(0, s.length - _searchSamples);
  final starts = <int>[];
  for (var r = 0; r + _block <= ref.length; r += _block) {
    // Blocks of all zeros or near-constant carry no shape to match.
    var energy = 0.0;
    for (var k = 0; k < _block; k++) {
      energy += ref[r + k].toDouble() * ref[r + k];
    }
    if (energy < _block * 1e6) continue;
    var best = 0.0, at = -1;
    for (var i = from; i + _block <= s.length; i++) {
      final c = _ncc(ref, r, s, i);
      if (c > best) {
        best = c;
        at = i;
      }
    }
    if (best > _match) starts.add(at - r);
  }
  if (starts.isEmpty) return null;
  starts.sort();
  for (var i = 1; i < starts.length; i++) {
    if ((starts[i] - starts[i - 1]).abs() <= 4) {
      return max(0, starts.first);
    }
  }
  return null;
}

typedef _Result = ({
  int looked,
  int cut,
  double removedMs,
  double longestMs,
  List<String> names,
});

_Result _work(List<String> paths, Int16List ref, bool write, String backup) {
  var looked = 0, cut = 0;
  var removedMs = 0.0;
  var longestMs = 0.0;
  final names = <String>[];
  for (final path in paths) {
    final file = File(path);
    Uint8List wav;
    try {
      wav = decompressAudio(file.readAsBytesSync());
    } catch (_) {
      continue;
    }
    if (wav.length < 52 || String.fromCharCodes(wav, 0, 4) != 'RIFF') {
      continue;
    }
    looked++;
    final v = ByteData.sublistView(wav);
    final s = Int16List((wav.length - 44) ~/ 2);
    for (var i = 0; i < s.length; i++) {
      s[i] = v.getInt16(44 + i * 2, Endian.little);
    }
    final start = _manifestStart(s, ref);
    if (start == null) continue;
    cut++;
    removedMs += (s.length - start) / 24;
    longestMs = max(longestMs, (s.length - start) / 24);
    names.add(file.uri.pathSegments.last);
    if (!write) continue;

    // Keep the sound before the manifest, and fade its last 120 ms so the
    // cut itself cannot tick.
    final kept = Int16List.fromList(s.sublist(0, start));
    final fade = min(kept.length, 24000 * 120 ~/ 1000);
    for (var i = 0; i < fade; i++) {
      final at = kept.length - fade + i;
      kept[at] = (kept[at] * (1 - i / max(1, fade - 1))).round();
    }
    final out = Uint8List(44 + kept.length * 2);
    out.setRange(0, 44, wav);
    final o = ByteData.sublistView(out);
    o.setUint32(4, 36 + kept.length * 2, Endian.little);
    o.setUint32(40, kept.length * 2, Endian.little);
    for (var i = 0; i < kept.length; i++) {
      o.setInt16(44 + i * 2, kept[i], Endian.little);
    }
    file.copySync('$backup\\${file.uri.pathSegments.last}');
    final tmp = File('${file.path}.tmp')..writeAsBytesSync(compressAudio(out));
    tmp.renameSync(file.path);
  }
  return (
    looked: looked,
    cut: cut,
    removedMs: removedMs,
    longestMs: longestMs,
    names: names,
  );
}

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final dir = Directory(
    '${Platform.environment['USERPROFILE']}\\Documents\\Moonloom\\audio',
  );
  final ref = await _reference();
  stdout.writeln('reference manifest: ${ref.length} samples');

  var backup = '';
  if (write) {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    backup = Directory('${dir.path}.bak-c2pa-$stamp').path;
    Directory(backup).createSync();
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => !f.path.endsWith('.tmp'))
      .map((f) => f.path)
      .toList();
  final cores = max(1, Platform.numberOfProcessors);
  final slices = [
    for (var w = 0; w < cores; w++)
      [for (var i = w; i < files.length; i += cores) files[i]],
  ].where((s) => s.isNotEmpty).toList();

  final watch = Stopwatch()..start();
  final results = await Future.wait([
    for (final slice in slices)
      Isolate.run(() => _work(slice, ref, write, backup)),
  ]);
  final looked = results.fold(0, (n, r) => n + r.looked);
  final cut = results.fold(0, (n, r) => n + r.cut);
  final removed = results.fold(0.0, (n, r) => n + r.removedMs);
  final longest = results.fold(0.0, (n, r) => max(n, r.longestMs));

  stdout.writeln(
    '$looked cached WAV files, '
    '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
  stdout.writeln(
    '  $cut still had a manifest inside their sound'
    '${cut == 0 ? '' : ' (${(removed / cut).round()} ms each on average, the longest ${longest.round()} ms; a manifest is 126)'}',
  );
  for (final n in results.expand((r) => r.names).take(8)) {
    stdout.writeln('    e.g. $n');
  }
  stdout.writeln(
    write
        ? (cut == 0
              ? '\nNothing to repair.'
              : '\nRepaired. Originals of every changed file are in $backup')
        : '\nReport only. Re-run with --write to repair.',
  );
}
