import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';

class AdBannerWidget extends ConsumerStatefulWidget {
  const AdBannerWidget({super.key});

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int? _lastRequestedWidth;
  Orientation? _lastRequestedOrientation;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  bool get wantKeepAlive => true;

  // Ganti dengan Ad Unit ID asli Anda dari AdMob console
  String get adUnitId => defaultTargetPlatform == TargetPlatform.android
      // ? 'ca-app-pub-3940256099942544/6300978111' // Google Test ID Android
      ? 'ca-app-pub-4602657974905060/5021274187' // Real Android Banner ID
      : 'ca-app-pub-3940256099942544/2934735716'; // Google Test ID iOS

  void _safeDisposeBanner() {
    final ad = _bannerAd;
    _bannerAd = null;
    if (ad != null) {
      try {
        ad.dispose();
      } catch (e) {
        debugPrint('Safe dispose BannerAd error: $e');
      }
    }
  }

  Future<void> _loadAd({
    required int availableWidth,
    required Orientation orientation,
  }) async {
    if (_isLoading) return;

    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          availableWidth,
        );

    if (!mounted) return;

    if (adaptiveSize == null) {
      debugPrint(
        'BannerAd size unavailable for width=$availableWidth, orientation=$orientation',
      );
      setState(() {
        _isLoaded = false;
        _isLoading = false;
      });
      return;
    }

    _safeDisposeBanner();

    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: adaptiveSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded successfully.');
          if (!mounted) return;
          _retryCount = 0;
          _retryTimer?.cancel();
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'BannerAd failed to load (attempt ${_retryCount + 1}/$_maxRetries): ${error.message} (code ${error.code})',
          );
          if (_bannerAd == ad) {
            _bannerAd = null;
          }
          try {
            ad.dispose();
          } catch (_) {}

          if (!mounted) return;
          setState(() {
            _isLoaded = false;
            _isLoading = false;
          });

          // Code 3 is ERROR_CODE_NO_FILL. Do not hammer retry to prevent rate limit / crash.
          if (error.code == 3) {
            debugPrint('BannerAd no fill. Halting rapid retries.');
            return;
          }

          // Auto retry with exponential backoff (4s, 8s, 16s, 32s, 60s)
          if (_retryCount < _maxRetries) {
            _retryCount++;
            final delaySeconds = min(60, 2 << _retryCount);
            debugPrint('BannerAd scheduling retry in $delaySeconds seconds...');
            _retryTimer?.cancel();
            _retryTimer = Timer(Duration(seconds: delaySeconds), () {
              if (mounted) {
                _loadAd(availableWidth: availableWidth, orientation: orientation);
              }
            });
          }
        },
      ),
    );

    setState(() {
      _bannerAd = bannerAd;
      _isLoaded = false;
      _isLoading = true;
    });

    try {
      await bannerAd.load();
    } catch (e) {
      debugPrint('Error loading bannerAd: $e');
      _safeDisposeBanner();
      if (mounted) {
        setState(() {
          _isLoaded = false;
          _isLoading = false;
        });
      }
    }
  }

  void _ensureAdForLayout(BoxConstraints constraints, Orientation orientation) {
    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth.floor()
        : MediaQuery.sizeOf(context).width.floor();

    if (availableWidth <= 0) return;

    if (_lastRequestedWidth == availableWidth &&
        _lastRequestedOrientation == orientation) {
      return;
    }

    _lastRequestedWidth = availableWidth;
    _lastRequestedOrientation = orientation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAd(availableWidth: availableWidth, orientation: orientation);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _safeDisposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) return const SizedBox.shrink();

    final shouldShowAds = ref.watch(featureGateProvider).shouldShowAds();
    if (!shouldShowAds) return const SizedBox.shrink();

    final orientation = MediaQuery.orientationOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureAdForLayout(constraints, orientation);

        if (!_isLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        );
      },
    );
  }
}
