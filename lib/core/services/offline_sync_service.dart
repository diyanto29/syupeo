import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';

final pendingSyncCountProvider = StateNotifierProvider<PendingSyncCountNotifier, int>((ref) {
  return PendingSyncCountNotifier();
});

class PendingSyncCountNotifier extends StateNotifier<int> {
  PendingSyncCountNotifier() : super(0) {
    refresh();
  }

  Future<void> refresh() async {
    final count = await LocalDatabaseService.instance.getPendingSyncCount();
    if (mounted) state = count;
  }
}

final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return !results.contains(ConnectivityResult.none);
  });
});

enum SyncStatus {
  success,
  partialSuccess,
  failed,
  offline,
  noPending,
}

class SyncResult {
  final SyncStatus status;
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;

  const SyncResult({
    required this.status,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
  });

  bool get isSuccess => status == SyncStatus.success;
  bool get isOffline => status == SyncStatus.offline;
}

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  WidgetRef? _cachedRef;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('no address associated with hostname') ||
        str.contains('network is unreachable') ||
        str.contains('handshakeexception') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('os error: no address');
  }

  static String humanizeError(dynamic error) {
    if (error == null) return 'Terjadi kesalahan tidak terduga';
    final str = error.toString().toLowerCase();
    if (isNetworkError(error)) {
      return 'Koneksi internet bermasalah atau server tidak dapat dijangkau. Perangkat masih dalam kondisi offline.';
    }
    if (str.contains('timeoutexception')) {
      return 'Koneksi internet terlalu lambat (waktu tunggu habis).';
    }
    if (str.contains('jwt') || str.contains('unauthorized')) {
      return 'Sesi login telah kedaluwarsa. Silakan periksa akun kasir.';
    }
    String clean = error.toString();
    if (clean.startsWith('Exception: ')) {
      clean = clean.substring(11);
    }
    return clean;
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? str) {
    if (str == null) return false;
    return _uuidRegex.hasMatch(str.trim());
  }

  void initialize(WidgetRef? ref) {
    if (ref != null) _cachedRef = ref;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      debugPrint('[OfflineSync] Connectivity changed. Online: $isOnline');
      if (isOnline) {
        syncPendingOrders(_cachedRef);
      }
    });

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      syncPendingOrders(_cachedRef);
    });

    // Initial check
    syncPendingOrders(_cachedRef);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  Future<SyncResult> syncPendingOrders([WidgetRef? ref]) async {
    if (ref != null) _cachedRef = ref;

    if (_isSyncing) {
      return const SyncResult(
        status: SyncStatus.failed,
        errorMessage: 'Proses sinkronisasi sedang berjalan.',
      );
    }

    // 1. Cek konektivitas terlebih dahulu
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isDisconnected = connectivity.contains(ConnectivityResult.none) ||
          connectivity.isEmpty ||
          connectivity.every((c) => c == ConnectivityResult.none);
      if (isDisconnected) {
        debugPrint('[OfflineSync] Currently offline, skipping sync.');
        return const SyncResult(
          status: SyncStatus.offline,
          errorMessage: 'Perangkat masih offline (tidak ada koneksi internet).',
        );
      }
    } catch (e) {
      return SyncResult(
        status: SyncStatus.offline,
        errorMessage: 'Gagal memeriksa koneksi: ${humanizeError(e)}',
      );
    }

    _isSyncing = true;
    int syncedCount = 0;
    int failedCount = 0;
    String? lastError;

    try {
      final pendingOrders = await LocalDatabaseService.instance.getPendingOrders();
      if (pendingOrders.isEmpty) {
        _isSyncing = false;
        return const SyncResult(
          status: SyncStatus.noPending,
          errorMessage: 'Semua transaksi lokal sudah tersinkronkan ke cloud.',
        );
      }

      debugPrint('[OfflineSync] Found ${pendingOrders.length} pending orders to sync.');
      final client = SupabaseService.client;

      for (final item in pendingOrders) {
        final orderMap = item['order'] as Map<String, dynamic>;
        final orderId = orderMap['id'] as String;
        final items = (item['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        final discounts = (item['discounts'] as List<dynamic>).cast<Map<String, dynamic>>();
        final payments = (item['payments'] as List<dynamic>).cast<Map<String, dynamic>>();

        try {
          // 1. Upsert order dengan timeout & auto-fallback jika column belum ada di schema cache Supabase
          Map<String, dynamic> currentOrderPayload = Map<String, dynamic>.from(orderMap);
          bool upserted = false;
          int retries = 0;
          while (!upserted && retries < 3) {
            try {
              await client.from('orders').upsert(currentOrderPayload).timeout(const Duration(seconds: 10));
              upserted = true;
            } on PostgrestException catch (e) {
              if (e.code == 'PGRST204' && retries < 2) {
                final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
                final missingCol = match?.group(1);
                if (missingCol != null && currentOrderPayload.containsKey(missingCol)) {
                  debugPrint('[OfflineSync] Column $missingCol not in schema, retrying order $orderId without it.');
                  currentOrderPayload.remove(missingCol);
                  retries++;
                  continue;
                } else if (currentOrderPayload.containsKey('dining_option')) {
                  debugPrint('[OfflineSync] Column dining_option not in schema, retrying order $orderId without it.');
                  currentOrderPayload.remove('dining_option');
                  retries++;
                  continue;
                }
              }
              rethrow;
            }
          }

          // 2. Clear & insert order items
          await client.from('order_items').delete().eq('order_id', orderId).timeout(const Duration(seconds: 10));
          if (items.isNotEmpty) {
            final sanitizedItems = items.map((m) {
              final copy = Map<String, dynamic>.from(m);
              final dId = copy['discount_id']?.toString();
              if (dId != null && !isValidUuid(dId)) {
                copy['discount_id'] = null;
              }
              return copy;
            }).toList();

            try {
              await client.from('order_items').insert(sanitizedItems).timeout(const Duration(seconds: 10));
            } on PostgrestException catch (e) {
              if (e.code == '23503' || e.code == '22P02') {
                // Fallback discount foreign key or invalid uuid
                final fallbackItems = sanitizedItems.map((m) {
                  final copy = Map<String, dynamic>.from(m);
                  copy['discount_id'] = null;
                  return copy;
                }).toList();
                await client.from('order_items').insert(fallbackItems).timeout(const Duration(seconds: 10));
              } else {
                rethrow;
              }
            }
          }

          // 3. Clear & insert discounts
          await client.from('order_discounts').delete().eq('order_id', orderId).timeout(const Duration(seconds: 10));
          if (discounts.isNotEmpty) {
            final sanitizedDiscounts = discounts.map((m) {
              final copy = Map<String, dynamic>.from(m);
              final dId = copy['discount_id']?.toString();
              if (dId != null && !isValidUuid(dId)) {
                copy['discount_id'] = null;
              }
              return copy;
            }).toList();

            try {
              await client.from('order_discounts').insert(sanitizedDiscounts).timeout(const Duration(seconds: 10));
            } on PostgrestException catch (e) {
              if (e.code == '23503' || e.code == '22P02') {
                final fallbackDiscounts = sanitizedDiscounts.map((m) {
                  final copy = Map<String, dynamic>.from(m);
                  copy['discount_id'] = null;
                  return copy;
                }).toList();
                await client.from('order_discounts').insert(fallbackDiscounts).timeout(const Duration(seconds: 10));
              } else {
                rethrow;
              }
            }
          }

          // 4. Clear & insert payments
          await client.from('order_payments').delete().eq('order_id', orderId).timeout(const Duration(seconds: 10));
          if (payments.isNotEmpty) {
            final sanitizedPayments = payments.map((m) {
              final copy = Map<String, dynamic>.from(m);
              final pmId = copy['payment_method_id']?.toString();
              // Jika payment_method_id bukan format UUID valid (seperti 'cash-default'), jadikan null
              if (pmId == null || !isValidUuid(pmId)) {
                copy['payment_method_id'] = null;
              }
              return copy;
            }).toList();

            try {
              await client.from('order_payments').insert(sanitizedPayments).timeout(const Duration(seconds: 10));
            } on PostgrestException catch (e) {
              if (e.code == '23503' || e.code == '22P02') {
                final fallbackPayments = sanitizedPayments.map((m) {
                  final copy = Map<String, dynamic>.from(m);
                  copy['payment_method_id'] = null;
                  return copy;
                }).toList();
                await client.from('order_payments').insert(fallbackPayments).timeout(const Duration(seconds: 10));
              } else {
                rethrow;
              }
            }
          }

          // Mark as synced locally!
          await LocalDatabaseService.instance.markOrderSynced(orderId);
          syncedCount++;
          debugPrint('[OfflineSync] Successfully synced order $orderId (${orderMap['invoice_number']})');
        } catch (e) {
          failedCount++;
          lastError = e.toString();
          debugPrint('[OfflineSync] Failed syncing order $orderId: $e');
          await LocalDatabaseService.instance.markOrderSyncFailed(orderId, e.toString());
        }
      }

      if (syncedCount > 0 && failedCount == 0) {
        return SyncResult(
          status: SyncStatus.success,
          syncedCount: syncedCount,
        );
      } else if (syncedCount > 0 && failedCount > 0) {
        return SyncResult(
          status: SyncStatus.partialSuccess,
          syncedCount: syncedCount,
          failedCount: failedCount,
          errorMessage: humanizeError(lastError),
        );
      } else {
        final isNet = isNetworkError(lastError);
        return SyncResult(
          status: isNet ? SyncStatus.offline : SyncStatus.failed,
          failedCount: failedCount,
          errorMessage: humanizeError(lastError),
        );
      }
    } catch (e) {
      debugPrint('[OfflineSync] Sync batch failed: $e');
      final isNet = isNetworkError(e);
      return SyncResult(
        status: isNet ? SyncStatus.offline : SyncStatus.failed,
        errorMessage: humanizeError(e),
      );
    } finally {
      _isSyncing = false;
      // Refresh pending sync counter
      final activeRef = ref ?? _cachedRef;
      if (activeRef != null) {
        activeRef.read(pendingSyncCountProvider.notifier).refresh();
      }
    }
  }
}
