import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/customer_debt/data/customer_debt_repository.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';
import 'package:dpos/features/customer_debt/state/customer_debt_providers.dart';

class PayDebtDialog extends ConsumerStatefulWidget {
  final CustomerDebt debt;

  const PayDebtDialog({super.key, required this.debt});

  @override
  ConsumerState<PayDebtDialog> createState() => _PayDebtDialogState();
}

class _PayDebtDialogState extends ConsumerState<PayDebtDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isLoading = false;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double get remainingAmount => widget.debt.remainingAmount;

  double get amountToPay {
    return RupiahInputHelper.parseToDouble(_amountController.text);
  }

  @override
  void initState() {
    super.initState();
    // Default isi lunas pas dengan currency formatting
    _amountController.text = RupiahInputHelper.format(remainingAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pay = amountToPay;
    if (pay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran harus lebih dari Rp 0')),
      );
      return;
    }

    if (pay > remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal pembayaran tidak boleh melebihi sisa tagihan (${_currency.format(remainingAmount)})',
          ),
        ),
      );
      return;
    }

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final outletId = bootstrap?.currentOutlet?.id ?? widget.debt.outletId;
    final activeShift = ref.read(activeShiftProvider).valueOrNull;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerDebtRepositoryProvider);
      await repo.payDebt(
        debtId: widget.debt.id,
        customerId: widget.debt.customerId,
        outletId: outletId,
        shiftId: _paymentMethod == 'cash' ? activeShift?.id : null,
        amountPaid: pay,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      ref.invalidate(customerDebtsProvider);
      ref.invalidate(customersProvider);
      if (_paymentMethod == 'cash') {
        ref.invalidate(shiftLiveTotalsProvider);
      }

      if (mounted) {
        Navigator.pop(context, true);
        final isFull = pay >= remainingAmount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFull
                  ? 'Kasbon telah LUNAS! Pembayaran ${_currency.format(pay)} berhasil dicatat.'
                  : 'Cicilan ${_currency.format(pay)} berhasil dicatat. Sisa: ${_currency.format(remainingAmount - pay)}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat pembayaran: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.debt.customerName ?? 'Pelanggan';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bayar Kasbon / Cicilan',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$customerName • ${widget.debt.invoiceNumber ?? "-"}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Kartu Ringkasan Sisa Hutang
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAL SISA TAGIHAN KASBON',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currency.format(remainingAmount),
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input Nominal Bayar
              Text(
                'Nominal Pembayaran *',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: const [
                  RupiahTextInputFormatter(allowEmpty: false),
                ],
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Shortcut Bayar Pas
              Row(
                children: [
                  ActionChip(
                    label: const Text('Bayar Pas (Lunas)'),
                    backgroundColor: const Color(0xFFDCFCE7),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                    onPressed: () {
                      _amountController.text = RupiahInputHelper.format(remainingAmount);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  if (remainingAmount > 50000)
                    ActionChip(
                      label: const Text('Rp 50.000'),
                      labelStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      onPressed: () {
                        _amountController.text = RupiahInputHelper.format(50000);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Metode Bayar
              Text(
                'Metode Pembayaran *',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _methodTile('cash', '💵 Tunai (Kasir)', 'Masuk kas laci'),
                  const SizedBox(width: 8),
                  _methodTile('transfer', '🏦 Transfer', 'Rekening bank'),
                  const SizedBox(width: 8),
                  _methodTile('qris', '📱 QRIS', 'E-Wallet'),
                ],
              ),
              const SizedBox(height: 16),

              // Catatan
              Text(
                'Catatan (Opsional)',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Misal: Dititipkan lewat anaknya',
                  hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
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
                        backgroundColor: const Color(0xFF10B981),
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
                              'Konfirmasi Pembayaran',
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

  Widget _methodTile(String key, String label, String subtitle) {
    final isSelected = _paymentMethod == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF166534) : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: isSelected ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
