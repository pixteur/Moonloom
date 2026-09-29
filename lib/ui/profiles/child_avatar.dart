import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/child_profile.dart';

/// A child's face, or their initial.
///
/// Square with rounded corners rather than a circle, because a photo of a
/// child crops badly to a circle — a round mask takes the top of the head and
/// the chin and leaves a face filling the frame edge to edge. A rounded square
/// keeps the shoulders, which is what makes it read as a photo of a person
/// rather than a cropped detail.
///
/// Most children will never have a photo, so the lettered version is the
/// common case and has to look like a choice: the same square, the same
/// corners, the child's own colour.
class ChildAvatar extends ConsumerWidget {
  const ChildAvatar({super.key, required this.child, this.size = 64});

  final ChildProfile child;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(size * 0.28);

    Widget initial() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(child.themeColor),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        child.displayName.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.44,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (child.photoKey.isEmpty) return initial();

    return FutureBuilder(
      future: ref.read(pictureStoreProvider).fileFor(child.photoKey),
      builder: (context, snapshot) {
        final file = snapshot.data;
        // The letter stands in while the file resolves and for a photo whose
        // file has gone, so the layout never shifts and a missing photo is
        // never an empty box.
        if (file == null || !file.existsSync()) return initial();
        return ClipRRect(
          borderRadius: radius,
          child: Image.file(
            file,
            width: size,
            height: size,
            // Fills the square and crops the overflow, rather than letterboxing
            // a portrait photo into bars.
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
