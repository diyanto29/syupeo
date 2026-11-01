import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/core/widgets/bluetooth_prompt_sheet.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/transaction/data/invoice_pdf_service.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/presentation/widgets/sales_return_sheet.dart';
import 'package:dpos/features/transaction/presentation/widgets/void_order_dialog.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');

/// Full-page transaction detail with reprint capability.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Canvas background slate-50
      body: SafeArea(
        child: TransactionDetailView(
          order: order,
          isSidePanel: false,
          onClose: () => context.pop(),
        ),
      ),
    );
  }
}

/// Reusable Transaction Detail component (used in full-screen and desktop side panel).
class TransactionDetailView extends ConsumerWidget {
  const TransactionDetailView({
    super.key,
    required this.order,
    this.isSidePanel = false,
    this.onClose,
    this.onOrderUpdated,
  });

  final TransactionOrder order;
  final bool isSidePanel;
  final VoidCallback? onClose;
  final VoidCallback? onOrderUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // ── Top Header Bar ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              isSidePanel ? 20 : 8,
              isSidePanel ? 14 : 8,
              12,
              isSidePanel ? 14 : 8,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                if (!isSidePanel)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                    ),
                    onPressed: onClose ?? () => context.pop(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0070FC).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF0070FC),
                      size: 20,
                    ),
                  ),
                SizedBox(width: isSidePanel ? 12 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail Transaksi',
                        style: GoogleFonts.inter(
                          fontSize: isSidePanel ? 16 : 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        order.invoiceNumber,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF475569),
                  ),
                  tooltip: 'Menu Opsi',
                  onSelected: (value) {
                    if (value == 'print') {
                      _printReceipt(context, ref);
                    } else if (value == 'invoice') {
                      _shareInvoice(context, ref);
                    } else if (value == 'return') {
                      _showSalesReturnDialog(context, ref);
                    } else if (value == 'cancel') {
                      _showCancelDialog(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Cetak Struk'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'invoice',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Kirim Invoice'),
                        ],
                      ),
                    ),
                    if (order.status == TransactionStatus.paid ||
                        order.status == TransactionStatus.partialPaid)
                      const PopupMenuItem(
                        value: 'return',
                        child: Row(
                          children: [
                            Icon(
                              Icons.assignment_return_rounded,
                              color: Color(0xFF0070FC),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Retur / Tukar Barang',
                              style: TextStyle(
                                color: Color(0xFF0070FC),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (order.status != TransactionStatus.void_ &&
                        order.status != TransactionStatus.refunded)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              color: Color(0xFFEF4444),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Refund / Batalkan Semua',
                              style: TextStyle(color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (isSidePanel && onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: 'Tutup Detail',
                    onPressed: onClose,
                  ),
                ],
              ],
            ),
          ),

          // ── Scrollable Content ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status & Hero Total Header
                  _StatusHeader(order: order),
                  const SizedBox(height: 14),

                  // 2. Info Grid Card
                  _InfoCard(order: order),
                  const SizedBox(height: 14),

                  // 3. Order Items Card
                  _ItemsCard(order: order),
                  const SizedBox(height: 14),

                  // 4. Summary & Payments Card
                  _SummaryCard(order: order),

                  // 5. Debt Notice (if applicable)
                  if (order.payments.any((p) => p.methodType == 'debt')) ...[
                    const SizedBox(height: 14),
                    _DebtNoticeCard(
                      isSidePanel: isSidePanel,
                      onClose: onClose,
                    ),
                  ],

                  // 6. Audit Trail History
                  _StatusHistorySection(orderId: order.id),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bottom Action Buttons ───────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF002147).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order.status == TransactionStatus.confirmed ||
                    order.status == TransactionStatus.draft) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openInPos(context, ref),
                          icon: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 18,
                          ),
                          label: const Text('Buka di Kasir'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => _payNow(context, ref),
                          icon: const Icon(Icons.payments_rounded, size: 20),
                          label: Text(
                            'Bayar (${_currency.format(order.grandTotal)})',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Paid / completed orders
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _printReceipt(context, ref),
                          icon: const Icon(Icons.print_rounded, size: 20),
                          label: Text(
                            'Cetak Struk',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0070FC),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareInvoice(context, ref),
                          icon: const Icon(Icons.share_rounded, size: 19),
                          label: Text(
                            'Kirim Invoice',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.status == TransactionStatus.paid ||
                      order.status == TransactionStatus.partialPaid) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _showSalesReturnDialog(context, ref),
                      icon: const Icon(
                        Icons.assignment_return_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      label: Text(
                        'Retur / Tukar Barang',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInPos(BuildContext context, WidgetRef ref) {
    ref.read(cartProvider.notifier).loadOrder(order);
    if (!isSidePanel && context.canPop()) {
      context.pop();
    }
    OwnerDashboardNavigation.selectMenu(
      ref,
      OwnerMenu.transaction,
      bootstrap: ref.read(homeBootstrapProvider).value,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pesanan ${order.invoiceNumber} dimuat ke Kasir'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _payNow(BuildContext context, WidgetRef ref) async {
    ref.read(cartProvider.notifier).loadOrder(order);
    await context.push(RoutesPath.transactionPayment);
    if (!context.mounted) return;
    onOrderUpdated?.call();
    if (!isSidePanel &&
        ref.read(cartProvider).orderId == null &&
        context.canPop()) {
      context.pop();
    }
  }

  void _showSalesReturnDialog(BuildContext context, WidgetRef ref) {
    SalesReturnSheet.show(
      context,
      order: order,
      onReturnSuccess: () {
        if (context.mounted) {
          if (onOrderUpdated != null) {
            onOrderUpdated!();
          } else {
            context.pop();
          }
        }
      },
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showVoidOrderDialog(
      context,
      order,
      onSuccess: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Pesanan berhasil dibatalkan'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (onOrderUpdated != null) {
            onOrderUpdated!();
          } else {
            context.pop();
          }
        }
      },
    );
  }

  Future<void> _printReceipt(BuildContext context, WidgetRef ref) async {
    final printerService = ref.read(thermalPrinterServiceProvider);
    final isBtEnabled = await printerService.bluetoothEnabled;
    if (!isBtEnabled && context.mounted) {
      final action = await BluetoothPromptSheet.show(
        context,
        type: BluetoothPromptType.enableBluetooth,
      );
      if (action == BluetoothPromptAction.primaryAction) {
        await printerService.requestEnableBluetooth();
        await Future.delayed(const Duration(seconds: 1));
      } else if (action == BluetoothPromptAction.openSettings) {
        await printerService.openBluetoothSettings();
        return;
      } else {
        return;
      }
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Mencetak struk...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final success = await ref.read(receiptServiceProvider).printReceipt(order);
    if (!context.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Struk berhasil dicetak'
              : '✗ Gagal mencetak. Periksa printer.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _shareInvoice(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Menyiapkan PDF Invoice...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    try {
      final pdfBytes = await ref
          .read(invoicePdfServiceProvider)
          .generateInvoicePdf(order);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Invoice_${order.invoiceNumber}.pdf',
      );

      messenger.clearSnackBars();
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('✗ Gagal membagikan invoice: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Sub-Widgets (Styled After Admin Web & Syupeo Design System) ──────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeText, badgeBorder, badgeLabel, badgeIcon) =
        _getStatusBadgeStyle(order.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Badge Status + Invoice Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeText),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  order.invoiceNumber,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Tagihan
          Text(
            'TOTAL TRANSAKSI',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currency.format(order.grandTotal),
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Divider
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),

          // Footer meta info
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order.createdAt != null
                      ? _dateFormat.format(order.createdAt!)
                      : '-',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                order.cashierName?.isNotEmpty == true
                    ? order.cashierName!
                    : 'Kasir',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (Color, Color, Color, String, IconData) _getStatusBadgeStyle(
      TransactionStatus status) {
    return switch (status) {
      TransactionStatus.paid => (
          const Color(0xFFECFDF5),
          const Color(0xFF047857),
          const Color(0xFFA7F3D0),
          'Lunas',
          Icons.check_circle_rounded,
        ),
      TransactionStatus.confirmed => (
          const Color(0xFFEFF6FF),
          const Color(0xFF1D4ED8),
          const Color(0xFFBFDBFE),
          'Pesanan Masuk',
          Icons.schedule_rounded,
        ),
      TransactionStatus.draft => (
          const Color(0xFFFFFBEB),
          const Color(0xFFB45309),
          const Color(0xFFFDE68A),
          'Draft Kasir',
          Icons.edit_note_rounded,
        ),
      TransactionStatus.partialPaid => (
          const Color(0xFFFFF7ED),
          const Color(0xFFC2410C),
          const Color(0xFFFED7AA),
          'Sebagian',
          Icons.hourglass_bottom_rounded,
        ),
      TransactionStatus.void_ => (
          const Color(0xFFFFF1F2),
          const Color(0xFFBE123C),
          const Color(0xFFFECDD3),
          'Dibatalkan',
          Icons.cancel_outlined,
        ),
      TransactionStatus.refunded => (
          const Color(0xFFFAF5FF),
          const Color(0xFF6B21A8),
          const Color(0xFFE9D5FF),
          'Direfund',
          Icons.replay_rounded,
        ),
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order});
  final TransactionOrder order;

  String _getPaymentMethodDisplay() {
    if (order.payments.isNotEmpty) {
      return order.payments
          .map((p) => p.methodName.isNotEmpty ? p.methodName : p.methodType)
          .join(', ');
    }
    return 'Tunai (Cash)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: Color(0xFF0070FC),
              ),
              const SizedBox(width: 8),
              Text(
                'INFORMASI TRANSAKSI',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2-Column Grid Data
          Row(
            children: [
              Expanded(
                child: _metaBlock(
                  'Waktu Transaksi',
                  order.createdAt != null
                      ? _dateFormat.format(order.createdAt!)
                      : '-',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metaBlock(
                  'Pelanggan / Meja',
                  order.customerName?.isNotEmpty == true
                      ? order.customerName!
                      : (order.tableNumber != null
                          ? 'Meja ${order.tableNumber}'
                          : 'Pelanggan Umum'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _metaBlock(
                  'Metode Bayar',
                  _getPaymentMethodDisplay(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metaBlock(
                  'Kasir',
                  order.cashierName?.isNotEmpty == true
                      ? order.cashierName!
                      : 'Kasir Utama',
                ),
              ),
            ],
          ),

          if (order.paidAt != null && order.paidAt != order.createdAt) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metaBlock(
                    'Waktu Pembayaran',
                    _dateFormat.format(order.paidAt!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metaBlock(
                    'Sumber Order',
                    order.orderSource.label,
                  ),
                ),
              ],
            ),
          ],

          if (order.voidReason != null && order.voidReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _metaBlock(
              'Alasan Batal',
              order.voidReason!,
              isError: true,
            ),
          ],

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _metaBlock(
              'Catatan Order',
              order.notes!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaBlock(String label, String value, {bool isError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isError ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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
                    Icons.shopping_bag_outlined,
                    size: 15,
                    color: Color(0xFF0070FC),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DETAIL PESANAN',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${order.items.length} Item',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items List with Divider
          ...order.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (idx > 0)
                  const Divider(color: Color(0xFFF1F5F9), height: 16),
                _ItemRow(item: item),
              ],
            );
          }),

          if (order.discounts.isNotEmpty) ...[
            const Divider(color: Color(0xFFE2E8F0), height: 24),
            Text(
              'DISKON PESANAN',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            ...order.discounts.map((disc) => _DiscountRow(discount: disc)),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    '${item.quantity} × ${_currency.format(item.unitPrice)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (item.hasDiscount)
                    Text(
                      '(-${_currency.format(item.discountApplied)})',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF059669),
                      ),
                    ),
                ],
              ),
              if (item.notes != null && item.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Catatan: ${item.notes}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _currency.format(item.subtotal),
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _DiscountRow extends StatelessWidget {
  const _DiscountRow({required this.discount});
  final TransactionDiscount discount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_rounded,
            size: 14,
            color: Color(0xFF059669),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              discount.name,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          Text(
            '-${_currency.format(discount.appliedAmount)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_outlined,
                size: 15,
                color: Color(0xFF0070FC),
              ),
              const SizedBox(width: 8),
              Text(
                'RINGKASAN PEMBAYARAN',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _summaryRow('Subtotal', _currency.format(order.subtotal)),
          if (order.discountTotal > 0)
            _summaryRow(
              'Diskon',
              '-${_currency.format(order.discountTotal)}',
              isDiscount: true,
            ),
          if (order.taxAmount > 0)
            _summaryRow('Pajak (PB1)', _currency.format(order.taxAmount)),

          const Divider(color: Color(0xFFE2E8F0), height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Tagihan',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                _currency.format(order.grandTotal),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0070FC),
                ),
              ),
            ],
          ),

          if (order.paidAmount > 0 ||
              order.changeAmount > 0 ||
              order.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  if (order.payments.isNotEmpty) ...[
                    ...order.payments.map((p) => _PaymentRow(payment: p)),
                  ],
                  if (order.changeAmount > 0) ...[
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kembalian',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF047857),
                          ),
                        ),
                        Text(
                          _currency.format(order.changeAmount),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount
                  ? const Color(0xFF059669)
                  : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final TransactionPayment payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      payment.methodName.isNotEmpty
                          ? payment.methodName
                          : payment.methodType,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    if (payment.methodType == 'debt') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Piutang',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (payment.referenceNumber != null &&
                    payment.referenceNumber!.isNotEmpty)
                  Text(
                    'Ref: ${payment.referenceNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _currency.format(payment.amount),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtNoticeCard extends ConsumerWidget {
  const _DebtNoticeCard({
    required this.isSidePanel,
    this.onClose,
  });

  final bool isSidePanel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Transaksi Kasbon / Tempo',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan ini dicatat sebagai piutang pelanggan di Buku Kasbon. Jika pelanggan sudah melunasi, silakan catat pelunasan melalui menu Buku Kasbon.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFFB45309),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              if (isSidePanel) {
                onClose?.call();
                OwnerDashboardNavigation.selectMenu(
                  ref,
                  OwnerMenu.customerDebt,
                  bootstrap: ref.read(homeBootstrapProvider).value,
                );
              } else {
                if (context.canPop()) {
                  context.pop();
                }
                OwnerDashboardNavigation.selectMenu(
                  ref,
                  OwnerMenu.customerDebt,
                  bootstrap: ref.read(homeBootstrapProvider).value,
                );
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Color(0xFF92400E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Buka Buku Kasbon',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHistorySection extends ConsumerWidget {
  const _StatusHistorySection({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(statusLogsProvider(orderId));

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: Color(0xFF0070FC),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RIWAYAT STATUS (AUDIT TRAIL)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...logs.map((log) => _StatusLogTile(log: log)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatusLogTile extends StatelessWidget {
  const _StatusLogTile({required this.log});
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(log['created_at'] ?? '')?.toLocal();
    final toStatusStr = log['to_status'] as String? ?? '';
    final reason = log['reason'] as String?;
    final color = _statusColor(toStatusStr);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      toStatusStr.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('HH:mm, dd MMM').format(createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
                if (reason != null && reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Alasan: $reason',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'paid' => const Color(0xFF047857),
      'draft' => const Color(0xFFB45309),
      'confirmed' => const Color(0xFF1D4ED8),
      'void' => const Color(0xFFDC2626),
      'refunded' => const Color(0xFF7C3AED),
      _ => const Color(0xFF64748B),
    };
  }
}

final statusLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) {
  return ref.read(transactionRepositoryProvider).getOrderStatusLogs(id);
});
