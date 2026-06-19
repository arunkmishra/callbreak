import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/audio_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tier_system.dart';
import '../../data/models/emoticon_event.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../widgets/emoticon_overlay.dart';
import '../widgets/emoticon_picker.dart';
import '../widgets/opponent_widget.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/score_board_widget.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/trick_zone_widget.dart';
import '../widgets/turn_timer_widget.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

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

  // ── Emoticon overlay keys — one per seat (left, top, right, me) ──────────
  final _leftOverlayKey  = GlobalKey<EmoticonOverlayController>();
  final _topOverlayKey   = GlobalKey<EmoticonOverlayController>();
  final _rightOverlayKey = GlobalKey<EmoticonOverlayController>();
  final _myOverlayKey    = GlobalKey<EmoticonOverlayController>();

  @override
  void initState() {
    super.initState();
    // WakelockPlus injects no_sleep.js into the DOM on every enable() call.
    // On web this causes a PromiseCompleter re-declaration crash when the
    // screen is remounted (e.g. after rematch). Skip wakelock on web.
    if (!kIsWeb) {
      try {
        WakelockPlus.enable();
      } catch (e) {
        debugPrint('Wakelock enable error: $e');
      }
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      try {
        WakelockPlus.disable();
      } catch (e) {
        debugPrint('Wakelock disable error: $e');
      }
    }
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
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1830),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF2A3A5C),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.errorRed.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // ── Warning icon with glow ───────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.errorRed.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.errorRed.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.errorRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),

              // ── Title ────────────────────────────────────────────────
              const Text(
                'Leave Match?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),

              // ── Subtitle ─────────────────────────────────────────────
              const Text(
                'Are you sure you want to leave?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // ── Info box ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.errorRed.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 1),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.errorRed.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(text: 'A bot will take over your seat, and you may '),
                            TextSpan(
                              text: 'lose points.',
                              style: TextStyle(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Buttons ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                      ),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      onPressed: () => _dismissDialog(),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 18),
                      onPressed: () {
                        _dismissDialog();
                        context.read<GameBloc>().add(const DisconnectRequested());
                      },
                      label: const Text(
                        'Leave',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }


  Future<void> _shareScreenshot(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      late XFile xFile;
      if (kIsWeb) {
        xFile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'callbreak_result.png');
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/callbreak_result.png').create();
        await file.writeAsBytes(pngBytes);
        xFile = XFile(file.path);
      }
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'I just finished a game of Callbreak! Check out the results!');
    } catch (e) {
      debugPrint('Failed to share screenshot: $e');
    }
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Builder(builder: (context) {
          final isLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

          final myPlayer = gameState.players.firstWhere(
            (p) => p.id == state.myPlayerId,
            orElse: () => gameState.players.first,
          );
          final bool isWinner = state.isGameOver && myPlayer.rank == 1;

          // ── Left panel ──────────────────────────────────────────────────
          final leftPanel = Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E3A6E), width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Trophy glow ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isWinner
                        ? const Text('🏆', style: TextStyle(fontSize: 48))
                        : Container(
                            width: 45,
                            height: 65,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'A',
                                  style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold, height: 1.1),
                                ),
                                Text(
                                  '♠',
                                  style: TextStyle(color: Colors.black, fontSize: 24, height: 1.1),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Headline ─────────────────────────────────────────────
                if (state.isGameOver) ...[
                  Text(
                    isWinner ? 'YOU WON!' : 'GAME OVER',
                    style: TextStyle(
                      color: isWinner ? AppColors.gold : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.2,
                      shadows: isWinner
                          ? [Shadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 16)]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWinner
                        ? 'Great game! You outplayed everyone.'
                        : 'Better luck next time!',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  
                  // ── Ranked Progression ───────────────────────────────────
                  Builder(builder: (context) {
                    final rpChange = myPlayer.rpChange ?? 0;
                    final currentRp = myPlayer.currentRp ?? 1000;
                    final isPositive = rpChange >= 0;
                    final sign = isPositive ? '+' : '';
                    final color = isPositive ? AppColors.gold : AppColors.errorRed;
                    final tierName = TierSystem.getTierName(currentRp);
                    final tierColor = TierSystem.getTierColor(currentRp);
                    final tierIcon = TierSystem.getTierIcon(currentRp);

                    return Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tierIcon, color: tierColor, size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tierName,
                                style: TextStyle(
                                  color: tierColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '$currentRp RP',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '($sign$rpChange)',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // ── Share Result button (outlined purple) ───────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: const Color(0xFFA78BFA),
                        backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      onPressed: () => _shareScreenshot(screenshotKey),
                      label: const Text(
                        'Share Result',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Rematch (host only in private rooms) + Back to Lobby ───────────────
                  Builder(builder: (context) {
                    final isPrivateRoom = !gameState.isPublic;
                    
                    // The host is the first non-bot player (room creator).
                    final hostId = gameState.players
                        .firstWhere((p) => !p.isBot,
                            orElse: () => gameState.players.first)
                        .id;
                    final isHost = state.myPlayerId == hostId;

                    if (isPrivateRoom && isHost) {
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              onPressed: () {
                                _dismissDialog();
                                context.read<GameBloc>().add(RematchRequested(gameState));
                              },
                              label: const Text(
                                'Rematch',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.home_rounded, size: 16),
                              onPressed: () {
                                _dismissDialog();
                                context.read<GameBloc>().add(const DisconnectRequested());
                              },
                              label: const Text(
                                'Back to Lobby',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Non-host or Public Room: full-width Back to Lobby only
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.home_rounded, size: 20),
                        onPressed: () {
                          _dismissDialog();
                          context.read<GameBloc>().add(const DisconnectRequested());
                        },
                        label: const Text(
                          'Back to Lobby',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  // ── Round over (not game over) ──────────────────────────
                  Text(
                    'Round ${gameState.currentRound} Over!',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Next round starting in 5s...',
                    style: TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          );

          // ── Right panel (scorecard) ──────────────────────────────────────
          final rightPanel = RepaintBoundary(
            key: screenshotKey,
            child: ScoreBoardWidget(
              players: gameState.players,
              roundScores: gameState.roundScores,
              myPlayerId: state.myPlayerId,
              isGameOver: gameState.isGameOver,
            ),
          );

          // ── Layout ───────────────────────────────────────────────────────
          if (isLandscape) {
            return SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1B33),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftPanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 7, child: rightPanel),
                  ],
                ),
              ),
            );
          } else {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B33),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leftPanel,
                    const SizedBox(height: 16),
                    rightPanel,
                  ],
                ),
              ),
            );
          }
        }),
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showLeaveMatchDialog(context);
      },
      child: BlocConsumer<GameBloc, GameBlocState>(
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

        // ── Emoticon overlay trigger ────────────────────────────────────────
        EmoticonEvent? pending;
        if (state is GameActive) {
          pending = state.pendingEmoticon;
        } else if (state is GameBidding) {
          pending = state.pendingEmoticon;
        }
        if (pending != null) {
          String emoticonPlayerId = pending.playerId;
          List players = [];
          if (state is GameActive) {
            players = state.gameState.players;
          } else if (state is GameBidding) {
            players = state.gameState.players;
          }
          if (players.isNotEmpty) {
            final myPlayerId = state is GameActive
                ? state.myPlayerId
                : (state as GameBidding).myPlayerId;
            final numPlayers = players.length;
            int myIndex = players.indexWhere((p) => p.id == myPlayerId);
            if (myIndex == -1) myIndex = 0;

            if (emoticonPlayerId == myPlayerId) {
              _myOverlayKey.currentState?.show(pending.emoticon);
            } else if (numPlayers > 1 &&
                emoticonPlayerId == players[(myIndex + 1) % numPlayers].id) {
              _leftOverlayKey.currentState?.show(pending.emoticon);
            } else if (numPlayers > 2 &&
                emoticonPlayerId == players[(myIndex + 2) % numPlayers].id) {
              _topOverlayKey.currentState?.show(pending.emoticon);
            } else if (numPlayers > 3 &&
                emoticonPlayerId == players[(myIndex + 3) % numPlayers].id) {
              _rightOverlayKey.currentState?.show(pending.emoticon);
            }
          }
        }

        if (state is GameInitial) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
        // Multiplayer rematch non-initiator: bloc emits GameLobby when
        // the auto-join succeeds. Navigate to LobbyScreen to wait for others.
        // (Bot rematch skips GameLobby entirely, so this won't fire for bots.)
        if (state is GameLobby) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LobbyScreen()),
            (route) => false,
          );
        }
        if (state is GameError) {
          if (state.message == 'FORCE_UPDATE_REQUIRED') {
            showDialog(
              context: context,
              barrierDismissible: true,
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
            rootScaffoldMessengerKey.currentState?.showSnackBar(
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
        if (state is GameLoading || state is GameInitial) {
          return const Scaffold(
            backgroundColor: Color(0xFF080B14),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }
        
        if (state is GameError) {
          final isUpdate = state.message == 'FORCE_UPDATE_REQUIRED';
          return Scaffold(
            backgroundColor: const Color(0xFF080B14),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUpdate ? Icons.system_update_rounded : Icons.error_outline_rounded, color: isUpdate ? AppColors.gold : AppColors.errorRed, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      isUpdate ? 'Update Required' : 'Connection Lost',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUpdate ? getUpdateMessage() : state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      child: Text(isUpdate ? 'OK' : 'Return to Home', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settingsState) {
            // Derive accent color from the chosen table-color scheme.
            // The base is always dark navy; the scheme adds a subtle tint.
            final Color schemeAccent;
            final Color bgDark;
            final Color bgLight;
            switch (settingsState.tableColor) {
              case TableColor.green:
                schemeAccent = const Color(0xFF1DB954); // emerald green
                bgDark  = const Color(0xFF060F17);
                bgLight = const Color(0xFF0A1F18);
              case TableColor.red:
                schemeAccent = const Color(0xFFE53935); // crimson red
                bgDark  = const Color(0xFF130608);
                bgLight = const Color(0xFF1F0A0A);
              case TableColor.blue:
                schemeAccent = const Color(0xFF2563EB); // cobalt blue (default)
                bgDark  = const Color(0xFF08122A);
                bgLight = const Color(0xFF0D1F45);
            }

            if (state is! GameActive && state is! GameBidding) {
              return Scaffold(
                backgroundColor: bgDark,
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

        // Assign opponents to positions in a clockwise layout:
        // Bottom: Me, Left: +1, Top: +2, Right: +3
        final leftOpponent = numPlayers > 1 ? gameState.players[(myIndex + 1) % numPlayers] : null;
        final topOpponent = numPlayers > 2 ? gameState.players[(myIndex + 2) % numPlayers] : null;
        final rightOpponent = numPlayers > 3 ? gameState.players[(myIndex + 3) % numPlayers] : null;

        return Scaffold(
          backgroundColor: bgDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Dark tinted gradient background ────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.3,
                    colors: [bgLight, bgDark],
                  ),
                ),
                child: CustomPaint(
                  painter: _NavyBackgroundPainter(accentColor: schemeAccent),
                ),
              ),

              // ── Reconnecting banner ──────────────────────────────────
              if (isReconnecting)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _ReconnectingBanner(),
                ),

              // ── Top App Bar (Exit + Settings) ─────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 8,
                child: Row(
                  children: [
                    _IconBtn(
                      icon: Icons.exit_to_app,
                      onTap: () => _showLeaveMatchDialog(context),
                    ),
                    const SizedBox(width: 4),
                    _IconBtn(
                      icon: Icons.settings_outlined,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => BlocProvider.value(
                            value: context.read<SettingsCubit>(),
                            child: const SettingsDialog(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Top Opponent (horizontal card, top center) ─────────────
              if (topOpponent != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        OpponentWidget(
                          player: topOpponent,
                          isCurrentTurn: gameState.currentTurn == topOpponent.id,
                          turnEndTime: gameState.currentTurn == topOpponent.id ? gameState.turnEndTime : null,
                          position: OpponentPosition.top,
                          accentColor: schemeAccent,
                          calledTrumpSuit: (gameState.allowCustomTrump && gameState.trumpBidState.highestBidderId == topOpponent.id) ? (gameState.trumpBidState.proposedSuit ?? gameState.currentTrumpSuit) : null,
                        ),
                        Positioned(
                          right: -40,
                          top: 20,
                          child: EmoticonOverlay(key: _topOverlayKey),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Score panel (top right) ───────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 12,
                child: _ScorePanel(gameState: gameState, myPlayerId: myPlayerId),
              ),

              // ── Left Opponent (vertical card) ─────────────────────────
              if (leftOpponent != null)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        OpponentWidget(
                          player: leftOpponent,
                          isCurrentTurn: gameState.currentTurn == leftOpponent.id,
                          turnEndTime: gameState.currentTurn == leftOpponent.id ? gameState.turnEndTime : null,
                          position: OpponentPosition.left,
                          accentColor: schemeAccent,
                          calledTrumpSuit: (gameState.allowCustomTrump && gameState.trumpBidState.highestBidderId == leftOpponent.id) ? (gameState.trumpBidState.proposedSuit ?? gameState.currentTrumpSuit) : null,
                        ),
                        Positioned(
                          right: -40,
                          top: 20,
                          child: EmoticonOverlay(key: _leftOverlayKey),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Right Opponent (vertical card) ────────────────────────
              if (rightOpponent != null)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        OpponentWidget(
                          player: rightOpponent,
                          isCurrentTurn: gameState.currentTurn == rightOpponent.id,
                          turnEndTime: gameState.currentTurn == rightOpponent.id ? gameState.turnEndTime : null,
                          position: OpponentPosition.right,
                          accentColor: schemeAccent,
                          calledTrumpSuit: (gameState.allowCustomTrump && gameState.trumpBidState.highestBidderId == rightOpponent.id) ? (gameState.trumpBidState.proposedSuit ?? gameState.currentTrumpSuit) : null,
                        ),
                        Positioned(
                          left: -40,
                          top: 20,
                          child: EmoticonOverlay(key: _rightOverlayKey),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Center Area (Trick Zone or Bidding Overlay) ────────────
              Positioned(
                left: 80,
                right: 80,
                top: 40,
                bottom: 160,
                child: Center(
                  child: state is GameBidding
                      ? _BiddingOverlay(
                          gameState: gameState,
                          myPlayerId: myPlayerId,
                        )
                      : TrickZoneWidget(
                          trick: gameState.currentTrick,
                          players: gameState.players,
                          myPlayerId: myPlayerId,
                          accentColor: schemeAccent,
                        ),
                ),
              ),

              // ── Timer + Turn indicator ─────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: state is GameBidding ? 95 : 158,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMyTurn && gameState.turnEndTime != null)
                      TurnTimerWidget(
                        turnEndTime: gameState.turnEndTime!,
                        isMyTurn: true,
                      ),
                  ],
                ),
              ),

              // ── My player stats bar ────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 110,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      _MyStatsBar(
                        player: myPlayer,
                        isMyTurn: isMyTurn,
                        calledTrumpSuit: (gameState.allowCustomTrump && gameState.trumpBidState.highestBidderId == myPlayer.id) ? (gameState.trumpBidState.proposedSuit ?? gameState.currentTrumpSuit) : null,
                      ),
                      Positioned(
                        top: -46,
                        child: EmoticonOverlay(key: _myOverlayKey),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Emoticon button (right-side) + flying overlay ────────────
              Positioned(
                right: 110,
                bottom: 150,
                child: _EmoticonButton(
                  accentColor: schemeAccent,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => BlocProvider.value(
                        value: context.read<GameBloc>(),
                        child: EmoticonPicker(accentColor: schemeAccent),
                      ),
                    );
                  },
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
            ],
          ),
        );
      },
    );
        },
      ),
    );
  }
}

// ── Navy background painter with subtle grid + center rings ────────────────
class _NavyBackgroundPainter extends CustomPainter {
  final Color accentColor;
  const _NavyBackgroundPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const double gridSize = 80.0;
    for (double i = 0; i <= size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    final center = Offset(size.width / 2, size.height / 2);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = accentColor.withValues(alpha: 0.08)
      ..strokeWidth = 1.5;

    // Oval rings around center play area
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.45, height: size.height * 0.22),
      ringPaint,
    );

    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = accentColor.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.65, height: size.height * 0.35),
      outerRingPaint,
    );

    // Small dot indicators on sides
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.08, center.dy), 5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.92, center.dy), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _NavyBackgroundPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// ── Small icon button ────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white54, size: 18),
      ),
    );
  }
}

