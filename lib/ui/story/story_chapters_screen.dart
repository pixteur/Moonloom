import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/provider_exceptions.dart';
import '../../adapters/lunii/lunii_transfer.dart';
import '../../adapters/tts/voice_catalog.dart';
import '../../app_providers.dart';
import '../../domain/cast_line.dart';
import '../../domain/models/beat.dart';
import '../../domain/models/series.dart';
import '../../domain/models/story_character.dart';
import '../../domain/models/story_image.dart';
import '../../domain/picture_prompt.dart';
import '../common/hold_to_delete.dart';
import '../common/language_choices.dart';
import '../series/story_language_sheet.dart';
import '../common/error_banner.dart';
import 'story_picture.dart';
import 'story_view_screen.dart';

/// A single story's chapter list: start from the beginning or jump to any
/// chapter. For a freshly created story the chapters generate in the background
/// and stream into the list; you can start chapter 1 as soon as it's ready.
/// Replaces the old per-series "tonight begins" screen + archive.
/// See `docs/ui-ux.md`.
class StoryChaptersScreen extends ConsumerStatefulWidget {
  const StoryChaptersScreen({super.key, this.initialIntent, this.initialTwist});

  /// For a brand-new story: how chapter 1 begins (dice / option / typed idea).
  /// Null when opening an existing story from the library.
  final StoryIntent? initialIntent;
  final String? initialTwist;

  @override
  ConsumerState<StoryChaptersScreen> createState() =>
      _StoryChaptersScreenState();
}

class _StoryChaptersScreenState extends ConsumerState<StoryChaptersScreen> {
  static const int _maxChapters = 6;
  bool _building = false;
  bool _active = true;

  /// A whole-story download is running; chapters are saved one at a time.
  bool _downloading = false;

  /// A transfer is in flight. The work is in a worker isolate, so the app
  /// stays responsive; this only stops a second send being started on top.
  bool _sending = false;

  /// How many chapters that run has got through, for the progress label.
  int _downloaded = 0;

