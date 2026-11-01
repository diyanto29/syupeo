import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/cash_flow/presentation/widgets/open_shift_dialog.dart';
import 'package:dpos/features/cash_flow/presentation/widgets/close_shift_dialog.dart';
import 'package:dpos/features/cash_flow/presentation/widgets/add_cash_entry_dialog.dart';
import 'package:dpos/features/cash_flow/presentation/widgets/cash_flow_detail_panel.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';

class CashFlowTabletView extends ConsumerStatefulWidget {
  final EdgeInsets padding;
  const CashFlowTabletView({super.key, this.padding = EdgeInsets.zero});

  @override
  ConsumerState<CashFlowTabletView> createState() => _CashFlowTabletViewState();
}

class _CashFlowTabletViewState extends ConsumerState<CashFlowTabletView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  CashFlowEntry? _selectedEntry;
  CashShift? _selectedShift;

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
    showDialog(context: context, builder: (_) => const OpenShiftDialog());
  }

  void _showCloseShift(CashShift shift, Map<String, double> totals) {
    showDialog(
      context: context,
      builder: (_) => CloseShiftDialog(shift: shift, totals: totals),
    );
  }

  void _showAddEntry(CashFlowType type, String? shiftId) {
    showDialog(
      context: context,
      builder: (_) => AddCashEntryDialog(initialType: type, shiftId: shiftId),
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
        setState(() {
          if (_selectedEntry?.id == item.id) {
            _selectedEntry = null;
          }
        });
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
    final totals =
        totalsAsync.value ??
        {
          'totalSalesCash': 0.0,
          'totalCashIn': 0.0,
          'totalCashOut': 0.0,
          'drawerBalance': 0.0,
        };

    final drawerBalance = totals['drawerBalance'] ?? 0;
    final salesCash = totals['totalSalesCash'] ?? 0;
    final cashOut = totals['totalCashOut'] ?? 0;
    final cashIn = totals['totalCashIn'] ?? 0;

    final width = MediaQuery.sizeOf(context).width;
    final isWideDesktop = width >= 1150;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: AppTabletHeader(
        title: const Text('Arus Kas & Shift Kasir'),
        subtitle: Text(
          'Rekonsiliasi kas laci kasir, pencatatan kas masuk & keluar',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        badge: const AppTabletBadge(label: 'Syupeo'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAddEntry(CashFlowType.cashIn, shift?.id),
            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
            label: Text(
              'Kas Masuk',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF16A34A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFBBF7D0)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAddEntry(CashFlowType.cashOut, shift?.id),
            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
            label: Text(
              'Kas Keluar',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: shift == null
                ? _showOpenShift
                : () => _showCloseShift(shift, totals),
            icon: Icon(
              shift == null
                  ? Icons.lock_open_rounded
                  : Icons.lock_clock_rounded,
              size: 16,
            ),
            label: Text(
              shift == null ? 'Buka Shift' : 'Tutup Shift',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: shift == null
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: widget.padding == EdgeInsets.zero
              ? const EdgeInsets.all(20)
              : widget.padding,
          child: isWideDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom 1: Live Cash Drawer & Shift Status (width 340)
                    SizedBox(
                      width: 340,
                      child: SingleChildScrollView(
                        child: _buildDrawerStatusColumn(
                          shift,
                          totals,
                          drawerBalance,
                          salesCash,
                          cashIn,
                          cashOut,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Kolom 2: Tab Mutasi & Riwayat Shift (Expanded)
                    Expanded(
                      child: _buildTabsContainer(
                        isWideDesktop: true,
                        entriesAsync: entriesAsync,
                        historyAsync: historyAsync,
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Kolom 3: Dedicated Detail Panel (width 390)
                    Container(
                      width: 390,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _selectedEntry != null
                          ? CashFlowEntryDetailPanel(
                              key: ValueKey(_selectedEntry!.id),
                              entry: _selectedEntry!,
                              onClose: () =>
                                  setState(() => _selectedEntry = null),
                              onDelete: () => _deleteEntry(_selectedEntry!),
                            )
                          : _selectedShift != null
                              ? CashShiftDetailPanel(
                                  key: ValueKey(_selectedShift!.id),
                                  shift: _selectedShift!,
                                  onClose: () =>
                                      setState(() => _selectedShift = null),
                                )
                              : const CashFlowEmptyDetailPanel(),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom Kiri: Live Cash Drawer & Shift Status (45%)
                    Expanded(
                      flex: 45,
                      child: SingleChildScrollView(
                        child: _buildDrawerStatusColumn(
                          shift,
                          totals,
                          drawerBalance,
                          salesCash,
                          cashIn,
                          cashOut,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Kolom Kanan: Tab Mutasi & Riwayat Shift (55%)
                    Expanded(
                      flex: 55,
                      child: _buildTabsContainer(
                        isWideDesktop: false,
                        entriesAsync: entriesAsync,
                        historyAsync: historyAsync,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDrawerStatusColumn(
    CashShift? shift,
    Map<String, double> totals,
    double drawerBalance,
    double salesCash,
    double cashIn,
    double cashOut,
  ) {
    return Column(
      children: [
        // Card Utama Saldo Kas Laci
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF98B35).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFFF98B35),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SALDO LACI BERJALAN',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            shift != null
                                ? 'Shift Sedang Aktif'
                                : 'Mode Kas Harian (Tanpa Shift)',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: shift != null
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (shift != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Kasir: ${shift.cashierName}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _currency.format(drawerBalance),
                style: GoogleFonts.manrope(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 18),

              // Grid 4 Kartu Breakdown
              Row(
                children: [
                  Expanded(
                    child: _buildTabletDrawerStat(
                      'Modal Awal',
                      _currency.format(shift?.startingCash ?? 0),
                      const Color(0xFF94A3B8),
                    ),
                  ),
                  Expanded(
                    child: _buildTabletDrawerStat(
                      'Penjualan Kas',
                      _currency.format(salesCash),
                      const Color(0xFF4ADE80),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTabletDrawerStat(
                      'Kas Masuk',
                      _currency.format(cashIn),
                      const Color(0xFF60A5FA),
                    ),
                  ),
                  Expanded(
                    child: _buildTabletDrawerStat(
                      'Kas Keluar',
                      _currency.format(cashOut),
                      const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
              if (shift != null) ...[
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _selectedShift = shift),
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
                          'Lihat Transaksi Shift Berjalan',
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
        const SizedBox(height: 16),

        // Informasi Ringkasan Operasional
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Panduan Operasional Kasir',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '1. Buka Shift di awal sesi dan masukkan modal uang receh untuk kembalian.\n'
                '2. Selalu catat kas keluar jika ada belanja bahan baku atau keperluan toko.\n'
                '3. Saat pergantian kasir atau tutup toko, lakukan Tutup Shift dan hitung uang fisik laci.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabsContainer({
    required bool isWideDesktop,
    required AsyncValue<List<CashFlowEntry>> entriesAsync,
    required AsyncValue<List<CashShift>> historyAsync,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Tab Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Mutasi Kas Hari Ini'),
                Tab(text: 'Riwayat Shift Selesai'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Mutasi
                entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 54,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada mutasi kas hari ini',
                              style: GoogleFonts.manrope(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = entries[index];
                        final isOut = item.isExpense;
                        final isSelected =
                            isWideDesktop && _selectedEntry?.id == item.id;

                        return Material(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () {
                              if (isWideDesktop) {
                                setState(() {
                                  _selectedEntry = item;
                                  _selectedShift = null;
                                });
                              } else {
                                _openDetailSheet(
                                  CashFlowEntryDetailPanel(
                                    entry: item,
                                    onClose: () => Navigator.pop(context),
                                    onDelete: () {
                                      Navigator.pop(context);
                                      _deleteEntry(item);
                                    },
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF2563EB,
                                          ).withValues(alpha: 0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? const Color(0xFFFEF2F2)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isOut
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: isOut
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.category,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2563EB,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  'Dipilih',
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
                                        if (item.notes != null &&
                                            item.notes!.isNotEmpty)
                                          Text(
                                            item.notes!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        Text(
                                          '${DateFormat('HH:mm').format(item.createdAt)} • Kasir: ${item.cashierName}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${isOut ? "-" : "+"}${_currency.format(item.amount)}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isOut
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 54,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada riwayat shift selesai',
                              style: GoogleFonts.manrope(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: shifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final s = shifts[index];
                        final isDiff = s.hasDifference;
                        final isSelected =
                            isWideDesktop && _selectedShift?.id == s.id;

                        return Material(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: () {
                              if (isWideDesktop) {
                                setState(() {
                                  _selectedShift = s;
                                  _selectedEntry = null;
                                });
                              } else {
                                _openDetailSheet(
                                  CashShiftDetailPanel(
                                    shift: s,
                                    onClose: () => Navigator.pop(context),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF2563EB,
                                          ).withValues(alpha: 0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            DateFormat(
                                              'EEEE, d MMM yyyy',
                                              'id_ID',
                                            ).format(s.openedAt),
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'Dipilih',
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDiff
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          isDiff
                                              ? 'Selisih ${_currency.format(s.differenceAmount ?? 0)}'
                                              : 'Uang Pas (Sesuai)',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDiff
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Kasir: ${s.cashierName} • Jam: ${DateFormat("HH:mm").format(s.openedAt)} - ${s.closedAt != null ? DateFormat("HH:mm").format(s.closedAt!) : "-"}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildTabletSummaryText(
                                        'Modal Awal',
                                        _currency.format(s.startingCash),
                                      ),
                                      _buildTabletSummaryText(
                                        'Penjualan Kas',
                                        _currency.format(s.totalSalesCash),
                                        color: const Color(0xFF16A34A),
                                      ),
                                      _buildTabletSummaryText(
                                        'Uang Fisik Akhir',
                                        _currency.format(s.actualCash ?? 0),
                                      ),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Gagal memuat: $e')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletDrawerStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTabletSummaryText(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