// ── My player stats bar (Shared | Bid | Won) ────────────────────────────────
class _MyStatsBar extends StatelessWidget {
  final Player player;
  final bool isMyTurn;
  final String? calledTrumpSuit;

  const _MyStatsBar({required this.player, required this.isMyTurn, this.calledTrumpSuit});

  String _getSuitSymbol(String suit) {
    switch (suit.toLowerCase()) {
      case 'spade': return '♠';
      case 'heart': return '♥';
      case 'diamond': return '♦';
      case 'club': return '♣';
      default: return suit;
    }
  }

  Color _getSuitColor(String suit) {
    return (suit.toLowerCase() == 'heart' || suit.toLowerCase() == 'diamond')
        ? const Color(0xFFEF4444)
        : const Color(0xFF1F2937);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statItem('Bid', '${player.bid ?? "-"}', highlight: true),
          _divider(),
          _statItem('Won', '${player.tricksWon}'),
          if (calledTrumpSuit != null) ...[
            _divider(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trump: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                Text(
                  _getSuitSymbol(calledTrumpSuit!),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.0,
                    color: _getSuitColor(calledTrumpSuit!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF5B9BF5) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '|',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
      ),
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
      duration: const Duration(milliseconds: 1200),
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
        height: 120,
        child: Center(
          child: Text('No cards', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final sortedCards = List<dynamic>.from(widget.cards)..sort();
    final int count = sortedCards.length;
    const double staggerStep = 1.0 / 13;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double cardH = 100.0;
        const double cardW = 65.0;

        final double availW = constraints.maxWidth - 32;
        final double step = count > 1
            ? ((availW - cardW) / (count - 1)).clamp(16.0, 58.0)
            : 0.0;
        final double totalW = (count - 1) * step + cardW;

        return Container(
          height: cardH + 28,
          alignment: Alignment.center,
          child: SizedBox(
            width: totalW,
            height: cardH + 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: sortedCards.asMap().entries.map((entry) {
                final i = entry.key;
                final card = entry.value;
                final canPlay = _canPlayCard(card);

                final start = (i * staggerStep).clamp(0.0, 1.0);
                final end = (start + 0.2).clamp(0.0, 1.0);
                final animation = CurvedAnimation(
                  parent: _dealController,
                  curve: Interval(start, end, curve: Curves.easeOutBack),
                );

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final dy = (1.0 - animation.value) * (cardH + 60);
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
                        0, canPlay ? -14 : 0, 0),
                    child: GestureDetector(
                      onTap: canPlay ? () => widget.onCardTap(card) : null,
                      child: _HandCard(
                        card: card,
                        canPlay: canPlay,
                        cardW: cardW,
                        cardH: cardH,
                        onTap: canPlay ? () => widget.onCardTap(card) : null,
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

/// A hand card with gold border highlight when playable (matching screenshot).
class _HandCard extends StatelessWidget {
  final dynamic card;
  final bool canPlay;
  final double cardW;
  final double cardH;
  final VoidCallback? onTap;

  const _HandCard({
    required this.card,
    required this.canPlay,
    required this.cardW,
    required this.cardH,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardW,
      height: cardH,
      decoration: canPlay
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.gold,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: PlayingCardWidget(
        card: card,
        isPlayable: canPlay,
        isSmall: false,
        onTap: onTap,
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  final dynamic gameState;
  final String myPlayerId;

  const _ScorePanel({required this.gameState, required this.myPlayerId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          _TrumpBadge(gameState: gameState),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: ScoreBoardWidget(
                    players: gameState.players,
                    roundScores: gameState.roundScores,
                    myPlayerId: myPlayerId,
                    isGameOver: gameState.isGameOver,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A6E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: AppColors.gold, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrumpBadge extends StatelessWidget {
  final dynamic gameState;
  const _TrumpBadge({required this.gameState});

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Trump: ',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            char,
            style: TextStyle(color: suitColor, fontSize: 13, fontWeight: FontWeight.bold),
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
  Timer? _autoSubmitTimer;
  bool _hasSubmitted = false;
  bool _initializedSuggestedBid = false;

  @override
  void initState() {
    super.initState();
    _initBidValues();
    _autoSubmitTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkTimer();
    });
  }

  @override
  void didUpdateWidget(covariant _BiddingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initBidValues();
    if (!widget.gameState.isMyTurn(widget.myPlayerId)) {
      _hasSubmitted = false;
    }
  }

  void _checkTimer() {
    if (_hasSubmitted || !widget.gameState.isMyTurn(widget.myPlayerId) || widget.gameState.turnEndTime == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (widget.gameState.turnEndTime! - now <= 2500) {
      _hasSubmitted = true;
      if (widget.gameState.phase == GamePhase.trumpBidding) {
        context.read<GameBloc>().add(PlaceTrumpBidAttempt(_trumpBid, _trumpSuit));
      } else {
        context.read<GameBloc>().add(PlaceBidAttempt(_sliderBid));
      }
    }
  }

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    super.dispose();
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

      if (!_initializedSuggestedBid) {
        int suggestedBid = 1;
        final trumpSuit = gameState.currentTrumpSuit ?? 'Spade';
        for (final card in gameState.myHand) {
          if (card.suit == trumpSuit) {
            if (card.rank == 'A' || card.rank == 'K' || card.rank == 'Q') {
              suggestedBid++;
            }
          } else {
            if (card.rank == 'A') {
              suggestedBid++;
            }
          }
        }
        _sliderBid = suggestedBid;
        _initializedSuggestedBid = true;
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
        color: const Color(0xFF0F1B33).withValues(alpha: 0.9),
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
      padding: EdgeInsets.all(isCompact ? 8 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B33).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Place Your Bid',
              style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: isCompact ? 14 : 18),
            ),
            SizedBox(height: isCompact ? 2 : 8),
            Text(
              'Select how many tricks you can win',
              style: TextStyle(color: Colors.white70, fontSize: isCompact ? 11 : 13),
            ),
            SizedBox(height: isCompact ? 4 : 24),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: AppColors.gold),
                  onPressed: _sliderBid > minBid
                      ? () {
                          setState(() {
                            _sliderBid--;
                          });
                        }
                      : null,
                ),
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
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.gold),
                  onPressed: _sliderBid < 13
                      ? () {
                          setState(() {
                            _sliderBid++;
                          });
                        }
                      : null,
                ),
              ],
            ),
            SizedBox(height: isCompact ? 4 : 16),
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
                    padding: isCompact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: isCompact ? const Size(0, 32) : const Size(0, 42),
                  ),
                  onPressed: () {
                    context.read<GameBloc>().add(PlaceBidAttempt(_sliderBid));
                  },
                  icon: Icon(Icons.check, size: isCompact ? 16 : 18),
                  label: Text(
                    isCompact ? 'CONFIRM' : 'CONFIRM BID',
                    style: TextStyle(fontSize: isCompact ? 12 : 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrumpBidForm(GameState gameState, BuildContext context) {
    final highest = gameState.trumpBidState.highestBid;
    final validBids = List.generate(13 - 5 + 1, (i) => 5 + i).where((b) => b > highest).toList();

    final isCompact = MediaQuery.sizeOf(context).height < 500;

    return Container(
      width: isCompact ? 300 : 320,
      padding: EdgeInsets.all(isCompact ? 8 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B33).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBA68C8).withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: SingleChildScrollView(
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
            SizedBox(height: isCompact ? 8 : 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bid:', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: validBids.contains(_trumpBid) ? _trumpBid : (validBids.isNotEmpty ? validBids.first : null),
                  dropdownColor: const Color(0xFF0F1B33),
                  items: validBids.map((b) => DropdownMenuItem(value: b, child: Text('$b', style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _trumpBid = v);
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _trumpSuit,
                  dropdownColor: const Color(0xFF0F1B33),
                  items: ['Spade', 'Heart', 'Diamond', 'Club'].map((s) {
                    final String symbol = s == 'Spade' ? '♠' : s == 'Heart' ? '♥' : s == 'Diamond' ? '♦' : '♣';
                    final Color color = (s == 'Heart' || s == 'Diamond') ? AppColors.rankRed : Colors.white;
                    return DropdownMenuItem(
                      value: s,
                      child: Text(symbol, style: TextStyle(color: color, fontSize: 18)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _trumpSuit = v);
                  },
                ),
              ],
            ),
            SizedBox(height: isCompact ? 8 : 24),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emoticon Button with 5-second cooldown ring
// ─────────────────────────────────────────────────────────────────────────────

class _EmoticonButton extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onTap;

  const _EmoticonButton({required this.accentColor, required this.onTap});

  @override
  State<_EmoticonButton> createState() => _EmoticonButtonState();
}

class _EmoticonButtonState extends State<_EmoticonButton>
    with SingleTickerProviderStateMixin {
  static const _cooldownSeconds = 10;

  late final AnimationController _cooldown;
  bool _onCooldown = false;
  int _remaining = _cooldownSeconds;

  @override
  void initState() {
    super.initState();
    _cooldown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _cooldownSeconds),
    );
    _cooldown.addListener(_onTick);
    _cooldown.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {
          _onCooldown = false;
          _remaining = _cooldownSeconds;
        });
      }
    });
  }

  void _onTick() {
    final secs = (_cooldownSeconds * (1 - _cooldown.value)).ceil();
    if (secs != _remaining && mounted) {
      setState(() => _remaining = secs);
    }
  }

  void _handleTap() {
    if (_onCooldown) return;
    widget.onTap();
    setState(() {
      _onCooldown = true;
      _remaining = _cooldownSeconds;
    });
    _cooldown.forward(from: 0);
  }

  @override
  void dispose() {
    _cooldown.removeListener(_onTick);
    _cooldown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final enabled = !_onCooldown;

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cooldown ring
            if (_onCooldown)
              AnimatedBuilder(
                animation: _cooldown,
                builder: (_, __) => SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: 1 - _cooldown.value,
                    strokeWidth: 3.5,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.15),
                  ),
                ),
              ),

            // Button body
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled
                      ? accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _onCooldown
                    ? Text(
                        '$_remaining',
                        style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Text('😊', style: TextStyle(fontSize: 22)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
