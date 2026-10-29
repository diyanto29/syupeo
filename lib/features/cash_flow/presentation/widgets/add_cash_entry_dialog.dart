import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';

class AddCashEntryDialog extends ConsumerStatefulWidget {
  final CashFlowType initialType;
  final String? shiftId;

  const AddCashEntryDialog({
    super.key,
    this.initialType = CashFlowType.cashOut,
    this.shiftId,
  });

  @override
  ConsumerState<AddCashEntryDialog> createState() => _AddCashEntryDialogState();
}

class _AddCashEntryDialogState extends ConsumerState<AddCashEntryDialog> {
  late CashFlowType _selectedType;
  late String _selectedCategory;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentSource = 'cash';
  bool _isLoading = false;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final List<double> _quickAmounts = [10000, 20000, 50000, 100000, 200000];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedCategory = _selectedType == CashFlowType.cashOut
        ? CashCategories.expenseCategories.first
        : CashCategories.incomeCategories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(CashFlowType type) {
    setState(() {
      _selectedType = type;
      _selectedCategory = type == CashFlowType.cashOut
          ? CashCategories.expenseCategories.first
          : CashCategories.incomeCategories.first;
    });
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(rawAmount) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid')),
      );
      return;
    }

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;
    final outletId = bootstrap?.currentOutlet?.id;
    final cashierName = bootstrap?.profile?.fullName ?? 'Kasir';

    if (businessId == null || outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data bisnis atau outlet tidak ditemukan')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(cashFlowRepositoryProvider);
      await repo.addCashEntry(
        businessId: businessId,
        outletId: outletId,
        shiftId: widget.shiftId,
        type: _selectedType,
        category: _selectedCategory,
        amount: amount,
        paymentSource: _paymentSource,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        cashierName: cashierName,
      );

      ref.invalidate(shiftLiveTotalsProvider);
      ref.invalidate(todayCashEntriesProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedType.label} ${_currency.format(amount)} ($_selectedCategory) berhasil dicatat',
            ),
            backgroundColor: _selectedType == CashFlowType.cashIn
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencatat mutasi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _selectedType == CashFlowType.cashOut
        ? CashCategories.expenseCategories
        : CashCategories.incomeCategories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Catat Mutasi Kas',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Pencatatan uang masuk atau keluar di luar transaksi kasir',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),

              // Segmented Switcher Type (Kas Keluar vs Kas Masuk)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged(CashFlowType.cashOut),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedType == CashFlowType.cashOut
                                ? const Color(0xFFDC2626)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: _selectedType == CashFlowType.cashOut ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kas Keluar (Pengeluaran)',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedType == CashFlowType.cashOut ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged(CashFlowType.cashIn),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedType == CashFlowType.cashIn
                                ? const Color(0xFF16A34A)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: _selectedType == CashFlowType.cashIn ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kas Masuk',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedType == CashFlowType.cashIn ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Nominal Input
              Text(
                'Nominal (Rp)',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
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
                    color: _selectedType == CashFlowType.cashIn
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                  hintText: '0',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Amount Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amt) {
                  return InkWell(
                    onTap: () {
                      _amountController.text = amt.toInt().toString();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _currency.format(amt),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Category Selector
              Text(
                'Kategori',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: _selectedType == CashFlowType.cashIn
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    backgroundColor: const Color(0xFFF8FAFC),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (_selectedType == CashFlowType.cashIn ? const Color(0xFF15803D) : const Color(0xFFB91C1C))
                          : const Color(0xFF64748B),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? (_selectedType == CashFlowType.cashIn ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5))
                          : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Sumber Uang (Laci vs Bank)
              Text(
                'Sumber Dana',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'cash',
                      groupValue: _paymentSource,
                      onChanged: (v) => setState(() => _paymentSource = v!),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Uang Laci Kasir',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'bank_transfer',
                      groupValue: _paymentSource,
                      onChanged: (v) => setState(() => _paymentSource = v!),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Transfer Bank',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Catatan / Keterangan
              Text(
                'Keterangan / Keperluan',
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
                  hintText: 'Misal: Beli es batu 2 kantong, plastik kresek besar',
                  hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == CashFlowType.cashIn
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
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
                              'Simpan ${_selectedType.label}',
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
}
