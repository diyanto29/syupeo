import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/product_catalog/data/master_catalog_repository.dart';

/// BottomSheet cepat untuk mendaftarkan barang baru langsung dari barcode
/// tanpa meninggalkan layar transaksi atau stok.
class QuickAddProductSheet extends ConsumerStatefulWidget {
  const QuickAddProductSheet({
    super.key,
    required this.barcode,
    this.onProductCreated,
  });

  final String barcode;
  final void Function(MenuItem newItem)? onProductCreated;

  static Future<MenuItem?> show(
    BuildContext context, {
    required String barcode,
    void Function(MenuItem newItem)? onProductCreated,
  }) {
    return showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddProductSheet(
        barcode: barcode,
        onProductCreated: onProductCreated,
      ),
    );
  }

  @override
  ConsumerState<QuickAddProductSheet> createState() =>
      _QuickAddProductSheetState();
}

class _QuickAddProductSheetState extends ConsumerState<QuickAddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');

  String? _selectedCategoryId;
  bool _isCheckingMasterCatalog = true;
  bool _isFoundInMasterCatalog = false;
  String? _matchedCategoryName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkMasterCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _checkMasterCatalog() async {
    try {
      final page = await ref
          .read(masterCatalogRepositoryProvider)
          .searchSamples(widget.barcode.trim());

      if (!mounted) return;

      if (page.items.isNotEmpty) {
        final match = page.items.firstWhere(
          (item) => item.barcode?.trim() == widget.barcode.trim(),
          orElse: () => page.items.first,
        );

        setState(() {
          _isFoundInMasterCatalog = true;
          _nameController.text = match.name;
          _matchedCategoryName = match.category;
          if (match.unit != null && match.unit!.trim().isNotEmpty) {
            _unitController.text = match.unit!.trim();
          }
          if (match.sellingPrice > 0) {
            _priceController.text =
                RupiahInputHelper.format(match.sellingPrice.round());
          } else if (match.basePrice > 0) {
            _priceController.text =
                RupiahInputHelper.format(match.basePrice.round());
          }
        });
      }
    } catch (_) {
      // Abaikan jika offline / master catalog tidak ada
    } finally {
      if (mounted) {
        setState(() => _isCheckingMasterCatalog = false);
      }
    }
  }

  Future<void> _saveAndSubmit(List<MenuCatalogCategory> categories) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Bisnis tidak ditemukan')),
      );
      return;
    }

    // Tentukan kategori:
    var targetCategoryId = _selectedCategoryId;
    if (targetCategoryId == null && categories.isNotEmpty) {
      // Coba cocokkan dengan kategori dari master catalog jika ada
      if (_matchedCategoryName != null && _matchedCategoryName!.isNotEmpty) {
        final matchedCat = categories.where((c) =>
            c.name.toLowerCase() == _matchedCategoryName!.toLowerCase()).firstOrNull;
        targetCategoryId = matchedCat?.id ?? categories.first.id;
      } else {
        targetCategoryId = categories.first.id;
      }
    }

    if (targetCategoryId == null) {
      // Buat kategori default 'Umum' jika belum ada kategori sama sekali
      try {
        final newCategory = MenuCatalogCategory(
          id: const Uuid().v4(),
          businessId: businessId,
          name: 'Umum',
          visualIndex: 0,
        );
        await ref
            .read(menuCategoriesProvider.notifier)
            .upsertCategory(newCategory);
        targetCategoryId = newCategory.id;
      } catch (_) {}
    }

    final sellingPrice =
        RupiahInputHelper.parseToDouble(_priceController.text);

    setState(() => _isSaving = true);

    try {
      final newItem = MenuItem(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        categoryId: targetCategoryId ?? 'default',
        businessId: businessId,
        price: sellingPrice,
        unit: _unitController.text.trim().isEmpty
            ? 'pcs'
            : _unitController.text.trim(),
        barcode: widget.barcode.trim(),
        sku: widget.barcode.trim(),
        stockAvailable: true,
        trackStockQuantity: false,
      );

      // Simpan ke database via Riverpod provider
      await ref.read(menuItemsProvider.notifier).upsertItem(
            newItem,
            inventoryNote: 'Didaftarkan cepat melalui scan barcode kasir.',
          );

      if (!mounted) return;

      widget.onProductCreated?.call(newItem);
      Navigator.of(context).pop(newItem);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan produk: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final categories = ref.watch(menuCategoriesProvider).value ?? [];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Info Barcode
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: Color(0xFFFF7A00),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftarkan Produk Baru',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Barcode: ${widget.barcode}',
                            style: GoogleFonts.firaCode(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Indikator Master Catalog
                if (_isCheckingMasterCatalog)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Mencari data di Master Catalog...',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isFoundInMasterCatalog) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✨ Ditemukan di Master Catalog',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              Text(
                                'Nama & harga referensi terisi otomatis.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Input Nama Barang
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isFoundInMasterCatalog,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk *',
                    hintText: 'Misal: Teh Botol Sosro 250ml',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama produk wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Baris Harga Jual & Satuan
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual *',
                          hintText: '0',
                          prefixText: 'Rp ',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          const RupiahTextInputFormatter(allowEmpty: true),
                        ],
                        validator: (value) {
                          final parsed =
                              RupiahInputHelper.parseToDouble(value ?? '');
                          if (parsed <= 0) {
                            return 'Harga jual wajib > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _unitController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Satuan',
                          hintText: 'pcs',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pilihan Kategori
                if (categories.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId ?? categories.first.id,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategoryId = val);
                    },
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 12),

                // Tombol Simpan & Masukkan ke Keranjang
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _saveAndSubmit(categories),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan & Masuk Keranjang',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
