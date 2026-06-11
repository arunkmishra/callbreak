import 'package:flutter/material.dart';

/// A single emoticon entry in the catalog.
class EmoticonItem {
  final String emoji;
  final String label;

  /// Whether this emoticon is part of the premium (locked) tier.
  /// Premium emoticons require an in-app purchase to unlock.
  final bool isPremium;

  const EmoticonItem({
    required this.emoji,
    required this.label,
    this.isPremium = false,
  });
}

/// Defines the full emoticon catalog split into free and premium tiers.
///
/// **Free tier** (6 emoticons): available to all players out of the box.
/// **Premium tier** (11 emoticons): shown with a lock overlay; require IAP to unlock.
///
/// To add more emoticons in the future, extend [premium] and update the
/// server-side allowlist in GameRoom.kt accordingly.
class EmoticonCatalog {
  EmoticonCatalog._();

  static const List<EmoticonItem> free = [
    EmoticonItem(emoji: '😂', label: 'LOL'),
    EmoticonItem(emoji: '😤', label: 'Angry'),
    EmoticonItem(emoji: '😭', label: 'Sad'),
    EmoticonItem(emoji: '🤯', label: 'Mind blown'),
    EmoticonItem(emoji: '😎', label: 'Cool'),
    EmoticonItem(emoji: '🤬', label: 'Rage'),
  ];

  static const List<EmoticonItem> premium = [
    EmoticonItem(emoji: '🎯', label: 'Bullseye', isPremium: true),
    EmoticonItem(emoji: '👑', label: 'King', isPremium: true),
    EmoticonItem(emoji: '💎', label: 'Diamond', isPremium: true),
    EmoticonItem(emoji: '🦁', label: 'Lion', isPremium: true),
    EmoticonItem(emoji: '⚡', label: 'Lightning', isPremium: true),
    EmoticonItem(emoji: '🌪️', label: 'Tornado', isPremium: true),
    EmoticonItem(emoji: '🏆', label: 'Trophy', isPremium: true),
    EmoticonItem(emoji: '🤑', label: 'Money', isPremium: true),
    EmoticonItem(emoji: '🔥', label: 'Fire', isPremium: true),
    EmoticonItem(emoji: '👏', label: 'Clap', isPremium: true),
    EmoticonItem(emoji: '💀', label: 'Skull', isPremium: true),
  ];

  static const List<EmoticonItem> all = [...free, ...premium];

  /// Returns the accent color for the picker based on the current table accent.
  static Color overlayColor(Color accent) =>
      Color.lerp(accent, Colors.black, 0.55)!;
}
