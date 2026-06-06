import 'package:flutter_test/flutter_test.dart';
import 'package:callbreak_client/core/tier_system.dart';
import 'package:flutter/material.dart';

void main() {
  group('TierSystem', () {
    test('getTierForRP correctly maps Rank Points to Tiers', () {
      expect(TierSystem.getTierForRP(0), Tier.bronze);
      expect(TierSystem.getTierForRP(1000), Tier.bronze);
      expect(TierSystem.getTierForRP(1199), Tier.bronze);
      
      expect(TierSystem.getTierForRP(1200), Tier.silver);
      expect(TierSystem.getTierForRP(1399), Tier.silver);
      
      expect(TierSystem.getTierForRP(1400), Tier.gold);
      expect(TierSystem.getTierForRP(1599), Tier.gold);
      
      expect(TierSystem.getTierForRP(1600), Tier.platinum);
      
      expect(TierSystem.getTierForRP(1800), Tier.diamond);
      
      expect(TierSystem.getTierForRP(2000), Tier.master);
      
      expect(TierSystem.getTierForRP(2500), Tier.grandmaster);
      expect(TierSystem.getTierForRP(3000), Tier.grandmaster);
    });

    test('getTierName correctly maps subdivisions', () {
      // Bronze (0 - 1199)
      expect(TierSystem.getTierName(1000), 'BRONZE I');
      expect(TierSystem.getTierName(1100), 'BRONZE II');
      expect(TierSystem.getTierName(1150), 'BRONZE III');

      // Silver (1200 - 1399)
      expect(TierSystem.getTierName(1200), 'SILVER I');
      expect(TierSystem.getTierName(1300), 'SILVER II');
      expect(TierSystem.getTierName(1350), 'SILVER III');

      // Diamond (1800 - 1999)
      expect(TierSystem.getTierName(1800), 'DIAMOND I');
      expect(TierSystem.getTierName(1900), 'DIAMOND II');
      expect(TierSystem.getTierName(1950), 'DIAMOND III');

      // Master and GM
      expect(TierSystem.getTierName(2200), 'MASTER');
      expect(TierSystem.getTierName(2600), 'GRANDMASTER');
    });

    test('getTierColor returns correct colors', () {
      expect(TierSystem.getTierColor(1000), const Color(0xFFCD7F32)); // Bronze
      expect(TierSystem.getTierColor(1500), const Color(0xFFFFD700)); // Gold
      expect(TierSystem.getTierColor(2500), const Color(0xFFFF4500)); // Grandmaster
    });

    test('getTierIcon returns correct icons', () {
      expect(TierSystem.getTierIcon(1000), Icons.workspace_premium);
      expect(TierSystem.getTierIcon(1800), Icons.diamond);
      expect(TierSystem.getTierIcon(2000), Icons.military_tech);
      expect(TierSystem.getTierIcon(2500), Icons.local_fire_department);
    });
  });
}
