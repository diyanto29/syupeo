import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service untuk menangani In-App Update (Non-Flexible / Immediate Update).
/// Mode Non-Flexible (Immediate) menampilkan UI pembaruan layar penuh dari Google Play
/// dan mewajibkan pengguna untuk memperbarui aplikasi sebelum dapat melanjutkan.
class InAppUpdateService {
  InAppUpdateService._();

  static bool _isChecking = false;

  /// Memeriksa pembaruan di Google Play Store dan langsung memulai Immediate Update jika tersedia.
  static Future<void> checkForImmediateUpdate() async {
    // In-App Update hanya didukung pada platform Android (Google Play)
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    if (_isChecking) {
      return;
    }
    _isChecking = true;

    try {
      debugPrint('[InAppUpdate] Memeriksa ketersediaan pembaruan di Play Store...');
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      debugPrint(
        '[InAppUpdate] Status: ${updateInfo.updateAvailability}, '
        'ImmediateAllowed: ${updateInfo.immediateUpdateAllowed}, '
        'AvailableVersionCode: ${updateInfo.availableVersionCode}',
      );

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          debugPrint('[InAppUpdate] Memulai Immediate (Non-Flexible) Update...');
          final AppUpdateResult result = await InAppUpdate.performImmediateUpdate();
          debugPrint('[InAppUpdate] Hasil Immediate Update: $result');
        } else {
          debugPrint('[InAppUpdate] Pembaruan tersedia, tetapi Immediate Update tidak diizinkan oleh Google Play.');
        }
      } else {
        debugPrint('[InAppUpdate] Aplikasi sudah versi terbaru.');
      }
    } catch (e) {
      // Catatan: In-App Update akan throw error jika aplikasi dijalankan via debug/sideload
      // (bukan diunduh langsung dari Play Store). Exception ini ditangkap agar tidak mengganggu flow app.
      debugPrint('[InAppUpdate] Pengecekan dilewati atau gagal: $e');
    } finally {
      _isChecking = false;
    }
  }
}