  /// Chunks saved / to save within the chapter being worked on. A chapter can
  /// be a dozen voice requests, so chapter-level counting alone leaves the
  /// label unchanged for minutes and reads as hung.
  (int, int) _chapterParts = (0, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_build()));
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  /// Generate the story to a natural end in the background, one chapter at a
  /// time, refreshing the list as each lands. Chapter 1 uses the chosen opening;
  /// the rest continue. Stops at the cap or the final chapter, and never crashes
  /// the reader.
  Future<void> _build() async {
    final child = ref.read(activeChildProvider);
    final active = ref.read(activeSeriesProvider);
    if (child == null || active == null) return;
    var series = active;
    final repo = ref.read(storageRepoProvider);
    if (mounted) setState(() => _building = true);
    try {
      // Waits for the grown-up's chosen provider to load. Read directly, this
      // could land before settings did and capture an engine on the fake
      // provider for the whole story — six canned chapters, no warning, never
      // named. Inside the try, so a settings read that fails is reported like
      // any other build failure rather than escaping an unawaited future.
      final engine = await readyStoryEngine(ref);
      if (!mounted) return;
      // Never silently. The placeholder answers instantly and successfully, so
      // a story written by it looks like the app working — six identical
      // chapters and a title stuck on "Naming it…" — unless it says so.
      final placeholder = placeholderReason(ref);
      if (placeholder != null) {
        showErrorBanner(
          context,
          'These are offline placeholder chapters, not a real story: '
          '$placeholder. Set up the story AI in Settings to write real ones.',
        );
      }
      var beats = await repo.loadBeats(series.id);
      var first = true;
      while (_active &&
          mounted &&
          beats.length < _maxChapters &&
          !(beats.isNotEmpty && beats.last.isFinal)) {
        final isOpening = beats.isEmpty && first;
        await engine.takeTurn(
          child: child,
          series: series,
          intent: isOpening
              ? (widget.initialIntent ?? StoryIntent.dice)
              : StoryIntent.continued,
          chosenTwist: isOpening ? widget.initialTwist : null,
        );
        first = false;
        if (!_active || !mounted) return;
        // Read the story back rather than reusing the copy we started with.
        // The first chapter names an untitled story, and that name is written
        // to the database, not to this object — so a stale copy left the
        // placeholder on screen for the whole session and told every later
        // chapter the story still needed naming, renaming it each time.
        series = await repo.loadSeriesById(series.id) ?? series;
        ref.read(activeSeriesProvider.notifier).select(series);
        ref.invalidate(beatsForSeriesProvider(series.id));
        ref.invalidate(seriesForChildProvider(child.id));
        _warn(engine.lastFallbackReason);
        beats = await repo.loadBeats(series.id);
      }
    } catch (e, stack) {
      // The banner can only carry a sentence; without the stack a failure here
      // is guesswork, and this is the path a broken bedtime actually takes.
      debugPrintStack(stackTrace: stack, label: 'story build failed: $e');
      if (mounted) {
        showErrorBanner(context, 'Could not finish building the story: $e');
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
    // NB: we intentionally do NOT pre-synthesize every chapter's audio — that
    // burned through the voice provider's daily quota. Narration is fetched
    // on demand (Listen, or tapping a chapter's cloud badge) and then cached.
  }

  /// Voices this device has recorded with, so an export can still find audio
  /// saved before the grown-up changed voice.
  List<String> get _knownVoices =>
      ref.read(knownVoicesProvider).asData?.value ?? const [];

  void _warn(String? reason) {
    if (reason != null && mounted) {
      showErrorBanner(context, 'Story AI used a placeholder. ($reason)');
    }
  }

  /// Bundle this story (text + cached audio + metadata) into a shareable
  /// `.sleepy` file in the app's exports folder.
  Future<void> _export(Series series) async {
    final child = ref.read(activeChildProvider);
    final lang = languageFor(series, child?.language);
    final voiceSig = ref.read(ttsProvider).voiceSignature;
    try {
      final path = await ref
          .read(sleepyServiceProvider)
          .exportToFile(
            series,
            language: lang,
            voiceSignature: voiceSig,
            alsoTryVoices: _knownVoices,
          );
      if (mounted) showErrorBanner(context, 'Saved story file: $path');
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Export failed: $e');
    }
  }

  /// Text-only .sleepy for sending by message/email; the recipient's app
  /// rebuilds narration with their own preferred voice on import.
  Future<void> _exportText(Series series) async {
    final child = ref.read(activeChildProvider);
    final lang = languageFor(series, child?.language);
    final voiceSig = ref.read(ttsProvider).voiceSignature;
    try {
      final path = await ref
          .read(sleepyServiceProvider)
          .exportToFile(
            series,
            language: lang,
            voiceSignature: voiceSig,
            includeAudio: false,
          );
      if (mounted) {
        showErrorBanner(
          context,
          'Text-only story saved — attach it to a message/email: $path',
        );
      }
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Export failed: $e');
    }
  }

  /// Whole story joined into one audiobook file + metadata, saved in the library
  /// (upload to Dropbox / iCloud / Drive from there).
  Future<void> _exportAudiobook(Series series) async {
    final child = ref.read(activeChildProvider);
    final lang = languageFor(series, child?.language);
    final tts = ref.read(ttsProvider);
    try {
      final path = await ref
          .read(sleepyServiceProvider)
          .exportAudiobook(
            series,
            language: lang,
            voiceSignature: tts.voiceSignature,
            mimeType: tts.audioMimeType,
            author: child?.displayName ?? 'MoonloomApp',
            alsoTryVoices: _knownVoices,
          );
      if (mounted) showErrorBanner(context, 'Audiobook saved: $path');
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Audiobook export: ${_reason(e)}');
    }
  }

  /// Write the story straight onto a plugged-in storyteller.
  ///
  /// The one export that changes something outside the app, on hardware
  /// holding content somebody paid for — so it asks first, names the device
  /// and the picture, and says afterwards exactly what it did.
  Future<void> _sendToLunii(Series series) async {
    if (_sending) return;
    final service = ref.read(sleepyServiceProvider);
    final devices = service.attachedLuniiDevices();
    if (devices.isEmpty) {
      showErrorBanner(
        context,
        'No storyteller found. Plug the Lunii in with its USB cable, then try '
        'again.',
      );
      return;
    }

    // An episode of a world has a picture of its own — a portrait of one of
    // its characters — so there is nothing to choose. Only a standalone story
    // gets asked which drawn-in-code motif to wear.
    final repo = ref.read(storageRepoProvider);
    final world = series.worldId == null
        ? null
        : await repo.loadWorldById(series.worldId!);
    final beats = world == null
        ? const <Beat>[]
        : await repo.loadBeats(series.id);
    final cast = world == null
        ? const <StoryCharacter>[]
        : await repo.loadCharacters(world.id);
    // Worked out before asking, so the grown-up is told whose face it will be
    // and whether this costs a picture. The same pure function the service
    // uses, so what the dialog promises is what gets drawn.
    final subject = portraitSubject(
      seriesId: series.id,
      cast: [for (final c in cast) c.promptLine],
      beats: beats,
    );
    final who = subject == null ? '' : parseCastEntry(subject).$1;
    final alreadyDrawn = (await repo.loadImages(
      series.id,
    )).any((i) => i.kind == StoryImageKind.lunii);
    if (!mounted) return;

    final LuniiCoverMotif? motif;
    if (world != null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send to the Lunii'),
          content: Text(
            '"${series.title}" will be added to the storyteller on '
            '${devices.first}. Nothing already on it is changed.\n\n'
            '${who.isEmpty ? 'It will show the picture for “${world.name}”.' : 'It will show a portrait of $who, so this episode looks '
                      'different from the others on the shelf.'
                      '${alreadyDrawn ? '' : ' Drawing it costs one picture.'}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
      // Ignored: the world supplies the art.
      motif = LuniiCoverMotif.nightSky;
    } else {
      motif = await showDialog<LuniiCoverMotif>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send to the Lunii'),
          content: Text(
            '"${series.title}" will be added to the storyteller on '
            '${devices.first}. Nothing already on it is changed.\n\n'
            'Which picture should it show?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            for (final option in LuniiCoverMotif.values)
              TextButton(
                onPressed: () => Navigator.pop(context, option),
                child: Text(option.label),
              ),
          ],
        ),
      );
      if (motif == null || !mounted) return;
    }

    setState(() => _sending = true);
    showErrorBanner(context, 'Sending to the Lunii — this takes a minute…');
    try {
      final child = ref.read(activeChildProvider);
      // Best effort, like the spoken title: a portrait the image model refuses
      // or has no key for leaves the pack wearing the world's picture, which
      // is how every pack written before this behaved. Not a reason to refuse
      // a transfer whose audio is all present.
      Uint8List? portrait;
      if (world != null) {
        try {
          final drawn = await ref
              .read(illustrationServiceProvider)
              .ensureLuniiPortrait(
                series: series,
                beats: beats,
                world: world,
                cast: cast,
              );
          portrait = drawn?.$2;
        } catch (_) {
          portrait = null;
        }
      }
      final result = await service.sendToLunii(
        series,
        language: languageFor(series, child?.language),
        voiceSignature: ref.read(ttsProvider).voiceSignature,
        motif: motif,
        coverImage: portrait,
        drive: devices.first,
        alsoTryVoices: _knownVoices,
        // Lets the cover say the story's name — the device has no screen to
        // read, so this is how a child knows what they are standing on.
        voice: ref.read(ttsProvider),
      );
      if (mounted) showErrorBanner(context, result.summary);
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Send failed: ${_reason(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Save every chapter's narration, in order, one at a time.
  ///
  /// Sequential on purpose. Each chapter is several requests to the voice
  /// provider, so starting them all at once is a burst — and a burst is what
  /// trips a per-minute limit, which then reads as "you are out of quota" even
  /// on a paid plan. One chapter at a time keeps it to a trickle.
  ///
  /// A chapter that fails is retried once after a pause, since a rate-limit
  /// refusal is usually over within seconds, and the rest of the story
  /// continues either way — one missing chapter should not stop the download.
  Future<void> _downloadAll(List<Beat> beats) async {
    if (_downloading) return;
    final lang = languageFor(
      ref.read(activeSeriesProvider),
      ref.read(activeChildProvider)?.language,
    );
    final tts = ref.read(ttsProvider);
    setState(() {
      _downloading = true;
      _downloaded = 0;
      _chapterParts = (0, 0);
    });
    var failed = 0;
    try {
      for (final beat in beats) {
        if (!mounted || !_active) return;
        var saved = false;
        for (var attempt = 0; attempt < 2 && !saved; attempt++) {
          try {
            await tts.preload(
              beat.text,
              language: lang,
              notes: beat.narration,
              onProgress: (done, total) {
                if (mounted) setState(() => _chapterParts = (done, total));
              },
            );
            saved = true;
          } catch (_) {
            if (attempt == 0) {
              await Future<void>.delayed(const Duration(seconds: 4));
            }
          }
        }
        if (!saved) failed++;
        if (mounted) setState(() => _downloaded++);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
    if (!mounted) return;
    showErrorBanner(
      context,
      failed == 0
          ? 'All ${beats.length} chapters saved — this story now plays without '
                'the internet.'
          : '${beats.length - failed} of ${beats.length} chapters saved. '
                'Tap again to retry the rest.',
    );
  }

  /// Re-edit a finished story into a second, polished copy. The original is
  /// left exactly as it was, so the two can be read side by side.
  Future<void> _refineStory(Series series) async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    setState(() => _building = true);
    try {
      final copy = await ref
          .read(seriesServiceProvider)
          .refineIntoNewVersion(
            engine: await readyStoryEngine(ref),
            child: child,
            source: series,
          );
      ref.invalidate(seriesForChildProvider(child.id));
      if (mounted) {
        showErrorBanner(context, 'Saved a refined copy: "${copy.title}".');
      }
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Refine: ${_reason(e)}');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  /// A STUdio pack for the Lunii storyteller, saved in the library. The
  /// grown-up opens it in STUdio and transfers it to the device.
  Future<void> _exportLunii(Series series) async {
    final child = ref.read(activeChildProvider);
    final lang = languageFor(series, child?.language);
    final tts = ref.read(ttsProvider);
    try {
      final path = await ref
          .read(sleepyServiceProvider)
          .exportLuniiPack(
            series,
            language: lang,
            voiceSignature: tts.voiceSignature,
            mimeType: tts.audioMimeType,
            alsoTryVoices: _knownVoices,
          );
      if (mounted) {
        showErrorBanner(
          context,
          'Lunii pack saved — open it in STUdio to transfer: $path',
        );
      }
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Lunii export: ${_reason(e)}');
    }
  }

  /// "No narration saved yet…" reads better than "Bad state: No narration…".
  String _reason(Object error) =>
      error is StateError ? error.message : friendlyProviderError(error);

  /// The chapter at [seq], or null if it isn't there (e.g. it was deleted after
  /// the reading position was saved).
  Beat? _find(List<Beat> beats, int seq) {
    for (final b in beats) {
      if (b.seq == seq) return b;
    }
    return null;
  }

  Future<void> _open(Beat beat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewScreen(beat: beat)),
    );
  }

  /// Rename the story (parent mode only).
  /// Change the languages an existing story is told in.
  ///
  /// The creator asks once and there was no way back to it, so a story begun
  /// in the wrong language stayed that way. Chapters already written keep
  /// their words; this steers the ones still to come.
  Future<void> _editLanguages(Series series) async {
    final child = ref.read(activeChildProvider);
    final chosen = await showStoryLanguageSheet(
      context,
      series: series,
      childLanguage: child?.language ?? 'en',
    );
    if (chosen == null || !mounted) return;
    final updated = await ref
        .read(seriesServiceProvider)
        .setLanguages(
          series,
          baseLanguage: chosen.baseLanguage,
          bilingualEnabled: chosen.bilingualEnabled,
          secondaryLanguage: chosen.secondaryLanguage,
          bilingualBlend: chosen.bilingualBlend,
        );
    if (!mounted) return;
    ref.read(activeSeriesProvider.notifier).select(updated);
    ref.invalidate(seriesForChildProvider(series.childId));
    final second = updated.secondaryLanguage;
    showErrorBanner(
      context,
      'Told in ${languageLabel(languageFor(updated, child?.language))}'
      '${second == null ? "" : ", with ${languageLabel(second)} woven in"}.',
    );
  }

  Future<void> _rename(Series series) async {
    final controller = TextEditingController(text: series.title);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename story'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Story name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == series.title) return;
    final updated = series.copyWith(title: name);
    await ref.read(storageRepoProvider).saveSeries(updated);
    if (!mounted) return;
    ref.read(activeSeriesProvider.notifier).select(updated);
    ref.invalidate(seriesForChildProvider(series.childId));
  }

  /// Delete a chapter (parent-gated) and renumber the rest so numbering stays
  /// clean (1, 2, 3…). Handy for trimming early placeholder chapters.
  /// Hold a chapter to delete it — the same sheet, gate and double check as a
  /// story, a world or a child.
  Future<void> _holdToDeleteChapter(Beat beat) async {
    final series = ref.read(activeSeriesProvider);
    if (series == null) return;
    final title = beat.title.trim().isEmpty
        ? 'Chapter ${beat.seq + 1}'
        : 'Chapter ${beat.seq + 1} · ${beat.title.trim()}';
    await holdToDelete(
      context,
      enabled: ref.read(parentModeProvider),
      what: title,
      icon: '📄',
      warning:
          'This removes the chapter and its text. The rest of the story is '
          'left alone, and the chapters after it move up a number.',
      onDelete: () async {
        final repo = ref.read(storageRepoProvider);
        await repo.deleteBeat(beat.id);
        // Compact seq to 0..n-1 so the list still reads 1, 2, 3…
        final remaining = await repo.loadBeats(series.id);
        for (var i = 0; i < remaining.length; i++) {
          if (remaining[i].seq != i) {
            await repo.saveBeat(_withSeq(remaining[i], i));
          }
        }
        ref.invalidate(beatsForSeriesProvider(series.id));
      },
    );
  }

  Beat _withSeq(Beat b, int seq) => Beat(
    id: b.id,
    seriesId: b.seriesId,
    childId: b.childId,
    seq: seq,
    intent: b.intent,
    text: b.text,
    summary: b.summary,
    rating: b.rating,
    setting: b.setting,
    chosenTwist: b.chosenTwist,
    characters: b.characters,
    openThreads: b.openThreads,
    language: b.language,
    isFinal: b.isFinal,
  );

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(activeSeriesProvider);
    final theme = Theme.of(context);
    if (series == null) {
      return const Scaffold(body: Center(child: Text('No story selected.')));
    }
    final beats =
        ref.watch(beatsForSeriesProvider(series.id)).asData?.value ??
        const <Beat>[];
    final ended = beats.isNotEmpty && beats.last.isFinal;
    final parentMode = ref.watch(parentModeProvider);
    final lang = languageFor(series, ref.watch(activeChildProvider)?.language);
    final voiceSig = ref.watch(ttsProvider).voiceSignature;

    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          if (parentMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Story settings',
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename story')),
                PopupMenuItem(value: 'language', child: Text('Languages…')),
              ],
              onSelected: (v) {
                if (v == 'rename') _rename(series);
                if (v == 'language') _editLanguages(series);
              },
            ),
          // Every export sends a story out of the app — as a file to pass on,
          // or onto another device — so the whole menu is grown-ups only.
          if (parentMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Export / share',
              enabled: beats.isNotEmpty,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'sleepy',
                  child: Text('Story file (.sleepy, with audio)'),
                ),
                PopupMenuItem(
                  value: 'text',
                  child: Text('Text to share (friend rebuilds voice)'),
                ),
                PopupMenuItem(
                  value: 'audiobook',
                  child: Text('Audiobook — single file'),
                ),
                PopupMenuItem(value: 'lunii', child: Text('Lunii story pack')),
                PopupMenuItem(
                  value: 'lunii-send',
                  child: Text('Send to the Lunii (plugged in)'),
                ),
                // No "(parents)" suffix any more — the whole menu is behind
                // parent mode now.
                PopupMenuItem(
                  value: 'refine',
                  child: Text('Refine into a new version'),
                ),
              ],
              onSelected: (v) {
                if (v == 'sleepy') _export(series);
                if (v == 'text') _exportText(series);
                if (v == 'audiobook') _exportAudiobook(series);
                if (v == 'lunii') _exportLunii(series);
                if (v == 'lunii-send') _sendToLunii(series);
                if (v == 'refine') _refineStory(series);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Pick the story back up where it was left, if it was left part-way.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Builder(
              builder: (_) {
                final resumeAt = series.isInProgress
                    ? _find(beats, series.lastReadSeq!)
                    : null;
                return Column(
                  children: [
                    FilledButton.icon(
                      onPressed: beats.isEmpty
                          ? null
                          : () => _open(resumeAt ?? beats.first),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        resumeAt == null
                            ? 'Start of story'
                            : 'Continue — chapter ${resumeAt.seq + 1}',
                      ),
                    ),
                    if (resumeAt != null)
                      TextButton(
                        onPressed: () => _open(beats.first),
                        child: const Text('Start from the beginning'),
                      ),
                  ],
                );
              },
            ),
          ),
          // One button saves the whole story, in order. Kids see only this —
          // the per-chapter badges are a grown-up's tool.
          if (beats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : () => _downloadAll(beats),
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _downloading
                      ? 'Saving chapter ${_downloaded + 1} of ${beats.length}'
                            '${_chapterParts.$2 > 1 ? " — part ${_chapterParts.$1 + 1} of ${_chapterParts.$2}" : ""}…'
                      : "Create the storyteller's audio",
                ),
              ),
            ),
          if (_building) const LinearProgressIndicator(),
          Expanded(
            child: beats.isEmpty
                ? const _Writing()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    // The cover sits above the chapters, with the story name
                    // set over it in real text rather than drawn in.
                    itemCount: beats.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: StoryPicture(
                            seriesId: series.id,
                            kind: StoryImageKind.cover,
                            title: series.title,
                          ),
                        );
                      }
                      final i = index - 1;
                      final b = beats[i];
                      // ListTile has no right-click of its own, so the card
                      // carries it. Same gesture as every other card.
                      return GestureDetector(
                        onSecondaryTap: () => _holdToDeleteChapter(b),
                        child: Card(
                          child: ListTile(
                            onLongPress: () => _holdToDeleteChapter(b),
                            leading: CircleAvatar(child: Text('${b.seq + 1}')),
                            // The number alone for chapters written before
                            // titles existed, and for fallback chapters.
                            title: Text(
                              b.title.trim().isEmpty
                                  ? 'Chapter ${b.seq + 1}'
                                  : 'Chapter ${b.seq + 1} · ${b.title.trim()}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              b.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Per-chapter control is a grown-up's tool; a
                                // child gets the one button above instead.
                                if (parentMode)
                                  _DownloadIcon(
                                    signature: '$voiceSig|$lang|${b.id}',
                                    // Which voice holds it, not merely whether
                                    // something does. A tick meaning "saved"
                                    // when the recording belongs to a voice
                                    // you have since changed away from is a
                                    // promise the app does not keep.
                                    state: () async {
                                      final current = ref
                                          .read(ttsProvider)
                                          .voiceSignature;
                                      final take = await ref
                                          .read(savedNarrationProvider)
                                          .find(
                                            b,
                                            language: lang,
                                            preferred: current,
                                            alternatives:
                                                ref
                                                    .read(knownVoicesProvider)
                                                    .asData
                                                    ?.value ??
                                                const [],
                                          );
                                      if (take == null) {
                                        return (_Narration.none, '');
                                      }
                                      return take.voiceSignature == current
                                          ? (_Narration.thisVoice, '')
                                          : (
                                              _Narration.otherVoice,
                                              take.voiceSignature,
                                            );
                                    },
                                    onDownload: () => ref
                                        .read(ttsProvider)
                                        .preload(
                                          b.text,
                                          language: lang,
                                          notes: b.narration,
                                        ),
                                  ),
                              ],
                            ),
                            onTap: () => _open(b),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (ended && !_building)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('The End  🌙', style: theme.textTheme.titleMedium),
            ),
        ],
      ),
    );
  }
}

