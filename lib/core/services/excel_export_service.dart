import 'dart:io';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class ExcelExportService {
  static Future<void> exportInventory(
    BuildContext context, {
    required List<MenuItem> items,
    required String businessName,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Inventaris';

    // Title & Info
    sheet.getRangeByIndex(1, 1).setText('LAPORAN INVENTARIS & STOK BARANG');
    sheet.getRangeByIndex(1, 1).cellStyle.fontSize = 14;
    sheet.getRangeByIndex(1, 1).cellStyle.bold = true;

    sheet.getRangeByIndex(3, 1).setText('Bisnis');
    sheet.getRangeByIndex(3, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(3, 2).setText(businessName);

    sheet.getRangeByIndex(4, 1).setText('Tanggal Ekspor');
    sheet.getRangeByIndex(4, 1).cellStyle.bold = true;
    sheet
        .getRangeByIndex(4, 2)
        .setText(DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now()));

    // Headers
    final headers = [
      'No',
      'Nama Produk',
      'SKU',
      'Barcode',
      'Kategori',
      'Stok',
      'Satuan',
      'Harga Beli (Modal)',
      'Harga Jual',
      'Status Stok',
    ];

    for (int col = 1; col <= headers.length; col++) {
      final cell = sheet.getRangeByIndex(6, col);
      cell.setText(headers[col - 1]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1F4E79';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int row = 7;
    int index = 1;
    for (final item in items) {
      final statusStok = item.trackStockQuantity
          ? (item.stockQuantity <= 0
                ? 'Habis'
                : (item.stockQuantity < 10 ? 'Menipis' : 'Aman'))
          : 'Tanpa Batas';

      sheet.getRangeByIndex(row, 1).setNumber(index.toDouble());
      index++;
      sheet.getRangeByIndex(row, 2).setText(item.name);
      sheet.getRangeByIndex(row, 3).setText(item.sku ?? '-');
      sheet.getRangeByIndex(row, 4).setText(item.barcode ?? '-');
      sheet.getRangeByIndex(row, 5).setText(item.categoryName);

      if (item.trackStockQuantity) {
        sheet.getRangeByIndex(row, 6).setNumber(item.stockQuantity.toDouble());
        sheet.getRangeByIndex(row, 6).numberFormat = '#,##0';
      } else {
        sheet.getRangeByIndex(row, 6).setText('-');
      }

      sheet.getRangeByIndex(row, 7).setText(item.displayUnit);

      sheet.getRangeByIndex(row, 8).setNumber(item.recipeCost);
      sheet.getRangeByIndex(row, 8).numberFormat = '#,##0';

      sheet.getRangeByIndex(row, 9).setNumber(item.price);
      sheet.getRangeByIndex(row, 9).numberFormat = '#,##0';

      sheet.getRangeByIndex(row, 10).setText(statusStok);

      row++;
    }

    // Auto-fit all columns
    for (int col = 1; col <= headers.length; col++) {
      sheet.autoFitColumn(col);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/Laporan_Inventaris_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes);

    if (context.mounted) {
      await _showSuccessDialog(
        context,
        filePath: file.path,
        subject: 'Laporan Inventaris $businessName',
      );
    }
  }

  static Future<void> exportSalesReport(
    BuildContext context, {
    required FullReport report,
    required String businessName,
    required String periodLabel,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Laporan Penjualan';

    int r = 1;

    // Title
    sheet.getRangeByIndex(r, 1).setText('LAPORAN PENJUALAN BISNIS');
    sheet.getRangeByIndex(r, 1).cellStyle.fontSize = 14;
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    r += 2;

    // Info
    sheet.getRangeByIndex(r, 1).setText('Bisnis');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 2).setText(businessName);
    r++;

    sheet.getRangeByIndex(r, 1).setText('Periode');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 2).setText(periodLabel);
    r++;

    sheet.getRangeByIndex(r, 1).setText('Tanggal Ekspor');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet
        .getRangeByIndex(r, 2)
        .setText(DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now()));
    r += 2;

    // 2. Ringkasan Utama
    sheet.getRangeByIndex(r, 1).setText('RINGKASAN UTAMA');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 1).cellStyle.fontSize = 12;
    r++;

    sheet.getRangeByIndex(r, 1).setText('Kategori');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 1).cellStyle.backColor = '#1F4E79';
    sheet.getRangeByIndex(r, 1).cellStyle.fontColor = '#FFFFFF';

    sheet.getRangeByIndex(r, 2).setText('Nilai');
    sheet.getRangeByIndex(r, 2).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 2).cellStyle.backColor = '#1F4E79';
    sheet.getRangeByIndex(r, 2).cellStyle.fontColor = '#FFFFFF';
    r++;

    void writeSummaryRow(
      String category,
      double value, {
      bool isInteger = false,
    }) {
      sheet.getRangeByIndex(r, 1).setText(category);
      sheet.getRangeByIndex(r, 2).setNumber(value);
      sheet.getRangeByIndex(r, 2).numberFormat = '#,##0';
      r++;
    }

    writeSummaryRow('Total Penjualan Kotor (Omzet)', report.totalRevenue);
    writeSummaryRow('Total Diskon', report.totalDiscount);
    writeSummaryRow('Total Penjualan Bersih (Net Revenue)', report.netRevenue);
    writeSummaryRow('Harga Pokok Penjualan (HPP / Modal)', report.totalCogs);
    writeSummaryRow('Laba Kotor (Gross Profit)', report.grossProfit);
    writeSummaryRow('Pengeluaran Operasional (Kas Keluar)', report.totalExpenses);
    writeSummaryRow('Laba Bersih (Net Profit)', report.netProfit);
    writeSummaryRow('Margin Laba Bersih (%)', report.netProfitMargin);
    writeSummaryRow(
      'Total Transaksi',
      report.totalOrders.toDouble(),
      isInteger: true,
    );
    writeSummaryRow('Rata-rata Nilai Transaksi', report.avgOrderValue);
    writeSummaryRow(
      'Transaksi Dibatalkan (Void)',
      report.cancelledOrders.toDouble(),
      isInteger: true,
    );
    writeSummaryRow(
      'Transaksi Refund',
      report.refundedOrders.toDouble(),
      isInteger: true,
    );
    r += 2;

    // 3. Daily Breakdown
    sheet.getRangeByIndex(r, 1).setText('PENJUALAN HARIAN');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 1).cellStyle.fontSize = 12;
    r++;

    final dailyHeaders = [
      'Tanggal',
      'Kotor',
      'Diskon',
      'Bersih (Net)',
      'Jumlah Transaksi',
      'Jumlah Barang',
    ];
    for (int col = 1; col <= dailyHeaders.length; col++) {
      final cell = sheet.getRangeByIndex(r, col);
      cell.setText(dailyHeaders[col - 1]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1F4E79';
      cell.cellStyle.fontColor = '#FFFFFF';
    }
    r++;

    for (final day in report.dailyBreakdown) {
      final dateStr = DateFormat('dd MMM yyyy').format(day.date);
      sheet.getRangeByIndex(r, 1).setText(dateStr);

      sheet.getRangeByIndex(r, 2).setNumber(day.totalRevenue);
      sheet.getRangeByIndex(r, 2).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 3).setNumber(day.totalDiscount);
      sheet.getRangeByIndex(r, 3).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 4).setNumber(day.netRevenue);
      sheet.getRangeByIndex(r, 4).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 5).setNumber(day.totalOrders.toDouble());
      sheet.getRangeByIndex(r, 5).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 6).setNumber(day.totalItems.toDouble());
      sheet.getRangeByIndex(r, 6).numberFormat = '#,##0';
      r++;
    }
    r += 2;

    // 4. Products
    sheet.getRangeByIndex(r, 1).setText('PERFORMA PRODUK (TERLARIS)');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 1).cellStyle.fontSize = 12;
    r++;

    final productHeaders = [
      'No',
      'Nama Produk',
      'Qty Terjual',
      'Total Omset',
      'Rata-rata Harga',
    ];
    for (int col = 1; col <= productHeaders.length; col++) {
      final cell = sheet.getRangeByIndex(r, col);
      cell.setText(productHeaders[col - 1]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1F4E79';
      cell.cellStyle.fontColor = '#FFFFFF';
    }
    r++;

    int prodIndex = 1;
    for (final prod in report.topProducts) {
      sheet.getRangeByIndex(r, 1).setNumber(prodIndex.toDouble());
      prodIndex++;
      sheet.getRangeByIndex(r, 2).setText(prod.name);

      sheet.getRangeByIndex(r, 3).setNumber(prod.qtySold.toDouble());
      sheet.getRangeByIndex(r, 3).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 4).setNumber(prod.revenue);
      sheet.getRangeByIndex(r, 4).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 5).setNumber(prod.avgPrice);
      sheet.getRangeByIndex(r, 5).numberFormat = '#,##0';
      r++;
    }
    r += 2;

    // 5. Cashier
    sheet.getRangeByIndex(r, 1).setText('PERFORMA KASIR');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 1).cellStyle.fontSize = 12;
    r++;

    final cashierHeaders = [
      'Nama Kasir',
      'Jumlah Transaksi',
      'Total Omset',
      'Rata-rata Transaksi',
    ];
    for (int col = 1; col <= cashierHeaders.length; col++) {
      final cell = sheet.getRangeByIndex(r, col);
      cell.setText(cashierHeaders[col - 1]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1F4E79';
      cell.cellStyle.fontColor = '#FFFFFF';
    }
    r++;

    for (final c in report.cashierPerformances) {
      sheet.getRangeByIndex(r, 1).setText(c.cashierName);

      sheet.getRangeByIndex(r, 2).setNumber(c.orderCount.toDouble());
      sheet.getRangeByIndex(r, 2).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 3).setNumber(c.totalRevenue);
      sheet.getRangeByIndex(r, 3).numberFormat = '#,##0';

      sheet.getRangeByIndex(r, 4).setNumber(c.avgOrderValue);
      sheet.getRangeByIndex(r, 4).numberFormat = '#,##0';
      r++;
    }
    r += 2;

    // 6. Payment Methods
    sheet.getRangeByIndex(r, 1).setText('METODE PEMBAYARAN');
    sheet.getRangeByIndex(r, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(r, 1).cellStyle.fontSize = 12;
    r++;

    final paymentHeaders = ['Metode', 'Total Omset'];
    for (int col = 1; col <= paymentHeaders.length; col++) {
      final cell = sheet.getRangeByIndex(r, col);
      cell.setText(paymentHeaders[col - 1]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1F4E79';
      cell.cellStyle.fontColor = '#FFFFFF';
    }
    r++;

    report.revenueByMethod.forEach((method, amount) {
      sheet.getRangeByIndex(r, 1).setText(method);
      sheet.getRangeByIndex(r, 2).setNumber(amount);
      sheet.getRangeByIndex(r, 2).numberFormat = '#,##0';
      r++;
    });

    // Auto-fit all columns (since max columns is 6)
    for (int col = 1; col <= 6; col++) {
      sheet.autoFitColumn(col);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/Laporan_Penjualan_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes);

    if (context.mounted) {
      await _showSuccessDialog(
        context,
        filePath: file.path,
        subject: 'Laporan Penjualan $businessName',
      );
    }
  }

  static Future<void> _showSuccessDialog(
    BuildContext context, {
    required String filePath,
    required String subject,
  }) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ekspor Excel Berhasil',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Laporan Excel telah berhasil dibuat dan disimpan di penyimpanan sementara.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tutup', style: TextStyle(color: scheme.outline)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Share.shareXFiles([
                      XFile(filePath),
                    ], subject: subject);
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Bagikan'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      final result = await OpenFilex.open(filePath);
                      if (result.type != ResultType.done) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Tidak dapat membuka file: ${result.message}',
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membuka file: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Buka'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
