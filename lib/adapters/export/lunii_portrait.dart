/// Turning a drawn picture into something a storyteller can show.
///
/// The device takes **320×240 in sixteen colours**, and that is a brutal
/// reduction: a painterly illustration arrives as mud, gradients band into
/// stripes, and a face becomes four grey pixels. `world_cover.dart` sidesteps
/// it by drawing procedurally for exactly those constraints, which is why
/// every story in a world has shown the same picture — the seed is the world's
/// name.
///
/// This is the other half: take a picture actually drawn for this story, and
/// reduce it honestly. Two things make that work, and both are about throwing
/// away the right information:
///
///   * **Crop, then scale.** Squeezing a 3:4 portrait into 4:3 stretches a
///     face sideways. Taking the largest 4:3 rectangle from the middle keeps
///     the subject's proportions, and the subject is the point.
///   * **Quantise by occurrence, not by beauty.** Sixteen colours chosen for
///     the whole image spends most of them on a background gradient nobody
///     looks at. Median-cut over the pixels that exist gives the colours the
///     picture actually uses.
///
/// Pure Dart beyond the image decode. See `docs/lunii-sync.md`.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../image/bmp_rle4.dart';

/// What the device's screen is.
const int deviceWidth = 320;
const int deviceHeight = 240;

/// Reduce [bytes] to the device's screen, or null if they cannot be read.
///
/// **The format is sniffed, not assumed.** The first version called
/// `decodePng`, which was wrong in a way that looked exactly like working
/// code: the image model hands back JPEG, the picture store names every file
/// `.png` because that is what the store was written for, and so `decodePng`
/// returned null for every real picture in the library. Nothing threw,
/// nothing logged, and the device simply kept showing the old procedural
/// cover — a plausible answer, no error, wrong. Same shape as the trap about
/// an MP3's first frame in CLAUDE.md, and found the same way: by running it
/// against the real library instead of fixtures.
///
/// Returns null rather than throwing, so a picture that will not decode costs
/// the nicer picture and not a story reaching the device.
IndexedImage? luniiImageFromBytes(Uint8List bytes) {
  // Caught, not just checked for null: a decoder returns null for bytes that
  // are not an image it knows but *throws* a RangeError for bytes that start
  // like one and stop early — an interrupted write, a half-restored backup.
  // Both are the same thing from here.
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return _reduce(decoded);
  } catch (_) {
    return null;
  }
}

IndexedImage _reduce(img.Image source) {
  final cropped = _centreCrop(source);
  final scaled = img.copyResize(
    cropped,
    width: deviceWidth,
    height: deviceHeight,
    interpolation: img.Interpolation.average,
  );

  // A little more contrast and saturation before the reduction, not after.
  // Sixteen colours flatten a picture on their own; giving the quantiser a
  // livelier image to choose from is the difference between a silhouette and
  // a smudge, and doing it afterwards would only stretch the sixteen it kept.
  img.adjustColor(scaled, contrast: 1.18, saturation: 1.25);

  final palette = _medianCut(scaled, paletteSize);
  final pixels = Uint8List(deviceWidth * deviceHeight);
  for (var y = 0; y < deviceHeight; y++) {
    for (var x = 0; x < deviceWidth; x++) {
      final p = scaled.getPixel(x, y);
      pixels[y * deviceWidth + x] = _nearest(
        palette,
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
      );
    }
  }
  return IndexedImage(
    width: deviceWidth,
    height: deviceHeight,
    pixels: pixels,
    palette: [for (final c in palette) (c.r << 16) | (c.g << 8) | c.b],
  );
}

/// The largest 4:3 rectangle in the middle of [source].
///
/// Covers are drawn 3:4 and chapter pictures 4:3, so this has to handle both
/// without distorting either. Cropping loses the top of a cover — which is
/// the part deliberately left empty for a title, and which the device has no
/// use for anyway.
img.Image _centreCrop(img.Image source) {
  final wanted = deviceWidth / deviceHeight;
  final actual = source.width / source.height;
  if ((actual - wanted).abs() < 0.01) return source;

  if (actual > wanted) {
    final width = (source.height * wanted).round();
    return img.copyCrop(
      source,
      x: (source.width - width) ~/ 2,
      y: 0,
      width: width,
      height: source.height,
    );
  }
  final height = (source.width / wanted).round();
  // Biased above centre: in a portrait of a character the face is in the
  // upper half, and a centred crop of a standing figure keeps the knees.
  final top = ((source.height - height) * 0.35).round();
  return img.copyCrop(
    source,
    x: 0,
    y: top.clamp(0, source.height - height),
    width: source.width,
    height: height,
  );
}

class _Colour {
  const _Colour(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;
}

/// Median cut: split the colour box along its longest axis until there are
/// [count] boxes, then take each box's average.
///
/// Chosen over a fixed palette because a sea story and a forest story want
/// different sixteen colours, and over an octree because this runs once per
/// story on 76 800 pixels, where simplicity is worth more than speed.
List<_Colour> _medianCut(img.Image image, int count) {
  final pixels = <_Colour>[];
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      pixels.add(_Colour(p.r.toInt(), p.g.toInt(), p.b.toInt()));
    }
  }
  if (pixels.isEmpty) return const [_Colour(0, 0, 0)];

  var boxes = <List<_Colour>>[pixels];
  while (boxes.length < count) {
    // Split the box with the widest spread; splitting the biggest by pixel
    // count would keep halving the sky.
    var widest = -1;
    var spread = 0;
    for (var i = 0; i < boxes.length; i++) {
      if (boxes[i].length < 2) continue;
      final s = _spreadOf(boxes[i]).$2;
      if (s > spread) {
        spread = s;
        widest = i;
      }
    }
    if (widest < 0) break;

    final box = boxes[widest];
    final axis = _spreadOf(box).$1;
    box.sort((a, b) => _channel(a, axis).compareTo(_channel(b, axis)));
    final middle = box.length ~/ 2;
    boxes = [
      ...boxes.sublist(0, widest),
      box.sublist(0, middle),
      box.sublist(middle),
      ...boxes.sublist(widest + 1),
    ];
  }

  return [
    for (final box in boxes)
      if (box.isNotEmpty) _averageOf(box),
  ];
}

int _channel(_Colour c, int axis) => switch (axis) {
  0 => c.r,
  1 => c.g,
  _ => c.b,
};

/// Which axis this box is widest on, and by how much.
(int, int) _spreadOf(List<_Colour> box) {
  var minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0;
  for (final c in box) {
    minR = min(minR, c.r);
    maxR = max(maxR, c.r);
    minG = min(minG, c.g);
    maxG = max(maxG, c.g);
    minB = min(minB, c.b);
    maxB = max(maxB, c.b);
  }
  final r = maxR - minR, g = maxG - minG, b = maxB - minB;
  if (r >= g && r >= b) return (0, r);
  if (g >= b) return (1, g);
  return (2, b);
}

_Colour _averageOf(List<_Colour> box) {
  var r = 0, g = 0, b = 0;
  for (final c in box) {
    r += c.r;
    g += c.g;
    b += c.b;
  }
  return _Colour(r ~/ box.length, g ~/ box.length, b ~/ box.length);
}

/// The palette entry closest to a colour, by squared distance.
int _nearest(List<_Colour> palette, int r, int g, int b) {
  var best = 0;
  var bestDistance = 1 << 30;
  for (var i = 0; i < palette.length; i++) {
    final c = palette[i];
    final dr = c.r - r, dg = c.g - g, db = c.b - b;
    final distance = dr * dr + dg * dg + db * db;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = i;
    }
  }
  return best;
}
