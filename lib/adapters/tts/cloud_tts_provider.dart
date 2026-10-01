import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' hide AudioCache;

import '../../domain/models/narration.dart';
import '../ai/rate_limit_retry.dart';
import '../audio/audio_kind.dart';
import 'audio_polish.dart';
import 'audio_cache.dart';
import 'narrated_chunks.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// A [TtsProvider] that streams narration smoothly despite a slow cloud
/// synthesizer (Gemini TTS adds ~10s of fixed latency per request). It splits a
/// chapter into a few sizeable chunks and synthesizes them *all* in the
/// background, sequentially, the moment narration starts — so once the first
/// chunk plays the rest are already buffered and playback is gap-free.
///
/// Two levers keep it smooth:
///  * the first chunk is small (fast time-to-audio),
///  * later chunks are large, so each one's playback comfortably outlasts the
///    next chunk's synthesis.
/// Plays via `audioplayers`. See `docs/voice-tts.md`.
class CloudTtsProvider implements TtsProvider {
  CloudTtsProvider(
    this._synth,
    this._id, {
    AudioCache? cache,
    AudioPlayer? player,
  }) : _cache = cache, // ignore: prefer_initializing_formals
       _player = player ?? AudioPlayer() {
    _completeSub = _player.onPlayerComplete.listen((_) => _advance());
    _durSub = _player.onDurationChanged.listen((d) => _duration = d);
    _posSub = _player.onPositionChanged.listen((p) {
      final ms = _duration.inMilliseconds;
      if (ms > 0 && !_progress.isClosed) {
        _progress.add(_chapterProgress(p.inMilliseconds / ms));
      }
    });
  }

  final TtsSynthesizer _synth;
  final TtsProviderId _id;

  final AudioCache? _cache;
  final AudioPlayer _player;
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<Duration> _posSub;
  Duration _duration = Duration.zero;
  final StreamController<TtsState> _states =
      StreamController<TtsState>.broadcast();
  final StreamController<double> _progress =
      StreamController<double>.broadcast();
  final StreamController<void> _done = StreamController<void>.broadcast();
  TtsState _state = TtsState.idle;

  // Chunk queue + a cache of in-flight/finished synthesis jobs, keyed by index.
  List<NarratedChunk> _chunks = const [];

  /// The chapter's standing direction, applied to every chunk on top of that
  /// chunk's own cue.
  NarrationNotes _notes = const NarrationNotes();
  final Map<int, Future<Uint8List>> _jobs = {};
  int _i = 0;
  bool _active = false;
  String _lang = 'en';
  TtsVoicePref _voice = const TtsVoicePref();

  @override
  TtsProviderId get id => _id;

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _states.stream;

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  Stream<void> get onDone => _done.stream;

  @override
  String get voiceSignature => _synth.voiceSignature;

  @override
  String get audioMimeType => _synth.mimeType;