class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Writing your story…'),
      ],
    ),
  );
}

/// Per-chapter narration status + on-demand download. A filled "downloaded"
/// badge when the audio is saved on-device; otherwise a tappable cloud that
/// synthesizes (with the current cloud voice), downloads, and saves it.
/// What the app holds for one chapter's narration.
///
/// Narration is keyed by the voice that spoke it, so there is a third state
/// between "saved" and "not saved": saved, but by a voice that is no longer
/// the one chosen. Playback reads in the chosen voice, so such a chapter gets
/// recorded again rather than replayed — and showing that as a plain tick is
/// what made a library with 600 MB of audio in it look empty.
enum _Narration { none, otherVoice, thisVoice }

/// A voice signature as something a grown-up can read. `elevenlabs/eleven_v3/
/// MF3mGyEYCl7XYWbV9V6O` identifies a voice to the cache and nobody else.
String _voiceLabel(String signature) {
  final parts = signature.split('/');
  if (parts.length < 3) return signature;
  final engine = switch (parts.first) {
    'elevenlabs' => 'an ElevenLabs voice',
    'openai' => 'an OpenAI voice',
    // Gemini's voices have names the app gives friendlier labels to; the other
    // engines use opaque ids, where naming the engine is the most that can
    // honestly be said.
    'gemini' => 'the Gemini voice ${voiceLabel(parts.last)}',
    _ => parts.first,
  };
  return engine;
}

