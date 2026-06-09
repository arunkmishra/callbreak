import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Singleton pattern
  static final AdService instance = AdService._internal();
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdReady = false;

  /// Call this inside main() after WidgetsFlutterBinding.ensureInitialized()
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadInterstitialAd();
  }

  /// Use Google's test ad unit ID for development, replace with real ID in production.
  String get _interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final envId = dotenv.env['ADMOB_INTERSTITIAL_UNIT_ID_ANDROID'];
      return (envId != null && envId.trim().isNotEmpty) ? envId.trim() : 'ca-app-pub-3940256099942544/1033173712';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final envId = dotenv.env['ADMOB_INTERSTITIAL_UNIT_ID_IOS'];
      return (envId != null && envId.trim().isNotEmpty) ? envId.trim() : 'ca-app-pub-3940256099942544/4411468910';
    }
    // Web or other platforms, we don't have mobile ads support.
    return '';
  }

  /// Preloads the next interstitial ad.
  void loadInterstitialAd() {
    if (_interstitialAdUnitId.isEmpty) return;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdReady = true;

          // Handle the full screen content callbacks
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isAdReady = false;
              // Preload the next ad
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isAdReady = false;
              // Try to load another ad
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _isAdReady = false;
          _interstitialAd = null;
          // Optionally, retry loading after some delay
        },
      ),
    );
  }

  /// Shows the interstitial ad if it's ready. If not, immediately invokes the callback.
  void showInterstitialAd({required VoidCallback onDismissed}) {
    if (_isAdReady && _interstitialAd != null) {
      // Temporarily store the dismissed callback to the fullScreenContentCallback
      final originalCallback = _interstitialAd!.fullScreenContentCallback;
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          originalCallback?.onAdDismissedFullScreenContent?.call(ad);
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          originalCallback?.onAdFailedToShowFullScreenContent?.call(ad, error);
          onDismissed();
        },
      );
      
      _interstitialAd!.show();
    } else {
      // Ad isn't ready, just continue the flow
      onDismissed();
      
      // Try to load one for next time
      loadInterstitialAd();
    }
  }
}
