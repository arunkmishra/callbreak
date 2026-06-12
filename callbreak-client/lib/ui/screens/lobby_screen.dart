import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../data/services/heartbeat_service.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.read<GameBloc>().add(const DisconnectRequested());
      },
      child: BlocConsumer<GameBloc, GameBlocState>(
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
            if (state.message == 'FORCE_UPDATE_REQUIRED') {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E3A5F),
                  title: const Text('Update Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text(
                    getUpdateMessage(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.errorRed,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is! GameLobby) {
            return Scaffold(
              backgroundColor: const Color(0xFF050810),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      state is GameMatchmaking ? 'Searching for Match...' : 'Connecting...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (state is GameMatchmaking) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Finding the best opponents for you',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () {
                          context.read<GameBloc>().add(const DisconnectRequested());
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final gameState = state.gameState;
          final myPlayerId = state.myPlayerId;
          final players = gameState.players;
          final canStart = players.isNotEmpty;
          final isHost = players.isNotEmpty && players.first.id == myPlayerId;
          final myName = players.isEmpty ? 'Guest' : players.firstWhere((p) => p.id == myPlayerId, orElse: () => players.first).name;

          return Scaffold(
            backgroundColor: const Color(0xFF050810),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, isHost, canStart, gameState.isPublic),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        if (isWide) {
                          return _buildWideLayout(context, gameState, myPlayerId, myName, players, canStart, isHost);
                        }
                        return _buildNarrowLayout(context, gameState, myPlayerId, myName, players, canStart, isHost);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isHost, bool canStart, bool isPublic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.exit_to_app,
            onTap: () => context.read<GameBloc>().add(const DisconnectRequested()),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LOBBY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSuitIcon(Icons.favorite, const Color(0xFF4B5563)),
                  const SizedBox(width: 8),
                  _buildSuitIcon(Icons.favorite, const Color(0xFF7C3AED)), // purple heart representing diamond/heart
                  const SizedBox(width: 8),
                  _buildSuitIcon(Icons.favorite, const Color(0xFF4B5563)),
                  const SizedBox(width: 8),
                  _buildSuitIcon(Icons.favorite, const Color(0xFF4B5563)),
                ],
              ),
            ],
          ),
          const Spacer(),
          _StartGameSection(isHost: isHost, canStart: canStart, isPublic: isPublic),
        ],
      ),
    );
  }

  Widget _buildSuitIcon(IconData icon, Color color) {
    // using generic shapes since card suits aren't perfectly built-in.
    // In actual app we'd use custom icons or images.
    return Icon(icon, color: color, size: 14);
  }

  Widget _buildWideLayout(BuildContext context, dynamic gameState, String myId, String myName, List<dynamic> players, bool canStart, bool isHost) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (gameState.isPublic)
                  const Expanded(child: _PublicMatchmakingStats())
                else ...[
                  _RoomCodeSection(roomCode: gameState.roomId, myName: myName),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _OnlineFriendsSection(roomId: gameState.roomId, myName: myName),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlayersHeader(players: players),
                  const SizedBox(height: 12),
                  _PlayerGrid(players: players, myPlayerId: myId),
                  const SizedBox(height: 12),
                  _GameSettingsCard(gameState: gameState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, dynamic gameState, String myId, String myName, List<dynamic> players, bool canStart, bool isHost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (gameState.isPublic) ...[
            const SizedBox(height: 210, child: _PublicMatchmakingStats()),
            const SizedBox(height: 16),
          ] else ...[
            _RoomCodeSection(roomCode: gameState.roomId, myName: myName),
            const SizedBox(height: 16),
          ],
          _PlayersHeader(players: players),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _PlayerGrid(players: players, myPlayerId: myId),
          ),
          const SizedBox(height: 16),
          _GameSettingsCard(gameState: gameState),
          if (!gameState.isPublic) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 350,
              child: _OnlineFriendsSection(roomId: gameState.roomId, myName: myName),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Left Section: Room Code & Friends ────────────────────────────────────────

class _RoomCodeSection extends StatelessWidget {
  final String roomCode;
  final String myName;
  const _RoomCodeSection({required this.roomCode, required this.myName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ROOM CODE',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    roomCode,
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room code copied!')));
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.copy_outlined, color: Colors.white54, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E1A5B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              minimumSize: const Size(0, 42),
            ),
            onPressed: () {
              final url = kIsWeb
                  ? Uri.base.replace(queryParameters: {'room': roomCode}).toString()
                  : 'https://arunkumarmishra.github.io/callbreak/?room=$roomCode';
              // ignore: deprecated_member_use
              Share.share('Join my Callbreak room! Tap here to join: $url');
            },
            icon: const Icon(Icons.link_rounded, size: 16, color: Color(0xFFA78BFA)),
            label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _OnlineFriendsSection extends StatefulWidget {
  final String roomId;
  final String myName;
  const _OnlineFriendsSection({required this.roomId, required this.myName});

  @override
  State<_OnlineFriendsSection> createState() => _OnlineFriendsSectionState();
}

class _OnlineFriendsSectionState extends State<_OnlineFriendsSection> {
  final _supabaseRepo = SupabaseRepository();
  List<Friendship> _friends = [];
  Map<String, String> _onlineUserStatuses = {};
  Timer? _timer;
  RealtimeChannel? _invitesChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
    _invitesChannel = Supabase.instance.client.channel('system_invites');
    _invitesChannel!.subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _invitesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final f = await _supabaseRepo.getFriends();
      final s = await HeartbeatService.getOnlineUsers();
      if (mounted) {
        setState(() {
          _friends = f;
          _onlineUserStatuses = s;
        });
      }
    } catch (_) {}
  }

  void _sendInvite(String friendId, String friendName) async {
    try {
      await _invitesChannel!.sendBroadcastMessage(
        event: 'invite',
        payload: {
          'inviteeId': friendId,
          'roomId': widget.roomId,
          'inviterName': widget.myName,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite sent to $friendName!')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final allFriends = _friends.where((f) => f.profile != null && f.profile!.id != myId).toList();
    
    // Sort online first
    allFriends.sort((a, b) {
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

    final onlineCount = allFriends.where((f) => _onlineUserStatuses.containsKey(f.profile!.id)).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Text(
              'ONLINE FRIENDS ($onlineCount)',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: allFriends.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No friends found', style: TextStyle(color: Colors.white54, fontSize: 12))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: allFriends.length,
                    itemBuilder: (context, index) {
                      final f = allFriends[index];
                      final name = f.profile!.username;
                      final isOnline = _onlineUserStatuses.containsKey(f.profile!.id);
                      final status = _onlineUserStatuses[f.profile!.id] ?? 'offline';
                      final isAvailable = status == 'available';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarUrl: f.profile!.avatarUrl,
                              username: name,
                              radius: 18,
                              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isOnline ? AppColors.successGreen : Colors.white38,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOnline ? 'Online' : 'Offline',
                                        style: TextStyle(color: isOnline ? AppColors.successGreen : Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isAvailable)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7C3AED),
                                  side: const BorderSide(color: Color(0xFF2E1A5B)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () => _sendInvite(f.profile!.id, name),
                                child: const Text('Invite', style: TextStyle(fontSize: 12)),
                              )
                            else if (isOnline)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Text(
                                  'Playing',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              const SizedBox(width: 64),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Right Section: Players & Settings ────────────────────────────────────────

class _PlayersHeader extends StatelessWidget {
  final List<dynamic> players;
  const _PlayersHeader({required this.players});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PLAYERS (${players.length}/4)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const Text(
          'Waiting for players to join...',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  final List<dynamic> players;
  final String myPlayerId;
  const _PlayerGrid({required this.players, required this.myPlayerId});

  @override
  Widget build(BuildContext context) {
    List<Widget> slots = [];
    for (int i = 0; i < 4; i++) {
      if (i < players.length) {
        final player = players[i];
        final isMe = player.id == myPlayerId;
        slots.add(_GridPlayerCard(name: player.name, isMe: isMe, isHost: i == 0));
      } else {
        slots.add(const _GridEmptySlot());
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: slots[0]),
            const SizedBox(width: 12),
            Expanded(child: slots[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: slots[2]),
            const SizedBox(width: 12),
            Expanded(child: slots[3]),
          ],
        ),
      ],
    );
  }
}

class _GridPlayerCard extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool isHost;
  const _GridPlayerCard({required this.name, required this.isMe, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              isMe ? 'Y' : name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? 'You' : name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      const Text('👑', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.successGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Ready', style: TextStyle(color: AppColors.successGreen, fontSize: 11)),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('?', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Empty Seat', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Waiting...', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameSettingsCard extends StatelessWidget {
  final dynamic gameState;
  const _GameSettingsCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GAME SETTINGS', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SettingItem(icon: Icons.gavel_rounded, label: 'Minimum Bid', value: '${gameState.minBid ?? 1}')),
              Container(width: 1, height: 30, color: Colors.white10),
              Expanded(child: _SettingItem(icon: Icons.filter_vintage, label: 'Trump', value: gameState.allowCustomTrump == true ? 'Dynamic' : 'Spade')),
              Container(width: 1, height: 30, color: Colors.white10),
              Expanded(child: _SettingItem(icon: Icons.access_time_rounded, label: 'Round', value: '${gameState.totalRounds} Rounds')),
              Container(width: 1, height: 30, color: Colors.white10),
              Expanded(child: _SettingItem(icon: Icons.monetization_on_rounded, label: 'Greedy Mode', value: gameState.greedPenalty == true ? 'Enabled' : 'Disabled')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 9)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartGameSection extends StatelessWidget {
  final bool isHost;
  final bool canStart;
  final bool isPublic;
  const _StartGameSection({required this.isHost, required this.canStart, this.isPublic = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        onPressed: (!isPublic && isHost && canStart) ? () => context.read<GameBloc>().add(const StartGameRequested()) : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Opacity(
              opacity: (!isPublic && isHost && canStart) ? 1.0 : 0.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isPublic && isHost && canStart) const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  if (!isPublic && isHost && canStart) const SizedBox(width: 8),
                  Text(
                    isPublic ? 'WAITING FOR PLAYERS...' : (isHost ? 'START GAME' : 'WAITING FOR HOST TO START...'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isHost ? 14 : 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Public Matchmaking Stats ────────────────────────────────────────────────

class _PublicMatchmakingStats extends StatefulWidget {
  const _PublicMatchmakingStats();

  @override
  State<_PublicMatchmakingStats> createState() => _PublicMatchmakingStatsState();
}

class _PublicMatchmakingStatsState extends State<_PublicMatchmakingStats> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _baseOnlineCount = getSimulatedOnlineCount();
  int _onlineCount = getSimulatedOnlineCount();
  int _activeGames = (getSimulatedOnlineCount() / 4).floor() + 12;
  int _elapsedSeconds = 0;
  Timer? _pollingTimer;
  Timer? _waitTimer;
  Timer? _fluctuationTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _baseOnlineCount = getSimulatedOnlineCount();
        });
      }
    });

    // Fluctuate the numbers every 3 seconds to make them look live
    _fluctuationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          // Slight random fluctuation between -2 and +3
          int change = (DateTime.now().millisecondsSinceEpoch % 6) - 2;
          _onlineCount = _baseOnlineCount + change;
          if (_onlineCount < 100) _onlineCount = 100;
          
          // Slight fluctuation for active games
          int gamesChange = (DateTime.now().millisecondsSinceEpoch % 3) - 1;
          _activeGames += gamesChange;
          if (_activeGames < 20) _activeGames = 20;
        });
      }
    });

    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _waitTimer?.cancel();
    _fluctuationTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const Icon(Icons.public, color: Color(0xFF60A5FA), size: 24),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'MATCHMAKING',
              style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            _buildStatRow(Icons.timer_outlined, 'Elapsed Wait', _formatTime(_elapsedSeconds)),
            const SizedBox(height: 6),
            _buildStatRow(Icons.access_time_filled, 'Avg Wait', '~15s'),
            const SizedBox(height: 6),
            _buildStatRow(Icons.group, 'Online Players', '$_onlineCount'),
            const SizedBox(height: 6),
            _buildStatRow(Icons.videogame_asset, 'Active Matches', '$_activeGames'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 14),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