  void _set(TtsState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Start (or return the running) synthesis job for chunk [i]. Serves from the
  /// on-disk cache when possible; otherwise synthesizes (retrying through
  /// transient 429s) and caches the result for instant replay next time.
  Future<Uint8List> _synthAt(int i) => _jobs[i] ??= _cachedSynthesize(
    _chunks[i],
    _lang,
    _voice,
    cancelled: () => !_active,
  );

  /// Where the reading has got to in the **chapter**, 0–1, given how far it has
  /// got through the clip currently playing.
  ///
  /// The player only knows about one clip at a time, so its own position runs
  /// 0→1 for every chunk. Reported raw, a read-along highlight races through
  /// the whole chapter during the first chunk and then does it again for each
  /// one after. Chunks are scaled by character count, which tracks spoken
  /// duration closely enough for a highlight — the alternative needs every
  /// clip synthesized and measured before playback starts.
  double _chapterProgress(double clipFraction) {
    if (_chunks.isEmpty) return 0;
    var total = 0;
    var before = 0;
    for (var j = 0; j < _chunks.length; j++) {
      final len = _chunks[j].text.length;
      total += len;
      if (j < _i) before += len;
    }
    if (total == 0) return 0;
    final current = _i < _chunks.length ? _chunks[_i].text.length : 0;
    return ((before + current * clipFraction) / total).clamp(0.0, 1.0);
  }

  /// The cue is part of the key: it changes the audio without changing a word
  /// of the text, so a key built from text alone would replay the old reading.
  String _keyFor(NarratedChunk chunk, String language) => chunkAudioKey(
    voiceSignature: _synth.voiceSignature,
    language: language,
    chunk: chunk,
  );

  Future<Uint8List> _cachedSynthesize(
    NarratedChunk chunk,
    String language,
    TtsVoicePref voice, {
    bool Function()? cancelled,
  }) async {
    final key = _keyFor(chunk, language);
    final hit = await _cache?.get(key);
    if (hit != null && hit.isNotEmpty) return hit;

    final bytes = await retryOnRateLimit(
      () => _synth.synthesize(
        chunk.text,
        language: language,
        voice: voice,
        cue: chunk.cue,
        standingDirection: _notes.asStandingDirection(),
      ),
      cancelled: cancelled ?? () => false,
    );
    // Even the level and lengthen the paragraph breaks before anything sees
    // this audio, so the cache, the exports and the Lunii pack all carry the
    // same reading. Measured on real output: 18.8 dB of drift inside one
    // request, and paragraph pauses no longer than sentence ones.
    final polished = polishNarration(bytes);
    await _cache?.put(key, polished);
    return polished;
  }

  /// Warm the cache for [text] (the next chapter) without playing it, so paging
  /// forward has no synthesis pause. Runs sequentially in the background and
  /// swallows errors — it's an optimization, not a hard requirement. Does not
  /// touch playback state, so it's safe to call while the current chapter plays.
  @override
  Future<bool> isCached(
    String text, {
    String language = 'en',
    NarrationNotes notes = const NarrationNotes(),
  }) async {
    final cache = _cache;
    if (cache == null) return false;
    final chunks = narratedChunks(text, notes, sizeChunks);
    if (chunks.isEmpty) return false;
    // A chapter counts as saved only when every chunk is — a half-cached
    // chapter still needs the network to finish playing.
    for (final chunk in chunks) {
      final bytes = await cache.get(_keyFor(chunk, language));
      if (bytes == null || bytes.isEmpty) return false;
    }
    return true;
  }

  @override
  Future<void> preload(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationNotes notes = const NarrationNotes(),
    void Function(int done, int total)? onProgress,
  }) async {
    if (_cache == null) return;
    // Warm exactly what playback will ask for, cue and all — otherwise the
    // cache fills with undirected audio that `speak` then misses.
    _notes = notes;
    // Let errors propagate — callers that want best-effort warming already catch
    // them; an explicit "download this chapter" needs to know if it failed.
    final chunks = narratedChunks(text, notes, sizeChunks);
    onProgress?.call(0, chunks.length);
    for (var i = 0; i < chunks.length; i++) {
      await _cachedSynthesize(chunks[i], language, voice);
      onProgress?.call(i + 1, chunks.length);
    }
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationNotes notes = const NarrationNotes(),
  }) async {
    await _player.stop();
    _lang = language;
    _voice = voice;
    _notes = notes;
    _chunks = narratedChunks(text, notes, sizeChunks);
    _jobs.clear();
    _i = 0;
    _active = true;
    _duration = Duration.zero;
    if (!_progress.isClosed) _progress.add(0);
    if (_chunks.isEmpty) {
      _set(TtsState.idle);
      return;
    }
    // NB: we do NOT emit "speaking" here — only once audio actually starts (see
    // _play), so the UI's buffering indicator stays up during synthesis.
    await _play(0); // awaits the FIRST chunk's synthesis, then starts playback
  }

  Future<void> _play(int i) async {
    Uint8List bytes;
    try {
      bytes = await _synthAt(i); // usually already buffered
      // Prefetch exactly ONE chunk ahead while this one plays. Because chunks
      // are large, a chunk's playback comfortably outlasts the next chunk's
      // synthesis, so it's ready in time — and pacing it to playback (rather
      // than firing the whole chapter at once) stays under provider rate limits.
      if (_active && i + 1 < _chunks.length) _synthAt(i + 1);
    } catch (_) {
      // Synthesis failed for real (e.g. rate limit exhausted, no key) — surface
      // it so the reader knows the voice is unavailable.
      _active = false;
      _set(TtsState.idle);
      rethrow;
    }
    if (!_active) return;
    // A degenerate buffer (empty / header-only WAV) can make the Windows audio
    // backend throw a RangeError. Skip it and keep the story going instead of
    // dropping narration entirely.
    if (bytes.length < 64) {
      _advance();
      return;
    }
    try {
      _set(TtsState.speaking); // audio is starting for real now
      // The format comes from the bytes, not from whichever synthesizer
      // happens to be live. A recording outlives the voice that made it, so
      // the two disagree as soon as a saved take is played — and a WAV
      // announced as MP3 simply does not play, silently.
      await _player.play(BytesSource(bytes, mimeType: audioMimeOf(bytes)));
    } catch (_) {
      // This one chunk wouldn't play — skip it and continue with the next.
      _advance();
    }
  }

  void _advance() {
    if (!_active) return;
    _i++;
    if (_i >= _chunks.length) {
      final playedSomething = _state == TtsState.speaking;
      _active = false;
      _set(TtsState.idle);
      // Only a genuine finish (we were actually speaking) counts as "done".
      if (playedSomething && !_done.isClosed) _done.add(null);
      return;
    }
    _play(_i).catchError((_) {
      _active = false;
      _set(TtsState.idle);
    });
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _set(TtsState.paused);
  }

  @override
  Future<void> resume() async {
    await _player.resume();
    _set(TtsState.speaking);
  }

  @override
  Future<void> stop() async {
    _active = false;
    _chunks = const [];
    _jobs.clear();
    await _player.stop();
    if (!_progress.isClosed) _progress.add(0);
    _set(TtsState.idle);
  }

  @override
  Future<void> dispose() async {
    _active = false;
    await _completeSub.cancel();
    await _posSub.cancel();
    await _durSub.cancel();
    await _player.dispose();
    await _states.close();
    await _progress.close();
    await _done.close();
  }
}
