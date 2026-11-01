import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/analytics_outlet_filter_provider.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/widgets/announcement_banner_widget.dart';
import 'package:dpos/core/utils/riverpod_cache_extension.dart';
import 'package:dpos/features/dashboard/presentation/widgets/pending_store_activation_banner.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _decimalNumber = NumberFormat.decimalPattern('id_ID');

enum DashboardPeriod {
  daily('Harian'),
  monthly('Bulanan');

  const DashboardPeriod(this.label);
  final String label;
}

final dashboardPeriodProvider =
    StateProvider<DashboardPeriod>((ref) => DashboardPeriod.daily);

// ── Data Model ──────────────────────────────────────────────────

class SalesSummary {
  final double totalRevenue;
  final double totalDiscount;
  final double netRevenue;
  final double monthlyRevenue;
  final double totalCogs;
  final double totalExpenses;
  final double totalCashIn;
  final double grossProfit;
  final double netProfit;
  final double profitMargin;
  final double monthlyNetProfit;
  final int totalOrders;
  final int totalItems;
  final double avgOrderValue;
  final Map<String, double> revenueByMethod;
  final Map<String, int> ordersBySource;
  final List<TopSalesItem> topItems;
  final List<HourlySalePoint> hourlySales;
  final int cancelledOrders;
  final double cancelledRevenue;
  final int refundedOrders;
  final double refundedRevenue;
  final List<TransactionOrder> refundedOrdersList;
  final List<OutletSalesContribution> outletContributions;

  const SalesSummary({
    required this.totalRevenue,
    required this.totalDiscount,
    required this.netRevenue,
    required this.monthlyRevenue,
    this.totalCogs = 0,
    this.totalExpenses = 0,
    this.totalCashIn = 0,
    this.grossProfit = 0,
    this.netProfit = 0,
    this.profitMargin = 0,
    this.monthlyNetProfit = 0,
    required this.totalOrders,
    required this.totalItems,
    required this.avgOrderValue,
    required this.revenueByMethod,
    required this.ordersBySource,
    required this.topItems,
    required this.hourlySales,
    required this.cancelledOrders,
    required this.cancelledRevenue,
    required this.refundedOrders,
    required this.refundedRevenue,
    required this.refundedOrdersList,
    this.outletContributions = const [],
  });

  factory SalesSummary.empty() => const SalesSummary(
    totalRevenue: 0,
    totalDiscount: 0,
    netRevenue: 0,
    monthlyRevenue: 0,
    totalCogs: 0,
    totalExpenses: 0,
    totalCashIn: 0,
    grossProfit: 0,
    netProfit: 0,
    profitMargin: 0,
    monthlyNetProfit: 0,
    totalOrders: 0,
    totalItems: 0,
    avgOrderValue: 0,
    revenueByMethod: {},
    ordersBySource: {},
    topItems: [],
    hourlySales: [],
    cancelledOrders: 0,
    cancelledRevenue: 0,
    refundedOrders: 0,
    refundedRevenue: 0,
    refundedOrdersList: [],
    outletContributions: [],
  );

