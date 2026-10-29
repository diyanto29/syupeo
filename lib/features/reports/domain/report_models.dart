import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:intl/intl.dart';

/// Range filter untuk laporan.
enum ReportPeriod {
  today('Hari Ini'),
  yesterday('Kemarin'),
  thisWeek('Minggu Ini'),
  thisMonth('Bulan Ini'),
  lastMonth('Bulan Lalu'),
  thisYear('Tahun Ini'),
  custom('Kustom');

  const ReportPeriod(this.label);
  final String label;

  DateTimeRange get dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportPeriod.today => DateTimeRange(
          start: todayStart,
          end: todayStart.add(const Duration(days: 1)),
        ),
      ReportPeriod.yesterday => DateTimeRange(
          start: todayStart.subtract(const Duration(days: 1)),
          end: todayStart,
        ),
      ReportPeriod.thisWeek => DateTimeRange(
          start: todayStart.subtract(Duration(days: now.weekday - 1)),
          end: todayStart.add(const Duration(days: 1)),
        ),
      ReportPeriod.thisMonth => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: todayStart.add(const Duration(days: 1)),
        ),
      ReportPeriod.lastMonth => DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 1),
        ),
      ReportPeriod.thisYear => DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: todayStart.add(const Duration(days: 1)),
        ),
      ReportPeriod.custom => DateTimeRange(
          start: todayStart,
          end: todayStart.add(const Duration(days: 1)),
        ),
    };
  }
}

/// Helper class for date range.
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});

  int get dayCount => end.difference(start).inDays.clamp(1, 365);
}

/// Laporan harian ringkas.
class DailySalesReport {
  final DateTime date;
  final double totalRevenue;
  final double totalDiscount;
  final double netRevenue;
  final int totalOrders;
  final int totalItems;
  final double avgOrderValue;

  const DailySalesReport({
    required this.date,
    required this.totalRevenue,
    required this.totalDiscount,
    required this.netRevenue,
    required this.totalOrders,
    required this.totalItems,
    required this.avgOrderValue,
  });
}

/// Performa kasir.
class CashierPerformance {
  final String cashierName;
  final int orderCount;
  final double totalRevenue;
  final double avgOrderValue;

  const CashierPerformance({
    required this.cashierName,
    required this.orderCount,
    required this.totalRevenue,
    required this.avgOrderValue,
  });
}

/// Performa waiter.
class WaiterPerformance {
  final String waiterName;
  final int orderCount;
  final double totalRevenue;
  final double avgOrderValue;

  const WaiterPerformance({
    required this.waiterName,
    required this.orderCount,
    required this.totalRevenue,
    required this.avgOrderValue,
  });
}

/// Profitability item.
class ProductPerformance {
  final String name;
  final int qtySold;
  final double revenue;
  final double avgPrice;

  const ProductPerformance({
    required this.name,
    required this.qtySold,
    required this.revenue,
    required this.avgPrice,
  });
}

/// Performa penjualan per outlet/cabang.
class OutletPerformance {
  final String outletId;
  final String outletName;
  final double totalRevenue;
  final int totalOrders;
  final double avgOrderValue;
  final double percentage;

  const OutletPerformance({
    required this.outletId,
    required this.outletName,
    required this.totalRevenue,
    required this.totalOrders,
    required this.avgOrderValue,
    this.percentage = 0.0,
  });
}

/// Model laporan lengkap.
class FullReport {
  final DateTimeRange period;
  final double totalRevenue;
  final double totalDiscount;
  final double totalTax;
  final double netRevenue;
  final double totalCogs;
  final double totalExpenses;
  final double totalCashInExtra;
  final double grossProfit;
  final double netProfit;
  final double grossProfitMargin;
  final double netProfitMargin;
  final int totalOrders;
  final int totalItems;
  final double avgOrderValue;
  final Map<String, double> revenueByMethod;
  final Map<String, int> ordersBySource;
  final List<ProductPerformance> topProducts;
  final List<ProductPerformance> bottomProducts;
  final List<CashierPerformance> cashierPerformances;
  final List<WaiterPerformance> waiterPerformances;
  final List<DailySalesReport> dailyBreakdown;
  final Map<int, double> hourlySales;
  final int cancelledOrders;
  final int refundedOrders;
  final double cancelledRevenue;
  final double refundedRevenue;
  final List<TransactionOrder> cancelledOrdersList;
  final List<TransactionOrder> refundedOrdersList;
  final List<OutletPerformance> outletPerformances;

