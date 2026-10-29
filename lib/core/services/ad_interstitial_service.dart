import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdInterstitialService {
  static InterstitialAd? _interstitialAd;
  static bool _isLoaded = false;
  static bool _isLoading = false;
  static Timer? _retryTimer;
  static int _retryCount = 0;
  static const int _maxRetries = 5;

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Ganti dengan Ad Unit ID asli Anda
  static String get adUnitId => defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-4602657974905060/6334355852' // Real Android Interstitial ID
      : 'ca-app-pub-3940256099942544/4411468910'; // Sample iOS Interstitial ID

  static void loadAd() {
    if (!_isSupportedPlatform) return;
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
          _isLoading = false;
          _retryCount = 0;
          _retryTimer?.cancel();
          debugPrint('InterstitialAd loaded successfully.');

          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  _isLoaded = false;
                  loadAd(); // Preload next ad
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  debugPrint('InterstitialAd failed to show: $error');
                  ad.dispose();
                  _interstitialAd = null;
                  _isLoaded = false;
                  loadAd();
                },
              );
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'InterstitialAd failed to load (attempt ${_retryCount + 1}/$_maxRetries): $error',
          );
          _interstitialAd = null;
          _isLoaded = false;
          _isLoading = false;

          // Code 3 = ERROR_CODE_NO_FILL
          if (error.code == 3) {
            debugPrint('InterstitialAd no fill. Halting rapid retries.');
            return;
          }

          // Auto retry with exponential backoff (4s, 8s, 16s, 32s, 60s)
          if (_retryCount < _maxRetries) {
            _retryCount++;
            final delaySeconds = min(60, 2 << _retryCount);
            debugPrint('InterstitialAd scheduling retry in $delaySeconds seconds...');
            _retryTimer?.cancel();
            _retryTimer = Timer(Duration(seconds: delaySeconds), () {
              loadAd();
            });
          }
        },
      ),
    );
  }

  static bool showAd() {
    if (!_isSupportedPlatform) return false;
    if (_isLoaded && _interstitialAd != null) {
      final ad = _interstitialAd!;
      _interstitialAd = null;
      _isLoaded = false;
      ad.show();
      return true;
    } else {
      debugPrint('InterstitialAd not loaded yet.');
      loadAd(); // Try loading for next time
      return false;
    }
  }
}
