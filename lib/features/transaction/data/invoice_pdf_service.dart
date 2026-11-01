import 'dart:typed_data';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final invoicePdfServiceProvider = Provider<InvoicePdfService>((ref) {
  return InvoicePdfService(ref);
});

class InvoicePdfService {
  const InvoicePdfService(this._ref);

  final Ref _ref;

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateTimeFmt = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

  Future<Uint8List> generateInvoicePdf(TransactionOrder order) async {
    final bootstrap = _ref.read(homeBootstrapProvider).value;
    final businessName = bootstrap?.business?.name ?? 'D-POS';
    final outletName = bootstrap?.currentOutlet?.name ?? '';
    final outletAddress = bootstrap?.currentOutlet?.address ?? '';
    final outletPhone = bootstrap?.currentOutlet?.phone ?? '';

    final settings = await PrinterSettings.load();
    final is58mm = settings.paperSize == PrinterPaperSize.mm58;

    final pdf = pw.Document(
      title: 'Invoice ${order.invoiceNumber}',
      author: businessName,
    );

    // ── Styles ──────────────────────────────────────────────
    final titleStyle = pw.TextStyle(
      fontSize: is58mm ? 13 : 16,
      fontWeight: pw.FontWeight.bold,
    );
    final bodyStyle = pw.TextStyle(fontSize: is58mm ? 8.5 : 10);
    final boldStyle = pw.TextStyle(
      fontSize: is58mm ? 8.5 : 10,
      fontWeight: pw.FontWeight.bold,
    );
    final smallStyle = pw.TextStyle(
      fontSize: is58mm ? 7.5 : 8,
      color: PdfColors.grey700,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: is58mm ? PdfPageFormat.roll57 : PdfPageFormat.roll80,
        margin: pw.EdgeInsets.symmetric(
          horizontal: is58mm ? 4 : 8,
          vertical: 6,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(businessName.toUpperCase(), style: titleStyle),
                    if (outletName.isNotEmpty)
                      pw.Text(outletName, style: bodyStyle),
                    if (outletAddress.isNotEmpty)
                      pw.Text(
                        outletAddress,
                        style: smallStyle,
                        textAlign: pw.TextAlign.center,
                      ),
                    if (outletPhone.isNotEmpty)
                      pw.Text('Telp: $outletPhone', style: smallStyle),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                  ],
                ),
              ),