  const FullReport({
    required this.period,
    required this.totalRevenue,
    required this.totalDiscount,
    this.totalTax = 0,
    required this.netRevenue,
    this.totalCogs = 0,
    this.totalExpenses = 0,
    this.totalCashInExtra = 0,
    this.grossProfit = 0,
    this.netProfit = 0,
    this.grossProfitMargin = 0,
    this.netProfitMargin = 0,
    required this.totalOrders,
    required this.totalItems,
    required this.avgOrderValue,
    required this.revenueByMethod,
    required this.ordersBySource,
    required this.topProducts,
    required this.bottomProducts,
    required this.cashierPerformances,
    required this.waiterPerformances,
    required this.dailyBreakdown,
    required this.hourlySales,
    required this.cancelledOrders,
    required this.refundedOrders,
    required this.cancelledRevenue,
    required this.refundedRevenue,
    required this.cancelledOrdersList,
    required this.refundedOrdersList,
    this.outletPerformances = const [],
  });

  factory FullReport.empty(DateTimeRange period) => FullReport(
        period: period,
        totalRevenue: 0,
        totalDiscount: 0,
        totalTax: 0,
        netRevenue: 0,
        totalCogs: 0,
        totalExpenses: 0,
        totalCashInExtra: 0,
        grossProfit: 0,
        netProfit: 0,
        grossProfitMargin: 0,
        netProfitMargin: 0,
        totalOrders: 0,
        totalItems: 0,
        avgOrderValue: 0,
        revenueByMethod: const {},
        ordersBySource: const {},
        topProducts: const [],
        bottomProducts: const [],
        cashierPerformances: const [],
        waiterPerformances: const [],
        dailyBreakdown: const [],
        hourlySales: const {},
        cancelledOrders: 0,
        refundedOrders: 0,
        cancelledRevenue: 0,
        refundedRevenue: 0,
        cancelledOrdersList: const [],
        refundedOrdersList: const [],
        outletPerformances: const [],
      );

