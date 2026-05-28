import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/theme.dart';
import '../widgets/opponent_widget.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/tech_background.dart';
import '../widgets/trick_zone_widget.dart';
import '../../data/models/player.dart';
import 'bidding_screen.dart';
import 'home_screen.dart';

/// Screen 4: The Virtual Game Table.
///
/// Layout using [Stack] + [Align]:
/// - Opponent (top center)
/// - Opponent (left center)
/// - Opponent (right center)
/// - Trick Zone (center)
/// - Player hand (bottom center)
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Force landscape mode for the game table
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore all orientations when leaving game
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

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

  void _showRoundOverDialog(BuildContext context, GameRoundOver state) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    final gameState = state.gameState;
    
    // Sort scoreboard players by rank ascending, fallback to score descending
    final sortedPlayers = List<Player>.from(gameState.players)
      ..sort((a, b) {
        if (a.rank != null && b.rank != null) {
          return a.rank!.compareTo(b.rank!);
        }
        return b.cumulativeScore.compareTo(a.cumulativeScore);
      });

    final screenshotKey = GlobalKey();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        contentPadding: EdgeInsets.zero,
        content: RepaintBoundary(
          key: screenshotKey,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.isGameOver ? '🏆 Game Over!' : 'Round ${gameState.currentRound} Over!',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 16),
                ...sortedPlayers.mapIndexed((idx, p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _RankBadge(rank: p.rank ?? (idx + 1)),
                              const SizedBox(width: 8),
                              Text(
                                p.name,
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Text(
                            p.cumulativeScore.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          if (!state.isGameOver)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Next round starting in 5s...',
                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else ...[
            TextButton.icon(
              icon: const Icon(Icons.share, color: AppColors.gold),
              onPressed: () async {
                try {
                  final boundary = screenshotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                  if (boundary == null) return;
                  final image = await boundary.toImage(pixelRatio: 2.0);
                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  if (byteData == null) return;
                  final pngBytes = byteData.buffer.asUint8List();
                  
                  final xFile = XFile.fromData(
                    pngBytes,
                    mimeType: 'image/png',
                    name: 'callbreak_result.png',
                  );
                  // ignore: deprecated_member_use
                  await Share.shareXFiles(
                    [xFile],
                    text: 'I just finished a game of Callbreak! Check out the results!',
                  );
                } catch (e) {
                  debugPrint('Failed to share screenshot: $e');
                }
              },
              label: const Text('Share Result', style: TextStyle(color: AppColors.gold)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.home_rounded),
              onPressed: () {
                _dismissDialog();
                context
                    .read<GameBloc>()
                    .add(const DisconnectRequested());
              },
              label: const Text('Back to Home'),
            ),
          ]
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
        if (state is GameRoundOver) {
          _showRoundOverDialog(context, state);
        } else {
          _dismissDialog();
        }
        if (state is GameBidding) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BiddingScreen()),
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

            if (state is! GameActive) {
              return Scaffold(
                backgroundColor: getTableColor(false),
                body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              );
            }

        final gameState = state.gameState;
        final myPlayerId = state.myPlayerId;
        final isMyTurn = gameState.isMyTurn(myPlayerId);

        final numPlayers = gameState.players.length;
        int myIndex = gameState.players.indexWhere((p) => p.id == myPlayerId);
        if (myIndex == -1) myIndex = 0;

        final myPlayer = gameState.players[myIndex];

        // Assign opponents to positions in a clockwise layout around the table:
        // Bottom: Me (index: myIndex)
        // Left:   Opponent next to me (index: myIndex + 1)
        // Top:    Opponent opposite to me (index: myIndex + 2)
        // Right:  Opponent preceding me (index: myIndex + 3)
        final leftOpponent = numPlayers > 1 ? gameState.players[(myIndex + 1) % numPlayers] : null;
        final topOpponent = numPlayers > 2 ? gameState.players[(myIndex + 2) % numPlayers] : null;
        final rightOpponent = numPlayers > 3 ? gameState.players[(myIndex + 3) % numPlayers] : null;

        return Scaffold(
          backgroundColor: getTableColor(false),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white54),
              onPressed: () => _showLeaveMatchDialog(context),
            ),
          ),
          extendBodyBehindAppBar: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Table background texture ───────────────────────────────
              TechBackground(
                color: getTableColor(false),
                lightColor: getTableColor(true),
              ),

              // ── Top Opponent ───────────────────────────────────────────
              if (topOpponent != null)
                Align(
                  alignment: const Alignment(0, -0.8),
                  child: OpponentWidget(
                    player: topOpponent,
                    isCurrentTurn: gameState.currentTurn == topOpponent.id,
                    position: OpponentPosition.top,
                  ),
                ),

              // ── Left Opponent ──────────────────────────────────────────
              if (leftOpponent != null)
                Align(
                  alignment: const Alignment(-0.9, 0),
                  child: OpponentWidget(
                    player: leftOpponent,
                    isCurrentTurn: gameState.currentTurn == leftOpponent.id,
                    position: OpponentPosition.left,
                  ),
                ),

              // ── Right Opponent ─────────────────────────────────────────
              if (rightOpponent != null)
                Align(
                  alignment: const Alignment(0.9, 0),
                  child: OpponentWidget(
                    player: rightOpponent,
                    isCurrentTurn: gameState.currentTurn == rightOpponent.id,
                    position: OpponentPosition.right,
                  ),
                ),

              // ── Trick Zone (center) ────────────────────────────────────
              Align(
                alignment: Alignment.center,
                child: TrickZoneWidget(
                  trick: gameState.currentTrick,
                  players: gameState.players,
                  myPlayerId: myPlayerId,
                ),
              ),

              // ── Turn indicator ─────────────────────────────────────────
              Align(
                alignment: const Alignment(0, 0.4),
                child: AnimatedOpacity(
                  opacity: isMyTurn ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Your turn — play a card',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // ── My player stats ────────────────────────────────────────
              Align(
                alignment: const Alignment(0, 0.5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        myPlayer.name,
                        style: TextStyle(
                          color: isMyTurn ? AppColors.gold : Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: isMyTurn
                              ? [const Shadow(color: AppColors.gold, blurRadius: 8)]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatBadge(
                        label: 'Bid',
                        value: '${myPlayer.bid ?? "-"}',
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      _StatBadge(
                        label: 'Won',
                        value: '${myPlayer.tricksWon}',
                        color: AppColors.successGreen,
                      ),
                    ],
                  ),
                ),
              ),

              // ── My Hand (bottom) ───────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _FannedHand(
                  cards: gameState.myHand,
                  isMyTurn: isMyTurn,
                  awaitingServer: state.awaitingServer,
                  currentTrick: gameState.currentTrick,
                  trumpSuit: gameState.currentTrumpSuit ?? 'Spade',
                  onCardTap: (card) {
                    if (isMyTurn && !state.awaitingServer) {
                      context.read<GameBloc>().add(PlayCardAttempt(card));
                    }
                  },
                ),
              ),

              // ── Score overlay (round info) ─────────────────────────────
              Positioned(
                top: 40,
                right: 16,
                child: _ScorePanel(gameState: gameState),
              ),
            ],
          ),
        );
      },
    );
      },
    );
  }
}

