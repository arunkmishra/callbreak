import re

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/ui/screens/lobby_screen.dart', 'r') as f:
    content = f.read()

wide_layout_orig = """            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RoomCodeSection(roomCode: gameState.roomId, myName: myName),
                const SizedBox(height: 12),
                Expanded(
                  child: _OnlineFriendsSection(roomId: gameState.roomId, myName: myName),
                ),
              ],
            ),"""

wide_layout_new = """            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (gameState.isPublic)
                  const Expanded(child: _PublicMatchmakingStats())
                else ...[
                  _RoomCodeSection(roomCode: gameState.roomId, myName: myName),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _OnlineFriendsSection(roomId: gameState.roomId, myName: myName),
                  ),
                ],
              ],
            ),"""

content = content.replace(wide_layout_orig, wide_layout_new)

narrow_layout_orig = """        children: [
          _RoomCodeSection(roomCode: gameState.roomId, myName: myName),
          const SizedBox(height: 16),
          _PlayersHeader(players: players),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _PlayerGrid(players: players, myPlayerId: myId),
          ),
          const SizedBox(height: 16),
          _GameSettingsCard(gameState: gameState),
          const SizedBox(height: 24),
          SizedBox(
            height: 350,
            child: _OnlineFriendsSection(roomId: gameState.roomId, myName: myName),
          ),
        ],"""

narrow_layout_new = """        children: [
          if (gameState.isPublic) ...[
            const SizedBox(height: 320, child: _PublicMatchmakingStats()),
            const SizedBox(height: 16),
          ] else ...[
            _RoomCodeSection(roomCode: gameState.roomId, myName: myName),
            const SizedBox(height: 16),
          ],
          _PlayersHeader(players: players),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _PlayerGrid(players: players, myPlayerId: myId),
          ),
          const SizedBox(height: 16),
          _GameSettingsCard(gameState: gameState),
          if (!gameState.isPublic) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 350,
              child: _OnlineFriendsSection(roomId: gameState.roomId, myName: myName),
            ),
          ],
        ],"""

content = content.replace(narrow_layout_orig, narrow_layout_new)

widget_code = """
// ─── Public Matchmaking Stats ────────────────────────────────────────────────

class _PublicMatchmakingStats extends StatefulWidget {
  const _PublicMatchmakingStats();

  @override
  State<_PublicMatchmakingStats> createState() => _PublicMatchmakingStatsState();
}

class _PublicMatchmakingStatsState extends State<_PublicMatchmakingStats> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _onlineCount = getSimulatedOnlineCount();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {
          _onlineCount = getSimulatedOnlineCount();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  ),
                ),
              ),
              const Icon(Icons.public, color: Color(0xFF60A5FA), size: 36),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'MATCHMAKING',
            style: TextStyle(color: Color(0xFF60A5FA), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 16),
          _buildStatRow(Icons.group, 'Online Players', '$_onlineCount'),
          const SizedBox(height: 12),
          _buildStatRow(Icons.videogame_asset, 'Active Matches', '${(_onlineCount / 4).floor() + 12}'),
          const SizedBox(height: 12),
          _buildStatRow(Icons.timer, 'Est. Wait', '~15s'),
          const SizedBox(height: 12),
          _buildStatRow(Icons.radar, 'Region', 'Asia South'),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

"""

content += widget_code

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/ui/screens/lobby_screen.dart', 'w') as f:
    f.write(content)
