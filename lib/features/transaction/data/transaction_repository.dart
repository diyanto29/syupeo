import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/analytics_outlet_filter_provider.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/services/offline_sync_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/transaction_models.dart';

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;

  /// Generate invoice number via server function with offline fallback.
  Future<String> generateInvoiceNumber(String outletId) async {
    try {
      final result = await _client
          .rpc(
            'generate_invoice_number',
            params: {'target_outlet_id': outletId},
          )
          .timeout(const Duration(milliseconds: 2500));
      return result as String;
    } catch (e) {
      debugPrint('[TransactionRepo] Server invoice RPC failed or timed out ($e), using local invoice generator.');
      return await LocalDatabaseService.instance.getNextLocalInvoiceNumber(outletId);
    }
  }

  /// Fetch active payment methods for an outlet with offline cache.
  Future<List<PaymentMethodOption>> getPaymentMethods(String outletId) async {
    // 1. Cek offline dulu: jika sedang offline dan ada data di SQLite, return dalam 0ms!
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final localMethods = await LocalDatabaseService.instance.getPaymentMethods(outletId);
        if (localMethods.isNotEmpty) {
          debugPrint('[TransactionRepo] Offline mode: loaded ${localMethods.length} payment methods from SQLite in 0ms');
          return localMethods;
        }
      }
    } catch (_) {}

    try {
      final response = await _client
          .from('outlet_payment_methods')
          .select()
          .eq('outlet_id', outletId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .timeout(const Duration(seconds: 2));

      final methods = (response as List<dynamic>)
          .map(
            (json) => PaymentMethodOption.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      // Cache to local SQLite for offline use
      await LocalDatabaseService.instance.savePaymentMethods(outletId, methods);
      return methods;
    } catch (e) {
      debugPrint('[TransactionRepo] Failed fetching online payment methods ($e), reading local cache.');
      final cached = await LocalDatabaseService.instance.getPaymentMethods(outletId);
      if (cached.isNotEmpty) {
        return cached;
      }
      // Fallback default cash method jika belum sempat tersinkron agar kasir tetap bisa checkout offline
      return const [
        PaymentMethodOption(
          id: 'cash_default',
          code: 'cash',
          name: 'Tunai',
          type: 'cash',
          isActive: true,
          sortOrder: 0,
          requiresReference: false,
          allowsChange: true,
        ),
      ];
    }
  }

  /// Save a full transaction (order + items + discounts).
  /// Local-first guarantee: saves to local SQLite first, then attempts cloud sync.
  Future<TransactionOrder> saveTransaction(
    TransactionOrder order, {
    required List<TransactionItem> items,
    required List<TransactionDiscount> discounts,
    List<TransactionPayment>? payments,
  }) async {
    // 1. SAVE TO LOCAL SQLITE (Guaranteed 0-latency and offline resilient)
    await LocalDatabaseService.instance.saveLocalOrder(
      order,
      items: items,
      discounts: discounts,
      payments: payments,
      syncStatus: 'pending',
    );

    // 2. ATTEMPT IMMEDIATE CLOUD SYNC
    bool cloudSynced = false;
    try {
      // Upsert order dengan auto-fallback jika column belum ada di schema cache Supabase
      Map<String, dynamic> currentOrderPayload = order.toOrderJson();
      currentOrderPayload.removeWhere((k, v) => v == null && k != 'id');
      currentOrderPayload = currentOrderPayload.map((k, v) {
        if (v is num && (v.truncateToDouble() == v)) {
          return MapEntry(k, v.round());
        }
        return MapEntry(k, v);
      });

      const allowedOrderItemKeys = {
        'id',
        'order_id',
        'menu_item_id',
        'variant_id',
        'name',
        'variant_name',
        'quantity',
        'unit_price',
        'subtotal',
        'notes',
        'created_at',
      };

      final itemsPayload = items.map((item) {
        final map = item.toJson(order.id);
        map.removeWhere((k, _) => !allowedOrderItemKeys.contains(k));
        return map;
      }).toList();
      final discountsPayload = discounts.map((disc) => disc.toJson(order.id)).toList();
      final paymentsPayload = (payments ?? []).map((pay) => pay.toJson(order.id)).toList();

      // TAHAP A: Coba panggil RPC rpc_sync_offline_order (SECURITY DEFINER, bypass RLS secara aman)
      try {
        final rpcRes = await _client.rpc('rpc_sync_offline_order', params: {
          'p_order': currentOrderPayload,
          'p_items': itemsPayload,
          'p_discounts': discountsPayload,
          'p_payments': paymentsPayload,
        }).timeout(const Duration(seconds: 10));

        if (rpcRes is Map && rpcRes['success'] == true) {
          cloudSynced = true;
          debugPrint('[TransactionRepo] Order ${order.id} synced immediately via RPC');
        }
      } catch (e) {
        debugPrint('[TransactionRepo] RPC unavailable or note: $e');
      }

      // TAHAP B: Fallback langsung ke tabel jika RPC belum dipasang
      if (!cloudSynced) {
        await OfflineSyncService.safeUpsertOrder(
          client: _client,
          rawOrder: currentOrderPayload,
        );

        // Delete existing items / discounts / payments and re-insert
        await _client.from('order_items').delete().eq('order_id', order.id);
        if (itemsPayload.isNotEmpty) {
          await OfflineSyncService.safeInsertList(
            client: _client,
            table: 'order_items',
            rawRows: itemsPayload,
          );
        }

        try {
          await _client.from('order_discounts').delete().eq('order_id', order.id);
          if (discountsPayload.isNotEmpty) {
            await OfflineSyncService.safeInsertList(
              client: _client,
              table: 'order_discounts',
              rawRows: discountsPayload,
            );
          }
        } catch (_) {}

        if (paymentsPayload.isNotEmpty) {
          await _client.from('order_payments').delete().eq('order_id', order.id);
          await OfflineSyncService.safeInsertList(
            client: _client,
            table: 'order_payments',
            rawRows: paymentsPayload,
          );
        }
      }

      // Auto-deduct stock and recipe ingredients if order is paid
      if (order.status == TransactionStatus.paid && items.isNotEmpty) {
        unawaited(_deductIngredientsAndStock(order, items));
      }

      // Mark locally as synced
      await LocalDatabaseService.instance.markOrderSynced(order.id);
      cloudSynced = true;
    } catch (e) {
      debugPrint('[TransactionRepo] Cloud sync deferred (offline/network issue): $e');
      await LocalDatabaseService.instance.markOrderSyncFailed(order.id, e.toString());
    }

    // 3. RETURN SAVED ORDER
    if (cloudSynced) {
      try {
        return await getOrder(order.id);
      } catch (_) {}
    }

    return order.copyWith(
      items: items,
      discounts: discounts,
      payments: payments ?? [],
    );
  }

  Future<void> _deductIngredientsAndStock(
    TransactionOrder order,
    List<TransactionItem> items,
  ) async {
    for (final item in items) {
      final menuItemId = item.menuItemId;
      if (menuItemId == null || menuItemId.isEmpty) continue;

      try {
        // 1. Direct menu_item stock deduction if tracking is enabled
        final menuData = await _client
            .from('menu_items')
            .select('track_stock_quantity, stock_quantity')
            .eq('id', menuItemId)
            .maybeSingle();

        if (menuData != null && menuData['track_stock_quantity'] == true) {
          final current = (menuData['stock_quantity'] as num?)?.toInt() ?? 0;
          final updated = current - item.quantity;
          await _client
              .from('menu_items')
              .update({'stock_quantity': updated})
              .eq('id', menuItemId);

          await _client.from('inventory_movements').insert({
            'business_id': order.businessId,
            'outlet_id': order.outletId,
            'menu_item_id': menuItemId,
            'movement_type': 'sale',
            'quantity_before': current,
            'quantity_delta': -item.quantity,
            'quantity_after': updated,
            'note': 'Penjualan Kasir POS: ${order.invoiceNumber}',
            'reference_type': 'order',
            'reference_id': order.id,
            'performed_by_user_id': _client.auth.currentUser?.id,
          });
        }

        // 2. Recipe BOM raw materials deduction (mendukung resep varian khusus atau resep default)
        final allRecipesRes = await _client
            .from('menu_item_recipes')
            .select('ingredient_id, quantity_required, variant_id')
            .eq('menu_item_id', menuItemId);

        final allRecipes = allRecipesRes as List<dynamic>;
        List<dynamic> targetRecipes = [];
        if (item.variantId != null && item.variantId!.isNotEmpty) {
          final variantRecipes = allRecipes.where((r) => r['variant_id'] == item.variantId).toList();
          if (variantRecipes.isNotEmpty) {
            targetRecipes = variantRecipes;
          } else {
            targetRecipes = allRecipes.where((r) => r['variant_id'] == null).toList();
          }
        } else {
          targetRecipes = allRecipes.where((r) => r['variant_id'] == null).toList();
        }

        for (final r in targetRecipes) {
          final ingId = r['ingredient_id'] as String;
          final qtyReq = (r['quantity_required'] as num?)?.toDouble() ?? 0.0;
          final totalNeeded = qtyReq * item.quantity;

          final ingData = await _client
              .from('inventory_ingredients')
              .select('current_stock')
              .eq('id', ingId)
              .maybeSingle();

          if (ingData != null) {
            final currentIngStock = (ingData['current_stock'] as num?)?.toDouble() ?? 0.0;
            final updatedIngStock = currentIngStock - totalNeeded;

            await _client.from('inventory_ingredients').update({
              'current_stock': updatedIngStock,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', ingId);

            await _client.from('ingredient_movements').insert({
              'business_id': order.businessId,
              'outlet_id': order.outletId,
              'ingredient_id': ingId,
              'movement_type': 'out_recipe_deduction',
              'quantity_delta': -totalNeeded,
              'balance_after': updatedIngStock,
              'note': 'Pengurangan resep POS: ${item.name} (x${item.quantity})',
              'reference_id': order.id,
              'performed_by': _client.auth.currentUser?.id,
            });
          }
        }
      } catch (_) {
        // Silently capture errors so pos checkout is never blocked
      }
    }
  }

  /// Get a single order with all relations.
  Future<TransactionOrder> getOrder(String orderId) async {
    final response = await _client
        .from('orders')
        .select('*, order_items(*), order_payments(*)')
        .eq('id', orderId)
        .single();

    return TransactionOrder.fromJson(response);
  }

  /// List orders for an outlet (or multiple outlets).
  Future<List<TransactionOrder>> getOrders(
    String? outletId, {
    List<String>? outletIds,
    TransactionStatus? status,
    OrderSource? orderSource,
    String? cashierId,
    String? waiterId,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('orders')
        .select('*, order_items(*), order_payments(*)');

    if (outletId != null) {
      query = query.eq('outlet_id', outletId);
    } else if (outletIds != null && outletIds.isNotEmpty) {
      query = query.inFilter('outlet_id', outletIds);
    }

    if (status != null) {
      query = query.eq('status', status.dbValue);
    }

    if (orderSource != null) {
      query = query.eq('order_source', orderSource.dbValue);
    }

    if (cashierId != null && cashierId.isNotEmpty) {
      query = query.eq('cashier_id', cashierId);
    }

    if (waiterId != null && waiterId.isNotEmpty) {
      query = query.eq('waiter_id', waiterId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('invoice_number', '%$searchQuery%');
    }

    try {
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .withNetworkTimeout(operationName: 'memuat daftar transaksi');

      final remoteOrders = (response as List<dynamic>)
          .map((json) => TransactionOrder.fromJson(json as Map<String, dynamic>))
          .toList();

      // Jika offset == 0, gabungkan dengan order lokal SQLite yang pending jika ada
      if (offset == 0 && outletId != null) {
        try {
          final pendingOrders = await LocalDatabaseService.instance.getPendingOrders();
          if (pendingOrders.isNotEmpty) {
            final existingIds = remoteOrders.map((o) => o.id).toSet();
            final pendingParsed = <TransactionOrder>[];
            for (final p in pendingOrders) {
              final raw = p['order'] as Map<String, dynamic>;
              if (raw['outlet_id'] == outletId && !existingIds.contains(raw['id'])) {
                final fullJson = Map<String, dynamic>.from(raw);
                fullJson['order_items'] = p['items'];
                fullJson['order_discounts'] = p['discounts'];
                fullJson['order_payments'] = p['payments'];
                pendingParsed.add(TransactionOrder.fromJson(fullJson));
              }
            }
            if (pendingParsed.isNotEmpty) {
              return [...pendingParsed, ...remoteOrders];
            }
          }
        } catch (_) {}
      }

      return remoteOrders;
    } catch (e) {
      // OFFLINE FALLBACK: Jika koneksi offline/gagal, baca dari SQLite lokal
      final targetOutletId = outletId ?? (outletIds != null && outletIds.isNotEmpty ? outletIds.first : null);
      if (targetOutletId != null) {
        try {
          final localOrders = await LocalDatabaseService.instance.getAllLocalOrders(
            outletId: targetOutletId,
            limit: limit,
            offset: offset,
            searchQuery: searchQuery,
            status: status?.dbValue,
          );
          if (localOrders.isNotEmpty) {
            return localOrders;
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Get draft orders for an outlet.
  Future<List<TransactionOrder>> getDraftOrders(
    String outletId, {
    OrderSource? orderSource,
    String? cashierId,
    String? waiterId,
  }) {
    return getOrders(
      outletId,
      status: TransactionStatus.draft,
      orderSource: orderSource,
      cashierId: cashierId,
      waiterId: waiterId,
    );
  }

  /// Update order status (e.g. void).
  Future<void> updateOrderStatus(
    String orderId,
    TransactionStatus status, {
    String? reason,
    String? voidedBy,
  }) async {
    final updates = <String, dynamic>{'status': status.dbValue};
    if (status == TransactionStatus.paid) {
      updates['paid_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == TransactionStatus.void_) {
      if (reason != null) updates['void_reason'] = reason;
      if (voidedBy != null) updates['voided_by'] = voidedBy;
    }
    await _client.from('orders').update(updates).eq('id', orderId);
  }

  /// Update status pemrosesan dapur (pending -> cooking -> ready -> served).
  Future<void> updateKitchenStatus(String orderId, KitchenStatus status) async {
    // 1. Coba via RPC update_kitchen_order_status (SECURITY DEFINER, bypass RLS untuk role kitchen)
    try {
      final rpcRes = await _client.rpc(
        'update_kitchen_order_status',
        params: {
          'p_order_id': orderId,
          'p_status': status.dbValue,
        },
      );
      if (rpcRes != null) return;
    } catch (_) {
      // Jika RPC belum ada di Supabase, lanjut ke update langsung
    }

    // 2. Direct update kolom kitchen_status
    try {
      final updated = await _client
          .from('orders')
          .update({
            'kitchen_status': status.dbValue,
          })
          .eq('id', orderId)
          .select('id, kitchen_status');

      if (updated.isNotEmpty) return;

      // Jika update mengembalikan array kosong, kemungkinan RLS memblokir role kitchen
      throw PostgrestException(
        message:
            'Akses ditolak (RLS). Role dapur belum memiliki izin update di tabel orders. Silakan jalankan migrasi SQL Supabase 20261021220000_allow_kitchen_role_to_update_orders.sql.',
        code: '42501',
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('kitchen_status')) {
        // Fallback backward-compatible: simpan di notes tag jika kolom belum ada di DB
        final currentOrder = await _client
            .from('orders')
            .select('notes')
            .eq('id', orderId)
            .maybeSingle();
        String currentNotes = (currentOrder?['notes'] as String?) ?? '';
        currentNotes = currentNotes
            .replaceAll('[KITCHEN:PENDING]', '')
            .replaceAll('[KITCHEN:COOKING]', '')
            .replaceAll('[KITCHEN:READY]', '')
            .replaceAll('[KITCHEN:SERVED]', '')
            .trim();
        final updatedNotes =
            '[KITCHEN:${status.name.toUpperCase()}] $currentNotes'.trim();
        await _client
            .from('orders')
            .update({'notes': updatedNotes})
            .eq('id', orderId);
      } else {
        rethrow;
      }
    }
  }

  /// Get status change history for an order.
  Future<List<Map<String, dynamic>>> getOrderStatusLogs(String orderId) async {
    final response = await _client
        .from('order_status_logs')
        .select('*')
        .eq('order_id', orderId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Delete a draft order.
  Future<void> deleteOrder(String orderId) async {
    await _client.from('orders').delete().eq('id', orderId);
  }

  /// Count paid transactions for a business in the current month.
  Future<int> countMonthlyTransactions(String businessId) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    final response = await _client
        .from('orders')
        .select('id')
        .eq('business_id', businessId)
        .eq('status', TransactionStatus.paid.dbValue)
        .gte('created_at', firstDayOfMonth.toUtc().toIso8601String())
        .count(CountOption.exact);

    return response.count;
  }
}

// ── Providers ─────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(SupabaseService.client);
});

final paymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethodOption>>((ref) async {
      final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
      final outletId = bootstrap?.currentOutlet?.id;
      if (outletId == null) return [];
      return ref
          .read(transactionRepositoryProvider)
          .getPaymentMethods(outletId);
    });

final draftOrdersProvider =
    AsyncNotifierProvider<DraftOrdersNotifier, List<TransactionOrder>>(() {
      return DraftOrdersNotifier();
    });

class DraftOrdersNotifier extends AsyncNotifier<List<TransactionOrder>> {
  @override
  Future<List<TransactionOrder>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) return [];
    final role = bootstrap?.effectiveRole;
    final currentUserId = SupabaseService.currentUser?.id;
    return ref
        .read(transactionRepositoryProvider)
        .getDraftOrders(
          outletId,
          orderSource: role == AppRole.waiter ? OrderSource.waiter : null,
          waiterId: role == AppRole.waiter ? currentUserId : null,
        );
  }

  Future<void> refresh() async {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) return;
    final role = bootstrap?.effectiveRole;
    final currentUserId = SupabaseService.currentUser?.id;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(transactionRepositoryProvider)
          .getDraftOrders(
            outletId,
            orderSource: role == AppRole.waiter ? OrderSource.waiter : null,
            waiterId: role == AppRole.waiter ? currentUserId : null,
          ),
    );
  }
}

final orderHistoryProvider =
    AsyncNotifierProvider<OrderHistoryNotifier, List<TransactionOrder>>(() {
      return OrderHistoryNotifier();
    });

class OrderHistoryNotifier extends AsyncNotifier<List<TransactionOrder>> {
  static const int _pageSize = 30;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _currentQuery;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  (String?, List<String>?) _resolveOutletFilter() {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    if (bootstrap == null) return (null, null);

    final isOwnerOrAdmin = bootstrap.effectiveRole == AppRole.owner ||
        bootstrap.effectiveRole == AppRole.admin;

    if (isOwnerOrAdmin) {
      final selectedOutletId = ref.read(selectedAnalyticsOutletIdProvider);
      if (selectedOutletId != null) {
        return (selectedOutletId, null);
      }
      final allOutletIds = bootstrap.outlets.map((o) => o.id).toList();
      return (null, allOutletIds.isNotEmpty ? allOutletIds : null);
    }

    return (bootstrap.currentOutlet?.id, null);
  }

  @override
  Future<List<TransactionOrder>> build() async {
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _currentQuery = null;

    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    if (bootstrap == null) return [];

    final isOwnerOrAdmin = bootstrap.effectiveRole == AppRole.owner ||
        bootstrap.effectiveRole == AppRole.admin;

    // Watch outlet filter agar otomatis refresh saat user mengganti outlet / semua outlet
    if (isOwnerOrAdmin) {
      ref.watch(selectedAnalyticsOutletIdProvider);
    }

    final (outletId, outletIds) = _resolveOutletFilter();
    if (outletId == null && (outletIds == null || outletIds.isEmpty)) {
      return [];
    }

    final items = await ref.read(transactionRepositoryProvider).getOrders(
          outletId,
          outletIds: outletIds,
          limit: _pageSize,
          offset: 0,
        );
    _hasMore = items.length == _pageSize;
    _currentOffset = items.length;
    return items;
  }

  Future<void> refresh() async {
    final (outletId, outletIds) = _resolveOutletFilter();
    if (outletId == null && (outletIds == null || outletIds.isEmpty)) return;

    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await ref.read(transactionRepositoryProvider).getOrders(
            outletId,
            outletIds: outletIds,
            limit: _pageSize,
            offset: 0,
            searchQuery: _currentQuery,
          );
      _hasMore = items.length == _pageSize;
      _currentOffset = items.length;
      return items;
    });
  }

  Future<void> search(String query) async {
    final (outletId, outletIds) = _resolveOutletFilter();
    if (outletId == null && (outletIds == null || outletIds.isEmpty)) return;

    _currentQuery = query.isNotEmpty ? query : null;
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await ref.read(transactionRepositoryProvider).getOrders(
            outletId,
            outletIds: outletIds,
            limit: _pageSize,
            offset: 0,
            searchQuery: _currentQuery,
          );
      _hasMore = items.length == _pageSize;
      _currentOffset = items.length;
      return items;
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    final currentList = state.value ?? [];
    if (currentList.isEmpty) return;

    final (outletId, outletIds) = _resolveOutletFilter();
    if (outletId == null && (outletIds == null || outletIds.isEmpty)) return;

    _isLoadingMore = true;
    try {
      final newItems = await ref.read(transactionRepositoryProvider).getOrders(
            outletId,
            outletIds: outletIds,
            limit: _pageSize,
            offset: _currentOffset,
            searchQuery: _currentQuery,
          );
      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _currentOffset += newItems.length;
        _hasMore = newItems.length == _pageSize;
        state = AsyncValue.data([...currentList, ...newItems]);
      }
    } catch (_) {
      // Ignore loadMore error gracefully
    } finally {
      _isLoadingMore = false;
    }
  }
}

/// Provider for confirmed (incoming) orders — from QR/waiter.
final confirmedOrdersProvider =
    AsyncNotifierProvider<ConfirmedOrdersNotifier, List<TransactionOrder>>(() {
      return ConfirmedOrdersNotifier();
    });

class ConfirmedOrdersNotifier extends AsyncNotifier<List<TransactionOrder>> {
  @override
  Future<List<TransactionOrder>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) return [];
    final allOutletIds = bootstrap?.outlets.map((o) => o.id).toList();
    final hasMultipleOutlets = allOutletIds != null && allOutletIds.isNotEmpty;
    return ref.read(transactionRepositoryProvider).getOrders(
          hasMultipleOutlets ? null : outletId,
          outletIds: hasMultipleOutlets ? allOutletIds : null,
          status: TransactionStatus.confirmed,
        );
  }

  Future<void> refresh() async {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) return;
    final allOutletIds = bootstrap?.outlets.map((o) => o.id).toList();
    final hasMultipleOutlets = allOutletIds != null && allOutletIds.isNotEmpty;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(transactionRepositoryProvider).getOrders(
            hasMultipleOutlets ? null : outletId,
            outletIds: hasMultipleOutlets ? allOutletIds : null,
            status: TransactionStatus.confirmed,
          ),
    );
  }
}
