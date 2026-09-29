import 'package:flutter/material.dart';

/// Show a problem to the parent in a way that does NOT flash and vanish:
/// a floating SnackBar that stays until dismissed (close button), and is also
/// mirrored to the debug console / app log so errors can be diagnosed after the
/// fact. Use for voice/story-AI failures (e.g. provider rate limits or outages).
void showErrorBanner(BuildContext context, String message) {
  // Goes to stdout of the running app, so it lands in the launch log too.
  debugPrint('MoonloomApp error: $message');
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(minutes: 10),
      showCloseIcon: true,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
