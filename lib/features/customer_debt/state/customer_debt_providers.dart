import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/customer_debt/data/customer_debt_repository.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';

/// State untuk pencarian pelanggan
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

/// State filter status kasbon (null = Semua, unpaid, partially_paid, paid, bad_debt)
final debtFilterStatusProvider = StateProvider<DebtStatus?>((ref) => null);

/// Provider untuk mengambil daftar pelanggan toko
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final businessId = bootstrap?.business?.id;
  if (businessId == null) return [];

  final query = ref.watch(customerSearchQueryProvider);
  final repo = ref.watch(customerDebtRepositoryProvider);
  return repo.getCustomers(businessId, searchQuery: query);
});

/// Provider untuk mengambil daftar kasbon / piutang toko
final customerDebtsProvider = FutureProvider<List<CustomerDebt>>((ref) async {
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final businessId = bootstrap?.business?.id;
  if (businessId == null) return [];

  final status = ref.watch(debtFilterStatusProvider);
  final repo = ref.watch(customerDebtRepositoryProvider);
  return repo.getDebts(businessId, status: status);
});

/// Provider untuk mengambil riwayat cicilan kasbon tertentu
final debtPaymentsProvider =
    FutureProvider.family<List<DebtPayment>, String>((ref, debtId) async {
  final repo = ref.watch(customerDebtRepositoryProvider);
  return repo.getDebtPayments(debtId);
});

/// Provider untuk mengambil semua kasbon milik pelanggan tertentu
final customerDebtsByCustomerProvider =
    FutureProvider.family<List<CustomerDebt>, String>((ref, customerId) async {
  final repo = ref.watch(customerDebtRepositoryProvider);
  return repo.getCustomerDebtsByCustomerId(customerId);
});

class DebtSummary {
  final double totalUnpaid;
  final int countUnpaid;
  final int countOverdue;
  final double totalOverdue;
  final double totalPaid;
  final int countPaid;

  const DebtSummary({
    required this.totalUnpaid,
    required this.countUnpaid,
    required this.countOverdue,
    required this.totalOverdue,
    this.totalPaid = 0,
    this.countPaid = 0,
  });
}

/// Provider ringkasan total kasbon aktif
final debtSummaryProvider = Provider<DebtSummary>((ref) {
  final debtsAsync = ref.watch(customerDebtsProvider);
  final debts = debtsAsync.value ?? [];

  double totalUnpaid = 0;
  int countUnpaid = 0;
  int countOverdue = 0;
  double totalOverdue = 0;
  double totalPaid = 0;
  int countPaid = 0;

  for (final d in debts) {
    if (!d.isPaid) {
      totalUnpaid += d.remainingAmount;
      countUnpaid++;
      totalPaid += (d.totalAmount - d.remainingAmount);

      if (d.isOverdue) {
        countOverdue++;
        totalOverdue += d.remainingAmount;
      }
    } else {
      totalPaid += d.totalAmount;
      countPaid++;
    }
  }

  return DebtSummary(
    totalUnpaid: totalUnpaid,
    countUnpaid: countUnpaid,
    countOverdue: countOverdue,
    totalOverdue: totalOverdue,
    totalPaid: totalPaid,
    countPaid: countPaid,
  );
});
