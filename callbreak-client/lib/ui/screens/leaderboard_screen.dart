import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────

class _LeaderboardEntry {
  final String id;
  final String username;
  final int totalWins;
  final int totalGames;
  final double totalScore;
  final int rankPoints;

  const _LeaderboardEntry({
    required this.id,
    required this.username,
    required this.totalWins,
    required this.totalGames,
    required this.totalScore,
    required this.rankPoints,
  });

  factory _LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return _LeaderboardEntry(
      id: (map['id'] as String?) ?? '',
      username: (map['username'] as String?) ?? 'Player',
      totalWins: (map['total_wins'] as num?)?.toInt() ?? 0,
      totalGames: (map['total_games'] as num?)?.toInt() ?? 0,
      totalScore: (map['total_score'] as num?)?.toDouble() ?? 0.0,
      rankPoints: (map['rank_points'] as num?)?.toInt() ?? 1000,
    );
  }
}

// ─── Leaderboard Screen ───────────────────────────────────────────────────────

/// Displays a global leaderboard of the top 100 players, ranked by total wins.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<_LeaderboardEntry> _entries = [];
  _LeaderboardEntry? _userEntry;
  int? _userRank;
  bool _isLoading = true;
  String? _error;

  /// Drives the shimmer pulse animation during loading.
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _userEntry = null;
      _userRank = null;
    });

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, username, total_wins, total_games, total_score, rank_points')
          .order('rank_points', ascending: false)
          .order('total_wins', ascending: false)
          .order('total_score', ascending: false)
          .limit(100);

      if (!mounted) return;
      
      final allEntries = (data as List<dynamic>)
          .map((e) => _LeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      final top5 = allEntries.take(5).toList();
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      _LeaderboardEntry? currentUserEntry;
      int? currentUserRank;

      if (userId != null) {
        final userIndex = allEntries.indexWhere((e) => e.id == userId);
        if (userIndex != -1) {
          if (userIndex >= 5) {
            currentUserEntry = allEntries[userIndex];
            currentUserRank = userIndex + 1;
          }
        } else {
          // User not in top 100, fetch specifically
          final userData = await Supabase.instance.client
              .from('profiles')
              .select('id, username, total_wins, total_games, total_score, rank_points')
              .eq('id', userId)
              .maybeSingle();

          if (userData != null) {
            currentUserEntry = _LeaderboardEntry.fromMap(userData);
            
            // Calculate rank using RP
            final rp = currentUserEntry.rankPoints;
            final w = currentUserEntry.totalWins;
            
            final betterPlayers = await Supabase.instance.client
                .from('profiles')
                .select('id')
                .or('rank_points.gt.$rp,and(rank_points.eq.$rp,total_wins.gt.$w)');
                
            currentUserRank = (betterPlayers as List).length + 1;
            if (currentUserRank! <= 5) currentUserRank = 6;
          }
        }
      }

      setState(() {
        _entries = top5;
        _userEntry = currentUserEntry;
        _userRank = currentUserRank;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load leaderboard.\nPlease check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: Stack(
        children: [
          // ── Subtle background painter ────────────────────────────────────
          CustomPaint(
            painter: _LeaderboardBackgroundPainter(),
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1F35),
            Color(0xFF080B14),
          ],
        ),
      ),
      child: Column(
        children: [
          // Back button + title row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFFE082),
                        Color(0xFFFFC107),
                        Color(0xFFFF8F00),
                        Color(0xFFFFC107),
                        Color(0xFFFFE082),
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    ).createShader(bounds),
                    child: const Text(
                      'LEADERBOARD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ),
                // Spacer to balance the back button
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Column labels
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    const SizedBox(width: 44), // rank column
                    const Expanded(
                      child: Text(
                        'PLAYER',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _HeaderCell('RP', width: 52),
                    _HeaderCell('WINS', width: 52),
                    _HeaderCell('SCORE', width: 60),
                  ],
                ),
              ),
            ),
          ),

          // Gold divider
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x60FFC107),
                  Color(0xA0FFC107),
                  Color(0x60FFC107),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) return _buildShimmerList();
    if (_error != null) return _buildError();
    if (_entries.isEmpty) return _buildEmpty();
    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      color: AppColors.gold,
      backgroundColor: const Color(0xFF111827),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _entries.length + (_userEntry != null ? 2 : 0),
        itemBuilder: (context, index) {
          if (index < _entries.length) {
            return _LeaderboardRow(
              rank: index + 1,
              entry: _entries[index],
            );
          } else if (index == _entries.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.2), size: 20),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                ],
              ),
            );
          } else {
            return _LeaderboardRow(
              rank: _userRank ?? 0,
              entry: _userEntry!,
            );
          }
        },
      ),
    );
  }

  Widget _buildShimmerList() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        final opacity = 0.3 + 0.4 * _shimmerAnimation.value;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: 12,
          itemBuilder: (context, index) =>
              _ShimmerRow(opacity: opacity, index: index),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.errorRed,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _fetchLeaderboard,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Color(0xFF1A1200),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              color: AppColors.textSecondary, size: 56),
          SizedBox(height: 16),
          Text(
            'No players yet.\nBe the first to make history!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header Cell ─────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;

  const _HeaderCell(this.label, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Leaderboard Row ─────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final _LeaderboardEntry entry;

  const _LeaderboardRow({required this.rank, required this.entry});

  static const _avatarColors = [
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFF16A34A),
  ];

  Color _avatarColor(String id) {
    if (id.isEmpty) return _avatarColors[0];
    final code = id.codeUnits.fold(0, (a, b) => a + b);
    return _avatarColors[code % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: isTop3
                ? _top3Background(rank).withValues(alpha: 0.08)
                : const Color(0xFF111827).withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTop3
                  ? _medalColor(rank).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.04),
              width: isTop3 ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Rank badge / number ────────────────────────────────────
            SizedBox(
              width: 32,
              child: isTop3 ? _MedalBadge(rank: rank) : _RankNumber(rank: rank),
            ),

            const SizedBox(width: 12),

            // ── Avatar ─────────────────────────────────────────────────
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _avatarColor(entry.id),
                shape: BoxShape.circle,
                boxShadow: isTop3
                    ? [
                        BoxShadow(
                          color: _avatarColor(entry.id).withValues(alpha: 0.4),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  entry.username.isNotEmpty
                      ? entry.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── Username ───────────────────────────────────────────────
            Expanded(
              child: Text(
                entry.username,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isTop3 ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight:
                      isTop3 ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            // ── Stats ──────────────────────────────────────────────────
            _StatCell(
              value: entry.rankPoints.toString(),
              width: 52,
              highlight: isTop3,
            ),
            _StatCell(
              value: entry.totalWins.toString(),
              width: 52,
            ),
            _StatCell(
              value: entry.totalScore.toStringAsFixed(1),
              width: 60,
            ),
          ],
        ),
      ),
    ),
      ),
    );
  }

  Color _medalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC107); // gold
      case 2:
        return const Color(0xFFB0BEC5); // silver
      case 3:
        return const Color(0xFFBF8A6E); // bronze
      default:
        return Colors.transparent;
    }
  }

  Color _top3Background(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC107);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFBF8A6E);
      default:
        return Colors.transparent;
    }
  }
}

