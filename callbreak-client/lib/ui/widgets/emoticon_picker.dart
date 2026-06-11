import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../bloc/game_event.dart';
import '../../core/emoticon_catalog.dart';

/// A compact bottom sheet emoticon picker.
///
/// Shows the full emoticon catalog in a small grid:
/// - Free emoticons are fully tappable.
/// - Premium emoticons display a lock badge and a "Coming Soon" snackbar.
class EmoticonPicker extends StatelessWidget {
  final Color accentColor;

  const EmoticonPicker({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final darkBg = Color.lerp(accentColor, Colors.black, 0.82)!;
    final borderColor = accentColor.withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),



          // ── Emoticon grid ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: EmoticonCatalog.all.map((item) {
                return _EmoticonTile(
                  item: item,
                  accentColor: accentColor,
                  onTap: () {
                    if (item.isPremium) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔒', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 6),
                              Text(
                                'Premium — coming soon!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1E3A5F),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    context.read<GameBloc>().add(SendEmoticonRequested(item.emoji));
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // ── Premium hint row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Unlock all premium reactions — coming soon!',
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// Individual emoticon cell — small and tight.
class _EmoticonTile extends StatefulWidget {
  final EmoticonItem item;
  final Color accentColor;
  final VoidCallback onTap;

  const _EmoticonTile({
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_EmoticonTile> createState() => _EmoticonTileState();
}

class _EmoticonTileState extends State<_EmoticonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = widget.item.isPremium;

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (ctx, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cell background
              Container(
                decoration: BoxDecoration(
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.04)
                      : widget.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPremium
                        ? Colors.white.withValues(alpha: 0.07)
                        : widget.accentColor.withValues(alpha: 0.28),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.item.emoji,
                    style: TextStyle(
                      fontSize: 22,
                      color: isPremium
                          ? Colors.white.withValues(alpha: 0.3)
                          : null,
                    ),
                  ),
                ),
              ),
              // Lock badge
              if (isPremium)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🔒', style: TextStyle(fontSize: 7)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
