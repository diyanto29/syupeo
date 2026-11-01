import 'dart:typed_data';
import 'package:dpos/features/reports/domain/report_models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Service to generate a comprehensive PDF report from [FullReport].
class ReportPdfService {
  const ReportPdfService._();

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateFmt = DateFormat('dd MMM yyyy', 'id_ID');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

  /// Generate a complete PDF report and return it as bytes.
  static Future<Uint8List> generateFullReport({
    required FullReport report,
    required String businessName,
    required String outletName,
    required String periodLabel,
  }) async {
    final pdf = pw.Document(
      title: 'Laporan Penjualan - $businessName',
      author: businessName,
      creator: 'Syupeo',
    );

    // ── Theme ────────────────────────────────────────────────
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#0F2027'),
    );
    final labelStyle = pw.TextStyle(fontSize: 8, color: PdfColors.grey600);
    final valueStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final tableHeaderStyle = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final tableCellStyle = pw.TextStyle(fontSize: 8);

    final accentColor = PdfColor.fromHex('#FF8C00');
    final darkColor = PdfColor.fromHex('#0F2027');

    // ── Timestamp ────────────────────────────────────────────
    final generatedAt = _dateTimeFmt.format(DateTime.now());
    final periodStart = _dateFmt.format(report.period.start);
    final periodEnd = _dateFmt.format(
      report.period.end.subtract(const Duration(days: 1)),
    );
    final periodStr = report.period.dayCount == 1
        ? periodStart
        : '$periodStart – $periodEnd';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPageHeader(
          context,
          businessName: businessName,
          outletName: outletName,
          periodStr: periodStr,
          periodLabel: periodLabel,
          generatedAt: generatedAt,
          headerStyle: headerStyle,
          labelStyle: labelStyle,
          accentColor: accentColor,
          darkColor: darkColor,
        ),
        footer: (context) => _buildPageFooter(context, labelStyle),
        build: (context) => [
          // ══════════════════════════════════════════════════════
          // SECTION 1: RINGKASAN UTAMA
          // ══════════════════════════════════════════════════════
          _sectionTitle('RINGKASAN PENJUALAN', sectionStyle, accentColor),
          pw.SizedBox(height: 8),
          _buildSummaryGrid(report, valueStyle, labelStyle, accentColor),
          pw.SizedBox(height: 20),

          // ══════════════════════════════════════════════════════
          // SECTION: PERFORMA CABANG (KONSOLIDASI)
          // ══════════════════════════════════════════════════════
          if (report.outletPerformances.length > 1) ...[
            _sectionTitle('KONTRIBUSI CABANG / OUTLET', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildOutletPerformanceTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 2: METODE PEMBAYARAN
          // ══════════════════════════════════════════════════════
          if (report.revenueByMethod.isNotEmpty) ...[
            _sectionTitle('METODE PEMBAYARAN', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildPaymentMethodsTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 3: SUMBER PESANAN
          // ══════════════════════════════════════════════════════
          if (report.ordersBySource.isNotEmpty) ...[
            _sectionTitle('SUMBER PESANAN', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildOrderSourcesTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 4: PRODUK TERLARIS
          // ══════════════════════════════════════════════════════
          if (report.topProducts.isNotEmpty) ...[
            _sectionTitle(
              'PRODUK TERLARIS (TOP 10)',
              sectionStyle,
              accentColor,
            ),
            pw.SizedBox(height: 8),
            _buildProductsTable(
              report.topProducts,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 5: PRODUK TERENDAH
          // ══════════════════════════════════════════════════════
          if (report.bottomProducts.isNotEmpty &&
              report.bottomProducts.length > 1) ...[
            _sectionTitle('PRODUK PERLU PERHATIAN', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildProductsTable(
              report.bottomProducts,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 6: PERFORMA KASIR
          // ══════════════════════════════════════════════════════
          if (report.cashierPerformances.isNotEmpty) ...[
            _sectionTitle('PERFORMA KASIR', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildCashierTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 6.5: PERFORMA WAITER
          // ══════════════════════════════════════════════════════
          if (report.waiterPerformances.isNotEmpty) ...[
            _sectionTitle('PERFORMA WAITER', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildWaiterTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 7: PENJUALAN PER JAM
          // ══════════════════════════════════════════════════════
          if (report.hourlySales.isNotEmpty) ...[
            _sectionTitle('PENJUALAN PER JAM', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildHourlySalesTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
              accentColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 8: BREAKDOWN HARIAN
          // ══════════════════════════════════════════════════════
          if (report.dailyBreakdown.isNotEmpty) ...[
            _sectionTitle('BREAKDOWN HARIAN', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildDailyBreakdownTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
            pw.SizedBox(height: 20),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION 9: VOID & REFUND (AUDIT)
          // ══════════════════════════════════════════════════════
          if (report.cancelledOrders > 0 || report.refundedOrders > 0) ...[
            _sectionTitle('DETAIL VOID & REFUND', sectionStyle, accentColor),
            pw.SizedBox(height: 8),
            _buildVoidRefundTable(
              report,
              tableHeaderStyle,
              tableCellStyle,
              darkColor,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════
  // PAGE HEADER & FOOTER
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildPageHeader(
    pw.Context context, {
    required String businessName,
    required String outletName,
    required String periodStr,
    required String periodLabel,
    required String generatedAt,
    required pw.TextStyle headerStyle,
    required pw.TextStyle labelStyle,
    required PdfColor accentColor,
    required PdfColor darkColor,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(businessName, style: headerStyle),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    outletName,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'LAPORAN PENJUALAN',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Periode: $periodLabel', style: labelStyle),
                  pw.Text(periodStr, style: labelStyle),
                  pw.Text('Dicetak: $generatedAt', style: labelStyle),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 2,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [darkColor, accentColor]),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(
    pw.Context context,
    pw.TextStyle labelStyle,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat oleh Syupeo (mudahkan.online)',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SECTION TITLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _sectionTitle(
    String title,
    pw.TextStyle style,
    PdfColor accent,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accent, width: 1.5)),
      ),
      child: pw.Text(title, style: style),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUMMARY GRID
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildSummaryGrid(
    FullReport report,
    pw.TextStyle valueStyle,
    pw.TextStyle labelStyle,
    PdfColor accent,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F5F5FA'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              _summaryCell(
                'Total Pendapatan',
                _currency.format(report.totalRevenue),
                valueStyle,
                labelStyle,
                highlight: true,
                accent: accent,
              ),
              _summaryCell(
                'Total Diskon',
                _currency.format(report.totalDiscount),
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Net Revenue',
                _currency.format(report.netRevenue),
                valueStyle,
                labelStyle,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _summaryCell(
                'Modal Produk (HPP)',
                _currency.format(report.totalCogs),
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Beban Kas Keluar',
                _currency.format(report.totalExpenses),
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Laba Bersih (${report.netProfitMargin.toStringAsFixed(1)}%)',
                _currency.format(report.netProfit),
                valueStyle,
                labelStyle,
                highlight: true,
                accent: PdfColor.fromHex('#00A843'),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _summaryCell(
                'Total Order',
                '${report.totalOrders}',
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Total Item',
                '${report.totalItems}',
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Rata-rata Order',
                _currency.format(report.avgOrderValue),
                valueStyle,
                labelStyle,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _summaryCell(
                'Order Batal',
                '${report.cancelledOrders} (${_currency.format(report.cancelledRevenue)})',
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Order Refund',
                '${report.refundedOrders} (${_currency.format(report.refundedRevenue)})',
                valueStyle,
                labelStyle,
              ),
              _summaryCell(
                'Periode',
                '${report.period.dayCount} hari',
                valueStyle,
                labelStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Expanded _summaryCell(
    String label,
    String value,
    pw.TextStyle valueStyle,
    pw.TextStyle labelStyle, {
    bool highlight = false,
    PdfColor? accent,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: highlight
            ? pw.BoxDecoration(
                color: accent?.shade(0.95) ?? PdfColors.orange50,
                borderRadius: pw.BorderRadius.circular(4),
              )
            : null,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: labelStyle),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: highlight
                  ? valueStyle.copyWith(
                      fontSize: 12,
                      color: accent ?? PdfColors.orange800,
                    )
                  : valueStyle,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PAYMENT METHODS TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildPaymentMethodsTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    final total = report.revenueByMethod.values.fold(0.0, (a, b) => a + b);
    final sorted = report.revenueByMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headers: ['Metode', 'Jumlah', '%'],
      data: [
        ...sorted.map((e) {
          final pct = total > 0 ? (e.value / total * 100) : 0.0;
          return [
            e.key,
            _currency.format(e.value),
            '${pct.toStringAsFixed(1)}%',
          ];
        }),
        ['TOTAL', _currency.format(total), '100%'],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ORDER SOURCES TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildOrderSourcesTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      headers: ['Sumber', 'Jumlah Order', '%'],
      data: report.ordersBySource.entries.map((e) {
        final pct = report.totalOrders > 0
            ? (e.value / report.totalOrders * 100)
            : 0.0;
        return [e.key, '${e.value}', '${pct.toStringAsFixed(1)}%'];
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PRODUCTS TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildProductsTable(
    List<ProductPerformance> products,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['#', 'Produk', 'Qty', 'Avg Harga', 'Revenue'],
      data: products.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        return [
          '${i + 1}',
          p.name,
          '${p.qtySold}',
          _currency.format(p.avgPrice),
          _currency.format(p.revenue),
        ];
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CASHIER TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildCashierTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    final totalRevenue = report.cashierPerformances.fold(
      0.0,
      (sum, c) => sum + c.totalRevenue,
    );

    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['#', 'Nama Kasir', 'Order', 'Avg Order', 'Revenue (%)'],
      data: report.cashierPerformances.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        final pct = totalRevenue > 0
            ? (c.totalRevenue / totalRevenue * 100)
            : 0.0;
        return [
          '${i + 1}',
          c.cashierName,
          '${c.orderCount}',
          _currency.format(c.avgOrderValue),
          '${_currency.format(c.totalRevenue)} (${pct.toStringAsFixed(1)}%)',
        ];
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // WAITER TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildWaiterTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    final totalRevenue = report.waiterPerformances.fold(
      0.0,
      (sum, w) => sum + w.totalRevenue,
    );

    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['#', 'Nama Waiter', 'Order', 'Avg Order', 'Revenue (%)'],
      data: report.waiterPerformances.asMap().entries.map((entry) {
        final i = entry.key;
        final w = entry.value;
        final pct = totalRevenue > 0
            ? (w.totalRevenue / totalRevenue * 100)
            : 0.0;
        return [
          '${i + 1}',
          w.waiterName,
          '${w.orderCount}',
          _currency.format(w.avgOrderValue),
          '${_currency.format(w.totalRevenue)} (${pct.toStringAsFixed(1)}%)',
        ];
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // OUTLET PERFORMANCE TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildOutletPerformanceTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['#', 'Nama Cabang / Outlet', 'Total Order', 'Avg Order', 'Total Omset (%)'],
      data: report.outletPerformances.asMap().entries.map((entry) {
        final i = entry.key;
        final o = entry.value;
        return [
          '${i + 1}',
          o.outletName,
          '${o.totalOrders}',
          _currency.format(o.avgOrderValue),
          '${_currency.format(o.totalRevenue)} (${o.percentage.toStringAsFixed(1)}%)',
        ];
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HOURLY SALES TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildHourlySalesTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
    PdfColor accentColor,
  ) {
    final sortedHours = report.hourlySales.keys.toList()..sort();
    final maxRevenue = report.hourlySales.values.isNotEmpty
        ? report.hourlySales.values.reduce((a, b) => a > b ? a : b)
        : 1.0;

    return pw.Column(
      children: [
        // Mini bar chart
        pw.Container(
          height: 60,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: sortedHours.map((hour) {
              final revenue = report.hourlySales[hour] ?? 0;
              final barHeight = maxRevenue > 0
                  ? (revenue / maxRevenue) * 50
                  : 0.0;
              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        height: barHeight.clamp(2, 50),
                        decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: const pw.BorderRadius.vertical(
                            top: pw.Radius.circular(2),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        hour.toString().padLeft(2, '0'),
                        style: pw.TextStyle(
                          fontSize: 5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        pw.SizedBox(height: 8),
        // Data table
        pw.TableHelper.fromTextArray(
          border: null,
          headerDecoration: pw.BoxDecoration(color: darkColor),
          headerStyle: headerStyle,
          cellStyle: cellStyle,
          oddRowDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F9F9FE'),
          ),
          headerAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerRight,
          },
          cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerRight},
          headers: ['Jam', 'Revenue'],
          data: sortedHours.map((hour) {
            return [
              '${hour.toString().padLeft(2, '0')}:00',
              _currency.format(report.hourlySales[hour] ?? 0),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DAILY BREAKDOWN TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildDailyBreakdownTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9F9FE')),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headers: ['Tanggal', 'Revenue', 'Diskon', 'Order', 'Item', 'Avg Order'],
      data: [
        ...report.dailyBreakdown.map((d) {
          return [
            _dateFmt.format(d.date),
            _currency.format(d.totalRevenue),
            _currency.format(d.totalDiscount),
            '${d.totalOrders}',
            '${d.totalItems}',
            _currency.format(d.avgOrderValue),
          ];
        }),
        // Total row
        [
          'TOTAL',
          _currency.format(report.totalRevenue),
          _currency.format(report.totalDiscount),
          '${report.totalOrders}',
          '${report.totalItems}',
          _currency.format(report.avgOrderValue),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // VOID & REFUND TABLE
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _buildVoidRefundTable(
    FullReport report,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor darkColor,
  ) {
    final allAudit =
        [...report.cancelledOrdersList, ...report.refundedOrdersList]..sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );

    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: darkColor),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF5F5')),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerLeft,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerLeft,
      },
      headers: ['No Invoice', 'Status', 'Tgl/Waktu', 'Nominal', 'Alasan'],
      data: allAudit.map((order) {
        return [
          order.invoiceNumber,
          order.status.label.toUpperCase(),
          order.createdAt != null ? _dateTimeFmt.format(order.createdAt!) : '-',
          _currency.format(order.grandTotal),
          order.voidReason ?? '-',
        ];
      }).toList(),
    );
  }
}
