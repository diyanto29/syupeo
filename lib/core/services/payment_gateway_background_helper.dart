import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper untuk mengontrol Android Foreground Service 24/7 dan Ignore Battery Optimizations
class PaymentGatewayBackgroundHelper {
  static const MethodChannel _channel = MethodChannel(
    'dpos/payment_gateway_service',
  );

  /// Menyalakan Foreground Service (hanya di Android)
  static Future<bool> startGatewayService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startGatewayService');
      return res ?? false;
    } catch (e) {
      debugPrint('[PaymentGatewayBackgroundHelper] startGatewayService error: $e');
      return false;
    }
  }

  /// Mematikan Foreground Service (hanya di Android)
  static Future<bool> stopGatewayService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>('stopGatewayService');
      return res ?? false;
    } catch (e) {
      debugPrint('[PaymentGatewayBackgroundHelper] stopGatewayService error: $e');
      return false;
    }
  }

  /// Cek apakah Foreground Service sedang aktif
  static Future<bool> isGatewayServiceRunning() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isGatewayServiceRunning');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Cek apakah aplikasi Syupeo sudah diizinkan bebas dari optimasi baterai Doze mode
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final res = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Buka dialog / menu pengaturan Android untuk meminta izin Tanpa Batas Baterai
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      return res ?? false;
    } catch (e) {
      debugPrint(
        '[PaymentGatewayBackgroundHelper] requestIgnoreBatteryOptimizations error: $e',
      );
      return false;
    }
  }
}
