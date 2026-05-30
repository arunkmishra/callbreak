import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/audio_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../widgets/opponent_widget.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/score_board_widget.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tech_background.dart';
import '../widgets/trick_zone_widget.dart';
import '../widgets/turn_timer_widget.dart';
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
  String? _lastTrumpBidderId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded, color: AppColors.errorRed, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Leave Match?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to leave?\n\nA bot will take over your seat, and you may lose points.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _dismissDialog(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _dismissDialog();
                        context.read<GameBloc>().add(const DisconnectRequested());
                      },
                      child: const Text('Leave', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  void _showRoundOverDialog(BuildContext context, GameRoundOver state) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    final gameState = state.gameState;
    
    final screenshotKey = GlobalKey();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) {
                  final isLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
                  
                  final myPlayer = gameState.players.firstWhere((p) => p.id == state.myPlayerId, orElse: () => gameState.players.first);
                  final bool isWinner = state.isGameOver && myPlayer.rank == 1;

                  final titleWidget = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.isGameOver ? '🏆 Game Over!' : 'Round ${gameState.currentRound} Over!',
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      if (isWinner)
                        const Padding(
                          padding: EdgeInsets.only(top: 12.0),
                          child: Text(
                            '🎉 Congratulations!\nYou Won! 🎉',
                            style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  );

                  Widget actionWidget;
                  if (!state.isGameOver) {
                    actionWidget = const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('Next round starting in 5s...', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                    );
                  } else {
                    actionWidget = Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                                
                                late XFile xFile;
                                if (kIsWeb) {
                                  xFile = XFile.fromData(
                                    pngBytes,
                                    mimeType: 'image/png',
                                    name: 'callbreak_result.png',
                                  );
                                } else {
                                  final tempDir = await getTemporaryDirectory();
                                  final file = await File('${tempDir.path}/callbreak_result.png').create();
                                  await file.writeAsBytes(pngBytes);
                                  xFile = XFile(file.path);
                                }
                                
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
                              context.read<GameBloc>().add(const DisconnectRequested());
                            },
                            label: const Text('Back to Home'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (isLandscape) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              titleWidget,
                              const SizedBox(height: 24),
                              actionWidget,
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 3,
                          child: RepaintBoundary(
                            key: screenshotKey,
                            child: ScoreBoardWidget(gameState: gameState, hideTitle: false),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        titleWidget,
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          key: screenshotKey,
                          child: ScoreBoardWidget(gameState: gameState, hideTitle: true),
                        ),
                        actionWidget,
                      ],
                    );
                  }
                }
              ),
            ),
          ),
        ),
      ).then((_) {
      _isDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (!context.mounted) return;
        if (state is GameRoundOver) {
          _showRoundOverDialog(context, state);
        } else {
          _dismissDialog();
        }
        if (state is GameBidding) {
          final gameState = state.gameState;
          if (gameState.phase == GamePhase.trumpBidding) {
            final bidState = gameState.trumpBidState;
            if (bidState.highestBidderId != null && bidState.highestBidderId != _lastTrumpBidderId) {
              _lastTrumpBidderId = bidState.highestBidderId;
              
              final player = gameState.players.firstWhere((p) => p.id == bidState.highestBidderId, orElse: () => gameState.players.first);
              final suit = bidState.proposedSuit ?? 'Spade';
              final isMe = player.id == state.myPlayerId;
              final namePrefix = isMe ? 'You' : player.name;
              
              String char = '♠';
              Color suitColor = Colors.white;
              if (suit.toUpperCase().contains('HEART')) { char = '♥'; suitColor = Colors.redAccent; }
              else if (suit.toUpperCase().contains('DIAMOND')) { char = '♦'; suitColor = Colors.redAccent; }
              else if (suit.toUpperCase().contains('CLUB')) { char = '♣'; suitColor = Colors.white; }

              rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.sizeOf(context).height - 120, 
                    left: 16, 
                    right: 16
                  ),
                  content: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active, color: AppColors.gold, size: 16),
                          const SizedBox(width: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: '$namePrefix updated Trump to ', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                TextSpan(text: char, style: TextStyle(color: suitColor, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
          } else {
            _lastTrumpBidderId = null;
          }
        } else if (state is GameActive) {
          _lastTrumpBidderId = null;
        }

        if (state is GameInitial) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
        if (state is GameError) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
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

            if (state is! GameActive && state is! GameBidding) {
              return Scaffold(
                backgroundColor: getTableColor(false),
                body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              );
            }

        final gameState = state is GameActive 
            ? state.gameState 
            : (state as GameBidding).gameState;
        final myPlayerId = state is GameActive 
            ? state.myPlayerId 
            : (state as GameBidding).myPlayerId;
        final isReconnecting = state is GameActive 
            ? state.isReconnecting 
            : (state as GameBidding).isReconnecting;
        final awaitingServer = state is GameActive 
            ? state.awaitingServer 
            : false;
            
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
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white54),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => const SettingsSheet(),
                  );
                },
              ),
            ],
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

              // ── Reconnecting banner ────────────────────────────────────
              if (isReconnecting)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _ReconnectingBanner(),
                ),

              // ── Top Opponent ───────────────────────────────────────────
              if (topOpponent != null)
                Align(
                  alignment: const Alignment(0, -0.95),
                  child: OpponentWidget(
                    player: topOpponent,
                    isCurrentTurn: gameState.currentTurn == topOpponent.id,
                    turnEndTime: gameState.currentTurn == topOpponent.id ? gameState.turnEndTime : null,
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
                    turnEndTime: gameState.currentTurn == leftOpponent.id ? gameState.turnEndTime : null,
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
                    turnEndTime: gameState.currentTurn == rightOpponent.id ? gameState.turnEndTime : null,
                    position: OpponentPosition.right,
                  ),
                ),

              // ── Center Area (Trick Zone or Bidding Overlay) ──────────────
              Align(
                alignment: state is GameBidding ? const Alignment(0, -0.3) : Alignment.center,
                child: state is GameBidding
                    ? _BiddingOverlay(
                        gameState: gameState,
                        myPlayerId: myPlayerId,
                      )
                    : TrickZoneWidget(
                        trick: gameState.currentTrick,
                        players: gameState.players,
                        myPlayerId: myPlayerId,
                      ),
              ),

              // ── Turn indicator & Timer ─────────────────────────────────
              Align(
                alignment: const Alignment(0, 0.4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMyTurn && gameState.turnEndTime != null)
                      TurnTimerWidget(
                        turnEndTime: gameState.turnEndTime!,
                        isMyTurn: true,
                      ),
                    const SizedBox(height: 8),
                    AnimatedOpacity(
                      opacity: (isMyTurn && state is GameActive) ? 1.0 : 0.0,
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
                  ],
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
                  isMyTurn: state is GameActive && isMyTurn,
                  awaitingServer: awaitingServer,
                  currentTrick: gameState.currentTrick,
                  trumpSuit: gameState.currentTrumpSuit ?? 'Spade',
                  onCardTap: (card) {
                    if (state is GameActive && isMyTurn && !awaitingServer) {
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
class _FannedHand extends StatefulWidget {
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

  @override
  State<_FannedHand> createState() => _FannedHandState();
}

class _FannedHandState extends State<_FannedHand> with SingleTickerProviderStateMixin {
  late AnimationController _dealController;
  @override
  void initState() {
    super.initState();
    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Total deal time
    );
    if (widget.cards.isNotEmpty) {
      _dealController.forward();
      AudioService.playCardDealSequence();
    }
  }

  @override
  void didUpdateWidget(covariant _FannedHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.isEmpty && widget.cards.isNotEmpty) {
      _dealController.forward(from: 0.0);
      AudioService.playCardDealSequence();
    }
  }

  @override
  void dispose() {
    _dealController.dispose();
    super.dispose();
  }

  bool _canPlayCard(dynamic cardToPlay) {
    if (!widget.isMyTurn || widget.awaitingServer) return false;

    final trickCards = widget.currentTrick.cards as List<dynamic>;
    if (trickCards.isEmpty) return true;

    final String ledSuit = (widget.currentTrick.ledSuit ?? trickCards.first.card.suit) as String;

    dynamic getWinningTrickCard() {
      final trumpCards = trickCards.where((tc) => tc.card.suit == widget.trumpSuit).toList();
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
    final hasLedSuit = widget.cards.any((c) => c.suit == ledSuit);

    if (hasLedSuit) {
      if (cardToPlay.suit != ledSuit) return false;
      final bool canBeat = winningCard.suit == ledSuit;
      final hasBeatingCard = widget.cards.any(
          (c) => c.suit == ledSuit && canBeat && c.value > winningCard.value);
      if (hasBeatingCard) return cardToPlay.value > winningCard.value;
      return true;
    } else {
      final hasBeatingSpade = widget.cards.any((c) =>
          c.suit == widget.trumpSuit &&
          (winningCard.suit != widget.trumpSuit || c.value > winningCard.value));
          
      if (hasBeatingSpade) {
        if (cardToPlay.suit != widget.trumpSuit) return false;
        if (winningCard.suit == widget.trumpSuit && cardToPlay.value <= winningCard.value) return false;
        return true;
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('No cards', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final sortedCards = List<dynamic>.from(widget.cards)..sort();
    final int count = sortedCards.length;
    // Base the stagger on 13 cards so timing is consistent
    const double staggerStep = 1.0 / 13; 

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

                // Calculate staggered animation for this specific card
                final start = (i * staggerStep).clamp(0.0, 1.0);
                final end = (start + 0.2).clamp(0.0, 1.0);
                final animation = CurvedAnimation(
                  parent: _dealController,
                  curve: Interval(start, end, curve: Curves.easeOutBack),
                );

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // Fly in from bottom (offset dx=0, dy=cardH + 50) and fade in
                    final dy = (1.0 - animation.value) * (cardH + 50);
                    final opacity = animation.value.clamp(0.0, 1.0);
                    
                    return Positioned(
                      left: i * step,
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(
                        0, canPlay ? -10 : 0, 0),
                    child: GestureDetector(
                      onTap: canPlay ? () => widget.onCardTap(card) : null,
                      child: SizedBox(
                        width: cardW,
                        height: cardH,
                        child: PlayingCardWidget(
                          card: card,
                          isPlayable: canPlay,
                          isSmall: true,
                          onTap: canPlay ? () => widget.onCardTap(card) : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Builder(
              builder: (context) {
                String trump = gameState.currentTrumpSuit ?? 'Spade';
                if (gameState.phase == GamePhase.trumpBidding && gameState.trumpBidState.proposedSuit != null) {
                  trump = gameState.trumpBidState.proposedSuit!;
                }
                final s = trump.toUpperCase();
                String char = '♠';
                Color suitColor = Colors.white;
                if (s.contains('HEART')) { char = '♥'; suitColor = Colors.redAccent; }
                else if (s.contains('DIAMOND')) { char = '♦'; suitColor = Colors.redAccent; }
                else if (s.contains('CLUB')) { char = '♣'; suitColor = Colors.white; }
                return RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Trump: ',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: char,
                        style: TextStyle(color: suitColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.tableGreenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.leaderboard, color: AppColors.gold, size: 20),
            ),
          ),
        ],
      ),
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

/// Amber banner shown at top of screen while reconnecting.
class _ReconnectingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.amber.shade800.withValues(alpha: 0.92),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bidding Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _BiddingOverlay extends StatefulWidget {
  final GameState gameState;
  final String myPlayerId;

  const _BiddingOverlay({required this.gameState, required this.myPlayerId});

  @override
  State<_BiddingOverlay> createState() => _BiddingOverlayState();
}

class _BiddingOverlayState extends State<_BiddingOverlay> {
  int _sliderBid = 1; 
  late int _trumpBid;
  String _trumpSuit = 'Spade';

  @override
  void initState() {
    super.initState();
    _initBidValues();
  }

  @override
  void didUpdateWidget(covariant _BiddingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initBidValues();
  }

  void _initBidValues() {
    final gameState = widget.gameState;
    int minBid = gameState.minBid ?? 1;
    if (gameState.phase == GamePhase.trumpBidding) {
      final highest = gameState.trumpBidState.highestBid;
      _trumpBid = highest >= 5 ? highest + 1 : 5;
    } else {
      final myPlayer = gameState.players.firstWhere((p) => p.id == widget.myPlayerId);
      final trumpState = gameState.trumpBidState;
      if (trumpState.highestBidderId == myPlayer.id && trumpState.highestBid > 0) {
        if (trumpState.highestBid > minBid) {
          minBid = trumpState.highestBid;
        }
      }
      if (_sliderBid < minBid) {
        _sliderBid = minBid;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = widget.gameState;
    final myPlayer = gameState.players.firstWhere((p) => p.id == widget.myPlayerId);
    final isMyTurn = gameState.isMyTurn(widget.myPlayerId);
    final currentBidder = gameState.players.firstWhere(
      (p) => p.id == gameState.currentTurn,
      orElse: () => gameState.players.first,
    );

    if (myPlayer.bid != null) {
      return _buildWaitingBubble(
        icon: Icons.check_circle,
        color: AppColors.successGreen,
        text: 'You bid ${myPlayer.bid}. Waiting for others...',
      );
    }

    if (!isMyTurn) {
      return _buildWaitingBubble(
        icon: Icons.hourglass_empty,
        color: Colors.white54,
        text: 'Waiting for ${currentBidder.name} to bid...',
      );
    }

    if (gameState.phase == GamePhase.trumpBidding) {
      return _buildTrumpBidForm(gameState, context);
    }

    return _buildRegularBidSlider(gameState, myPlayer, context);
  }

  Widget _buildWaitingBubble({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRegularBidSlider(GameState gameState, Player myPlayer, BuildContext context) {
    int minBid = gameState.minBid ?? 1;
    final trumpState = gameState.trumpBidState;
    if (trumpState.highestBidderId == myPlayer.id && trumpState.highestBid > 0) {
      if (trumpState.highestBid > minBid) {
        minBid = trumpState.highestBid;
      }
    }

    final isCompact = MediaQuery.sizeOf(context).height < 500;

    return Container(
      width: isCompact ? 300 : 320,
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Place Your Bid',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: isCompact ? 16 : 18),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            'Select how many tricks you can win',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 11 : 13),
          ),
          SizedBox(height: isCompact ? 12 : 24),
          Row(
            children: [
              Text('$minBid', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              Expanded(
                child: Slider(
                  value: _sliderBid.toDouble(),
                  min: minBid.toDouble(),
                  max: 13,
                  divisions: 13 - minBid > 0 ? 13 - minBid : 1,
                  activeColor: AppColors.gold,
                  inactiveColor: Colors.white24,
                  label: '$_sliderBid',
                  onChanged: (val) {
                    setState(() {
                      _sliderBid = val.toInt();
                    });
                  },
                ),
              ),
              const Text('13', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_sliderBid',
                style: TextStyle(color: AppColors.gold, fontSize: isCompact ? 36 : 48, fontWeight: FontWeight.w900, height: 1),
              ),
              SizedBox(width: isCompact ? 20 : 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: isCompact ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : null,
                  minimumSize: isCompact ? const Size(0, 36) : const Size(0, 52),
                ),
                onPressed: () {
                  context.read<GameBloc>().add(PlaceBidAttempt(_sliderBid));
                },
                icon: Icon(Icons.check, size: isCompact ? 18 : 20),
                label: Text(isCompact ? 'CONFIRM' : 'CONFIRM BID'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrumpBidForm(GameState gameState, BuildContext context) {
    final highest = gameState.trumpBidState.highestBid;
    final validBids = List.generate(13 - 5 + 1, (i) => 5 + i).where((b) => b > highest).toList();

    final isCompact = MediaQuery.sizeOf(context).height < 500;

    return Container(
      width: isCompact ? 300 : 320,
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBA68C8).withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Set Trump Suit & Bid',
            style: TextStyle(color: const Color(0xFFBA68C8), fontWeight: FontWeight.bold, fontSize: isCompact ? 16 : 18),
          ),
          if (!isCompact) ...[
            const SizedBox(height: 8),
            const Text(
              'Based on your first 5 cards',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          SizedBox(height: isCompact ? 12 : 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Bid:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: validBids.contains(_trumpBid) ? _trumpBid : (validBids.isNotEmpty ? validBids.first : null),
                dropdownColor: AppColors.surfaceElevated,
                items: validBids.map((b) => DropdownMenuItem(value: b, child: Text('$b', style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _trumpBid = v);
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _trumpSuit,
                dropdownColor: AppColors.surfaceElevated,
                items: ['Spade', 'Heart', 'Diamond', 'Club'].map((s) {
                  final String symbol = s == 'Spade' ? '♠' : s == 'Heart' ? '♥' : s == 'Diamond' ? '♦' : '♣';
                  final Color color = (s == 'Heart' || s == 'Diamond') ? AppColors.rankRed : Colors.white;
                  return DropdownMenuItem(
                    value: s,
                    child: Text(symbol, style: TextStyle(color: color, fontSize: 22)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _trumpSuit = v);
                },
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    context.read<GameBloc>().add(const PlaceTrumpBidAttempt(null, null));
                  },
                  child: const Text('PASS', style: TextStyle(color: Colors.white54)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA68C8),
                    padding: isCompact ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8) : null,
                    minimumSize: isCompact ? const Size(0, 36) : const Size(0, 52),
                  ),
                  onPressed: () {
                    context.read<GameBloc>().add(PlaceTrumpBidAttempt(_trumpBid, _trumpSuit));
                  },
                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text('BID & SET', style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

