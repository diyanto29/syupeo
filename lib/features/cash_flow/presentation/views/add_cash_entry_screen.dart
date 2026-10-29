import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/cash_flow/data/cash_flow_repository.dart';
import 'package:dpos/features/cash_flow/domain/cash_flow_models.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';

class AddCashEntryScreen extends ConsumerStatefulWidget {
  final CashFlowType initialType;
  final String? shiftId;

  const AddCashEntryScreen({
    super.key,
    this.initialType = CashFlowType.cashOut,
    this.shiftId,
  });

  @override
  ConsumerState<AddCashEntryScreen> createState() => _AddCashEntryScreenState();
}

class _AddCashEntryScreenState extends ConsumerState<AddCashEntryScreen> {
  late CashFlowType _selectedType;
  late String _selectedCategory;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _paymentSource = 'cash';
  bool _isLoading = false;
  bool _isCustomCategory = false;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final List<double> _quickAmounts = [
    10000,
    20000,
    50000,
    100000,
    200000,
    500000,
  ];

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
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onTypeChanged(CashFlowType type) {
    setState(() {
      _selectedType = type;
      _isCustomCategory = false;
      _selectedCategory = type == CashFlowType.cashOut
          ? CashCategories.expenseCategories.first
          : CashCategories.incomeCategories.first;
    });
  }

  void _setQuickAmount(double amt) {
    _amountController.text = _currency.format(amt).replaceAll('Rp', '').trim();
    setState(() {});
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(rawAmount) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal uang yang valid')),
      );
      return;
    }

    final category = _isCustomCategory && _customCategoryController.text.trim().isNotEmpty
        ? _customCategoryController.text.trim()
        : _selectedCategory;

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
        category: category,
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
              '${_selectedType.label} ${_currency.format(amount)} ($category) berhasil dicatat',
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
          SnackBar(content: Text('Gagal mencatat mutasi kas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOut = _selectedType == CashFlowType.cashOut;
    final primaryColor = isOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final lightBg = isOut ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final borderTint = isOut ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);

    final categories = isOut
        ? CashCategories.expenseCategories
        : CashCategories.incomeCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isOut ? 'Catat Kas Keluar (Beban)' : 'Catat Kas Masuk',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Type Selector (Kas Keluar vs Kas Masuk)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _onTypeChanged(CashFlowType.cashOut),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isOut ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isOut
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 16,
                                      color: isOut ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Kas Keluar (Beban)',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: isOut ? FontWeight.w800 : FontWeight.w600,
                                        color: isOut ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _onTypeChanged(CashFlowType.cashIn),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !isOut ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !isOut
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 16,
                                      color: !isOut ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Kas Masuk',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: !isOut ? FontWeight.w800 : FontWeight.w600,
                                        color: !isOut ? const Color(0xFF16A34A) : const Color(0xFF64748B),
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
                    const SizedBox(height: 24),

                    // Amount Input Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderTint),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nominal Uang (${_selectedType.label})',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Rp ',
                                style: GoogleFonts.manrope(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                  style: GoogleFonts.manrope(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: GoogleFonts.manrope(
                                      color: const Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (clean.isEmpty) {
                                      _amountController.text = '';
                                    } else {
                                      final numVal = int.parse(clean);
                                      final formatted = NumberFormat.decimalPattern('id').format(numVal);
                                      _amountController.value = TextEditingValue(
                                        text: formatted,
                                        selection: TextSelection.collapsed(offset: formatted.length),
                                      );
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // Quick Amount Chips
                          Text(
                            'Pilihan Cepat:',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickAmounts.map((amt) {
                              return ActionChip(
                                label: Text(
                                  _currency.format(amt).replaceAll(',00', ''),
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                onPressed: () => _setQuickAmount(amt),
                                backgroundColor: const Color(0xFFF1F5F9),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Kategori Section
                    Text(
                      'Pilih Kategori',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...categories.map((cat) {
                          final isSelected = !_isCustomCategory && _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _isCustomCategory = false;
                                  _selectedCategory = cat;
                                });
                              }
                            },
                            labelStyle: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? primaryColor : const Color(0xFF475569),
                            ),
                            selectedColor: lightBg,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }),
                        ChoiceChip(
                          label: const Text('+ Kategori Lain'),
                          selected: _isCustomCategory,
                          onSelected: (selected) {
                            setState(() => _isCustomCategory = selected);
                          },
                          labelStyle: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: _isCustomCategory ? FontWeight.w800 : FontWeight.w600,
                            color: _isCustomCategory ? primaryColor : const Color(0xFF475569),
                          ),
                          selectedColor: lightBg,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _isCustomCategory ? primaryColor : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),

                    if (_isCustomCategory) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customCategoryController,
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Ketik nama kategori kustom...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Sumber Kas / Payment Source
                    Text(
                      'Sumber Uang Kas',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(
                                'Laci Kasir (Cash)',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              value: 'cash',
                              groupValue: _paymentSource,
                              activeColor: primaryColor,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              onChanged: (val) => setState(() => _paymentSource = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(
                                'Petty Cash Toko',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              value: 'petty_cash',
                              groupValue: _paymentSource,
                              activeColor: primaryColor,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              onChanged: (val) => setState(() => _paymentSource = val!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Catatan / Keterangan
                    Text(
                      'Catatan / Keperluan (Opsional)',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: GoogleFonts.manrope(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: isOut
                            ? 'Contoh: Beli es batu kristal 2 bungkus, bensin motor kurir...'
                            : 'Contoh: Uang kembalian dari owner, kas modal tambahan...',
                        hintStyle: GoogleFonts.manrope(color: const Color(0xFF94A3B8), fontSize: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Submit Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isOut ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOut ? 'Simpan Kas Keluar' : 'Simpan Kas Masuk',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
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
    );
  }
}
