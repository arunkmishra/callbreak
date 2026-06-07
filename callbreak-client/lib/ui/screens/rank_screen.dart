import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/tier_system.dart';
import '../../data/repositories/supabase_repository.dart';
import '../widgets/rank_badge.dart';

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseRepository().getMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131824),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.gold, size: 24),
              const SizedBox(width: 12),
              const Text('HOW RANK WORKS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Rank Points (RP) represent your skill level and standing among other players. You earn RP by participating and winning in matches. The better you perform against your opponents, the more RP you gain. Keep playing, outsmart your opponents, and win games to climb the ranks and reach the prestigious Grandmaster tier!',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('GOT IT', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _profile == null
              ? const Center(child: Text('Failed to load profile', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTopCard(),
                      const SizedBox(height: 16),
                      _buildTimelineCard(),
                    ],
                  ),
                ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0F1A),
      elevation: 0,
      toolbarHeight: 70,
      leadingWidth: 70,
      leading: Center(
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDecorativeLine(isLeft: true),
          const SizedBox(width: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.shield, color: AppColors.gold, size: 28),
              const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.shield, color: Color(0xFF0F1423), size: 22),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.star, color: AppColors.gold, size: 14),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Text(
            'RANK PROGRESS',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          _buildDecorativeLine(isLeft: false),
        ],
      ),
      centerTitle: true,
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: _showInfoDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeLine({required bool isLeft}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            if (isLeft)
              Container(width: 20, height: 1, color: AppColors.gold.withOpacity(0.5)),
            if (isLeft)
              Container(
                margin: const EdgeInsets.only(left: 4),
                child: Transform.rotate(
                  angle: 0.785,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: Center(
                      child: Container(width: 2, height: 2, color: AppColors.gold),
                    ),
                  ),
                ),
              ),
            
            if (!isLeft)
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Transform.rotate(
                  angle: 0.785,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: Center(
                      child: Container(width: 2, height: 2, color: AppColors.gold),
                    ),
                  ),
                ),
              ),
            if (!isLeft)
              Container(width: 20, height: 1, color: AppColors.gold.withOpacity(0.5)),
          ],
        );
      }
    );
  }

  Widget _buildTopCard() {
    final rp = _profile?.rankPoints ?? 1000;
    final rankName = TierSystem.getTierName(rp);
    final rankColor = TierSystem.getTierColor(rp);
    final rankIcon = TierSystem.getTierIcon(rp);
    
    int floorRP = TierSystem.getFloorRPForTier(rp);
    int ceilRP = TierSystem.getCeilRPForTier(rp);
    String nextRankName = TierSystem.getNextTierName(rp);
    double progress = (ceilRP - floorRP) > 0 ? (rp - floorRP) / (ceilRP - floorRP) : 1.0;
    int rpRemaining = ceilRP - rp;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1423),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 10,
            child: Icon(Icons.bar_chart, color: Colors.white.withOpacity(0.03), size: 120),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: rankColor.withOpacity(0.15), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: Center(
                          child: RankBadge(
                            size: 65,
                            baseColor: rankColor,
                            icon: rankIcon,
                            rankName: rankName,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('CURRENT RANK', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(rankName, style: TextStyle(color: rankColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.emoji_events, color: AppColors.gold, size: 14),
                                const SizedBox(width: 6),
                                Text('$rp RP', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text('Keep winning to rank up!', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.white.withOpacity(0.1),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('PROGRESS TO NEXT RANK', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '$rpRemaining RP', style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold)),
                            TextSpan(text: ' to $nextRankName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, barConstraints) {
                          double width = barConstraints.maxWidth;
                          return SizedBox(
                            width: width,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 12,
                                  width: width,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2638),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                Container(
                                  height: 12,
                                  width: width * progress.clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.gold.withOpacity(0.5), blurRadius: 6),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: (width * progress.clamp(0.0, 1.0)) - 10,
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: AppColors.gold,
                                    size: 28,
                                    shadows: [Shadow(color: AppColors.gold.withOpacity(0.8), blurRadius: 8)],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$floorRP RP', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('$ceilRP RP', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    final rp = _profile?.rankPoints ?? 1000;
    final upcomingCeils = TierSystem.getUpcomingTiersCeilRPs(rp, count: 4);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1423),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimelineCurrentNode(rp),
            Expanded(child: _buildTimelineProgressLine(rp)),
            _buildTimelineUpcomingNode(upcomingCeils[0]),
            Expanded(child: _buildTimelineEmptyLine()),
            _buildTimelineUpcomingNode(upcomingCeils[1]),
            Expanded(child: _buildTimelineEmptyLine()),
            _buildTimelineUpcomingNode(upcomingCeils[2]),
            const SizedBox(width: 8),
            _buildTimelineEnd(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCurrentNode(int rp) {
    final rankName = TierSystem.getTierName(rp);
    final rankColor = TierSystem.getTierColor(rp);
    final rankIcon = TierSystem.getTierIcon(rp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rankName, style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0A0F1A),
            border: Border.all(color: rankColor, width: 2),
            boxShadow: [
              BoxShadow(color: rankColor.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: Center(
            child: RankBadge(
              size: 40,
              baseColor: rankColor,
              icon: rankIcon,
              rankName: rankName,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Icon(Icons.arrow_drop_up, color: rankColor, size: 20),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Text('$rp RP', style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTimelineUpcomingNode(int targetRp) {
    final rankName = TierSystem.getTierName(targetRp);
    final rankColor = const Color(0xFF6B7280); // Greyed out
    final rankIcon = TierSystem.getTierIcon(targetRp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rankName, style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0A0F1A),
            border: Border.all(color: rankColor.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: RankBadge(
              size: 40,
              baseColor: rankColor,
              icon: rankIcon,
              rankName: rankName,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('$targetRp RP', style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTimelineProgressLine(int rp) {
    int floorRP = TierSystem.getFloorRPForTier(rp);
    int ceilRP = TierSystem.getCeilRPForTier(rp);
    double progress = (ceilRP - floorRP) > 0 ? (rp - floorRP) / (ceilRP - floorRP) : 1.0;

    return Container(
      margin: const EdgeInsets.only(top: 45), // Align center of circles
      child: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(height: 2, color: Colors.white.withOpacity(0.1)),
              Container(
                height: 2,
                width: width * progress.clamp(0.0, 1.0),
                color: AppColors.gold,
              ),
              Positioned(
                left: (width * progress.clamp(0.0, 1.0)) - 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.8), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildTimelineEmptyLine() {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(top: 45),
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildTimelineEnd() {
    return Container(
      margin: const EdgeInsets.only(top: 35),
      child: const Icon(Icons.keyboard_double_arrow_right, color: Colors.white24, size: 20),
    );
  }
}
