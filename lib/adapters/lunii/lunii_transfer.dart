/// Turning a story's cached narration into a pack on an attached storyteller.
///
/// The work — decompress, decode, trim, join, encode, cipher, write — is tens
/// of seconds of solid CPU and a couple of dozen megabytes of file I/O for a
/// six-chapter story. All of it runs in a worker isolate, because doing it on
/// the UI isolate would freeze the app for the duration.
///
/// What crosses into the isolate is the *compressed* cached chunks, a few
/// megabytes, rather than the decoded audio, which is an order of magnitude
/// larger. Everything downstream of that is pure Dart, FFI or file I/O, none
/// of which needs Flutter bindings.
///
/// See [docs/lunii-sync.md](../../../docs/lunii-sync.md).
library;

import 'dart:isolate';
import 'dart:typed_data';

import '../audio/mp3_encoder.dart';
import '../audio/mp3_decoder.dart';
import '../audio/wav.dart';
import '../export/cover_image.dart';
import '../export/lunii_portrait.dart';
import '../export/world_cover.dart';

import '../tts/audio_compression.dart';
import 'device_pack.dart';
import 'device_writer.dart';

/// Which picture the storyteller shows while the story plays.
enum LuniiCoverMotif {
  nightSky('Night sky'),
  velo('Bicycle');

  const LuniiCoverMotif(this.label);
  final String label;
}

/// What was sent, for telling the grown-up afterwards.
class LuniiTransfer {
  const LuniiTransfer({
    required this.packName,
    required this.chapters,
    required this.skipped,
    required this.bytes,
    required this.drive,
  });

  final String packName;
  final int chapters;

  /// Chapters left out because their narration is not fully downloaded.
  final int skipped;
  final int bytes;
  final String drive;

  String get summary =>
      '$chapters chapter${chapters == 1 ? '' : 's'} '
      '(${(bytes / 1024 / 1024).toStringAsFixed(1)} MB) sent to the '
      'storyteller on $drive'
      '${skipped > 0 ? ' — $skipped not downloaded yet, left out' : ''}';
}

/// Everything the worker needs, in plain values it can be handed.
class LuniiTransferRequest {
  const LuniiTransferRequest({
    required this.drive,
    required this.backupDirectory,
    required this.title,
    required this.chapterChunks,
    required this.skipped,
    required this.motif,
    this.titleChunks,
    this.announceChunks,
    this.worldName,
    this.coverImage,
  });

  final String drive;
  final String backupDirectory;
  final String title;

  /// Per chapter, its cached chunks exactly as they sit in the audio cache —
  /// still compressed, so this stays small enough to hand across cheaply.
  final List<List<Uint8List>> chapterChunks;

  /// The story's title, spoken — cached chunks like any other clip. Null when
  /// it has not been synthesized, which leaves the cover silent as before
  /// rather than failing the transfer over a nicety.
  final List<Uint8List>? titleChunks;

  /// Per chapter, its name spoken — the wheel's menu. Null, or short of a
  /// chapter, and the pack stays a straight line: a menu that is silent on
  /// some options is worse than none.
  final List<List<Uint8List>?>? announceChunks;
  final int skipped;

  /// The world this story belongs to, if any. A world gets a picture of its
  /// own — every episode of it arrives on the device looking like the same
  /// place — and [motif] is only consulted for a standalone story.
  final String? worldName;
  final LuniiCoverMotif motif;

  /// A picture drawn for *this* story, to show instead of the drawn-in-code
  /// one. Null falls back to the world picture, and that to [motif], so a story
  /// with no illustrations still reaches the device looking like something.
  ///
  /// Whatever the image model handed back — JPEG, in practice, whatever the
  /// file is named. [luniiImageFromBytes] sniffs it.
  final Uint8List? coverImage;
}

/// Build a pack from [request] and install it, off the UI isolate.
Future<LuniiTransfer> sendStoryToLunii(LuniiTransferRequest request) =>
    Isolate.run(() => buildAndWritePack(request));

/// The worker. Top-level and synchronous on purpose: it is what
/// [sendStoryToLunii] runs, and `tool/lunii_write.dart` exercises the same
/// path from the command line.
LuniiTransfer buildAndWritePack(LuniiTransferRequest request) {
  if (request.chapterChunks.isEmpty) {
    throw const LuniiDeviceException(
      'No narration saved yet — play or download the story first.',
    );
  }
  final device = LuniiDevice.open(request.drive);

  final announce = request.announceChunks;
  final chapters = <DevicePackChapter>[];
  for (var i = 0; i < request.chapterChunks.length; i++) {
    final named = announce != null && i < announce.length ? announce[i] : null;
    chapters.add(
      DevicePackChapter(
        audio: _chapterAudio(request.chapterChunks[i]),
        announce: named == null || named.isEmpty ? null : _chapterAudio(named),
      ),
    );
  }

  // A picture drawn for this story if there is one, reduced to what the screen
  // can show. The fallbacks matter and are in this order on purpose: a world's
  // procedural picture at least says *which world*, and the motif at least
  // says *a story*. Reducing returns null rather than throwing, so a picture
  // that will not decode costs a nicer picture, not the transfer.
  final picture = request.coverImage;
  final world = request.worldName?.trim();
  final cover =
      (picture == null || picture.isEmpty
          ? null
          : luniiImageFromBytes(picture)) ??
      (world != null && world.isNotEmpty
          ? worldCoverIndexed(seed: world)
          : switch (request.motif) {
              LuniiCoverMotif.velo => veloCoverIndexed(seed: request.title),
              LuniiCoverMotif.nightSky => nightSkyCoverIndexed(
                seed: request.title,
              ),
            });

  final titleChunks = request.titleChunks;
  final pack = buildDevicePack(
    chapters: chapters,
    deviceKey: device.deviceKey,
    cover: cover,
    titleAudio: titleChunks == null || titleChunks.isEmpty
        ? null
        : _chapterAudio(titleChunks),
  );
  writePack(device, pack, backupDirectory: request.backupDirectory);

  return LuniiTransfer(
    packName: pack.directoryName,
    chapters: chapters.length,
    skipped: request.skipped,
    bytes: pack.byteCount,
    drive: request.drive,
  );
}

/// One chapter's chunks as a single MP3 the device will play.
///
/// Every voice ends up in the same place — samples, trimmed, joined, encoded
/// at what the device plays — whether it handed back WAV or MP3. Going through
/// samples even for MP3 that is already the right shape costs a decode, and
/// buys a chapter that is one clean stream rather than several concatenated
/// ones, with the dead air taken out of each.
///
/// Trimming is per chunk rather than once at the end, because a provider's
/// dead air can land in the middle of a chapter as easily as after it. See
/// [trimTrailingSilence].
Uint8List _chapterAudio(List<Uint8List> chunks) {
  final parts = <WavAudio>[];
  for (final chunk in chunks) {
    final raw = decompressAudio(chunk);
    parts.add(
      trimTrailingSilence(_isMp3(raw) ? decodeMp3(raw) : decodeWav(raw)),
    );
  }
  return encodePcmToLuniiMp3(joinWav(parts));
}

/// Cached narration is WAV from most voices and MP3 from the rest, and the
/// cache does not record which. RIFF's magic is the tell.
bool _isMp3(Uint8List bytes) =>
    bytes.length < 4 ||
    !(bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46); //  F