  factory FullReport.fromOrders(
    List<TransactionOrder> allOrders,
    DateTimeRange period, {
    double totalExpenses = 0,
    double totalCashInExtra = 0,
    Map<String, String>? outletNamesById,
  }) {
    // Separate paid vs cancelled/refunded
    final paidOrders =
        allOrders.where((o) => o.status == TransactionStatus.paid).toList();
    final cancelledOrdersList =
        allOrders.where((o) => o.status == TransactionStatus.void_).toList();
    final refundedOrdersList =
        allOrders.where((o) => o.status == TransactionStatus.refunded).toList();

    final cancelledRevenue = cancelledOrdersList.fold<double>(0, (sum, o) => sum + o.grandTotal);
    final refundedRevenue = refundedOrdersList.fold<double>(0, (sum, o) => sum + o.grandTotal);

    if (paidOrders.isEmpty) {
      return FullReport.empty(period).copyWith(
        totalExpenses: totalExpenses,
        totalCashInExtra: totalCashInExtra,
        netProfit: totalCashInExtra - totalExpenses,
        cancelledOrders: cancelledOrdersList.length,
        refundedOrders: refundedOrdersList.length,
        cancelledRevenue: cancelledRevenue,
        refundedRevenue: refundedRevenue,
      );
    }

    double totalRevenue = 0;
    double totalDiscount = 0;
    double totalTax = 0;
    double totalCogs = 0;
    int totalItems = 0;
    final methodRevenue = <String, double>{};
    final sourceOrders = <String, int>{};
    final itemAccum = <String, _ItemAccumulator>{};
    final cashierAccum = <String, _CashierAccumulator>{};
    final waiterAccum = <String, _WaiterAccumulator>{};
    final outletAccum = <String, _OutletAccumulator>{};
    final hourlyMap = <int, double>{};
    final dailyMap = <String, _DailyAccumulator>{};

    final dayFmt = DateFormat('yyyy-MM-dd');

    for (final order in paidOrders) {
      totalRevenue += order.grandTotal;
      totalDiscount += order.discountTotal;
      totalTax += order.taxAmount;
      totalItems += order.totalItemCount;

      for (final item in order.items) {
        totalCogs += item.totalCost;
      }

      // Revenue by method
      for (final pay in order.payments) {
        methodRevenue[pay.methodName] =
            (methodRevenue[pay.methodName] ?? 0) + pay.amount;
      }

      // Orders by source
      final srcLabel = order.orderSource.label;
      sourceOrders[srcLabel] = (sourceOrders[srcLabel] ?? 0) + 1;

      // Products
      for (final item in order.items) {
        final acc = itemAccum[item.name] ??
            _ItemAccumulator(item.name, 0, 0);
        itemAccum[item.name] = _ItemAccumulator(
          item.name,
          acc.qty + item.quantity,
          acc.revenue + item.subtotal,
        );
      }

      // Cashier
      final cashier = order.cashierName ?? 'Tidak diketahui';
      final cAcc = cashierAccum[cashier] ?? _CashierAccumulator(cashier, 0, 0);
      cashierAccum[cashier] = _CashierAccumulator(
        cashier,
        cAcc.count + 1,
        cAcc.revenue + order.grandTotal,
      );

      // Hourly
      if (order.paidAt != null) {
        final h = order.paidAt!.hour;
        hourlyMap[h] = (hourlyMap[h] ?? 0) + order.grandTotal;
      }

      // Daily
      final dayKey = order.paidAt != null
          ? dayFmt.format(order.paidAt!)
          : dayFmt.format(order.createdAt ?? DateTime.now());
      final dAcc = dailyMap[dayKey] ?? _DailyAccumulator(dayKey, 0, 0, 0, 0);
      dailyMap[dayKey] = _DailyAccumulator(
        dayKey,
        dAcc.revenue + order.grandTotal,
        dAcc.discount + order.discountTotal,
        dAcc.orders + 1,
        dAcc.items + order.totalItemCount,
      );
      
      // Waiter
      if (order.waiterName != null && order.waiterName!.isNotEmpty) {
        final waiter = order.waiterName!;
        final wAcc = waiterAccum[waiter] ?? _WaiterAccumulator(waiter, 0, 0);
        waiterAccum[waiter] = _WaiterAccumulator(
          waiter,
          wAcc.count + 1,
          wAcc.revenue + order.grandTotal,
        );
      }

      // Outlet accumulation
      if (outletNamesById != null && outletNamesById.isNotEmpty) {
        final oId = order.outletId;
        final oName = outletNamesById[oId] ?? 'Outlet';
        final oAcc = outletAccum[oId] ?? _OutletAccumulator(oId, oName);
        outletAccum[oId] = _OutletAccumulator(
          oId,
          oName,
          oAcc.count + 1,
          oAcc.revenue + order.grandTotal,
        );
      }
    }

    // Top products
    final sortedProducts = itemAccum.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    final topProducts = sortedProducts
        .take(10)
        .map((a) => ProductPerformance(
              name: a.name,
              qtySold: a.qty,
              revenue: a.revenue,
              avgPrice: a.qty > 0 ? a.revenue / a.qty : 0,
            ))
        .toList();

    // Bottom products (lowest sellers)
    final bottomProducts = sortedProducts.reversed
        .take(5)
        .map((a) => ProductPerformance(
              name: a.name,
              qtySold: a.qty,
              revenue: a.revenue,
              avgPrice: a.qty > 0 ? a.revenue / a.qty : 0,
            ))
        .toList();

    // Cashier performances
    final cashierPerformances = cashierAccum.values
        .map((c) => CashierPerformance(
              cashierName: c.name,
              orderCount: c.count,
              totalRevenue: c.revenue,
              avgOrderValue: c.count > 0 ? c.revenue / c.count : 0,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    // Waiter performances
    final waiterPerformances = waiterAccum.values
        .map((w) => WaiterPerformance(
              waiterName: w.name,
              orderCount: w.count,
              totalRevenue: w.revenue,
              avgOrderValue: w.count > 0 ? w.revenue / w.count : 0,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    // Daily breakdown
    final dailyBreakdown = dailyMap.entries
        .map((e) {
          final d = e.value;
          return DailySalesReport(
            date: DateTime.parse(d.dateKey),
            totalRevenue: d.revenue,
            totalDiscount: d.discount,
            netRevenue: d.revenue,
            totalOrders: d.orders,
            totalItems: d.items,
            avgOrderValue: d.orders > 0 ? d.revenue / d.orders : 0,
          );
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Outlet performances
    final outletPerformances = <OutletPerformance>[];
    if (outletNamesById != null && outletNamesById.isNotEmpty) {
      for (final entry in outletNamesById.entries) {
        final acc = outletAccum[entry.key] ?? _OutletAccumulator(entry.key, entry.value);
        final pct = totalRevenue > 0 ? (acc.revenue / totalRevenue * 100) : 0.0;
        outletPerformances.add(OutletPerformance(
          outletId: acc.id,
          outletName: acc.name,
          totalRevenue: acc.revenue,
          totalOrders: acc.count,
          avgOrderValue: acc.count > 0 ? acc.revenue / acc.count : 0,
          percentage: pct,
        ));
      }
      outletPerformances.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    }

    final grossProfit = totalRevenue - totalCogs;
    final netProfit = grossProfit - totalExpenses;
    final grossProfitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue * 100) : 0.0;
    final netProfitMargin = totalRevenue > 0 ? (netProfit / totalRevenue * 100) : 0.0;

    return FullReport(
      period: period,
      totalRevenue: totalRevenue,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      netRevenue: totalRevenue,
      totalCogs: totalCogs,
      totalExpenses: totalExpenses,
      totalCashInExtra: totalCashInExtra,
      grossProfit: grossProfit,
      netProfit: netProfit,
      grossProfitMargin: grossProfitMargin,
      netProfitMargin: netProfitMargin,
      totalOrders: paidOrders.length,
      totalItems: totalItems,
      avgOrderValue: paidOrders.isNotEmpty
          ? totalRevenue / paidOrders.length
          : 0,
      revenueByMethod: methodRevenue,
      ordersBySource: sourceOrders,
      topProducts: topProducts,
      bottomProducts: bottomProducts,
      cashierPerformances: cashierPerformances,
      waiterPerformances: waiterPerformances,
      dailyBreakdown: dailyBreakdown,
      hourlySales: hourlyMap,
      cancelledOrders: cancelledOrdersList.length,
      refundedOrders: refundedOrdersList.length,
      cancelledRevenue: cancelledRevenue,
      refundedRevenue: refundedRevenue,
      cancelledOrdersList: cancelledOrdersList,
      refundedOrdersList: refundedOrdersList,
      outletPerformances: outletPerformances,
    );
  }

  FullReport copyWith({
    double? totalTax,
    double? totalCogs,
    double? totalExpenses,
    double? totalCashInExtra,
    double? grossProfit,
    double? netProfit,
    double? grossProfitMargin,
    double? netProfitMargin,
    int? cancelledOrders,
    int? refundedOrders,
    double? cancelledRevenue,
    double? refundedRevenue,
    List<TransactionOrder>? cancelledOrdersList,
    List<TransactionOrder>? refundedOrdersList,
    List<OutletPerformance>? outletPerformances,
  }) {
    return FullReport(
      period: period,
      totalRevenue: totalRevenue,
      totalDiscount: totalDiscount,
      totalTax: totalTax ?? this.totalTax,
      netRevenue: netRevenue,
      totalCogs: totalCogs ?? this.totalCogs,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      totalCashInExtra: totalCashInExtra ?? this.totalCashInExtra,
      grossProfit: grossProfit ?? this.grossProfit,
      netProfit: netProfit ?? this.netProfit,
      grossProfitMargin: grossProfitMargin ?? this.grossProfitMargin,
      netProfitMargin: netProfitMargin ?? this.netProfitMargin,
      totalOrders: totalOrders,
      totalItems: totalItems,
      avgOrderValue: avgOrderValue,
      revenueByMethod: revenueByMethod,
      ordersBySource: ordersBySource,
      topProducts: topProducts,
      bottomProducts: bottomProducts,
      cashierPerformances: cashierPerformances,
      waiterPerformances: waiterPerformances,
      dailyBreakdown: dailyBreakdown,
      hourlySales: hourlySales,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      refundedOrders: refundedOrders ?? this.refundedOrders,
      cancelledRevenue: cancelledRevenue ?? this.cancelledRevenue,
      refundedRevenue: refundedRevenue ?? this.refundedRevenue,
      cancelledOrdersList: cancelledOrdersList ?? this.cancelledOrdersList,
      refundedOrdersList: refundedOrdersList ?? this.refundedOrdersList,
      outletPerformances: outletPerformances ?? this.outletPerformances,
    );
  }
}

class _OutletAccumulator {
  final String id;
  final String name;
  final int count;
  final double revenue;
  const _OutletAccumulator(this.id, this.name, [this.count = 0, this.revenue = 0.0]);
}

class _ItemAccumulator {
  final String name;
  final int qty;
  final double revenue;
  const _ItemAccumulator(this.name, this.qty, this.revenue);
}

class _CashierAccumulator {
  final String name;
  final int count;
  final double revenue;
  const _CashierAccumulator(this.name, this.count, this.revenue);
}

class _WaiterAccumulator {
  final String name;
  final int count;
  final double revenue;
  const _WaiterAccumulator(this.name, this.count, this.revenue);
}

class _DailyAccumulator {
  final String dateKey;
  final double revenue;
  final double discount;
  final int orders;
  final int items;
  const _DailyAccumulator(
      this.dateKey, this.revenue, this.discount, this.orders, this.items);
}
