import 'package:flutter/foundation.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportRepository {
  ReportRepository(this._client);
  final SupabaseClient _client;

  /// Fetch all orders in the given date range for the outlet(s),
  /// including any local pending/offline orders from SQLite.
  Future<List<TransactionOrder>> getOrdersInRange({
    String? outletId,
    List<String>? outletIds,
    required DateTime start,
    required DateTime end,
  }) async {
    var query = _client
        .from('orders')
        .select('*, order_items(*, menu_items(recipe_cost)), order_payments(*)');

    if (outletId != null) {
      query = query.eq('outlet_id', outletId);
    } else if (outletIds != null && outletIds.isNotEmpty) {
      query = query.inFilter('outlet_id', outletIds);
    }

    List<TransactionOrder> orders = [];
    try {
      final response = await SupabaseService.withAutoRefresh(
        () => query
            .gte('created_at', start.toUtc().toIso8601String())
            .lt('created_at', end.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .withNetworkTimeout(operationName: 'memuat laporan penjualan'),
      );

      orders = (response as List<dynamic>)
          .map((json) => TransactionOrder.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ReportRepository] Gagal memuat order online ($e), fallback ke data lokal.');
    }

    // Gabungkan transaksi offline / pending sync dari SQLite lokal agar angka laporan konsisten dengan dashboard
    try {
      final pendingOrders = await LocalDatabaseService.instance.getPendingOrders();
      for (final item in pendingOrders) {
        final rawOrder = item['order'] as Map<String, dynamic>;
        final orderId = rawOrder['id'] as String?;
        if (orderId == null) continue;

        if (!orders.any((o) => o.id == orderId)) {
          final fullJson = Map<String, dynamic>.from(rawOrder);
          fullJson['order_items'] = item['items'];
          fullJson['order_discounts'] = item['discounts'];
          fullJson['order_payments'] = item['payments'];
          try {
            final localOrder = TransactionOrder.fromJson(fullJson);
            final orderDate = localOrder.createdAt ?? DateTime.now();
            if (!orderDate.isBefore(start) && orderDate.isBefore(end)) {
              if (outletId == null || localOrder.outletId == outletId) {
                if (outletIds == null || outletIds.contains(localOrder.outletId)) {
                  orders.add(localOrder);
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return orders;
  }

  /// Build full report from orders in a date range.
  Future<FullReport> generateReport({
    String? outletId,
    List<String>? outletIds,
    Map<String, String>? outletNamesById,
    required DateTimeRange period,
  }) async {
    final orders = await getOrdersInRange(
      outletId: outletId,
      outletIds: outletIds,
      start: period.start,
      end: period.end,
    );

    double totalExpenses = 0;
    double totalCashIn = 0;
    try {
      var cashFlowQuery = _client
          .from('cash_flow_entries')
          .select('type, amount');

      if (outletId != null) {
        cashFlowQuery = cashFlowQuery.eq('outlet_id', outletId);
      } else if (outletIds != null && outletIds.isNotEmpty) {
        cashFlowQuery = cashFlowQuery.inFilter('outlet_id', outletIds);
      }

      final cashFlowRes = await cashFlowQuery
          .gte('created_at', period.start.toUtc().toIso8601String())
          .lt('created_at', period.end.toUtc().toIso8601String())
          .withNetworkTimeout(duration: const Duration(seconds: 10));

      for (final row in (cashFlowRes as List<dynamic>)) {
        final type = row['type'] as String?;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (type == 'out') {
          totalExpenses += amount;
        } else if (type == 'in') {
          totalCashIn += amount;
        }
      }
    } catch (_) {
      // Graceful fallback
    }

    return FullReport.fromOrders(
      orders,
      period,
      totalExpenses: totalExpenses,
      totalCashInExtra: totalCashIn,
      outletNamesById: outletNamesById,
    );
  }
}
