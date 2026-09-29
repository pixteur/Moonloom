import 'dart:async';

import 'package:uuid/uuid.dart';

import '../adapters/ai/ai_provider.dart';
import '../adapters/storage/storage_repo.dart';
import 'age_policy.dart';
import 'beat_store.dart';
import 'models/beat.dart';
import 'models/cast_changes.dart';
import 'models/child_profile.dart';
import 'models/learned_profile.dart';
import 'models/series.dart';
import 'models/story_request.dart';
import 'models/story_segment.dart';
import 'prompt_builder.dart';
import 'safety_guard.dart';
import 'spoken_text.dart';

/// Orchestrates one story turn end-to-end:
/// gather context → build prompt → generate → SafetyGuard → (retry/fallback) →
/// persist a Beat → update the LearnedProfile + story bible.
///
/// Bedtime must never break: on repeated failure or unsafe output it falls back
/// to a safe pre-written beat. See `docs/architecture.md`, `docs/safety.md`.
class StoryEngine {
  StoryEngine({
    required AiProvider ai,
    required StorageRepo repo,
    BeatStore? beatStore,
    PromptBuilder promptBuilder = const PromptBuilder(),
    SafetyGuard safetyGuard = const SafetyGuard(),
    List<String> bannedThemes = BannedThemes.defaults,
    int maxRetries = 2,
    int maxChapters = 7,
    int? minChapters,
    bool refinePass = true,
    Uuid? uuid,
  }) : _ai = ai, // ignore: prefer_initializing_formals
       _repo = repo,
       _beats = beatStore ?? BeatStore(repo),
       _prompt = promptBuilder,
       _safety = safetyGuard,
       _banned = bannedThemes,
       _maxRetries = maxRetries, // ignore: prefer_initializing_formals
       _maxChapters = maxChapters, // ignore: prefer_initializing_formals
       _minChapters = minChapters, // ignore: prefer_initializing_formals
       _refinePass = refinePass, // ignore: prefer_initializing_formals
       _uuid = uuid ?? const Uuid();

  final AiProvider _ai;
  final StorageRepo _repo;
  final BeatStore _beats;
  final PromptBuilder _prompt;
  final SafetyGuard _safety;
  final List<String> _banned;
  final int _maxRetries;
  final int _maxChapters;

  /// Overrides the floor a story's length would set. Null — the normal case —
  /// derives it from the child's chosen chapter length; tests pin it.
  final int? _minChapters;

  /// How many chapters a story of this length owes before it may end.
  ///
  /// "Long" means long: a child who asked for long stories and got two
  /// chapters was told one thing and given another, and the model will
  /// happily resolve everything early if nothing stops it. A long story is
  /// therefore **exactly seven** — one chapter a night, Monday to Sunday —
  /// with the floor and the ceiling set to the same number so it can neither
  /// finish early nor run on into a second week.
  /// Clamped to [_maxChapters], which is the one bound nothing may exceed: it
  /// exists to stop runaway generation burning through quota, so a caller
  /// capping a story at three chapters must get three even from a length whose
  /// floor is higher. Without this the ceiling below computes `5.clamp(4, 3)`,
  /// an invalid range.
  int _floorFor(DetailLevel level) =>
      (_minChapters ??
              switch (level) {
                DetailLevel.short => 1,
                DetailLevel.medium => 3,
                DetailLevel.long => _weekOfChapters,
              })
          .clamp(1, _maxChapters);

  /// The last chapter a story of this length may have.
  ///
  /// Per length rather than one global number, because "at most seven" is
  /// only right for the length that wants seven. [_maxChapters] stays as the
  /// absolute ceiling above all of them — it exists to stop runaway
  /// generation burning through quota when a model will not conclude, and
  /// nothing here may exceed it.
  int _ceilingFor(DetailLevel level) => switch (level) {
    // One sitting, beginning to end — a mini episode rather than a short
    // serial. A child who wants a story tonight and nothing hanging over
    // tomorrow is asking for a different thing, not a smaller one.
    DetailLevel.short => 1,
    DetailLevel.medium => 4,
    DetailLevel.long => _weekOfChapters,
  }.clamp(_floorFor(level), _maxChapters);

