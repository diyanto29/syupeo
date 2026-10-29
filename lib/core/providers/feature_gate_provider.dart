import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';

final featureGateProvider = Provider((ref) {
  final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
  final business = bootstrap?.business;

  return FeatureGate(business);
});

class FeatureGate {
  final Business? _business;

  FeatureGate(this._business);

  /// Menghasilkan true jika fitur diizinkan berdasarkan paket aktif.
  bool isEnabled(String featureKey) {
    if (_business == null) return false;

    // 1. Cek konfigurasi fitur dari Template atau Business Override
    var config = _business.featuresConfig[featureKey];
    if (config == null) {
      if (featureKey == 'kitchen_kds') config = _business.featuresConfig['kds'];
      if (featureKey == 'kds') config = _business.featuresConfig['kitchen_kds'];
      if (featureKey == 'qr_order') config = _business.featuresConfig['qr_ordering'];
      if (featureKey == 'qr_ordering') config = _business.featuresConfig['qr_order'];
    }

    // Default 'free' untuk fitur subscription agar backward-compatible (selalu tampil kecuali dimatikan)
    if (config == null && featureKey == 'subscription') {
      config = 'free';
    }

    // Default 'free' untuk realtime_notifications agar notifikasi realtime order kasir selalu jalan
    if (config == null && featureKey == 'realtime_notifications') {
      config = 'free';
    }

    // Default 'pro' untuk fitur cash_flow jika belum diset eksplisit di template
    if (config == null && featureKey == 'cash_flow') {
      config = 'pro';
    }

    // Default 'free' untuk fitur customer_debt agar buku kasbon langsung aktif untuk semua pengguna
    if (config == null && featureKey == 'customer_debt') {
      config = 'free';
    }

    if (config != null) {
      // Jika fitur diset OFF, maka disembunyikan untuk semua user
      if (config == 'off') return false;

      // Jika fitur diset FREE, maka terbuka untuk semua (termasuk user paket Free)
      if (config == 'free') return true;

      // Jika fitur diset PRO, cek status langganan atau bypass
      if (config == 'pro') {
        // Jika Gating dimatikan secara manual (admin bypass), maka terbuka
        if (!_business.isFeatureGateEnabled) return true;

        // Jika bisnis berada di paket Pro/Enterprise, maka semua fitur 'pro' terbuka
        if (isProPlan()) return true;

        // Cek apakah paket langganan saat ini mengizinkan fitur ini secara spesifik
        return _business.plan?.isFeatureEnabled(featureKey) ?? false;
      }
    }

    // BACKWARD COMPATIBILITY: Jika featuresConfig kosong, gunakan enabledFeatures lama
    if (_business.enabledFeatures.contains(featureKey)) {
      // Jika fitur ada di daftar enabled, dan gating dimatikan, atau bisnis ini Pro, beri akses
      if (!_business.isFeatureGateEnabled || isProPlan()) return true;
    }

    return false;
  }

  /// Menghasilkan batas (limit) tertentu berdasarkan paket aktif.
  int getLimit(String limitKey, {int defaultValue = 0}) {
    if (_business == null) return defaultValue;

    // Jika gating dimatikan (false), berikan limit tak terbatas (angka besar)
    if (!_business.isFeatureGateEnabled) return 999999999;

    // 1. Tentukan Tier Aktif (free atau pro)
    final tierKey = isProPlan() ? 'pro' : 'free';

    // 2. Ambil dari limitsConfig jika ada
    final tierLimits = _business.limitsConfig[tierKey];
    if (tierLimits is Map) {
      final snakeKey = limitKey.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      );

      final value = tierLimits[limitKey] ?? tierLimits[snakeKey];
      if (value != null) {
        return int.tryParse(value.toString()) ?? defaultValue;
      }
    }

    // 3. FALLBACK: Gunakan kolom legacy jika config kosong
    if (limitKey == 'maxTransactions' || limitKey == 'max_transactions') {
      return _business.maxTransactions ?? defaultValue;
    }
    if (limitKey == 'maxProducts' || limitKey == 'max_products') {
      return _business.maxProducts ?? defaultValue;
    }
    if (limitKey == 'maxOutlets' || limitKey == 'max_outlets') {
      return _business.maxOutlets ?? defaultValue;
    }

    return defaultValue;
  }

  /// Memeriksa apakah iklan harus ditampilkan.
  /// - Paid Pro: Bebas iklan (false).
  /// - Trial Pro / Free: Mengikuti pengaturan 'show_ads' dari database, default true.
  bool shouldShowAds() {
    if (_business == null) return true;

    // Jika gating dimatikan (biasanya untuk debugging), sembunyikan iklan
    if (!_business.isFeatureGateEnabled) return false;

    // 1. Jika Paid Pro aktif (berbayar), bebas iklan
    if (isPaidProActive()) return false;

    // 2. Cek konfigurasi eksplisit show_ads dari admin di database
    // Admin bisa mengatur apakah Trial Pro ini mau ada iklannya atau tanpa iklan
    if (_business.showAds != null) {
      return _business.showAds!;
    }

    // 3. Default jika belum diset: tampilkan iklan untuk Free & Trial Pro standar
    return true;
  }

  /// Memeriksa apakah bisnis saat ini menggunakan paket 'Free' / bukan Pro aktif & bukan Trial aktif.
  bool isFreePlan() {
    if (_business == null) return true;
    if (!_business.isFeatureGateEnabled) return false;
    return !isProPlan();
  }

  /// Memeriksa apakah bisnis memiliki akses ke fitur Pro (baik via Paid Pro maupun Trial Aktif).
  bool isProPlan() {
    if (_business == null) return false;
    if (!_business.isFeatureGateEnabled) return true;

    // 1. Cek apakah sedang dalam masa Uji Coba (Trial Pro) yang aktif
    if (isTrialActive()) return true;

    // 2. Cek apakah langganan Pro Berbayar aktif
    return isPaidProActive();
  }

  /// Memeriksa apakah masa Uji Coba (Trial Pro) sedang aktif.
  bool isTrialActive() {
    if (_business == null) return false;
    if (_business.subscriptionStatus != 'trial') return false;

    // Jika subscriptionEndAt == null -> Trial Selamanya (Lifetime Trial)
    if (_business.subscriptionEndAt == null) return true;

    return DateTime.now().isBefore(_business.subscriptionEndAt!);
  }

  /// Memeriksa apakah langganan Pro Berbayar (Official Paid Pro) aktif.
  bool isPaidProActive() {
    if (_business == null) return false;
    if (_business.subscriptionStatus == 'trial') return false;
    if (_business.subscriptionStatus == 'expired') return false;

    // Jika data plan hasil join ada, gunakan kodenya
    if (_business.plan != null) {
      final isProCode = _business.plan?.code == 'pro' ||
          _business.plan?.code == 'enterprise';
      if (!isProCode) return false;

      // Cek masa aktif: jika subscriptionEndAt == null -> LIFETIME (permanen aktif)
      if (_business.subscriptionEndAt == null) return true;

      return DateTime.now().isBefore(_business.subscriptionEndAt!);
    }

    // FALLBACK jika data join kosong tapi planId terisi
    if (_business.planId != null && _business.planId!.isNotEmpty) {
      if (_business.subscriptionEndAt != null) {
        return DateTime.now().isBefore(_business.subscriptionEndAt!);
      }
      return true;
    }

    return false;
  }
}
