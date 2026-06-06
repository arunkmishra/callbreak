import 'package:flutter/material.dart';

enum Tier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  master,
  grandmaster
}

class TierSystem {
  static Tier getTierForRP(int rp) {
    if (rp < 1200) return Tier.bronze;
    if (rp < 1400) return Tier.silver;
    if (rp < 1600) return Tier.gold;
    if (rp < 1800) return Tier.platinum;
    if (rp < 2000) return Tier.diamond;
    if (rp < 2500) return Tier.master;
    return Tier.grandmaster;
  }

  static String getTierName(int rp) {
    if (rp < 1200) {
      if (rp < 1066) return 'BRONZE I';
      if (rp < 1133) return 'BRONZE II';
      return 'BRONZE III';
    }
    if (rp < 1400) {
      if (rp < 1266) return 'SILVER I';
      if (rp < 1333) return 'SILVER II';
      return 'SILVER III';
    }
    if (rp < 1600) {
      if (rp < 1466) return 'GOLD I';
      if (rp < 1533) return 'GOLD II';
      return 'GOLD III';
    }
    if (rp < 1800) {
      if (rp < 1666) return 'PLATINUM I';
      if (rp < 1733) return 'PLATINUM II';
      return 'PLATINUM III';
    }
    if (rp < 2000) {
      if (rp < 1866) return 'DIAMOND I';
      if (rp < 1933) return 'DIAMOND II';
      return 'DIAMOND III';
    }
    if (rp < 2500) return 'MASTER';
    return 'GRANDMASTER';
  }

  static Color getTierColor(int rp) {
    final tier = getTierForRP(rp);
    switch (tier) {
      case Tier.bronze:
        return const Color(0xFFCD7F32); // Bronze
      case Tier.silver:
        return const Color(0xFFC0C0C0); // Silver
      case Tier.gold:
        return const Color(0xFFFFD700); // Gold
      case Tier.platinum:
        return const Color(0xFF00CED1); // Platinum (Teal/Cyan)
      case Tier.diamond:
        return const Color(0xFFB9F2FF); // Diamond (Light Blue)
      case Tier.master:
        return const Color(0xFF9932CC); // Master (Purple)
      case Tier.grandmaster:
        return const Color(0xFFFF4500); // Grandmaster (Orange/Red)
    }
  }

  static IconData getTierIcon(int rp) {
    final tier = getTierForRP(rp);
    switch (tier) {
      case Tier.bronze:
      case Tier.silver:
      case Tier.gold:
      case Tier.platinum:
        return Icons.workspace_premium;
      case Tier.diamond:
        return Icons.diamond;
      case Tier.master:
        return Icons.military_tech;
      case Tier.grandmaster:
        return Icons.local_fire_department;
    }
  }

  static int getFloorRPForTier(int rp) {
    if (rp < 1066) return 1000; // Base start
    if (rp < 1133) return 1066;
    if (rp < 1200) return 1133;
    if (rp < 1266) return 1200;
    if (rp < 1333) return 1266;
    if (rp < 1400) return 1333;
    if (rp < 1466) return 1400;
    if (rp < 1533) return 1466;
    if (rp < 1600) return 1533;
    if (rp < 1666) return 1600;
    if (rp < 1733) return 1666;
    if (rp < 1800) return 1733;
    if (rp < 1866) return 1800;
    if (rp < 1933) return 1866;
    if (rp < 2000) return 1933;
    if (rp < 2500) return 2000;
    return 2500;
  }

  static int getCeilRPForTier(int rp) {
    if (rp < 1066) return 1066;
    if (rp < 1133) return 1133;
    if (rp < 1200) return 1200;
    if (rp < 1266) return 1266;
    if (rp < 1333) return 1333;
    if (rp < 1400) return 1400;
    if (rp < 1466) return 1466;
    if (rp < 1533) return 1533;
    if (rp < 1600) return 1600;
    if (rp < 1666) return 1666;
    if (rp < 1733) return 1733;
    if (rp < 1800) return 1800;
    if (rp < 1866) return 1866;
    if (rp < 1933) return 1933;
    if (rp < 2000) return 2000;
    if (rp < 2500) return 2500;
    return 3000; // Arbitrary high number for Grandmaster cap
  }

  static String getNextTierName(int rp) {
    int ceil = getCeilRPForTier(rp);
    if (ceil >= 2500) return 'MAX RANK';
    return getTierName(ceil);
  }
}
