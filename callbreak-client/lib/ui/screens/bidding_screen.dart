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
import '../widgets/score_board_widget.dart';
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
            onPressed: _dismissDialog,
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
    ).then((_) => _isDialogOpen = false);
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
            final currentBidder = gameState.players.firstWhere(
              (p) => p.id == gameState.currentTurn,
              orElse: () => gameState.players.first,
            );

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: TechBackground(
                color: getTableColor(false),
                lightColor: getTableColor(true),
                child: SafeArea(
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      if (orientation == Orientation.landscape) {
                        return _buildLandscapeLayout(
                          context, gameState, isMyTurn, myPlayer, currentBidder, state,
                        );
                      }
                      return _buildPortraitLayout(
                        context, gameState, isMyTurn, myPlayer, currentBidder, state,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Portrait layout
  //   Top:    header + trump info + bidding status
  //   Middle: fanned hand (all 13 cards visible, no scroll)
  //   Bottom: bid grid (Wrap, all 13 in 2 rows, no scroll)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPortraitLayout(
    BuildContext context,
    dynamic gameState,
    bool isMyTurn,
    dynamic myPlayer,
    dynamic currentBidder,
    GameBidding state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isReconnecting) _BiddingReconnectingBanner(),
        _buildHeader(context, gameState),
        _buildTrumpInfo(gameState),
        _buildBiddingStatus(gameState, isMyTurn, myPlayer, currentBidder),
        const SizedBox(height: 12),
        // Fanned hand — always fully visible
        _buildFannedHand(gameState, compact: false),
        const SizedBox(height: 16),
        // Bid grid — all 13 in Wrap, no scroll
        _buildBidSelector(context, isMyTurn, myPlayer, gameState, currentBidder),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Landscape layout
  //   Left  (flex 6): fanned hand + bid controls
  //   Right (flex 4): header + trump info + bidding status
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildLandscapeLayout(
    BuildContext context,
    dynamic gameState,
    bool isMyTurn,
    dynamic myPlayer,
    dynamic currentBidder,
    GameBidding state,
  ) {
    return Column(
      children: [
        if (state.isReconnecting) _BiddingReconnectingBanner(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: hand + bid controls ────────────────────────────────
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFannedHand(gameState, compact: true),
                      const SizedBox(height: 10),
                      _buildBidSelector(context, isMyTurn, myPlayer, gameState, currentBidder),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.white12,
              ),

              // ── Right: header + trump + bidding status ───────────────────
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, gameState),
                      _buildTrumpInfo(gameState),
                      _buildBiddingStatus(gameState, isMyTurn, myPlayer, currentBidder),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Fanned hand — all 13 cards overlapping, fully visible, no scroll needed
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildFannedHand(dynamic gameState, {required bool compact}) {
    final sortedCards = List<dynamic>.from(gameState.myHand)..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'YOUR HAND',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          _FannedHandPreview(cards: sortedCards, compact: compact),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Shared section builders
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, dynamic gameState) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8, top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.white54),
                  onPressed: () => _showLeaveMatchDialog(context),
                  tooltip: 'Leave Match',
                ),
                Flexible(
                  child: Text(
                    'Round ${gameState.currentRound}/${gameState.totalRounds}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'BIDDING',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: ScoreBoardWidget(gameState: gameState),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.tableGreenLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.leaderboard, color: AppColors.gold, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrumpInfo(dynamic gameState) {
    return Builder(
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
          String char = '♠\uFE0E';
          Color color = Colors.white;
          if (s.contains('HEART')) { char = '♥\uFE0E'; color = const Color(0xFFE53935); }
          else if (s.contains('DIAMOND')) { char = '♦\uFE0E'; color = const Color(0xFFE53935); }
          else if (s.contains('CLUB')) { char = '♣\uFE0E'; color = Colors.white; }
          return Text(char, style: TextStyle(fontSize: 24, height: 1.2, color: color));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              if (gameState.phase == GamePhase.trumpBidding) ...[
                const Text(
                  'TRUMP BIDDING',
                  style: TextStyle(
                    color: Color(0xFFBA68C8),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Widget _buildBiddingStatus(
    dynamic gameState,
    bool isMyTurn,
    dynamic myPlayer,
    dynamic currentBidder,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              isMyTurn ? 'Your turn to bid!' : '${currentBidder.name} is bidding...',
              style: TextStyle(
                color: isMyTurn ? AppColors.gold : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: gameState.players.map<Widget>((player) {
                final hasBid = player.bid != null;
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: hasBid ? AppColors.successGreen : AppColors.surfaceElevated,
                      child: Text(
                        hasBid ? '${player.bid}' : player.name[0].toUpperCase(),
                        style: TextStyle(
                          color: hasBid ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.name.split(' ').first,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Bid selector — uses Wrap so all 13 buttons fit in compact rows (no scroll)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBidSelector(
    BuildContext context,
    bool isMyTurn,
    dynamic myPlayer,
    dynamic gameState,
    dynamic currentBidder,
  ) {
    // Trump bidding — my turn
    if (isMyTurn && gameState.phase == GamePhase.trumpBidding) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(14),
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
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            _InlineTrumpBidForm(
              currentHighest: gameState.trumpBidState.highestBid,
              onBid: (bid, suit) => context.read<GameBloc>().add(PlaceTrumpBidAttempt(bid, suit)),
              onPass: () => context.read<GameBloc>().add(const PlaceTrumpBidAttempt(null, null)),
            ),
          ],
        ),
      );
    }

    // Regular bidding — my turn: Wrap grid, all 13 visible
    if (isMyTurn && myPlayer.bid == null && gameState.phase != GamePhase.trumpBidding) {
      int minBid = gameState.minBid ?? 1;
      final trumpState = gameState.trumpBidState;
      if (trumpState.highestBidderId == myPlayer.id && trumpState.highestBid > 0) {
        if (trumpState.highestBid > minBid) {
          minBid = trumpState.highestBid;
        }
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 2),
              child: Text(
                'Select your bid',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(kCardsPerHand, (index) {
                final bid = index + 1;
                final isAllowed = bid >= minBid;
                return _BidButton(
                  bid: bid,
                  isAllowed: isAllowed,
                  onTap: isAllowed
                      ? () => context.read<GameBloc>().add(PlaceBidAttempt(bid))
                      : null,
                );
              }),
            ),
          ],
        ),
      );
    }

    // Trump bidding — waiting
    if (gameState.phase == GamePhase.trumpBidding) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
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
              style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Already bid — waiting for others
    if (myPlayer.bid != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
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
              style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fanned hand preview — all cards overlapping, computed to always fit width
// ─────────────────────────────────────────────────────────────────────────────

/// Displays all cards fanned with overlap so every card is visible at a glance.
/// No scrolling needed — uses [LayoutBuilder] to compute the optimal step width.
class _FannedHandPreview extends StatelessWidget {
  final List<dynamic> cards;
  /// [compact] uses smaller card height for landscape mode.
  final bool compact;

  const _FannedHandPreview({required this.cards, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    // isSmall=true → 52×78; we scale further for compact (landscape)
    const double cardW = 52.0;
    final double cardH = compact ? 70.0 : 78.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int count = cards.length;
        final double availW = constraints.maxWidth - 8;

        // Compute step so all cards fit: (count-1)*step + cardW <= availW
        final double step = count > 1
            ? ((availW - cardW) / (count - 1)).clamp(8.0, cardW)
            : 0.0;

        return SizedBox(
          height: cardH + 6, // +6 for shadow clearance
          child: Stack(
            clipBehavior: Clip.none,
            children: cards.asMap().entries.map((entry) {
              final i = entry.key;
              final card = entry.value;
              return Positioned(
                left: i * step,
                bottom: 0,
                child: SizedBox(
                  width: cardW,
                  height: cardH,
                  child: PlayingCardWidget(
                    card: card,
                    isPlayable: false,
                    isSmall: true,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact bid button used inside the Wrap grid
// ─────────────────────────────────────────────────────────────────────────────

class _BidButton extends StatefulWidget {
  final int bid;
  final bool isAllowed;
  final VoidCallback? onTap;

  const _BidButton({required this.bid, required this.isAllowed, this.onTap});

  @override
  State<_BidButton> createState() => _BidButtonState();
}

class _BidButtonState extends State<_BidButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isAllowed ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.isAllowed
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isAllowed
                  ? [AppColors.gold, AppColors.goldDark]
                  : [Colors.grey.shade700, Colors.grey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isAllowed
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: _pressed ? 0.5 : 0.3),
                      blurRadius: _pressed ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              '${widget.bid}',
              style: TextStyle(
                color: widget.isAllowed ? Colors.black87 : Colors.white30,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trump bid form
// ─────────────────────────────────────────────────────────────────────────────

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
    final validBids = List.generate(13 - 5 + 1, (i) => 5 + i)
        .where((b) => b > widget.currentHighest)
        .toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bid:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: validBids.contains(_selectedBid)
                  ? _selectedBid
                  : (validBids.isNotEmpty ? validBids.first : null),
              dropdownColor: AppColors.surfaceElevated,
              items: validBids
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text('$b', style: const TextStyle(color: Colors.white)),
                      ))
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
              items: ['Spade', 'Heart', 'Diamond', 'Club'].map((s) {
                String char = '♠\uFE0E';
                Color color = Colors.white;
                if (s == 'Heart') { char = '♥\uFE0E'; color = const Color(0xFFE53935); }
                else if (s == 'Diamond') { char = '♦\uFE0E'; color = const Color(0xFFE53935); }
                else if (s == 'Club') { char = '♣\uFE0E'; color = Colors.white; }
                return DropdownMenuItem(
                  value: s,
                  child: Text(char, style: TextStyle(color: color, fontSize: 18)),
                );
              }).toList(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reconnecting banner
// ─────────────────────────────────────────────────────────────────────────────

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
