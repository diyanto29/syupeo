import 'dart:async';
import 'dart:math' as math;

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/product_image_compression_helper.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/product_catalog/data/master_catalog_repository.dart';
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
  final List<_VariantDraft> _variantDrafts = [];
  final List<_TieredPriceDraft> _tieredPriceDrafts = [];
  final List<_PackageComponentDraft> _packageComponentDrafts = [];

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
    _stockController.text = item.trackStockQuantity
        ? '${item.stockQuantity}'
        : '0';
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
        _PackageComponentDraft(
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
      builder: (_) => AiProductPhotoSheet(
        initialProductName: productName,
      ),
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

  void _updateStock(int delta) {
    if (!_trackStockQuantity) {
      return;
    }

    final currentStock = int.tryParse(_stockController.text) ?? 0;
    final nextStock = math.max(0, currentStock + delta);
    setState(() => _stockController.text = '$nextStock');
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
      if (variant.useMainPrice && variant.priceController.text != mainPriceText) {
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

  _VariantDraft _createVariantDraft({
    String? variantId,
    String? name,
    String? priceText,
    String? sku,
    String? barcode,
    bool stockAvailable = true,
    bool useMainPrice = false,
  }) {
    return _VariantDraft(
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

  _TieredPriceDraft _createTieredPriceDraft({
    String? id,
    int? minQuantity,
    String? priceText,
  }) {
    return _TieredPriceDraft(
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

  void _removeTieredPriceDraft(_TieredPriceDraft draft) {
    setState(() {
      _tieredPriceDrafts.removeWhere((item) => item.localId == draft.localId);
      draft.dispose();
    });
  }

  void _removeVariantDraft(_VariantDraft draft) {
    setState(() {
      _variantDrafts.removeWhere((item) => item.localId == draft.localId);
      draft.dispose();
      if (_variantDrafts.isEmpty) {
        _hasVariants = false;
      }
    });
  }

  void _removePackageComponentDraft(_PackageComponentDraft draft) {
    setState(() {
      _packageComponentDrafts.removeWhere((item) => item.localId == draft.localId);
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
          content: Text('Belum ada menu lain yang dapat dijadikan komponen paket.'),
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
      builder: (sheetContext) => _SelectPackageComponentSheet(
        items: availableItems,
        alreadySelectedIds: _packageComponentDrafts.map((e) => e.componentMenuItemId).toSet(),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _packageComponentDrafts.add(
          _PackageComponentDraft(
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

    final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
    final currentOutletId = ref
        .read(homeBootstrapProvider)
        .value
        ?.currentOutlet
        ?.id;
    if (businessId == null) {
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
        ? int.tryParse(_stockController.text.trim()) ?? 0
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
              id: draft.variantId ?? _uuid.v4(),
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
      builder: (context) => _MasterCatalogPickerSheet(initialQuery: initialQuery),
    );

    if (!mounted || selectedSample == null) {
      return;
    }

    _applyMasterCatalogSample(selectedSample, categories);
  }

  Future<void> _scanAndSearchMasterCatalog(
    List<MenuCatalogCategory> categories,
  ) async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(
        title: 'Scan Barcode Master Catalog',
      ),
    );

    if (code != null && code.trim().isNotEmpty && mounted) {
      await _openMasterCatalogPicker(categories, initialQuery: code.trim());
    }
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
    final featureGate = ref.watch(featureGateProvider);

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
        body: const _ProductFormAccessDenied(),
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
              badge: const AppTabletBadge(label: 'Mangga POS'),
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
                    if (featureGate.isEnabled('master_catalog')) ...[
                      _SectionCard(
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
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _scanAndSearchMasterCatalog(categories),
                                    icon: const Icon(Icons.qr_code_scanner_rounded),
                                    label: const Text('Scan Barcode Master'),
                                  ),
                                ],
                              ),
                            if (_selectedSample != null) ...[
                              const SizedBox(height: 16),
                              _SelectedSampleCard(
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
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _scanAndSearchMasterCatalog(categories),
                                    icon: const Icon(Icons.qr_code_scanner_rounded),
                                    label: const Text('Scan Barcode Lain'),
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
                    _SectionCard(
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
                    _SectionCard(
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
                                      topTrailing: const AppBadgeText('INTERNAL ONLY'),
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
                                      topTrailing: const AppBadgeText('INTERNAL ONLY'),
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
                                    content: Text('Simpan produk terlebih dahulu sebelum mengatur komposisi resep bahan baku.'),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, color: Color(0xFFDC2626), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
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
                                      Text(
                                        'Lacak Stok',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Aktifkan jika produk ini perlu stok kuantitas.',
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
                                  value: _trackStockQuantity,
                                  onChanged: (value) {
                                    setState(() {
                                      _trackStockQuantity = value;
                                      if (!value) {
                                        _stockController.text = '0';
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _trackStockQuantity ? 1 : 0.45,
                            child: IgnorePointer(
                              ignoring: !_trackStockQuantity,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AppTextInput(
                                      label: 'Stok Awal',
                                      controller: _stockController,
                                      enabled: _trackStockQuantity,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) => setState(() {}),
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
                                      validator: (value) {
                                        if (!_trackStockQuantity) {
                                          return null;
                                        }
                                        if (value == null || value.isEmpty) {
                                          return 'Stok awal wajib diisi.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: scheme.secondaryContainer
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          _StepperButton(
                                            icon: Icons.remove,
                                            enabled: _trackStockQuantity,
                                            onTap: () => _updateStock(-1),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 24,
                                            color: scheme.outline.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                          _StepperButton(
                                            icon: Icons.add,
                                            enabled: _trackStockQuantity,
                                            onTap: () => _updateStock(1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!_trackStockQuantity) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Toggle aktif diperlukan kalau kamu ingin isi stok awal produk.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.64),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
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
                              _VariantEditorCard(
                                index: i + 1,
                                draft: _variantDrafts[i],
                                onChanged: () => setState(() {}),
                                onToggleMainPrice: () =>
                                    _toggleVariantMainPrice(i),
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
                    _SectionCard(
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
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Gabungkan beberapa menu jadi satu paket penjualan (misal: Ayam + Nasi + Es Teh).',
                                      style: theme.textTheme.bodyMedium?.copyWith(
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
                              _PackageComponentEditorCard(
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
                    _SectionCard(
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
                            _TieredPriceEditorCard(
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
      painter: _DashedRoundedRectPainter(
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

class _ProductFormAccessDenied extends StatelessWidget {
  const _ProductFormAccessDenied();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 52,
                  color: scheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Akses produk terbatas',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tambah dan edit produk hanya bisa dilakukan oleh Owner atau Admin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.66),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantDraft {
  _VariantDraft({
    required this.localId,
    this.variantId,
    required String name,
    required String priceText,
    required String sku,
    required String barcode,
    required this.stockAvailable,
    this.useMainPrice = false,
  }) : nameController = TextEditingController(text: name),
       priceController = TextEditingController(text: priceText),
       skuController = TextEditingController(text: sku),
       barcodeController = TextEditingController(text: barcode);

  final String localId;
  final String? variantId;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController skuController;
  final TextEditingController barcodeController;
  bool stockAvailable;
  bool useMainPrice;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    skuController.dispose();
    barcodeController.dispose();
  }
}

class _TieredPriceDraft {
  _TieredPriceDraft({
    required this.localId,
    this.id,
    int minQuantity = 1,
    required String priceText,
  }) : minQuantityController = TextEditingController(text: '$minQuantity'),
       priceController = TextEditingController(text: priceText);

  final String localId;
  final String? id;
  final TextEditingController minQuantityController;
  final TextEditingController priceController;

  void dispose() {
    minQuantityController.dispose();
    priceController.dispose();
  }
}

class _VariantEditorCard extends StatelessWidget {
  const _VariantEditorCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onToggleMainPrice,
    this.onRemove,
  });

  final int index;
  final _VariantDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onToggleMainPrice;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Varian $index',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Hapus varian',
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                ),
            ],
          ),
          const SizedBox(height: 6),
          AppTextInput(
            label: 'Nama Varian',
            isRequired: true,
            controller: draft.nameController,
            textInputAction: TextInputAction.next,
            hintText: 'e.g. Kecil, Sedang, Besar',
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama varian wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AppCurrencyInput(
            label: 'Harga Varian',
            isRequired: true,
            topTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sama Harga Utama',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: draft.useMainPrice,
                    onChanged: (v) => onToggleMainPrice(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            controller: draft.priceController,
            enabled: !draft.useMainPrice,
            prefixBadge: 'IDR',
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Harga varian wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextInput(
                  label: 'SKU (Opsional)',
                  controller: draft.skuController,
                  textInputAction: TextInputAction.next,
                  hintText: 'SKU varian',
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextInput(
                  label: 'Barcode (Opsional)',
                  controller: draft.barcodeController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  hintText: 'Barcode varian',
                  onChanged: (_) => onChanged(),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFFF98B35),
                      size: 20,
                    ),
                    onPressed: () =>
                        (context
                                .findAncestorStateOfType<
                                  _AddProductScreenState
                                >())
                            ?._scanVariantBarcode(index),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Variant Available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: draft.stockAvailable,
                  onChanged: (value) {
                    draft.stockAvailable = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TieredPriceEditorCard extends StatelessWidget {
  const _TieredPriceEditorCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _TieredPriceDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: scheme.primary.withValues(alpha: 0.1),
                child: Text(
                  '$index',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tier $index',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: scheme.error,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: draft.minQuantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Min. Qty',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: draft.priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahTextInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Harga per Unit',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageComponentDraft {
  _PackageComponentDraft({
    required this.localId,
    this.id,
    required this.componentMenuItemId,
    required this.componentName,
    required this.componentPrice,
    int initialQuantity = 1,
  }) : quantityController = TextEditingController(text: '$initialQuantity');

  final String localId;
  final String? id;
  final String componentMenuItemId;
  final String componentName;
  final double componentPrice;
  final TextEditingController quantityController;

  void dispose() {
    quantityController.dispose();
  }
}

class _PackageComponentEditorCard extends StatelessWidget {
  const _PackageComponentEditorCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _PackageComponentDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primary.withValues(alpha: 0.1),
            child: Text(
              '$index',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.componentName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  RupiahInputHelper.format(draft.componentPrice),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: draft.quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Qty',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: scheme.error,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SelectPackageComponentSheet extends StatefulWidget {
  const _SelectPackageComponentSheet({
    required this.items,
    required this.alreadySelectedIds,
  });

  final List<MenuItem> items;
  final Set<String> alreadySelectedIds;

  @override
  State<_SelectPackageComponentSheet> createState() =>
      _SelectPackageComponentSheetState();
}

class _SelectPackageComponentSheetState
    extends State<_SelectPackageComponentSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final filteredItems = widget.items.where((item) {
      if (_query.isEmpty) return true;
      return item.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pilih Komponen Paket',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama produk...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _query = val.trim()),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 350),
            child: filteredItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Tidak ada produk ditemukan.'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected =
                          widget.alreadySelectedIds.contains(item.id);

                      return ListTile(
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? scheme.onSurface.withValues(alpha: 0.4)
                                : scheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          RupiahInputHelper.format(item.price),
                          style: TextStyle(
                            color: isSelected
                                ? scheme.onSurface.withValues(alpha: 0.3)
                                : scheme.primary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Text(
                                'Sudah Ada',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline_rounded),
                        enabled: !isSelected,
                        onTap: isSelected
                            ? null
                            : () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens?.raisedSurface ?? scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (tokens?.tintedShadow ?? scheme.shadow).withValues(
              alpha: 0.08,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

class _SelectedSampleCard extends StatelessWidget {
  const _SelectedSampleCard({
    required this.sample,
    required this.matchedCategory,
  });

  final MasterCatalogItem sample;
  final MenuCatalogCategory? matchedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: scheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sample.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (sample.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sample.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sample.barcode != null && sample.barcode!.trim().isNotEmpty)
                _InfoChip(label: 'Barcode ${sample.barcode}'),
              if (sample.basePrice > 0)
                _InfoChip(
                  label:
                      'Modal ${RupiahInputHelper.formatWithPrefix(sample.basePrice)}',
                ),
              if (sample.sellingPrice > 0)
                _InfoChip(
                  label:
                      'Jual ${RupiahInputHelper.formatWithPrefix(sample.sellingPrice)}',
                ),
            ],
          ),
          if (sample.category != null &&
              sample.category!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              matchedCategory != null
                  ? 'Kategori master cocok ke: ${matchedCategory!.name}'
                  : 'Kategori master: ${sample.category} belum cocok otomatis ke kategori bisnismu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: matchedCategory != null ? scheme.primary : scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}


class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 44,
        height: 56,
        child: Icon(
          icon,
          color: enabled
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.4;
    const radius = 28.0;
    const dashWidth = 6.0;
    const dashGap = 5.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final currentDash = math.min(dashWidth, metric.length - distance);
        canvas.drawPath(
          metric.extractPath(distance, distance + currentDash),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MasterCatalogPickerSheet extends ConsumerStatefulWidget {
  const _MasterCatalogPickerSheet({this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<_MasterCatalogPickerSheet> createState() =>
      _MasterCatalogPickerSheetState();
}

class _MasterCatalogPickerSheetState
    extends ConsumerState<_MasterCatalogPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  final List<MasterCatalogItem> _items = [];
  String _searchQuery = '';
  Object? _error;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _exactBarcodeMatched = false;
  int _generalOffset = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _searchQuery = widget.initialQuery!.trim();
    }
    _scrollController.addListener(_handleScroll);
    scheduleMicrotask(() => _loadSamples(reset: true));
  }

  Future<void> _scanBarcodeForSearch() async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(
        title: 'Scan Barcode Master Catalog',
      ),
    );

    if (code != null && code.trim().isNotEmpty && mounted) {
      _searchController.text = code.trim();
      _debounce?.cancel();
      setState(() => _searchQuery = code.trim());
      _loadSamples(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value.trim());
      _loadSamples(reset: true);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadSamples();
    }
  }

  Future<void> _loadSamples({bool reset = false}) async {
    if (_isLoadingMore) {
      return;
    }

    final requestVersion = ++_requestVersion;
    final startingOffset = reset ? 0 : _generalOffset;

    setState(() {
      _error = null;
      if (reset) {
        _isInitialLoading = true;
        _items.clear();
        _hasMore = true;
        _generalOffset = 0;
        _exactBarcodeMatched = false;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final page = await ref
          .read(masterCatalogRepositoryProvider)
          .searchSamples(_searchQuery, generalOffset: startingOffset);

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      final mergedItems = reset
          ? page.items
          : _mergeWithoutDuplicates(_items, page.items);

      setState(() {
        _items
          ..clear()
          ..addAll(mergedItems);
        _generalOffset = page.nextGeneralOffset;
        _hasMore = page.hasMore;
        _exactBarcodeMatched = reset && page.exactBarcodeMatched;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  List<MasterCatalogItem> _mergeWithoutDuplicates(
    List<MasterCatalogItem> existing,
    List<MasterCatalogItem> incoming,
  ) {
    final existingIds = existing.map((item) => item.id).toSet();
    return [
      ...existing,
      ...incoming.where((item) => !existingIds.contains(item.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        child: SizedBox(
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Master Catalog',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cari berdasarkan nama, barcode, brand, atau kategori.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                  _handleSearchChanged(value);
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama, barcode, atau brand...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _handleSearchChanged('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      IconButton(
                        tooltip: 'Scan Barcode',
                        onPressed: _scanBarcodeForSearch,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_exactBarcodeMatched) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Exact barcode match ditaruh paling atas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(child: _buildResults(theme, scheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, ColorScheme scheme) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Gagal memuat master catalog: $_error'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _loadSamples(reset: true),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return _EmptyMasterCatalogState(query: _searchQuery);
    }

    final itemCount = _items.length + (_isLoadingMore || _hasMore ? 1 : 0);
    return ListView.separated(
      controller: _scrollController,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : Text(
                      'Scroll lagi untuk memuat sample berikutnya',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
            ),
          );
        }

        final item = _items[index];
        return Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).pop(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.content_copy_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.64),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (item.barcode != null &&
                                item.barcode!.trim().isNotEmpty)
                              _InfoChip(label: 'Barcode ${item.barcode}'),
                            if (item.basePrice > 0)
                              _InfoChip(
                                label: 'Modal Rp ${item.basePrice.round()}',
                              ),
                            if (item.sellingPrice > 0)
                              _InfoChip(
                                label: 'Jual Rp ${item.sellingPrice.round()}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: scheme.outline),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyMasterCatalogState extends StatelessWidget {
  const _EmptyMasterCatalogState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: scheme.outline.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'Belum ada sample yang tampil.'
                : 'Sample tidak ditemukan.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query.isEmpty
                ? 'Coba cari produk berdasarkan nama atau barcode.'
                : 'Coba kata kunci lain atau barcode yang lebih spesifik.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}
