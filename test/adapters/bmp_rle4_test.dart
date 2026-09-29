import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/export/cover_image.dart';
import 'package:moonloom/adapters/image/bmp_rle4.dart';

/// The format is pinned by what 199 real images on a device turned out to be,
/// so these check the same things `tool/lunii_image_survey.dart` checks:
/// header shape, a stream that decodes to exactly the right pixel count and
/// ends cleanly, runs capped at 255, and no delta escape.
void main() {
  IndexedImage image(
    int width,
    int height,
    int Function(int x, int y) index, {
    int colours = 16,
  }) {
    final pixels = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        pixels[y * width + x] = index(x, y);
      }
    }
    return IndexedImage(
      width: width,
      height: height,
      pixels: pixels,
      palette: [for (var i = 0; i < colours; i++) 0x111111 * i],
    );
  }

  /// The RLE stream, past the 118-byte header and palette.
  Uint8List body(Uint8List bmp) => Uint8List.sublistView(bmp, 118);

  group('header', () {
    final bmp = encodeBmpRle4(image(320, 240, (x, y) => (x ~/ 20) & 0xF));
    final view = ByteData.sublistView(bmp);

    test('is the shape every image on the device has', () {
      expect(String.fromCharCodes(bmp, 0, 2), 'BM');
      expect(view.getUint32(14, Endian.little), 40, reason: 'DIB header');
      expect(view.getInt32(18, Endian.little), 320);
      expect(
        view.getInt32(22, Endian.little),
        240,
        reason: 'positive: bottom-up',
      );
      expect(view.getUint16(28, Endian.little), 4, reason: 'bits per pixel');
      expect(view.getUint32(30, Endian.little), 2, reason: 'BI_RLE4');
      expect(view.getUint32(10, Endian.little), 118, reason: 'pixel offset');
    });

    test('declares its own sizes correctly', () {
      expect(view.getUint32(2, Endian.little), bmp.length, reason: 'bfSize');
      expect(
        view.getUint32(34, Endian.little),
        bmp.length - 118,
        reason: 'biSizeImage',
      );
    });

    test('carries sixteen palette entries, in BGR', () {
      expect(view.getUint32(46, Endian.little), 16);
      // Entry 1 of the test palette is 0x111111.
      expect([bmp[118 - 60], bmp[118 - 59], bmp[118 - 58]], [0x11, 0x11, 0x11]);
    });
  });

  group('the stream', () {
    test('ends with end-of-bitmap', () {
      final bmp = encodeBmpRle4(image(64, 4, (x, y) => 3));
      expect(bmp.sublist(bmp.length - 2), [0x00, 0x01]);
    });

    test('never emits a delta escape', () {
      // Deltas are the one escape no image on the device uses, so the
      // firmware's support for them is unproven.
      final bytes = body(
        encodeBmpRle4(image(320, 240, (x, y) => (x * y) & 0xF)),
      );
      var at = 0;
      while (at + 1 < bytes.length) {
        final count = bytes[at];
        final value = bytes[at + 1];
        at += 2;
        expect(count == 0 && value == 2, isFalse, reason: 'delta at $at');
        if (count == 0 && value >= 3) at += ((value + 1) ~/ 2 + 1) & ~1;
      }
    });

    test('no run exceeds 255 pixels', () {
      // A 700-wide band of one colour has to be split into several runs.
      final bytes = body(encodeBmpRle4(image(700, 2, (x, y) => 5)));
      for (var at = 0; at + 1 < bytes.length; at += 2) {
        expect(bytes[at], lessThanOrEqualTo(255));
      }
      expect(
        decodeBmpRle4(encodeBmpRle4(image(700, 2, (x, y) => 5))).at(699, 1),
        5,
      );
    });

    test('a flat image collapses to almost nothing', () {
      final bmp = encodeBmpRle4(image(320, 240, (x, y) => 7));
      // Two runs plus an end-of-line per row, then end-of-bitmap.
      expect(bmp.length - 118, 240 * 6 + 2);
    });

    test(
      'a two-colour check rides in runs, because runs alternate nibbles',
      () {
        final striped = encodeBmpRle4(
          image(320, 240, (x, y) => x.isEven ? 1 : 2),
        );
        final flat = encodeBmpRle4(image(320, 240, (x, y) => 1));
        expect(striped.length, flat.length);
      },
    );
  });

  group('round trip', () {
    test('a busy image survives exactly', () {
      final source = image(97, 53, (x, y) => (x * 7 + y * 13 + x * y) & 0xF);
      final back = decodeBmpRle4(encodeBmpRle4(source));
      expect(back.width, 97);
      expect(back.height, 53);
      expect(back.pixels, source.pixels);
    });

    test('the palette comes back', () {
      final back = decodeBmpRle4(encodeBmpRle4(image(8, 8, (x, y) => x & 0x7)));
      expect(back.palette.length, 16);
      expect(back.palette[3], 0x333333);
    });

    test('rows are not flipped', () {
      // The bug this catches round-trips perfectly and shows upside down on
      // the device, so it has to be checked in the bytes: BMP stores the
      // bottom row first, so the stream must open with row 1's colour.
      final bmp = encodeBmpRle4(image(64, 2, (x, y) => y == 0 ? 1 : 2));
      expect(body(bmp)[1], 0x22, reason: 'bottom row (index 2) comes first');
      expect(
        decodeBmpRle4(bmp).at(0, 0),
        1,
        reason: 'and decodes back upright',
      );
    });

    test('single pixel, single row and single column all work', () {
      for (final size in [
        [1, 1],
        [1, 40],
        [40, 1],
        [3, 3],
      ]) {
        final source = image(size[0], size[1], (x, y) => (x + y) & 0xF);
        expect(decodeBmpRle4(encodeBmpRle4(source)).pixels, source.pixels);
      }
    });

    test('runs of one and two pixels are not lost', () {
      // Absolute mode needs three, so short tails take a different path.
      for (final width in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final source = image(width, 1, (x, y) => x & 0xF);
        expect(
          decodeBmpRle4(encodeBmpRle4(source)).pixels,
          source.pixels,
          reason: 'width $width',
        );
      }
    });
  });

  group('refuses what it cannot encode', () {
    test('more than sixteen colours', () {
      expect(
        () => encodeBmpRle4(image(4, 4, (x, y) => 0, colours: 17)),
        throwsA(isA<BmpFormatException>()),
      );
    });

    test('a pixel index outside the palette', () {
      expect(
        () => encodeBmpRle4(
          IndexedImage(
            width: 2,
            height: 1,
            pixels: Uint8List.fromList([0, 16]),
            palette: const [0],
          ),
        ),
        throwsA(isA<BmpFormatException>()),
      );
    });

    test('a pixel count that does not match the size', () {
      expect(
        () => encodeBmpRle4(
          IndexedImage(
            width: 4,
            height: 4,
            pixels: Uint8List(9),
            palette: const [0],
          ),
        ),
        throwsA(isA<BmpFormatException>()),
      );
    });
  });

  group('the decoder is stricter about what it is given', () {
    test('rejects a file that is not a BMP', () {
      expect(
        () => decodeBmpRle4(Uint8List(64)),
        throwsA(isA<BmpFormatException>()),
      );
    });

    test('rejects the wrong bit depth and the wrong compression', () {
      final bmp = encodeBmpRle4(image(8, 8, (x, y) => 1));
      final wrongDepth = Uint8List.fromList(bmp);
      ByteData.sublistView(wrongDepth).setUint16(28, 8, Endian.little);
      expect(
        () => decodeBmpRle4(wrongDepth),
        throwsA(isA<BmpFormatException>()),
      );

      final wrongCompression = Uint8List.fromList(bmp);
      ByteData.sublistView(wrongCompression).setUint32(30, 0, Endian.little);
      expect(
        () => decodeBmpRle4(wrongCompression),
        throwsA(isA<BmpFormatException>()),
      );
    });

    test('rejects a stream with no end-of-bitmap', () {
      final bmp = encodeBmpRle4(image(8, 8, (x, y) => 1));
      expect(
        () => decodeBmpRle4(bmp.sublist(0, bmp.length - 2)),
        throwsA(isA<BmpFormatException>()),
      );
    });

    test('reads a top-down image, which we never write', () {
      final bmp = Uint8List.fromList(
        encodeBmpRle4(image(64, 2, (x, y) => y == 0 ? 1 : 2)),
      );
      ByteData.sublistView(bmp).setInt32(22, -2, Endian.little);
      // Same bytes, opposite row order: what was the bottom row is now the top.
      expect(decodeBmpRle4(bmp).at(0, 0), 2);
    });
  });

  group('the night-sky cover', () {
    test('reduces to sixteen colours the device can show', () {
      final cover = nightSkyCoverIndexed(seed: 'Obsidian Stone');
      expect(cover.width, 320);
      expect(cover.height, 240);
      expect(cover.palette.length, 16);
      expect(cover.pixels.every((p) => p < 16), isTrue);
    });

    test('encodes, and comes back unchanged', () {
      final cover = nightSkyCoverIndexed(seed: 'Obsidian Stone');
      final bmp = encodeBmpRle4(cover);
      expect(decodeBmpRle4(bmp).pixels, cover.pixels);
      // The dither alternates between neighbouring sky steps, which is exactly
      // what an RLE4 run encodes, so the whole picture should stay small.
      expect(bmp.length, lessThan(40 * 1024));
    });

    test('the same story always gets the same sky', () {
      expect(
        nightSkyCoverIndexed(seed: 'Obsidian Stone').pixels,
        nightSkyCoverIndexed(seed: 'Obsidian Stone').pixels,
      );
    });

    test('the sky is darkest at the top', () {
      final cover = nightSkyCoverIndexed();
      int brightness(int index) {
        final c = cover.palette[index];
        return ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF);
      }

      // Sample a column well clear of the moon, which sits upper-right.
      expect(
        brightness(cover.at(40, 10)),
        lessThan(brightness(cover.at(40, 230))),
      );
    });

    test('the 24-bit cover still works, for the STUdio zip', () {
      final bmp = nightSkyCover(seed: 'Obsidian Stone');
      expect(String.fromCharCodes(bmp, 0, 2), 'BM');
      expect(ByteData.sublistView(bmp).getUint16(28, Endian.little), 24);
      expect(bmp.length, 54 + 320 * 240 * 3);
    });
  });
}
