import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/customer_debt/data/customer_debt_repository.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';
import 'package:dpos/features/customer_debt/presentation/customer_form_screen.dart';
import 'package:dpos/features/customer_debt/presentation/widgets/customer_debt_detail_panel.dart';
import 'package:dpos/features/customer_debt/presentation/widgets/pay_debt_dialog.dart';
import 'package:dpos/features/customer_debt/state/customer_debt_providers.dart';

class CustomerDebtScreen extends ConsumerStatefulWidget {
  final EdgeInsets padding;

  const CustomerDebtScreen({
    super.key,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  ConsumerState<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends ConsumerState<CustomerDebtScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  CustomerDebt? _selectedDebt;
  Customer? _selectedCustomer;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final _dateFormat = DateFormat('d MMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(debtSummaryProvider);
    final debtsAsync = ref.watch(customerDebtsProvider);
    final customersAsync = ref.watch(customersProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;

    // Sinkronisasi item terpilih dengan data terbaru
    CustomerDebt? effectiveSelectedDebt = _selectedDebt;
    if (debtsAsync.hasValue && (debtsAsync.value?.isNotEmpty ?? false)) {
      final list = debtsAsync.value!;
      if (effectiveSelectedDebt == null) {
        effectiveSelectedDebt = list.first;
      } else {
        effectiveSelectedDebt =
            list.where((d) => d.id == effectiveSelectedDebt!.id).firstOrNull ??
                list.first;
      }
    }

    Customer? effectiveSelectedCustomer = _selectedCustomer;
    if (customersAsync.hasValue && (customersAsync.value?.isNotEmpty ?? false)) {
      final list = customersAsync.value!;
      if (effectiveSelectedCustomer == null) {
        effectiveSelectedCustomer = list.first;
      } else {
        effectiveSelectedCustomer =
            list.where((c) => c.id == effectiveSelectedCustomer!.id).firstOrNull ??
                list.first;
      }
    }

    final customersWithDebtCount =
        customersAsync.value?.where((c) => c.hasDebt).length ?? 0;
    final totalCustomersCount = customersAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                CustomerFormScreen.open(context);
              },
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                'Tambah Pelanggan',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
              ),
            ),
      body: SingleChildScrollView(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Title ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buku Kasbon & Pelanggan',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola piutang pelanggan, jatuh tempo & kirim tagihan WhatsApp',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDesktop) ...[
                  FilledButton.icon(
                    onPressed: () => CustomerFormScreen.open(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(
                      'Tambah Pelanggan',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  onPressed: () {
                    ref.invalidate(customerDebtsProvider);
                    ref.invalidate(customersProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Segarkan Data',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Ringkasan Piutang (Metric Cards) ───────────────────────────
            if (isDesktop)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'TOTAL PIUTANG AKTIF',
                      value: _currency.format(summary.totalUnpaid),
                      subtitle: '${summary.countUnpaid} nota belum lunas',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'LEWAT JATUH TEMPO',
                      value: '${summary.countOverdue} Nota',
                      subtitle: _currency.format(summary.totalOverdue),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PELANGGAN KASBON',
                      value: '$customersWithDebtCount Orang',
                      subtitle: 'Dari total $totalCustomersCount kontak',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'SUDAH TERBAYAR',
                      value: _currency.format(summary.totalPaid),
                      subtitle: '${summary.countPaid} nota lunas',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'TOTAL PIUTANG AKTIF',
                      value: _currency.format(summary.totalUnpaid),
                      subtitle: '${summary.countUnpaid} nota belum lunas',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'LEWAT JATUH TEMPO',
                      value: '${summary.countOverdue} Nota',
                      subtitle: _currency.format(summary.totalOverdue),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // ── Tab Bar ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                labelColor: const Color(0xFF059669),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Daftar Kasbon (Piutang)'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_alt_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Kontak Pelanggan'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab Content ───────────────────────────────────────────────
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                if (_tabController.index == 0) {
                  return _buildDebtsTab(
                    isDesktop: isDesktop,
                    effectiveSelectedDebt: effectiveSelectedDebt,
                  );
                } else {
                  return _buildCustomersTab(
                    isDesktop: isDesktop,
                    effectiveSelectedCustomer: effectiveSelectedCustomer,
                  );
                }
              },
            ),
            SizedBox(height: isDesktop ? 40 : 80),
          ],
        ),
      ),
    );
  }

