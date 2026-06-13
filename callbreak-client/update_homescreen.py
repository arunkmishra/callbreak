import re

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/ui/screens/home_screen.dart', 'r') as f:
    content = f.read()

# 1. Add getSimulatedOnlineCount
func_def = """
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
"""
content = content.replace('class HomeScreen extends StatefulWidget {', func_def, 1)

# 2. Add variables
vars_def = """  int _selectedNavIndex = 0;

  int _simulatedOnlineCount = getSimulatedOnlineCount();
  Timer? _counterTimer;"""
content = content.replace('  int _selectedNavIndex = 0;', vars_def, 1)

# 3. Add to initState
init_def = """    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchOnlineUsers();
    });

    _counterTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _simulatedOnlineCount = getSimulatedOnlineCount());
    });"""
content = content.replace("""    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchOnlineUsers();
    });""", init_def, 1)

# 4. Add to dispose
dispose_def = """  @override
  void dispose() {
    _counterTimer?.cancel();
    _fanController.dispose();"""
content = content.replace("""  @override
  void dispose() {
    _fanController.dispose();""", dispose_def, 1)

# 5. Add _startPlayOnline
start_def = """  void _startPlayOnline(BuildContext context) {
    AudioService.preload();
    setState(() => _isBotGame = false);
    final username = _profile?.username ?? 'Player';
    context.read<GameBloc>().add(FindMatchRequested(username));
  }

  void _startQuickPlay(BuildContext context) {"""
content = content.replace('  void _startQuickPlay(BuildContext context) {', start_def, 1)

# 6. Handle GameMatchmaking
match_def = """          if (state is GameMatchmaking) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LobbyScreen()),
              (route) => false,
            );
          } else if (state is GameLobby) {"""
content = content.replace('          if (state is GameLobby) {', match_def, 1)

# 7. Update text
content = content.replace("'1,248 Players Online',", "'$_simulatedOnlineCount Players Online',")

# 8. Update tile
tile_repl = """            badge: 'Play Now',
            badgeColor: const Color(0xFF60A5FA),
            comingSoon: false,
            onTap: () => _startPlayOnline(context),"""
tile_orig = """            badge: 'Coming Soon',
            badgeColor: const Color(0xFF60A5FA),
            comingSoon: true,
            onTap: () => _showComingSoon(context, 'Play Online'),"""
content = content.replace(tile_orig, tile_repl, 1)

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/ui/screens/home_screen.dart', 'w') as f:
    f.write(content)
