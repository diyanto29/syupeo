import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/reports/data/whatsapp_report_service.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  final CashShift shift;
  final Map<String, double> totals;

  const CloseShiftDialog({
    super.key,
    required this.shift,
    required this.totals,
  });

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _sendWhatsAppReport = true;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double get startingCash => widget.shift.startingCash;
  double get salesCash => widget.totals['totalSalesCash'] ?? 0;
  double get cashIn => widget.totals['totalCashIn'] ?? 0;
  double get cashOut => widget.totals['totalCashOut'] ?? 0;
  double get expectedCash => startingCash + salesCash + cashIn - cashOut;

  double get actualCash {
    final raw = _actualCashController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0;
  }

  double get difference => actualCash - expectedCash;

  @override
  void initState() {
    super.initState();
    // Default actual diisi dengan expected agar memudahkan kasir jika uang pas
    _actualCashController.text = expectedCash.toInt().toString();
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(cashFlowRepositoryProvider);
      final closedShift = await repo.closeShift(
        shift: widget.shift,
        actualCash: actualCash,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      ref.invalidate(activeShiftProvider);
      ref.invalidate(shiftLiveTotalsProvider);
      ref.invalidate(todayCashEntriesProvider);
      ref.invalidate(shiftHistoryProvider);

      if (mounted) {
        Navigator.pop(context, closedShift);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Shift kasir berhasil ditutup. ${difference == 0 ? "Kas laci pas." : "Selisih: ${_currency.format(difference)}"}',
            ),
            backgroundColor: difference < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          ),
        );

        if (_sendWhatsAppReport) {
          final bootstrap = ref.read(homeBootstrapProvider).value;
          final businessName = bootstrap?.business?.name ?? 'Toko';
          final outletName = bootstrap?.currentOutlet?.name;
          final ownerPhone = bootstrap?.business?.phone;

          final shiftMsg = StringBuffer();
          shiftMsg.writeln('📊 *LAPORAN TUTUP SHIFT KASIR - SYUPEO*');
          shiftMsg.writeln('🏪 *Toko:* $businessName${outletName != null ? " ($outletName)" : ""}');
          shiftMsg.writeln('📅 *Tanggal:* ${DateFormat("EEEE, d MMMM yyyy", "id_ID").format(DateTime.now())}');
          shiftMsg.writeln('⏰ *Waktu Tutup:* ${DateFormat("HH:mm", "id_ID").format(DateTime.now())} WIB');
          shiftMsg.writeln('👤 *Kasir Bertugas:* ${widget.shift.cashierName}');
          shiftMsg.writeln('━━━━━━━━━━━━━━━━━━━━');
          shiftMsg.writeln('💵 *REKONSILIASI KAS LACI:*');
          shiftMsg.writeln('• Modal Awal Kas: ${_currency.format(startingCash)}');
          shiftMsg.writeln('• Penjualan Tunai: +${_currency.format(salesCash)}');
          if (cashIn > 0) shiftMsg.writeln('• Kas Masuk Lain: +${_currency.format(cashIn)}');
          if (cashOut > 0) shiftMsg.writeln('• Kas Keluar (Beban): -${_currency.format(cashOut)}');
          shiftMsg.writeln('• Uang Seharusnya di Laci: *${_currency.format(expectedCash)}*');
          shiftMsg.writeln('• Uang Fisik Aktual di Laci: *${_currency.format(actualCash)}*');
          if (difference == 0) {
            shiftMsg.writeln('• *Status Selisih:* ✅ *PAS (Tidak Ada Selisih)*');
          } else if (difference > 0) {
            shiftMsg.writeln('• *Status Selisih:* 🟢 *LEBIH ${_currency.format(difference)}*');
          } else {
            shiftMsg.writeln('• *Status Selisih:* 🔴 *KURANG ${_currency.format(difference.abs())}*');
          }
          if (_notesController.text.trim().isNotEmpty) {
            shiftMsg.writeln('• Catatan: "${_notesController.text.trim()}"');
          }
          shiftMsg.writeln('━━━━━━━━━━━━━━━━━━━━');
          shiftMsg.writeln('🔗 *Portal Backoffice:* https://app.mudahkan.online/merchant/reports');

          WhatsAppReportService.shareToWhatsApp(
            message: shiftMsg.toString(),
            targetPhone: ownerPhone,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menutup shift: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tutup Shift Kasir',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Hitung uang fisik di laci kasir untuk rekonsiliasi',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Rincian Perhitungan Sistem
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow('Modal Awal (Kas Awal)', _currency.format(startingCash), false),
                    const SizedBox(height: 8),
                    _buildRow('Penjualan Tunai (+)', _currency.format(salesCash), false, color: const Color(0xFF16A34A)),
                    const SizedBox(height: 8),
                    _buildRow('Kas Masuk Lain (+)', _currency.format(cashIn), false, color: const Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    _buildRow('Kas Keluar / Pengeluaran (-)', '-${_currency.format(cashOut)}', false, color: const Color(0xFFDC2626)),
                    const Divider(height: 20, color: Color(0xFFCBD5E1)),
                    _buildRow(
                      'Uang Kas Sistem (Harus Ada)',
                      _currency.format(expectedCash),
                      true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input Uang Fisik Riil
              Text(
                'Uang Fisik Riil di Laci (Dihitung Kasir)',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _actualCashController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2563EB),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status Selisih
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: difference == 0
                      ? const Color(0xFFF0FDF4)
                      : difference > 0
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: difference == 0
                        ? const Color(0xFFBBF7D0)
                        : difference > 0
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      difference == 0
                          ? Icons.check_circle_rounded
                          : difference > 0
                              ? Icons.arrow_upward_rounded
                              : Icons.warning_rounded,
                      size: 20,
                      color: difference == 0
                          ? const Color(0xFF16A34A)
                          : difference > 0
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            difference == 0
                                ? 'Uang Kas Sesuai (Pas)'
                                : difference > 0
                                    ? 'Uang Kas Lebih'
                                    : 'Uang Kas Kurang (Selisih)',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: difference == 0
                                  ? const Color(0xFF16A34A)
                                  : difference > 0
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            difference == 0
                                ? 'Tidak ada selisih uang di laci kasir.'
                                : 'Selisih: ${_currency.format(difference)}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Catatan
              Text(
                'Catatan Penutupan Shift (Opsional)',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Misal: Uang fisik pas, diserahkan ke kasir shift sore',
                  hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              // Checkbox Kirim Rekap WA
              InkWell(
                onTap: () => setState(() => _sendWhatsAppReport = !_sendWhatsAppReport),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _sendWhatsAppReport,
                        onChanged: (val) => setState(() => _sendWhatsAppReport = val ?? true),
                        activeColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Kirim Laporan Shift ke WhatsApp Pemilik',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Konfirmasi Tutup Shift',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isBold, {Color? color}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: color ?? (isBold ? const Color(0xFF0F172A) : const Color(0xFF334155)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
