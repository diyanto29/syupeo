import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/cash_flow/presentation/views/open_shift_screen.dart';
import 'package:dpos/features/cash_flow/presentation/views/close_shift_screen.dart';
import 'package:dpos/features/cash_flow/presentation/views/add_cash_entry_screen.dart';
import 'package:dpos/features/cash_flow/presentation/widgets/cash_flow_detail_panel.dart';

class CashFlowMobileView extends ConsumerStatefulWidget {
  final EdgeInsets padding;
  const CashFlowMobileView({super.key, this.padding = EdgeInsets.zero});

  @override
  ConsumerState<CashFlowMobileView> createState() => _CashFlowMobileViewState();
}

class _CashFlowMobileViewState extends ConsumerState<CashFlowMobileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showOpenShift() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OpenShiftScreen(),
      ),
    );
  }

  void _showCloseShift(CashShift shift, Map<String, double> totals) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CloseShiftScreen(shift: shift, totals: totals),
      ),
    );
  }

  void _showAddEntry(CashFlowType type, String? shiftId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCashEntryScreen(initialType: type, shiftId: shiftId),
      ),
    );
  }

  void _openDetailSheet(Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Future<void> _deleteEntry(CashFlowEntry item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan Kas'),
        content: Text(
          'Catatan ${item.type == CashFlowType.cashIn ? "kas masuk" : "kas keluar"} sebesar ${_currency.format(item.amount)} (${item.category}) akan dihapus permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(cashFlowRepositoryProvider).deleteCashEntry(item.id);
      ref.invalidate(todayCashEntriesProvider);
      ref.invalidate(shiftLiveTotalsProvider);
      ref.invalidate(activeShiftProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan mutasi kas berhasil dihapus.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus catatan kas: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeShiftAsync = ref.watch(activeShiftProvider);
    final totalsAsync = ref.watch(shiftLiveTotalsProvider);
    final entriesAsync = ref.watch(todayCashEntriesProvider);
    final historyAsync = ref.watch(shiftHistoryProvider);

    final shift = activeShiftAsync.value;
    final totals = totalsAsync.value ?? {
      'totalSalesCash': 0.0,
      'totalCashIn': 0.0,
      'totalCashOut': 0.0,
      'drawerBalance': 0.0,
    };

    final drawerBalance = totals['drawerBalance'] ?? 0;
    final salesCash = totals['totalSalesCash'] ?? 0;
    final cashOut = totals['totalCashOut'] ?? 0;
    final cashIn = totals['totalCashIn'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arus Kas & Shift Kasir',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Pantau uang laci, penjualan & pengeluaran toko',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          // Shift status chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: shift != null
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: shift != null
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: shift != null
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  shift != null ? 'Shift Aktif' : 'Kas Harian',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: shift != null
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Card Saldo Laci Kasir Utama
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Color(0xFFF98B35),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'SALDO LACI KASIR BERJALAN',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white.withValues(alpha: 0.7),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                if (shift != null)
                                  Text(
                                    shift.cashierName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF98B35),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currency.format(drawerBalance),
                              style: GoogleFonts.manrope(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 12),

                            // Grid ringkasan 3 rincian
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniStat(
                                  'Modal Awal',
                                  _currency.format(shift?.startingCash ?? 0),
                                  const Color(0xFF94A3B8),
                                ),
                                _buildMiniStat(
                                  'Penjualan',
                                  _currency.format(salesCash),
                                  const Color(0xFF4ADE80),
                                ),
                                _buildMiniStat(
                                  'Masuk',
                                  _currency.format(cashIn),
                                  const Color(0xFF60A5FA),
                                ),
                                _buildMiniStat(
                                  'Keluar',
                                  _currency.format(cashOut),
                                  const Color(0xFFF87171),
                                ),
                              ],
                            ),
                            if (shift != null) ...[
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white12, height: 1),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _openDetailSheet(
                                  CashShiftDetailPanel(
                                    shift: shift,
                                    onClose: () => Navigator.pop(context),
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 14,
                                        color: Color(0xFF60A5FA),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Lihat Rincian & Transaksi Shift Berjalan',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF60A5FA),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 13,
                                        color: Color(0xFF60A5FA),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddEntry(CashFlowType.cashOut, shift?.id),
                              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                              label: Text(
                                'Kas Keluar',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEF2F2),
                                foregroundColor: const Color(0xFFDC2626),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFFECACA)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddEntry(CashFlowType.cashIn, shift?.id),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                              label: Text(
                                'Kas Masuk',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF0FDF4),
                                foregroundColor: const Color(0xFF16A34A),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: shift == null
                                  ? _showOpenShift
                                  : () => _showCloseShift(shift, totals),
                              icon: Icon(
                                shift == null ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
                                size: 16,
                              ),
                              label: Text(
                                shift == null ? 'Buka Shift' : 'Tutup Shift',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: shift == null
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tabs Navigation
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF0F172A),
                        unselectedLabelColor: const Color(0xFF64748B),
                        indicatorColor: const Color(0xFF2563EB),
                        indicatorWeight: 3,
                        labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
                        unselectedLabelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
                        tabs: const [
                          Tab(text: 'Mutasi Hari Ini'),
                          Tab(text: 'Riwayat Shift'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Mutasi Kas Hari Ini
              entriesAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada mutasi kas hari ini',
                            style: GoogleFonts.manrope(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      final isOut = item.isExpense;

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _openDetailSheet(
                            CashFlowEntryDetailPanel(
                              entry: item,
                              onClose: () => Navigator.pop(context),
                              onDelete: () {
                                Navigator.pop(context);
                                _deleteEntry(item);
                              },
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isOut ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isOut ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    color: isOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.category,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (item.notes != null && item.notes!.isNotEmpty)
                                        Text(
                                          item.notes!,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      Text(
                                        '${DateFormat('HH:mm').format(item.createdAt)} • ${item.cashierName}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isOut ? "-" : "+"}${_currency.format(item.amount)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              ),

              // Tab 2: Riwayat Shift Selesai
              historyAsync.when(
                data: (shifts) {
                  if (shifts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada riwayat shift selesai',
                            style: GoogleFonts.manrope(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: shifts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = shifts[index];
                      final isDiff = s.hasDifference;

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: () => _openDetailSheet(
                            CashShiftDetailPanel(
                              shift: s,
                              onClose: () => Navigator.pop(context),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('EEEE, d MMM yyyy', 'id_ID').format(s.openedAt),
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDiff ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isDiff
                                            ? 'Selisih ${_currency.format(s.differenceAmount ?? 0)}'
                                            : 'Kas Sesuai (Pas)',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDiff ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kasir: ${s.cashierName} • Jam: ${DateFormat("HH:mm").format(s.openedAt)} - ${s.closedAt != null ? DateFormat("HH:mm").format(s.closedAt!) : "-"}',
                                  style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMiniStat('Modal Awal', _currency.format(s.startingCash), const Color(0xFF64748B)),
                                    _buildMiniStat('Penjualan Kas', _currency.format(s.totalSalesCash), const Color(0xFF16A34A)),
                                    _buildMiniStat('Fisik Akhir', _currency.format(s.actualCash ?? 0), const Color(0xFF0F172A)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