  // ── METRIC CARD ───────────────────────────────────────────────────────────
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: BUKU KASBON ─────────────────────────────────────────────────────
  Widget _buildDebtsTab({
    required bool isDesktop,
    CustomerDebt? effectiveSelectedDebt,
  }) {
    final debtsAsync = ref.watch(customerDebtsProvider);
    final selectedStatus = ref.watch(debtFilterStatusProvider);

    final leftList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _statusChip('Semua', null, selectedStatus == null),
              const SizedBox(width: 8),
              _statusChip('Belum Lunas', DebtStatus.unpaid,
                  selectedStatus == DebtStatus.unpaid),
              const SizedBox(width: 8),
              _statusChip('Dicicil', DebtStatus.partiallyPaid,
                  selectedStatus == DebtStatus.partiallyPaid),
              const SizedBox(width: 8),
              _statusChip(
                  'Lunas', DebtStatus.paid, selectedStatus == DebtStatus.paid),
            ],
          ),
        ),
        const SizedBox(height: 16),

        debtsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text('Gagal memuat kasbon: $err')),
          ),
          data: (debts) {
            if (debts.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 40,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak Ada Data Kasbon',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Semua tagihan lunas atau belum ada catatan piutang.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: debts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final debt = debts[index];
                final isSelected = isDesktop && effectiveSelectedDebt?.id == debt.id;
                return _buildDebtCard(
                  debt,
                  isSelected: isSelected,
                  isDesktop: isDesktop,
                  onTap: () {
                    setState(() {
                      _selectedDebt = debt;
                    });
                  },
                );
              },
            );
          },
        ),
      ],
    );

    if (!isDesktop) {
      return leftList;
    }

    // ── Desktop Master-Detail Layout ──
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: leftList,
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 420,
          child: effectiveSelectedDebt != null
              ? CustomerDebtDetailPanel(
                  debt: effectiveSelectedDebt,
                  onClose: () => setState(() => _selectedDebt = null),
                  onPayDebt: () => _openPayDialog(effectiveSelectedDebt),
                  onSendReminder: () => _sendReminder(effectiveSelectedDebt),
                )
              : const CustomerDebtEmptyDetailPanel(),
        ),
      ],
    );
  }

  Widget _statusChip(String label, DebtStatus? status, bool isSelected) {
    return FilterChip(
      selected: isSelected,
      onSelected: (_) {
        ref.read(debtFilterStatusProvider.notifier).state = status;
      },
      label: Text(label),
      labelStyle: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFD1FAE5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildDebtCard(
    CustomerDebt debt, {
    bool isSelected = false,
    bool isDesktop = false,
    VoidCallback? onTap,
  }) {
    final customerName = debt.customerName ?? 'Pelanggan';
    final customerPhone = debt.customerPhone ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : debt.isOverdue
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : (debt.isOverdue ? 1.5 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card: Nama & Status Badge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  customerName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Aktif',
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${debt.invoiceNumber ?? "-"} • ${_dateFormat.format(debt.createdAt)}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildBadge(debt),
                  ],
                ),
                const SizedBox(height: 14),

                // Total & Sisa Tagihan
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BELANJA',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currency.format(debt.totalAmount),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'SISA PIUTANG',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currency.format(debt.remainingAmount),
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: debt.isPaid
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (debt.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: debt.isOverdue
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Jatuh tempo: ${_dateFormat.format(debt.dueDate!)}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight:
                              debt.isOverdue ? FontWeight.w700 : FontWeight.w500,
                          color: debt.isOverdue
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],

                if (debt.notes != null && debt.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Catatan: "${debt.notes!.trim()}"',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],

                // Action buttons on card (hidden on desktop if split view is available)
                if (!isDesktop) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      if (!debt.isPaid && customerPhone.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendReminder(debt),
                            icon: const Icon(Icons.chat_bubble_rounded,
                                size: 16, color: Color(0xFF059669)),
                            label: const Text('Tagih WA'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (!debt.isPaid)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openPayDialog(debt),
                            icon: const Icon(Icons.payments_rounded, size: 16),
                            label: const Text('Bayar Cicilan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPayDialog(CustomerDebt debt) {
    showDialog(
      context: context,
      builder: (_) => PayDebtDialog(debt: debt),
    );
  }

  Widget _buildBadge(CustomerDebt debt) {
    if (debt.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Lunas',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF16A34A),
          ),
        ),
      );
    }

    if (debt.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Lewat Tempo (${debt.overdueDays}h)',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFDC2626),
          ),
        ),
      );
    }

    if (debt.isDueToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Jatuh Tempo Hari Ini',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFD97706),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        debt.status == DebtStatus.partiallyPaid ? 'Dicicil Sebagian' : 'Belum Bayar',
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0284C7),
        ),
      ),
    );
  }

  Future<void> _sendReminder(CustomerDebt debt) async {
    final bootstrap = ref.read(homeBootstrapProvider).value;
    final businessName = bootstrap?.business?.name ?? 'Toko';

    final repo = ref.read(customerDebtRepositoryProvider);
    final ok = await repo.sendWhatsAppReminder(
      debt: debt,
      businessName: businessName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Membuka WhatsApp... Pesan pengingat telah disalin ke clipboard.'
                : 'Pesan pengingat telah disalin ke clipboard.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // ── TAB 2: KONTAK PELANGGAN ───────────────────────────────────────────────
  Widget _buildCustomersTab({
    required bool isDesktop,
    Customer? effectiveSelectedCustomer,
  }) {
    final customersAsync = ref.watch(customersProvider);

    final leftList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        TextField(
          controller: _searchController,
          onChanged: (val) {
            ref.read(customerSearchQueryProvider.notifier).state = val;
          },
          decoration: InputDecoration(
            hintText: 'Cari nama atau nomor WhatsApp...',
            hintStyle: GoogleFonts.manrope(
                fontSize: 13, color: const Color(0xFF94A3B8)),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        customersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text('Gagal memuat pelanggan: $err')),
          ),
          data: (customers) {
            if (customers.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 40,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum Ada Pelanggan',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Klik tombol "+ Tambah Pelanggan" untuk mendaftarkan pelanggan pertama Anda.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final customer = customers[index];
                final isSelected =
                    isDesktop && effectiveSelectedCustomer?.id == customer.id;
                return _buildCustomerCard(
                  customer,
                  isSelected: isSelected,
                  isDesktop: isDesktop,
                  onTap: () {
                    setState(() {
                      _selectedCustomer = customer;
                    });
                  },
                );
              },
            );
          },
        ),
      ],
    );

    if (!isDesktop) {
      return leftList;
    }

    // ── Desktop Master-Detail Layout ──
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: leftList,
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 420,
          child: effectiveSelectedCustomer != null
              ? CustomerProfileDetailPanel(
                  customer: effectiveSelectedCustomer,
                  onClose: () => setState(() => _selectedCustomer = null),
                  onEdit: () => CustomerFormScreen.open(context,
                      initialCustomer: effectiveSelectedCustomer),
                  onDelete: () =>
                      _confirmDeleteCustomer(effectiveSelectedCustomer),
                )
              : const CustomerDebtEmptyDetailPanel(
                  title: 'Pilih Kontak Pelanggan',
                  subtitle:
                      'Pilih salah satu kontak di sebelah kiri untuk melihat rincian profil dan riwayat kasbonnya.',
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(
    Customer customer, {
    bool isSelected = false,
    bool isDesktop = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar Initial
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      const Color(0xFF10B981).withValues(alpha: 0.15),
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Detail
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customer.name,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Aktif',
                                style: GoogleFonts.manrope(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customer.phone,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (customer.address != null &&
                          customer.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          customer.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                              fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ],
                  ),
                ),

                // Sisa Hutang Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (customer.hasDebt) ...[
                      Text(
                        'SISA HUTANG',
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        _currency.format(customer.currentDebt),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tidak Ada Hutang',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    if (!isDesktop)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              CustomerFormScreen.open(context,
                                  initialCustomer: customer);
                            },
                            tooltip: 'Edit Pelanggan',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => _confirmDeleteCustomer(customer),
                            tooltip: 'Hapus Pelanggan',
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCustomer(Customer customer) async {
    if (customer.hasDebt) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 10),
              Text(
                'Tidak Dapat Dihapus',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Pelanggan "${customer.name}" masih memiliki sisa kasbon sebesar ${_currency.format(customer.currentDebt)}.\n\nMohon lunasi kasbon terlebih dahulu sebelum menghapus data pelanggan.',
            style: GoogleFonts.manrope(
                fontSize: 13, height: 1.4, color: const Color(0xFF475569)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Pelanggan?',
          style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pelanggan "${customer.name}" (${customer.phone}) dari kontak toko?',
          style: GoogleFonts.manrope(
              fontSize: 13, height: 1.4, color: const Color(0xFF475569)),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(customerDebtRepositoryProvider);
        await repo.deleteCustomer(customer.id);
        ref.invalidate(customersProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pelanggan "${customer.name}" berhasil dihapus.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }
}
