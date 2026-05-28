import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../core/theme.dart';
import '../widgets/settings_sheet.dart';
import 'bidding_screen.dart';
import 'lobby_screen.dart';

// ─── Home Screen ──────────────────────────────────────────────────────────────

/// Landing screen — choose between solo bot game or multiplayer room.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fanController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  /// True when the user entered via "Play vs Bot" — skips the lobby and
  /// auto-starts the game as soon as the room is created.
  bool _isBotGame = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeepLink();
    });
  }

  void _checkDeepLink() {
    String? roomCode;
    
    // 1. Try Uri.base (highly reliable for Flutter Web)
    try {
      if (Uri.base.queryParameters.containsKey('room')) {
        roomCode = Uri.base.queryParameters['room'];
      }
    } catch (_) {}
    
    // 2. Fallback to defaultRouteName (for Mobile Deep Links)
    if (roomCode == null || roomCode.isEmpty) {
      final routeName = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      final uri = Uri.tryParse(routeName);
      if (uri != null && uri.queryParameters.containsKey('room')) {
        roomCode = uri.queryParameters['room'];
      }
    }

    if (roomCode != null && roomCode.isNotEmpty) {
      _openMultiplayerSheet(context, initialRoomCode: roomCode);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (state is GameLobby) {
          if (_isBotGame) {
            // Bot game: skip the lobby screen entirely — immediately send
            // START_GAME so the server fills seats with bots and begins.
            context.read<GameBloc>().add(const StartGameRequested());
          } else {
            // Multiplayer: show the lobby so friends can join.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LobbyScreen()),
              (route) => false,
            );
          }
        } else if (state is GameBidding && _isBotGame) {
          // Bot game started — go directly to the bidding screen.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const BiddingScreen()),
            (route) => false,
          );
        } else if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is GameLoading;
        return Scaffold(
          backgroundColor: const Color(0xFF080B14),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Layered background
              CustomPaint(painter: _BackgroundPainter()),

              // Main content
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _fadeController,
                  curve: Curves.easeOut,
                ),
                child: SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          children: [
                            const Spacer(flex: 2),

                            // ── Animated card fan hero ─────────────────────────
                            _buildCardFan(),

                            const SizedBox(height: 44),

                            // ── CALLBREAK branding ─────────────────────────────
                            _buildBranding(),

                            const Spacer(flex: 3),

                            // ── Mode selection tiles ───────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ModeTile(
                                      id: 'play_vs_bot_tile',
                                      label: 'Play vs Bot',
                                      subtitle: 'Solo · AI opponents',
                                      icon: Icons.smart_toy_outlined,
                                      accentColor: const Color(0xFF1E88E5),
                                      suitSymbols: '♠♣',
                                      onTap: isLoading ? null : () => _openBotSheet(context),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _ModeTile(
                                      id: 'multiplayer_tile',
                                      label: 'Multiplayer',
                                      subtitle: 'Play with friends',
                                      icon: Icons.group_outlined,
                                      accentColor: const Color(0xFF8E24AA),
                                      suitSymbols: '♥♦',
                                      onTap: isLoading ? null : () => _openMultiplayerSheet(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(flex: 1),
                            
                            // ── Bottom Action Bar ──────────────────────────────
                            _buildBottomActionBar(context),

                            if (isLoading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 32, top: 16),
                                child: CircularProgressIndicator(color: AppColors.gold),
                              )
                            else
                              const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Card fan hero ───────────────────────────────────────────────────────────

  Widget _buildCardFan() {
    const fanCards = [
      (rank: 'A', suit: '♠', isRed: false),
      (rank: 'K', suit: '♥', isRed: true),
      (rank: 'Q', suit: '♦', isRed: true),
      (rank: 'J', suit: '♣', isRed: false),
    ];
    const angles = [-0.42, -0.14, 0.14, 0.42];
    const offsets = [-68.0, -23.0, 23.0, 68.0];

    return SizedBox(
      height: 190,
      child: AnimatedBuilder(
        animation: _fanController,
        builder: (context, _) {
          final t = CurvedAnimation(
            parent: _fanController,
            curve: Curves.elasticOut,
          ).value.clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.bottomCenter,
            children: List.generate(fanCards.length, (i) {
              return Transform.translate(
                offset: Offset(offsets[i] * t, 0),
                child: Transform.rotate(
                  angle: angles[i] * t,
                  alignment: Alignment.bottomCenter,
                  child: _FanCard(
                    rank: fanCards[i].rank,
                    suit: fanCards[i].suit,
                    isRed: fanCards[i].isRed,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ── Branding ────────────────────────────────────────────────────────────────

  Widget _buildBranding() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 0.975 + 0.025 * _pulseController.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFFE082),
                Color(0xFFFFC107),
                Color(0xFFFF8F00),
                Color(0xFFFFC107),
                Color(0xFFFFE082),
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            ).createShader(bounds),
            child: const Text(
              'CALLBREAK',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 9,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.textSecondary.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'T H E  C L A S S I C  C A R D  G A M E',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.textSecondary.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ───────────────────────────────────────────────────────

  Widget _buildBottomActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.person_outline,
            label: 'Stats',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile & Stats coming soon!')),
              );
            },
          ),
          _ActionButton(
            icon: Icons.menu_book_rounded,
            label: 'Rules',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('How to Play coming soon!')),
              );
            },
          ),
          _ActionButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SettingsSheet(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Sheet launchers ─────────────────────────────────────────────────────────

  void _openBotSheet(BuildContext context) {
    setState(() => _isBotGame = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<GameBloc>(),
        child: const _BotGameSheet(),
      ),
    );
  }

  void _openMultiplayerSheet(BuildContext context, {String? initialRoomCode}) {
    setState(() => _isBotGame = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<GameBloc>(),
        child: _MultiplayerSheet(initialRoomCode: initialRoomCode),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deep space radial gradient
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.35),
        radius: 1.15,
        colors: [
          Color(0xFF1A1F35),
          Color(0xFF080B14),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle glowing arc at top (table edge suggestion)
    final arcPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -1.2),
        radius: 0.7,
        colors: [
          Color(0x18FFC107),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      arcPaint,
    );

    // Floating suit symbols (very subtle)
    final suits = ['♠', '♥', '♦', '♣', '♠', '♥', '♦'];
    final positions = [
      (0.08, 0.08),
      (0.82, 0.12),
      (0.04, 0.52),
      (0.88, 0.65),
      (0.52, 0.88),
      (0.22, 0.92),
      (0.70, 0.28),
    ];

    for (int i = 0; i < suits.length; i++) {
      final (x, y) = positions[i];
      final tp = TextPainter(
        text: TextSpan(
          text: suits[i],
          style: TextStyle(
            color: const Color(0x07FFFFFF),
            fontSize: 70 + (i % 3) * 15.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x * size.width, y * size.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Fan Card ─────────────────────────────────────────────────────────────────

/// Simplified playing card used in the animated hero fan.
class _FanCard extends StatelessWidget {
  final String rank;
  final String suit;
  final bool isRed;

  const _FanCard({required this.rank, required this.suit, required this.isRed});

  @override
  Widget build(BuildContext context) {
    final color = isRed ? AppColors.rankRed : AppColors.rankBlack;
    return Container(
      width: 72,
      height: 108,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: (isRed ? AppColors.rankRed : AppColors.spadeBlue)
                .withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rank,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1,
              ),
            ),
            Text(
              suit,
              style: TextStyle(color: color, fontSize: 13, height: 1),
            ),
            const Spacer(),
            Center(
              child: Text(
                suit,
                style: TextStyle(color: color, fontSize: 34),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ─── Mode Tile ────────────────────────────────────────────────────────────────

class _ModeTile extends StatefulWidget {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String suitSymbols;
  final VoidCallback? onTap;

  const _ModeTile({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.suitSymbols,
    this.onTap,
  });

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accentColor,
                widget.accentColor.withValues(alpha: 0.65),
                widget.accentColor.withValues(alpha: 0.40),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.30),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Large background suit symbols for texture
              Positioned(
                bottom: -10,
                right: -6,
                child: Text(
                  widget.suitSymbols,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.07),
                    fontSize: 80,
                    height: 1,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon badge
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),

                    const Spacer(),

                    // Label
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Tap arrow hint
              Positioned(
                bottom: 16,
                right: 16,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sheet Container ──────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final Widget child;

  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: math.max(MediaQuery.of(context).viewInsets.bottom, 24),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Bot Game Sheet ───────────────────────────────────────────────────────────

class _BotGameSheet extends StatefulWidget {
  const _BotGameSheet();

  @override
  State<_BotGameSheet> createState() => _BotGameSheetState();
}

class _BotGameSheetState extends State<_BotGameSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _rounds = 5;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameBlocState>(
      listener: (ctx, state) {
        // GameLobby navigation is handled exclusively by HomeScreen's
        // BlocConsumer (via pushAndRemoveUntil), which also removes this sheet.
        if (state is GameError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      },
      child: BlocBuilder<GameBloc, GameBlocState>(
        builder: (ctx, state) {
          final isLoading = state is GameLoading;
          return _SheetContainer(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.smart_toy_outlined,
                          color: Color(0xFF42A5F5),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Play vs Bot',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Solo game · AI fills all seats',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Name field ─────────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF42A5F5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E88E5)),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    textCapitalization: TextCapitalization.words,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),

                  // ── Rounds ─────────────────────────────────────────────
                  DropdownButtonFormField<int>(
                    initialValue: _rounds,
                    decoration: const InputDecoration(
                      labelText: 'Rounds',
                      prefixIcon: Icon(Icons.loop_outlined, color: Color(0xFF42A5F5)),
                    ),
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Round  ·  Quick')),
                      DropdownMenuItem(value: 3, child: Text('3 Rounds  ·  Short')),
                      DropdownMenuItem(value: 5, child: Text('5 Rounds  ·  Standard')),
                      DropdownMenuItem(value: 10, child: Text('10 Rounds  ·  Marathon')),
                    ],
                    onChanged: isLoading
                        ? null
                        : (v) {
                            if (v != null) setState(() => _rounds = v);
                          },
                  ),
                  const SizedBox(height: 28),

                  // ── Play button ────────────────────────────────────────
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF1E88E5),
                    ),
                    onPressed: isLoading ? null : _startBotGame,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      isLoading ? 'Starting…' : 'Quick Play',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startBotGame() {
    if (!_formKey.currentState!.validate()) return;
    context.read<GameBloc>().add(
          CreateRoomRequested(
            _nameController.text.trim(),
            totalRounds: _rounds,
          ),
        );
  }
}

// ─── Multiplayer Sheet ────────────────────────────────────────────────────────

class _MultiplayerSheet extends StatefulWidget {
  final String? initialRoomCode;
  const _MultiplayerSheet({this.initialRoomCode});

  @override
  State<_MultiplayerSheet> createState() => _MultiplayerSheetState();
}

class _MultiplayerSheetState extends State<_MultiplayerSheet> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  int _rounds = 5;
  int? _minBid;
  bool _greedPenalty = false;
  bool _allowCustomTrump = false;
  bool _isCreateMode = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoomCode != null && widget.initialRoomCode!.isNotEmpty) {
      _isCreateMode = false;
      _roomCodeController.text = widget.initialRoomCode!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameBlocState>(
      listener: (ctx, state) {
        // GameLobby navigation is handled exclusively by HomeScreen's
        // BlocConsumer (via pushAndRemoveUntil), which also removes this sheet.
        if (state is GameError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      },
      child: BlocBuilder<GameBloc, GameBlocState>(
        builder: (ctx, state) {
          final isLoading = state is GameLoading;
          return _SheetContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E24AA).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.group_outlined,
                        color: Color(0xFFBA68C8),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multiplayer',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Real-time game with friends',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Create / Join toggle ──────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToggleTab(
                          label: 'Create Room',
                          icon: Icons.add_circle_outline,
                          isActive: _isCreateMode,
                          onTap: () => setState(() => _isCreateMode = true),
                        ),
                      ),
                      Expanded(
                        child: _ToggleTab(
                          label: 'Join Room',
                          icon: Icons.login_outlined,
                          isActive: !_isCreateMode,
                          onTap: () => setState(() => _isCreateMode = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Animated form switch ──────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _isCreateMode
                      ? _CreateRoomForm(
                          key: const ValueKey('create'),
                          nameController: _nameController,
                          formKey: _createFormKey,
                          rounds: _rounds,
                          minBid: _minBid,
                          greedPenalty: _greedPenalty,
                          allowCustomTrump: _allowCustomTrump,
                          isLoading: isLoading,
                          onRoundsChanged: (v) => setState(() => _rounds = v),
                          onMinBidChanged: (v) => setState(() => _minBid = v),
                          onGreedPenaltyChanged: (v) => setState(() => _greedPenalty = v),
                          onAllowCustomTrumpChanged: (v) => setState(() => _allowCustomTrump = v),
                          onSubmit: _createRoom,
                        )
                      : _JoinRoomForm(
                          key: const ValueKey('join'),
                          nameController: _nameController,
                          roomCodeController: _roomCodeController,
                          formKey: _joinFormKey,
                          isLoading: isLoading,
                          onSubmit: _joinRoom,
                        ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );
  }

  void _createRoom() {
    if (!_createFormKey.currentState!.validate()) return;
    context.read<GameBloc>().add(
          CreateRoomRequested(
            _nameController.text.trim(),
            totalRounds: _rounds,
            minBid: _minBid,
            greedPenalty: _greedPenalty,
            allowCustomTrump: _allowCustomTrump,
          ),
        );
  }

  void _joinRoom() {
    if (!_joinFormKey.currentState!.validate()) return;
    final code = _roomCodeController.text.trim().toUpperCase();
    context
        .read<GameBloc>()
        .add(JoinRoomRequested(code, _nameController.text.trim()));
  }
}

// ─── Create Room Form ─────────────────────────────────────────────────────────

class _CreateRoomForm extends StatelessWidget {
  final TextEditingController nameController;
  final GlobalKey<FormState> formKey;
  final int rounds;
  final int? minBid;
  final bool greedPenalty;
  final bool allowCustomTrump;
  final bool isLoading;
  final ValueChanged<int> onRoundsChanged;
  final ValueChanged<int?> onMinBidChanged;
  final ValueChanged<bool> onGreedPenaltyChanged;
  final ValueChanged<bool> onAllowCustomTrumpChanged;
  final VoidCallback onSubmit;

  const _CreateRoomForm({
    super.key,
    required this.nameController,
    required this.formKey,
    required this.rounds,
    required this.minBid,
    required this.greedPenalty,
    required this.allowCustomTrump,
    required this.isLoading,
    required this.onRoundsChanged,
    required this.onMinBidChanged,
    required this.onGreedPenaltyChanged,
    required this.onAllowCustomTrumpChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFFBA68C8)),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            textCapitalization: TextCapitalization.words,
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: rounds,
            decoration: const InputDecoration(
              labelText: 'Match Duration',
              prefixIcon: Icon(Icons.loop_outlined, color: Color(0xFFBA68C8)),
            ),
            dropdownColor: AppColors.surfaceElevated,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 Round  ·  Quick')),
              DropdownMenuItem(value: 3, child: Text('3 Rounds  ·  Short')),
              DropdownMenuItem(value: 5, child: Text('5 Rounds  ·  Standard')),
              DropdownMenuItem(value: 10, child: Text('10 Rounds  ·  Marathon')),
            ],
            onChanged: isLoading
                ? null
                : (v) {
                    if (v != null) onRoundsChanged(v);
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: minBid,
            decoration: const InputDecoration(
              labelText: 'Minimum Bid',
              prefixIcon: Icon(Icons.arrow_upward_outlined, color: Color(0xFFBA68C8)),
            ),
            dropdownColor: AppColors.surfaceElevated,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            items: const [
              DropdownMenuItem(value: null, child: Text('None (Default)')),
              DropdownMenuItem(value: 1, child: Text('1')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
            ],
            onChanged: isLoading ? null : onMinBidChanged,
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Greed Penalty', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('0 points if player wins 2x their bid', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              value: greedPenalty,
              onChanged: isLoading ? null : onGreedPenaltyChanged,
              activeTrackColor: AppColors.gold.withValues(alpha: 0.5),
              activeThumbColor: AppColors.gold,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Dynamic Trump Rules', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Split deal & dynamic trump suit selection', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              value: allowCustomTrump,
              onChanged: isLoading ? null : onAllowCustomTrumpChanged,
              activeTrackColor: const Color(0xFFBA68C8).withValues(alpha: 0.5),
              activeThumbColor: const Color(0xFFBA68C8),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E24AA),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              shadowColor: const Color(0xFF8E24AA),
              elevation: 4,
            ),
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(
              isLoading ? 'Creating…' : 'Create Room',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Join Room Form ───────────────────────────────────────────────────────────

class _JoinRoomForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController roomCodeController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _JoinRoomForm({
    super.key,
    required this.nameController,
    required this.roomCodeController,
    required this.formKey,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFFBA68C8)),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            textCapitalization: TextCapitalization.words,
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: roomCodeController,
            decoration: const InputDecoration(
              labelText: 'Room Code',
              prefixIcon: Icon(Icons.key_outlined, color: AppColors.gold),
              hintText: 'e.g.  A B C D E',
            ),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              fontSize: 20,
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
              LengthLimitingTextInputFormatter(5),
            ],
            validator: (v) {
              if (v == null || v.trim().length != 5) {
                return 'Room code must be exactly 5 letters';
              }
              return null;
            },
            enabled: !isLoading,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E24AA),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              shadowColor: const Color(0xFF8E24AA),
              elevation: 4,
            ),
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.login_outlined),
            label: Text(
              isLoading ? 'Joining…' : 'Join Room',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Tab ───────────────────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8E24AA)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.textSecondary,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
