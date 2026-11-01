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

  /// Menghasilkan true jika fitur diizinkan (Seluruh fitur Syupeo kini 100% Free & Terbuka).
  bool isEnabled(String featureKey) {
    if (_business == null) return false;

    // Cek jika ada konfigurasi yang dimatikan spesifik 'off'
    var config = _business.featuresConfig[featureKey];
    if (config == 'off') return false;

    // Semua fitur (pos, kasir, cash_flow, reports, inventori, debt, dll) 100% gratis
    return true;
  }

  /// Menghasilkan batas (limit) tertentu berdasarkan paket aktif (unlimited).
  int getLimit(String limitKey, {int defaultValue = 0}) {
    return 999999999;
  }

  /// Memeriksa apakah iklan harus ditampilkan.
  /// Seluruh mitra toko Syupeo bebas iklan.
  bool shouldShowAds() => false;

  /// Seluruh mitra toko kini mendapatkan akses penuh (bebas batasan).
  bool isFreePlan() => false;

  /// Memeriksa apakah bisnis memiliki akses ke seluruh fitur (selalu true).
  bool isProPlan() => true;

  /// Memeriksa apakah masa Uji Coba (Trial Pro) sedang aktif.
  bool isTrialActive() => false;

  /// Memeriksa apakah langganan Pro Berbayar aktif.
  bool isPaidProActive() => true;
}
