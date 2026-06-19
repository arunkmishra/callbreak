import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../bloc/game_state.dart';
import '../../core/audio_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tier_system.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../data/services/heartbeat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/game_invite_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/ad_service.dart';
import 'friends_screen.dart';
import 'game_history_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';
import 'rank_screen.dart';
import 'store_screen.dart';
import '../../bloc/store_bloc.dart';
import '../../bloc/store_state.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

// ─── Home Screen ──────────────────────────────────────────────────────────────


/// Returns a simulated "players online" count based on time of day.
/// Oscillates 150–450 using a sine curve keyed to IST hour, with ±15 jitter.
int getSimulatedOnlineCount() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = now.hour + now.minute / 60.0;
  // Peak at ~21:00 IST (evening), trough at ~05:00 IST (dawn)
  final sinValue = math.sin((hour - 5) * math.pi / 16.0);
  final base = (300 + 150 * sinValue).round(); // 150..450 range
  final jitter = (math.Random().nextInt(31) - 15); // -15..+15
  return (base + jitter).clamp(100, 500);
}

class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fanController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  RealtimeChannel? _invitesChannel;
  bool _isBotGame = false;

  UserProfile? _profile;
  List<UserProfile> _topPlayers = [];
  int? _myRank;
  
  List<Friendship> _friends = [];
  Map<String, String> _onlineUserStatuses = {};
  Timer? _onlineTimer;

  int _selectedNavIndex = 2;

  int _simulatedOnlineCount = getSimulatedOnlineCount();
  Timer? _counterTimer;
  
  bool _hasInternet = true;
  StreamSubscription<InternetStatus>? _internetSubscription;

  @override
  void initState() {
    super.initState();

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
    
    _fetchOnlineUsers();
    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchOnlineUsers();
    });

    _counterTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _simulatedOnlineCount = getSimulatedOnlineCount());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeepLink();
      _listenForInvites();
      _loadData();
    });

    InternetConnection().hasInternetAccess.then((hasInternet) {
      if (mounted && _hasInternet != hasInternet) {
        setState(() => _hasInternet = hasInternet);
      }
    });

    _internetSubscription = InternetConnection().onStatusChange.listen((status) {
      final hasInternet = status == InternetStatus.connected;
      if (mounted && _hasInternet != hasInternet) {
        setState(() => _hasInternet = hasInternet);
      }
    });
  }

  Future<void> _fetchOnlineUsers() async {
    try {
      final statuses = await HeartbeatService.getOnlineUsers();
      if (!mounted) return;
      setState(() {
        _onlineUserStatuses = statuses;
        _sortFriendsList();
      });
    } catch (_) {}
  }


  void _sortFriendsList() {
    _friends.sort((a, b) {
      if (a.profile == null && b.profile == null) return 0;
      if (a.profile == null) return 1;
      if (b.profile == null) return -1;
      
      final statusA = _onlineUserStatuses[a.profile!.id] ?? 'offline';
      final statusB = _onlineUserStatuses[b.profile!.id] ?? 'offline';
      
      int weight(String s) {
        if (s == 'available') return 2;
        if (s == 'playing') return 1;
        return 0;
      }
      
      final wA = weight(statusA);
      final wB = weight(statusB);
      if (wA != wB) return wB.compareTo(wA);
      return a.profile!.username.toLowerCase().compareTo(b.profile!.username.toLowerCase());
    });
  }

  Future<void> _loadData() async {
    try {
      final profile = await SupabaseRepository().getMyProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}

    try {
      final top = await SupabaseRepository().getLeaderboard();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      int? rank;
      if (userId != null) {
        final idx = top.indexWhere((e) => e.id == userId);
        if (idx != -1) rank = idx + 1;
      }
      if (mounted) {
        setState(() {
          _topPlayers = top.take(3).toList();
          _myRank = rank;
        });
      }
    } catch (_) {}

    try {
      final friends = await SupabaseRepository().getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _sortFriendsList();
        });
      }
    } catch (_) {}
  }

  Future<void> _listenForInvites() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _invitesChannel = Supabase.instance.client.channel('system_invites');
    _invitesChannel!
        .onBroadcast(
          event: 'invite',
          callback: (payload) {
            if (HeartbeatService.currentStatus != 'available') return;
            final inviteeId = payload['inviteeId'] as String?;
            if (inviteeId != userId) return;
            final roomId = payload['roomId'] as String?;
            final inviterName = payload['inviterName'] as String?;
            if (roomId != null && inviterName != null) {
              _showInviteDialog(inviterName, roomId);
            }
          },
        )
        .subscribe();
  }

  void _showInviteDialog(String inviterName, String roomId) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => GameInviteDialog(
        inviterName: inviterName,
        roomId: roomId,
        onDecline: () {
          Navigator.of(ctx).pop();
        },
        onAccept: () async {
          Navigator.of(ctx).pop();
          if (!await _checkInternetConnection(context)) return;
          final profile = await SupabaseRepository().getMyProfile();
          final playerName = profile?.username ?? 'Player';
          if (mounted) {
            context.read<GameBloc>().add(JoinRoomRequested(roomId, playerName));
          }
        },
      ),
    );
  }

  void _checkDeepLink() {
    String? roomCode;
    try {
      if (Uri.base.queryParameters.containsKey('room')) {
        roomCode = Uri.base.queryParameters['room'];
      }
    } catch (_) {}
    if (roomCode == null || roomCode.isEmpty) {
      final routeName =
          WidgetsBinding.instance.platformDispatcher.defaultRouteName;
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
    _internetSubscription?.cancel();
    _onlineTimer?.cancel();
    _invitesChannel?.unsubscribe();
    _fadeController.dispose();
    _fanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Quick Play: 3-round bot game, no sheet ────────────────────────────────

  Future<bool> _checkInternetConnection(BuildContext context) async {
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      if (!context.mounted) return false;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          title: const Text('No Internet Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'You need an internet connection to play the game. Please check your network and try again.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _startPlayOnline(BuildContext context) async {
    if (!await _checkInternetConnection(context)) return;
    if (!context.mounted) return;
    AudioService.preload();
    setState(() => _isBotGame = false);
    final username = _profile?.username ?? 'Player';
    context.read<GameBloc>().add(FindMatchRequested(username));
  }

  Future<void> _startQuickPlay(BuildContext context) async {
    if (!await _checkInternetConnection(context)) return;
    if (!context.mounted) return;
    AudioService.preload();
    setState(() => _isBotGame = true);
    final username = _profile?.username ?? 'Player';
    context.read<GameBloc>().add(CreateRoomRequested(username, totalRounds: 3));
  }

  Future<void> _openPracticeSheet(BuildContext context) async {
    if (!await _checkInternetConnection(context)) return;
    if (!context.mounted) return;
    AudioService.preload();
    setState(() => _isBotGame = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<GameBloc>(),
        child: _BotGameSheet(defaultUsername: _profile?.username ?? 'Player'),
      ),
    );
  }

  Future<void> _openMultiplayerSheet(BuildContext context, {String? initialRoomCode}) async {
    if (!await _checkInternetConnection(context)) return;
    if (!context.mounted) return;
    AudioService.preload();
    setState(() => _isBotGame = false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => BlocProvider.value(
        value: context.read<GameBloc>(),
        child: _MultiplayerSheet(
          initialRoomCode: initialRoomCode,
          defaultUsername: _profile?.username ?? 'Player',
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Text('$feature — Coming Soon!',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (state is GameMatchmaking) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LobbyScreen()),
            (route) => false,
          );
        } else if (state is GameLobby) {
          if (_isBotGame) {
            context.read<GameBloc>().add(const StartGameRequested());
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LobbyScreen()),
              (route) => false,
            );
          }
        } else if (state is GameBidding ||
            state is GameActive ||
            state is GameRoundOver ||
            state is GameOver) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const GameScreen()),
            (route) => false,
          );
        } else if (state is GameError) {
          if (state.message == 'FORCE_UPDATE_REQUIRED') {
            showDialog(
              context: context,
              barrierDismissible: false,
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is GameLoading;
        return Scaffold(
          backgroundColor: const Color(0xFF080B14),
          body: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _BackgroundPainter()),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _fadeController,
                  curve: Curves.easeOut,
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      if (!_hasInternet)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: AppColors.errorRed,
                          child: const Text(
                            '⚠️ No Internet Connection',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Expanded(
                        child: _buildDashboard(context, isLoading),
                      ),
                      _buildBottomNav(context),
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

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Widget _buildDashboard(BuildContext context, bool isLoading) {
    return Column(
      children: [
        _buildTopBar(context),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Center (now Left) column
              Expanded(
                flex: 73,
                child: _buildCenterColumn(context, isLoading),
              ),
              // Right column
              Expanded(
                flex: 27,
                child: _buildRightColumn(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final username = _profile?.username ?? 'Player';
    final wins = _profile?.totalWins ?? 0;
    final games = _profile?.totalGames ?? 0;
    // Derive mock XP from wins so it's somewhat real
    final xp = (wins * 87 + games * 12).clamp(0, 99999);
    final xpMax = ((xp ~/ 5000) + 1) * 5000;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // ── User avatar + info ─────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Row(
              children: [
                // Avatar
                UserAvatar(
                  avatarUrl: _profile?.avatarUrl,
                  username: username,
                  radius: 21,
                  backgroundColor: const Color(0xFF7C3AED),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined,
                            color: Colors.white38, size: 13),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lv. ${(wins ~/ 3 + 1).clamp(1, 99)}',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (xp % 5000) / xpMax.clamp(1, 5000),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppColors.gold),
                                  minHeight: 4,
                                ),
                              ),
                              Text(
                                '$xp / $xpMax',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── CALLBREAK title center ─────────────────────────────────
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => child!,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [
                            Color(0xFFFFE082),
                            Color(0xFFFFC107),
                            Color(0xFFFF8F00),
                            Color(0xFFFFC107),
                            Color(0xFFFFE082),
                          ],
                          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                        ).createShader(b),
                        child: const Text(
                          'CALLBREAK',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                      const Text(
                        'PLAY.  BID.  OUTSMART.  WIN.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '♠  ♥  ♦  ♣',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right: currencies + icons ──────────────────────────────
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                BlocBuilder<StoreBloc, StoreState>(
                  builder: (context, state) {
                    return _CurrencyBadge(
                      icon: Icons.monetization_on_rounded,
                      iconColor: const Color(0xFFFFD700),
                      value: '${state.coinBalance}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StoreScreen()),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _TopBarIcon(
                  icon: Icons.notifications_outlined,
                  badge: 0,
                  onTap: () => _showComingSoon(context, 'Notifications'),
                ),
                const SizedBox(width: 4),
                _TopBarIcon(
                  icon: Icons.settings_outlined,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: context.read<SettingsCubit>(),
                      child: const SettingsDialog(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left Column: Rank + Daily Chest ───────────────────────────────────────

  Widget _buildLeftColumn(BuildContext context) {
    final wins = _profile?.totalWins ?? 0;
    final rp = _profile?.rankPoints ?? 1000;
    final rankLabel = TierSystem.getTierName(rp);
    final rankColor = TierSystem.getTierColor(rp);
    final rankIcon = TierSystem.getTierIcon(rp);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      child: Column(
        children: [
          // CURRENT RANK card
          Expanded(
            flex: 5,
            child: _DashCard(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CURRENT RANK',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              rankColor.withValues(alpha: 0.3),
                              rankColor.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                              color: rankColor.withValues(alpha: 0.5),
                              width: 1.5),
                        ),
                        child: Center(
                          child: Icon(rankIcon,
                              size: 32, color: rankColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        rankLabel,
                        style: TextStyle(
                          color: rankColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        '$rp RP',
                        style: TextStyle(
                          color: rankColor.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        '$wins / ${((wins ~/ 100) + 1) * 100}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (wins % 100) / 100.0,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.gold),
                          minHeight: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // DAILY CHEST card
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () => _showComingSoon(context, 'Daily Chest'),
              child: _DashCard(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'DAILY CHEST',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 38,
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'COMING SOON',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(width: 4),
                          Text(
                            'Spins: 1 / 3',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
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

  // ── Center Column ─────────────────────────────────────────────────────────

  Widget _buildCenterColumn(BuildContext context, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        children: [
          // QUICK PLAY banner
          Expanded(
            flex: 5,
            child: _buildQuickPlayBanner(context, isLoading),
          ),
          const SizedBox(height: 8),
          // 4 mode tiles row
          Expanded(
            flex: 5,
            child: _buildModeTiles(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPlayBanner(BuildContext context, bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2149), Color(0xFF0A1535), Color(0xFF061128)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Card fan visual
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildCardFanMini(),
            ),
          ),
          // Text + button
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 16, 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // QUICK PLAY Title
                          const Text(
                            'QUICK PLAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          // Message on the right
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Play a fast 3-round match\nagainst AI bots',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),

                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // PLAY NOW button
                      GestureDetector(
                        onTap: isLoading ? null : () => _startQuickPlay(context),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else ...[
                                const Text(
                                  'PLAY NOW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildModeTiles(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeTile(
            icon: Icons.public,
            iconColor: const Color(0xFF60A5FA),
            bgColor: const Color(0xFF0F172A),
            borderColor: const Color(0xFF60A5FA),
            title: 'PLAY ONLINE',
            subtitle: 'Compete with players\naround the world',
            badge: 'Play Now',
            badgeColor: const Color(0xFF60A5FA),
            comingSoon: false,
            onlineCount: _simulatedOnlineCount,
            onTap: () => _startPlayOnline(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeTile(
            icon: Icons.group_add_outlined,
            iconColor: const Color(0xFF34D399),
            bgColor: const Color(0xFF061511),
            borderColor: const Color(0xFF34D399),
            title: 'PRIVATE ROOM',
            subtitle: 'Create a room and\nplay with friends',
            badge: 'Create Now',
            badgeColor: const Color(0xFF34D399),
            comingSoon: false,
            onTap: () => _openMultiplayerSheet(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeTile(
            icon: Icons.track_changes_outlined,
            iconColor: const Color(0xFFFB923C),
            bgColor: const Color(0xFF170B00),
            borderColor: const Color(0xFFFB923C),
            title: 'PRACTICE',
            subtitle: 'Play vs AI and\nimprove your skills',
            badge: 'Play Now',
            badgeColor: const Color(0xFFFB923C),
            comingSoon: false,
            onTap: () => _openPracticeSheet(context),
          ),
        ),
      ],
    );
  }

  // ── Right Column ──────────────────────────────────────────────────────────

  Widget _buildRightColumn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
      child: Column(
        children: [
          // FRIENDS LIST
          Expanded(
            flex: 4,
            child: _DashCard(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, color: Color(0xFF60A5FA), size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'FRIENDS',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FriendsScreen())),
                          child: const Text(
                            'VIEW ALL',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_friends.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No friends yet',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ),
                      )
                    else
                      ..._friends.map((f) {
                        if (f.profile == null) return const SizedBox.shrink();
                        final status = _onlineUserStatuses[f.profile!.id] ?? 'offline';
                        final isOnline = status == 'available' || status == 'playing';
                        return _FriendRow(
                          name: f.profile!.username,
                          status: status == 'playing' ? 'Playing' : (isOnline ? 'Online' : 'Offline'),
                          isOnline: isOnline,
                          avatarUrl: f.profile!.avatarUrl,
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // LEADERBOARD
          Expanded(
            flex: 5,
            child: _DashCard(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'LEADERBOARD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen()),
                          ),
                          child: const Text(
                            'VIEW ALL',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'TOP PLAYERS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Top 3 entries
                    if (_topPlayers.isEmpty) ...const [
                      _LeaderboardRow(rank: 1, name: 'PlayerX', score: 2450),
                      _LeaderboardRow(rank: 2, name: 'PlayerY', score: 2421),
                      _LeaderboardRow(rank: 3, name: 'PlayerZ', score: 2387),
                    ] else
                      for (int i = 0; i < _topPlayers.length; i++)
                        _LeaderboardRow(
                          rank: i + 1,
                          name: _topPlayers[i].username,
                          score: _topPlayers[i].totalWins,
                        ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 6),
                    // My entry
                    _LeaderboardRow(
                      rank: _myRank ?? 23,
                      name: _profile?.username ?? 'Ak Sir',
                      score: _profile?.totalWins ?? 1895,
                      isMe: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    final onlineFriendsCount = _friends.where((f) => f.profile != null && _onlineUserStatuses.containsKey(f.profile!.id)).length;

    const items = [
      (icon: Icons.people_outline, label: 'FRIENDS'),
      (icon: Icons.emoji_events_outlined, label: 'RANK'),
      (icon: Icons.home_rounded, label: 'HOME'),
      (icon: Icons.history, label: 'HISTORY'),
      (icon: Icons.storefront_rounded, label: 'STORE'),
    ];

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF060912),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isActive = _selectedNavIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                setState(() => _selectedNavIndex = i);
                if (item.label == 'HOME') {
                  // Do nothing, stay on home
                } else if (item.label == 'RANK') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RankScreen()),
                  );
                  if (mounted) setState(() => _selectedNavIndex = 2);
                } else if (item.label == 'FRIENDS') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  );
                  if (mounted) setState(() => _selectedNavIndex = 2);
                } else if (item.label == 'HISTORY') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GameHistoryScreen()),
                  );
                  if (mounted) setState(() => _selectedNavIndex = 2);
                } else if (item.label == 'STORE') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoreScreen()),
                  );
                  if (mounted) setState(() => _selectedNavIndex = 2);
                } else {
                  _showComingSoon(context, item.label);
                  if (mounted) setState(() => _selectedNavIndex = 2);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isActive)
                    Container(
                      width: 32,
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 6),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        item.icon,
                        color: isActive
                            ? const Color(0xFF2563EB)
                            : Colors.white38,
                        size: 20,
                      ),
                      if (item.label == 'FRIENDS' && onlineFriendsCount > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('$onlineFriendsCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      color:
                          isActive ? const Color(0xFF2563EB) : Colors.white30,
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Mini card fan for Quick Play banner ───────────────────────────────────

  Widget _buildCardFanMini() {
    const fanCards = [
      (rank: 'K', suit: '♠', isRed: false),
      (rank: 'Q', suit: '♠', isRed: false),
      (rank: 'J', suit: '♠', isRed: false),
      (rank: 'A', suit: '♠', isRed: false),
    ];
    const angles = [-0.35, -0.12, 0.12, 0.35];
    const offsets = [-40.0, -13.0, 13.0, 40.0];

    return AnimatedBuilder(
      animation: _fanController,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _fanController,
          curve: Curves.elasticOut,
        ).value.clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
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
                  width: 55,
                  height: 80,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Rank helpers ──────────────────────────────────────────────────────────

}

// ─── Shared Card Widget ──────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final Widget child;
  const _DashCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1729),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E3A5F).withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Currency Badge ──────────────────────────────────────────────────────────

class _CurrencyBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final VoidCallback? onTap;
  const _CurrencyBadge(
      {required this.icon, required this.iconColor, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.add_circle_outline,
                color: Colors.white.withValues(alpha: 0.4), size: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar Icon ─────────────────────────────────────────────────────────────

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final VoidCallback onTap;
  const _TopBarIcon({required this.icon, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: Colors.white60, size: 18),
          ),
          if (badge != null)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.errorRed,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Mode Tile ────────────────────────────────────────────────────────────────

class _ModeTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool comingSoon;
  final VoidCallback onTap;
  final int? onlineCount;

  const _ModeTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.comingSoon,
    required this.onTap,
    this.onlineCount,
  });

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.borderColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: widget.iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.iconColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Icon(widget.icon, color: widget.iconColor, size: 28),
                            ),
                            const SizedBox(width: 12),
                            // Title & Subtitle
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                ),
                                if (widget.onlineCount != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF22C55E),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x6622C55E),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.onlineCount} Players Online',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.55),
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        // Badge / action
              Row(
                children: [
                  if (widget.comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          widget.badge,
                          style: TextStyle(
                            color: widget.badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_forward,
                            color: widget.badgeColor, size: 12),
                      ],
                    ),
                ],
              ),
            ],
          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Friend Row ───────────────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  final String name;
  final String status;
  final bool isOnline;
  final String? avatarUrl;
  
  const _FriendRow({
    required this.name,
    required this.status,
    required this.isOnline,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xFF22C55E) : Colors.white38,
              boxShadow: isOnline ? [
                const BoxShadow(
                  color: Color(0x6622C55E),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
          const SizedBox(width: 6),
          UserAvatar(
            avatarUrl: avatarUrl,
            username: name,
            radius: 8,
            backgroundColor: const Color(0xFF374151),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isOnline ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: isOnline ? const Color(0xFF60A5FA) : Colors.white38,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard Row (compact) ────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final bool isMe;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.score,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF1E3A5F).withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(7),
        border: isMe
            ? Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 13))
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          if (isMe)
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 12)
          else
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.gold, size: 12),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight:
                    isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fan Card ─────────────────────────────────────────────────────────────────

class _FanCard extends StatelessWidget {
  final String rank;
  final String suit;
  final bool isRed;
  final double width;
  final double height;

  const _FanCard({
    required this.rank,
    required this.suit,
    required this.isRed,
    this.width = 72,
    this.height = 108,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? AppColors.rankRed : AppColors.rankBlack;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                  fontSize: width * 0.22,
                  height: 1,
                )),
            Text(suit,
                style:
                    TextStyle(color: color, fontSize: width * 0.16, height: 1)),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(suit,
                      style: TextStyle(color: color, fontSize: width * 0.38, height: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.35),
        radius: 1.15,
        colors: [Color(0xFF0D1729), Color(0xFF080B14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final arcPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -1.2),
        radius: 0.7,
        colors: [Color(0x12FFC107), Colors.transparent],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.4), arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Sheet Container ──────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final Widget child;
  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
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
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: math.max(bottomInset, 24),
          ),
          physics: isLandscape
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
      ),
    );
  }
}

// ─── Bot Game Sheet (Practice) ────────────────────────────────────────────────

class _BotGameSheet extends StatefulWidget {
  final String defaultUsername;
  const _BotGameSheet({this.defaultUsername = 'Player'});

  @override
  State<_BotGameSheet> createState() => _BotGameSheetState();
}

class _BotGameSheetState extends State<_BotGameSheet> {
  final _formKey = GlobalKey<FormState>();
  int _rounds = 5;
  int? _minBid = 1;
  bool _greedPenalty = false;
  bool _allowCustomTrump = false;
  late String _username;

  @override
  void initState() {
    super.initState();
    _username = widget.defaultUsername;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameBlocState>(
      listener: (ctx, state) {
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
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB923C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.track_changes_outlined,
                            color: Color(0xFFFB923C), size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Practice Mode',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Play vs AI and improve your skills',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Section: GAME SETTINGS
                  const Text(
                    'GAME SETTINGS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _SettingsRow(
                    icon: Icons.sync_rounded,
                    iconColor: const Color(0xFFFB923C), // Orange
                    title: 'Match Duration',
                    subtitle: 'Choose number of rounds and game type',
                    trailing: _CustomDropdown<int>(
                      value: _rounds,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 Round · Quick')),
                        DropdownMenuItem(value: 3, child: Text('3 Rounds · Short')),
                        DropdownMenuItem(value: 5, child: Text('5 Rounds · Standard')),
                        DropdownMenuItem(value: 10, child: Text('10 Rounds · Marathon')),
                      ],
                      onChanged: isLoading
                          ? null
                          : (v) {
                              if (v != null) setState(() => _rounds = v);
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _SettingsRow(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFFFB923C), // Orange
                    title: 'Minimum Bid',
                    subtitle: 'Set minimum bid required to play',
                    trailing: _CustomDropdown<int?>(
                      value: _minBid,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('None')),
                        DropdownMenuItem(value: 1, child: Text('1 Bid (Default)')),
                        DropdownMenuItem(value: 2, child: Text('2 Bids')),
                        DropdownMenuItem(value: 3, child: Text('3 Bids')),
                      ],
                      onChanged: isLoading
                          ? null
                          : (v) {
                              setState(() => _minBid = v);
                            },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Section: ADVANCED OPTIONS
                  const Text(
                    'ADVANCED OPTIONS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _SettingsRow(
                    icon: Icons.balance_rounded,
                    iconColor: const Color(0xFF9333EA), // Purple
                    title: 'Greed Penalty',
                    subtitle: '0 points if player wins 2x their bid',
                    trailing: Switch(
                      value: _greedPenalty,
                      onChanged: isLoading
                          ? null
                          : (v) {
                              setState(() => _greedPenalty = v);
                            },
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFFFB923C), // Orange track
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _SettingsRow(
                    icon: Icons.style_rounded,
                    iconColor: const Color(0xFF9333EA), // Purple
                    title: 'Dynamic Trump Rules',
                    subtitle: 'Split deal & dynamic trump suit selection',
                    trailing: Switch(
                      value: _allowCustomTrump,
                      onChanged: isLoading
                          ? null
                          : (v) {
                              setState(() => _allowCustomTrump = v);
                            },
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFFFB923C), // Orange track
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Start button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFB923C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                      shadowColor: const Color(0xFFFB923C),
                    ),
                    onPressed: isLoading ? null : _startGame,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      isLoading ? 'Starting…' : 'Start Practice',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
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

  void _startGame() {
    if (!_formKey.currentState!.validate()) return;
    context.read<GameBloc>().add(CreateRoomRequested(
          _username,
          totalRounds: _rounds,
          minBid: _minBid,
          greedPenalty: _greedPenalty,
          allowCustomTrump: _allowCustomTrump,
        ));
  }
}

// ─── Multiplayer Modal Dialog ───────────────────────────────────────────────

class _MultiplayerSheet extends StatefulWidget {
  final String? initialRoomCode;
  final String defaultUsername;

  const _MultiplayerSheet(
      {this.initialRoomCode, this.defaultUsername = 'Player'});

  @override
  State<_MultiplayerSheet> createState() => _MultiplayerSheetState();
}

class _MultiplayerSheetState extends State<_MultiplayerSheet> {
  final _roomCodeController = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  int _rounds = 5;
  int? _minBid = 1;
  bool _greedPenalty = false;
  bool _allowCustomTrump = false;
  bool _isCreateMode = true;
  late String _username;

  @override
  void initState() {
    super.initState();
    _username = widget.defaultUsername;
    if (widget.initialRoomCode != null &&
        widget.initialRoomCode!.isNotEmpty) {
      _isCreateMode = false;
      _roomCodeController.text = widget.initialRoomCode!;
    }
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameBlocState>(
      listener: (ctx, state) {
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
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 520,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111620), // Dark modal background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Area
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF4ADE80), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded,
                                color: Color(0xFF4ADE80), size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCreateMode ? 'CREATE PRIVATE ROOM' : 'JOIN PRIVATE ROOM',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Play with friends in real-time',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Icon(Icons.close, color: Colors.white70, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(color: Colors.white10, height: 1),

                    // Scrollable content area
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Toggle Tabs
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D111A), // Darker inset
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ToggleTab(
                                      label: 'Create Room',
                                      icon: Icons.group_add_outlined,
                                      isActive: _isCreateMode,
                                      onTap: () =>
                                          setState(() => _isCreateMode = true),
                                    ),
                                  ),
                                  Expanded(
                                    child: _ToggleTab(
                                      label: 'Join Room',
                                      icon: Icons.login_outlined,
                                      isActive: !_isCreateMode,
                                      onTap: () =>
                                          setState(() => _isCreateMode = false),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              child: _isCreateMode
                                  ? _CreateRoomForm(
                                      key: const ValueKey('create'),
                                      formKey: _createFormKey,
                                      rounds: _rounds,
                                      minBid: _minBid,
                                      greedPenalty: _greedPenalty,
                                      allowCustomTrump: _allowCustomTrump,
                                      isLoading: isLoading,
                                      onRoundsChanged: (v) =>
                                          setState(() => _rounds = v),
                                      onMinBidChanged: (v) =>
                                          setState(() => _minBid = v),
                                      onGreedPenaltyChanged: (v) =>
                                          setState(() => _greedPenalty = v),
                                      onAllowCustomTrumpChanged: (v) =>
                                          setState(() => _allowCustomTrump = v),
                                      onSubmit: _createRoom,
                                    )
                                  : _JoinRoomForm(
                                      key: const ValueKey('join'),
                                      roomCodeController: _roomCodeController,
                                      formKey: _joinFormKey,
                                      isLoading: isLoading,
                                      onSubmit: _joinRoom,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _createRoom() {
    if (!_createFormKey.currentState!.validate()) return;
    context.read<GameBloc>().add(CreateRoomRequested(
          _username,
          totalRounds: _rounds,
          minBid: _minBid,
          greedPenalty: _greedPenalty,
          allowCustomTrump: _allowCustomTrump,
        ));
  }

  void _joinRoom() {
    if (!_joinFormKey.currentState!.validate()) return;
    final code = _roomCodeController.text.trim().toUpperCase();
    context.read<GameBloc>().add(JoinRoomRequested(code, _username));
  }
}

// ─── Create Room Form ─────────────────────────────────────────────────────────

class _CreateRoomForm extends StatelessWidget {
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
          // Section: GAME SETTINGS
          const Text(
            'GAME SETTINGS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsRow(
            icon: Icons.sync_rounded,
            iconColor: const Color(0xFF4ADE80), // Green
            title: 'Match Duration',
            subtitle: 'Choose number of rounds and game type',
            trailing: _CustomDropdown<int>(
              value: rounds,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 Round · Quick')),
                DropdownMenuItem(value: 3, child: Text('3 Rounds · Short')),
                DropdownMenuItem(value: 5, child: Text('5 Rounds · Standard')),
                DropdownMenuItem(value: 10, child: Text('10 Rounds · Marathon')),
              ],
              onChanged: isLoading ? null : (v) => v != null ? onRoundsChanged(v) : null,
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsRow(
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFF4ADE80), // Green
            title: 'Minimum Bid',
            subtitle: 'Set minimum bid required to play',
            trailing: _CustomDropdown<int?>(
              value: minBid,
              items: const [
                DropdownMenuItem(value: null, child: Text('None')),
                DropdownMenuItem(value: 1, child: Text('1 Bid (Default)')),
                DropdownMenuItem(value: 2, child: Text('2 Bids')),
                DropdownMenuItem(value: 3, child: Text('3 Bids')),
              ],
              onChanged: isLoading ? null : onMinBidChanged,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Section: ADVANCED OPTIONS
          const Text(
            'ADVANCED OPTIONS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsRow(
            icon: Icons.balance_rounded,
            iconColor: const Color(0xFF9333EA), // Purple
            title: 'Greed Penalty',
            subtitle: '0 points if player wins 2x their bid',
            trailing: Switch(
              value: greedPenalty,
              onChanged: isLoading ? null : onGreedPenaltyChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF4ADE80), // Green track
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsRow(
            icon: Icons.style_rounded,
            iconColor: const Color(0xFF9333EA), // Purple
            title: 'Dynamic Trump Rules',
            subtitle: 'Split deal & dynamic trump suit selection',
            trailing: Switch(
              value: allowCustomTrump,
              onChanged: isLoading ? null : onAllowCustomTrumpChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF4ADE80), // Green track
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          
          const SizedBox(height: 32),
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
              foregroundColor: const Color(0xFF0F172A),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: const Color(0xFF4ADE80).withValues(alpha: 0.5),
              elevation: 8,
            ),
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Color(0xFF0F172A), strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline, size: 20),
            label: Text(
              isLoading ? 'Creating…' : 'Create Room',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Settings Row ──────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191F2C), // Slightly lighter than modal background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

// ─── Custom Dropdown ──────────────────────────────────────────────────────────

class _CustomDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _CustomDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF191F2C),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18),
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Join Room Form ───────────────────────────────────────────────────────────

class _JoinRoomForm extends StatelessWidget {
  final TextEditingController roomCodeController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _JoinRoomForm({
    super.key,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF191F2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextFormField(
              controller: roomCodeController,
              decoration: const InputDecoration(
                labelText: 'Enter Room Code',
                labelStyle: TextStyle(color: Colors.white54, fontSize: 13),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.key_outlined, color: Color(0xFF4ADE80)),
                prefixIconConstraints: BoxConstraints(minWidth: 40),
                hintText: 'e.g. A B C D E',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 8),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontSize: 18,
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
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
              foregroundColor: const Color(0xFF0F172A),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: const Color(0xFF4ADE80).withValues(alpha: 0.5),
              elevation: 8,
            ),
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Color(0xFF0F172A), strokeWidth: 2),
                  )
                : const Icon(Icons.login_outlined, size: 20),
            label: Text(
              isLoading ? 'Joining…' : 'Join Room',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4ADE80).withValues(alpha: 0.1) // Subtle green tint
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF4ADE80) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF4ADE80) : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
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