  /// A week of bedtimes. The point of a long story is that it lasts one.
  static const int _weekOfChapters = 7;

  /// Whether a generated chapter gets a second, editorial pass before it is
  /// saved. Costs one extra call per chapter, so tests turn it off.
  final bool _refinePass;
  final Uuid _uuid;

  /// Per-series generation lock so concurrent turns (e.g. background
  /// auto-complete + a user tap) can't compute the same `seq` and duplicate a
  /// chapter. Turns for a series run one at a time.
  final Map<String, Future<void>> _locks = {};

  /// Why the last turn used the safe fallback instead of a generated chapter
  /// (API error or safety rejection), or null if the real provider succeeded.
  /// The UI surfaces this so silent "generic" chapters become diagnosable.
  String? lastFallbackReason;

  /// Produce, vet, and persist the next beat for [series]. Serialized per series.
  Future<Beat> takeTurn({
    required ChildProfile child,
    required Series series,
    required StoryIntent intent,
    String? chosenTwist,
  }) async {
    final prior = _locks[series.id];
    final gate = Completer<void>();
    _locks[series.id] = gate.future;
    try {
      if (prior != null) {
        try {
          await prior;
        } catch (_) {
          /* a failed prior turn shouldn't block the next */
        }
      }
      return await _runTurn(
        child: child,
        series: series,
        intent: intent,
        chosenTwist: chosenTwist,
      );
    } finally {
      gate.complete();
      if (identical(_locks[series.id], gate.future)) _locks.remove(series.id);
    }
  }

  /// Run the editorial second pass over a chapter that is already written.
  ///
  /// Same pass a fresh chapter gets, applied to saved text — used to produce a
  /// refined copy of a finished story without touching the original. Returns
  /// null when the polish fails its checks, and the caller keeps the chapter
  /// as it stands.
  Future<StorySegment?> refineExisting({
    required ChildProfile child,
    required Series series,
    required Beat beat,
    List<Beat> earlier = const [],
    int totalChapters = 0,
  }) {
    final request = StoryRequest(
      child: child,
      series: series,
      intent: beat.intent,
      recentBeats: earlier,
      chapterNumber: beat.seq + 1,
      // The real chapter count, so a long story's later chapters aren't
      // treated as if they had run past the cap.
      maxChapters: totalChapters > 0 ? totalChapters : beat.seq + 1,
      chosenTwist: beat.chosenTwist,
    );
    return _refine(
      request,
      StorySegment(
        storyText: beat.text,
        summary: beat.summary,
        rating: beat.rating,
        chapterTitle: beat.title,
        setting: beat.setting,
        characters: beat.characters,
        openThreads: beat.openThreads,
        isFinal: beat.isFinal,
      ),
    );
  }

