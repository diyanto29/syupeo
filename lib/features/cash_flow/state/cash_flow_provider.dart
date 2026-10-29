import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/core/utils/riverpod_cache_extension.dart';

/// Provider untuk mengambil shift aktif saat ini
final activeShiftProvider =
    AsyncNotifierProvider<ActiveShiftNotifier, CashShift?>(() {
  return ActiveShiftNotifier();
});

class ActiveShiftNotifier extends AsyncNotifier<CashShift?> {
  @override
  Future<CashShift?> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) return null;

    final repo = ref.watch(cashFlowRepositoryProvider);
    return repo.getActiveShift(outletId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider ringkasan kalkulasi live saldo shift / harian saat ini
final shiftLiveTotalsProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final shift = ref.watch(activeShiftProvider).value;
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final outletId = shift?.outletId ?? bootstrap?.currentOutlet?.id;

  if (outletId == null) {
    return {
      'totalSalesCash': 0.0,
      'totalCashIn': 0.0,
      'totalCashOut': 0.0,
      'drawerBalance': 0.0,
    };
  }

  final repo = ref.watch(cashFlowRepositoryProvider);

  if (shift != null) {
    // Mode Shift: Dihitung dari waktu buka shift + modal kas awal
    final totals = await repo.calculateShiftTotals(shift.outletId, shift.openedAt);
    final salesCash = totals['totalSalesCash'] ?? 0;
    final cashIn = totals['totalCashIn'] ?? 0;
    final cashOut = totals['totalCashOut'] ?? 0;
    final drawerBalance = shift.startingCash + salesCash + cashIn - cashOut;

    return {
      'totalSalesCash': salesCash,
      'totalCashIn': cashIn,
      'totalCashOut': cashOut,
      'drawerBalance': drawerBalance,
    };
  } else {
    // Mode Tanpa Shift: Dihitung akumulasi kas hari ini (sejak 00:00)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final totals = await repo.calculateShiftTotals(outletId, startOfDay);
    final salesCash = totals['totalSalesCash'] ?? 0;
    final cashIn = totals['totalCashIn'] ?? 0;
    final cashOut = totals['totalCashOut'] ?? 0;
    final drawerBalance = salesCash + cashIn - cashOut;

    return {
      'totalSalesCash': salesCash,
      'totalCashIn': cashIn,
      'totalCashOut': cashOut,
      'drawerBalance': drawerBalance,
    };
  }
});

/// Provider riwayat mutasi kas hari ini
final todayCashEntriesProvider =
    FutureProvider.autoDispose<List<CashFlowEntry>>((ref) async {
  ref.cacheFor(const Duration(minutes: 3));
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final outletId = bootstrap?.currentOutlet?.id;
  if (outletId == null) return [];

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final repo = ref.watch(cashFlowRepositoryProvider);

  return repo.getCashEntries(outletId, fromDate: startOfDay);
});

/// Provider riwayat shift kasir (Owner & Admin melihat seluruh kasir, Staff/Kasir hanya miliknya sendiri)
final shiftHistoryProvider =
    FutureProvider.autoDispose<List<CashShift>>((ref) async {
  ref.cacheFor(const Duration(minutes: 3));
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final outletId = bootstrap?.currentOutlet?.id;
  if (outletId == null) return [];

  final isOwnerOrAdmin = bootstrap?.effectiveRole == AppRole.owner ||
      bootstrap?.effectiveRole == AppRole.admin;
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // Kasir / Staff biasa hanya melihat riwayat shift yang dia buka/jalankan sendiri
  final filterCashierId = isOwnerOrAdmin ? null : currentUserId;

  final repo = ref.watch(cashFlowRepositoryProvider);
  return repo.getShiftHistory(outletId, cashierId: filterCashierId, limit: 50);
});

/// Provider untuk mengambil daftar pesanan/transaksi yang terjadi pada shift tertentu
final shiftOrdersProvider =
    FutureProvider.family.autoDispose<List<TransactionOrder>, CashShift>((ref, shift) async {
  if (shift.isClosed) {
    ref.cacheFor(const Duration(minutes: 5));
  } else {
    // Sesi shift yang sedang aktif: hanya cache 5 detik agar transaksi baru kasir langsung muncul instan
    ref.cacheFor(const Duration(seconds: 5));
  }
  final repo = ref.watch(cashFlowRepositoryProvider);
  return repo.getShiftOrders(
    outletId: shift.outletId,
    openedAt: shift.openedAt,
    closedAt: shift.closedAt,
  );
});

