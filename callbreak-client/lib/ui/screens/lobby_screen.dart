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
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Room Code Display ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
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
                          Clipboard.setData(
                              ClipboardData(text: gameState.roomId));
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
                              ? Uri.base.replace(queryParameters: {'room': gameState.roomId}).toString()
                              : 'https://arunkumarmishra.github.io/callbreak/?room=${gameState.roomId}';
                          // ignore: deprecated_member_use
                          Share.share('Join my Callbreak room! Tap here to join: $url');
                        },
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share Link'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Player Slots ───────────────────────────────────────────
                Row(
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
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView.separated(
                    itemCount: kPlayersRequired,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index < players.length) {
                        final player = players[index];
                        final isMe = player.id == myPlayerId;
                        return _PlayerTile(
                          name: player.name,
                          isMe: isMe,
                          isHost: index == 0,
                        );
                      } else {
                        return _EmptySlot(slotNumber: index + 1);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── Start Game Button ──────────────────────────────────────
                if (isHost)
                  AnimatedOpacity(
                    opacity: canStart ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton.icon(
                      onPressed: canStart
                          ? () => context
                              .read<GameBloc>()
                              .add(const StartGameRequested())
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Game'),
                    ),
                  )
                else
                  Container(
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
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool isHost;

  const _PlayerTile({
    required this.name,
    required this.isMe,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.gold : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isMe ? AppColors.gold : AppColors.tableGreenLight,
            radius: 20,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: isMe ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const Text('(You)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final int slotNumber;

  const _EmptySlot({required this.slotNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceElevated,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceElevated,
            radius: 20,
            child: Text(
              '$slotNumber',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Waiting for player...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
