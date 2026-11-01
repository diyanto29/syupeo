import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/inventory_models.dart';
import '../../menu_management/domain/menu_models.dart';

class InventoryReportService {
  static final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final dateFormat = DateFormat('dd MMMM yyyy, HH:mm');

  static Future<Uint8List> generateInventoryPdf({
    required String businessName,
    required List<MenuItem> stockItems,
    required List<PurchaseOrder> recentPOs,
    required List<Supplier> suppliers,
  }) async {
    final pdf = pw.Document();

    // Load Font
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LAPORAN INVENTARIS',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    businessName.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 14),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Dicetak pada:',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                  pw.Text(
                    dateFormat.format(DateTime.now()),
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(thickness: 2, color: PdfColors.blue900),
          pw.SizedBox(height: 24),

          // 1. Ringkasan Stok
          pw.Text(
            '1. Ringkasan Stok Barang',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          _buildStockTable(stockItems, font, fontBold),
          pw.SizedBox(height: 32),

          // 2. Pesanan Pembelian Terbaru
          pw.Text(
            '2. Pesanan Pembelian Terbaru (PO)',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          _buildPOTable(recentPOs, font, fontBold),
          pw.SizedBox(height: 32),

          // 3. Daftar Supplier
          pw.Text(
            '3. Daftar Supplier Aktif',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          _buildSupplierTable(suppliers, font, fontBold),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStockTable(
      List<MenuItem> items, pw.Font font, pw.Font fontBold) {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      headers: ['Nama Barang', 'Stok Saat Ini', 'Satuan', 'Status'],
      data: items.map((item) {
        final isLow = (item.stockQuantity) < 10; // Threshold contoh
        return [
          item.name,
          item.formattedStock,
          item.unit,
          isLow ? 'Stok Menipis' : 'Aman',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildPOTable(
      List<PurchaseOrder> pos, pw.Font font, pw.Font fontBold) {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      headers: ['No. PO', 'Tanggal', 'Supplier', 'Total', 'Status'],
      data: pos.map((po) {
        return [
          po.poNumber,
          po.createdAt != null ? DateFormat('dd/MM/yy').format(po.createdAt!) : '-',
          po.supplier?.name ?? '-',
          currencyFormat.format(po.totalAmount),
          po.status.name.toUpperCase(),
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildSupplierTable(
      List<Supplier> suppliers, pw.Font font, pw.Font fontBold) {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      headers: ['Nama Supplier', 'Kontak', 'Telepon', 'Email'],
      data: suppliers.map((s) {
        return [
          s.name,
          s.contactName ?? '-',
          s.phone ?? '-',
          s.email ?? '-',
        ];
      }).toList(),
    );
  }
}
