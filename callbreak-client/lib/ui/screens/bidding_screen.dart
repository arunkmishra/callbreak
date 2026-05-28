import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/tech_background.dart';
import 'game_screen.dart';
import 'home_screen.dart';

/// Screen 3: Bidding — each player picks their bid (1–13).
class BiddingScreen extends StatefulWidget {
  const BiddingScreen({super.key});

  @override
  State<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends State<BiddingScreen> {
  bool _isDialogOpen = false;

  void _dismissDialog() {
    if (_isDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isDialogOpen = false;
    }
  }

  void _showLeaveMatchDialog(BuildContext context) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave Match?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave?\n\nA bot will take over your seat, and you may lose points.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dismissDialog();
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _dismissDialog();
              context.read<GameBloc>().add(const DisconnectRequested());
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (state is GameActive) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GameScreen()),
          );
        }
        if (state is GameInitial) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        return BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settingsState) {
            Color getTableColor(bool isLight) {
              switch (settingsState.tableColor) {
                case TableColor.red:
                  return isLight ? AppColors.tableRedLight : AppColors.tableRed;
                case TableColor.blue:
                  return isLight ? AppColors.tableBlueLight : AppColors.tableBlue;
                case TableColor.green:
                  return isLight ? AppColors.tableGreenLight : AppColors.tableGreen;
              }
            }

            if (state is! GameBidding) {
              return Scaffold(
                backgroundColor: getTableColor(false),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

        final gameState = state.gameState;
        final myPlayerId = state.myPlayerId;
        final isMyTurn = gameState.isMyTurn(myPlayerId);
        final myPlayer = gameState.players
            .firstWhere((p) => p.id == myPlayerId, orElse: () => gameState.players.first);
        final currentBidder = gameState.players
            .firstWhere((p) => p.id == gameState.currentTurn,
                orElse: () => gameState.players.first);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: TechBackground(
            color: getTableColor(false),
            lightColor: getTableColor(true),
            child: SafeArea(
              child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      // ── Header ─────────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.exit_to_app, color: Colors.white54),
                                  onPressed: () => _showLeaveMatchDialog(context),
                                ),
                                Text(
                                  'Round ${gameState.currentRound} / ${gameState.totalRounds}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'BIDDING',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 48), // Balance for the icon button on the left
                          ],
                        ),
                      ),

                      // ── Bidding Status ─────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                isMyTurn
                                    ? 'Your turn to bid!'
                                    : '${currentBidder.name} is bidding...',
                                style: TextStyle(
                                  color: isMyTurn ? AppColors.gold : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Show each player's bid status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: gameState.players.map((player) {
                                  final hasBid = player.bid != null;
                                  return Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: hasBid
                                            ? AppColors.successGreen
                                            : AppColors.surfaceElevated,
                                        child: Text(
                                          hasBid
                                              ? '${player.bid}'
                                              : player.name[0].toUpperCase(),
                                          style: TextStyle(
                                            color: hasBid
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        player.name.split(' ').first,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── My Hand Preview ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 8),
                              child: Text(
                                'YOUR HAND',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: (List<dynamic>.from(gameState.myHand)..sort())
                                    .map((card) => Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: PlayingCardWidget(
                                            card: card,
                                            isPlayable: false,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      const SizedBox(height: 16),

                // ── Bid Selector ───────────────────────────────────────────
                if (isMyTurn && myPlayer.bid == null) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Select your bid',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: kCardsPerHand,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final bid = index + 1;
                        final minBid = gameState.minBid ?? 1;
                        final isAllowed = bid >= minBid;
                        
                        return GestureDetector(
                          onTap: isAllowed ? () => context
                              .read<GameBloc>()
                              .add(PlaceBidAttempt(bid)) : null,
                          child: Container(
                            width: 56,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isAllowed 
                                  ? [AppColors.gold, AppColors.goldDark]
                                  : [Colors.grey.shade700, Colors.grey.shade900],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isAllowed ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ] : [],
                            ),
                            child: Center(
                              child: Text(
                                '$bid',
                                style: TextStyle(
                                  color: isAllowed ? Colors.black87 : Colors.white30,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else if (myPlayer.bid != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.successGreen),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.successGreen),
                        const SizedBox(width: 12),
                        Text(
                          'You bid ${myPlayer.bid}. Waiting for others...',
                          style: const TextStyle(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    ),
  ));
          },
        );
      },
    );
  }
}
