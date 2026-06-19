import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/store_bloc.dart';
import '../../bloc/store_event.dart';
import '../../bloc/store_state.dart';
import '../../core/ad_service.dart';
import '../../core/theme.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _isWatchingAd = false;
  int _selectedTabIndex = 0; // 0: Earn Coins, 1: Shop
  int _currentAdReward = 10;

  void _watchAd() {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0D1729),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2563EB), width: 1),
          ),
          title: const Text('Mobile App Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Watching ads to earn free coins is only available on the Callbreak mobile app. Download it now to unlock this feature!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    
    AdService.instance.showRewardedAd(
      onReward: (rewardItem) {
        final earned = _currentAdReward;
        context.read<StoreBloc>().add(WatchAdReward(earned));
        _showRewardPrompt(earned);
      },
      onDismissed: () {
        setState(() => _isWatchingAd = false);
      },
    );
  }

  void _showRewardPrompt(int earnedCoins) {
    final nextReward = earnedCoins + 5;
    
    showDialog(
      context: context,
      barrierDismissible: true, // Close when clicking anywhere
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D1729),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2563EB), width: 1),
          ),
          title: Text('+$earnedCoins Coins!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 64),
              const SizedBox(height: 16),
              const Text('You earned free coins!', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _currentAdReward = nextReward;
                  _watchAd();
                },
                icon: const Text('🎬', style: TextStyle(fontSize: 18)),
                label: Text('Watch again for +$nextReward Coins'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Store', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: BlocConsumer<StoreBloc, StoreState>(
        listenWhen: (previous, current) => current.errorMessage != null && current.errorMessage!.isNotEmpty && current.errorMessage != previous.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.errorRed),
            );
          }
        },
        builder: (context, state) {
          if (state.status == StoreStatus.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Navigation Panel (~20%)
              Container(
                width: 140,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NavTab(
                      title: 'Earn Coins',
                      icon: Icons.monetization_on_rounded,
                      isSelected: _selectedTabIndex == 0,
                      onTap: () => setState(() => _selectedTabIndex = 0),
                    ),
                    const SizedBox(height: 12),
                    _NavTab(
                      title: 'Shop',
                      icon: Icons.storefront_rounded,
                      isSelected: _selectedTabIndex == 1,
                      onTap: () => setState(() => _selectedTabIndex = 1),
                    ),
                  ],
                ),
              ),
              
              const VerticalDivider(width: 1, color: Colors.white12),

              // Right Content Panel (~80%)
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildEarnCoinsView(context, state)
                    : _buildShopView(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEarnCoinsView(BuildContext context, StoreState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earn Free Coins',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Discover ways to boost your coin balance without spending.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Play Game Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1729),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_esports_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Play Matches',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Complete any full match to earn +5 coins automatically.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Watch Ad Box
          GestureDetector(
            onTap: _watchAd,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🎬', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Watch a Video',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Watch a short advertisement to instantly receive +$_currentAdReward coins.',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_isWatchingAd)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopView(BuildContext context, StoreState state) {
    final items = state.items;
    final isPremium = state.isPremium;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Item Shop',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          const Text(
            'Premium Memberships',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (isPremium)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'You are an active Premium member. Purchasing another tier will extend your duration!',
                style: TextStyle(color: AppColors.gold, fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          _buildPremiumTier(context, state, 'premium_1_week', '1 Week', 200, const Color(0xFF3B82F6), const Color(0xFF1D4ED8)),
          const SizedBox(height: 8),
          _buildPremiumTier(context, state, 'premium_1_month', '1 Month', 450, const Color(0xFF8B5CF6), const Color(0xFF6D28D9)),
          const SizedBox(height: 8),
          _buildPremiumTier(context, state, 'premium_1_year', '1 Year', 1000, const Color(0xFFF59E0B), const Color(0xFFD97706)),

          const SizedBox(height: 16),

          const Text(
            'Cosmetics',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.where((i) => i.category == 'cards' || i.category == 'table').length,
            itemBuilder: (context, index) {
              final item = items.where((i) => i.category == 'cards' || i.category == 'table').toList()[index];
              final isUnlocked = state.unlockedSkins.contains(item.id);
              
              // Custom design for neon and gold cards
              BoxDecoration decoration;
              if (item.id == 'neon_cards') {
                decoration = BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.4), blurRadius: 8),
                  ],
                );
              } else if (item.id == 'gold_cards') {
                decoration = BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.4), blurRadius: 8),
                  ],
                );
              } else {
                decoration = BoxDecoration(
                  color: const Color(0xFF0D1729),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                );
              }

              return Container(
                decoration: decoration,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.category == 'cards' ? Icons.style_rounded : Icons.table_bar_rounded,
                      size: 32,
                      color: (item.id == 'neon_cards' || item.id == 'gold_cards') ? Colors.white : (isUnlocked ? AppColors.gold : Colors.white54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const Spacer(),
                    if (isUnlocked)
                      const Text('UNLOCKED', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold))
                    else
                      ElevatedButton(
                        onPressed: () {
                          context.read<StoreBloc>().add(PurchaseItem(item.id));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (item.id == 'neon_cards' || item.id == 'gold_cards') ? Colors.white.withOpacity(0.2) : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 28),
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        child: Text('${item.price} Coins'),
                      )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTier(BuildContext context, StoreState state, String itemId, String title, int price, Color colorStart, Color colorEnd) {
    final label = state.isPremium ? 'Extend' : 'Buy';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorStart, colorEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorStart.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 28, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium ($title)',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ad-free experience.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final item = state.items.firstWhere((i) => i.id == itemId);
                context.read<StoreBloc>().add(PurchaseItem(item.id));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item $itemId not loaded yet')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colorEnd,
              minimumSize: const Size(80, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('$label $price Coins', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          )
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTab({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB).withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
