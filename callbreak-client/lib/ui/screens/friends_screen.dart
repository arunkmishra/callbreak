import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../data/services/heartbeat_service.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../core/tier_system.dart';
import 'profile_screen.dart';

// ─── Friends Screen ───────────────────────────────────────────────────────────

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _onlineTimer;
  RealtimeChannel? _friendshipsChannel;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoadingFriends = true;
  bool _isLoadingRequests = true;
  bool _isSearching = false;
  bool _isSearchVisible = false;

  List<Friendship> _friends = [];
  List<Friendship> _requests = [];
  List<UserProfile> _searchResults = [];
  Map<String, String> _onlineUserStatuses = {};

  final Set<String> _pendingSentIds = {};
  String _searchQuery = '';

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _searchResults = [];
        });
      }
    });

    _fetchFriends();
    _fetchRequests();
    _fetchOnlineUsers();

    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchOnlineUsers();
    });

    _friendshipsChannel = Supabase.instance.client.channel('public:friendships');
    _friendshipsChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      callback: (payload) {
        _fetchFriends();
        _fetchRequests();
      },
    ).subscribe();
  }

  @override
  void dispose() {
    _friendshipsChannel?.unsubscribe();
    _onlineTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final friends = await SupabaseRepository().getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends.where((f) => f.profile != null).toList();
        _sortFriendsList();
        _isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFriends = false);
      _showError('Failed to load friends.');
    }
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final reqs = await SupabaseRepository().getPendingRequests();
      if (!mounted) return;
      setState(() {
        _requests = reqs.where((r) => r.profile != null).toList();
        _isLoadingRequests = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingRequests = false);
      _showError('Failed to load friend requests.');
    }
  }

  Future<void> _fetchOnlineUsers() async {
    try {
      final statuses = await HeartbeatService.getOnlineUsers();
      if (!mounted) return;
      setState(() {
        _onlineUserStatuses = statuses;
        _sortFriendsList();
      });
    } catch (_) {}
  }

  void _sortFriendsList() {
    _friends.sort((a, b) {
      final statusA = _onlineUserStatuses[a.profile!.id] ?? 'offline';
      final statusB = _onlineUserStatuses[b.profile!.id] ?? 'offline';
      
      int weight(String s) {
        if (s == 'available') return 2;
        if (s == 'playing') return 1;
        return 0;
      }
      
      final wA = weight(statusA);
      final wB = weight(statusB);
      if (wA != wB) return wB.compareTo(wA);
      return a.profile!.username.toLowerCase().compareTo(b.profile!.username.toLowerCase());
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await SupabaseRepository().searchUsers(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showError('Search failed.');
    }
  }

  // ── Friendship actions ─────────────────────────────────────────────────────

  Future<void> _sendFriendRequest(String targetId) async {
    setState(() => _pendingSentIds.add(targetId));
    try {
      await SupabaseRepository().sendFriendRequest(targetId);
      if (!mounted) return;
      _showSuccess('Friend request sent!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingSentIds.remove(targetId));
      _showError('Could not send friend request.');
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    try {
      await SupabaseRepository().acceptFriendRequest(friendshipId);
      if (!mounted) return;
      _showSuccess('Friend request accepted!');
      await Future.wait([_fetchFriends(), _fetchRequests()]);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not accept request.');
    }
  }

  Future<void> _declineRequest(String friendshipId) async {
    try {
      await SupabaseRepository().declineFriendRequest(friendshipId);
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == friendshipId);
      });
      _showSuccess('Request declined.');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not decline request.');
    }
  }

  Future<void> _unfriendUser(String friendshipId) async {
    try {
      await SupabaseRepository().unfriendUser(friendshipId);
      if (!mounted) return;
      setState(() {
        _friends.removeWhere((f) => f.id == friendshipId);
      });
      _showSuccess('Unfriended successfully.');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not unfriend.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.successGreen),
    );
  }

  bool _isAlreadyFriend(String userId) {
    return _friends.any((f) => f.profile?.id == userId);
  }

  bool _hasPendingRequest(String userId) {
    return _requests.any((r) => r.profile?.id == userId) ||
        _pendingSentIds.contains(userId);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A101C),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isSearchVisible ? _buildSearchBar() : const SizedBox.shrink(),
            ),
            _buildTabBar(),
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildTabContent()
                  : _buildSearchResults(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          
          // Title
          Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt, color: AppColors.gold, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'FRIENDS',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Play together, win together',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),

          // Add Friend Button
          InkWell(
            onTap: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (_isSearchVisible) {
                  _searchFocus.requestFocus();
                } else {
                  _searchFocus.unfocus();
                  _searchController.clear();
                  _searchQuery = '';
                  _searchResults = [];
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1, color: const Color(0xFF34D399), size: 16),
                  const SizedBox(width: 6),
                  const Text('ADD FRIEND', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF131A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _searchFocus.hasFocus ? AppColors.gold.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.search, color: Colors.white30, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search players by username...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _searchUsers(value);
                },
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  _searchFocus.unfocus();
                  setState(() {
                    _searchQuery = '';
                    _searchResults = [];
                  });
                },
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.gold,
        indicatorWeight: 3,
        labelColor: AppColors.gold,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_rounded, size: 18),
                const SizedBox(width: 8),
                Text('FRIENDS (${_friends.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt_1, size: 18),
                const SizedBox(width: 8),
                Text('REQUESTS (${_requests.length})'),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_requests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, color: Colors.white30, size: 14),
          SizedBox(width: 6),
          Text(
            'Add friends, invite them to play and climb the leaderboard together!',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Tab Content ─────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildFriendsTab(),
        _buildRequestsTab(),
      ],
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_friends.isEmpty) {
      return _buildEmptyState('No friends yet', 'Search for players above to add them.');
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_fetchFriends(), _fetchOnlineUsers()]);
      },
      color: AppColors.gold,
      backgroundColor: const Color(0xFF131A2A),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = _friends[index];
          final profile = entry.profile!;
          final isOnline = _onlineUserStatuses.containsKey(profile.id);
          
          return _UserCard(
            profile: profile,
            isOnline: isOnline,
            action: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => _unfriendUser(entry.id),
              icon: const Icon(Icons.person_remove_outlined, color: Colors.white54, size: 14),
              label: const Text('UNFRIEND', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_requests.isEmpty) {
      return _buildEmptyState('No pending requests', 'You have no incoming friend requests.');
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      color: AppColors.gold,
      backgroundColor: const Color(0xFF131A2A),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = _requests[index];
          final profile = req.profile!;
          
          return _UserCard(
            profile: profile,
            isOnline: false,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _declineRequest(req.id),
                  child: const Text('DECLINE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _acceptRequest(req.id),
                  child: const Text('ACCEPT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Search Results ───────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState('No players found', 'Try a different username.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        final alreadyFriend = _isAlreadyFriend(profile.id);
        final hasPending = _hasPendingRequest(profile.id);

        Widget actionWidget;
        if (alreadyFriend) {
          actionWidget = const Text('FRIENDS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold));
        } else if (hasPending) {
          actionWidget = const Text('REQUESTED', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold));
        } else {
          actionWidget = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => _sendFriendRequest(profile.id),
            icon: const Icon(Icons.person_add, color: Colors.white, size: 14),
            label: const Text('ADD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          );
        }

        return _UserCard(
          profile: profile,
          isOnline: false,
          action: actionWidget,
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── Custom User Card ────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserProfile profile;
  final bool isOnline;
  final Widget action;

  const _UserCard({
    required this.profile,
    required this.isOnline,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final initial = profile.username.isNotEmpty ? profile.username[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFF97316), // Orange
    ];
    final avatarColor = colors[profile.username.hashCode % colors.length];
    
    final rp = profile.rankPoints;
    final rankLabel = TierSystem.getTierName(rp);
    final rankColor = TierSystem.getTierColor(rp);
    final rankIcon = TierSystem.getTierIcon(rp);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userProfile: profile)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Avatar with online status
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(color: avatarColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF10B981) : Colors.white30,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF131A2A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(rankIcon, color: rankColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      rankLabel,
                      style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($rp RP)',
                      style: TextStyle(color: rankColor.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF10B981) : Colors.white30,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? const Color(0xFF10B981) : Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Widget (Unfriend / Accept / Request)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [action],
          ),
        ],
      ),
    ));
  }
}