class _DownloadIcon extends StatefulWidget {
  const _DownloadIcon({
    required this.state,
    required this.signature,
    required this.onDownload,
  });

  /// Asks [SavedNarration] — the only thing that knows how a chapter is
  /// chunked and keyed — rather than rebuilding a cache key here. It answers
  /// *which* voice holds the recording, because that is what decides whether
  /// pressing play is instant or is a paid re-recording.
  final Future<(_Narration, String)> Function() state;

  /// Changes whenever the voice, language or text does, so the badge rechecks.
  final String signature;
  final Future<void> Function() onDownload;

  @override
  State<_DownloadIcon> createState() => _DownloadIconState();
}

class _DownloadIconState extends State<_DownloadIcon> {
  _Narration _state = _Narration.none;
  String _otherVoice = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(_DownloadIcon old) {
    super.didUpdateWidget(old);
    // Re-check on every rebuild, not just when the signature changes. Playing
    // a chapter caches its audio without changing anything this widget is
    // built from, so a signature-only check kept showing the answer from when
    // the list was first built — audio saved, badge still empty. The check is
    // a handful of cache lookups, which is cheap next to being wrong.
    _check();
  }

  Future<void> _check() async {
    final (state, voice) = await widget.state();
    if (mounted) {
      setState(() {
        _state = state;
        _otherVoice = voice;
      });
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(minutes: 2),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('Downloading narration…'),
          ],
        ),
      ),
    );
    Object? error;
    try {
      await widget.onDownload();
    } catch (e) {
      error = e;
      debugPrint('MoonloomApp: chapter download error → $e');
    }
    await _check();
    if (mounted) setState(() => _busy = false);
    final ok = _state == _Narration.thisVoice;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: error != null,
        duration: Duration(seconds: error != null ? 10 : 4),
        content: Text(
          ok
              ? '✓ Narration saved on this device.'
              : error != null
              ? friendlyProviderError(error)
              : 'No cloud voice active — set one in Voice setup to save '
                    'narration (the free device voice reads live, nothing to save).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_busy) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // Three states, because there are three. The middle one used to show the
    // same tick as the first and then not play — which is how a library with
    // every chapter recorded came to be reported as having no audio at all.
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        switch (_state) {
          _Narration.thisVoice => Icons.download_done_rounded,
          _Narration.otherVoice => Icons.record_voice_over_outlined,
          _Narration.none => Icons.cloud_download_outlined,
        },
        size: 22,
        color: switch (_state) {
          _Narration.thisVoice => theme.colorScheme.primary,
          _Narration.otherVoice => theme.colorScheme.tertiary,
          _Narration.none => theme.disabledColor,
        },
      ),
      tooltip: switch (_state) {
        _Narration.thisVoice => 'Saved in this voice',
        _Narration.otherVoice =>
          'Saved in ${_voiceLabel(_otherVoice)}, not the voice you are using '
              'now. Tap to record it in this one, or switch the voice back.',
        _Narration.none => 'Download narration',
      },
      onPressed: _state == _Narration.thisVoice ? null : _download,
    );
  }
}
