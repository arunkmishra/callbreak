import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/audio_service.dart';

class TurnTimerWidget extends StatefulWidget {
  final int turnEndTime;
  final VoidCallback? onTimerExpired;
  final bool isMyTurn;
  final bool compact;

  const TurnTimerWidget({
    super.key,
    required this.turnEndTime,
    this.onTimerExpired,
    this.isMyTurn = false,
    this.compact = false,
  });

  @override
  State<TurnTimerWidget> createState() => _TurnTimerWidgetState();
}

class _TurnTimerWidgetState extends State<TurnTimerWidget> {
  late Timer _timer;
  int _remainingSeconds = 0;
  int _lastTickTime = 0;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateRemainingTime();
    });
  }

  @override
  void didUpdateWidget(covariant TurnTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turnEndTime != widget.turnEndTime) {
      _updateRemainingTime();
    }
  }

  void _updateRemainingTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = widget.turnEndTime - now;
    final seconds = (remaining / 1000).ceil();
    
    if (widget.isMyTurn && remaining > 0 && remaining <= 3000) {
      if (now - _lastTickTime >= 400) {
        AudioService.playTickAlert();
        _lastTickTime = now;
      }
    }

    if (seconds != _remainingSeconds) {
      setState(() {
        _remainingSeconds = seconds > 0 ? seconds : 0;
      });
      if (_remainingSeconds <= 0) {
        widget.onTimerExpired?.call();
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();

    final isWarning = _remainingSeconds <= 3;
    final color = isWarning ? Colors.redAccent : (widget.isMyTurn ? Colors.amber : Colors.white70);

    return AnimatedScale(
      scale: isWarning ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: widget.compact 
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, size: widget.compact ? 12 : 16, color: color),
            const SizedBox(width: 4),
            Text(
              '${_remainingSeconds}s',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: widget.compact ? 11 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
