import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui/profiles/profile_select_screen.dart';

/// Root widget. Theming/color config and routing live here; only this UI layer
/// changes meaningfully when porting to touch/iOS. See `docs/ui-ux.md`.
class MoonloomApp extends StatelessWidget {
  const MoonloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moonloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark, // bedtime-friendly default
        ),
      ),
      // Design target is a portrait phone (iPhone). On a wider desktop window we
      // render the whole app inside a centered phone frame so the layout matches
      // the iPhone build; on an actual phone it just fills the screen.
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox()),
      home: const ProfileSelectScreen(),
    );
  }
}

/// Constrains the app to a portrait, phone-width column. When the surrounding
/// window is already phone-sized (a real device, or the portrait Windows
/// window) it passes straight through; on a larger window it centers a
/// phone-shaped frame on a dark backdrop.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  /// Logical phone size (≈ iPhone portrait). Content lays out at this width.
  static const double _phoneWidth = 402;
  static const double _phoneMaxHeight = 900;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Already narrow → real phone (or a portrait desktop window): fill it.
    if (size.width <= _phoneWidth + 40) return child;

    final frameHeight = math.min(size.height - 24, _phoneMaxHeight);
    return ColoredBox(
      color: const Color(0xFF07070B),
      child: Center(
        child: Container(
          width: _phoneWidth,
          height: frameHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                blurRadius: 48,
                spreadRadius: 4,
                color: Color(0x88000000),
              ),
            ],
          ),
          child: MediaQuery(
            // Tell the app its usable size is the frame, not the OS window.
            data: MediaQuery.of(
              context,
            ).copyWith(size: Size(_phoneWidth, frameHeight)),
            child: child,
          ),
        ),
      ),
    );
  }
}