// ─── Medal Badge ─────────────────────────────────────────────────────────────

class _MedalBadge extends StatelessWidget {
  final int rank;

  const _MedalBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (rank) {
      1 => (Icons.emoji_events_rounded, const Color(0xFFFFC107)),
      2 => (Icons.emoji_events_rounded, const Color(0xFFB0BEC5)),
      _ => (Icons.emoji_events_rounded, const Color(0xFFBF8A6E)),
    };

    return Icon(icon, color: color, size: 26);
  }
}

// ─── Rank Number ─────────────────────────────────────────────────────────────

class _RankNumber extends StatelessWidget {
  final int rank;

  const _RankNumber({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Text(
      '#$rank',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─── Stat Cell ───────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final double width;
  final bool highlight;

  const _StatCell({
    required this.value,
    required this.width,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: highlight ? AppColors.gold : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Shimmer Row ─────────────────────────────────────────────────────────────

class _ShimmerRow extends StatelessWidget {
  final double opacity;
  final int index;

  const _ShimmerRow({required this.opacity, required this.index});

  @override
  Widget build(BuildContext context) {
    // Slightly stagger opacity so rows look like they cascade
    final staggeredOpacity = (opacity - index * 0.02).clamp(0.1, 0.7);

    return Opacity(
      opacity: staggeredOpacity,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _ShimmerBox(width: 28, height: 14, radius: 4),
              const SizedBox(width: 12),
              _ShimmerBox(width: 36, height: 36, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 12,
                  radius: 4,
                ),
              ),
              const SizedBox(width: 12),
              _ShimmerBox(width: 32, height: 12, radius: 4),
              const SizedBox(width: 8),
              _ShimmerBox(width: 32, height: 12, radius: 4),
              const SizedBox(width: 8),
              _ShimmerBox(width: 40, height: 12, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────

class _LeaderboardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deep space gradient
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.4),
        radius: 1.2,
        colors: [Color(0xFF1A1F35), Color(0xFF080B14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Gold glow at top
    final glowPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -1.3),
        radius: 0.8,
        colors: [Color(0x22FFC107), Colors.transparent],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
      glowPaint,
    );

    // Subtle suit watermarks
    final suits = ['♠', '♦', '♣', '♥'];
    final positions = [
      (0.05, 0.55),
      (0.85, 0.70),
      (0.10, 0.85),
      (0.78, 0.15),
    ];

    for (int i = 0; i < suits.length; i++) {
      final (x, y) = positions[i];
      final tp = TextPainter(
        text: TextSpan(
          text: suits[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.025),
            fontSize: 90.0 + (i % 2) * 20.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x * size.width, y * size.height));
    }

    // Subtle trophy/star decoration using math
    final starPaint = Paint()
      ..color = const Color(0x06FFC107)
      ..style = PaintingStyle.fill;

    final starPath = Path();
    const numPoints = 5;
    const outerRadius = 40.0;
    const innerRadius = 18.0;
    final center =
        Offset(size.width * 0.92, size.height * 0.92);

    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi / numPoints) - math.pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        starPath.moveTo(point.dx, point.dy);
      } else {
        starPath.lineTo(point.dx, point.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
