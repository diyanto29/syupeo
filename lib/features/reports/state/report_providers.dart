import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/analytics_outlet_filter_provider.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/reports/data/report_repository.dart';
import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/utils/riverpod_cache_extension.dart';

// ── Repository Provider ─────────────────────────────────────────
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(SupabaseService.client);
});

// ── Selected Period Provider ────────────────────────────────────
final selectedReportPeriodProvider = StateProvider<ReportPeriod>((ref) {
  return ReportPeriod.today;
});

// ── Custom Date Range (for custom period) ───────────────────────
final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) {
  return null;
});

// ── Effective Date Range ────────────────────────────────────────
DateTimeRange effectiveDateRange(WidgetRef ref) {
  final period = ref.read(selectedReportPeriodProvider);
  if (period == ReportPeriod.custom) {
    return ref.read(customDateRangeProvider) ?? ReportPeriod.today.dateRange;
  }
  return period.dateRange;
}

// ── Report Data Provider ────────────────────────────────────────
final reportDataProvider =
    FutureProvider.autoDispose<FullReport>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  if (bootstrap == null) {
    return FullReport.empty(ReportPeriod.today.dateRange);
  }

  final isOwnerOrAdmin = bootstrap.effectiveRole == AppRole.owner ||
      bootstrap.effectiveRole == AppRole.admin;
  final allOutlets = bootstrap.outlets;
  final selectedOutletId = ref.watch(selectedAnalyticsOutletIdProvider);
  final targetOutletId = isOwnerOrAdmin ? selectedOutletId : bootstrap.currentOutlet?.id;

  final outletIds = targetOutletId == null
      ? allOutlets.map((o) => o.id).toList()
      : [targetOutletId];

  if (outletIds.isEmpty) {
    return FullReport.empty(ReportPeriod.today.dateRange);
  }

  final period = ref.watch(selectedReportPeriodProvider);
  final customRange = ref.watch(customDateRangeProvider);

  final range = period == ReportPeriod.custom
      ? (customRange ?? ReportPeriod.today.dateRange)
      : period.dateRange;

  final outletNamesById = {for (final o in allOutlets) o.id: o.name};

  return ref.read(reportRepositoryProvider).generateReport(
        outletId: targetOutletId,
        outletIds: targetOutletId == null ? outletIds : null,
        outletNamesById: outletNamesById,
        period: range,
      );
});

// ── Selected Report Tab ─────────────────────────────────────────
enum ReportTab {
  overview('Ringkasan', isPro: false),
  outlets('Per Cabang', isPro: true),
  cashFlow('Arus Kas', isPro: true),
  products('Produk', isPro: true),
  cashiers('Kasir', isPro: true),
  waiters('Waiter', isPro: true),
  payments('Pembayaran', isPro: true),
  daily('Harian', isPro: false);

  const ReportTab(this.label, {this.isPro = false});
  final String label;
  final bool isPro;
}

final selectedReportTabProvider = StateProvider<ReportTab>((ref) {
  return ReportTab.overview;
});

// ── Cash Flow Report Data Provider ─────────────────────────────
final reportCashFlowDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  if (bootstrap == null) {
    return {
      'totalSalesCash': 0.0,
      'totalCashIn': 0.0,
      'totalCashOut': 0.0,
      'netCash': 0.0,
      'categories': <String, double>{},
      'entries': <CashFlowEntry>[],
    };
  }

  final isOwnerOrAdmin = bootstrap.effectiveRole == AppRole.owner ||
      bootstrap.effectiveRole == AppRole.admin;
  final allOutlets = bootstrap.outlets;
  final selectedOutletId = ref.watch(selectedAnalyticsOutletIdProvider);
  final targetOutletId = isOwnerOrAdmin ? selectedOutletId : bootstrap.currentOutlet?.id;

  final outletIds = targetOutletId == null
      ? allOutlets.map((o) => o.id).toList()
      : [targetOutletId];

  if (outletIds.isEmpty) {
    return {
      'totalSalesCash': 0.0,
      'totalCashIn': 0.0,
      'totalCashOut': 0.0,
      'netCash': 0.0,
      'categories': <String, double>{},
      'entries': <CashFlowEntry>[],
    };
  }

  final period = ref.watch(selectedReportPeriodProvider);
  final customRange = ref.watch(customDateRangeProvider);
  final range = period == ReportPeriod.custom
      ? (customRange ?? ReportPeriod.today.dateRange)
      : period.dateRange;

  final repo = ref.watch(cashFlowRepositoryProvider);
  final entries = await repo.getCashEntries(
    targetOutletId,
    outletIds: targetOutletId == null ? outletIds : null,
    fromDate: range.start,
    toDate: range.end,
    limit: 300,
  );

  final totals = await repo.calculateShiftTotals(
    targetOutletId,
    range.start,
    closedAt: range.end,
    outletIds: targetOutletId == null ? outletIds : null,
  );

  final totalSalesCash = totals['totalSalesCash'] ?? 0.0;
  double totalCashIn = 0.0;
  double totalCashOut = 0.0;
  final Map<String, double> categoryBreakdown = {};

  for (final e in entries) {
    if (e.type == CashFlowType.cashIn) {
      totalCashIn += e.amount;
    } else {
      totalCashOut += e.amount;
      categoryBreakdown[e.category] =
          (categoryBreakdown[e.category] ?? 0.0) + e.amount;
    }
  }

  final netCash = (totalSalesCash + totalCashIn) - totalCashOut;

  return {
    'totalSalesCash': totalSalesCash,
    'totalCashIn': totalCashIn,
    'totalCashOut': totalCashOut,
    'netCash': netCash,
    'categories': categoryBreakdown,
    'entries': entries,
  };
});

