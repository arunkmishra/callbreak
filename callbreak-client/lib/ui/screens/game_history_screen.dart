import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'history_scorecard_screen.dart';

enum MatchSort { newest, oldest }

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _currentPage = 1;
  final int _limit = 10;
  int _totalCount = 0;
  MatchSort _sort = MatchSort.newest;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final offset = (_currentPage - 1) * _limit;
      final response = await _supabase
          .from('match_scorecards')
          .select('*, user_match_records!inner(user_id)')
          .eq('user_match_records.user_id', user.id)
          .order('played_at', ascending: _sort == MatchSort.oldest)
          .range(offset, offset + _limit - 1)
          .count(CountOption.exact);

      _totalCount = response.count ?? 0;

      final List<Map<String, dynamic>> fetched = [];
      for (var row in response.data as List<dynamic>) {
        fetched.add(row as Map<String, dynamic>);
      }

      setState(() {
        _history = fetched;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching history: $e');
      setState(() => _isLoading = false);
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > (_totalCount / _limit).ceil()) return;
    setState(() => _currentPage = page);
    _fetchData();
  }

  void _showSortFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1B33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Sort By', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Newest First', style: TextStyle(color: Colors.white)),
                trailing: _sort == MatchSort.newest ? const Icon(Icons.check, color: AppColors.gold) : null,
                onTap: () {
                  setState(() => _sort = MatchSort.newest);
                  Navigator.pop(context);
                  _fetchData();
                },
              ),
              ListTile(
                title: const Text('Oldest First', style: TextStyle(color: Colors.white)),
                trailing: _sort == MatchSort.oldest ? const Icon(Icons.check, color: AppColors.gold) : null,
                onTap: () {
                  setState(() => _sort = MatchSort.oldest);
                  Navigator.pop(context);
                  _fetchData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A101C), // Deep dark background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : _history.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _HistoryCard(
                              matchData: _history[index],
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => HistoryScorecardScreen(matchData: _history[index]),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
            if (!_isLoading && _totalCount > 0) _buildPagination(),
            const Padding(
              padding: EdgeInsets.only(bottom: 12, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white30, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Scores are calculated based on multi-round matches.',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          // Title
          Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: AppColors.gold, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'MATCH HISTORY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Your recent matches',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          // Filter Button
          InkWell(
            onTap: _showSortFilter,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  const Text('FILTER', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _limit).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    Widget buildBtn(String text, VoidCallback? onTap, {bool isActive = false}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? AppColors.gold : (onTap == null ? Colors.white30 : Colors.white70),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildBtn('« First', _currentPage > 1 ? () => _goToPage(1) : null),
            buildBtn('< Prev', _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null),
            
            // Show up to 5 page numbers around current page
            for (int i = 1; i <= totalPages; i++)
              if (i >= _currentPage - 2 && i <= _currentPage + 2)
                buildBtn('$i', () => _goToPage(i), isActive: i == _currentPage),

            buildBtn('Next >', _currentPage < totalPages ? () => _goToPage(_currentPage + 1) : null),
            buildBtn('Last »', _currentPage < totalPages ? () => _goToPage(totalPages) : null),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text('No matches found', style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> matchData;
  final VoidCallback onTap;

  const _HistoryCard({required this.matchData, required this.onTap});

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    
    var hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    
    return '$day $month $year  •  $hourStr:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final roomId = matchData['room_id'] ?? 'Unknown';
    final playedAt = matchData['played_at'] != null 
        ? DateTime.parse(matchData['played_at']).toLocal() 
        : DateTime.now();
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final participants = (matchData['participants'] as List<dynamic>?) ?? [];
    
    Map<String, dynamic>? myData;
    for (var p in participants) {
      if (p['id'] == userId) {
        myData = p as Map<String, dynamic>;
        break;
      }
    }
    
    final rank = myData?['rank'] ?? 4;
    final score = myData?['total_score'] ?? 0.0;
    final isWinner = rank == 1;

    final borderColor = isWinner ? AppColors.gold.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.08);
    final bgColor = const Color(0xFF131A2A); // Slightly lighter than scaffold bg

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: isWinner ? [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.1),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Row(
          children: [
            // Rank Circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0A101C),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWinner ? AppColors.gold : Colors.white12,
                  width: 1.2,
                ),
                boxShadow: isWinner ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: -1,
                  )
                ] : null,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: isWinner ? AppColors.gold : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Middle Content (Details + Avatars)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Room Code & Date
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Room Code', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          roomId,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white54, size: 9),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(playedAt),
                              style: const TextStyle(color: Colors.white54, fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Players Avatars
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Players', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: participants.take(4).map((p) {
                            final pMap = p as Map<String, dynamic>;
                            final isMe = pMap['id'] == userId;
                            final name = pMap['name'] as String? ?? '?';
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                            
                            // Deterministic color based on name length/hash
                            final colors = [
                              const Color(0xFF8B5CF6), // Purple
                              const Color(0xFF3B82F6), // Blue
                              const Color(0xFF10B981), // Green
                              const Color(0xFFF97316), // Orange
                            ];
                            final avatarColor = isMe ? colors[0] : colors[name.hashCode % colors.length];

                            return Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A101C),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: avatarColor, width: 1.0),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(color: avatarColor, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isMe ? 'You' : (name.split(' ').first),
                                    style: TextStyle(
                                      color: isMe ? AppColors.gold : Colors.white70,
                                      fontSize: 8,
                                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Score & Status
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 32,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Your Score', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    color: isWinner ? AppColors.gold : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isWinner ? const Color(0xFF052E16) : const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isWinner ? 'WON' : 'LOST',
                    style: TextStyle(
                      color: isWinner ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }
}
