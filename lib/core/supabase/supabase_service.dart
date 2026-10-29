import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  static bool get isConfigured => SupabaseConfig.isConfigured;

  static Session? get currentSession =>
      isConfigured ? client.auth.currentSession : null;

  static User? get currentUser => isConfigured ? client.auth.currentUser : null;

  static bool get isLoggedIn => currentSession != null;

  static Future<void> sendPhoneOtp({
    required String phone,
    bool shouldCreateUser = true,
  }) async {
    await client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: shouldCreateUser,
    );
  }

  static Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    return client.auth.verifyOTP(type: OtpType.sms, phone: phone, token: token);
  }

  static Future<void> signOut() {
    return client.auth.signOut();
  }

  static bool isLikelyTransientNetworkError(Object error) {
    if (error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('clientexception') ||
        message.contains('connection closed') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('koneksi internet') ||
        message.contains('xmlhttprequest error') ||
        message.contains('authretryablefetchexception');
  }

  static bool isJwtExpiredError(Object error) {
    if (error is PostgrestException) {
      if (error.code == 'PGRST303') return true;
      final msg = error.message.toLowerCase();
      if (msg.contains('jwt expired') || msg.contains('jwt invalid')) return true;
    }
    final str = error.toString().toLowerCase();
    return str.contains('jwt expired') || str.contains('pgrst303');
  }

  static Future<bool> ensureFreshSession() async {
    if (!isConfigured) return false;
    try {
      final session = client.auth.currentSession;
      if (session == null) return false;
      if (session.isExpired) {
        final res = await client.auth.refreshSession();
        return res.session != null;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<T> withAutoRefresh<T>(Future<T> Function() operation) async {
    try {
      if (isConfigured) {
        final session = client.auth.currentSession;
        if (session != null && session.isExpired) {
          try {
            await client.auth.refreshSession();
          } catch (_) {}
        }
      }
      return await operation();
    } catch (error) {
      if (isJwtExpiredError(error)) {
        try {
          final res = await client.auth.refreshSession();
          if (res.session != null) {
            return await operation();
          }
        } catch (_) {}
      }
      rethrow;
    }
  }
}

/// Extension to enforce sensible timeouts on network queries,
/// preventing infinite spinners on unstable/dropping cellular/WiFi networks.
extension NetworkTimeoutGuard<T> on Future<T> {
  Future<T> withNetworkTimeout({
    Duration duration = const Duration(seconds: 15),
    String? operationName,
  }) {
    return timeout(
      duration,
      onTimeout: () {
        throw TimeoutException(
          'Koneksi internet lambat atau terputus${operationName != null ? " saat $operationName" : ""}. Silakan periksa jaringan Anda.',
        );
      },
    );
  }
}
