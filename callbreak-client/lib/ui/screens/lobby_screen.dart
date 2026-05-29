import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'bidding_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';

/// Screen 2: Lobby — waiting for players, shows room code.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (state is GameBidding) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BiddingScreen()),
          );
        } else if (state is GameActive || state is GameRoundOver || state is GameOver) {
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
                    context, gameState, myPlayerId, players, canStart, isHost);
              }
              return _buildPortraitBody(
                  context, gameState, myPlayerId, players, canStart, isHost);
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
          _RoomCodeCard(gameState: gameState),
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
              child: _RoomCodeCard(gameState: gameState),
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

class _RoomCodeCard extends StatelessWidget {
  final dynamic gameState;
  const _RoomCodeCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
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
              Clipboard.setData(ClipboardData(text: gameState.roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room code copied!')),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  gameState.roomId,
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
                      .replace(queryParameters: {'room': gameState.roomId})
                      .toString()
                  : 'https://arunkumarmishra.github.io/callbreak/?room=${gameState.roomId}';
              // ignore: deprecated_member_use
              Share.share('Join my Callbreak room! Tap here to join: $url');
            },
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share Link'),
          ),
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
      child: Row(
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
