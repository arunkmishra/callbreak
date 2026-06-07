import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/tier_system.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../data/services/heartbeat_service.dart';
import '../widgets/rank_badge.dart';
import '../widgets/user_avatar.dart';
import 'username_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const ProfileScreen({super.key, this.userProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = SupabaseRepository();
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  bool _isFriend = false;
  bool _isOnline = false;
  Timer? _onlineTimer;

  bool get _userIsOnline => widget.userProfile == null ? true : _isOnline;

  @override
  void initState() {
    super.initState();
    if (widget.userProfile != null) {
      _profile = widget.userProfile;
      _isLoading = false;
      _fetchFriendshipStatus();
      _fetchOnlineStatus();
      _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchOnlineStatus());
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOnlineStatus() async {
    if (_profile == null) return;
    try {
      final statuses = await HeartbeatService.getOnlineUsers();
      if (mounted) {
        setState(() {
          _isOnline = statuses.containsKey(_profile!.id);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchFriendshipStatus() async {
    if (_profile == null) return;
    try {
      final friends = await _repository.getFriends();
      final isFriend = friends.any((f) => f.profile?.id == _profile!.id);
      if (mounted) {
        setState(() {
          _isFriend = isFriend;
        });
      }
    } catch (_) {}
  }

  Future<void> _addFriend() async {
    if (_profile == null) return;
    try {
      await _repository.sendFriendRequest(_profile!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send friend request.'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.successGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF0891B2),
  ];

  Color _avatarColor(String id) {
    if (id.isEmpty) return _colors[0];
    final code = id.codeUnits.fold(0, (a, b) => a + b);
    return _colors[code % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Darker background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        toolbarHeight: 60, // Compact AppBar
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.userProfile == null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 12.0),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsernameScreen()),
                  ).then((_) => _loadProfile());
                },
                icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 12.0),
              child: _isFriend
                  ? OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.check, size: 14, color: AppColors.successGreen),
                      label: const Text('FRIEND', style: TextStyle(color: AppColors.successGreen, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.successGreen.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _addFriend,
                      icon: const Icon(Icons.person_add, size: 14, color: Colors.white),
                      label: const Text('ADD FRIEND', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (_error != null || _profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load profile\n${_error ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1200),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final p = _profile!;
    final rp = p.rankPoints;
    final rankName = TierSystem.getTierName(rp);
    final rankColor = TierSystem.getTierColor(rp);
    final rankIcon = TierSystem.getTierIcon(rp);
    final winRate = p.totalGames > 0 ? (p.totalWins / p.totalGames * 100).toStringAsFixed(1) : '0.0';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Make children stretch to fill height
          children: [
            // Left Column: Profile Card
            Expanded(
              flex: 4,
              child: _buildProfileCard(p, rankName, rankColor, rankIcon),
            ),
            const SizedBox(width: 16),
            // Right Column: Stats and Rank Progress
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildStatsSection(p, winRate),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 1,
                    child: _buildRankProgressSection(rp, rankName, rankColor, rankIcon),
                  ),
                  if (widget.userProfile == null && Supabase.instance.client.auth.currentUser?.isAnonymous == true) ...[
                    const SizedBox(height: 8),
                    _buildLinkAccountButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile p, String rankName, Color rankColor, IconData rankIcon) {
    String memberSince = 'Unknown';
    if (p.createdAt != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      memberSince = '${months[p.createdAt!.month - 1]} ${p.createdAt!.day}, ${p.createdAt!.year}';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131824), // Lighter card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center vertically
        children: [
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(
                avatarUrl: p.avatarUrl,
                username: p.username,
                radius: 40, // Smaller avatar
                backgroundColor: _avatarColor(p.id),
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              const Positioned(
                top: -6,
                child: Icon(Icons.workspace_premium, color: AppColors.gold, size: 24),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _userIsOnline ? AppColors.successGreen : Colors.white30,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF131824), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Username
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  p.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.userProfile == null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsernameScreen()),
                    ).then((_) => _loadProfile());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.edit, size: 12, color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Rank Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RankBadge(
                size: 32,
                baseColor: rankColor,
                icon: rankIcon,
                rankName: rankName,
              ),
              const SizedBox(width: 8),
              Text(
                rankName.split(' ').first, // e.g. "BRONZE"
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Member Since
          _buildInfoRow(Icons.calendar_today, 'Member Since', memberSince),
          const SizedBox(height: 8),
          // User ID
          _buildInfoRow(
            Icons.location_on, 
            'User ID', 
            p.id.length > 8 ? p.id.substring(0, 8).toUpperCase() : p.id.toUpperCase(), 
            showCopy: true, 
            onCopy: () => _copyToClipboard(p.id, 'User ID')
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool showCopy = false, VoidCallback? onCopy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (showCopy) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onCopy,
              child: const Icon(Icons.copy, color: AppColors.textSecondary, size: 14),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserProfile p, String winRate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131824),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATISTICS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.emoji_events, 
                  AppColors.gold, 
                  'Matches Played', 
                  p.totalGames.toString()
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _buildStatItem(
                  Icons.stars, 
                  AppColors.successGreen, 
                  'Matches Won', 
                  p.totalWins.toString(),
                  subtitle: '$winRate% Win Rate'
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _buildStatItem(
                  Icons.style, 
                  AppColors.spadeBlue, 
                  'Best Score', 
                  p.totalScore.toStringAsFixed(1)
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String label, String value, {String? subtitle}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
          ),
        ]
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildRankProgressSection(int rp, String rankName, Color rankColor, IconData rankIcon) {
    int floorRP = TierSystem.getFloorRPForTier(rp);
    int ceilRP = TierSystem.getCeilRPForTier(rp);
    String nextRankName = TierSystem.getNextTierName(rp);
    
    double progress = (ceilRP - floorRP) > 0 
        ? (rp - floorRP) / (ceilRP - floorRP) 
        : 1.0;
        
    int rpProgress = rp - floorRP;
    int rpTotal = ceilRP - floorRP;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131824),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RANK PROGRESS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              RankBadge(
                size: 48,
                baseColor: rankColor,
                icon: rankIcon,
                rankName: rankName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rankName,
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Keep playing to rank up',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Icon(rankIcon, color: rankColor, size: 10),
                                const SizedBox(width: 4),
                                const Text(
                                  'Next Rank',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 9),
                                ),
                              ],
                            ),
                            Text(
                              nextRankName,
                              style: TextStyle(
                                color: rankColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: rankColor,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: rankColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$rpProgress / $rpTotal RP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildLinkAccountButton() {
    return SizedBox(
      height: 36, // Compact height
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            final redirectTo = kIsWeb
                ? (kReleaseMode ? 'https://arunkmishra.github.io/callbreak/' : Uri.base.origin)
                : 'io.supabase.callbreak://login-callback/';
            await Supabase.instance.client.auth.linkIdentity(
              OAuthProvider.google,
              redirectTo: redirectTo,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account linked successfully!')),
            );
            setState(() {});
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to link account: $e')),
            );
          }
        },
        icon: const Icon(Icons.link_rounded, size: 16),
        label: const Text('Link Google Account', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