  Future<Beat> _runTurn({
    required ChildProfile child,
    required Series series,
    required StoryIntent intent,
    String? chosenTwist,
  }) async {
    final ctx = await _beats.recentContext(series.id);
    final interests = await _repo.loadInterests(child.id);
    // Pull in the world premise + saved cast so episodes stay in-universe.
    final worldId = series.worldId;
    final world = worldId == null ? null : await _repo.loadWorldById(worldId);
    final cast = worldId == null
        ? const <String>[]
        : (await _repo.loadCharacters(
            worldId,
          )).map((c) => c.promptLine).toList();
    // Cast edits are honoured by the first chapter of the next story, so a
    // departing character gets their send-off there rather than mid-story.
    final isFirstChapter = ctx.nextSeq == 0;
    final castChanges = isFirstChapter
        ? (world?.pendingCastChanges ?? CastChanges.none)
        : CastChanges.none;

    final request = StoryRequest(
      child: child,
      series: series,
      intent: intent,
      recentBeats: ctx.recentBeats,
      interests: interests,
      chosenTwist: chosenTwist,
      chapterNumber: ctx.nextSeq + 1,
      maxChapters: _ceilingFor(child.detailLevel),
      minChapters: _floorFor(child.detailLevel),
      worldPremise: world?.premise ?? '',
      cast: cast,
      castChanges: castChanges,
    );
    final prompt = _prompt.build(request, bannedThemes: _banned);
    final band = child.ageBand;

    StorySegment? safe;
    String? reason;
    for (var attempt = 0; attempt <= _maxRetries && safe == null; attempt++) {
      try {
        final segment = await _ai.generate(prompt);
        final verdict = _safety.review(
          segment,
          band: band,
          bannedThemes: _banned,
        );
        if (verdict.ok) {
          safe = segment;
        } else {
          reason = 'safety rejected (${verdict.reasons.join(", ")})';
        }
      } catch (e) {
        // Swallow and retry; the fallback below guarantees a result.
        reason = e.toString();
      }
    }
    if (safe == null) {
      lastFallbackReason = reason ?? 'unknown error';
      safe = _fallback();
    } else {
      lastFallbackReason = null;
      // Second pass, before the chapter is saved or shown: the model edits its
      // own draft. A refusal here is not a failure — we simply keep the draft.
      if (_refinePass) safe = await _refine(request, safe) ?? safe;
    }

    // Enforce both bounds. The cap stops runaway generation (and quota burn):
    // the last allowed chapter is always final, whatever the model says. The
    // floor is the other half — a model asked for "about 3 to 6 chapters" will
    // wrap the whole story up in two, so an early is_final is overruled and
    // the next turn carries on. The prompt asks as well, but asking alone
    // produced two-chapter stories.
    final isFinal =
        (safe.isFinal && !request.mayNotEndYet) || request.mustConclude;

    final beat = Beat(
      id: _uuid.v4(),
      seriesId: series.id,
      childId: child.id,
      seq: ctx.nextSeq,
      intent: intent,
      chosenTwist: chosenTwist,
      // Asking the model to keep markup out works nearly always; the misses
      // get read aloud to a child as "asterisk brillant asterisk". Enforced
      // here so every path — draft, refined, or fallback — goes through it.
      text: stripSpokenMarkup(safe.storyText),
      summary: stripSpokenMarkup(safe.summary),
      title: _chapterTitle(safe.chapterTitle, ctx.recentBeats),
      rating: safe.rating,
      setting: safe.setting,
      characters: safe.characters,
      openThreads: isFinal ? const [] : safe.openThreads,
      language: languageFor(series, child.language),
      isFinal: isFinal,
      narration: safe.narration,
    );
    await _beats.append(beat);
    await _recordLearning(child.id, intent, chosenTwist);
    await _saveSeriesProgress(
      series,
      safe,
      // Any chapter may name the story, not only the first. Naming used to be
      // first-chapter-only, so one fallback on chapter 1 — a rate limit is
      // enough — left the "Naming it…" placeholder showing to a child for the
      // life of the story with no way back. `autoTitle` switches itself off
      // once a name sticks, so this stops on its own.
      nameIt: series.autoTitle && lastFallbackReason == null,
    );
    // The send-off has been written, so the world's cast is settled again.
    // (A fallback chapter didn't say goodbye — keep them pending for next time.)
    if (world != null && castChanges.isNotEmpty && lastFallbackReason == null) {
      await _repo.saveWorld(
        world.copyWith(pendingCastChanges: CastChanges.none),
      );
    }
    return beat;
  }

