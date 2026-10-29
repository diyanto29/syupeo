import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/inventory/domain/ingredient_models.dart';
import 'package:dpos/features/inventory/data/ingredient_repository.dart';

class AddEditIngredientSheet extends ConsumerStatefulWidget {
  const AddEditIngredientSheet({super.key, this.ingredient});

  final Ingredient? ingredient;

  static Future<bool?> show(BuildContext context, {Ingredient? ingredient}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditIngredientSheet(ingredient: ingredient),
    );
  }

  @override
  ConsumerState<AddEditIngredientSheet> createState() => _AddEditIngredientSheetState();
}

class _AddEditIngredientSheetState extends ConsumerState<AddEditIngredientSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _categoryController;
  late final TextEditingController _purchaseUnitController;
  late final TextEditingController _conversionRatioController;
  late final TextEditingController _costPerPurchaseUnitController;
  late final TextEditingController _currentStockController;
  late final TextEditingController _minStockController;

  String _baseUnit = 'gram';
  String _storageType = 'dry';
  bool _isLoading = false;

  final List<String> _baseUnitOptions = ['gram', 'ml', 'pcs', 'slice', 'lembar'];
  final List<String> _categoryOptions = [
    'Kopi & Teh',
    'Susu & Dairy',
    'Sirup & Flavor',
    'Topping',
    'Daging & Seafood',
    'Sayur & Buah',
    'Tepung & Bumbu',
    'Kemasan & Cup',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.ingredient;
    _nameController = TextEditingController(text: item?.name ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
    _categoryController = TextEditingController(text: item?.category ?? 'Kopi & Teh');
    _baseUnit = item?.baseUnit ?? 'gram';
    _purchaseUnitController = TextEditingController(text: item?.purchaseUnit ?? 'kg');
    _conversionRatioController = TextEditingController(
      text: item != null ? item.conversionRatio.toStringAsFixed(0) : '1000',
    );
    final initialCost = item != null ? (item.costPerBaseUnit * item.conversionRatio) : 0.0;
    _costPerPurchaseUnitController = TextEditingController(
      text: RupiahInputHelper.format(initialCost),
    );
    _currentStockController = TextEditingController(
      text: item != null ? item.currentStock.toStringAsFixed(1) : '0',
    );
    _minStockController = TextEditingController(
      text: item != null ? item.minStockAlert.toStringAsFixed(1) : '100',
    );
    _storageType = item?.storageType ?? 'dry';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _purchaseUnitController.dispose();
    _conversionRatioController.dispose();
    _costPerPurchaseUnitController.dispose();
    _currentStockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  double get _calculatedCostPerBaseUnit {
    final purchaseCost = RupiahInputHelper.parseToDouble(_costPerPurchaseUnitController.text);
    final ratio = double.tryParse(_conversionRatioController.text) ?? 1.0;
    if (ratio <= 0) return 0.0;
    return purchaseCost / ratio;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Bisnis tidak ditemukan.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final purchaseCost = RupiahInputHelper.parseToDouble(_costPerPurchaseUnitController.text);
      final ratio = double.tryParse(_conversionRatioController.text) ?? 1000.0;
      final costPerBase = ratio > 0 ? (purchaseCost / ratio) : 0.0;
      final stock = double.tryParse(_currentStockController.text) ?? 0.0;
      final minStock = double.tryParse(_minStockController.text) ?? 0.0;

      final ingredient = Ingredient(
        id: widget.ingredient?.id ?? '',
        businessId: businessId,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        category: _categoryController.text.trim(),
        baseUnit: _baseUnit,
        purchaseUnit: _purchaseUnitController.text.trim(),
        conversionRatio: ratio,
        currentStock: stock,
        minStockAlert: minStock,
        costPerBaseUnit: costPerBase,
        storageType: _storageType,
        isActive: true,
      );

      await ref.read(ingredientRepositoryProvider).saveIngredient(ingredient);
      ref.invalidate(ingredientListProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.ingredient != null
                  ? 'Bahan baku berhasil diperbarui!'
                  : 'Bahan baku baru berhasil disimpan!',
            ),
            backgroundColor: const Color(0xFFFF7A00),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.egg_outlined, color: Colors.amber.shade800, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ingredient != null ? 'Edit Bahan Baku' : 'Tambah Bahan Baku',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Catat bahan dapur & bar untuk hitung HPP resep otomatis.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Nama Bahan
              Text(
                'Nama Bahan Baku *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Misal: Biji Kopi Arabica Gayo, Susu UHT Diamond',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_cafe_outlined, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama bahan wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // Kategori & SKU
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kategori',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _categoryOptions.contains(_categoryController.text)
                              ? _categoryController.text
                              : _categoryOptions.first,
                          items: _categoryOptions
                              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _categoryController.text = val);
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKU / Kode',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _skuController,
                          decoration: InputDecoration(
                            hintText: 'Misal: ING-001',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Satuan Resep & Beli
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konversi Satuan & HPP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Satuan Beli', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.blue.shade900)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _purchaseUnitController,
                                decoration: InputDecoration(
                                  hintText: 'kg / liter',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('=', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Isi Takaran', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.blue.shade900)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _conversionRatioController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: '1000',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Satuan Resep', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.blue.shade900)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _baseUnit,
                                items: _baseUnitOptions
                                    .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _baseUnit = val);
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Harga Beli per ${_purchaseUnitController.text.isEmpty ? "Satuan Beli" : _purchaseUnitController.text}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _costPerPurchaseUnitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RupiahTextInputFormatter(allowEmpty: true)],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimasi Biaya per $_baseUnit:',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          Text(
                            RupiahInputHelper.formatWithPrefix(_calculatedCostPerBaseUnit),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stok Saat Ini & Minimal Alert
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stok Saat Ini ($_baseUnit)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _currentStockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batas Menipis ($_baseUnit)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _minStockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isLoading ? 'Menyimpan...' : 'Simpan Bahan Baku',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