  factory SalesSummary.fromOrders(
    List<TransactionOrder> orders, {
    bool isService = false,
    DashboardPeriod period = DashboardPeriod.daily,
    double totalExpenses = 0,
    double totalCashIn = 0,
    double monthlyExpenses = 0,
    Map<String, String>? outletNamesById,
  }) {
    if (orders.isEmpty) {
      final netProfit = totalCashIn - totalExpenses;
      return SalesSummary.empty().copyWith(
        totalExpenses: totalExpenses,
        totalCashIn: totalCashIn,
        netProfit: netProfit,
        monthlyNetProfit: netProfit,
      );
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    double totalRevenue = 0;
    double totalDiscount = 0;
    double monthlyRevenue = 0;
    double totalCogs = 0;
    int totalItems = 0;
    final methodRevenue = <String, double>{};
    final sourceOrders = <String, int>{};
    final itemCount = <String, _TopItemAccumulator>{};
    final hourlyMap = <int, double>{};
    final dailyMap = <String, double>{};
    final monthlyDayMap = <int, double>{};
    int cancelledOrders = 0;
    double cancelledRevenue = 0;
    int refundedOrders = 0;
    double refundedRevenue = 0;
    final refundedOrdersList = <TransactionOrder>[];

    for (final order in orders) {
      final orderDate = order.createdAt ?? now;

      // Sum monthly revenue for any paid order in the current month
      if (order.status == TransactionStatus.paid &&
          orderDate.year == now.year &&
          orderDate.month == now.month) {
        monthlyRevenue += order.grandTotal;
      }

      final isOrderToday =
          !orderDate.isBefore(todayStart) && orderDate.isBefore(todayEnd);
      final isOrderThisMonth =
          !orderDate.isBefore(monthStart) && orderDate.isBefore(monthEnd);

      if (period == DashboardPeriod.daily) {
        if (isService && !isOrderToday) {
          if (order.status == TransactionStatus.paid) {
            final dateKey =
                DateFormat('yyyy-MM-dd').format(orderDate.toLocal());
            dailyMap[dateKey] = (dailyMap[dateKey] ?? 0) + order.grandTotal;
          }
          continue;
        }
        if (!isOrderToday) {
          continue;
        }
      } else {
        if (!isOrderThisMonth) {
          continue;
        }
      }

      if (order.status == TransactionStatus.void_) {
        cancelledOrders++;
        cancelledRevenue += order.grandTotal;
        continue;
      }
      if (order.status == TransactionStatus.refunded) {
        refundedOrders++;
        refundedRevenue += order.grandTotal;
        refundedOrdersList.add(order);
        continue;
      }

      if (order.status != TransactionStatus.paid) {
        continue;
      }

      totalRevenue += order.grandTotal;
      totalDiscount += order.discountTotal;
      totalItems += order.totalItemCount;

      for (final item in order.items) {
        totalCogs += item.totalCost;
      }

      // Revenue by payment method
      for (final pay in order.payments) {
        methodRevenue[pay.methodName] =
            (methodRevenue[pay.methodName] ?? 0) + pay.amount;
      }

      // Orders by source
      final sourceLabel = order.orderSource.label;
      sourceOrders[sourceLabel] = (sourceOrders[sourceLabel] ?? 0) + 1;

      // Top items
      for (final item in order.items) {
        final key = item.name;
        final acc = itemCount[key] ?? _TopItemAccumulator(key, 0, 0);
        itemCount[key] = _TopItemAccumulator(
          key,
          acc.qty + item.quantity,
          acc.revenue + item.subtotal,
        );
      }

      // Hourly/Daily sales
      if (period == DashboardPeriod.monthly) {
        final day = orderDate.day;
        monthlyDayMap[day] = (monthlyDayMap[day] ?? 0) + order.grandTotal;
      } else {
        if (isService) {
          final dateKey =
              DateFormat('yyyy-MM-dd').format(orderDate.toLocal());
          dailyMap[dateKey] = (dailyMap[dateKey] ?? 0) + order.grandTotal;
        } else {
          if (order.paidAt != null) {
            final hour = order.paidAt!.hour;
            hourlyMap[hour] = (hourlyMap[hour] ?? 0) + order.grandTotal;
          }
        }
      }
    }

    // Sort top items by qty
    final topItems =
        itemCount.values
            .map((a) => TopSalesItem(a.name, a.qty, a.revenue))
            .toList()
          ..sort((a, b) => b.qty.compareTo(a.qty));

    // Build chart points
    final hourlySales = <HourlySalePoint>[];
    if (period == DashboardPeriod.monthly) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final maxDay = now.day < 7 ? 7 : now.day;
      for (int d = 1; d <= maxDay.clamp(1, daysInMonth); d++) {
        final revenue = monthlyDayMap[d] ?? 0.0;
        hourlySales.add(HourlySalePoint(d, revenue, label: '$d'));
      }
    } else if (isService) {
      // Generate the last 7 days (including today)
      for (int i = 6; i >= 0; i--) {
        final date = todayStart.subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final label = DateFormat('dd/MM').format(date);
        final revenue = dailyMap[dateKey] ?? 0.0;
        hourlySales.add(HourlySalePoint(i, revenue, label: label));
      }
    } else {
      for (int h = 0; h < 24; h++) {
        if (hourlyMap.containsKey(h)) {
          hourlySales.add(HourlySalePoint(h, hourlyMap[h]!));
        }
      }
    }

    final totalPaidCount = orders.where((o) {
      final orderDate = o.createdAt ?? now;
      if (period == DashboardPeriod.monthly) {
        final isOrderThisMonth =
            orderDate.isAfter(monthStart) && orderDate.isBefore(monthEnd);
        return o.status == TransactionStatus.paid && isOrderThisMonth;
      } else {
        final isOrderToday =
            !orderDate.isBefore(todayStart) && orderDate.isBefore(todayEnd);
        return o.status == TransactionStatus.paid && (!isService || isOrderToday);
      }
    }).length;

    final grossProfit = totalRevenue - totalCogs;
    final netProfit = grossProfit - totalExpenses + totalCashIn;
    final profitMargin =
        totalRevenue > 0 ? (netProfit / totalRevenue * 100) : 0.0;
    final monthlyNetProfit = netProfit;

    // Build outlet contributions
    final outletContributions = <OutletSalesContribution>[];
    if (outletNamesById != null && outletNamesById.length > 1) {
      final outletMap = <String, _OutletAccumulatorSales>{};
      for (final entry in outletNamesById.entries) {
        outletMap[entry.key] = _OutletAccumulatorSales(entry.key, entry.value);
      }
      for (final o in orders) {
        if (o.status == TransactionStatus.paid) {
          final acc = outletMap[o.outletId];
          if (acc != null) {
            acc.revenue += o.grandTotal;
            acc.count++;
          }
        }
      }
      for (final acc in outletMap.values) {
        final pct = totalRevenue > 0 ? (acc.revenue / totalRevenue * 100) : 0.0;
        outletContributions.add(OutletSalesContribution(
          outletId: acc.id,
          outletName: acc.name,
          revenue: acc.revenue,
          orderCount: acc.count,
          percentage: pct,
        ));
      }
      outletContributions.sort((a, b) => b.revenue.compareTo(a.revenue));
    }

    return SalesSummary(
      totalRevenue: totalRevenue,
      totalDiscount: totalDiscount,
      netRevenue: totalRevenue,
      monthlyRevenue: monthlyRevenue,
      totalCogs: totalCogs,
      totalExpenses: totalExpenses,
      totalCashIn: totalCashIn,
      grossProfit: grossProfit,
      netProfit: netProfit,
      profitMargin: profitMargin,
      monthlyNetProfit: monthlyNetProfit,
      totalOrders: totalPaidCount,
      totalItems: totalItems,
      avgOrderValue: totalRevenue / (totalPaidCount > 0 ? totalPaidCount : 1),
      revenueByMethod: methodRevenue,
      ordersBySource: sourceOrders,
      topItems: topItems.take(5).toList(),
      hourlySales: hourlySales,
      cancelledOrders: cancelledOrders,
      cancelledRevenue: cancelledRevenue,
      refundedOrders: refundedOrders,
      refundedRevenue: refundedRevenue,
      refundedOrdersList: refundedOrdersList,
      outletContributions: outletContributions,
    );
  }