  /// Hand the draft back to the model as an editor and take the result only if
  /// it is demonstrably still the same chapter. Returns null to keep the draft.
  ///
  /// Nothing here is trusted on the model's word. A model asked to polish can
  /// answer with a summary, a critique, or an empty string, and any of those
  /// would silently replace a good chapter with rubbish that a child then
  /// hears read aloud — so the length is measured, the safety guard runs
  /// again, and the plot-critical fields are carried over from the draft
  /// rather than accepted from the edit.
  Future<StorySegment?> _refine(
    StoryRequest request,
    StorySegment draft,
  ) async {
    final before = _wordCount(draft.storyText);
    if (before == 0) return null;
    try {
      final polished = await _ai.generate(
        _prompt.buildRefinement(request, draft, bannedThemes: _banned),
      );
      final after = _wordCount(polished.storyText);
      // Deliberately wider than the ±10% the prompt asks for: this is here to
      // catch a summary or a truncation, not to police the brief.
      if (after < before * 0.6 || after > before * 1.5) return null;

      // A polish that comes back as one unbroken block is unusable however
      // good the prose is: the reader synthesizes a chunk per paragraph and
      // matches narration cues to them by index.
      final text = restoreParagraphs(polished.storyText, draft.storyText);
      if (text == null) return null;
      final verdict = _safety.review(
        polished,
        band: request.child.ageBand,
        bannedThemes: _banned,
      );
      if (!verdict.ok) return null;

      return StorySegment(
        storyText: text,
        summary: _preferring(polished.summary, draft.summary),
        rating: draft.rating,
        suggestedTitle: _preferring(
          polished.suggestedTitle,
          draft.suggestedTitle,
        ),
        chapterTitle: _preferring(polished.chapterTitle, draft.chapterTitle),
        setting: _preferring(polished.setting, draft.setting),
        sensitiveFlags: polished.sensitiveFlags,
        characters: polished.characters.isEmpty
            ? draft.characters
            : polished.characters,
        openThreads: polished.openThreads.isEmpty
            ? draft.openThreads
            : polished.openThreads,
        // Never the edit's call: the chapter cap and the next chapter's
        // existence were both decided against the draft.
        isFinal: draft.isFinal,
        // The editor saw the finished prose, so its direction wins — but a
        // silent editor leaves the draft's standing voice in place.
        narration: polished.narration.isEmpty
            ? draft.narration
            : polished.narration,
      );
    } catch (_) {
      // A polish that errors must not cost the child their bedtime story.
      return null;
    }
  }

  /// Put a refined chapter's paragraph breaks back, or reject it.
  ///
  /// Asked for prose inside a JSON string, a model very often separates
  /// paragraphs with a single newline instead of a blank line. That reads
  /// identically on screen but collapses the chapter into one chunk for the
  /// reader, so single newlines are promoted back to real breaks. A chapter
  /// that came back with no line breaks at all cannot be repaired and is
  /// rejected in favour of the draft.
  ///
  /// Returns the usable text, or null to keep the draft.
  static String? restoreParagraphs(String polished, String draft) {
    final wanted = _paragraphCount(draft);
    if (wanted < 2 || _paragraphCount(polished) >= wanted) return polished;
    final repaired = polished.replaceAll(RegExp(r'\n[ \t]*\n?'), '\n\n');
    // Half the draft's paragraphs is a generous floor: an editor is allowed to
    // merge two short ones, but not to flatten the chapter.
    return _paragraphCount(repaired) >= (wanted / 2).ceil() ? repaired : null;
  }

  static int _paragraphCount(String text) =>
      text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;

  static String _preferring(String edited, String original) =>
      edited.trim().isEmpty ? original : edited;

  static int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// A safe pre-written beat so the night never breaks.
  StorySegment _fallback() => const StorySegment(
    storyText:
        'Tonight, a soft cloud drifted by and offered a quiet, cozy ride. '
        'Wrapped in starlight, everyone felt calm, safe, and sleepy as the '
        'moon hummed a gentle lullaby.',
    summary: 'A calm, cozy cloud ride under a humming moon.',
    rating: AgeRating.tiny,
    setting: 'a soft, starlit sky',
    characters: [],
    openThreads: [],
  );

