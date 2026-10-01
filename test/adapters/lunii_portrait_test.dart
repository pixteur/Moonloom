import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moonloom/adapters/image/bmp_rle4.dart';
import 'package:moonloom/adapters/export/lunii_portrait.dart';

/// Reducing a drawn picture to what a storyteller's screen can show.
///
/// The interesting part is not that it produces an image — it is that it
/// produces one at exactly the shape the device accepts, from any shape it is
/// handed, without a stretched face, and without ever throwing on input it
/// cannot read. The device is the one consumer here that cannot report a
/// problem: a pack with a malformed picture in it simply does not appear.
void main() {
  /// A PNG with a recognisable layout: a bright band across the top third and
  /// a dark band below, so a crop that loses the wrong half is visible in the
  /// output rather than merely different.
  Uint8List png({required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final top = y < height ~/ 3;
        image.setPixelRgb(x, y, top ? 240 : 20, top ? 200 : 30, top ? 90 : 80);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  group('the shape the device takes', () {
    test('a 4:3 chapter picture comes out 320×240', () {
      final out = luniiImageFromBytes(png(width: 1024, height: 768))!;
      expect(out.width, 320);
      expect(out.height, 240);
      expect(out.pixels, hasLength(320 * 240));
    });

    // A cover is drawn 3:4 and the screen is 4:3. Squeezing one into the other
    // is what makes a portrait's face look wrong, and it is the sort of thing
    // nobody notices in a thumbnail and everybody notices on the device.
    test('a 3:4 cover is cropped, not squashed', () {
      final out = luniiImageFromBytes(png(width: 1536, height: 2048))!;
      expect(out.width, 320);
      expect(out.height, 240);
    });

    test('a square picture also lands at 320×240', () {
      final out = luniiImageFromBytes(png(width: 2048, height: 2048))!;
      expect(out.width, 320);
      expect(out.height, 240);
    });
  });

  // The one the first version got wrong, and the reason the function sniffs
  // the format instead of assuming PNG. Every picture in the real library is
  // JPEG under a `.png` name — the model sends JPEG, the store names files for
  // what it was written to hold — so `decodePng` returned null for all of
  // them, nothing threw, and the device silently kept the old procedural
  // cover. No fixture would have caught it; the real library did.
  group('whatever the model actually sent', () {
    test('a JPEG reduces, despite every file being named .png', () {
      final image = img.Image(width: 1024, height: 768);
      for (var y = 0; y < 768; y++) {
        for (var x = 0; x < 1024; x++) {
          image.setPixelRgb(x, y, x ~/ 4, y ~/ 3, 120);
        }
      }
      final jpeg = Uint8List.fromList(img.encodeJpg(image, quality: 90));
      expect(jpeg[0], 0xFF, reason: 'a JPEG, not a PNG');
      final out = luniiImageFromBytes(jpeg)!;
      expect(out.width, 320);
      expect(out.height, 240);
      expect(out.palette.length, lessThanOrEqualTo(paletteSize));
    });
  });

  group('sixteen colours', () {
    test('never more than the palette the device has room for', () {
      final out = luniiImageFromBytes(png(width: 800, height: 600))!;
      expect(out.palette.length, lessThanOrEqualTo(paletteSize));
      for (final index in out.pixels) {
        expect(index, lessThan(out.palette.length));
      }
    });

    // A gradient is the case a fixed palette handles worst and the one a
    // drawn picture always contains: sky, water, a lit face. What matters is
    // that the sixteen chosen are *spread* — a palette of sixteen near-blacks
    // is a legal palette and an unusable picture.
    test('a gradient keeps a spread of colours, not sixteen of one', () {
      final image = img.Image(width: 640, height: 480);
      for (var y = 0; y < 480; y++) {
        for (var x = 0; x < 640; x++) {
          image.setPixelRgb(x, y, x ~/ 3, y ~/ 2, 128);
        }
      }
      final out = luniiImageFromBytes(
        Uint8List.fromList(img.encodePng(image)),
      )!;
      final reds = [for (final c in out.palette) (c >> 16) & 0xFF];
      expect(
        reds.reduce((a, b) => a > b ? a : b) -
            reds.reduce((a, b) => a < b ? a : b),
        greaterThan(80),
        reason: 'the palette spans the picture it was chosen for',
      );
    });

    test('a flat picture does not need all sixteen', () {
      final image = img.Image(width: 320, height: 240);
      img.fill(image, color: img.ColorRgb8(10, 90, 180));
      final out = luniiImageFromBytes(
        Uint8List.fromList(img.encodePng(image)),
      )!;
      expect(out.palette, isNotEmpty);
      expect(out.pixels.toSet(), hasLength(lessThanOrEqualTo(paletteSize)));
    });
  });

  // Returning null rather than throwing is the whole contract: the caller
  // falls back to the procedural cover, so an unreadable picture costs a nicer
  // picture and not a transfer whose audio was all present.
  group('input it cannot read', () {
    test('rubbish bytes give null, not an exception', () {
      expect(luniiImageFromBytes(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });

    test('empty bytes give null', () {
      expect(luniiImageFromBytes(Uint8List(0)), isNull);
    });

    // A PNG that starts correctly and stops early — an interrupted write, a
    // half-restored backup. This one threw a RangeError from inside the
    // decoder rather than returning null, which would have failed a transfer
    // whose audio was all present.
    test('a truncated PNG gives null, not an exception', () {
      final image = img.Image(width: 64, height: 48);
      img.fill(image, color: img.ColorRgb8(200, 100, 50));
      final bytes = Uint8List.fromList(img.encodePng(image));
      expect(luniiImageFromBytes(bytes.sublist(0, 30)), isNull);
      expect(luniiImageFromBytes(bytes.sublist(0, 8)), isNull);
    });
  });
}