  SalesSummary copyWith({
    double? totalRevenue,
    double? totalDiscount,
    double? netRevenue,
    double? monthlyRevenue,
    double? totalCogs,
    double? totalExpenses,
    double? totalCashIn,
    double? grossProfit,
    double? netProfit,
    double? profitMargin,
    double? monthlyNetProfit,
    int? totalOrders,
    int? totalItems,
    double? avgOrderValue,
    Map<String, double>? revenueByMethod,
    Map<String, int>? ordersBySource,
    List<TopSalesItem>? topItems,
    List<HourlySalePoint>? hourlySales,
    int? cancelledOrders,
    double? cancelledRevenue,
    int? refundedOrders,
    double? refundedRevenue,
    List<TransactionOrder>? refundedOrdersList,
    List<OutletSalesContribution>? outletContributions,
  }) {
    return SalesSummary(
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      netRevenue: netRevenue ?? this.netRevenue,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      totalCogs: totalCogs ?? this.totalCogs,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      totalCashIn: totalCashIn ?? this.totalCashIn,
      grossProfit: grossProfit ?? this.grossProfit,
      netProfit: netProfit ?? this.netProfit,
      profitMargin: profitMargin ?? this.profitMargin,
      monthlyNetProfit: monthlyNetProfit ?? this.monthlyNetProfit,
      totalOrders: totalOrders ?? this.totalOrders,
      totalItems: totalItems ?? this.totalItems,
      avgOrderValue: avgOrderValue ?? this.avgOrderValue,
      revenueByMethod: revenueByMethod ?? this.revenueByMethod,
      ordersBySource: ordersBySource ?? this.ordersBySource,
      topItems: topItems ?? this.topItems,
      hourlySales: hourlySales ?? this.hourlySales,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      cancelledRevenue: cancelledRevenue ?? this.cancelledRevenue,
      refundedOrders: refundedOrders ?? this.refundedOrders,
      refundedRevenue: refundedRevenue ?? this.refundedRevenue,
      refundedOrdersList: refundedOrdersList ?? this.refundedOrdersList,
      outletContributions: outletContributions ?? this.outletContributions,
    );
  }
}

class OutletSalesContribution {
  final String outletId;
  final String outletName;
  final double revenue;
  final int orderCount;
  final double percentage;

  const OutletSalesContribution({
    required this.outletId,
    required this.outletName,
    required this.revenue,
    required this.orderCount,
    required this.percentage,
  });
}

class _OutletAccumulatorSales {
  final String id;
  final String name;
  double revenue = 0;
  int count = 0;
  _OutletAccumulatorSales(this.id, this.name);
}

class TopSalesItem {
  final String name;
  final int qty;
  final double revenue;
  const TopSalesItem(this.name, this.qty, this.revenue);
}

class _TopItemAccumulator {
  final String name;
  final int qty;
  final double revenue;
  const _TopItemAccumulator(this.name, this.qty, this.revenue);
}

class HourlySalePoint {
  final int hour;
  final double revenue;
  final String? label;
  const HourlySalePoint(this.hour, this.revenue, {this.label});
}

// ── Provider ────────────────────────────────────────────────────

final salesSummaryProvider = FutureProvider.autoDispose<SalesSummary>((
  ref,
) async {
  ref.cacheFor(const Duration(minutes: 5));

  final bootstrap = ref.watch(homeBootstrapProvider).value;
  if (bootstrap == null) return SalesSummary.empty();

  final isOwnerOrAdmin = bootstrap.effectiveRole == AppRole.owner ||
      bootstrap.effectiveRole == AppRole.admin;
  final allOutlets = bootstrap.outlets;
  final selectedOutletId = ref.watch(selectedAnalyticsOutletIdProvider);
  final targetOutletId = isOwnerOrAdmin ? selectedOutletId : bootstrap.currentOutlet?.id;

  final outletIds = targetOutletId == null
      ? allOutlets.map((o) => o.id).toList()
      : [targetOutletId];

  if (outletIds.isEmpty) return SalesSummary.empty();

  final period = ref.watch(dashboardPeriodProvider);
  final businessType = bootstrap.business?.businessType;
  final isService = businessType == 'service';

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 1);

  final DateTime startQuery;
  final DateTime endQuery;

  if (period == DashboardPeriod.monthly) {
    startQuery = startOfMonth;
    endQuery = endOfMonth;
  } else {
    startQuery = isService 
        ? startOfDay.subtract(const Duration(days: 6)) 
        : startOfDay;
    endQuery = endOfDay;
  }

  var ordersQuery = SupabaseService.client
      .from('orders')
      .select('*, order_items(*, menu_items(recipe_cost)), order_payments(*)');

  if (targetOutletId != null) {
    ordersQuery = ordersQuery.eq('outlet_id', targetOutletId);
  } else {
    ordersQuery = ordersQuery.inFilter('outlet_id', outletIds);
  }

  List<TransactionOrder> orders = [];
  try {
    final response = await SupabaseService.withAutoRefresh(
      () => ordersQuery
          .gte('created_at', startQuery.toUtc().toIso8601String())
          .lt('created_at', endQuery.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .withNetworkTimeout(operationName: 'memuat ringkasan penjualan'),
    );

    orders = (response as List<dynamic>)
        .map((json) => TransactionOrder.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('[SalesDashboard] Gagal memuat order online ($e), menggunakan data lokal SQLite.');
  }

  // Gabungkan transaksi offline / pending sync dari SQLite lokal agar angka dashboard tidak 0
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
          if (!orderDate.isBefore(startQuery) && orderDate.isBefore(endQuery)) {
            if (targetOutletId == null || localOrder.outletId == targetOutletId) {
              orders.add(localOrder);
            }
          }
        } catch (_) {}
      }
    }
  } catch (_) {}

  final DateTime cashStart;
  final DateTime cashEnd;

  if (period == DashboardPeriod.monthly) {
    cashStart = startOfMonth;
    cashEnd = endOfMonth;
  } else {
    cashStart = startOfDay;
    cashEnd = endOfDay;
  }

  double totalExpenses = 0;
  double totalCashIn = 0;
  try {
    var cashQuery = SupabaseService.client
        .from('cash_flow_entries')
        .select('type, amount');

    if (targetOutletId != null) {
      cashQuery = cashQuery.eq('outlet_id', targetOutletId);
    } else {
      cashQuery = cashQuery.inFilter('outlet_id', outletIds);
    }

    final cashRes = await cashQuery
        .gte('created_at', cashStart.toUtc().toIso8601String())
        .lt('created_at', cashEnd.toUtc().toIso8601String())
        .withNetworkTimeout(duration: const Duration(seconds: 10));

    for (final row in (cashRes as List<dynamic>)) {
      final type = row['type'] as String?;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'out') {
        totalExpenses += amount;
      } else if (type == 'in') {
        totalCashIn += amount;
      }
    }
  } catch (_) {}

  final outletNamesById = {for (final o in allOutlets) o.id: o.name};

  return SalesSummary.fromOrders(
    orders,
    isService: isService,
    period: period,
    totalExpenses: totalExpenses,
    totalCashIn: totalCashIn,
    outletNamesById: targetOutletId == null ? outletNamesById : null,
  );
});

