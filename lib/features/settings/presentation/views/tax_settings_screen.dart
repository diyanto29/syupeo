import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _taxNameController;
  late final TextEditingController _taxRateController;
  late final TextEditingController _simulationController;

  bool _taxEnabled = false;
  bool _isTaxInclusive = false;
  bool _applyToAllOutlets = false;
  bool _isSubmitting = false;
  String? _selectedOutletId;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _taxNameController = TextEditingController(text: 'PB1');
    _taxRateController = TextEditingController(text: '10');
    _simulationController = TextEditingController(text: '100000');

    // Populate from active outlet if available
    final bootstrap = ref.read(homeBootstrapProvider).value;
    final outlet = bootstrap?.currentOutlet;
    if (outlet != null) {
      _selectedOutletId = outlet.id;
      _loadOutletSettings(outlet);
    }
  }

  void _loadOutletSettings(Outlet outlet) {
    _taxEnabled = outlet.taxEnabled;
    _taxNameController.text = outlet.taxName.isNotEmpty ? outlet.taxName : 'PB1';
    _taxRateController.text = (outlet.taxRate % 1 == 0)
        ? outlet.taxRate.toInt().toString()
        : outlet.taxRate.toString();
    _isTaxInclusive = outlet.isTaxInclusive;
  }

  @override
  void dispose() {
    _taxNameController.dispose();
    _taxRateController.dispose();
    _simulationController.dispose();
    super.dispose();
  }

  double get _currentTaxRate {
    final parsed = double.tryParse(_taxRateController.text.replaceAll(',', '.'));
    return parsed ?? 0.0;
  }

  double get _simulationSubtotal {
    final clean = _simulationController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 100000.0;
  }

  double get _simulatedTaxAmount {
    if (!_taxEnabled || _currentTaxRate <= 0 || _simulationSubtotal <= 0) return 0.0;
    if (_isTaxInclusive) {
      return (_simulationSubtotal - (_simulationSubtotal / (1 + (_currentTaxRate / 100))))
          .roundToDouble();
    } else {
      return (_simulationSubtotal * (_currentTaxRate / 100)).roundToDouble();
    }
  }

  double get _simulatedGrandTotal {
    if (!_taxEnabled || _isTaxInclusive) {
      return _simulationSubtotal;
    }
    return _simulationSubtotal + _simulatedTaxAmount;
  }

  void _applyPreset({
    required String name,
    required double rate,
    required bool inclusive,
  }) {
    setState(() {
      _taxEnabled = true;
      _taxNameController.text = name;
      _taxRateController.text =
          (rate % 1 == 0) ? rate.toInt().toString() : rate.toString();
      _isTaxInclusive = inclusive;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final business = bootstrap?.business;
    if (business == null) return;

    final targetOutletId = _selectedOutletId ?? bootstrap?.currentOutletId;
    if (targetOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet terlebih dahulu.')),
      );
      return;
    }

    final rate = double.tryParse(_taxRateController.text.replaceAll(',', '.')) ?? 0.0;
    final name = _taxNameController.text.trim().isEmpty ? 'PB1' : _taxNameController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (_applyToAllOutlets && bootstrap?.outlets != null && bootstrap!.outlets.length > 1) {
        for (final o in bootstrap.outlets) {
          await authRepo.updateOutletTaxSettings(
            outletId: o.id,
            businessId: business.id,
            taxEnabled: _taxEnabled,
            taxName: name,
            taxRate: rate,
            isTaxInclusive: _isTaxInclusive,
          );
        }
      } else {
        await authRepo.updateOutletTaxSettings(
          outletId: targetOutletId,
          businessId: business.id,
          taxEnabled: _taxEnabled,
          taxName: name,
          taxRate: rate,
          isTaxInclusive: _isTaxInclusive,
        );
      }

      ref.invalidate(homeBootstrapProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _taxEnabled
                ? 'Pengaturan pajak "$name ($rate%)" berhasil disimpan.'
                : 'Pajak transaksi berhasil dinonaktifkan.',
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengaturan: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 760;
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final outlets = bootstrap?.outlets ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isWide
          ? AppTabletHeader(
              title: const Text('Pengaturan Pajak (PB1 / PPN)'),
              badge: const AppTabletBadge(label: 'Pajak & Biaya'),
              actions: [
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _saveSettings,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Simpan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
              title: const Text('Pengaturan Pajak (PB1/PPN)'),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Simpan',
                  onPressed: _isSubmitting ? null : _saveSettings,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                ),
              ],
            ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 40 : 20,
            vertical: 24,
          ),
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFF97316),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sistem Pajak Otomatis',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pajak akan otomatis dihitung saat kasir membuat transaksi dan tercetak rapi di struk belanja pelanggan.',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Outlet Selector (if multiple outlets)
            if (outlets.length > 1) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PILIH OUTLET',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedOutletId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        items: outlets
                            .map(
                              (o) => DropdownMenuItem(
                                value: o.id,
                                child: Text(o.name, style: const TextStyle(fontSize: 14)),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedOutletId = val);
                          final found = outlets.firstWhere((o) => o.id == val);
                          _loadOutletSettings(found);
                        },
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: _applyToAllOutlets,
                        onChanged: (v) => setState(() => _applyToAllOutlets = v ?? false),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Terapkan pengaturan pajak ini ke semua outlet',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Main Tax Toggle Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: _taxEnabled ? const Color(0xFFF97316).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                  width: _taxEnabled ? 1.5 : 1,
                ),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _taxEnabled
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.percent_rounded,
                            color: _taxEnabled
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF94A3B8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aktifkan Pajak Transaksi',
                                style: GoogleFonts.manrope(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                _taxEnabled
                                    ? 'Pajak aktif dan dihitung di transaksi kasir.'
                                    : 'Pajak dinonaktifkan (tidak ada potongan pajak).',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _taxEnabled,
                          activeColor: const Color(0xFFEA580C),
                          onChanged: (val) => setState(() => _taxEnabled = val),
                        ),
                      ],
                    ),

                    if (_taxEnabled) ...[
                      const Divider(height: 28, color: Color(0xFFF1F5F9)),

                      // Quick Preset Chips
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PILIHAN PRESET PAJAK POPULER',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPresetChip(
                            label: 'PB1 Resto/Kafe 10%',
                            sublabel: 'Eksklusif',
                            onTap: () => _applyPreset(
                              name: 'PB1',
                              rate: 10,
                              inclusive: false,
                            ),
                          ),
                          _buildPresetChip(
                            label: 'PPN Nasional 11%',
                            sublabel: 'Eksklusif',
                            onTap: () => _applyPreset(
                              name: 'PPN',
                              rate: 11,
                              inclusive: false,
                            ),
                          ),
                          _buildPresetChip(
                            label: 'PPN 12%',
                            sublabel: 'Eksklusif',
                            onTap: () => _applyPreset(
                              name: 'PPN',
                              rate: 12,
                              inclusive: false,
                            ),
                          ),
                          _buildPresetChip(
                            label: 'Retail Inklusif 11%',
                            sublabel: 'Harga termasuk PPN',
                            onTap: () => _applyPreset(
                              name: 'PPN',
                              rate: 11,
                              inclusive: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Tax Name Field
                      TextFormField(
                        controller: _taxNameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Pajak pada Struk',
                          hintText: 'Contoh: PB1, PPN, Pajak Restoran',
                          prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: 'Nama yang tertera pada invoice dan kertas struk pelanggan',
                        ),
                        validator: (val) {
                          if (_taxEnabled && (val ?? '').trim().isEmpty) {
                            return 'Nama pajak tidak boleh kosong';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Tax Rate Field
                      TextFormField(
                        controller: _taxRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Tarif Pajak (%)',
                          hintText: 'Contoh: 10 atau 11',
                          prefixIcon: const Icon(Icons.percent_rounded, size: 20),
                          suffixText: '%',
                          suffixStyle: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: 'Persentase tarif yang dikenakan (contoh: 10% untuk PB1)',
                        ),
                        validator: (val) {
                          if (!_taxEnabled) return null;
                          final clean = (val ?? '').replaceAll(',', '.');
                          final parsed = double.tryParse(clean);
                          if (parsed == null || parsed <= 0) {
                            return 'Masukkan tarif pajak yang valid (> 0%)';
                          }
                          if (parsed > 100) {
                            return 'Tarif pajak maksimal 100%';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),

                      // Tax Scheme (Inclusive vs Exclusive)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SKEMA PERHITUNGAN PAJAK',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Exclusive Radio Card
                      _buildSchemeCard(
                        title: 'Harga Belum Termasuk Pajak (Eksklusif)',
                        description:
                            'Pajak ditambahkan di atas subtotal saat checkout kasir. Cocok untuk restoran, kafe, dan warung makan.',
                        formula: 'Contoh: Subtotal Rp 100.000 + PB1 10% = Total Rp 110.000',
                        isSelected: !_isTaxInclusive,
                        onTap: () => setState(() => _isTaxInclusive = false),
                      ),
                      const SizedBox(height: 10),

                      // Inclusive Radio Card
                      _buildSchemeCard(
                        title: 'Harga Sudah Termasuk Pajak (Inklusif)',
                        description:
                            'Harga jual produk di katalog sudah termasuk pajak. Cocok untuk toko retail, supermarket, dan butik.',
                        formula: 'Contoh: Total Rp 100.000 (di dalamnya ada PPN 11% Rp 9.910)',
                        isSelected: _isTaxInclusive,
                        onTap: () => setState(() => _isTaxInclusive = true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Calculation Simulation Card
            if (_taxEnabled) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                color: const Color(0xFFF1F5F9),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calculate_outlined,
                            color: Color(0xFF0F172A),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Simulasi Perhitungan Nyata',
                            style: GoogleFonts.manrope(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Simulasi Subtotal:',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextFormField(
                                controller: _simulationController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  prefixText: 'Rp ',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _simRow(
                              'Subtotal Produk',
                              _currency.format(_simulationSubtotal),
                            ),
                            const SizedBox(height: 6),
                            _simRow(
                              '${_taxNameController.text.trim().isEmpty ? "Pajak" : _taxNameController.text.trim()} (${_currentTaxRate.toStringAsFixed(_currentTaxRate % 1 == 0 ? 0 : 1)}%)',
                              _isTaxInclusive
                                  ? '${_currency.format(_simulatedTaxAmount)} (Termasuk)'
                                  : '+ ${_currency.format(_simulatedTaxAmount)}',
                              isHighlight: true,
                              highlightColor: const Color(0xFFEA580C),
                            ),
                            const Divider(height: 16, color: Color(0xFFE2E8F0)),
                            _simRow(
                              'Total Bayar Pelanggan',
                              _currency.format(_simulatedGrandTotal),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _saveSettings,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Menyimpan...' : 'Simpan Pengaturan Pajak',
                  style: GoogleFonts.manrope(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemeCard({
    required String title,
    required String description,
    required String formula,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formula,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFC2410C)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isBold ? 15 : 12.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: highlightColor ??
                (isBold ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}
