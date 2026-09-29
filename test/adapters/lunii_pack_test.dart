import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/export/cover_image.dart';
import 'package:moonloom/adapters/export/lunii_pack.dart';

/// The pack has to satisfy STUdio's ArchiveStoryPackReader: story.json at the
/// root, assets under `assets/`, every referenced asset present, and a node
/// graph it can walk.
void main() {
  List<LuniiChapter> chapters(int count, {String mime = 'audio/wav'}) => [
    for (var i = 0; i < count; i++)
      LuniiChapter(
        name: 'Chapter ${i + 1}',
        audio: Uint8List.fromList([i, i, i]),
        mimeType: mime,
      ),
  ];

  Archive unpack(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

  Map<String, dynamic> storyJson(Archive archive) {
    final file = archive.files.firstWhere((f) => f.name == 'story.json');
    return jsonDecode(utf8.decode(file.content as List<int>))
        as Map<String, dynamic>;
  }

  Uint8List build({int count = 3, Uint8List? cover}) => encodeLuniiPack(
    title: 'Obsidian Stone',
    description: 'Bob and Leo find a glowing stone.',
    chapters: chapters(count),
    cover: cover,
    rng: Random(7),
  );

  test('the zip holds story.json plus one asset per chapter', () {
    final archive = unpack(build(cover: nightSkyCover()));
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('story.json'));
    expect(names, contains('assets/cover.bmp'));
    expect(names, contains('assets/chapter-01.wav'));
    expect(names, contains('assets/chapter-03.wav'));
  });

  test('every asset a node references is actually in the zip', () {
    final archive = unpack(build(cover: nightSkyCover()));
    final present = archive.files.map((f) => f.name).toSet();
    for (final node in storyJson(archive)['stageNodes'] as List) {
      for (final key in ['image', 'audio']) {
        final asset = (node as Map)[key] as String?;
        if (asset != null) expect(present, contains('assets/$asset'));
      }
    }
  });

  test('chapters chain into a line the device can play through', () {
    final story = storyJson(unpack(build()));
    final stages = (story['stageNodes'] as List).cast<Map<String, dynamic>>();
    final actions = {
      for (final a
          in (story['actionNodes'] as List).cast<Map<String, dynamic>>())
        a['id'] as String: (a['options'] as List).cast<String>(),
    };

    // Walk cover → chapter 1 → … and confirm we reach every chapter once.
    final visited = <String>[];
    var node = stages.firstWhere((n) => n['squareOne'] == true);
    while (node['okTransition'] != null) {
      final link = node['okTransition'] as Map<String, dynamic>;
      final options = actions[link['actionNode']]!;
      final next = options[link['optionIndex'] as int];
      expect(visited, isNot(contains(next)), reason: 'the graph loops');
      visited.add(next);
      node = stages.firstWhere((n) => n['uuid'] == next);
    }
    expect(visited.length, 3);
    // Chapters play on by themselves; the last one ends the story.
    expect(node['controlSettings']['autoplay'], isTrue);
    expect(node['okTransition'], isNull);
    expect(stages.length, 4); // cover + 3 chapters
  });

  test('the cover node waits for OK instead of autoplaying', () {
    final stages = (storyJson(unpack(build()))['stageNodes'] as List)
        .cast<Map<String, dynamic>>();
    final cover = stages.firstWhere((n) => n['squareOne'] == true);
    expect(cover['controlSettings']['autoplay'], isFalse);
    expect(cover['controlSettings']['ok'], isTrue);
    expect(cover['audio'], isNull);
  });

  test('the file extension follows the voice provider\'s format', () {
    final mp3 = encodeLuniiPack(
      title: 'T',
      description: '',
      chapters: chapters(1, mime: 'audio/mpeg'),
      rng: Random(1),
    );
    expect(
      unpack(mp3).files.map((f) => f.name),
      contains('assets/chapter-01.mp3'),
    );
  });

  test('a pack needs at least one chapter', () {
    expect(
      () => encodeLuniiPack(title: 'T', description: '', chapters: const []),
      throwsArgumentError,
    );
  });

  test('the cover is a 320x240 24-bit BMP', () {
    final bmp = nightSkyCover(seed: 'Obsidian Stone');
    final header = ByteData.view(bmp.buffer);
    expect(bmp[0], 0x42); // 'B'
    expect(bmp[1], 0x4d); // 'M'
    expect(header.getInt32(18, Endian.little), 320);
    expect(header.getInt32(22, Endian.little), 240);
    expect(header.getUint16(28, Endian.little), 24);
    expect(bmp.length, 54 + 320 * 240 * 3);
    expect(header.getUint32(2, Endian.little), bmp.length);
    // Same story, same sky.
    expect(nightSkyCover(seed: 'Obsidian Stone'), bmp);
  });
}
