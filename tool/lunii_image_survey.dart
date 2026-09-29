/// Read-only survey of the images already on an attached Lunii storyteller.
///
/// [docs/lunii-sync.md](../docs/lunii-sync.md) says the device wants "BMP,
/// exactly 320×240, 4-bit RLE4, 16-level greyscale". This measures that claim
/// against every `rf/` asset on the device, so an encoder can be written to
/// what is actually there.
///
/// It reads the BMP file header, the DIB header and the whole palette of each
/// file rather than sampling — the audio survey's first cut looked at one
/// frame per file and drew a confident wrong conclusion, and a header field
/// read in isolation is the same kind of mistake.
///
/// Assets are ciphered over their first 512 bytes with the generic key. A
/// 16-colour BMP's header and palette together are 118 bytes, so both sit
/// inside that sector and both need deciphering first.
///
/// This never opens the device for writing.
///
///     dart run tool/lunii_image_survey.dart F:
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/image/bmp_rle4.dart';
import 'package:moonloom/adapters/lunii/lunii_cipher.dart';

/// BMP compression values, from the `biCompression` field.
const Map<int, String> _compression = {
  0: 'BI_RGB (none)',
  1: 'BI_RLE8',
  2: 'BI_RLE4',
  3: 'BI_BITFIELDS',
};

