import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

enum CatalogSyncStatus {
  idle,
  syncing,
  completed,
  error,
}

class CatalogSyncState {
  const CatalogSyncState({
    this.status = CatalogSyncStatus.idle,
    this.downloadedCount = 0,
    this.totalCount = 0,
    this.currentStep = 'Siap',
    this.lastSyncedAt,
    this.errorMessage,
  });

  final CatalogSyncStatus status;
  final int downloadedCount;
  final int totalCount;
  final String currentStep;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  bool get isSyncing => status == CatalogSyncStatus.syncing;
  bool get isCompleted => status == CatalogSyncStatus.completed;
  bool get isError => status == CatalogSyncStatus.error;

  double get progress {
    if (totalCount <= 0) return 0.0;
    return (downloadedCount / totalCount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).toInt();

  CatalogSyncState copyWith({
    CatalogSyncStatus? status,
    int? downloadedCount,
    int? totalCount,
    String? currentStep,
    DateTime? lastSyncedAt,
    String? errorMessage,
  }) {
    return CatalogSyncState(
      status: status ?? this.status,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      totalCount: totalCount ?? this.totalCount,
      currentStep: currentStep ?? this.currentStep,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ProductCatalogSyncService extends StateNotifier<CatalogSyncState> {
  ProductCatalogSyncService(this._supabase) : super(const CatalogSyncState());

  final SupabaseClient _supabase;
  bool _isRunning = false;

  static const String _selectFields =
      '*, menu_category:menu_categories!menu_items_category_id_fkey(*), menu_item_variants(*), menu_item_tiered_prices(*)';

  /// Inisialisasi awal saat toko terbuka
  Future<void> initializeForBusiness(String businessId, [String? outletId]) async {
    // 1. Cek berapa produk yang sudah tersimpan di SQLite lokal saat ini
    final localCount = await LocalDatabaseService.instance.getMenuItemCount(businessId);
    final lastSyncStr = await LocalDatabaseService.instance.getKeyValue('last_catalog_sync_$businessId');
    final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

    if (localCount > 0) {
      state = state.copyWith(
        status: CatalogSyncStatus.completed,
        downloadedCount: localCount,
        totalCount: localCount,
        currentStep: 'Database lokal siap ($localCount produk)',
        lastSyncedAt: lastSync,
      );
    }

    // 2. Jalankan sinkronisasi background di balik layar tanpa memblokir kasir
    unawaited(syncCatalog(businessId, outletId: outletId));
  }

  /// Eksekusi proses unduh katalog produk secara bertahap (Chunked Download)
  Future<void> syncCatalog(String businessId, {String? outletId, bool forceFull = false}) async {
    if (_isRunning) {
      debugPrint('[CatalogSync] Sync already in progress, skipping request.');
      return;
    }

    _isRunning = true;

    try {
      // 1. Cek Konektivitas
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);

      if (isOffline) {
        final localCount = await LocalDatabaseService.instance.getMenuItemCount(businessId);
        state = state.copyWith(
          status: CatalogSyncStatus.completed,
          downloadedCount: localCount,
          totalCount: localCount,
          currentStep: 'Mode Offline: $localCount produk siap di lokal',
        );
        _isRunning = false;
        return;
      }

      state = state.copyWith(
        status: CatalogSyncStatus.syncing,
        currentStep: 'Menyiapkan database lokal...',
        downloadedCount: 0,
      );

      // 2. Sinkronkan Kategori Terlebih Dahulu
      state = state.copyWith(currentStep: 'Menyinkronkan kategori...');
      try {
        final catRes = await _supabase
            .from('menu_categories')
            .select('*')
            .eq('business_id', businessId)
            .order('visual_index', ascending: true);

        final categories = (catRes as List<dynamic>)
            .map((json) => MenuCatalogCategory.fromJson(json as Map<String, dynamic>))
            .toList();

        await LocalDatabaseService.instance.saveMenuCategories(businessId, categories);
      } catch (e) {
        debugPrint('[CatalogSync] Warning: Failed to sync categories: $e');
      }

      // 3. Sinkronkan Metode Pembayaran (jika outletId ada)
      if (outletId != null && outletId.isNotEmpty) {
        try {
          final pmRes = await _supabase
              .from('outlet_payment_methods')
              .select('*')
              .eq('outlet_id', outletId)
              .eq('is_active', true);

          final paymentMethods = (pmRes as List<dynamic>)
              .map((json) => PaymentMethodOption.fromJson(json as Map<String, dynamic>))
              .toList();

          await LocalDatabaseService.instance.savePaymentMethods(outletId, paymentMethods);
        } catch (e) {
          debugPrint('[CatalogSync] Warning: Failed to sync payment methods: $e');
        }
      }

      // 4. Hitung Total Produk di Supabase (Head Count Query)
      state = state.copyWith(currentStep: 'Menghitung total produk...');
      final countRes = await _supabase
          .from('menu_items')
          .select('id')
          .eq('business_id', businessId)
          .count(CountOption.exact);

      final totalItems = countRes.count;

      if (totalItems == 0) {
        state = state.copyWith(
          status: CatalogSyncStatus.completed,
          totalCount: 0,
          downloadedCount: 0,
          currentStep: 'Katalog kosong',
          lastSyncedAt: DateTime.now(),
        );
        _isRunning = false;
        return;
      }

      state = state.copyWith(
        totalCount: totalItems,
        currentStep: 'Mengunduh produk (0 / $totalItems)...',
      );

      // 5. Unduh Produk dengan Chunked Paging (500 per batch)
      const int batchSize = 500;
      int downloaded = 0;

      while (downloaded < totalItems) {
        final from = downloaded;
        final to = math.min(downloaded + batchSize - 1, totalItems - 1);

        state = state.copyWith(
          currentStep: 'Mengunduh produk (${downloaded + 1} - ${to + 1} / $totalItems)...',
          downloadedCount: downloaded,
        );

        List<dynamic> rawRows;
        try {
          final response = await _supabase
              .from('menu_items')
              .select(_selectFields)
              .eq('business_id', businessId)
              .order('name', ascending: true)
              .range(from, to);
          rawRows = response as List<dynamic>;
        } catch (e) {
          debugPrint('[CatalogSync] Relational fetch failed ($e), falling back to simple select...');
          final response = await _supabase
              .from('menu_items')
              .select('*')
              .eq('business_id', businessId)
              .order('name', ascending: true)
              .range(from, to);
          rawRows = response as List<dynamic>;
        }

        final items = rawRows
            .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
            .toList();

        if (items.isEmpty) break;

        // Tulis langsung ke SQLite lokal via Batch
        await LocalDatabaseService.instance.saveMenuItems(items);
        downloaded += items.length;

        state = state.copyWith(
          downloadedCount: downloaded,
          currentStep: 'Menyimpan ke SQLite ($downloaded / $totalItems)...',
        );
      }

      // 6. Simpan waktu sinkronisasi berhasil
      final now = DateTime.now();
      await LocalDatabaseService.instance.setKeyValue(
        'last_catalog_sync_$businessId',
        now.toIso8601String(),
      );

      state = state.copyWith(
        status: CatalogSyncStatus.completed,
        downloadedCount: downloaded,
        totalCount: totalItems,
        currentStep: '✓ Database offline siap ($downloaded produk)',
        lastSyncedAt: now,
      );

      debugPrint('[CatalogSync] Successfully synced $downloaded / $totalItems products to local SQLite.');
    } catch (e) {
      debugPrint('[CatalogSync] Error syncing catalog: $e');
      final localCount = await LocalDatabaseService.instance.getMenuItemCount(businessId);
      state = state.copyWith(
        status: localCount > 0 ? CatalogSyncStatus.completed : CatalogSyncStatus.error,
        downloadedCount: localCount,
        currentStep: localCount > 0
            ? '✓ Database lokal siap ($localCount produk tersimpan)'
            : 'Gagal sinkronisasi produk',
        errorMessage: e.toString(),
      );
    } finally {
      _isRunning = false;
    }
  }
}

/// Riverpod provider untuk ProductCatalogSyncService
final productCatalogSyncProvider =
    StateNotifierProvider<ProductCatalogSyncService, CatalogSyncState>((ref) {
  final supabase = SupabaseService.client;
  return ProductCatalogSyncService(supabase);
});
