import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/inventory/domain/stock_opname_models.dart';

class StockOpnameRepository {
  StockOpnameRepository(this._client);
  final SupabaseClient _client;

  /// Buat sesi opname baru dan isi otomatis dengan daftar seluruh bahan baku aktif
  Future<StockOpnameSession> createOpnameSession({
    required String businessId,
    required String outletId,
    String opnameType = 'daily_closing',
    String? notes,
    bool blindCount = false,
  }) async {
    // 1. Generate session number (e.g., OP-20261021-001)
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomSuffix = now.millisecondsSinceEpoch.toString().substring(8);
    final sessionNumber = 'OP-$dateStr-$randomSuffix';

    // 2. Insert session header
    final sessionData = await _client
        .from('stock_opname_sessions')
        .insert({
          'business_id': businessId,
          'outlet_id': outletId,
          'session_number': sessionNumber,
          'opname_type': opnameType,
          'status': 'in_progress',
          'notes': notes,
          'conducted_by': _client.auth.currentUser?.id,
          'started_at': now.toUtc().toIso8601String(),
        })
        .select()
        .single();

    final sessionId = sessionData['id'] as String;

    // 3. Fetch all active ingredients for this business / outlet
    final ingredientsRes = await _client
        .from('inventory_ingredients')
        .select('*')
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('name', ascending: true);

    final List<Map<String, dynamic>> itemsPayload = [];
    double initialSystemValue = 0.0;

    for (final row in (ingredientsRes as List<dynamic>)) {
      final ingId = row['id'] as String;
      final name = row['name'] as String;
      final unit = (row['base_unit'] as String?) ?? 'pcs';
      final storage = (row['storage_type'] as String?) ?? 'General';
      final currentStock = (row['current_stock'] as num?)?.toDouble() ?? 0.0;
      final unitCost = (row['cost_per_base_unit'] as num?)?.toDouble() ?? 0.0;

      initialSystemValue += (currentStock * unitCost);

      itemsPayload.add({
        'session_id': sessionId,
        'ingredient_id': ingId,
        'item_name': name,
        'storage_location': storage,
        'unit': unit,
        'system_stock': currentStock,
        'physical_stock': blindCount ? 0.0 : currentStock,
        'unit_cost': unitCost,
        'discrepancy_reason': 'none',
      });
    }

    if (itemsPayload.isNotEmpty) {
      await _client.from('stock_opname_items').insert(itemsPayload);
    }

    // 4. Update session total system value
    await _client.from('stock_opname_sessions').update({
      'total_system_value': initialSystemValue,
    }).eq('id', sessionId);

    return getOpnameSessionDetails(sessionId);
  }

  /// Ambil detail sesi opname beserta seluruh rincian itemnya
  Future<StockOpnameSession> getOpnameSessionDetails(String sessionId) async {
    final res = await _client
        .from('stock_opname_sessions')
        .select('*, stock_opname_items(*)')
        .eq('id', sessionId)
        .single();

    final session = StockOpnameSession.fromJson(res);
    // Sort items by storage_location and item_name
    final sortedItems = List<StockOpnameItem>.from(session.items)
      ..sort((a, b) {
        final locCompare = a.storageLocation.compareTo(b.storageLocation);
        if (locCompare != 0) return locCompare;
        return a.itemName.compareTo(b.itemName);
      });

    return session.copyWith(items: sortedItems);
  }

  /// Update input fisik stok pada 1 baris item
  Future<void> updateItemCount({
    required String itemId,
    required double physicalStock,
    String? reason,
    String? notes,
  }) async {
    await _client.from('stock_opname_items').update({
      'physical_stock': physicalStock,
      'discrepancy_reason': reason,
      'notes': notes,
      'counted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
  }

  /// Batch update seluruh item opname sekaligus
  Future<void> batchSaveItemCounts(List<StockOpnameItem> items) async {
    for (final it in items) {
      await _client.from('stock_opname_items').update({
        'physical_stock': it.physicalStock,
        'discrepancy_reason': it.discrepancyReason,
        'notes': it.notes,
        'counted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', it.id);
    }
  }

  /// Selesaikan sesi opname dan lakukan rekonsiliasi (Update saldo fisik & catat mutasi ledger)
  Future<StockOpnameSession> completeAndReconcileOpname({
    required String sessionId,
    String? notes,
  }) async {
    final session = await getOpnameSessionDetails(sessionId);

    double totalSysVal = 0.0;
    double totalPhysVal = 0.0;
    double totalDiscrepancyVal = 0.0;

    final now = DateTime.now();

    for (final item in session.items) {
      totalSysVal += (item.systemStock * item.unitCost);
      totalPhysVal += (item.physicalStock * item.unitCost);
      final diff = item.physicalStock - item.systemStock;
      final diffVal = diff * item.unitCost;
      totalDiscrepancyVal += diffVal;

      // Jika ada selisih stok fisik vs sistem:
      if (diff.abs() > 0.0001 && item.ingredientId != null) {
        // 1. Update current_stock di inventory_ingredients
        await _client.from('inventory_ingredients').update({
          'current_stock': item.physicalStock,
          'updated_at': now.toUtc().toIso8601String(),
        }).eq('id', item.ingredientId!);

        // 2. Catat audit log permanen di ingredient_movements
        final reasonText = item.discrepancyReason != null && item.discrepancyReason != 'none'
            ? ' (${item.discrepancyReason})'
            : '';
        await _client.from('ingredient_movements').insert({
          'business_id': session.businessId,
          'outlet_id': session.outletId,
          'ingredient_id': item.ingredientId!,
          'movement_type': 'adjustment',
          'quantity_delta': diff,
          'balance_after': item.physicalStock,
          'note': 'Rekonsiliasi Opname #${session.sessionNumber}$reasonText: ${item.notes ?? 'Koreksi stok fisik'}',
          'reference_id': session.id,
          'performed_by': _client.auth.currentUser?.id,
          'created_at': now.toUtc().toIso8601String(),
        });
      }
    }

    // Update status session menjadi 'completed'
    await _client.from('stock_opname_sessions').update({
      'status': 'completed',
      'total_system_value': totalSysVal,
      'total_physical_value': totalPhysVal,
      'total_discrepancy_value': totalDiscrepancyVal,
      'completed_at': now.toUtc().toIso8601String(),
      'approved_by': _client.auth.currentUser?.id,
      if (notes != null) 'notes': notes,
    }).eq('id', sessionId);

    return getOpnameSessionDetails(sessionId);
  }

  /// Ambil riwayat sesi opname terdahulu
  Future<List<StockOpnameSession>> getOpnameHistory(String outletId, {int limit = 30}) async {
    final res = await _client
        .from('stock_opname_sessions')
        .select('*')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (res as List<dynamic>)
        .map((e) => StockOpnameSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final stockOpnameRepositoryProvider = Provider<StockOpnameRepository>((ref) {
  return StockOpnameRepository(SupabaseService.client);
});

final opnameHistoryProvider = FutureProvider.family.autoDispose<List<StockOpnameSession>, String>(
  (ref, outletId) async {
    if (outletId.isEmpty) return [];
    return ref.watch(stockOpnameRepositoryProvider).getOpnameHistory(outletId);
  },
);
