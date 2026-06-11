import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Displays an emoticon with a bounce animation.
///
/// Place this instance inside the player's Stack. Call [show()] to trigger.
/// The animation lasts 4 seconds (bouncing up and down repeatedly) and then fades out.
class EmoticonOverlay extends StatefulWidget {
  const EmoticonOverlay({super.key});

  @override
  State<EmoticonOverlay> createState() => EmoticonOverlayController();
}

class EmoticonOverlayController extends State<EmoticonOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounce;
  String? _emoji;

  @override
  void initState() {
    super.initState();
    // 2 second total animation
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Creates a repeating sine wave for bouncing
    _bounce = Tween<double>(begin: 0, end: 1).animate(_ctrl);

    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _emoji = null);
        _ctrl.reset();
      }
    });
  }

  /// Trigger the bounce animation for [emoji].
  void show(String emoji) {
    if (!mounted) return;
    _ctrl.reset();
    setState(() => _emoji = emoji);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_emoji == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) {
          final t = _bounce.value; // 0.0 to 1.0 over 2 seconds

          // Fade in (0 to 0.05), hold, fade out (0.95 to 1.0)
          final opacity = t < 0.05
              ? t / 0.05
              : t > 0.95
                  ? (1.0 - t) / 0.05
                  : 1.0;

          // Bounce effect: sin wave. Multiplying t by 4 * PI gives 2 full bounces.
          // math.sin(...) goes from -1 to 1, absolute value goes 0 to 1 to 0 (bounces).
          // We translate Y based on the bounce.
          final bounceY = -20.0 * math.sin(t * 4 * math.pi).abs();

          return Transform.translate(
            offset: Offset(0, bounceY),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(_emoji!, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}
