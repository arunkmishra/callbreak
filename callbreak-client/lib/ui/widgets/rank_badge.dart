import 'package:flutter/material.dart';

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final hQuarter = height / 4;
    
    path.moveTo(width / 2, 0);
    path.lineTo(width, hQuarter);
    path.lineTo(width, height - hQuarter);
    path.lineTo(width / 2, height);
    path.lineTo(0, height - hQuarter);
    path.lineTo(0, hQuarter);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class RankBadge extends StatelessWidget {
  final double size;
  final Color baseColor;
  final IconData icon;
  final String rankName;

  const RankBadge({
    super.key,
    required this.size,
    required this.baseColor,
    required this.icon,
    required this.rankName,
  });

  @override
  Widget build(BuildContext context) {
    final parts = rankName.split(' ');
    final subTier = parts.length > 1 && const ['I', 'II', 'III'].contains(parts.last) 
        ? parts.last 
        : '';

    // Create a darker and lighter version of the base color for gradients
    final hsl = HSLColor.fromColor(baseColor);
    final darkColor = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    final lightColor = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();

    return SizedBox(
      width: size,
      height: size * 1.1, // slightly taller to accommodate the sub-tier text at the bottom
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // The Hexagon itself
          SizedBox(
            width: size,
            height: size,
            child: ClipPath(
              clipper: HexagonClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lightColor, baseColor, darkColor],
                  ),
                ),
                padding: EdgeInsets.all(size * 0.08), // Border thickness
                child: ClipPath(
                  clipper: HexagonClipper(),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2A2A2A), Color(0xFF151515)],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: size * 0.05), // slightly offset up
                        child: Icon(
                          icon,
                          size: size * 0.45,
                          color: lightColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Sub-tier text replacing the diamond at the bottom
          if (subTier.isNotEmpty)
            Positioned(
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: size * 0.15, vertical: size * 0.02),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [baseColor, darkColor],
                  ),
                  borderRadius: BorderRadius.circular(size * 0.1),
                  border: Border.all(color: lightColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  subTier,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.2,
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
