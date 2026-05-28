import 'package:flutter/material.dart';

class TechBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    // Subtle grid pattern
    const double gridSize = 60.0;
    for (double i = 0; i <= size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Tech rings in the center
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 120, ringPaint);
    
    final thinRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, 200, thinRingPaint);

    // Crosshairs in the center
    canvas.drawLine(
      Offset(center.dx - 15, center.dy),
      Offset(center.dx + 15, center.dy),
      thinRingPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 15),
      Offset(center.dx, center.dy + 15),
      thinRingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TechBackground extends StatelessWidget {
  final Color color;
  final Color lightColor;
  final Widget? child;

  const TechBackground({
    super.key,
    required this.color,
    required this.lightColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [lightColor, color],
        ),
      ),
      child: CustomPaint(
        painter: TechBackgroundPainter(),
        child: child,
      ),
    );
  }
}