void main(List<String> args) {
  final root = args.isEmpty ? 'F:' : args.first;

  final pi = File('$root\\.pi').readAsBytesSync();
  final packs = <String>[
    for (var i = 0; i < pi.length; i += 16)
      pi
          .sublist(i + 12, i + 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(),
  ];

  final shapes = <String, int>{};
  final palettes = <String, int>{};
  final dibSizes = <int, int>{};
  var files = 0;
  var notBmp = 0;
  var greyscale = 0;
  var topDown = 0;
  var sizeMismatch = 0;
  var offsetOdd = 0;
  var rleSizeOdd = 0;
  var longestRun = 0;
  var roundTripped = 0;
  var ours = 0;
  var theirs = 0;
  final rle = <String, int>{};
  final escapes = <String, int>{};
  final library = <String, int>{};
  String? samplePalette;

  for (final pack in packs) {
    final dir = Directory('$root\\.content\\$pack\\rf\\000');
    if (!dir.existsSync()) {
      stdout.writeln('$pack  no rf/000');
      continue;
    }
    final images = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final packShapes = <String>{};

    for (final image in images) {
      final raw = image.readAsBytesSync();
      final bytes = luniiDecipher(raw, luniiGenericKey);
      files++;
      if (bytes.length < 54 || bytes[0] != 0x42 || bytes[1] != 0x4D) {
        notBmp++;
        packShapes.add('not a BMP');
        continue;
      }
      final view = ByteData.sublistView(bytes);
      final declaredSize = view.getUint32(2, Endian.little);
      final pixelOffset = view.getUint32(10, Endian.little);
      final dibSize = view.getUint32(14, Endian.little);
      final width = view.getInt32(18, Endian.little);
      final height = view.getInt32(22, Endian.little);
      final bitCount = view.getUint16(28, Endian.little);
      final compression = view.getUint32(30, Endian.little);
      final clrUsed = view.getUint32(46, Endian.little);

      dibSizes[dibSize] = (dibSizes[dibSize] ?? 0) + 1;
      if (declaredSize != bytes.length) sizeMismatch++;
      if (height < 0) topDown++;

      // A bottom-up BMP is the norm; height is stored negated for top-down.
      final shape =
          '${width}x${height.abs()} ${bitCount}bpp '
          '${_compression[compression] ?? 'unknown($compression)'}';
      shapes[shape] = (shapes[shape] ?? 0) + 1;
      packShapes.add(shape);

      // The palette follows the DIB header: clrUsed BGRA quads, or the full
      // 2^bitCount when clrUsed is 0.
      final entries = clrUsed != 0 ? clrUsed : (1 << bitCount);
      final paletteAt = 14 + dibSize;
      if (bitCount > 8 || paletteAt + entries * 4 > bytes.length) continue;
      if (paletteAt + entries * 4 != pixelOffset) offsetOdd++;

      final palette = bytes.sublist(paletteAt, paletteAt + entries * 4);
      var isGrey = true;
      for (var i = 0; i < entries; i++) {
        final b = palette[i * 4],
            g = palette[i * 4 + 1],
            r = palette[i * 4 + 2];
        if (r != g || g != b) isGrey = false;
      }
      if (isGrey) greyscale++;
      final key = _describePalette(palette, entries, isGrey);
      palettes[key] = (palettes[key] ?? 0) + 1;
      samplePalette ??= [
        for (var i = 0; i < entries; i++)
          '0x${palette[i * 4 + 2].toRadixString(16).padLeft(2, '0')}',
      ].join(' ');

      // Walk the RLE stream itself. Reading the header only tells us what the
      // file claims to be; decoding says whether it is, and which of RLE4's
      // escapes an encoder actually has to emit.
      final declaredPixels = view.getUint32(34, Endian.little);
      if (declaredPixels != bytes.length - pixelOffset) rleSizeOdd++;
      final walk = _walkRle4(bytes, pixelOffset, width, height.abs());
      rle[walk.verdict] = (rle[walk.verdict] ?? 0) + 1;
      for (final escape in walk.escapes) {
        escapes[escape] = (escapes[escape] ?? 0) + 1;
      }
      if (walk.runs > 0) {
        longestRun = walk.longest > longestRun ? walk.longest : longestRun;
      }

      // Now put the library through the same file. Decoding all 199 is the
      // real check on `bmp_rle4.dart`, and re-encoding what came out says
      // whether the encoder is faithful and how its compression compares to
      // whatever produced these.
      try {
        final decoded = decodeBmpRle4(bytes);
        final reencoded = encodeBmpRle4(decoded);
        final round = decodeBmpRle4(reencoded);
        if (_samePixels(decoded, round)) {
          roundTripped++;
        } else {
          library['re-encode changed pixels'] =
              (library['re-encode changed pixels'] ?? 0) + 1;
        }
        ours += reencoded.length;
        theirs += bytes.length;
      } on BmpFormatException catch (e) {
        library['decode failed: ${e.message}'] =
            (library['decode failed: ${e.message}'] ?? 0) + 1;
      }
    }

    stdout.writeln(
      '$pack  ${images.length.toString().padLeft(3)} images  '
      '${packShapes.join(' / ')}',
    );
  }

  stdout.writeln('\n── $files images across ${packs.length} packs ──');
  for (final e in shapes.entries) {
    stdout.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }
  stdout.writeln('  palettes:');
  for (final e in palettes.entries) {
    stdout.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }
  stdout.writeln(
    '  DIB header: ${dibSizes.entries.map((e) => '${e.key}B×${e.value}').join(' ')}',
  );
  stdout.writeln(
    '  greyscale palette: $greyscale/$files    not a BMP: $notBmp    '
    'top-down: $topDown',
  );
  stdout.writeln(
    '  declared size != actual: $sizeMismatch    '
    'pixel data not straight after palette: $offsetOdd',
  );
  stdout.writeln('  RLE4 decode:');
  for (final e in rle.entries) {
    stdout.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }
  stdout.writeln(
    '  escapes used: ${escapes.entries.map((e) => '${e.key}×${e.value}').join('  ')}',
  );
  stdout.writeln(
    '  longest single run: $longestRun px    '
    'biSizeImage != pixel bytes: $rleSizeOdd',
  );
  if (samplePalette != null) {
    stdout.writeln('  first palette seen (grey levels): $samplePalette');
  }

  stdout.writeln(
    '\n── lib/adapters/image/bmp_rle4.dart against the same files ──',
  );
  stdout.writeln('  decoded and re-encoded intact: $roundTripped/$files');
  for (final e in library.entries) {
    stdout.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }
  if (theirs > 0) {
    stdout.writeln(
      '  size: ours ${(ours / 1024).round()} kB vs theirs '
      '${(theirs / 1024).round()} kB '
      '(${(100 * ours / theirs).round()}%)',
    );
  }
}

bool _samePixels(IndexedImage a, IndexedImage b) {
  if (a.width != b.width || a.height != b.height) return false;
  for (var i = 0; i < a.pixels.length; i++) {
    if (a.pixels[i] != b.pixels[i]) return false;
  }
  return true;
}

class _RleWalk {
  const _RleWalk(this.verdict, this.escapes, this.runs, this.longest);
  final String verdict;
  final Set<String> escapes;
  final int runs;
  final int longest;
}

/// Decode a BI_RLE4 stream far enough to say whether it really covers the
/// whole bitmap, and which of the format's escapes it leans on.
///
/// RLE4 is a run of pairs. A non-zero first byte is a run: that many pixels,
/// alternating the two nibbles of the second byte. A zero first byte is an
/// escape — 0 end of line, 1 end of bitmap, 2 a delta jump, and 3 or more an
/// absolute run of that many nibble-packed indices, padded to a 2-byte
/// boundary.
_RleWalk _walkRle4(Uint8List bytes, int start, int width, int height) {
  final seen = <String>{};
  var at = start;
  var x = 0, y = 0, runs = 0, longest = 0, pixels = 0;

  while (at + 1 < bytes.length) {
    final count = bytes[at];
    final value = bytes[at + 1];
    at += 2;
    if (count > 0) {
      runs++;
      if (count > longest) longest = count;
      x += count;
      pixels += count;
      continue;
    }
    switch (value) {
      case 0:
        seen.add('end-of-line');
        x = 0;
        y++;
      case 1:
        seen.add('end-of-bitmap');
        return _RleWalk(
          pixels == width * height && at == bytes.length
              ? 'exact: $width×$height, ends cleanly'
              : 'pixels=$pixels/${width * height}, '
                    '${bytes.length - at} trailing bytes',
          seen,
          runs,
          longest,
        );
      case 2:
        if (at + 1 >= bytes.length) {
          return _RleWalk('truncated delta', seen, runs, longest);
        }
        seen.add('delta');
        x += bytes[at];
        y += bytes[at + 1];
        at += 2;
      default:
        seen.add('absolute');
        // `value` nibbles, packed two per byte and padded to 16 bits.
        final byteCount = ((value + 1) ~/ 2 + 1) & ~1;
        at += byteCount;
        x += value;
        pixels += value;
    }
  }
  return _RleWalk('ran off the end at y=$y x=$x', seen, runs, longest);
}

/// Collapse a palette to a description, so identical ones tally together.
String _describePalette(Uint8List palette, int entries, bool isGrey) {
  if (!isGrey) return '$entries entries, not greyscale';
  final levels = [for (var i = 0; i < entries; i++) palette[i * 4 + 2]];
  final evenRamp = () {
    if (entries < 2) return false;
    final step = 255 / (entries - 1);
    for (var i = 0; i < entries; i++) {
      if ((levels[i] - (i * step).round()).abs() > 1) return false;
    }
    return true;
  }();
  final ascending = [...levels]..sort();
  final sameSet = List.generate(entries, (i) => levels[i] == ascending[i]);
  return '$entries grey levels, '
      '${evenRamp ? 'even 0→255 ramp' : 'uneven'}, '
      '${sameSet.every((v) => v) ? 'ascending' : 'not in order'} '
      '(${levels.first}…${levels.last})';
}
