import 'provider_exceptions.dart';

/// Retry [action] on a busy server — 429 or 503 — with exponential backoff.
///
/// Gemini's free tier caps requests per minute (e.g. 10/min for TTS) and
/// returns 429 with a short "retry in ~1s" window, so a few spaced retries
/// recover transparently instead of failing the narration/story.
///
/// 503 belongs here for the same reason and was missing: the image model
/// answers "This model is currently experiencing high demand. Spikes in demand
/// are usually temporary. Please try again later." — which is the server
/// asking to be retried. Without it, one busy moment silently cost a story its
/// cover. Everything else rethrows immediately; gives up after [maxAttempts].
///
/// [cancelled] lets a caller bail out early (e.g. the user stopped playback).
Future<T> retryOnRateLimit<T>(
  Future<T> Function() action, {
  int maxAttempts = 4,
  Duration firstDelay = const Duration(milliseconds: 1500),
  bool Function()? cancelled,
}) async {
  var delay = firstDelay;
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } on ProviderRequestException catch (e) {
      final retryable = e.statusCode == 429 || e.statusCode == 503;
      final giveUp =
          !retryable || attempt >= maxAttempts || (cancelled?.call() ?? false);
      if (giveUp) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}
