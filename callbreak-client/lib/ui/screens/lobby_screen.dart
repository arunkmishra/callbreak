import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../data/services/heartbeat_service.dart';
import 'game_screen.dart';
import 'home_screen.dart';

/// Screen 2: Lobby — waiting for players, shows room code.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (state is GameBidding || state is GameActive || state is GameRoundOver || state is GameOver) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GameScreen()),
          );
        } else if (state is GameInitial) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.errorRed,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! GameLobby) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameState = state.gameState;
        final myPlayerId = state.myPlayerId;
        final players = gameState.players;
        final canStart = players.isNotEmpty;
        final isHost = players.isNotEmpty && players.first.id == myPlayerId;

        final myName = players.firstWhere((p) => p.id == myPlayerId, orElse: () => players.first).name;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Lobby'),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  context.read<GameBloc>().add(const DisconnectRequested());
                },
              ),
            ],
          ),
          body: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.landscape) {
                return _buildLandscapeBody(
                    context, gameState, myPlayerId, myName, players, canStart, isHost);
              }
              return _buildPortraitBody(
                  context, gameState, myPlayerId, myName, players, canStart, isHost);
            },
          ),
        );
      },
    );
  }

  // ─── Portrait layout ───────────────────────────────────────────────────────

  Widget _buildPortraitBody(
    BuildContext context,
    dynamic gameState,
    String myPlayerId,
    String myName,
    List<dynamic> players,
    bool canStart,
    bool isHost,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Room Code Display ──────────────────────────────────────────
          _RoomCodeCard(gameState: gameState, myName: myName),
          const SizedBox(height: 32),

          // ── Player Slots ───────────────────────────────────────────────
          _PlayersHeader(players: players),
          const SizedBox(height: 16),

          Expanded(
            child: _PlayerList(players: players, myPlayerId: myPlayerId),
          ),
          const SizedBox(height: 24),

          // ── Start Game Button ──────────────────────────────────────────
          _StartButton(
            isHost: isHost,
            canStart: canStart,
            onStart: () =>
                context.read<GameBloc>().add(const StartGameRequested()),
          ),
        ],
      ),
    );
  }

  // ─── Landscape layout (2-column) ──────────────────────────────────────────

  Widget _buildLandscapeBody(
    BuildContext context,
    dynamic gameState,
    String myPlayerId,
    String myName,
    List<dynamic> players,
    bool canStart,
    bool isHost,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: room code card
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: _RoomCodeCard(gameState: gameState, myName: myName),
            ),
          ),
          const SizedBox(width: 16),

          // Right: player list + start button
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlayersHeader(players: players),
                const SizedBox(height: 8),
                Expanded(
                  child: _PlayerList(players: players, myPlayerId: myPlayerId),
                ),
                const SizedBox(height: 12),
                _StartButton(
                  isHost: isHost,
                  canStart: canStart,
                  onStart: () =>
                      context.read<GameBloc>().add(const StartGameRequested()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Extracted sub-widgets ─────────────────────────────────────────────────────

class _RoomCodeCard extends StatefulWidget {
  final dynamic gameState;
  final String myName;
  const _RoomCodeCard({required this.gameState, required this.myName});

  @override
  State<_RoomCodeCard> createState() => _RoomCodeCardState();
}

class _RoomCodeCardState extends State<_RoomCodeCard> {
  final _supabaseRepo = SupabaseRepository();
  List<Friendship> _friends = [];
  Map<String, String> _onlineUserStatuses = {};
  Timer? _onlineTimer;
  bool _isLoadingFriends = true;
  RealtimeChannel? _invitesChannel;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _fetchOnlineUsers();
    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchOnlineUsers());
    
    _invitesChannel = Supabase.instance.client.channel('system_invites');
    _invitesChannel!.subscribe();
  }

  @override
  void dispose() {
    _invitesChannel?.unsubscribe();
    _onlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _supabaseRepo.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _fetchOnlineUsers() async {
    final statuses = await HeartbeatService.getOnlineUsers();
    if (mounted) {
      setState(() {
        _onlineUserStatuses = statuses;
      });
    }
  }

  Future<void> _sendInvite(String friendId, String friendName) async {
    try {
      await _invitesChannel!.sendBroadcastMessage(
        event: 'invite',
        payload: {
          'inviteeId': friendId,
          'roomId': widget.gameState.roomId,
          'inviterName': widget.myName,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to $friendName!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invite.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final onlineFriends = _friends
        .where((f) => f.profile != null && f.profile!.id != myId && _onlineUserStatuses.containsKey(f.profile!.id))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ROOM CODE',
            style: TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 3,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.gameState.roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room code copied!')),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.gameState.roomId,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 12,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_outlined,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this code with friends',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold.withValues(alpha: 0.1),
              foregroundColor: AppColors.gold,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
            ),
            onPressed: () {
              final url = kIsWeb
                  ? Uri.base
                      .replace(queryParameters: {'room': widget.gameState.roomId})
                      .toString()
                  : 'https://arunkumarmishra.github.io/callbreak/?room=${widget.gameState.roomId}';
              // ignore: deprecated_member_use
              Share.share('Join my Callbreak room! Tap here to join: $url');
            },
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share Link'),
          ),
          
          if (!_isLoadingFriends && onlineFriends.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Online Friends',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: onlineFriends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final friend = onlineFriends[index];
                final friendName = friend.profile!.username;
                final status = _onlineUserStatuses[friend.profile!.id] ?? 'available';
                final isAvailable = status == 'available';

                return Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.surface,
                          child: Text(
                            friendName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isAvailable ? AppColors.successGreen : AppColors.errorRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceElevated, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        friendName,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAvailable)
                      SizedBox(
                        height: 28,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _sendInvite(friend.profile!.id, friendName),
                          child: const Text('Invite', style: TextStyle(fontSize: 11, color: AppColors.gold)),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Text(
                          'Playing',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayersHeader extends StatelessWidget {
  final List<dynamic> players;
  const _PlayersHeader({required this.players});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Players (${players.length}/$kPlayersRequired)',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (players.length < kPlayersRequired)
          const Text(
            'Waiting (Empty seats filled by Bots)...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _PlayerList extends StatelessWidget {
  final List<dynamic> players;
  final String myPlayerId;
  const _PlayerList({required this.players, required this.myPlayerId});

  @override
  Widget build(BuildContext context) {
    List<Widget> slots = [];
    for (int i = 0; i < kPlayersRequired; i++) {
      if (i < players.length) {
        final player = players[i];
        final isMe = player.id == myPlayerId;
        slots.add(_GridPlayerCard(
          name: player.name,
          isMe: isMe,
          isHost: i == 0,
        ));
      } else {
        slots.add(const _GridEmptySlot());
      }
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: slots[0]),
              const SizedBox(width: 16),
              Expanded(child: slots[1]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: slots[2]),
              const SizedBox(width: 16),
              Expanded(child: slots[3]),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool isHost;
  final bool canStart;
  final VoidCallback onStart;
  const _StartButton({
    required this.isHost,
    required this.canStart,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (isHost) {
      return AnimatedOpacity(
        opacity: canStart ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton.icon(
          onPressed: canStart ? onStart : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Game'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Waiting for the host to start...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _GridPlayerCard extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool isHost;

  const _GridPlayerCard({
    required this.name,
    required this.isMe,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.tableGreen.withValues(alpha: 0.5),
            radius: 20,
            child: Text(
              isMe ? 'Y' : name[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.successGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? 'You' : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ready',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridEmptySlot extends StatelessWidget {
  const _GridEmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceElevated,
            radius: 20,
            child: const Text(
              '?',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Empty',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Waiting...',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
