import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/presentation/history/transaction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _dateTimeFormatter = DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID');
final _dateOnlyFormatter = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
final _timeOnlyFormatter = DateFormat('HH:mm', 'id_ID');

/// Panel Placeholder saat belum ada mutasi atau shift yang dipilih
class CashFlowEmptyDetailPanel extends StatelessWidget {
  const CashFlowEmptyDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Rincian Arus Kas & Shift',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih salah satu mutasi kas atau riwayat shift dari daftar di samping untuk melihat voucher transaksi, bukti struk, dan rekonsiliasi kas laci.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: scheme.outline,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail Panel untuk Entri Mutasi Kas (Kas Masuk / Kas Keluar)
class CashFlowEntryDetailPanel extends StatelessWidget {
  const CashFlowEntryDetailPanel({
    super.key,
    required this.entry,
    this.onClose,
    this.onDelete,
  });

  final CashFlowEntry entry;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: const Text('Gagal memuat foto bukti struk'),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOut = entry.isExpense;
    final accentColor = isOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final bgTint = isOut ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final borderTint = isOut ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderTint),
                  ),
                  child: Icon(
                    isOut
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOut ? 'Voucher Kas Keluar' : 'Voucher Kas Masuk',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        entry.category,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: scheme.error,
                    ),
                    tooltip: 'Hapus Entri Kas',
                    onPressed: onDelete,
                  ),
                if (onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Tutup Detail',
                    onPressed: onClose,
                  ),
                ],
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Big Amount Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: bgTint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderTint),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isOut ? 'TOTAL PENGELUARAN' : 'TOTAL PEMASUKAN',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOut ? 'Kas Keluar' : 'Kas Masuk',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${isOut ? "-" : "+"}${_currencyFormatter.format(entry.amount)}',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Waktu Transaksi',
                        _dateTimeFormatter.format(entry.createdAt),
                        icon: Icons.access_time_rounded,
                      ),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        'Kasir Pencatat',
                        entry.cashierName,
                        icon: Icons.person_outline_rounded,
                      ),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        'Sumber Kas',
                        entry.paymentSource == 'cash'
                            ? 'Laci Kasir (Cash Drawer)'
                            : entry.paymentSource.toUpperCase(),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        'Kategori Mutasi',
                        entry.category,
                        icon: Icons.category_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Catatan / Keterangan
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Keterangan / Keperluan',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (entry.notes != null && entry.notes!.trim().isNotEmpty)
                            ? entry.notes!
                            : 'Tidak ada catatan tambahan yang dituliskan.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: (entry.notes != null && entry.notes!.trim().isNotEmpty)
                              ? const Color(0xFF334155)
                              : const Color(0xFF94A3B8),
                          fontStyle: (entry.notes != null && entry.notes!.trim().isNotEmpty)
                              ? FontStyle.normal
                              : FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Foto Bukti Struk / Nota Belanja
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                Icons.receipt_outlined,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bukti Foto Struk / Nota',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          if (entry.receiptUrl != null &&
                              entry.receiptUrl!.trim().isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _showFullImage(
                                context,
                                entry.receiptUrl!,
                              ),
                              icon: const Icon(Icons.fullscreen_rounded, size: 16),
                              label: const Text('Perbesar'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (entry.receiptUrl != null &&
                          entry.receiptUrl!.trim().isNotEmpty)
                        GestureDetector(
                          onTap: () => _showFullImage(context, entry.receiptUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: entry.receiptUrl!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 180,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 180,
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: Text(
                                  'Gagal memuat gambar bukti',
                                  style: GoogleFonts.manrope(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 22,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Tidak ada foto struk yang dilampirkan',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// Detail Panel untuk Riwayat Shift Kasir Selesai (Rekonsiliasi & Daftar Transaksi)
class CashShiftDetailPanel extends ConsumerStatefulWidget {
  const CashShiftDetailPanel({
    super.key,
    required this.shift,
    this.onClose,
  });

  final CashShift shift;
  final VoidCallback? onClose;

  @override
  ConsumerState<CashShiftDetailPanel> createState() =>
      _CashShiftDetailPanelState();
}

class _CashShiftDetailPanelState extends ConsumerState<CashShiftDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _paymentFilter = 'all'; // 'all', 'cash', 'non_cash'

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

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return 'Sedang Berjalan';
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}j ${minutes}m';
  }

  void _copyShiftSummary(
    BuildContext context,
    int orderCount,
    double totalRevenue, {
    double? liveSalesCash,
    double? liveCashIn,
    double? liveCashOut,
    double? liveExpectedCash,
  }) {
    final shift = widget.shift;
    final diff = shift.differenceAmount ?? 0;
    final effSalesCash = liveSalesCash ?? shift.totalSalesCash;
    final effCashIn = liveCashIn ?? shift.totalCashIn;
    final effCashOut = liveCashOut ?? shift.totalCashOut;
    final effExpectedCash = liveExpectedCash ?? (shift.expectedCash ?? shift.estimatedDrawerCash);

    final diffText = shift.isOpen
        ? 'Shift Masih Berjalan (Estimasi: ${_currencyFormatter.format(effExpectedCash)})'
        : (diff.abs() < 0.01
            ? 'Uang Pas (Sesuai)'
            : diff > 0
                ? 'Lebih Kas: +${_currencyFormatter.format(diff)}'
                : 'Kurang Kas: ${_currencyFormatter.format(diff)}');

    final text = StringBuffer()
      ..writeln('=== REKAP SHIFT KASIR ===')
      ..writeln('Kasir: ${shift.cashierName}')
      ..writeln('Tanggal: ${_dateOnlyFormatter.format(shift.openedAt)}')
      ..writeln(
        'Jam Operasional: ${_timeOnlyFormatter.format(shift.openedAt)} - ${shift.closedAt != null ? _timeOnlyFormatter.format(shift.closedAt!) : "Masih Buka"}',
      )
      ..writeln('Durasi: ${_formatDuration(shift.openedAt, shift.closedAt)}')
      ..writeln('Total Transaksi: $orderCount Order')
      ..writeln('Total Omzet Shift: ${_currencyFormatter.format(totalRevenue)}')
      ..writeln('-------------------------')
      ..writeln('Modal Awal: ${_currencyFormatter.format(shift.startingCash)}')
      ..writeln(
        'Penjualan Tunai: ${_currencyFormatter.format(effSalesCash)}',
      )
      ..writeln('Kas Masuk: ${_currencyFormatter.format(effCashIn)}')
      ..writeln('Kas Keluar: ${_currencyFormatter.format(effCashOut)}')
      ..writeln(
        'Saldo Kas Sistem: ${_currencyFormatter.format(effExpectedCash)}',
      )
      ..writeln(
        'Uang Fisik Kasir: ${shift.isOpen ? "Masih Berjalan" : _currencyFormatter.format(shift.actualCash ?? 0)}',
      )
      ..writeln('Status Selisih: $diffText');

    if (shift.notes != null && shift.notes!.trim().isNotEmpty) {
      text.writeln('Catatan Kasir: ${shift.notes}');
    }

    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan rekap shift berhasil disalin ke clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isOrderCash(TransactionOrder order) {
    if (order.payments.isEmpty) return true;
    return order.payments.any((p) {
      final name = p.methodName.toLowerCase();
      final type = p.methodType.toLowerCase();
      return name.contains('cash') ||
          name.contains('tunai') ||
          type == 'cash';
    });
  }

  Widget _buildPaymentBadge(TransactionOrder order) {
    if (order.payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.payments_rounded,
              size: 11,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(width: 4),
            Text(
              'Tunai',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      );
    }

    final badges = order.payments.map((p) {
      final name = p.methodName.trim();
      final lower = name.toLowerCase();
      final isCash = lower.contains('tunai') ||
          lower.contains('cash') ||
          p.methodType == 'cash';
      final isQris = lower.contains('qris') || p.methodType == 'qris';
      final isDebt = p.methodType == 'debt' || lower.contains('kasbon');

      final color = isCash
          ? const Color(0xFF16A34A)
          : (isQris
              ? const Color(0xFF2563EB)
              : (isDebt ? const Color(0xFFB45309) : const Color(0xFF7C3AED)));
      final bg = isCash
          ? const Color(0xFFF0FDF4)
          : (isQris
              ? const Color(0xFFEFF6FF)
              : (isDebt ? const Color(0xFFFEF3C7) : const Color(0xFFF5F3FF)));
      final border = isCash
          ? const Color(0xFFBBF7D0)
          : (isQris
              ? const Color(0xFFBFDBFE)
              : (isDebt ? const Color(0xFFFDE68A) : const Color(0xFFDDD6FE)));
      final icon = isCash
          ? Icons.payments_rounded
          : (isQris
              ? Icons.qr_code_rounded
              : (isDebt ? Icons.menu_book_rounded : Icons.credit_card_rounded));

      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              name.isEmpty ? 'Bayar' : name,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _paymentFilter == value;
    return InkWell(
      onTap: () => setState(() => _paymentFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShift = widget.shift.isOpen ? ref.watch(activeShiftProvider).valueOrNull : null;
    final shift = (activeShift != null && activeShift.id == widget.shift.id) ? activeShift : widget.shift;
    final ordersAsync = ref.watch(shiftOrdersProvider(shift));
    final orders = ordersAsync.valueOrNull ?? [];
    final liveTotalsAsync = ref.watch(shiftLiveTotalsProvider);

    final isDiff = shift.hasDifference;
    final isDeficit = shift.isDeficit;

    final diffColor = shift.isOpen
        ? const Color(0xFF2563EB)
        : (isDiff
            ? (isDeficit ? const Color(0xFFDC2626) : const Color(0xFF2563EB))
            : const Color(0xFF16A34A));

    final diffBg = shift.isOpen
        ? const Color(0xFFEFF6FF)
        : (isDiff
            ? (isDeficit ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF))
            : const Color(0xFFF0FDF4));

    final diffBorder = shift.isOpen
        ? const Color(0xFFBFDBFE)
        : (isDiff
            ? (isDeficit ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE))
            : const Color(0xFFBBF7D0));

    final validOrders =
        orders.where((o) => o.status != TransactionStatus.void_).toList();
    final totalRevenue =
        validOrders.fold<double>(0, (sum, o) => sum + o.grandTotal);

    double computedCashSales = 0;
    for (final o in validOrders) {
      if (o.status != TransactionStatus.paid && o.status != TransactionStatus.refunded) continue;
      if (o.payments.isNotEmpty) {
        for (final p in o.payments) {
          final isCash = p.methodType.toLowerCase() == 'cash' ||
              p.methodName.toLowerCase().contains('tunai') ||
              p.methodName.toLowerCase().contains('cash');
          if (isCash) {
            computedCashSales += (p.amount - o.changeAmount).clamp(0.0, double.infinity);
          }
        }
      } else {
        computedCashSales += o.grandTotal;
      }
    }

    final liveTotals = liveTotalsAsync.valueOrNull;
    final liveSalesCash = shift.isOpen
        ? (liveTotals?['totalSalesCash'] != null && (liveTotals!['totalSalesCash']! > 0 || computedCashSales == 0)
            ? liveTotals['totalSalesCash']!
            : computedCashSales)
        : shift.totalSalesCash;
    final liveCashIn = shift.isOpen
        ? (liveTotals?['totalCashIn'] ?? 0.0)
        : shift.totalCashIn;
    final liveCashOut = shift.isOpen
        ? (liveTotals?['totalCashOut'] ?? 0.0)
        : shift.totalCashOut;
    final liveExpectedCash = shift.startingCash + liveSalesCash + liveCashIn - liveCashOut;

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Rekap Sesi Shift Kasir',
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              if (shift.isOpen) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Aktif',
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Kasir: ${shift.cashierName} • ${_dateOnlyFormatter.format(shift.openedAt)}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      tooltip: 'Muat Ulang Transaksi Shift',
                      onPressed: () {
                        ref.invalidate(shiftOrdersProvider(shift));
                        ref.invalidate(shiftLiveTotalsProvider);
                        if (shift.isOpen) {
                          ref.invalidate(activeShiftProvider);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 19),
                      tooltip: 'Salin Ringkasan Shift',
                      onPressed: () => _copyShiftSummary(
                        context,
                        validOrders.length,
                        totalRevenue,
                        liveSalesCash: liveSalesCash,
                        liveCashIn: liveCashIn,
                        liveCashOut: liveCashOut,
                        liveExpectedCash: liveExpectedCash,
                      ),
                    ),
                    if (widget.onClose != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Tutup Detail',
                        onPressed: widget.onClose,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF2563EB),
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
                  tabs: [
                    const Tab(
                      iconMargin: EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Rekap Kas Laci'),
                        ],
                      ),
                    ),
                    Tab(
                      iconMargin: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            validOrders.isNotEmpty
                                ? 'Transaksi (${validOrders.length})'
                                : 'Transaksi',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: AUDIT KAS LACI
                _buildAuditKasTab(
                  shift: shift,
                  diffColor: diffColor,
                  diffBg: diffBg,
                  diffBorder: diffBorder,
                  isDiff: isDiff,
                  isDeficit: isDeficit,
                  orderCount: validOrders.length,
                  totalRevenue: totalRevenue,
                  liveSalesCash: liveSalesCash,
                  liveCashIn: liveCashIn,
                  liveCashOut: liveCashOut,
                  liveExpectedCash: liveExpectedCash,
                ),

                // TAB 2: DAFTAR TRANSAKSI
                _buildTransactionsTab(ordersAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditKasTab({
    required CashShift shift,
    required Color diffColor,
    required Color diffBg,
    required Color diffBorder,
    required bool isDiff,
    required bool isDeficit,
    required int orderCount,
    required double totalRevenue,
    required double liveSalesCash,
    required double liveCashIn,
    required double liveCashOut,
    required double liveExpectedCash,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Highlight Status Selisih Kas
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: diffBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: diffBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shift.isOpen
                        ? 'ESTIMASI SALDO KAS LACI (SHIFT AKTIF)'
                        : 'AUDIT REKONSILIASI KAS LACI',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: diffColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: shift.isOpen ? const Color(0xFF2563EB) : diffColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shift.isOpen
                          ? 'Shift Sedang Berjalan'
                          : (isDiff
                              ? (isDeficit ? 'Defisit / Kurang' : 'Surplus / Lebih')
                              : 'Uang Pas'),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                shift.isOpen
                    ? _currencyFormatter.format(liveExpectedCash)
                    : (isDiff
                        ? '${isDeficit ? "-" : "+"}${_currencyFormatter.format(shift.differenceAmount?.abs() ?? 0)}'
                        : 'Rp 0 (Sempurna)'),
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: shift.isOpen ? const Color(0xFF2563EB) : diffColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                shift.isOpen
                    ? 'Estimasi saldo fisik uang di laci saat ini berdasarkan modal awal, penjualan kas, dan mutasi kas sementara.'
                    : (isDiff
                        ? (isDeficit
                            ? 'Uang fisik di laci kasir kurang dari saldo hitungan sistem.'
                            : 'Uang fisik di laci kasir lebih banyak dari saldo hitungan sistem.')
                        : 'Uang fisik di laci kasir cocok persis dengan total transaksi sistem.'),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: (shift.isOpen ? const Color(0xFF2563EB) : diffColor).withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Banner Transaksi Shift
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$orderCount Transaksi di Shift Ini',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Total Omzet: ${_currencyFormatter.format(totalRevenue)}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _tabController.animateTo(1),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat Rincian',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info Waktu & Durasi
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildShiftRow(
                'Tanggal Operasional',
                _dateOnlyFormatter.format(shift.openedAt),
                icon: Icons.calendar_today_rounded,
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              _buildShiftRow(
                'Jam Buka Shift',
                _timeOnlyFormatter.format(shift.openedAt),
                icon: Icons.login_rounded,
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              _buildShiftRow(
                'Jam Tutup Shift',
                shift.closedAt != null
                    ? _timeOnlyFormatter.format(shift.closedAt!)
                    : 'Masih Buka',
                icon: Icons.logout_rounded,
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              _buildShiftRow(
                'Total Jam Kerja',
                _formatDuration(shift.openedAt, shift.closedAt),
                icon: Icons.timelapse_rounded,
                valueColor: const Color(0xFF2563EB),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabel Breakdown Rekonsiliasi Kas Laci
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rincian Arus Uang Kas Laci',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              _buildCashRow(
                'Modal Awal (Uang Kembalian)',
                _currencyFormatter.format(shift.startingCash),
                const Color(0xFF64748B),
              ),
              const SizedBox(height: 8),
              _buildCashRow(
                shift.isOpen ? '(+) Penjualan Kas Kasir (Sementara)' : '(+) Penjualan Kas Kasir',
                '+${_currencyFormatter.format(liveSalesCash)}',
                const Color(0xFF16A34A),
              ),
              const SizedBox(height: 8),
              _buildCashRow(
                shift.isOpen ? '(+) Kas Masuk Lainnya (Sementara)' : '(+) Kas Masuk Lainnya',
                '+${_currencyFormatter.format(liveCashIn)}',
                const Color(0xFF2563EB),
              ),
              const SizedBox(height: 8),
              _buildCashRow(
                shift.isOpen ? '(-) Kas Keluar Toko (Sementara)' : '(-) Kas Keluar Toko',
                '-${_currencyFormatter.format(liveCashOut)}',
                const Color(0xFFDC2626),
              ),
              const Divider(
                height: 24,
                thickness: 1,
                color: Color(0xFFCBD5E1),
              ),
              _buildCashRow(
                shift.isOpen ? 'Total Estimasi Saldo Laci Saat Ini' : 'Total Saldo Sistem (Seharusnya)',
                _currencyFormatter.format(liveExpectedCash),
                const Color(0xFF0F172A),
                isBold: true,
              ),
              const SizedBox(height: 10),
              _buildCashRow(
                'Uang Fisik Dihitung Kasir',
                shift.isOpen
                    ? 'Dihitung saat Tutup Shift'
                    : _currencyFormatter.format(shift.actualCash ?? 0),
                const Color(0xFF0F172A),
                isBold: true,
              ),
            ],
          ),
        ),

        if (shift.notes != null && shift.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Catatan Kasir Saat Tutup Shift',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shift.notes!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionsTab(AsyncValue<List<TransactionOrder>> ordersAsync) {
    return ordersAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 12),
            Text('Memuat transaksi shift...'),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                'Gagal memuat transaksi: $e',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(shiftOrdersProvider(widget.shift)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum Ada Transaksi di Shift Ini',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Transaksi yang diselesaikan kasir selama jam shift ini akan otomatis muncul di sini.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final validOrders =
            orders.where((o) => o.status != TransactionStatus.void_).toList();
        final totalRevenue =
            validOrders.fold<double>(0, (sum, o) => sum + o.grandTotal);
        final cashOrders = validOrders.where((o) => _isOrderCash(o)).toList();
        final nonCashOrders =
            validOrders.where((o) => !_isOrderCash(o)).toList();
        final totalCash =
            cashOrders.fold<double>(0, (sum, o) => sum + o.grandTotal);
        final totalNonCash =
            nonCashOrders.fold<double>(0, (sum, o) => sum + o.grandTotal);

        // Filter by search & payment method
        final filtered = orders.where((o) {
          if (_paymentFilter == 'cash' && !_isOrderCash(o)) return false;
          if (_paymentFilter == 'non_cash' && _isOrderCash(o)) return false;

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchInvoice = o.invoiceNumber.toLowerCase().contains(q);
            final matchCustomer =
                (o.customerName ?? '').toLowerCase().contains(q);
            final matchTable = o.tableNumber?.toString().contains(q) ?? false;
            if (!matchInvoice && !matchCustomer && !matchTable) return false;
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stat Cards Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL OMZET SHIFT',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormatter.format(totalRevenue),
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_rounded,
                              size: 14,
                              color: Color(0xFFF98B35),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${validOrders.length} Order',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tunai / Cash (${cashOrders.length})',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyFormatter.format(totalCash),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4ADE80),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Non-Tunai / QRIS (${nonCashOrders.length})',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyFormatter.format(totalNonCash),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF60A5FA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari invoice, pelanggan, meja...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua (${orders.length})', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip('💵 Tunai (${cashOrders.length})', 'cash'),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '📱 Non-Tunai (${nonCashOrders.length})',
                    'non_cash',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Orders List
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Tidak ada transaksi yang cocok dengan filter.',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((order) => _buildOrderCard(order)),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(TransactionOrder order) {
    final isVoid = order.status == TransactionStatus.void_;
    final isRefunded = order.status == TransactionStatus.refunded;
    final isPaid = order.status == TransactionStatus.paid;
    final timeStr = order.createdAt != null
        ? DateFormat('HH:mm').format(order.createdAt!)
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVoid
              ? const Color(0xFFFECACA)
              : (isRefunded
                  ? const Color(0xFFFED7AA)
                  : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(order: order),
                  ),
                )
                .then((_) {
                  ref.invalidate(shiftOrdersProvider(widget.shift));
                  ref.invalidate(shiftLiveTotalsProvider);
                  if (widget.shift.isOpen) {
                    ref.invalidate(activeShiftProvider);
                  }
                });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Invoice, Jam, Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.invoiceNumber,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• $timeStr',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isVoid
                            ? const Color(0xFFFEF2F2)
                            : (isRefunded
                                ? const Color(0xFFFFF7ED)
                                : (isPaid
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFEFF6FF))),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.label,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isVoid
                              ? const Color(0xFFDC2626)
                              : (isRefunded
                                  ? const Color(0xFFEA580C)
                                  : (isPaid
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF2563EB))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Middle row: Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildPaymentBadge(order),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.diningOption.label,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    if (order.tableNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Meja ${order.tableNumber}',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    if (order.customerName != null &&
                        order.customerName!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.customerName!,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Bottom row: Total items & Grand total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${order.totalItemCount} item pesanan',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _currencyFormatter.format(order.grandTotal),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isVoid
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF0F172A),
                            decoration:
                                isVoid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
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

  Widget _buildShiftRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCashRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
