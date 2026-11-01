import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
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
    if (str.contains('42501') || str.contains('row-level security') || str.contains('forbidden')) {
      return 'Izin keamanan Supabase (RLS) menolak transaksi kasir. Silakan jalankan script SQL perbaikan RLS di Supabase SQL Editor.';
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

  /// Helper upsert order dengan auto-healing skema (menghapus kolom yang belum ada di PostgREST)
  static Future<void> safeUpsertOrder({
    required SupabaseClient client,
    required Map<String, dynamic> rawOrder,
    int maxRetries = 20,
  }) async {
    Map<String, dynamic> currentPayload = Map<String, dynamic>.from(rawOrder);
    currentPayload.removeWhere((k, v) => v == null && k != 'id');
    currentPayload = currentPayload.map((k, v) {
      if (v is num && (v.truncateToDouble() == v)) {
        return MapEntry(k, v.round());
      }
      return MapEntry(k, v);
    });

    bool upserted = false;
    int retries = 0;
    while (!upserted && retries < maxRetries) {
      try {
        await client.from('orders').upsert(currentPayload).timeout(const Duration(seconds: 10));
        upserted = true;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204' && retries < maxRetries - 1) {
          final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
          final missingCol = match?.group(1);
          if (missingCol != null) {
            debugPrint('[orders] Auto-healing: column $missingCol not in schema, stripping & retrying.');
            currentPayload.removeWhere((k, _) => k.toLowerCase() == missingCol.toLowerCase());
            retries++;
            continue;
          }
        } else if ((e.code == '23503' || e.code == '22P02') && retries < maxRetries - 1) {
          debugPrint('[orders] Foreign key or UUID error (${e.code}), clearing optional _id references.');
          for (final k in ['cashier_id', 'waiter_id', 'voided_by']) {
            currentPayload.remove(k);
          }
          retries++;
          continue;
        }
        rethrow;
      }
    }
  }

  /// Helper insert list tabel anak (order_items, order_discounts, order_payments) dengan auto-healing skema
  static Future<void> safeInsertList({
    required SupabaseClient client,
    required String table,
    required List<Map<String, dynamic>> rawRows,
    int maxRetries = 20,
  }) async {
    if (rawRows.isEmpty) return;

    List<Map<String, dynamic>> currentRows = rawRows.map((row) {
      final copy = Map<String, dynamic>.from(row);
      // Buang semua field bernilai null agar PostgREST tidak memeriksa kolom opsional yang tidak ada di skema
      copy.removeWhere((k, v) => v == null && k != 'id');
      return copy.map((k, v) {
        if (v is num && (v.truncateToDouble() == v)) {
          return MapEntry(k, v.round());
        }
        return MapEntry(k, v);
      });
    }).toList();

    bool inserted = false;
    int retries = 0;

    while (!inserted && retries < maxRetries) {
      try {
        await client.from(table).insert(currentRows).timeout(const Duration(seconds: 10));
        inserted = true;
      } on PostgrestException catch (e) {
        if ((e.code == 'PGRST204' || e.message.contains("Could not find the '")) && retries < maxRetries - 1) {
          final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
          final missingCol = match?.group(1);
          if (missingCol != null) {
            debugPrint('[$table] Auto-healing: column $missingCol not in schema, stripping & retrying.');
            currentRows = currentRows.map((m) {
              final copy = Map<String, dynamic>.from(m);
              copy.removeWhere((k, _) => k.toLowerCase() == missingCol.toLowerCase());
              // Khusus tabel order_payments: jika payment_method hilang atau belum ada, pastikan selalu ada fallback
              if (table == 'order_payments' && (!copy.containsKey('payment_method') || copy['payment_method'] == null)) {
                copy['payment_method'] = copy['method_name'] ?? copy['method_type'] ?? 'Tunai';
              }
              return copy;
            }).toList();
            retries++;
            continue;
          }
        } else if (e.code == '23502' && retries < maxRetries - 1) {
          // NOT NULL constraint violation (misalnya payment_method)
          debugPrint('[$table] Auto-healing: Not-null constraint hit (${e.message}), providing fallback defaults.');
          currentRows = currentRows.map((m) {
            final copy = Map<String, dynamic>.from(m);
            if (table == 'order_payments') {
              copy['payment_method'] ??= copy['method_name'] ?? copy['method_type'] ?? 'Tunai';
            }
            return copy;
          }).toList();
          retries++;
          continue;
        } else if ((e.code == '23503' || e.code == '22P02') && retries < maxRetries - 1) {
          debugPrint('[$table] Foreign key or UUID error (${e.code}), clearing optional _id references.');
          currentRows = currentRows.map((m) {
            final copy = Map<String, dynamic>.from(m);
            copy.removeWhere((k, _) => k.endsWith('_id') && k != 'id' && k != 'order_id');
            return copy;
          }).toList();
          retries++;
          continue;
        }
        rethrow;
      }
    }
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
      final activeRef = ref ?? _cachedRef;
      final bootstrap = activeRef?.read(homeBootstrapProvider).valueOrNull;
      final activeOutletId = bootstrap?.currentOutlet?.id;
      final activeBusinessId = bootstrap?.business?.id;

      for (final item in pendingOrders) {
        final orderMap = item['order'] as Map<String, dynamic>;
        final orderId = orderMap['id'] as String;
        final items = (item['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        final discounts = (item['discounts'] as List<dynamic>).cast<Map<String, dynamic>>();
        final payments = (item['payments'] as List<dynamic>).cast<Map<String, dynamic>>();

        try {
          // Siapkan payload order yang bersih & valid
          Map<String, dynamic> currentOrderPayload = Map<String, dynamic>.from(orderMap);
          currentOrderPayload.removeWhere((k, v) => v == null && k != 'id');

          // Fallback outlet_id & business_id aktif jika di local order kosong atau bukan valid UUID
          if ((currentOrderPayload['outlet_id'] == null || !isValidUuid(currentOrderPayload['outlet_id']?.toString())) && activeOutletId != null) {
            currentOrderPayload['outlet_id'] = activeOutletId;
          }
          if ((currentOrderPayload['business_id'] == null || !isValidUuid(currentOrderPayload['business_id']?.toString())) && activeBusinessId != null) {
            currentOrderPayload['business_id'] = activeBusinessId;
          }

          // Bersihkan relasi UUID opsional jika nilainya string non-UUID
          for (final key in ['cashier_id', 'waiter_id', 'voided_by']) {
            if (currentOrderPayload[key] != null && !isValidUuid(currentOrderPayload[key]?.toString())) {
              currentOrderPayload.remove(key);
            }
          }

          // Normalisasi seluruh angka bulat agar tidak memicu 22P02 jika kolom bertipe integer di Postgres
          currentOrderPayload = currentOrderPayload.map((k, v) {
            if (v is num && (v.truncateToDouble() == v)) {
              return MapEntry(k, v.round());
            }
            return MapEntry(k, v);
          });

          // Kolom resmi tabel order_items di PostgreSQL Supabase
          const allowedOrderItemKeys = {
            'id',
            'order_id',
            'menu_item_id',
            'variant_id',
            'name',
            'variant_name',
            'quantity',
            'unit_price',
            'cost_price',
            'subtotal',
            'notes',
            'created_at',
          };

          // Sanitasi items
          final sanitizedItems = items.map((m) {
            final copy = Map<String, dynamic>.from(m);
            // Hapus kolom non-resmi order_items (seperti discount_type, discount_name, dll.)
            copy.removeWhere((k, _) => !allowedOrderItemKeys.contains(k));
            if (copy['variant_id'] != null && !isValidUuid(copy['variant_id']?.toString())) {
              copy['variant_id'] = null;
            }
            if (copy['menu_item_id'] != null && !isValidUuid(copy['menu_item_id']?.toString())) {
              copy['menu_item_id'] = null;
            }
            return copy.map((k, v) {
              if (v is num && (v.truncateToDouble() == v)) {
                return MapEntry(k, v.round());
              }
              return MapEntry(k, v);
            });
          }).toList();

          // Kolom resmi tabel order_discounts
          const allowedOrderDiscountKeys = {
            'id',
            'order_id',
            'discount_id',
            'name',
            'type',
            'percentage_value',
            'amount_value',
            'max_discount_amount',
            'applied_amount',
            'created_at',
          };

          // Sanitasi discounts
          final sanitizedDiscounts = discounts.map((m) {
            final copy = Map<String, dynamic>.from(m);
            copy.removeWhere((k, _) => !allowedOrderDiscountKeys.contains(k));
            final dId = copy['discount_id']?.toString();
            if (dId != null && !isValidUuid(dId)) {
              copy['discount_id'] = null;
            }
            return copy.map((k, v) {
              if (v is num && (v.truncateToDouble() == v)) {
                return MapEntry(k, v.round());
              }
              return MapEntry(k, v);
            });
          }).toList();

          // Kolom yang didukung tabel order_payments (backward & forward compatible)
          const allowedOrderPaymentKeys = {
            'id',
            'order_id',
            'payment_method',
            'payment_method_id',
            'method_name',
            'method_type',
            'amount',
            'reference_number',
            'created_at',
          };

          // Sanitasi payments
          final sanitizedPayments = payments.map((m) {
            final copy = Map<String, dynamic>.from(m);
            // 1. Pastikan payment_method selalu terisi untuk backward-compatibility dengan skema Postgres
            copy['payment_method'] ??= copy['method_name'] ?? copy['method_type'] ?? 'Tunai';

            // 2. Filter key resmi
            copy.removeWhere((k, _) => !allowedOrderPaymentKeys.contains(k));

            // 3. Buang payment_method_id jika null atau bukan UUID valid
            final pmId = copy['payment_method_id']?.toString();
            if (pmId == null || !isValidUuid(pmId)) {
              copy.remove('payment_method_id');
            }
            if (copy['reference_number'] == null) {
              copy.remove('reference_number');
            }

            return copy.map((k, v) {
              if (v is num && (v.truncateToDouble() == v)) {
                return MapEntry(k, v.round());
              }
              return MapEntry(k, v);
            });
          }).toList();

          // TAHAP A: Coba panggil RPC rpc_sync_offline_order (SECURITY DEFINER, bypass RLS secara aman di PostgreSQL)
          bool syncedViaRpc = false;
          try {
            final rpcRes = await client.rpc(
              'rpc_sync_offline_order',
              params: {
                'p_order': currentOrderPayload,
                'p_items': sanitizedItems,
                'p_discounts': sanitizedDiscounts,
                'p_payments': sanitizedPayments,
              },
            ).timeout(const Duration(seconds: 10));

            if (rpcRes is Map && rpcRes['success'] == true) {
              syncedViaRpc = true;
              debugPrint('[OfflineSync] Order $orderId synced successfully via RPC.');
            } else if (rpcRes is Map && rpcRes['error'] != null) {
              debugPrint('[OfflineSync] RPC returned error: ${rpcRes['error']}');
            }
          } catch (rpcErr) {
            debugPrint('[OfflineSync] RPC unavailable or returned note: $rpcErr');
          }

          // TAHAP B: Fallback langsung ke tabel orders jika RPC belum dipasang di Supabase
          if (!syncedViaRpc) {
            // 1. Upsert order dengan auto-healing
            await safeUpsertOrder(
              client: client,
              rawOrder: currentOrderPayload,
            );

            // 2. Clear & insert order items dengan auto-healing
            await client.from('order_items').delete().eq('order_id', orderId).timeout(const Duration(seconds: 10));
            if (sanitizedItems.isNotEmpty) {
              await safeInsertList(
                client: client,
                table: 'order_items',
                rawRows: sanitizedItems,
              );
            }

            // 3. Clear & insert discounts dengan auto-healing
            try {
              await client.from('order_discounts').delete().eq('order_id', orderId).timeout(const Duration(seconds: 10));
              if (sanitizedDiscounts.isNotEmpty) {
                await safeInsertList(
                  client: client,
                  table: 'order_discounts',
                  rawRows: sanitizedDiscounts,
                );
              }
            } catch (e) {
              debugPrint('[OfflineSync] Non-critical discounts sync warning: $e');
            }

            // 4. Clear & insert payments dengan auto-healing
            await client.from('order_payments').delete().eq('order_id', orderId).timeout(const Duration(seconds: 10));
            if (sanitizedPayments.isNotEmpty) {
              await safeInsertList(
                client: client,
                table: 'order_payments',
                rawRows: sanitizedPayments,
              );
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