              // ── Transaction Info ──────────────────────────
              pw.SizedBox(height: 5),
              _infoRow('No. Invoice', order.invoiceNumber, boldStyle, bodyStyle),
              _infoRow(
                'Tanggal',
                order.createdAt != null
                    ? _dateTimeFmt.format(order.createdAt!)
                    : '-',
                bodyStyle,
                bodyStyle,
              ),
              if (order.customerName != null)
                _infoRow(
                  'Pelanggan',
                  order.customerName!,
                  bodyStyle,
                  bodyStyle,
                ),
              if (order.tableNumber != null)
                _infoRow(
                  'Meja',
                  order.tableNumber.toString(),
                  bodyStyle,
                  bodyStyle,
                ),
              if (order.cashierName != null)
                _infoRow('Kasir', order.cashierName!, bodyStyle, bodyStyle),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 5),

              // ── Items ──────────────────────────────────────
              ...order.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(item.displayName, style: bodyStyle),
                          ),
                          pw.Text(
                            _currency.format(item.rawSubtotal),
                            style: bodyStyle,
                          ),
                        ],
                      ),
                      pw.Text(
                        '${item.quantity} x ${_currency.format(item.unitPrice)}',
                        style: smallStyle,
                      ),
                      if (item.hasDiscount)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '  Diskon: ${item.discountName}',
                              style: smallStyle.copyWith(
                                color: PdfColors.green700,
                              ),
                            ),
                            pw.Text(
                              '-${_currency.format(item.discountApplied)}',
                              style: smallStyle.copyWith(
                                color: PdfColors.green700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 5),

              // ── Totals ─────────────────────────────────────
              _summaryRow('Subtotal', order.subtotal, bodyStyle),
              if (order.discountTotal > 0)
                _summaryRow('Total Diskon', -order.discountTotal, bodyStyle,
                    isDiscount: true),
              if (order.taxAmount > 0)
                _summaryRow('Pajak', order.taxAmount, bodyStyle),
              
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: boldStyle.copyWith(fontSize: 12)),
                  pw.Text(
                    _currency.format(order.grandTotal),
                    style: boldStyle.copyWith(fontSize: 12),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 5),

              // ── Payments ───────────────────────────────────
              if (order.payments.isNotEmpty) ...[
                ...order.payments.map((pay) {
                  return _infoRow(
                    pay.methodName,
                    _currency.format(pay.amount),
                    bodyStyle,
                    bodyStyle,
                  );
                }),
                if (order.changeAmount > 0)
                  _infoRow(
                    'Kembalian',
                    _currency.format(order.changeAmount),
                    bodyStyle,
                    bodyStyle,
                  ),
                if (order.payments.any((p) => p.methodType == 'debt'))
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 8),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber100,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.amber400),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'STATUS: KASBON / TEMPO (BELUM LUNAS)',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                    ),
                  ),
              ],

              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Terima Kasih', style: boldStyle),
                    pw.Text('Sudah berbelanja di kami', style: smallStyle),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Generated by Syupeo',
                      style: pw.TextStyle(
                        fontSize: 6,
                        color: PdfColors.grey500,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateTestPdf({required int copyIndex}) async {
    final settings = await PrinterSettings.load();
    final is58mm = settings.paperSize == PrinterPaperSize.mm58;

    final pdf = pw.Document(title: 'Test Print');

    final titleStyle = pw.TextStyle(
      fontSize: is58mm ? 13 : 16,
      fontWeight: pw.FontWeight.bold,
    );
    final bodyStyle = pw.TextStyle(fontSize: is58mm ? 8.5 : 10);
    final boldStyle = pw.TextStyle(
      fontSize: is58mm ? 8.5 : 10,
      fontWeight: pw.FontWeight.bold,
    );
    final smallStyle = pw.TextStyle(
      fontSize: is58mm ? 7.5 : 8,
      color: PdfColors.grey700,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: is58mm ? PdfPageFormat.roll57 : PdfPageFormat.roll80,
        margin: pw.EdgeInsets.symmetric(
          horizontal: is58mm ? 4 : 8,
          vertical: 6,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      settings.receiptTitle.trim().isEmpty
                          ? 'D-POS'
                          : settings.receiptTitle.trim(),
                      style: titleStyle,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Test Printer Windows / USB', style: smallStyle),
                    pw.SizedBox(height: 6),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              _infoRow('Status', 'BERHASIL TERHUBUNG', boldStyle, boldStyle),
              _infoRow('Mode Kertas', is58mm ? '58 mm' : '80 mm', bodyStyle, bodyStyle),
              _infoRow('Waktu', _dateTimeFmt.format(DateTime.now()), bodyStyle, bodyStyle),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kopi Susu x1', style: bodyStyle),
                  pw.Text('Rp 18.000', style: bodyStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Roti Bakar x2', style: bodyStyle),
                  pw.Text('Rp 30.000', style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: boldStyle),
                  pw.Text('Rp 48.000', style: boldStyle),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      settings.receiptFooter.trim().isEmpty
                          ? 'Terima kasih'
                          : settings.receiptFooter.trim(),
                      style: smallStyle,
                    ),
                    if (settings.copies > 1)
                      pw.Text('Copy $copyIndex/${settings.copies}', style: smallStyle),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateKitchenReceiptPdf(TransactionOrder order) async {
    final bootstrap = _ref.read(homeBootstrapProvider).value;
    final businessName = bootstrap?.business?.name ?? 'D-POS';
    final outletName = bootstrap?.currentOutlet?.name ?? '';

    final settings = await PrinterSettings.load();
    final is58mm = settings.paperSize == PrinterPaperSize.mm58;

    final pdf = pw.Document(
      title: 'Tiket Dapur ${order.invoiceNumber}',
      author: businessName,
    );

    final titleStyle = pw.TextStyle(
      fontSize: is58mm ? 13 : 16,
      fontWeight: pw.FontWeight.bold,
    );
    final boldStyle = pw.TextStyle(
      fontSize: is58mm ? 9.5 : 11,
      fontWeight: pw.FontWeight.bold,
    );
    final itemStyle = pw.TextStyle(
      fontSize: is58mm ? 10.5 : 12,
      fontWeight: pw.FontWeight.bold,
    );
    final noteStyle = pw.TextStyle(
      fontSize: is58mm ? 8.5 : 9.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.deepOrange800,
    );
    final smallStyle = pw.TextStyle(
      fontSize: is58mm ? 7.5 : 8.5,
      color: PdfColors.grey700,
    );

    final diningBanner = switch (order.diningOption) {
      DiningOption.takeAway => 'TAKE AWAY (BUNGKUS)',
      DiningOption.delivery => 'DELIVERY',
      DiningOption.goFood => 'ONLINE: GOFOOD',
      DiningOption.grabFood => 'ONLINE: GRABFOOD',
      DiningOption.shopeeFood => 'ONLINE: SHOPEEFOOD',
      DiningOption.custom => 'PESANAN KHUSUS',
      DiningOption.dineIn => (order.tableNumber != null
          ? 'DINE IN - MEJA ${order.tableNumber}'
          : 'DINE IN'),
    };

    final dateStr = order.createdAt != null
        ? _dateTimeFmt.format(order.createdAt!)
        : _dateTimeFmt.format(DateTime.now());

    final totalItems = order.items.fold(0, (sum, item) => sum + item.quantity);

    pdf.addPage(
      pw.Page(
        pageFormat: is58mm ? PdfPageFormat.roll57 : PdfPageFormat.roll80,
        margin: pw.EdgeInsets.symmetric(
          horizontal: is58mm ? 4 : 8,
          vertical: 6,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  '*** TIKET DAPUR (KOT) ***',
                  style: titleStyle,
                ),
              ),
              if (outletName.isNotEmpty)
                pw.Center(child: pw.Text(outletName, style: smallStyle)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    diningBanner,
                    style: pw.TextStyle(
                      fontSize: is58mm ? 12 : 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('No: ${order.invoiceNumber}', style: smallStyle),
              pw.Text('Waktu: $dateStr', style: smallStyle),
              if (order.waiterName != null && order.waiterName!.isNotEmpty)
                pw.Text('Waiter: ${order.waiterName}', style: smallStyle),
              if (order.cashierName != null && order.cashierName!.isNotEmpty)
                pw.Text('Kasir: ${order.cashierName}', style: smallStyle),
              if (order.customerName != null && order.customerName!.isNotEmpty)
                pw.Text('Pelanggan: ${order.customerName}', style: smallStyle),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Items
              ...order.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.grey300,
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                            ),
                            child: pw.Text('${item.quantity}x', style: itemStyle),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text(
                              item.displayName,
                              style: itemStyle,
                            ),
                          ),
                        ],
                      ),
                      if (item.isPackage && item.packageComponents.isNotEmpty)
                        ...item.packageComponents.map(
                          (comp) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 14, top: 1),
                            child: pw.Text('+ $comp', style: smallStyle),
                          ),
                        ),
                      if (item.notes != null && item.notes!.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 14, top: 1),
                          child: pw.Text('* REQ: ${item.notes} *', style: noteStyle),
                        ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                pw.Text('Catatan Pesanan:', style: boldStyle),
                pw.Text(order.notes!, style: noteStyle),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL ITEM:', style: boldStyle),
                  pw.Text('$totalItems Item', style: boldStyle),
                ],
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _infoRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: labelStyle),
          pw.Text(value, style: valueStyle),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    double value,
    pw.TextStyle style, {
    bool isDiscount = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(
            isDiscount
                ? '-${_currency.format(value.abs())}'
                : _currency.format(value),
            style: isDiscount
                ? style.copyWith(color: PdfColors.green700)
                : style,
          ),
        ],
      ),
    );
  }
}
