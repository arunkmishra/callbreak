import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile data loaded from the Supabase `profiles` table.
class UserProfile {
  final String id;
  final String username;
  final String? avatarUrl;
  final int totalWins;
  final int totalGames;
  final double totalScore;

  const UserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.totalWins,
    required this.totalGames,
    required this.totalScore,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      totalWins: (json['total_wins'] as num?)?.toInt() ?? 0,
      totalGames: (json['total_games'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Friendship data from the `friendships` table.
class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final UserProfile? profile; // The other user's profile

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.profile,
  });
}

/// Central repository for all Supabase database reads/writes relating
/// to leaderboards, friend connections, and user profiles.
class SupabaseRepository {
  final _client = Supabase.instance.client;

  String? get _myUserId => _client.auth.currentUser?.id;

  // ── Leaderboard ───────────────────────────────────────────────────────────

  /// Fetches the top 100 players ordered by total wins.
  Future<List<UserProfile>> getLeaderboard() async {
    final data = await _client
        .from('profiles')
        .select('id, username, avatar_url, total_wins, total_games, total_score')
        .order('total_wins', ascending: false)
        .limit(100);

    return (data as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Friends ───────────────────────────────────────────────────────────────

  Future<List<Friendship>> getFriends() async {
    final myId = _myUserId;
    if (myId == null) return [];

    final asRequester = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, addressee:profiles!friendships_addressee_id_fkey(id, username, avatar_url)')
        .eq('requester_id', myId)
        .eq('status', 'accepted');

    final asAddressee = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, requester:profiles!friendships_requester_id_fkey(id, username, avatar_url)')
        .eq('addressee_id', myId)
        .eq('status', 'accepted');

    final List<Friendship> friends = [];

    for (final row in asRequester as List<dynamic>) {
      final json = row as Map<String, dynamic>;
      final profileData = json['addressee'];
      friends.add(Friendship(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: json['status'] as String,
        profile: profileData != null ? UserProfile.fromJson(profileData as Map<String, dynamic>) : null,
      ));
    }

    for (final row in asAddressee as List<dynamic>) {
      final json = row as Map<String, dynamic>;
      final profileData = json['requester'];
      friends.add(Friendship(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: json['status'] as String,
        profile: profileData != null ? UserProfile.fromJson(profileData as Map<String, dynamic>) : null,
      ));
    }

    return friends;
  }

  /// Returns incoming pending friend requests (where current user is addressee).
  Future<List<Friendship>> getPendingRequests() async {
    final myId = _myUserId;
    if (myId == null) return [];

    final data = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, profiles!friendships_requester_id_fkey(id, username, avatar_url)')
        .eq('addressee_id', myId)
        .eq('status', 'pending');

    return (data as List<dynamic>).map((e) {
      final json = e as Map<String, dynamic>;
      final requesterProfile = json['profiles'] as Map<String, dynamic>?;
      return Friendship(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: json['status'] as String,
        profile: requesterProfile != null ? UserProfile.fromJson(requesterProfile) : null,
      );
    }).toList();
  }

  /// Searches for users by username (case-insensitive).
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    final myId = _myUserId;
    final data = await _client
        .from('profiles')
        .select('id, username, avatar_url, total_wins, total_games, total_score')
        .ilike('username', '%${query.trim()}%')
        .neq('id', myId ?? '')
        .limit(20);

    return (data as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a friend request to [targetUserId].
  Future<void> sendFriendRequest(String targetUserId) async {
    final myId = _myUserId;
    if (myId == null) return;
    await _client.from('friendships').insert({
      'requester_id': myId,
      'addressee_id': targetUserId,
      'status': 'pending',
    });
  }

  /// Accepts a pending friend request by [friendshipId].
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  /// Declines or removes a friendship by [friendshipId].
  Future<void> declineFriendRequest(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  // ── My Profile ────────────────────────────────────────────────────────────

  Future<UserProfile?> getMyProfile() async {
    final myId = _myUserId;
    if (myId == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', myId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  /// Updates the current user's username. Throws an exception if it violates
  /// the unique constraint.
  Future<void> updateUsername(String newUsername) async {
    final myId = _myUserId;
    if (myId == null) throw Exception('Not logged in');
    await _client.from('profiles').update({'username': newUsername}).eq('id', myId);
  }
  /// Syncs the user's Google avatar URL to the profiles table if available.
  Future<void> syncUserAvatarUrl() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final String? picture = user.userMetadata?['picture'] ?? user.userMetadata?['avatar_url'];
    if (picture != null) {
      try {
        await _client.from('profiles').update({'avatar_url': picture}).eq('id', user.id);
      } catch (e) {
        // Fail silently, this is a best-effort sync
      }
    }
  }
}
