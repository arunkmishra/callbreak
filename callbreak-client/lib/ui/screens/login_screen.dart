import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';

/// Login screen shown to unauthenticated users.
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

  // Simulated online count (replace with real data if available)
  final int _playersOnline = 1248;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final redirectTo = kIsWeb
          ? (kReleaseMode ? 'https://arunkmishra.github.io/callbreak/' : Uri.base.origin)
          : 'io.supabase.callbreak://login-callback/';
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
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
      backgroundColor: const Color(0xFF0A0C0E),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen dark base ──────────────────────────────────────
          Container(color: const Color(0xFF080A0D)),

          // ── Casino image: full brightness left, fades right ────────────
          // ShaderMask with dstIn keeps pixels where gradient is opaque.
          // Gradient: fully opaque on left → transparent on right ≈ 55%.
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              heightFactor: 1.0,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.55, 1.0],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/casino_bg.png',
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity,
                ),
              ),
            ),
          ),

          // ── Right-side dark panel for readability ──────────────────────
          // Only darkens the right content half, leaving image area clean.
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.55,
              heightFactor: 1.0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Color(0xF0080A0D)],
                    stops: [0.0, 0.4],
                  ),
                ),
              ),
            ),
          ),


          // ── Players Online badge (top-right) ───────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: _PlayersOnlineBadge(count: _playersOnline),
          ),

          // ── Main content ───────────────────────────────────────────────
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _fadeController,
              curve: Curves.easeOut,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  if (isWide) {
                    return _buildWideLayout();
                  }
                  return _buildNarrowLayout();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide (landscape / tablet) layout ──────────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left spacer for background image
        const Expanded(flex: 4, child: SizedBox()),
        // Right: all UI content
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: _buildRightPanel(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow (portrait / phone) layout ──────────────────────────────────────
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildRightPanel(),
        ],
      ),
    );
  }

  // ── Shared right-panel content ─────────────────────────────────────────────
  Widget _buildRightPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown icon
        _buildCrown(),
        const SizedBox(height: 8),

        // CALLBREAK title
        _buildTitle(),
        const SizedBox(height: 8),

        // Tagline
        const Text(
          'PLAY.  BID.  OUTSMART.  WIN.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),

        // Feature icons row
        _buildFeatureIcons(),
        const SizedBox(height: 32),

        // Buttons
        if (_isLoading)
          const SizedBox(
            height: 56,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2.5,
              ),
            ),
          )
        else ...[
          // Google button
          _GoldGoogleButton(onTap: _signInWithGoogle),
          const SizedBox(height: 12),

          // Guest button
          _GuestButton(onTap: _signInAsGuest),
          const SizedBox(height: 14),

          // No signup note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 13, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(width: 6),
              Text(
                'No sign up required. Start playing instantly!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],

        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
            ),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
            ),
          ),
        ],

        const SizedBox(height: 28),

        // Bottom stats bar
        _buildStatsBar(),
      ],
    );
  }

  Widget _buildCrown() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.5 + 0.5 * _pulseController.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              const Color(0xFFFFE082).withValues(alpha: glow),
              const Color(0xFFFFC107),
              const Color(0xFFFF8F00),
            ],
          ).createShader(bounds),
          child: const Text('♛', style: TextStyle(fontSize: 36, color: Colors.white)),
        );
      },
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => child!,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFD54F),
            Color(0xFFFFC107),
            Color(0xFFFF8F00),
            Color(0xFFFFC107),
            Color(0xFFFFE082),
          ],
          stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ).createShader(bounds),
        child: const Text(
          'CALLBREAK',
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 10,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _FeatureIcon(
          icon: Icons.emoji_events_outlined,
          title: 'COMPETE',
          subtitle: 'Climb the leaderboards',
        ),
        _VerticalDivider(),
        const _FeatureIcon(
          icon: Icons.group_outlined,
          title: 'PLAY TOGETHER',
          subtitle: 'Challenge your friends',
        ),
        _VerticalDivider(),
        const _FeatureIcon(
          icon: Icons.shield_outlined,
          title: 'WIN REWARDS',
          subtitle: 'Earn and unlock more',
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _StatItem(icon: Icons.group, value: '500K+', label: 'PLAYERS'),
          _StatDivider(),
          const _StatItem(icon: Icons.military_tech, value: 'DAILY', label: 'TOURNAMENTS'),
          _StatDivider(),
          const _StatItem(icon: Icons.bar_chart, value: 'GLOBAL', label: 'LEADERBOARDS'),
        ],
      ),
    );
  }
}

// ─── Players Online Badge ──────────────────────────────────────────────────────

class _PlayersOnlineBadge extends StatelessWidget {
  final int count;
  const _PlayersOnlineBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF22C55E),
              boxShadow: [
                BoxShadow(
                  color: Color(0x6622C55E),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatCount(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const Text(
                'PLAYERS ONLINE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return '$n';
  }
}

// ─── Feature Icon ──────────────────────────────────────────────────────────────

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureIcon({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 26),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

// ─── Gold Google Button ───────────────────────────────────────────────────────

class _GoldGoogleButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GoldGoogleButton({required this.onTap});

  @override
  State<_GoldGoogleButton> createState() => _GoldGoogleButtonState();
}

class _GoldGoogleButtonState extends State<_GoldGoogleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
        scale: _scale,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD54F), Color(0xFFFFC107), Color(0xFFFFB300)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC107).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google multicolour "G"
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  color: Color(0xFF1A0F00),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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

// ─── Guest Button ─────────────────────────────────────────────────────────────

class _GuestButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GuestButton({required this.onTap});

  @override
  State<_GuestButton> createState() => _GuestButtonState();
}

class _GuestButtonState extends State<_GuestButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
        scale: _scale,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Continue as Guest',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats Bar Items ──────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 9,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