// ── Widget ──────────────────────────────────────────────────────

class SalesDashboardView extends ConsumerWidget {
  const SalesDashboardView({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final period = ref.watch(dashboardPeriodProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 800;

    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final isServiceBusiness = bootstrap?.business?.businessType == 'service';

    void onPeriodChanged(DashboardPeriod p) {
      ref.read(dashboardPeriodProvider.notifier).state = p;
    }

    return Padding(
      padding: padding,
      child: summaryAsync.when(
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(salesSummaryProvider),
          child: isTablet
              ? _buildTabletContent(
                  context,
                  summary,
                  onRefresh: () => ref.invalidate(salesSummaryProvider),
                  isServiceBusiness: isServiceBusiness,
                  period: period,
                  onPeriodChanged: onPeriodChanged,
                )
              : _buildMobileContent(
                  context,
                  summary,
                  onRefresh: () => ref.invalidate(salesSummaryProvider),
                  isServiceBusiness: isServiceBusiness,
                  period: period,
                  onPeriodChanged: onPeriodChanged,
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final isJwtExpired = SupabaseService.isJwtExpiredError(e);
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isJwtExpired
                        ? Icons.lock_clock_rounded
                        : Icons.info_outline_rounded,
                    size: 44,
                    color: isJwtExpired ? Colors.orange.shade700 : Colors.red.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isJwtExpired
                        ? 'Sesi Login Kedaluwarsa'
                        : 'Terjadi Kendala Memuat Data',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isJwtExpired
                        ? 'Aplikasi telah lama berada di latar belakang. Ketuk tombol di bawah untuk menyegarkan sesi secara otomatis.'
                        : '$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      if (isJwtExpired) {
                        await SupabaseService.ensureFreshSession();
                        ref.invalidate(homeBootstrapProvider);
                      }
                      ref.invalidate(salesSummaryProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileContent(
    BuildContext context,
    SalesSummary summary, {
    required VoidCallback onRefresh,
    required bool isServiceBusiness,
    required DashboardPeriod period,
    required ValueChanged<DashboardPeriod> onPeriodChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final isMonthly = period == DashboardPeriod.monthly;
    final dateLabel = isMonthly
        ? DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())
        : DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dashboard Penjualan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const AnalyticsOutletFilterSelector(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        _DashboardPeriodSelector(
          period: period,
          onPeriodChanged: onPeriodChanged,
          isDark: false,
        ),
        const SizedBox(height: 14),
        const PendingStoreActivationBanner(),
        const AnnouncementBannerWidget(),
        _RevenueHeroCard(
          summary: summary,
          isServiceBusiness: isServiceBusiness,
          period: period,
        ),
        if (summary.outletContributions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _OutletContributionCard(contributions: summary.outletContributions),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Laba Bersih',
                value: _formatCompact(summary.netProfit),
                color: const Color(0xFF00C853),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.outbox_rounded,
                label: 'Beban Kas',
                value: _formatCompact(summary.totalExpenses),
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.inventory_2_outlined,
                label: 'Modal (HPP)',
                value: _formatCompact(summary.totalCogs),
                color: Colors.indigo.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.receipt_long_rounded,
                label: 'Total Order',
                value: summary.totalOrders.toString(),
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.shopping_bag_rounded,
                label: 'Total Item',
                value: summary.totalItems.toString(),
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.trending_up_rounded,
                label: isServiceBusiness ? 'Rata-rata Keuntungan' : 'Rata-rata',
                value: _formatCompact(summary.avgOrderValue),
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: isServiceBusiness ? Icons.percent_rounded : Icons.cancel_outlined,
                label: isServiceBusiness ? 'Rata-rata net margin' : 'Batal',
                value: isServiceBusiness
                    ? '100.0%'
                    : '${summary.cancelledOrders} (${_formatCompact(summary.cancelledRevenue)})',
                color: isServiceBusiness ? Colors.teal.shade700 : Colors.red.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.replay_rounded,
                label: 'Refund',
                value: '${summary.refundedOrders} (${_formatCompact(summary.refundedRevenue)})',
                color: Colors.purple.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (summary.hourlySales.isNotEmpty) ...[
          _SectionTitle(
            title: period == DashboardPeriod.monthly
                ? 'Tren Penjualan Harian (Bulan Ini)'
                : (isServiceBusiness ? 'Tren Penjualan (Harian)' : 'Penjualan Per Jam'),
          ),
          const SizedBox(height: 8),
          _HourlyChart(sales: summary.hourlySales),
          const SizedBox(height: 16),
        ],
        if (summary.topItems.isNotEmpty) ...[
          _SectionTitle(title: 'Produk Terlaris'),
          const SizedBox(height: 8),
          _TopProductsList(items: summary.topItems),
          const SizedBox(height: 16),
        ],
        if (summary.revenueByMethod.isNotEmpty) ...[
          _SectionTitle(title: 'Metode Pembayaran'),
          const SizedBox(height: 8),
          _PaymentMethodsCard(methods: summary.revenueByMethod),
          const SizedBox(height: 16),
        ],
        if (summary.ordersBySource.isNotEmpty) ...[
          _SectionTitle(title: 'Sumber Pesanan'),
          const SizedBox(height: 8),
          _OrderSourcesCard(
            sources: summary.ordersBySource,
            total: summary.totalOrders,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildTabletContent(
    BuildContext context,
    SalesSummary summary, {
    required VoidCallback onRefresh,
    required bool isServiceBusiness,
    required DashboardPeriod period,
    required ValueChanged<DashboardPeriod> onPeriodChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width >= 1200 ? 14.0 : 10.0;
        final twoColumnSection = width >= 1100;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dashboard Penjualan',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const AnalyticsOutletFilterSelector(),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                ],
              ),
            ),
            const PendingStoreActivationBanner(),
            _TabletRevenueHeroCard(
              summary: summary,
              onRefresh: onRefresh,
              isServiceBusiness: isServiceBusiness,
              period: period,
              onPeriodChanged: onPeriodChanged,
            ),
            if (summary.outletContributions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _OutletContributionCard(contributions: summary.outletContributions),
            ],
            const SizedBox(height: 12),
            SizedBox(height: gap),
            Row(
              children: [
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF00C853),
                    iconBackground: const Color(0xFFE8F5E9),
                    label: 'LABA BERSIH',
                    value: _formatCompactWithoutSymbol(summary.netProfit),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.outbox_rounded,
                    iconColor: Colors.amber.shade900,
                    iconBackground: Colors.amber.shade50,
                    label: 'BEBAN KAS',
                    value: _formatCompactWithoutSymbol(summary.totalExpenses),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: Colors.indigo.shade700,
                    iconBackground: Colors.indigo.shade50,
                    label: 'MODAL (HPP)',
                    value: _formatCompactWithoutSymbol(summary.totalCogs),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              children: [
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: const Color(0xFF356AE6),
                    iconBackground: const Color(0xFFEAF1FF),
                    label: 'TOTAL ORDER',
                    value: summary.totalOrders.toString(),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFF00796B),
                    iconBackground: const Color(0xFFE0F2F1),
                    label: 'TOTAL ITEM',
                    value: summary.totalItems.toString(),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.people_outline_rounded,
                    iconColor: const Color(0xFFE65A0A),
                    iconBackground: const Color(0xFFFFF1E4),
                    label: isServiceBusiness ? 'RATA-RATA KEUNTUNGAN' : 'RATA-RATA TIKET',
                    value: _formatCompactWithoutSymbol(summary.avgOrderValue),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              children: [
                Expanded(
                  child: _TabletMetricCard(
                    icon: isServiceBusiness ? Icons.percent_rounded : Icons.cancel_outlined,
                    iconColor: isServiceBusiness ? Colors.teal.shade700 : Colors.red.shade700,
                    iconBackground: isServiceBusiness ? Colors.teal.shade50 : Colors.red.shade50,
                    label: isServiceBusiness ? 'RATA-RATA NET MARGIN' : 'BATAL',
                    value: isServiceBusiness
                        ? '100%'
                        : '${summary.cancelledOrders} (${_formatCompactWithoutSymbol(summary.cancelledRevenue)})',
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _TabletMetricCard(
                    icon: Icons.replay_rounded,
                    iconColor: Colors.purple.shade700,
                    iconBackground: Colors.purple.shade50,
                    label: 'REFUND',
                    value: '${summary.refundedOrders} (${_formatCompactWithoutSymbol(summary.refundedRevenue)})',
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            _DashboardSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DashboardSectionLabel(
                        period == DashboardPeriod.monthly
                            ? 'TREN PENJUALAN HARIAN (BULAN INI)'
                            : (isServiceBusiness
                                ? 'VOLUME TRANSAKSI / JAM (HARIAN)'
                                : 'VOLUME TRANSAKSI / JAM'),
                      ),
                      if (period == DashboardPeriod.monthly || isServiceBusiness)
                        Text(
                          period == DashboardPeriod.monthly ? 'BULANAN' : 'HARIAN',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (summary.hourlySales.isEmpty)
                    _DashboardEmptyState(
                      icon: Icons.bar_chart_rounded,
                      title: period == DashboardPeriod.monthly
                          ? 'Belum ada transaksi bulan ini'
                          : 'Belum ada transaksi hari ini',
                      message:
                          'Grafik akan muncul setelah ada order yang lunas.',
                    )
                  else
                    _HourlyChart(
                      sales: summary.hourlySales,
                      framed: false,
                      height: width >= 1280 ? 160 : 128,
                    ),
                ],
              ),
            ),
            SizedBox(height: gap),
            if (twoColumnSection)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DashboardSurfaceCard(
                      child: _TabletTopProductsPanel(items: summary.topItems),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _DashboardSurfaceCard(
                      child: _TabletPaymentMethodsPanel(
                        methods: summary.revenueByMethod,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _DashboardSurfaceCard(
                    child: _TabletTopProductsPanel(items: summary.topItems),
                  ),
                  SizedBox(height: gap),
                  _DashboardSurfaceCard(
                    child: _TabletPaymentMethodsPanel(
                      methods: summary.revenueByMethod,
                    ),
                  ),
                ],
              ),
            SizedBox(height: gap),
            _TabletOrderSourcesBanner(
              sources: summary.ordersBySource,
              totalOrders: summary.totalOrders,
            ),
            if (summary.refundedOrdersList.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DashboardSurfaceCard(
                child: _TabletRecentRefundsPanel(
                  orders: summary.refundedOrdersList,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  static String _formatCompact(double value) {
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    }
    return _currency.format(value);
  }
}

String _formatCompactWithoutSymbol(double value) {
  if (value >= 1000000) {
    final fractionDigits = value >= 10000000 ? 0 : 1;
    return '${(value / 1000000).toStringAsFixed(fractionDigits)}jt';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}rb';
  }
  return _decimalNumber.format(value.round());
}

String _formatCompactWithSymbol(double value) {
  if (value >= 1000000) {
    final fractionDigits = value >= 10000000 ? 0 : 1;
    return 'Rp ${(value / 1000000).toStringAsFixed(fractionDigits)}jt';
  }
  if (value >= 1000) {
    return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
  }
  return _currency.format(value);
}

// ── Period Selector Widget ──────────────────────────────────────

class _DashboardPeriodSelector extends StatelessWidget {
  const _DashboardPeriodSelector({
    required this.period,
    required this.onPeriodChanged,
    this.isDark = false,
  });

  final DashboardPeriod period;
  final ValueChanged<DashboardPeriod> onPeriodChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.50);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : scheme.outlineVariant.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DashboardPeriod.values.map((p) {
          final isSelected = p == period;

          final selectedBg = isDark
              ? const Color(0xFF46E1D5)
              : scheme.primary;
          final selectedTextColor = isDark
              ? const Color(0xFF163633)
              : scheme.onPrimary;
          final unselectedTextColor = isDark
              ? Colors.white.withValues(alpha: 0.75)
              : scheme.onSurfaceVariant;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onPeriodChanged(p),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: selectedBg.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p == DashboardPeriod.daily
                          ? Icons.today_rounded
                          : Icons.calendar_month_rounded,
                      size: 15,
                      color: isSelected ? selectedTextColor : unselectedTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.label,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? selectedTextColor : unselectedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Revenue Hero Card ───────────────────────────────────────────

class _RevenueHeroCard extends StatelessWidget {
  const _RevenueHeroCard({
    required this.summary,
    required this.isServiceBusiness,
    this.period = DashboardPeriod.daily,
  });
  final SalesSummary summary;
  final bool isServiceBusiness;
  final DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMonthly = period == DashboardPeriod.monthly;
    final revenue = summary.totalRevenue;
    final netProfit = summary.netProfit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2027).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Pendapatan (Omzet)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.greenAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isMonthly ? 'Total Pendapatan (Bulan Ini)' : 'Total Pendapatan / Omzet (Hari Ini)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currency.format(revenue),
            style: GoogleFonts.manrope(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),
          // Section 2: Pemisah Laba Bersih
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (netProfit >= 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (netProfit >= 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isMonthly ? 'Laba Bersih (Bulan Ini)' : 'Estimasi Laba Bersih',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (netProfit >= 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Margin ${summary.profitMargin.toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currency.format(netProfit),
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: netProfit >= 0 ? Colors.white : Colors.redAccent.shade100,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (summary.totalCogs > 0 || summary.totalExpenses > 0 || summary.totalDiscount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (summary.totalCogs > 0)
                  _HeroPill(
                    icon: Icons.inventory_2_outlined,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    iconColor: Colors.amberAccent,
                    textColor: Colors.white70,
                    label: 'Modal: ${_formatCompactWithSymbol(summary.totalCogs)}',
                  ),
                if (summary.totalExpenses > 0)
                  _HeroPill(
                    icon: Icons.outbox_rounded,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    iconColor: Colors.orangeAccent,
                    textColor: Colors.white70,
                    label: 'Beban: ${_formatCompactWithSymbol(summary.totalExpenses)}',
                  ),
                if (summary.totalDiscount > 0)
                  _HeroPill(
                    icon: Icons.discount_outlined,
                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.12),
                    iconColor: Colors.greenAccent,
                    textColor: Colors.greenAccent.shade100,
                    label: 'Diskon: ${_formatCompactWithSymbol(summary.totalDiscount)}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TabletRevenueHeroCard extends StatelessWidget {
  const _TabletRevenueHeroCard({
    required this.summary,
    required this.onRefresh,
    required this.isServiceBusiness,
    required this.period,
    required this.onPeriodChanged,
  });

  final SalesSummary summary;
  final VoidCallback onRefresh;
  final bool isServiceBusiness;
  final DashboardPeriod period;
  final ValueChanged<DashboardPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMonthly = period == DashboardPeriod.monthly;
    final dateLabel = isMonthly
        ? DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())
        : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());
    final discountLabel = summary.totalDiscount > 0
        ? 'DISKON: ${_formatCompactWithSymbol(summary.totalDiscount)}'
        : 'TANPA DISKON';
    final revenue = summary.totalRevenue;
    final netProfit = summary.netProfit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3E3A), Color(0xFF163633)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163633).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMonthly ? 'RINGKASAN BULAN INI' : 'RINGKASAN HARI INI',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF46E1D5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _capitalizeDate(dateLabel),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _DashboardPeriodSelector(
                period: period,
                onPeriodChanged: onPeriodChanged,
                isDark: true,
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF5FE7DB),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Dual Column layout for Tablet
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Column 1: Total Pendapatan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMonthly ? 'TOTAL PENDAPATAN (BULAN INI)' : 'TOTAL PENDAPATAN (OMZET)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white60,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Rp ',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                            TextSpan(
                              text: _decimalNumber.format(revenue.round()),
                              style: GoogleFonts.manrope(
                                fontSize: 36,
                                height: 0.95,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 55,
                color: Colors.white.withValues(alpha: 0.12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Column 2: Estimasi Laba Bersih
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isMonthly ? 'LABA BERSIH (BULAN INI)' : 'ESTIMASI LABA BERSIH',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white60,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF46E1D5).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Margin ${summary.profitMargin.toStringAsFixed(1)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF46E1D5),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _currency.format(netProfit),
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: netProfit >= 0 ? const Color(0xFF46E1D5) : Colors.redAccent.shade100,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeroPill(
                icon: Icons.arrow_outward_rounded,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                iconColor: const Color(0xFF5FE7DB),
                textColor: const Color(0xFF5FE7DB),
                label: '${summary.totalItems} item terjual',
              ),
              if (summary.totalCogs > 0)
                _HeroPill(
                  icon: Icons.inventory_2_outlined,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  iconColor: Colors.amberAccent,
                  textColor: Colors.amberAccent.shade100,
                  label: 'Modal: ${_formatCompactWithSymbol(summary.totalCogs)}',
                ),
              if (summary.totalExpenses > 0)
                _HeroPill(
                  icon: Icons.outbox_rounded,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  iconColor: Colors.orangeAccent,
                  textColor: Colors.orangeAccent.shade100,
                  label: 'Beban: ${_formatCompactWithSymbol(summary.totalExpenses)}',
                ),
              _HeroPill(
                icon: Icons.receipt_long_outlined,
                backgroundColor: const Color(0xFFFF9A0C),
                iconColor: Colors.white,
                textColor: Colors.white,
                label: discountLabel,
                shadowColor: const Color(0xFFFF9A0C).withValues(alpha: 0.34),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.label,
    this.shadowColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final String label;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: shadowColor == null
            ? const []
            : [
                BoxShadow(
                  color: shadowColor!,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletMetricCard extends StatelessWidget {
  const _TabletMetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _DashboardSurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 26,
                height: 0.96,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E2A46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSurfaceCard extends StatelessWidget {
  const _DashboardSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DashboardSectionLabel extends StatelessWidget {
  const _DashboardSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: scheme.outline),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _TabletTopProductsPanel extends StatelessWidget {
  const _TabletTopProductsPanel({required this.items});

  final List<TopSalesItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(3).toList();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const accents = [Color(0xFFFF9513), Color(0xFF334155), Color(0xFF0F766E)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSectionLabel('TOP MENU'),
        const SizedBox(height: 10),
        if (visibleItems.isEmpty)
          const _DashboardEmptyState(
            icon: Icons.local_cafe_outlined,
            title: 'Belum ada produk terlaris',
            message: 'Data menu favorit muncul setelah ada transaksi.',
          )
        else
          ...visibleItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final accent = accents[index % accents.length];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleItems.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 44,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F2A44),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.qty} TERJUAL',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.outline,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currency.format(item.revenue),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFF6B00),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 14),
        Row(
          children: [
            InkWell(
              onTap: () {
                // TODO: Navigate to detail
              },
              child: Row(
                children: [
                  Text(
                    'DETAIL PRODUK',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFF6B00),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFFFF6B00),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (items.length > visibleItems.length)
              Text(
                '+${items.length - visibleItems.length} lainnya',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TabletPaymentMethodsPanel extends StatelessWidget {
  const _TabletPaymentMethodsPanel({required this.methods});

  final Map<String, double> methods;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = methods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSectionLabel('METODE BAYAR'),
        const SizedBox(height: 10),
        if (sortedEntries.isEmpty)
          const _DashboardEmptyState(
            icon: Icons.payment_outlined,
            title: 'Belum ada pembayaran',
            message: 'Metode pembayaran akan muncul saat transaksi masuk.',
          )
        else
          ...sortedEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final methodEntry = entry.value;
            final methodStyle = _paymentMethodStyle(methodEntry.key);

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == sortedEntries.length - 1 ? 0 : 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: methodStyle.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      methodStyle.icon,
                      color: methodStyle.foreground,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      methodEntry.key,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF44526D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currency.format(methodEntry.value),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E2A46),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (sortedEntries.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(color: scheme.outline.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Total Pembayaran',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _currency.format(
                  sortedEntries.fold<double>(
                    0,
                    (sum, entry) => sum + entry.value,
                  ),
                ),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E2A46),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TabletOrderSourcesBanner extends StatelessWidget {
  const _TabletOrderSourcesBanner({
    required this.sources,
    required this.totalOrders,
  });

  final Map<String, int> sources;
  final int totalOrders;

  @override
  Widget build(BuildContext context) {
    final sortedSources = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSource = sortedSources.isNotEmpty ? sortedSources.first : null;
    final distribution = topSource == null || totalOrders == 0
        ? 0
        : ((topSource.value / totalOrders) * 100).round();
    final isSingleSource = topSource != null && sources.length == 1;

    final title = topSource == null
        ? 'Belum Ada Sumber Pesanan'
        : isSingleSource
        ? 'Sumber Pesanan Tunggal'
        : 'Sumber Pesanan Dominan';
    final description = topSource == null
        ? 'Kartu ini akan menampilkan sumber order paling aktif setelah ada transaksi hari ini.'
        : isSingleSource
        ? 'Semua transaksi hari ini tercatat berasal dari ${topSource.key}.'
        : '${topSource.value} dari $totalOrders transaksi hari ini berasal dari ${topSource.key}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA312), Color(0xFFFF9300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          final summaryPanel = _OrderSourcesStatsPanel(
            totalOrders: totalOrders,
            distribution: distribution,
          );

          return wide
              ? Row(
                  children: [
                    Expanded(
                      child: _OrderSourcesBannerContent(
                        title: title,
                        description: description,
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(width: 300, child: summaryPanel),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrderSourcesBannerContent(
                      title: title,
                      description: description,
                    ),
                    const SizedBox(height: 14),
                    summaryPanel,
                  ],
                );
        },
      ),
    );
  }
}

class _OrderSourcesBannerContent extends StatelessWidget {
  const _OrderSourcesBannerContent({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.grid_view_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderSourcesStatsPanel extends StatelessWidget {
  const _OrderSourcesStatsPanel({
    required this.totalOrders,
    required this.distribution,
  });

  final int totalOrders;
  final int distribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OrderSourcesStatBlock(
              label: 'TOTAL ORDER',
              value: totalOrders.toString(),
            ),
          ),
          Container(
            width: 1,
            height: 58,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          Expanded(
            child: _OrderSourcesStatBlock(
              label: 'DISTRIBUSI',
              value: '$distribution%',
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSourcesStatBlock extends StatelessWidget {
  const _OrderSourcesStatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.84),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 24,
            height: 0.95,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── KPI Card ────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ───────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

// ── Hourly Chart ────────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({
    required this.sales,
    this.framed = true,
    this.height = 148,
  });
  final List<HourlySalePoint> sales;
  final bool framed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (sales.isEmpty) return const SizedBox.shrink();

    final maxRevenue = sales
        .map((s) => s.revenue)
        .reduce((a, b) => a > b ? a : b);

    final labelFontSize = height >= 200 ? 10.0 : 8.0;
    final hourFontSize = height >= 200 ? 11.0 : 9.0;

    final content = SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableBarHeight = (constraints.maxHeight - 34)
              .clamp(36.0, height - 36)
              .toDouble();

          final minWidth = sales.length * 28.0;
          final needsScroll = minWidth > constraints.maxWidth;

          Widget buildRow() {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sales.map((sale) {
                final revenueBarHeight = maxRevenue > 0
                    ? (sale.revenue / maxRevenue) * availableBarHeight
                    : 0.0;
                final barContent = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatShort(sale.revenue),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: labelFontSize,
                          height: 1,
                          color: scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: needsScroll ? 20 : null,
                        height: revenueBarHeight.clamp(6, availableBarHeight),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: 0.68),
                              scheme.primary,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sale.label ?? '${sale.hour.toString().padLeft(2, '0')}:00',
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: hourFontSize,
                          height: 1,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                );

                if (needsScroll) {
                  return SizedBox(
                    width: 28.0,
                    child: barContent,
                  );
                } else {
                  return Expanded(child: barContent);
                }
              }).toList(),
            );
          }

          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: minWidth,
                child: buildRow(),
              ),
            );
          }

          return buildRow();
        },
      ),
    );

    if (!framed) return content;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: content,
    );
  }

  static String _formatShort(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }
}

// ── Top Products List ───────────────────────────────────────────

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.items});
  final List<TopSalesItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final medalColor = index == 0
              ? Colors.amber.shade700
              : index == 1
              ? Colors.blueGrey.shade400
              : index == 2
              ? Colors.brown.shade400
              : scheme.outline;

          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 10 : 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: medalColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: medalColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${item.qty} terjual',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currency.format(item.revenue),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Payment Methods Card ────────────────────────────────────────

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({required this.methods});
  final Map<String, double> methods;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final total = methods.values.fold(0.0, (a, b) => a + b);

    final colors = [
      Colors.blue.shade600,
      Colors.teal.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.indigo.shade600,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: methods.entries.toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final e = entry.value;
                  final fraction = total > 0 ? e.value / total : 0.0;
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(color: colors[idx % colors.length]),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...methods.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final pct = total > 0 ? (e.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[idx % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currency.format(e.value),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Order Sources Card ──────────────────────────────────────────

class _OrderSourcesCard extends StatelessWidget {
  const _OrderSourcesCard({required this.sources, required this.total});
  final Map<String, int> sources;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: sources.entries.map((e) {
          final pct = total > 0 ? (e.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value} order',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaymentMethodStyle {
  const _PaymentMethodStyle({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}

_PaymentMethodStyle _paymentMethodStyle(String methodName) {
  final normalized = methodName.toLowerCase();

  if (normalized.contains('cash') || normalized.contains('tunai')) {
    return const _PaymentMethodStyle(
      icon: Icons.account_balance_wallet_outlined,
      foreground: Color(0xFF1677F0),
      background: Color(0xFFE8F1FF),
    );
  }
  if (normalized.contains('debit') ||
      normalized.contains('credit') ||
      normalized.contains('kartu')) {
    return const _PaymentMethodStyle(
      icon: Icons.credit_card_outlined,
      foreground: Color(0xFF0AA68F),
      background: Color(0xFFE6FAF6),
    );
  }
  if (normalized.contains('qris') || normalized.contains('qr')) {
    return const _PaymentMethodStyle(
      icon: Icons.phone_android_outlined,
      foreground: Color(0xFFFF9800),
      background: Color(0xFFFFF2DE),
    );
  }

  return const _PaymentMethodStyle(
    icon: Icons.payments_outlined,
    foreground: Color(0xFF5C6BC0),
    background: Color(0xFFEEF1FF),
  );
}

String _capitalizeDate(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

class _TabletRecentRefundsPanel extends StatelessWidget {
  const _TabletRecentRefundsPanel({required this.orders});
  final List<TransactionOrder> orders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeFormat = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSectionLabel('REFUND TERBARU'),
        const SizedBox(height: 16),
        ...orders.take(5).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final order = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: index < orders.length - 1 ? 12 : 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.replay_rounded,
                    size: 18,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.invoiceNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${order.paidAt != null ? timeFormat.format(order.paidAt!) : '-'} • ${order.totalItemCount} item',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currency.format(order.grandTotal),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _OutletContributionCard extends StatelessWidget {
  const _OutletContributionCard({required this.contributions});
  final List<OutletSalesContribution> contributions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _DashboardSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.apartment_rounded, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KONTRIBUSI PENJUALAN PER CABANG',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Perbandingan omzet antar outlet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${contributions.length} Outlet',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...contributions.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              c.outletName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${c.orderCount} order)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currency.format(c.revenue),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Stack(
                    children: [
                      Container(
                        height: 7,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (c.percentage / 100).clamp(0.02, 1.0),
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [scheme.primary, scheme.secondary],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${c.percentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

