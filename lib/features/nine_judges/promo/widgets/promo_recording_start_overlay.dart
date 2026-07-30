import 'package:flutter/material.dart';

/// The setup-phase gate before a recording screen's auto-play actually
/// starts: the board sits at its resting first frame (with the safe-area
/// guide visible, if requested) while the operator lines up their screen
/// recorder, then taps [onStart] once — at that exact moment, not some
/// arbitrary instant after page load — to begin. Keeps every take free of
/// dead air at the front without needing to trim it out afterward.
///
/// Generic on purpose — any future auto-play recording screen can reuse the
/// same "line it up, then tap" gate, not just [PromoPlayerScreen].
class PromoRecordingStartOverlay extends StatelessWidget {
  const PromoRecordingStartOverlay({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton.icon(
        key: const Key('promo-recording-start'),
        onPressed: onStart,
        icon: const Text('🎬'),
        label: const Text('録画開始'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF2E0A8),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );
}