  Future<void> _recordLearning(
    String childId,
    StoryIntent intent,
    String? chosenTwist,
  ) async {
    // Only twist-card / dice choices feed twist affinity (free requests don't).
    if (chosenTwist == null ||
        (intent != StoryIntent.dice && intent != StoryIntent.option)) {
      return;
    }
    final current =
        await _repo.loadLearnedProfile(childId) ??
        LearnedProfile(childId: childId);
    final affinity = Map<String, int>.from(current.twistAffinity);
    affinity[chosenTwist] = (affinity[chosenTwist] ?? 0) + 1;
    await _repo.saveLearnedProfile(current.copyWith(twistAffinity: affinity));
  }

  /// Roll the summary into the story bible and, for a story the grown-up left
  /// unnamed, adopt the title the model drew from the chapter it just wrote.
  Future<void> _saveSeriesProgress(
    Series series,
    StorySegment segment, {
    required bool nameIt,
  }) async {
    final combined = '${series.storyBible} ${segment.summary}'.trim();
    // Keep the bible bounded so context stays cheap.
    final bible = combined.length > 1200
        ? combined.substring(combined.length - 1200)
        : combined;
    final title = nameIt ? _cleanTitle(segment.suggestedTitle) : null;
    await _repo.saveSeries(
      series.copyWith(
        storyBible: bible,
        title: title,
        autoTitle: title == null ? null : false,
      ),
    );
    if (title != null) await _nameWorldAfterStory(series, title);
  }

  /// A world created alongside an unnamed story is itself unnamed — it took
  /// the story's placeholder, because there was nothing else to call it. Once
  /// the story has a real name, the world takes it too.
  ///
  /// Guarded on the names still matching: a world the grown-up named, or one
  /// that already holds other episodes, is left alone.
  Future<void> _nameWorldAfterStory(Series series, String title) async {
    final worldId = series.worldId;
    if (worldId == null) return;
    final world = await _repo.loadWorldById(worldId);
    if (world == null || world.name.trim() != series.title.trim()) return;
    await _repo.saveWorld(world.copyWith(name: title));
  }

  /// Tidy the model's title suggestion: strip wrapping quotes and trailing
  /// punctuation, cap the length, and reject anything unusable (null → keep
  /// the placeholder and try again next chapter).
  static String? _cleanTitle(String raw) {
    var t = raw
        .trim()
        .replaceAll(RegExp(r'^["“”\x27]+|["“”\x27.]+$'), '')
        .trim();
    if (t.length > 60) t = t.substring(0, 60).trim();
    if (t.isEmpty || _isJustANumbering(t)) return null;
    return t;
  }

  /// This chapter's title, or empty when there isn't a usable one.
  ///
  /// A title already used by a recent chapter is dropped rather than shown
  /// twice: two chapters running called "The Whispering Nebula" tells a child
  /// nothing about either. The prompt lists the used titles as well, so this
  /// is a backstop, not the whole answer.
  static String _chapterTitle(String raw, List<Beat> earlier) {
    final cleaned = _cleanTitle(raw);
    if (cleaned == null) return '';
    final taken = earlier.map((b) => b.title.trim().toLowerCase());
    return taken.contains(cleaned.toLowerCase()) ? '' : cleaned;
  }

  /// True for a "title" that only restates the chapter number.
  ///
  /// The chapter list already prints the number, so "Chapter One" renders as
  /// "Chapter 1 · Chapter One". Asking the model not to do it is not enough on
  /// its own — it fills the field with a label whenever nothing better comes
  /// to mind — and an absent title renders as the plain number, which is what
  /// it meant anyway.
  static bool _isJustANumbering(String title) => RegExp(
    r'^(chapter|chapitre|cap[íi]tulo|kapitel|capitolo|part)\s*'
    r'[-–—:.]?\s*'
    r'(\d+|one|two|three|four|five|six|seven|eight|nine|ten|'
    r'une?|deux|trois|quatre|cinq|sept|huit|neuf|dix|'
    r'dos|tres|cuatro|cinco|seis)?$',
    caseSensitive: false,
  ).hasMatch(title.trim());
}