/// Fanned card hand widget with playability logic.
/// Uses overlapping cards to fit all 13 cards on screen in landscape.
class _FannedHand extends StatelessWidget {
  final List<dynamic> cards;
  final bool isMyTurn;
  final bool awaitingServer;
  final dynamic currentTrick;
  final String trumpSuit;
  final void Function(dynamic card) onCardTap;

  const _FannedHand({
    required this.cards,
    required this.isMyTurn,
    required this.awaitingServer,
    required this.currentTrick,
    required this.trumpSuit,
    required this.onCardTap,
  });

  bool _canPlayCard(dynamic cardToPlay) {
    if (!isMyTurn || awaitingServer) return false;

    final trickCards = currentTrick.cards as List<dynamic>;
    if (trickCards.isEmpty) return true;

    final String ledSuit = (currentTrick.ledSuit ?? trickCards.first.card.suit) as String;

    dynamic getWinningTrickCard() {
      final trumpCards = trickCards.where((tc) => tc.card.suit == trumpSuit).toList();
      if (trumpCards.isNotEmpty) {
        var maxTrump = trumpCards[0];
        for (var i = 1; i < trumpCards.length; i++) {
          if (trumpCards[i].card.value > maxTrump.card.value) maxTrump = trumpCards[i];
        }
        return maxTrump.card;
      } else {
        final ledSuitCards = trickCards.where((tc) => tc.card.suit == ledSuit).toList();
        var maxLed = ledSuitCards[0];
        for (var i = 1; i < ledSuitCards.length; i++) {
          if (ledSuitCards[i].card.value > maxLed.card.value) maxLed = ledSuitCards[i];
        }
        return maxLed.card;
      }
    }

    final winningCard = getWinningTrickCard();
    final hasLedSuit = cards.any((c) => c.suit == ledSuit);

    if (hasLedSuit) {
      if (cardToPlay.suit != ledSuit) return false;
      final bool canBeat = winningCard.suit == ledSuit;
      final hasBeatingCard = cards.any(
          (c) => c.suit == ledSuit && canBeat && c.value > winningCard.value);
      if (hasBeatingCard) return cardToPlay.value > winningCard.value;
      return true;
    } else {
      final hasBeatingSpade = cards.any((c) =>
          c.suit == trumpSuit &&
          (winningCard.suit != trumpSuit || c.value > winningCard.value));
          
      if (hasBeatingSpade) {
        if (cardToPlay.suit != trumpSuit) return false;
        if (winningCard.suit == trumpSuit && cardToPlay.value <= winningCard.value) return false;
        return true;
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('No cards', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final sortedCards = List<dynamic>.from(cards)..sort();
    final int count = sortedCards.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // In landscape the available width is wider; compute a card width
        // that lets all 13 cards fan with overlap and still shows the full
        // last card.  Card ratio ≈ 2:3.
        const double cardH = 90.0;
        const double cardW = 60.0;
        // Overlap so all cards fit: total width = (n-1)*step + cardW
        // We want total <= availableWidth with some padding.
        final double availW = constraints.maxWidth - 24;
        final double step = count > 1
            ? ((availW - cardW) / (count - 1)).clamp(15.0, 54.0)
            : 0.0;
        final double totalW = (count - 1) * step + cardW;

        return Container(
          height: cardH + 20, // extra for lift animation
          alignment: Alignment.center,
          child: SizedBox(
            width: totalW,
            height: cardH + 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: sortedCards.asMap().entries.map((entry) {
                final i = entry.key;
                final card = entry.value;
                final canPlay = _canPlayCard(card);

                return Positioned(
                  left: i * step,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(
                        0, canPlay ? -10 : 0, 0),
                    child: GestureDetector(
                      onTap: canPlay ? () => onCardTap(card) : null,
                      child: SizedBox(
                        width: cardW,
                        height: cardH,
                        child: PlayingCardWidget(
                          card: card,
                          isPlayable: canPlay,
                          isSmall: true,
                          onTap: canPlay ? () => onCardTap(card) : null,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  final dynamic gameState;

  const _ScorePanel({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Round ${gameState.currentRound} / ${gameState.totalRounds}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              if (gameState.allowCustomTrump)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBA68C8).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFBA68C8)),
                  ),
                  child: Text(
                    'Trump: ${gameState.currentTrumpSuit ?? "Spade"}',
                    style: const TextStyle(
                      color: Color(0xFFBA68C8),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          ...gameState.players.map((p) => Text(
                '${p.name}: ${p.cumulativeScore.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              )),
        ],
      ),
    );
  }
}

/// Creative rank badge using medal emojis and colored containers.
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final String emoji;
    final Color bg;
    final Color border;

    switch (rank) {
      case 1:
        emoji = '🥇';
        bg = const Color(0xFFFFD700).withValues(alpha: 0.2);
        border = const Color(0xFFFFD700);
      case 2:
        emoji = '🥈';
        bg = const Color(0xFFC0C0C0).withValues(alpha: 0.2);
        border = const Color(0xFFC0C0C0);
      case 3:
        emoji = '🥉';
        bg = const Color(0xFFCD7F32).withValues(alpha: 0.2);
        border = const Color(0xFFCD7F32);
      default:
        emoji = '🤡';
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red.shade300;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    );
  }
}

// Extension to iterate with index
extension ListMapIndexed<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T element) f) sync* {
    var index = 0;
    for (final element in this) {
      yield f(index++, element);
    }
  }
}
