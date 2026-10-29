import 'package:dpos/features/transaction/data/invoice_pdf_service.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/presentation/widgets/void_order_dialog.dart';
import 'package:dpos/features/transaction/presentation/widgets/sales_return_sheet.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/core/widgets/bluetooth_prompt_sheet.dart';
import 'package:dpos/core/routes/routes_path.dart';
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
/// Full-page transaction detail with reprint capability.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final featureGate = ref.watch(featureGateProvider);
    final hasKitchenFeature = featureGate.isEnabled('kitchen_kds') ||
        featureGate.isEnabled('kds');

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          // Top Header Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              isSidePanel ? 20 : 8,
              isSidePanel ? 14 : 8,
              12,
              isSidePanel ? 14 : 8,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                if (!isSidePanel)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: onClose ?? () => context.pop(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: scheme.primary,
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
                        style: (isSidePanel
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.titleLarge)
                            ?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (isSidePanel)
                        Text(
                          order.invoiceNumber,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Menu Opsi',
                  onSelected: (value) {
                    if (value == 'print') {
                      _printReceipt(context, ref);
                    } else if (value == 'kitchen') {
                      _printKitchenReceipt(context, ref);
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
                    if (hasKitchenFeature)
                      const PopupMenuItem(
                        value: 'kitchen',
                        child: Row(
                          children: [
                            Icon(
                              Icons.soup_kitchen_rounded,
                              size: 18,
                              color: Color(0xFFEA580C),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cetak Tiket Dapur',
                              style: TextStyle(
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                            Icon(Icons.assignment_return_rounded,
                                color: Color(0xFFEA580C), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Retur / Tukar Barang',
                              style: TextStyle(
                                color: Color(0xFFEA580C),
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
                            Icon(Icons.cancel_outlined,
                                color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Refund / Batalkan Semua',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (isSidePanel && onClose != null) ...[
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
          Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status + Invoice Header ───────────────
                    _StatusHeader(order: order),
                    const SizedBox(height: 20),

                    // ── Info Card ─────────────────────────────
                    _InfoCard(order: order),
                    const SizedBox(height: 16),

                    // ── Items ─────────────────────────────────
                    Text(
                      'Detail Pesanan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...order.items.map((item) => _ItemRow(item: item)),

                    // ── Discounts ─────────────────────────────
                    if (order.discounts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Diskon Order',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.discounts.map(
                        (disc) => _DiscountRow(discount: disc),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Summary ───────────────────────────────
                    _SummarySection(order: order),

                    // ── Payments ──────────────────────────────
                    if (order.payments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Pembayaran',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.payments.map((pay) => _PaymentRow(payment: pay)),
                      if (order.changeAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kembalian',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                _currency.format(order.changeAmount),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (order.payments.any((p) => p.methodType == 'debt')) ...[
                        const SizedBox(height: 14),
                        Container(
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
                                    style: GoogleFonts.manrope(
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
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: const Color(0xFFB45309),
                                  height: 1.3,
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
                                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF92400E)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Buka Buku Kasbon',
                                        style: GoogleFonts.manrope(
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
                        ),
                      ],
                    ],

                    // ── Status History (Audit Trail) ──────────
                    _StatusHistorySection(orderId: order.id),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Buttons ────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF002147).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
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
                            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                            label: const Text('Buka di Kasir'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (order.status == TransactionStatus.paid ||
                      order.status == TransactionStatus.partialPaid) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showSalesReturnDialog(context, ref),
                      icon: const Icon(Icons.assignment_return_rounded,
                          size: 18, color: Color(0xFFEA580C)),
                      label: const Text(
                        'Retur / Tukar Barang',
                        style: TextStyle(
                          color: Color(0xFFEA580C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: const BorderSide(
                            color: Color(0xFFFFEDD5), width: 1.5),
                        backgroundColor: const Color(0xFFFFF7ED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (hasKitchenFeature) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _printReceipt(context, ref),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('Cetak Struk'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _printKitchenReceipt(context, ref),
                            icon: const Icon(
                              Icons.soup_kitchen_rounded,
                              size: 18,
                              color: Color(0xFFEA580C),
                            ),
                            label: const Text(
                              'Tiket Dapur',
                              style: TextStyle(
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(
                                color: Color(0xFFFED7AA),
                                width: 1.5,
                              ),
                              backgroundColor: const Color(0xFFFFF7ED),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _shareInvoice(context, ref),
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: const Text('Kirim / Bagikan Invoice'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _printReceipt(context, ref),
                            icon: const Icon(Icons.print_rounded, size: 20),
                            label: const Text('Cetak Struk'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _shareInvoice(context, ref),
                            icon: const Icon(Icons.share_rounded, size: 20),
                            label: const Text('Kirim Invoice'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
    if (!isSidePanel && ref.read(cartProvider).orderId == null && context.canPop()) {
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
            context.pop(); // Close detail screen so history refreshes
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
            context.pop(); // Close detail screen
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

  Future<void> _printKitchenReceipt(BuildContext context, WidgetRef ref) async {
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
        content: const Text('Mencetak tiket dapur...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final success =
        await ref.read(receiptServiceProvider).printKitchenReceipt(order);
    if (!context.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Tiket dapur berhasil dicetak'
              : '✗ Gagal mencetak tiket dapur. Periksa printer.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _shareInvoice(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    // Show loading snackbar
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
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Sub-Widgets ──────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final statusColor = _statusColor(order.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.1),
            statusColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              order.status == TransactionStatus.confirmed
                  ? 'Menunggu Pembayaran (Belum Lunas)'
                  : order.status.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            order.invoiceNumber,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(order.grandTotal),
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.paid => Colors.green.shade700,
      TransactionStatus.draft => Colors.amber.shade700,
      TransactionStatus.confirmed => Colors.blue.shade700,
      TransactionStatus.partialPaid => Colors.orange.shade700,
      TransactionStatus.void_ => Colors.red.shade700,
      TransactionStatus.refunded => Colors.purple.shade700,
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow(
            theme,
            'Tanggal',
            order.createdAt != null
                ? _dateFormat.format(order.createdAt!)
                : '-',
          ),
          if (order.paidAt != null)
            _infoRow(theme, 'Dibayar', _dateFormat.format(order.paidAt!)),
          _infoRow(theme, 'Sumber', order.orderSource.label),
          _infoRow(
            theme,
            'Status Dapur',
            order.kitchenStatus == KitchenStatus.served
                ? 'Disajikan 🛎️'
                : (order.kitchenStatus == KitchenStatus.ready
                    ? 'Siap Saji 🍽️'
                    : (order.kitchenStatus == KitchenStatus.cooking
                        ? 'Sedang Dimasak 🍳'
                        : 'Menunggu Masak ⏳')),
          ),
          if (order.cashierName != null && order.cashierName!.isNotEmpty)
            _infoRow(theme, 'Kasir', order.cashierName!),
          if (order.waiterName != null && order.waiterName!.isNotEmpty)
            _infoRow(theme, 'Waiter', order.waiterName!),
          if (order.customerName != null && order.customerName!.isNotEmpty)
            _infoRow(theme, 'Pelanggan', order.customerName!),
          if (order.tableNumber != null)
            _infoRow(theme, 'Meja', order.tableNumber.toString()),
          if (order.voidReason != null && order.voidReason!.isNotEmpty)
            _infoRow(theme, 'Alasan Batal', order.voidReason!, isError: true),
          if (order.notes != null && order.notes!.isNotEmpty)
            _infoRow(theme, 'Catatan', order.notes!),
        ],
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme,
    String label,
    String value, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError ? Colors.red : theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isError ? Colors.red : null,
              ),
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _currency.format(item.rawSubtotal),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${item.quantity} × ${_currency.format(item.unitPrice)}',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
          if (item.hasDiscount) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  size: 14,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.discountName} (-${_currency.format(item.discountApplied)})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _currency.format(item.subtotal),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📝 ${item.notes}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscountRow extends StatelessWidget {
  const _DiscountRow({required this.discount});
  final TransactionDiscount discount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_rounded,
            size: 16,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(discount.name, style: theme.textTheme.bodySmall),
          ),
          Text(
            '-${_currency.format(discount.appliedAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.order});
  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _row(theme, 'Subtotal', order.subtotal),
          if (order.discountTotal > 0)
            _row(theme, 'Total Diskon', -order.discountTotal, isDiscount: true),
          if (order.taxAmount > 0) _row(theme, 'Pajak', order.taxAmount),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _currency.format(order.grandTotal),
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    ThemeData theme,
    String label,
    double value, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            isDiscount
                ? '-${_currency.format(value.abs())}'
                : _currency.format(value),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green.shade700 : null,
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
    final theme = Theme.of(context);
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
                      payment.methodName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (payment.methodType == 'debt') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Piutang',
                          style: GoogleFonts.manrope(
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
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _currency.format(payment.amount),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    final logsAsync = ref.watch(statusLogsProvider(orderId));

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Text(
              'Riwayat Status (Audit)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...logs.map((log) => _StatusLogTile(log: log)),
          ],
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
    final theme = Theme.of(context);
    final createdAt = DateTime.tryParse(log['created_at'] ?? '')?.toLocal();
    final toStatusStr = log['to_status'] as String? ?? '';
    final reason = log['reason'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _statusColor(toStatusStr).withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _statusColor(toStatusStr),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 20,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${toStatusStr.toUpperCase()}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _statusColor(toStatusStr),
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('HH:mm, dd MMM').format(createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                if (reason != null && reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Alasan: $reason',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
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
      'paid' => Colors.green.shade700,
      'draft' => Colors.amber.shade700,
      'confirmed' => Colors.blue.shade700,
      'void' => Colors.red.shade700,
      'refunded' => Colors.purple.shade700,
      _ => Colors.grey,
    };
  }
}

final statusLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) {
      return ref.read(transactionRepositoryProvider).getOrderStatusLogs(id);
    });
