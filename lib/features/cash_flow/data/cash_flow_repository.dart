import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

final cashFlowRepositoryProvider = Provider<CashFlowRepository>((ref) {
  return CashFlowRepository(Supabase.instance.client);
});

class CashFlowRepository {
  final SupabaseClient _client;

  CashFlowRepository(this._client);

  /// Ambil shift aktif (status 'open') pada outlet saat ini
  Future<CashShift?> getActiveShift(String outletId) async {
    try {
      final res = await _client
          .from('cash_shifts')
          .select()
          .eq('outlet_id', outletId)
          .eq('status', 'open')
          .order('opened_at', ascending: false)
          .maybeSingle();

      if (res == null) {
        await LocalDatabaseService.instance.setKeyValue('active_shift_$outletId', '');
        return null;
      }
      final shift = CashShift.fromJson(res);
      await LocalDatabaseService.instance.setKeyValue('active_shift_$outletId', jsonEncode(shift.toJson()));
      return shift;
    } catch (e) {
      // Offline fallback: load from local cache!
      try {
        final cached = await LocalDatabaseService.instance.getKeyValue('active_shift_$outletId');
        if (cached != null && cached.isNotEmpty) {
          final json = jsonDecode(cached) as Map<String, dynamic>;
          return CashShift.fromJson(json);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Buka shift baru
  Future<CashShift> openShift({
    required String businessId,
    required String outletId,
    required double startingCash,
    required String cashierName,
    String? notes,
  }) async {
    // 1. Coba via RPC Security Definer (100% Kebal RLS & Mencegah Duplikasi Shift)
    try {
      final rpcRes = await _client.rpc('rpc_open_cash_shift', params: {
        'p_business_id': businessId,
        'p_outlet_id': outletId,
        'p_starting_cash': startingCash.round(),
        'p_cashier_name': cashierName,
        'p_notes': notes,
      });
      if (rpcRes != null) {
        final shift = CashShift.fromJson(Map<String, dynamic>.from(rpcRes));
        await LocalDatabaseService.instance.setKeyValue('active_shift_$outletId', jsonEncode(shift.toJson()));
        return shift;
      }
    } catch (e) {
      debugPrint('[CashFlow] rpc_open_cash_shift fallback to direct insert: $e');
    }

    // 2. Fallback direct table insert
    final user = _client.auth.currentUser;
    final payload = {
      'business_id': businessId,
      'outlet_id': outletId,
      'cashier_id': user?.id,
      'cashier_name': cashierName,
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'starting_cash': startingCash.round(),
      'status': 'open',
      'notes': notes,
    };

    final res = await _client
        .from('cash_shifts')
        .insert(payload)
        .select()
        .single();

    final shift = CashShift.fromJson(res);
    await LocalDatabaseService.instance.setKeyValue('active_shift_$outletId', jsonEncode(shift.toJson()));
    return shift;
  }

  /// Menghitung akumulasi penjualan tunai dan mutasi kas selama rentang waktu shift
  Future<Map<String, double>> calculateShiftTotals(
    String? outletId,
    DateTime openedAt, {
    DateTime? closedAt,
    List<String>? outletIds,
  }) async {
    double totalSalesCash = 0;
    double totalCashIn = 0;
    double totalCashOut = 0;

    final safeOpenedAt = sanitizeShiftTime(openedAt);
    final safeClosedAt = closedAt != null ? sanitizeShiftTime(closedAt) : null;

    // 1. Hitung total penjualan tunai dari getShiftOrders (mendukung SQLite lokal + Supabase cloud)
    try {
      final targetOutletId = outletId ?? (outletIds != null && outletIds.isNotEmpty ? outletIds.first : '');
      if (targetOutletId.isNotEmpty) {
        final shiftOrders = await getShiftOrders(
          outletId: targetOutletId,
          openedAt: safeOpenedAt,
          closedAt: safeClosedAt,
        );

        for (final order in shiftOrders) {
          if (order.status != TransactionStatus.paid && order.status != TransactionStatus.refunded) continue;

          if (order.payments.isNotEmpty) {
            for (final p in order.payments) {
              final isCash = p.methodType.toLowerCase() == 'cash' ||
                  p.methodName.toLowerCase().contains('tunai') ||
                  p.methodName.toLowerCase().contains('cash');
              if (isCash) {
                final netCash = (p.amount - order.changeAmount).clamp(0.0, double.infinity);
                totalSalesCash += netCash;
              }
            }
          } else {
            // Fallback untuk transaksi tunai tanpa row order_payments
            totalSalesCash += order.grandTotal;
          }
        }
      }
    } catch (e) {
      debugPrint('[CashFlow] Error computing shift sales cash: $e');
    }

    // 2. Hitung mutasi kas masuk & kas keluar
    try {
      final startIso = safeOpenedAt.toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
      final endIso = (safeClosedAt ?? DateTime.now()).toUtc().add(const Duration(minutes: 5)).toIso8601String();

      var entriesQuery = _client
          .from('cash_flow_entries')
          .select('type, amount, payment_source')
          .eq('payment_source', 'cash')
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      if (outletId != null) {
        entriesQuery = entriesQuery.eq('outlet_id', outletId);
      } else if (outletIds != null && outletIds.isNotEmpty) {
        entriesQuery = entriesQuery.inFilter('outlet_id', outletIds);
      }

      final entriesRes = await entriesQuery;

      for (final row in (entriesRes as List)) {
        final type = row['type'] as String?;
        final amt = (row['amount'] as num?)?.toDouble() ?? 0;
        if (type == 'in') {
          totalCashIn += amt;
        } else if (type == 'out') {
          totalCashOut += amt;
        }
      }
    } catch (e) {
      debugPrint('[CashFlow] Error computing shift entries: $e');
    }

    return {
      'totalSalesCash': totalSalesCash,
      'totalCashIn': totalCashIn,
      'totalCashOut': totalCashOut,
    };
  }

  /// Tutup shift kasir (Rekonsiliasi)
  Future<CashShift> closeShift({
    required CashShift shift,
    required double actualCash,
    String? notes,
  }) async {
    final totals = await calculateShiftTotals(
      shift.outletId,
      shift.openedAt,
    );

    final totalSalesCash = totals['totalSalesCash'] ?? 0;
    final totalCashIn = totals['totalCashIn'] ?? 0;
    final totalCashOut = totals['totalCashOut'] ?? 0;

    final expectedCash =
        shift.startingCash + totalSalesCash + totalCashIn - totalCashOut;
    final diff = actualCash - expectedCash;
    final now = DateTime.now().toUtc();

    // 1. Coba via RPC Security Definer (100% Kebal RLS)
    try {
      final rpcRes = await _client.rpc('rpc_close_cash_shift', params: {
        'p_shift_id': shift.id,
        'p_actual_cash': actualCash.round(),
        'p_expected_cash': expectedCash.round(),
        'p_difference_amount': diff.round(),
        'p_total_sales_cash': totalSalesCash.round(),
        'p_total_cash_in': totalCashIn.round(),
        'p_total_cash_out': totalCashOut.round(),
        'p_notes': notes ?? shift.notes,
      });
      if (rpcRes != null) {
        final closedShift = CashShift.fromJson(Map<String, dynamic>.from(rpcRes));
        await LocalDatabaseService.instance.setKeyValue('active_shift_${shift.outletId}', '');
        return closedShift;
      }
    } catch (e) {
      debugPrint('[CashFlow] rpc_close_cash_shift fallback to direct update: $e');
    }

    // 2. Fallback direct table update
    final payload = {
      'closed_at': now.toIso8601String(),
      'status': 'closed',
      'expected_cash': expectedCash.round(),
      'actual_cash': actualCash.round(),
      'difference_amount': diff.round(),
      'total_sales_cash': totalSalesCash.round(),
      'total_cash_in': totalCashIn.round(),
      'total_cash_out': totalCashOut.round(),
      'notes': notes ?? shift.notes,
      'updated_at': now.toIso8601String(),
    };

    final res = await _client
        .from('cash_shifts')
        .update(payload)
        .eq('id', shift.id)
        .select()
        .single();

    await LocalDatabaseService.instance.setKeyValue('active_shift_${shift.outletId}', '');
    return CashShift.fromJson(res);
  }

  /// Tambah entri mutasi kas (Masuk / Keluar)
  Future<CashFlowEntry> addCashEntry({
    required String businessId,
    required String outletId,
    String? shiftId,
    required CashFlowType type,
    required String category,
    required double amount,
    String paymentSource = 'cash',
    String? notes,
    String? receiptUrl,
    required String cashierName,
  }) async {
    // 1. Coba via RPC Security Definer (100% Kebal RLS)
    try {
      final rpcParams = <String, dynamic>{
        'p_business_id': businessId,
        'p_outlet_id': outletId,
        'p_type': type.value,
        'p_category': category,
        'p_amount': amount.round(),
        'p_cashier_name': cashierName,
        'p_payment_source': paymentSource,
      };
      if (shiftId != null && shiftId.isNotEmpty) {
        rpcParams['p_shift_id'] = shiftId;
      }
      if (notes != null && notes.isNotEmpty) {
        rpcParams['p_notes'] = notes;
      }
      if (receiptUrl != null && receiptUrl.isNotEmpty) {
        rpcParams['p_receipt_url'] = receiptUrl;
      }

      final rpcRes = await _client.rpc('rpc_add_cash_entry', params: rpcParams);
      if (rpcRes != null) {
        return CashFlowEntry.fromJson(Map<String, dynamic>.from(rpcRes));
      }
    } catch (e) {
      debugPrint('[CashFlow] rpc_add_cash_entry fallback to direct insert: $e');
    }

    // 2. Fallback direct table insert
    final user = _client.auth.currentUser;
    final payload = <String, dynamic>{
      'business_id': businessId,
      'outlet_id': outletId,
      'type': type.value,
      'category': category,
      'amount': amount.round(),
      'payment_source': paymentSource,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (shiftId != null && shiftId.isNotEmpty) {
      payload['shift_id'] = shiftId;
    }
    if (user != null) {
      payload['cashier_id'] = user.id;
      payload['user_id'] = user.id;
    }
    if (cashierName.isNotEmpty) {
      payload['cashier_name'] = cashierName;
      payload['user_name'] = cashierName;
    }
    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }
    // Hanya sertakan receipt_url jika ada nilainya, agar tidak error jika kolom belum ada di schema cache
    if (receiptUrl != null && receiptUrl.isNotEmpty) {
      payload['receipt_url'] = receiptUrl;
    }

    try {
      final res = await _client
          .from('cash_flow_entries')
          .insert(payload)
          .select()
          .single();

      return CashFlowEntry.fromJson(res);
    } catch (e) {
      // Jika skema database di cloud belum menambahkan receipt_url, coba sekali lagi tanpa receipt_url
      if (payload.containsKey('receipt_url')) {
        payload.remove('receipt_url');
        final res = await _client
            .from('cash_flow_entries')
            .insert(payload)
            .select()
            .single();
        return CashFlowEntry.fromJson(res);
      }
      rethrow;
    }
  }

  /// Ambil riwayat mutasi kas
  Future<List<CashFlowEntry>> getCashEntries(
    String? outletId, {
    List<String>? outletIds,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('cash_flow_entries').select();

      if (outletId != null) {
        query = query.eq('outlet_id', outletId);
      } else if (outletIds != null && outletIds.isNotEmpty) {
        query = query.inFilter('outlet_id', outletIds);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toUtc().toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('created_at', toDate.toUtc().toIso8601String());
      }

      final res = await query.order('created_at', ascending: false).limit(limit);
      return (res as List).map((e) => CashFlowEntry.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ambil riwayat shift kasir terdahulu
  Future<List<CashShift>> getShiftHistory(
    String outletId, {
    String? cashierId,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('cash_shifts')
          .select()
          .eq('outlet_id', outletId)
          .eq('status', 'closed');

      if (cashierId != null && cashierId.isNotEmpty) {
        query = query.eq('cashier_id', cashierId);
      }

      final res = await query.order('closed_at', ascending: false).limit(limit);
      return (res as List).map((e) => CashShift.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ambil seluruh transaksi pesanan yang terjadi dalam rentang waktu shift
  /// (Menggabungkan pesanan SQLite lokal instan + pesanan cloud Supabase)
  Future<List<TransactionOrder>> getShiftOrders({
    required String outletId,
    required DateTime openedAt,
    DateTime? closedAt,
  }) async {
    final safeOpenedAt = sanitizeShiftTime(openedAt);
    final safeClosedAt = closedAt != null ? sanitizeShiftTime(closedAt) : null;

    final ordersMap = <String, TransactionOrder>{};

    // 1. Ambil dari lokal SQLite (instan & selalu ada walau offline / antrean sync)
    try {
      final localOrders = await LocalDatabaseService.instance.getLocalOrdersForShift(
        outletId: outletId,
        openedAt: safeOpenedAt,
        closedAt: safeClosedAt,
      );
      for (final o in localOrders) {
        ordersMap[o.id] = o;
      }
    } catch (e) {
      debugPrint('[CashFlow] Failed reading local shift orders: $e');
    }

    // 2. Ambil dari remote Supabase (konversi UTC dengan buffer toleransi)
    try {
      final startIso = safeOpenedAt.toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
      final endIso = (safeClosedAt ?? DateTime.now()).toUtc().add(const Duration(minutes: 5)).toIso8601String();

      final res = await _client
          .from('orders')
          .select('*, order_items(*), order_payments(*)')
          .eq('outlet_id', outletId)
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .order('created_at', ascending: false);

      for (final row in (res as List<dynamic>)) {
        final order = TransactionOrder.fromJson(row as Map<String, dynamic>);
        ordersMap[order.id] = order;
      }
    } catch (e) {
      debugPrint('[CashFlow] Failed fetching remote shift orders: $e');
    }

    final list = ordersMap.values.toList();
    list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return list;
  }

  /// Hapus entri mutasi kas
  Future<void> deleteCashEntry(String id) async {
    await _client.from('cash_flow_entries').delete().eq('id', id);
  }
}
