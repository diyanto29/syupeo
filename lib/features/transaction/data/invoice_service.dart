import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  return InvoiceService(ref);
});

/// Service to generate invoice text (for sharing via WhatsApp, etc.).
class InvoiceService {
  const InvoiceService(this._ref);

  final Ref _ref;

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');

  /// Generate a shareable invoice text.
  String generateInvoiceText(TransactionOrder order) {
    final bootstrap = _ref.read(homeBootstrapProvider).value;
    final businessName = bootstrap?.business?.name ?? 'D-POS';
    final outletName = bootstrap?.currentOutlet?.name ?? '';

    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════');
    buffer.writeln('  $businessName');
    if (outletName.isNotEmpty) {
      buffer.writeln('  $outletName');
    }
    buffer.writeln('═══════════════════════');
    buffer.writeln();
    buffer.writeln('No. Invoice: ${order.invoiceNumber}');

    if (order.createdAt != null) {
      buffer.writeln('Tanggal: ${_dateFormat.format(order.createdAt!)}');
    }

    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buffer.writeln('Pelanggan: ${order.customerName}');
    }

    if (order.tableNumber != null) {
      buffer.writeln('Meja: ${order.tableNumber}');
    }

    if (order.cashierName != null && order.cashierName!.isNotEmpty) {
      buffer.writeln('Kasir: ${order.cashierName}');
    }

    if (order.waiterName != null && order.waiterName!.isNotEmpty) {
      buffer.writeln('Waiter: ${order.waiterName}');
    }

    buffer.writeln();
    buffer.writeln('───────────────────────');
    buffer.writeln('DETAIL PESANAN');
    buffer.writeln('───────────────────────');

    for (final item in order.items) {
      buffer.writeln(item.displayName);
      buffer.writeln('  ${item.quantity} x ${_currencyFormat.format(item.unitPrice)} = ${_currencyFormat.format(item.rawSubtotal)}');
      if (item.hasDiscount) {
        buffer.writeln('  Diskon: ${item.discountName} (-${_currencyFormat.format(item.discountApplied)})');
        buffer.writeln('  Setelah diskon: ${_currencyFormat.format(item.subtotal)}');
      }
      if (item.notes != null && item.notes!.isNotEmpty) {
        buffer.writeln('  Catatan: ${item.notes}');
      }
    }

    buffer.writeln();
    buffer.writeln('───────────────────────');
    buffer.writeln('Subtotal: ${_currencyFormat.format(order.subtotal)}');

    for (final disc in order.discounts) {
      buffer.writeln('Diskon (${disc.name}): -${_currencyFormat.format(disc.appliedAmount)}');
    }

    buffer.writeln();
    buffer.writeln('*TOTAL: ${_currencyFormat.format(order.grandTotal)}*');

    if (order.payments.isNotEmpty) {
      buffer.writeln();
      for (final pay in order.payments) {
        buffer.writeln('Bayar (${pay.methodName}): ${_currencyFormat.format(pay.amount)}');
      }
      if (order.changeAmount > 0) {
        buffer.writeln('Kembalian: ${_currencyFormat.format(order.changeAmount)}');
      }
      buffer.writeln();
      final isDebt = order.payments.any((p) => p.methodType == 'debt');
      if (isDebt) {
        buffer.writeln('Status: ⏳ KASBON / TEMPO (PIUTANG BELUM LUNAS)');
      } else {
        buffer.writeln('Status: ✅ LUNAS');
      }
    } else {
      buffer.writeln();
      buffer.writeln('Status: ⏳ BELUM LUNAS');
    }

    buffer.writeln();
    buffer.writeln('═══════════════════════');
    buffer.writeln('  Terima kasih 🙏');
    buffer.writeln('═══════════════════════');

    return buffer.toString();
  }
}
