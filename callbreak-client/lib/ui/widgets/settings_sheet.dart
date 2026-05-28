import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings_cubit.dart';
import '../../core/theme.dart';

/// A bottom sheet that allows users to customize their game experience.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            const Row(
              children: [
                Icon(Icons.settings_outlined, color: AppColors.gold, size: 26),
                SizedBox(width: 14),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Settings Content
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sound Toggle
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        title: const Text('Sound Effects', style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: const Text('Card sliding & flipping sounds', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        secondary: Icon(
                          state.soundEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                          color: state.soundEnabled ? AppColors.gold : AppColors.textSecondary,
                        ),
                        value: state.soundEnabled,
                        activeThumbColor: AppColors.gold,
                        onChanged: (val) {
                          context.read<SettingsCubit>().toggleSound();
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 32),

                    // Table Felt Color Picker
                    const Text('Table Felt Color', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ColorOption(
                          label: 'Classic Green',
                          color: AppColors.tableGreen,
                          isSelected: state.tableColor == TableColor.green,
                          onTap: () => context.read<SettingsCubit>().setTableColor(TableColor.green),
                        ),
                        _ColorOption(
                          label: 'Casino Red',
                          color: AppColors.tableRed,
                          isSelected: state.tableColor == TableColor.red,
                          onTap: () => context.read<SettingsCubit>().setTableColor(TableColor.red),
                        ),
                        _ColorOption(
                          label: 'Midnight Blue',
                          color: AppColors.tableBlue,
                          isSelected: state.tableColor == TableColor.blue,
                          onTap: () => context.read<SettingsCubit>().setTableColor(TableColor.blue),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.gold : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (isSelected)
                  const BoxShadow(
                    color: AppColors.gold,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                const BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
