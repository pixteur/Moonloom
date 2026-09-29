import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/export/world_cover.dart';

/// The picture is how a child tells one pack from another on a device with no
/// screen worth reading, so two things matter: a world always looks the same,
/// and two worlds do not look alike.
void main() {
  const names = [
    'Bob and Leo',
    "Pip's Adventures",
    'Leo and Bolt',
    'The Deep Blue',
    'Splat the Cat',
    'The Whispering Wood',
    'Nana and the Nine Keys',
    'Rocket Post',
  ];

  test('a world always gets the same picture', () {
    for (final name in names) {
      expect(
        worldCoverIndexed(seed: name).pixels,
        worldCoverIndexed(seed: name).pixels,
        reason: '$name changed between two builds',
      );
    }
    // Naming is not case- or whitespace-sensitive, so renaming a world to fix
    // its capitalisation does not hand a child a different place.
    expect(
      worldCoverIndexed(seed: 'Bob and Leo').pixels,
      worldCoverIndexed(seed: '  bob and leo ').pixels,
    );
  });

  test('different worlds look different', () {
    final seen = <String>{};
    for (final name in names) {
      final image = worldCoverIndexed(seed: name);
      // The palette alone is the first thing an eye lands on; the pixels
      // catch two worlds that share a palette but not a landscape.
      seen.add('${image.palette.join(",")}|${image.pixels.join(",").hashCode}');
    }
    expect(seen, hasLength(names.length));
  });

  test('the look is described in words a dry run can print', () {
    for (final name in names) {
      expect(
        worldCoverDescription(name),
        matches(RegExp(r'\w+ sky, \w+ above \w+')),
      );
    }
  });

  test('it is the size and depth the device takes', () {
    final image = worldCoverIndexed(seed: 'Bob and Leo');
    expect(image.width, 320);
    expect(image.height, 240);
    // RLE4 is four bits per pixel, so sixteen colours and no more.
    expect(image.palette, hasLength(16));
    expect(image.pixels, hasLength(320 * 240));
    expect(image.pixels.every((p) => p < 16), isTrue);
  });

  test('the sky is dithered rather than banded', () {
    // Ten colours cannot make a smooth gradient on their own. Neighbouring
    // pixels in one row must sometimes differ, or the sky is ten stripes.
    final image = worldCoverIndexed(seed: 'Bob and Leo');
    var mixedRows = 0;
    for (var y = 0; y < 100; y++) {
      final row = image.pixels.sublist(y * 320, y * 320 + 320);
      if (row.toSet().length > 1) mixedRows++;
    }
    expect(mixedRows, greaterThan(20));
  });
}
