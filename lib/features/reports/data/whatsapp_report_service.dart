import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dpos/features/reports/domain/report_models.dart';

class WhatsAppReportService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
  static final _timeFormat = DateFormat('HH:mm', 'id_ID');

  /// Membuat teks rekapitulasi penjualan rapi untuk dikirimkan via WhatsApp.
  static String generateReportText({
    required FullReport report,
    required String businessName,
    String? outletName,
    String? periodLabel,
    String? cashierName,
    bool isShiftClosed = false,
    double? startingCash,
    double? actualCash,
    double? cashDifference,
    List<String>? criticalStockAlerts,
  }) {
    final now = DateTime.now();
    final buffer = StringBuffer();

    // ── Header ──────────────────────────────────────────────
    if (isShiftClosed) {
      buffer.writeln('📊 *LAPORAN TUTUP TOKO (SHIFT) - SYUPEO*');
    } else {
      buffer.writeln('📊 *RINGKASAN PENJUALAN - SYUPEO*');
    }

    buffer.writeln('🏪 *Toko:* $businessName${outletName != null ? ' ($outletName)' : ''}');
    buffer.writeln('📅 *Tanggal:* ${_dateFormat.format(now)}');
    if (periodLabel != null && periodLabel != 'Hari Ini') {
      buffer.writeln('⏱️ *Periode:* $periodLabel');
    }
    buffer.writeln('⏰ *Waktu Rekap:* ${_timeFormat.format(now)} WIB');
    if (cashierName != null && cashierName.isNotEmpty) {
      buffer.writeln('👤 *Kasir:* $cashierName');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();

    // ── Ringkasan Omzet ─────────────────────────────────────
    buffer.writeln('💰 *RINGKASAN PENJUALAN:*');
    buffer.writeln('• Total Transaksi: ${report.totalOrders} Transaksi');
    buffer.writeln('• Penjualan Kotor: ${_currencyFormat.format(report.totalRevenue)}');
    if (report.totalDiscount > 0) {
      buffer.writeln('• Diskon: -${_currencyFormat.format(report.totalDiscount)}');
    }
    buffer.writeln('• *PENJUALAN BERSIH: ${_currencyFormat.format(report.netRevenue)}*');
    if (report.totalCogs > 0) {
      buffer.writeln('• Modal Produk (HPP): ${_currencyFormat.format(report.totalCogs)}');
    }
    buffer.writeln('• Estimasi Laba Kotor: ${_currencyFormat.format(report.grossProfit)} (${report.grossProfitMargin.toStringAsFixed(1)}%)');
    if (report.totalExpenses > 0) {
      buffer.writeln('• Beban Kas Keluar: -${_currencyFormat.format(report.totalExpenses)}');
    }
    buffer.writeln('• *ESTIMASI LABA BERSIH: ${_currencyFormat.format(report.netProfit)} (${report.netProfitMargin.toStringAsFixed(1)}%)*');
    buffer.writeln();

    // ── Rincian Metode Pembayaran ────────────────────────────
    if (report.revenueByMethod.isNotEmpty) {
      buffer.writeln('💳 *METODE PEMBAYARAN:*');
      for (final entry in report.revenueByMethod.entries) {
        final methodName = entry.key;
        final amount = entry.value;
        String icon = '• 💵';
        final lower = methodName.toLowerCase();
        if (lower.contains('qris')) {
          icon = '• 📱';
        } else if (lower.contains('transfer') || lower.contains('bank')) {
          icon = '• 🏦';
        } else if (lower.contains('kartu') || lower.contains('card') || lower.contains('debit')) {
          icon = '• 💳';
        } else if (lower.contains('kasbon') || lower.contains('tempo') || lower.contains('piutang')) {
          icon = '• 📝';
        }

        buffer.writeln('$icon $methodName: ${_currencyFormat.format(amount)}');
      }
      buffer.writeln();
    }

    // ── Rekonsiliasi Kas Laci (Jika ada shift) ───────────────
    if (isShiftClosed && startingCash != null && actualCash != null) {
      buffer.writeln('💵 *REKONSILIASI KAS LACI (SHIFT):*');
      buffer.writeln('• Modal Awal Kas: ${_currencyFormat.format(startingCash)}');
      
      // Hitung tunai masuk dari revenueByMethod
      double cashPayments = 0.0;
      for (final entry in report.revenueByMethod.entries) {
        final lower = entry.key.toLowerCase();
        if (lower.contains('tunai') || lower.contains('cash')) {
          cashPayments += entry.value;
        }
      }
      buffer.writeln('• Penjualan Tunai: +${_currencyFormat.format(cashPayments)}');

      if (report.totalExpenses > 0) {
        buffer.writeln('• Kas Keluar (Beban): -${_currencyFormat.format(report.totalExpenses)}');
      }

      final expectedCash = startingCash + cashPayments - report.totalExpenses;
      buffer.writeln('• Uang Seharusnya di Laci: *${_currencyFormat.format(expectedCash)}*');
      buffer.writeln('• Uang Fisik Aktual di Laci: *${_currencyFormat.format(actualCash)}*');

      final diff = cashDifference ?? (actualCash - expectedCash);
      if (diff == 0) {
        buffer.writeln('• *Status Selisih:* ✅ *PAS (Tidak ada selisih)*');
      } else if (diff > 0) {
        buffer.writeln('• *Status Selisih:* 🟢 *LEBIH ${_currencyFormat.format(diff)}*');
      } else {
        buffer.writeln('• *Status Selisih:* 🔴 *KURANG ${_currencyFormat.format(diff.abs())}*');
      }
      buffer.writeln();
    }

    // ── Top 3 Produk Terlaris ────────────────────────────────
    if (report.topProducts.isNotEmpty) {
      buffer.writeln('🏆 *TOP PRODUK TERLARIS:*');
      final top3 = report.topProducts.take(3).toList();
      for (int i = 0; i < top3.length; i++) {
        final p = top3[i];
        buffer.writeln('${i + 1}. ${p.name} (${p.qtySold} terjual)');
      }
      buffer.writeln();
    }

    // ── Peringatan Stok Menipis ──────────────────────────────
    if (criticalStockAlerts != null && criticalStockAlerts.isNotEmpty) {
      buffer.writeln('⚠️ *PERINGATAN STOK MENIPIS:*');
      for (final alert in criticalStockAlerts.take(5)) {
        buffer.writeln('• $alert');
      }
      buffer.writeln();
    }

    // ── Footer ──────────────────────────────────────────────
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔗 *Portal Backoffice Merchant:*');
    buffer.writeln('https://app.mudahkan.online/merchant/reports');

    return buffer.toString();
  }

  /// Membagikan laporan langsung ke WhatsApp.
  /// Jika [targetPhone] disediakan, akan ditujukan langsung ke nomor tersebut (misal nomor owner).
  /// Jika null, user dapat memilih kontak WhatsApp yang dituju.
  static Future<bool> shareToWhatsApp({
    required String message,
    String? targetPhone,
  }) async {
    // Salin ke clipboard sebagai backup
    await Clipboard.setData(ClipboardData(text: message));

    String cleanPhone = '';
    if (targetPhone != null && targetPhone.trim().isNotEmpty) {
      cleanPhone = targetPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '62${cleanPhone.substring(1)}';
      }
    }

    final encodedText = Uri.encodeComponent(message);

    // Coba deep link native WhatsApp
    Uri waUri;
    if (cleanPhone.isNotEmpty) {
      waUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText');
    } else {
      waUri = Uri.parse('whatsapp://send?text=$encodedText');
    }

    try {
      if (await canLaunchUrl(waUri)) {
        return await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Abaikan jika native URL scheme gagal, fallback ke HTTPS
    }

    // Fallback via HTTPS WhatsApp API
    Uri fallbackUri;
    if (cleanPhone.isNotEmpty) {
      fallbackUri = Uri.parse('https://api.whatsapp.com/send/?phone=$cleanPhone&text=$encodedText');
    } else {
      fallbackUri = Uri.parse('https://api.whatsapp.com/send/?text=$encodedText');
    }

    return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }
}
