import 'dart:async';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/product_image_compression_helper.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/product_catalog/domain/master_catalog_item.dart';
import 'package:dpos/core/widgets/barcode_scanner_sheet.dart';
import 'package:dpos/core/widgets/app_form_field.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/ai_product_photo_sheet.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/variant_editor_card.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/tiered_price_editor_card.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/package_component_editor_card.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/add_product_form_components.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/master_catalog_picker_sheet.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.initialItem});

  final MenuItem? initialItem;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  static const _defaultUnit = 'pcs';
  static const _defaultVariantNamePrefix = 'Varian';

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  final _productNameController = TextEditingController();
  final _unitController = TextEditingController(text: _defaultUnit);
  final _costPriceController = TextEditingController(
    text: RupiahInputHelper.format(0),
  );
  final _sellingPriceController = TextEditingController(
    text: RupiahInputHelper.format(0),
  );
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  final List<VariantDraft> _variantDrafts = [];
  final List<TieredPriceDraft> _tieredPriceDrafts = [];
  final List<PackageComponentDraft> _packageComponentDrafts = [];

  MasterCatalogItem? _selectedSample;
  String? _selectedCategoryId;
  bool _isProductNameSyncedFromSample = false;
  bool _isUnitSyncedFromSample = false;
  bool _isCostPriceSyncedFromSample = false;
  bool _isSellingPriceSyncedFromSample = false;
  bool _isBarcodeSyncedFromSample = false;
  bool _isCategorySyncedFromSample = false;
  bool _hasVariants = false;
  bool _isPackage = false;
  bool _trackStockQuantity = false;
  bool _isPickingPhoto = false;
  bool _isSaving = false;
  CompressedProductImage? _selectedPhoto;
  String? _initialRemoteImageUrl;
  String? _currentRemoteImageUrl;

  bool get _isEditMode => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    _sellingPriceController.addListener(_syncVariantPrices);
    _prefillInitialItem();
  }

  @override
  void dispose() {
    _sellingPriceController.removeListener(_syncVariantPrices);
    for (final variant in _variantDrafts) {
      variant.dispose();
    }
    for (final tiered in _tieredPriceDrafts) {
      tiered.dispose();
    }
    for (final pkg in _packageComponentDrafts) {
      pkg.dispose();
    }
    _productNameController.dispose();
    _unitController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefillInitialItem() {
    final item = widget.initialItem;
    if (item == null) {
      return;
    }

    _productNameController.text = item.name;
    _unitController.text = item.displayUnit;
    _costPriceController.text = RupiahInputHelper.format(item.recipeCost);
    _sellingPriceController.text = RupiahInputHelper.format(item.price);
    _barcodeController.text = item.barcode ?? '';
    _stockController.text = item.trackStockQuantity ? item.formattedStock : '0';
    _descriptionController.text = item.description;
    _selectedCategoryId = item.categoryId;
    _trackStockQuantity = item.trackStockQuantity;
    _hasVariants = item.variants.isNotEmpty;
    _isPackage = item.isPackage;
    _initialRemoteImageUrl =
        item.imageUrl == null || item.imageUrl!.trim().isEmpty
        ? null
        : item.imageUrl!.trim();
    _currentRemoteImageUrl = _initialRemoteImageUrl;

    for (final variant in item.variants) {
      _variantDrafts.add(
        _createVariantDraft(
          variantId: variant.id,
          name: variant.name,
          priceText: RupiahInputHelper.format(variant.price),
          sku: variant.sku,
          barcode: variant.barcode,
          stockAvailable: variant.stockAvailable,
        ),
      );
    }

    for (final tiered in item.tieredPrices) {
      _tieredPriceDrafts.add(
        _createTieredPriceDraft(
          id: tiered.id,
          minQuantity: tiered.minQuantity,
          priceText: RupiahInputHelper.format(tiered.price),
        ),
      );
    }

    for (final pkgItem in item.packageItems) {
      _packageComponentDrafts.add(
        PackageComponentDraft(
          localId: _uuid.v4(),
          id: pkgItem.id,
          componentMenuItemId: pkgItem.componentMenuItemId,
          componentName: pkgItem.componentName ?? 'Item',
          componentPrice: pkgItem.componentPrice ?? 0,
          initialQuantity: pkgItem.quantity,
        ),
      );
    }
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) {
      return;
    }

    setState(() => _isPickingPhoto = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) {
        return;
      }

      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ukuran foto asli maksimal 20MB. Pilih file yang lebih kecil.',
            ),
          ),
        );
        return;
      }

      final bytes = await file.readAsBytes();
      final compressedPhoto = ProductImageCompressionHelper.compress(
        bytes: bytes,
        originalFileName: file.name,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPhoto = compressedPhoto;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $error')));
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _openAiPhotoGenerator() async {
    final productName = _productNameController.text.trim();

    final Uint8List? imageBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiProductPhotoSheet(initialProductName: productName),
    );

    if (imageBytes != null && mounted) {
      final compressedPhoto = ProductImageCompressionHelper.compress(
        bytes: imageBytes,
        originalFileName:
            'ai_product_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      setState(() {
        _selectedPhoto = compressedPhoto;
        _currentRemoteImageUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('Foto produk AI berhasil diterapkan!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scanBarcode() async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(title: 'Scan Produk Barcode'),
    );

    if (code != null && mounted) {
      setState(() {
        _barcodeController.text = code;
        _isBarcodeSyncedFromSample = false;
      });
    }
  }

  void _scanVariantBarcode(int index) async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(title: 'Scan Varian Barcode'),
    );

    if (code != null && mounted) {
      setState(() {
        _variantDrafts[index - 1].barcodeController.text = code;
      });
    }
  }

  void _removePhoto() {
    if (_selectedPhoto != null) {
      setState(() {
        _selectedPhoto = null;
      });
      return;
    }

    if (_currentRemoteImageUrl == null) {
      return;
    }

    setState(() {
      _currentRemoteImageUrl = null;
    });
  }

  void _ensureVariantDraftExists() {
    if (_variantDrafts.isNotEmpty) {
      return;
    }

    final draft = _createVariantDraft(
      name: '$_defaultVariantNamePrefix 1',
      priceText: _sellingPriceController.text.trim(),
    );
    _variantDrafts.add(draft);
    setState(() {});
  }

  void _syncVariantPrices() {
    final mainPriceText = _sellingPriceController.text;
    bool changed = false;
    for (final variant in _variantDrafts) {
      if (variant.useMainPrice &&
          variant.priceController.text != mainPriceText) {
        variant.priceController.text = mainPriceText;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  void _toggleVariantMainPrice(int index) {
    if (index < 0 || index >= _variantDrafts.length) return;
    final variant = _variantDrafts[index];
    setState(() {
      variant.useMainPrice = !variant.useMainPrice;
      if (variant.useMainPrice) {
        variant.priceController.text = _sellingPriceController.text;
      }
    });
  }

  VariantDraft _createVariantDraft({
    String? variantId,
    String? name,
    String? priceText,
    String? sku,
    String? barcode,
    bool stockAvailable = true,
    bool useMainPrice = false,
  }) {
    return VariantDraft(
      localId: _uuid.v4(),
      variantId: variantId,
      name: name ?? '',
      priceText: priceText ?? '',
      sku: sku ?? '',
      barcode: barcode ?? '',
      stockAvailable: stockAvailable,
      useMainPrice: useMainPrice,
    );
  }

  void _addVariantDraft() {
    setState(() {
      final nextIndex = _variantDrafts.length + 1;
      _variantDrafts.add(
        _createVariantDraft(
          name: '$_defaultVariantNamePrefix $nextIndex',
          priceText: _sellingPriceController.text.trim(),
        ),
      );
    });
  }

  TieredPriceDraft _createTieredPriceDraft({
    String? id,
    int? minQuantity,
    String? priceText,
  }) {
    return TieredPriceDraft(
      localId: _uuid.v4(),
      id: id,
      minQuantity: minQuantity ?? 1,
      priceText: priceText ?? '',
    );
  }

  void _addTieredPriceDraft() {
    setState(() {
      _tieredPriceDrafts.add(_createTieredPriceDraft());
    });
  }

  void _removeTieredPriceDraft(TieredPriceDraft draft) {
    setState(() {
      _tieredPriceDrafts.removeWhere((item) => item.localId == draft.localId);
      draft.dispose();
    });
  }

  void _removeVariantDraft(VariantDraft draft) {
    setState(() {
      _variantDrafts.removeWhere((item) => item.localId == draft.localId);
      draft.dispose();
      if (_variantDrafts.isEmpty) {
        _hasVariants = false;
      }
    });
  }

  void _removePackageComponentDraft(PackageComponentDraft draft) {
    setState(() {
      _packageComponentDrafts.removeWhere(
        (item) => item.localId == draft.localId,
      );
      draft.dispose();
    });
  }

  double get _totalPackageComponentsPrice {
    double total = 0;
    for (final draft in _packageComponentDrafts) {
      final qty = int.tryParse(draft.quantityController.text.trim()) ?? 1;
      total += draft.componentPrice * qty;
    }
    return total;
  }

  Future<void> _openSelectPackageComponentModal() async {
    final allItems = ref.read(menuItemsProvider).value ?? [];
    final currentItemId = widget.initialItem?.id;
    final availableItems = allItems.where((item) {
      if (currentItemId != null && item.id == currentItemId) return false;
      if (item.isPackage) return false;
      return true;
    }).toList();

    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada menu lain yang dapat dijadikan komponen paket.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SelectPackageComponentSheet(
        items: availableItems,
        alreadySelectedIds: _packageComponentDrafts
            .map((e) => e.componentMenuItemId)
            .toSet(),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _packageComponentDrafts.add(
          PackageComponentDraft(
            localId: _uuid.v4(),
            componentMenuItemId: selected.id,
            componentName: selected.name,
            componentPrice: selected.price,
            initialQuantity: 1,
          ),
        );
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_isSaving) {
      return;
    }

    if (!ref.read(canManageCatalogProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya Owner dan Admin yang bisa menyimpan produk.'),
        ),
      );
      return;
    }

    if (!_isEditMode) {
      final menuItems = ref.read(menuItemsProvider).value ?? [];
      final featureGate = ref.read(featureGateProvider);
      final maxProducts = featureGate.getLimit('max_products');

      if (menuItems.length >= maxProducts) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limit Produk Tercapai'),
            content: Text(
              'Batas produk untuk paket Anda adalah $maxProducts. '
              'Silakan upgrade ke paket Pro untuk menambah lebih banyak produk.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pushNamed(RouteNames.businessAccountManagement);
                },
                child: const Text('Upgrade Sekarang'),
              ),
            ],
          ),
        );
        return;
      }
    }

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final businessId =
        ref.read(homeBootstrapProvider).value?.business?.id ??
        widget.initialItem?.businessId;
    final currentOutletId = ref
        .read(homeBootstrapProvider)
        .value
        ?.currentOutlet
        ?.id;
    if (businessId == null || businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data bisnis belum siap. Coba tunggu sebentar lalu simpan lagi.',
          ),
        ),
      );
      return;
    }

    if (_trackStockQuantity && currentOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih outlet aktif dulu sebelum menyimpan stok produk.',
          ),
        ),
      );
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category wajib dipilih.')));
      return;
    }

    if (_hasVariants && _variantDrafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 varian atau nonaktifkan variant.'),
        ),
      );
      return;
    }

    if (_isPackage && _packageComponentDrafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu paket wajib memiliki minimal 1 item komponen.'),
        ),
      );
      return;
    }

    final initialItem = widget.initialItem;
    final itemId = initialItem?.id ?? _uuid.v4();
    final parsedSellingPrice = RupiahInputHelper.parseToDouble(
      _sellingPriceController.text,
    );
    final parsedCostPrice = RupiahInputHelper.parseToDouble(
      _costPriceController.text,
    );
    final parsedStock = _trackStockQuantity
        ? num.tryParse(_stockController.text.trim()) ?? 0
        : 0;
    final effectiveStockQuantity = _trackStockQuantity
        ? parsedStock
        : (initialItem?.trackStockQuantity == true
              ? initialItem!.stockQuantity
              : 0);

    final variants = _hasVariants
        ? _variantDrafts.map((draft) {
            final name = draft.nameController.text.trim();
            final price = RupiahInputHelper.parseToDouble(
              draft.priceController.text,
            );
            if (name.isEmpty) {
              throw StateError('Semua varian wajib punya nama.');
            }
            return MenuItemVariant(
              id:
                  (draft.variantId != null &&
                      draft.variantId!.trim().isNotEmpty)
                  ? draft.variantId!.trim()
                  : _uuid.v4(),
              menuItemId: itemId,
              name: name,
              price: price,
              businessId: businessId,
              sku: draft.skuController.text.trim().isEmpty
                  ? null
                  : draft.skuController.text.trim(),
              barcode: draft.barcodeController.text.trim().isEmpty
                  ? null
                  : draft.barcodeController.text.trim(),
              stockAvailable: draft.stockAvailable,
            );
          }).toList()
        : const <MenuItemVariant>[];

    final packageItems = _isPackage
        ? _packageComponentDrafts.map((draft) {
            final qty = int.tryParse(draft.quantityController.text.trim()) ?? 1;
            return MenuPackageItem(
              id: draft.id ?? _uuid.v4(),
              packageMenuItemId: itemId,
              componentMenuItemId: draft.componentMenuItemId,
              quantity: qty > 0 ? qty : 1,
              componentName: draft.componentName,
              componentPrice: draft.componentPrice,
            );
          }).toList()
        : const <MenuPackageItem>[];

    setState(() => _isSaving = true);
    UploadedMenuItemImage? uploadedPhoto;
    final previousImageUrl = _initialRemoteImageUrl;
    try {
      if (_selectedPhoto != null) {
        uploadedPhoto = await ref
            .read(menuRepositoryProvider)
            .uploadProductImage(
              businessId: businessId,
              menuItemId: itemId,
              bytes: _selectedPhoto!.bytes,
              fileName: _selectedPhoto!.fileName,
              contentType: _selectedPhoto!.contentType,
            );
      }

      final nextImageUrl = uploadedPhoto?.publicUrl ?? _currentRemoteImageUrl;

      final item = MenuItem(
        id: itemId,
        name: _productNameController.text.trim(),
        categoryId: _selectedCategoryId!,
        businessId: businessId,
        price: parsedSellingPrice,
        unit: _unitController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: nextImageUrl,
        stockAvailable: initialItem?.stockAvailable ?? true,
        trackStockQuantity: _trackStockQuantity,
        stockQuantity: effectiveStockQuantity,
        ingredients: initialItem?.ingredients ?? const [],
        recipeCost: parsedCostPrice,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        variants: variants,
        isPackage: _isPackage,
        packageItems: packageItems,
        tieredPrices: _tieredPriceDrafts.map((draft) {
          final minQty = int.tryParse(draft.minQuantityController.text) ?? 1;
          final price = RupiahInputHelper.parseToDouble(
            draft.priceController.text,
          );
          return TieredPrice(id: draft.id, minQuantity: minQty, price: price);
        }).toList(),
      );

      await ref
          .read(menuItemsProvider.notifier)
          .upsertItem(
            item,
            previousItem: initialItem,
            inventoryNote: initialItem == null
                ? 'Stok awal dicatat saat produk dibuat.'
                : 'Penyesuaian stok dari form edit produk.',
          );
      if (!mounted) {
        return;
      }

      final menuState = ref.read(menuItemsProvider);
      if (menuState.hasError) {
        final error = menuState.error;
        if (uploadedPhoto != null) {
          try {
            await ref
                .read(menuRepositoryProvider)
                .deleteProductImage(uploadedPhoto.objectPath);
          } catch (_) {}
        }
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan produk: $error')),
        );
        return;
      }

      if (previousImageUrl != null && previousImageUrl != nextImageUrl) {
        final oldObjectPath = ref
            .read(menuRepositoryProvider)
            .extractProductImageObjectPath(previousImageUrl);
        if (oldObjectPath != null) {
          try {
            await ref
                .read(menuRepositoryProvider)
                .deleteProductImage(oldObjectPath);
          } catch (_) {}
        }
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (error) {
      if (uploadedPhoto != null) {
        try {
          await ref
              .read(menuRepositoryProvider)
              .deleteProductImage(uploadedPhoto.objectPath);
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan produk: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openMasterCatalogPicker(
    List<MenuCatalogCategory> categories, {
    String? initialQuery,
  }) async {
    final selectedSample = await showModalBottomSheet<MasterCatalogItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) =>
          MasterCatalogPickerSheet(initialQuery: initialQuery),
    );

    if (!mounted || selectedSample == null) {
      return;
    }

    _applyMasterCatalogSample(selectedSample, categories);
  }

  void _applyMasterCatalogSample(
    MasterCatalogItem sample,
    List<MenuCatalogCategory> categories,
  ) {
    final previousSample = _selectedSample;
    var copiedCount = 0;

    if (_shouldReplaceTextField(
      controller: _productNameController,
      isSyncedFromSample: _isProductNameSyncedFromSample,
    )) {
      _productNameController.text = sample.name.trim();
      _isProductNameSyncedFromSample = true;
      copiedCount++;
    }

    if (_shouldReplaceTextField(
          controller: _barcodeController,
          isSyncedFromSample: _isBarcodeSyncedFromSample,
        ) &&
        sample.barcode != null &&
        sample.barcode!.trim().isNotEmpty) {
      _barcodeController.text = sample.barcode!.trim();
      _isBarcodeSyncedFromSample = true;
      copiedCount++;
    }

    if (_shouldReplaceUnitField(isSyncedFromSample: _isUnitSyncedFromSample) &&
        sample.unit != null &&
        sample.unit!.trim().isNotEmpty) {
      _unitController.text = sample.unit!.trim();
      _isUnitSyncedFromSample = true;
      copiedCount++;
    }

    if (_shouldReplacePriceField(
          controller: _costPriceController,
          isSyncedFromSample: _isCostPriceSyncedFromSample,
        ) &&
        sample.basePrice > 0) {
      _costPriceController.text = RupiahInputHelper.format(sample.basePrice);
      _isCostPriceSyncedFromSample = true;
      copiedCount++;
    }

    if (_shouldReplacePriceField(
          controller: _sellingPriceController,
          isSyncedFromSample: _isSellingPriceSyncedFromSample,
        ) &&
        sample.sellingPrice > 0) {
      _sellingPriceController.text = RupiahInputHelper.format(
        sample.sellingPrice,
      );
      _isSellingPriceSyncedFromSample = true;
      copiedCount++;
    }

    final matchedCategory = _findMatchingCategory(categories, sample.category);
    if ((_selectedCategoryId == null || _isCategorySyncedFromSample) &&
        matchedCategory != null) {
      _selectedCategoryId = matchedCategory.id;
      _isCategorySyncedFromSample = true;
      copiedCount++;
    }

    setState(() {
      _selectedSample = sample;
    });

    final message = copiedCount > 0
        ? previousSample == null
              ? 'Sample diterapkan. $copiedCount field berhasil diisi.'
              : 'Sample diperbarui. $copiedCount field berhasil disesuaikan.'
        : 'Sample dipilih, tapi tidak ada field yang berubah.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _shouldReplaceTextField({
    required TextEditingController controller,
    required bool isSyncedFromSample,
  }) {
    final current = controller.text.trim();
    return current.isEmpty || isSyncedFromSample;
  }

  bool _shouldReplacePriceField({
    required TextEditingController controller,
    required bool isSyncedFromSample,
  }) {
    final current = RupiahInputHelper.parseToDouble(controller.text);
    return current == 0 || isSyncedFromSample;
  }

  bool _shouldReplaceUnitField({required bool isSyncedFromSample}) {
    final current = _unitController.text.trim();
    return current.isEmpty ||
        current.toLowerCase() == _defaultUnit ||
        isSyncedFromSample;
  }

  MenuCatalogCategory? _findMatchingCategory(
    List<MenuCatalogCategory> categories,
    String? sampleCategory,
  ) {
    if (sampleCategory == null || sampleCategory.trim().isEmpty) {
      return null;
    }

    final normalizedSample = _normalizeCategory(sampleCategory);
    for (final category in categories) {
      if (_normalizeCategory(category.name) == normalizedSample) {
        return category;
      }
    }
    return null;
  }

  String _normalizeCategory(String value) {
    return value.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final contentWidth = screenWidth >= 900 ? 780.0 : 680.0;
    final horizontalPadding = screenWidth >= 600 ? 24.0 : 16.0;
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final canManageProducts = ref.watch(canManageCatalogProvider);

    if (bootstrapAsync.isLoading && bootstrapAsync.value == null) {
      return Scaffold(
        backgroundColor: tokens?.baseSurface ?? scheme.surface,
        drawer: const AppOwnerDrawer(),
        appBar: AppBar(
          leadingWidth: isTablet ? AppTabletLeading.width : null,
          leading: isTablet ? const AppTabletLeading() : null,
          title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!canManageProducts) {
      return Scaffold(
        backgroundColor: tokens?.baseSurface ?? scheme.surface,
        drawer: const AppOwnerDrawer(),
        appBar: AppBar(
          leadingWidth: isTablet ? AppTabletLeading.width : null,
          leading: isTablet ? const AppTabletLeading() : null,
          title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
        ),
        body: const ProductFormAccessDenied(),
      );
    }

    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final categories = categoriesAsync.value ?? const [];
    final selectedCategoryId =
        categories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: Text(_isEditMode ? 'Edit Produk' : 'Tambah Produk Baru'),
              badge: const AppTabletBadge(label: 'Syupeo'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'Simpan' : '+ Simpan Produk',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            )
          : AppBar(
              title: Text(_isEditMode ? 'Edit Produk' : 'Tambah Produk'),
              centerTitle: false,
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Update' : 'Save',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPhotoPickerCard(theme, scheme),
                    const SizedBox(height: 20),

                    if (!_isEditMode) ...[
                      SectionCard(
                        title: 'Use Master Catalog Sample',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih sample produk dari master catalog supaya nama, barcode, dan harga referensi bisa terisi otomatis. Field yang sudah kamu isi tidak akan ditimpa.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.72),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_selectedSample == null)
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openMasterCatalogPicker(categories),
                                    icon: const Icon(Icons.search_rounded),
                                    label: const Text('Cari Master Catalog'),
                                  ),
                                ],
                              ),
                            if (_selectedSample != null) ...[
                              SelectedSampleCard(
                                sample: _selectedSample!,
                                matchedCategory: _findMatchingCategory(
                                  categories,
                                  _selectedSample!.category,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openMasterCatalogPicker(categories),
                                    icon: const Icon(Icons.sync_alt_rounded),
                                    label: const Text('Pilih Ulang'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _selectedSample = null);
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Lepas Sample'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    SectionCard(
                      title: 'Basic Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextInput(
                            label: 'Nama Produk',
                            isRequired: true,
                            controller: _productNameController,
                            textInputAction: TextInputAction.next,
                            hintText: 'e.g. Sepatu Sneaker Urban Low-Top',
                            helperText:
                                'Gunakan kombinasi tipe, merek, dan warna pembeda produk.',
                            onChanged: (_) {
                              _isProductNameSyncedFromSample = false;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama produk wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextInput(
                            label: 'Deskripsi Produk',
                            controller: _descriptionController,
                            maxLines: 3,
                            hintText:
                                'e.g. Spesifikasi produk, bahan, atau detail lainnya...',
                          ),
                          const SizedBox(height: 16),
                          AppDropdownField<String>(
                            label: 'Kategori',
                            isRequired: true,
                            value: selectedCategoryId,
                            hintText: 'Pilih Kategori',
                            items: categories
                                .map(
                                  (category) => DropdownMenuItem<String>(
                                    value: category.id,
                                    child: Text(category.name),
                                  ),
                                )
                                .toList(),
                            onChanged: categories.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedCategoryId = value;
                                      _isCategorySyncedFromSample = false;
                                    });
                                  },
                            validator: (value) {
                              if (categoriesAsync.isLoading) {
                                return 'Kategori masih dimuat.';
                              }
                              if (categories.isEmpty) {
                                return 'Belum ada kategori. Tambahkan kategori dulu.';
                              }
                              if (value == null || value.isEmpty) {
                                return 'Kategori wajib dipilih.';
                              }
                              return null;
                            },
                          ),
                          if (categoriesAsync.isLoading) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Memuat kategori...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.64),
                              ),
                            ),
                          ] else if (categories.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada kategori aktif. Buat kategori dulu dari halaman Category Management.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          AppTextInput(
                            label: 'Satuan',
                            isRequired: true,
                            controller: _unitController,
                            textInputAction: TextInputAction.next,
                            hintText: 'e.g. pcs, cup, porsi, slice',
                            onChanged: (_) {
                              _isUnitSyncedFromSample = false;
                              setState(() {});
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Satuan wajib diisi.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: 'Inventaris & Harga',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final useTwoColumns = constraints.maxWidth >= 540;
                              if (!useTwoColumns) {
                                return Column(
                                  children: [
                                    _buildCurrencyField(
                                      label: 'Harga Pokok Modal (HPP)',
                                      topTrailing: const AppBadgeText(
                                        'INTERNAL ONLY',
                                      ),
                                      controller: _costPriceController,
                                      onChanged: (_) {
                                        _isCostPriceSyncedFromSample = false;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildCurrencyField(
                                      label: 'Harga Jual Normal',
                                      controller: _sellingPriceController,
                                      onChanged: (_) {
                                        _isSellingPriceSyncedFromSample = false;
                                      },
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildCurrencyField(
                                      label: 'Harga Pokok Modal (HPP)',
                                      topTrailing: const AppBadgeText(
                                        'INTERNAL ONLY',
                                      ),
                                      controller: _costPriceController,
                                      onChanged: (_) {
                                        _isCostPriceSyncedFromSample = false;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildCurrencyField(
                                      label: 'Harga Jual Normal',
                                      controller: _sellingPriceController,
                                      onChanged: (_) {
                                        _isSellingPriceSyncedFromSample = false;
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              if (_isEditMode && widget.initialItem != null) {
                                context.pushNamed(
                                  RouteNames.recipeManagement,
                                  extra: widget.initialItem,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Simpan produk terlebih dahulu sebelum mengatur komposisi resep bahan baku.',
                                    ),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFCA5A5,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Komposisi Resep & Bahan Baku (BOM)',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF991B1B),
                                          ),
                                        ),
                                        Text(
                                          _isEditMode
                                              ? 'Klik untuk atur takaran bahan baku & hitung HPP otomatis'
                                              : 'Dapat diatur setelah produk pertama kali disimpan',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: const Color(0xFFB91C1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFDC2626),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppTextInput(
                            label: 'SKU & Barcode',
                            controller: _barcodeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            hintText: 'Scan or enter barcode',
                            onChanged: (_) {
                              _isBarcodeSyncedFromSample = false;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Color(0xFFF98B35),
                              ),
                              onPressed: _scanBarcode,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lock_outline_rounded,
                                            size: 16,
                                            color: scheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Lacak Stok Fisik',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Wajib aktif demi integritas inventori dan rantai pasok Syupeo.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.68),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: true,
                                  onChanged: (_) {
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Pelacakan stok fisik wajib selalu aktif pada produk Syupeo.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      size: 18,
                                      color: Color(0xFF0070FC),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Stok Terkunci oleh Sistem Syupeo',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Untuk menjamin pasokan resmi, stok tidak dapat ditambah manual. Stok otomatis bertambah saat pesanan Kulakan / Starter Kit Syupeo diterima.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextInput(
                                  label: 'Kuantitas Stok Fisik Saat Ini',
                                  controller: _stockController,
                                  enabled:
                                      false, // Merchant dilarang ubah stok manual
                                  keyboardType: TextInputType.number,
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      _unitController.text.trim().isEmpty
                                          ? _defaultUnit
                                          : _unitController.text.trim(),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: '',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.layers_outlined,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Variasi Produk',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Size, warna atau bahan',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.68,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _hasVariants,
                                onChanged: (value) {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _hasVariants = value;
                                    if (value) {
                                      _ensureVariantDraftExists();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_hasVariants) ...[
                            Text(
                              'Kelola harga, SKU, barcode, dan status jual per varian.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_variantDrafts.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer.withValues(
                                    alpha: 0.36,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'Tambahkan minimal 1 varian sebelum simpan.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            for (var i = 0; i < _variantDrafts.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              VariantEditorCard(
                                index: i + 1,
                                draft: _variantDrafts[i],
                                onChanged: () => setState(() {}),
                                onToggleMainPrice: () =>
                                    _toggleVariantMainPrice(i),
                                onScanBarcode: () => _scanVariantBarcode(i + 1),
                                onRemove: _variantDrafts.length == 1
                                    ? null
                                    : () => _removeVariantDraft(
                                        _variantDrafts[i],
                                      ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _addVariantDraft,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Tambah Varian'),
                            ),
                          ] else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                'Memungkinkan varian produk untuk mengelola harga, SKU, dan level stok yang berbeda untuk setiap opsi (misalnya, Kecil, Sedang, Besar).',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Menu Paket / Bundling',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jadikan Menu Paket (Combo)',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Gabungkan beberapa menu jadi satu paket penjualan (misal: Ayam + Nasi + Es Teh).',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.68,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isPackage,
                                onChanged: (value) {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _isPackage = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_isPackage) ...[
                            Text(
                              'Pilih komponen menu yang termasuk dalam paket ini. Stok komponen akan terpotong otomatis saat paket terjual.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_packageComponentDrafts.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer.withValues(
                                    alpha: 0.36,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'Tambahkan minimal 1 menu komponen sebelum simpan paket.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            for (
                              var i = 0;
                              i < _packageComponentDrafts.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(height: 10),
                              PackageComponentEditorCard(
                                index: i + 1,
                                draft: _packageComponentDrafts[i],
                                onChanged: () => setState(() {}),
                                onRemove: () => _removePackageComponentDraft(
                                  _packageComponentDrafts[i],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _openSelectPackageComponentModal,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Tambah Komponen Menu'),
                            ),
                            if (_packageComponentDrafts.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Harga Satuan Normal:',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      RupiahInputHelper.format(
                                        _totalPackageComponentsPrice,
                                      ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: scheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                'Aktifkan jika item ini adalah paket/bundling dari beberapa produk yang sudah ada di menu.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: 'Harga Bertingkat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atur harga grosir berdasarkan jumlah minimal pembelian. Misalnya: Beli minimal 10 pcs harga jadi Rp 9.000.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.72),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (
                            var i = 0;
                            i < _tieredPriceDrafts.length;
                            i++
                          ) ...[
                            if (i > 0) const SizedBox(height: 12),
                            TieredPriceEditorCard(
                              index: i + 1,
                              draft: _tieredPriceDrafts[i],
                              onChanged: () => setState(() {}),
                              onRemove: () => _removeTieredPriceDraft(
                                _tieredPriceDrafts[i],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _addTieredPriceDraft,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tambah Harga Bertingkat'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPickerCard(ThemeData theme, ColorScheme scheme) {
    return CustomPaint(
      painter: DashedRoundedRectPainter(
        color: scheme.primary.withValues(alpha: 0.28),
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: _isPickingPhoto ? null : _pickPhoto,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(minHeight: 260),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildPhotoPickerState(theme, scheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatImageSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    return '$bytes B';
  }

  Widget _buildPhotoPickerState(ThemeData theme, ColorScheme scheme) {
    if (_selectedPhoto != null) {
      return Column(
        key: const ValueKey('selected_photo'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.memory(
              _selectedPhoto!.bytes,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedPhoto!.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compressed to ${_formatImageSize(_selectedPhoto!.sizeInBytes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(height: 8),
          _buildPhotoActions(),
        ],
      );
    }

    if (_currentRemoteImageUrl != null) {
      return Column(
        key: const ValueKey('remote_photo'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CachedNetworkImage(
              imageUrl: _currentRemoteImageUrl!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              memCacheWidth: 500,
              placeholder: (context, url) => Container(
                width: double.infinity,
                height: 220,
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => Container(
                width: double.infinity,
                height: 220,
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 42,
                  color: scheme.onSurface.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Foto produk saat ini',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih foto baru kalau ingin mengganti gambar produk.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(height: 8),
          _buildPhotoActions(),
        ],
      );
    }

    return Column(
      key: const ValueKey('empty_photo'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_a_photo_outlined,
            color: scheme.primary,
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _isPickingPhoto ? 'Memilih foto...' : 'Foto Produk',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Unggah dari galeri atau buat foto katalog instan dengan AI.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _isPickingPhoto ? null : _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Pilih Galeri'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _openAiPhotoGenerator,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Buat Foto AI',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _isPickingPhoto ? null : _pickPhoto,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Galeri'),
        ),
        FilledButton.tonalIcon(
          onPressed: _openAiPhotoGenerator,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Foto AI'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange.shade50,
            foregroundColor: Colors.orange.shade900,
          ),
        ),
        TextButton.icon(
          onPressed: _isPickingPhoto ? null : _removePhoto,
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Hapus'),
        ),
      ],
    );
  }

  Widget _buildCurrencyField({
    required String label,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    Widget? topTrailing,
  }) {
    return AppCurrencyInput(
      label: label,
      topTrailing: topTrailing,
      controller: controller,
      prefixBadge: 'IDR',
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label wajib diisi.';
        }
        return null;
      },
    );
  }
}
