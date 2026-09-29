import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/story_image.dart';

/// A story's picture, if it has one.
///
/// Silent when there is none. Most stories will not be illustrated — a picture
/// costs more than the story it belongs to — so a plain chapter has to look
/// deliberate rather than broken. No placeholder, no empty frame, no "add a
/// picture" prompt sitting where a picture would be.
class StoryPicture extends ConsumerWidget {
  const StoryPicture({
    super.key,
    required this.seriesId,
    this.beatId,
    this.kind = StoryImageKind.chapter,
    this.title,
  });

  final String seriesId;

  /// Null to look for the story's cover rather than a chapter's picture.
  final String? beatId;
  final StoryImageKind kind;

  /// Set over a cover in real text rather than drawn into it — the title is
  /// always spelled right, stays crisp at any size, and survives the story
  /// renaming itself after the first chapter.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(storyImagesProvider(seriesId)).asData?.value;
    if (images == null) return const SizedBox.shrink();

    final match = images.where((i) {
      if (i.kind != kind) return false;
      return kind == StoryImageKind.cover ? true : i.beatId == beatId;
    });
    if (match.isEmpty) return const SizedBox.shrink();
    final image = match.last;

    return FutureBuilder(
      future: ref.read(pictureStoreProvider).fileFor(image.fileKey),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null || !file.existsSync()) {
          return const SizedBox.shrink();
        }
        final picture = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: image.aspect == '3:4' ? 3 / 4 : 4 / 3,
            child: Image.file(file, fit: BoxFit.cover),
          ),
        );
        final label = title;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: label == null || label.isEmpty
              ? picture
              : _Titled(picture: picture, title: label),
        );
      },
    );
  }
}

/// The title laid over the calm upper third the cover was composed to leave.
class _Titled extends StatelessWidget {
  const _Titled({required this.picture, required this.title});

  final Widget picture;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        picture,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              // A short scrim, so a light sky cannot swallow the lettering.
              // The art was asked to keep this area calm; this is the
              // insurance, not the plan.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0),
                ],
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                height: 1.1,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
