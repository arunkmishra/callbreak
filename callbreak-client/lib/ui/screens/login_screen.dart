import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';

/// Login screen shown to unauthenticated users.
///
/// Uses Supabase Google OAuth. On success, Supabase stores the session
/// locally, and the [_AuthGate] in main.dart automatically navigates
/// the user to [HomeScreen].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _fanController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _fanController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // On web: redirect back to the current page URL (e.g. http://localhost:52345)
      // On mobile: use the custom deep link scheme
      final redirectTo = kIsWeb
          ? (kReleaseMode ? 'https://arunkmishra.github.io/callbreak/' : Uri.base.origin)
          : 'io.supabase.callbreak://login-callback/';

      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      // Auth state listener in main.dart handles navigation after success.
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Guest login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          CustomPaint(painter: _LoginBackgroundPainter()),

          // Content
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _fadeController,
              curve: Curves.easeOut,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Animated card fan ──────────────────────────
                      _buildCardFan(),
                      const SizedBox(height: 12),

                      // ── Branding ───────────────────────────────────
                      _buildBranding(),
                      const SizedBox(height: 20),

                      // ── Sign In Card ───────────────────────────────
                      _buildSignInCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      height: 120,
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
                  child: _LoginFanCard(
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
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'T H E  C L A S S I C  C A R D  G A M E',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFC107).withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC107).withValues(alpha: 0.08),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Sign in to play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Google Sign In Button
            _isLoading
                ? const SizedBox(
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _GoogleSignInButton(onTap: _signInWithGoogle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _signInAsGuest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Guest Login', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 16),
            const Text(
              'Save your progress, join leaderboards,\nand challenge friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Google Sign In Button ────────────────────────────────────────────────────

class _GoogleSignInButton extends StatefulWidget {
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.onTap});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google "G" icon using a simple colored shape
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Text(
                  'G',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Google Login',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.35),
        radius: 1.15,
        colors: [Color(0xFF1A1F35), Color(0xFF080B14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final arcPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -1.2),
        radius: 0.7,
        colors: [Color(0x18FFC107), Colors.transparent],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.4), arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Fan Card ─────────────────────────────────────────────────────────────────

class _LoginFanCard extends StatelessWidget {
  final String rank;
  final String suit;
  final bool isRed;

  const _LoginFanCard(
      {required this.rank, required this.suit, required this.isRed});

  @override
  Widget build(BuildContext context) {
    final color = isRed ? AppColors.rankRed : AppColors.rankBlack;
    return Container(
      width: 64,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: (isRed ? AppColors.rankRed : AppColors.spadeBlue)
                .withValues(alpha: 0.15),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rank,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1)),
            Text(suit,
                style: TextStyle(color: color, fontSize: 11, height: 1)),
            const Spacer(),
            Center(
                child: Text(suit,
                    style: TextStyle(color: color, fontSize: 28))),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
