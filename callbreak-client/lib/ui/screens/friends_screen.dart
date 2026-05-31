import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../data/services/heartbeat_service.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class _FriendProfile {
  final String id;
  final String username;

  const _FriendProfile({required this.id, required this.username});

  factory _FriendProfile.fromMap(Map<String, dynamic> map) {
    return _FriendProfile(
      id: (map['id'] as String?) ?? '',
      username: (map['username'] as String?) ?? 'Player',
    );
  }
}

class _FriendEntry {
  final String friendshipId;
  final _FriendProfile profile;

  const _FriendEntry({required this.friendshipId, required this.profile});
}

class _RequestEntry {
  final String friendshipId;
  final _FriendProfile requester;

  const _RequestEntry({
    required this.friendshipId,
    required this.requester,
  });
}

// ─── Friends Screen ───────────────────────────────────────────────────────────

/// Two-tab screen: accepted friends and pending incoming friend requests.
/// Also includes a search bar to find users and send friend requests.
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

  List<_FriendEntry> _friends = [];
  List<_RequestEntry> _requests = [];
  List<_FriendProfile> _searchResults = [];
  Map<String, String> _onlineUserStatuses = {};

  /// IDs of users the current user has already sent a request to (in-session
  /// cache so we can disable the "Send" button immediately after tapping).
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
        // Clear search when switching tabs
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

    // Poll online status every 15 seconds
    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchOnlineUsers();
    });

    // Listen to real-time updates on friendships table
    _friendshipsChannel = Supabase.instance.client.channel('public:friendships');
    _friendshipsChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      callback: (payload) {
        // When any friendship changes, refresh the lists so both users see the update instantly
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
    final uid = _currentUserId;
    if (uid == null) return;

    setState(() => _isLoadingFriends = true);

    try {
      // Fetch accepted friendships where current user is requester
      final asRequester = await Supabase.instance.client
          .from('friendships')
          .select('id, addressee:profiles!friendships_addressee_id_fkey(id, username)')
          .eq('requester_id', uid)
          .eq('status', 'accepted');

      // Fetch accepted friendships where current user is addressee
      final asAddressee = await Supabase.instance.client
          .from('friendships')
          .select('id, requester:profiles!friendships_requester_id_fkey(id, username)')
          .eq('addressee_id', uid)
          .eq('status', 'accepted');

      if (!mounted) return;

      final List<_FriendEntry> combined = [];

      for (final row in asRequester as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final profileData = map['addressee'];
        if (profileData != null) {
          combined.add(_FriendEntry(
            friendshipId: map['id'] as String,
            profile: _FriendProfile.fromMap(profileData as Map<String, dynamic>),
          ));
        }
      }

      for (final row in asAddressee as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final profileData = map['requester'];
        if (profileData != null) {
          combined.add(_FriendEntry(
            friendshipId: map['id'] as String,
            profile: _FriendProfile.fromMap(profileData as Map<String, dynamic>),
          ));
        }
      }

      setState(() {
        _friends = combined;
        _isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFriends = false);
      _showError('Failed to load friends.');
    }
  }

  Future<void> _fetchRequests() async {
    final uid = _currentUserId;
    if (uid == null) return;

    setState(() => _isLoadingRequests = true);

    try {
      final data = await Supabase.instance.client
          .from('friendships')
          .select('id, requester:profiles!friendships_requester_id_fkey(id, username)')
          .eq('addressee_id', uid)
          .eq('status', 'pending');

      if (!mounted) return;

      final List<_RequestEntry> entries = [];
      for (final row in data as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final profileData = map['requester'];
        if (profileData != null) {
          entries.add(_RequestEntry(
            friendshipId: map['id'] as String,
            requester: _FriendProfile.fromMap(profileData as Map<String, dynamic>),
          ));
        }
      }

      setState(() {
        _requests = entries;
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
      setState(() => _onlineUserStatuses = statuses);
    } catch (_) {
      // Online status is non-critical — fail silently
    }
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
      final uid = _currentUserId;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, username')
          .ilike('username', '%${query.trim()}%')
          .limit(20);

      if (!mounted) return;

      // Filter out current user
      final results = (data as List<dynamic>)
          .map((e) => _FriendProfile.fromMap(e as Map<String, dynamic>))
          .where((p) => p.id != uid)
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showError('Search failed. Please try again.');
    }
  }

  // ── Friendship actions ─────────────────────────────────────────────────────

  Future<void> _sendFriendRequest(String targetId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    // Optimistically update UI
    setState(() => _pendingSentIds.add(targetId));

    try {
      await Supabase.instance.client.from('friendships').insert({
        'requester_id': uid,
        'addressee_id': targetId,
        'status': 'pending',
      });

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
      await Supabase.instance.client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

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
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('id', friendshipId);

      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.friendshipId == friendshipId);
      });
      _showSuccess('Request declined.');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not decline request.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _isAlreadyFriend(String userId) {
    return _friends.any((f) => f.profile.id == userId);
  }

  bool _hasPendingRequest(String userId) {
    return _requests.any((r) => r.requester.id == userId) ||
        _pendingSentIds.contains(userId);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: Stack(
        children: [
          CustomPaint(
            painter: _FriendsBackgroundPainter(),
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                _buildTabBar(),
                Expanded(
                  child: _searchQuery.isEmpty
                      ? _buildTabContent()
                      : _buildSearchResults(),
                ),
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
          colors: [Color(0xFF1A1F35), Color(0xFF080B14)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
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
                'FRIENDS',
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
          // Badge showing incoming requests count
          if (_requests.isNotEmpty)
            Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_requests.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchFocus.hasFocus
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.person_search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search players by username…',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
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
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF1A1200),
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Friends (${_friends.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('Requests'),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_friends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No friends yet',
        subtitle: 'Search for players above\nto send friend requests.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_fetchFriends(), _fetchOnlineUsers()]);
      },
      color: AppColors.gold,
      backgroundColor: const Color(0xFF111827),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final entry = _friends[index];
          final isOnline = _onlineUserStatuses.containsKey(entry.profile.id);
          return _FriendTile(
            profile: entry.profile,
            isOnline: isOnline,
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_rounded,
        title: 'No pending requests',
        subtitle: 'When someone sends you\na friend request, it appears here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      color: AppColors.gold,
      backgroundColor: const Color(0xFF111827),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return _RequestTile(
            entry: req,
            onAccept: () => _acceptRequest(req.friendshipId),
            onDecline: () => _declineRequest(req.friendshipId),
          );
        },
      ),
    );
  }

  // ── Search Results ───────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No players found',
        subtitle: 'Try a different username.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        final alreadyFriend = _isAlreadyFriend(profile.id);
        final hasPending = _hasPendingRequest(profile.id);

        return _SearchResultTile(
          profile: profile,
          alreadyFriend: alreadyFriend,
          hasPending: hasPending,
          onSendRequest: () => _sendFriendRequest(profile.id),
        );
      },
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Friend Tile ─────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final _FriendProfile profile;
  final bool isOnline;

  const _FriendTile({required this.profile, required this.isOnline});

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF0891B2),
  ];

  Color _avatarColor() {
    if (profile.id.isEmpty) return _colors[0];
    final code = profile.id.codeUnits.fold(0, (a, b) => a + b);
    return _colors[code % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _avatarColor(),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    profile.username.isNotEmpty
                        ? profile.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF111827),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline
                        ? const Color(0xFF22C55E)
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        isOnline ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // Invite to game button (future feature placeholder)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.gold.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOnline
                    ? AppColors.gold.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              isOnline ? 'Invite' : 'Offline',
              style: TextStyle(
                color: isOnline ? AppColors.gold : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Request Tile ─────────────────────────────────────────────────────────────

class _RequestTile extends StatefulWidget {
  final _RequestEntry entry;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestTile({
    required this.entry,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _isActing = false;

  Future<void> _handleAccept() async {
    setState(() => _isActing = true);
    widget.onAccept();
  }

  Future<void> _handleDecline() async {
    setState(() => _isActing = true);
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFF2563EB),
      Color(0xFFDC2626),
      Color(0xFFD97706),
      Color(0xFF0891B2),
    ];

    final profile = widget.entry.requester;
    final code = profile.id.codeUnits.fold(0, (a, b) => a + b);
    final avatarColor = colors[code % colors.length];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                profile.username.isNotEmpty
                    ? profile.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Wants to be your friend',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Accept / Decline buttons
          if (_isActing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decline
                GestureDetector(
                  onTap: _handleDecline,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.errorRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.errorRed,
                      size: 18,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Accept
                GestureDetector(
                  onTap: _handleAccept,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Search Result Tile ───────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final _FriendProfile profile;
  final bool alreadyFriend;
  final bool hasPending;
  final VoidCallback onSendRequest;

  const _SearchResultTile({
    required this.profile,
    required this.alreadyFriend,
    required this.hasPending,
    required this.onSendRequest,
  });

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF0891B2),
  ];

  Color _avatarColor() {
    if (profile.id.isEmpty) return _colors[0];
    final code = profile.id.codeUnits.fold(0, (a, b) => a + b);
    return _colors[code % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _avatarColor(),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                profile.username.isNotEmpty
                    ? profile.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              profile.username,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Action button
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (alreadyFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.successGreen.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, color: AppColors.successGreen, size: 14),
            SizedBox(width: 4),
            Text(
              'Friends',
              style: TextStyle(
                color: AppColors.successGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (hasPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Text(
          'Requested',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onSendRequest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF1A1200), size: 14),
            SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(
                color: Color(0xFF1A1200),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────

class _FriendsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.3, -0.4),
        radius: 1.2,
        colors: [Color(0xFF1A1F35), Color(0xFF080B14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final glowPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -1.3),
        radius: 0.8,
        colors: [Color(0x1AFFC107), Colors.transparent],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
      glowPaint,
    );

    // Subtle hearts/spades pattern
    final suits = ['♣', '♠', '♥'];
    final positions = [(0.06, 0.60), (0.82, 0.55), (0.50, 0.90)];
    for (int i = 0; i < suits.length; i++) {
      final (x, y) = positions[i];
      final tp = TextPainter(
        text: TextSpan(
          text: suits[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.022),
            fontSize: 80.0 + i * 15.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x * size.width, y * size.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
