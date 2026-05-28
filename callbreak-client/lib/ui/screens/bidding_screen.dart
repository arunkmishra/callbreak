import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../data/models/game_state.dart';
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
        if (state is GameError) {
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      // ── Reconnecting banner ────────────────────────────────────
                      if (state.isReconnecting)
                        _BiddingReconnectingBanner(),
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

                      // ── Trump Info ──────────────────────────────────────────────
                      Builder(
                        builder: (context) {
                          String prefix = 'TRUMP:';
                          String? displaySuit;
                          
                          if (gameState.phase == GamePhase.trumpBidding) {
                            if (gameState.trumpBidState.highestBid > 0) {
                              displaySuit = gameState.trumpBidState.proposedSuit;
                              prefix = 'HIGHEST BID: ${gameState.trumpBidState.highestBid}  |  TRUMP:';
                            } else {
                              displaySuit = 'Spade';
                            }
                          } else {
                            displaySuit = gameState.currentTrumpSuit ?? 'Spade';
                          }

                          Widget getSuitIcon(String? suit) {
                            final s = (suit ?? 'Spade').toUpperCase();
                            String char = '♠';
                            Color color = Colors.white;
                            if (s.contains('HEART')) { char = '♥'; color = const Color(0xFFE53935); }
                            else if (s.contains('DIAMOND')) { char = '♦'; color = const Color(0xFFE53935); }
                            else if (s.contains('CLUB')) { char = '♣'; color = Colors.white; }

                            return Text(
                              char,
                              style: TextStyle(fontSize: 24, height: 1.2, color: color),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                if (gameState.phase == GamePhase.trumpBidding) ...[
                                  const Text(
                                    'TRUMP BIDDING',
                                    style: TextStyle(
                                      color: Color(0xFFBA68C8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      prefix,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    getSuitIcon(displaySuit),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
                      
                      const SizedBox(height: 24),

                // ── Bid Selector ───────────────────────────────────────────
                if (isMyTurn && gameState.phase == GamePhase.trumpBidding) ...[
                  // TRUMP BIDDING UI INLINE
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBA68C8).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Place Your Trump Bid',
                          style: TextStyle(
                            color: Color(0xFFBA68C8),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InlineTrumpBidForm(
                          currentHighest: gameState.trumpBidState.highestBid,
                          onBid: (bid, suit) {
                            context.read<GameBloc>().add(PlaceTrumpBidAttempt(bid, suit));
                          },
                          onPass: () {
                            context.read<GameBloc>().add(const PlaceTrumpBidAttempt(null, null));
                          },
                        ),
                      ],
                    ),
                  ),
                ] else if (isMyTurn && myPlayer.bid == null && gameState.phase != GamePhase.trumpBidding) ...[
                  // REGULAR BIDDING UI
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
                ] else if (gameState.phase == GamePhase.trumpBidding) ...[
                  // Waiting in trump bidding
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_empty, color: Colors.white54),
                        const SizedBox(width: 12),
                        Text(
                          isMyTurn ? 'Loading...' : 'Waiting for ${currentBidder.name}...',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
        ),
      ),
    ),
  );
          },
        );
      },
    );
  }
}

class _InlineTrumpBidForm extends StatefulWidget {
  final int currentHighest;
  final void Function(int bid, String suit) onBid;
  final VoidCallback onPass;

  const _InlineTrumpBidForm({
    required this.currentHighest,
    required this.onBid,
    required this.onPass,
  });

  @override
  State<_InlineTrumpBidForm> createState() => _InlineTrumpBidFormState();
}

class _InlineTrumpBidFormState extends State<_InlineTrumpBidForm> {
  late int _selectedBid;
  String _selectedSuit = 'Spade';

  @override
  void initState() {
    super.initState();
    _selectedBid = (widget.currentHighest >= 5) ? widget.currentHighest + 1 : 5;
  }

  @override
  Widget build(BuildContext context) {
    final validBids = List.generate(13 - 5 + 1, (i) => 5 + i).where((b) => b > widget.currentHighest).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bid:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: validBids.contains(_selectedBid) ? _selectedBid : (validBids.isNotEmpty ? validBids.first : null),
              dropdownColor: AppColors.surfaceElevated,
              items: validBids
                  .map((b) => DropdownMenuItem(value: b, child: Text('$b', style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedBid = v);
              },
            ),
            const SizedBox(width: 24),
            const Text('Suit:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _selectedSuit,
              dropdownColor: AppColors.surfaceElevated,
              items: ['Spade', 'Heart', 'Diamond', 'Club']
                  .map((s) {
                    String char = '♠';
                    Color color = Colors.white;
                    if (s == 'Heart') { char = '♥'; color = const Color(0xFFE53935); }
                    else if (s == 'Diamond') { char = '♦'; color = const Color(0xFFE53935); }
                    else if (s == 'Club') { char = '♣'; color = Colors.white; }
                    return DropdownMenuItem(value: s, child: Text(char, style: TextStyle(color: color, fontSize: 18)));
                  })
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSuit = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: const Size(100, 48),
              ),
              onPressed: widget.onPass,
              child: const Text('PASS', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA68C8),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: const Size(140, 48),
              ),
              onPressed: validBids.isNotEmpty
                  ? () => widget.onBid(_selectedBid, _selectedSuit)
                  : null,
              child: const Text('CONFIRM BID', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Amber banner shown at the top of bidding screen while reconnecting.
class _BiddingReconnectingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.amber.shade800.withValues(alpha: 0.92),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 10),
          Text(
            'Reconnecting…',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
