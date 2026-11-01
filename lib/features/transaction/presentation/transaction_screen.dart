import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:dpos/features/transaction/presentation/widgets/cart_panel.dart';
import 'package:dpos/features/transaction/presentation/widgets/product_grid.dart';
import 'package:dpos/features/transaction/presentation/widgets/product_view_mode_toggle.dart';
import 'package:dpos/features/transaction/presentation/widgets/embedded_scanner.dart';
import 'package:dpos/features/transaction/presentation/widgets/draft_orders_sheet.dart';
import 'package:dpos/features/transaction/presentation/widgets/incoming_orders_sheet.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/widgets/pro_feature_dialog.dart';
import 'package:dpos/features/product_catalog/presentation/widgets/quick_add_product_sheet.dart';
import 'package:dpos/core/widgets/offline_sync_banner.dart';
import 'package:dpos/core/widgets/catalog_sync_indicator.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/services/product_catalog_sync_service.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:intl/intl.dart';

class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _isScanMode = false;
  final MobileScannerController _scannerController = MobileScannerController();
  DateTime? _lastScannedTime;
  String? _lastScannedCode;

  // Hardware barcode scanner buffer
  String _hardwareBarcodeBuffer = '';
  DateTime? _lastKeystrokeTime;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
      final bizId = bootstrap?.business?.id;
      final outletId = bootstrap?.outlets.firstOrNull?.id;
      if (bizId != null) {
        ref.read(productCatalogSyncProvider.notifier).initializeForBusiness(bizId, outletId);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    // F1: Checkout / Open Cart
    if (key == LogicalKeyboardKey.f1) {
      final cart = ref.read(cartProvider);
      if (cart.items.isNotEmpty) {
        context.push(RoutesPath.transactionCart);
        return true;
      }
    }

    // F5: Recall Draft
    if (key == LogicalKeyboardKey.f5) {
      _showDraftOrders(context);
      return true;
    }

    // Hardware / USB Barcode Scanner Detection:
    // Scanners emit characters in extremely rapid succession (< 65ms) followed by Enter
    final char = event.character;
    final now = DateTime.now();

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_hardwareBarcodeBuffer.length >= 3) {
        final code = _hardwareBarcodeBuffer;
        _hardwareBarcodeBuffer = '';
        _processBarcode(code);
        return true;
      }
      _hardwareBarcodeBuffer = '';
      return false;
    }

    if (char != null && char.isNotEmpty && RegExp(r'[0-9a-zA-Z\-_]').hasMatch(char)) {
      if (_lastKeystrokeTime != null && now.difference(_lastKeystrokeTime!).inMilliseconds > 65) {
        _hardwareBarcodeBuffer = char;
      } else {
        _hardwareBarcodeBuffer += char;
      }
      _lastKeystrokeTime = now;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 800;
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (isTablet) {
      return Material(
        color: const Color(0xFFF8FAFC),
        child: Padding(
          padding: widget.padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cartWidth = (constraints.maxWidth * 0.34)
                  .clamp(300.0, 360.0)
                  .toDouble();
              const cartGap = 12.0;

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildProductSide(context, theme, scheme),
                  ),
                  SizedBox(width: cartGap),
                  Container(
                    width: cartWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: const CartPanel(onClose: null, compact: true),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // Mobile layout — floating bar navigates to full-page cart
    return PopScope(
      canPop: !_isScanMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isScanMode) {
          setState(() {
            _isScanMode = false;
          });
        }
      },
      child: Stack(
        children: [
          Padding(
            padding: widget.padding,
            child: _buildProductSide(context, theme, scheme),
          ),
          // Floating cart badge
          if (cart.items.isNotEmpty)
            Positioned(
              bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
              left: 20,
              right: 20,
              child: _CartFloatingBar(
                cart: cart,
                onTap: () => context.push(RoutesPath.transactionCart),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductSide(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final isTablet = MediaQuery.sizeOf(context).width >= 800;

    return Column(
      children: [
        const OfflineSyncBanner(),
        const CatalogSyncIndicator(),
        // Search bar + action chips
        if (isTablet)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildSearchField(),
                ),
                const SizedBox(width: 8),
                _IncomingOrdersActionChip(
                  onTap: () => _showIncomingOrders(context),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.drafts_rounded,
                  label: 'Draft',
                  onTap: () => _showDraftOrders(context),
                ),
                const SizedBox(width: 8),
                _TieredPricingToggleChip(),
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
            child: _buildSearchField(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _IncomingOrdersActionChip(
                    onTap: () => _showIncomingOrders(context),
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.drafts_rounded,
                    label: 'Draft',
                    onTap: () => _showDraftOrders(context),
                  ),
                  const SizedBox(width: 8),
                  _TieredPricingToggleChip(),
                ],
              ),
            ),
          ),
        ],
        if (!_isScanMode) ...[
          Row(
            children: [
              Expanded(
                child: _CategoryChips(
                  selectedCategoryId: _selectedCategoryId,
                  onSelected: (id) => setState(() => _selectedCategoryId = id),
                ),
              ),
              const SizedBox(width: 8),
              const ProductViewModeToggle(),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Product grid or Embedded Scanner
        Expanded(
          child: _isScanMode
              ? EmbeddedScanner(
                  controller: _scannerController,
                  onDetect: _processBarcode,
                  onClose: () {
                    setState(() {
                      _isScanMode = false;
                    });
                  },
                )
              : ProductGrid(
                  searchQuery: _searchQuery,
                  categoryId: _selectedCategoryId,
                ),
        ),
      ],
    );
  }

  Future<void> _processBarcode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    final now = DateTime.now();
    // Throttling: prevent double-scanning of the same item within 1200ms
    if (_lastScannedCode == cleanCode &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastScannedCode = cleanCode;
    _lastScannedTime = now;

    // Trigger haptic feedback to notify cashier of successful scan
    HapticFeedback.lightImpact();

    final items = ref.read(menuItemsProvider).valueOrNull ?? [];
    MenuItem? found;

    try {
      found = items.firstWhere(
        (item) =>
            item.barcode == cleanCode ||
            item.sku == cleanCode ||
            item.variants.any((v) => v.barcode == cleanCode || v.sku == cleanCode),
      );
    } catch (_) {
      found = null;
    }

    // Fallback: search in SQLite local database directly
    if (found == null) {
      final bizId = ref.read(homeBootstrapProvider).valueOrNull?.business?.id;
      if (bizId != null) {
        try {
          found = await LocalDatabaseService.instance.getMenuItemByBarcode(bizId, cleanCode);
        } catch (_) {}
      }
    }

    if (found != null) {
      if (found.variants.isNotEmpty) {
        // Find specific variant if the barcode belongs to a variant
        final variant = found.variants
            .where((v) => v.barcode == cleanCode || v.sku == cleanCode)
            .firstOrNull;

        if (mounted) {
          _showVariantPicker(context, ref, found, initialVariant: variant);
        }
      } else {
        ref.read(cartProvider.notifier).addItem(found);
        if (mounted) {
          _showAddedFeedback(context, found.name);
        }
      }
      if (_searchController.text.trim() == cleanCode) {
        _searchController.clear();
        setState(() => _searchQuery = '');
      }
    } else {
      // Barcode belum terdaftar di toko: buka form pendaftaran instan
      if (mounted) {
        _openQuickAddProduct(cleanCode);
      }
    }
  }

  Future<void> _openQuickAddProduct(String barcode) async {
    final newItem = await QuickAddProductSheet.show(
      context,
      barcode: barcode,
      onProductCreated: (item) {
        ref.read(cartProvider.notifier).addItem(item);
        _showAddedFeedback(context, item.name);
      },
    );

    if (newItem != null && mounted) {
      final inCart =
          ref.read(cartProvider).items.any((ci) => ci.id == newItem.id);
      if (!inCart) {
        ref.read(cartProvider.notifier).addItem(newItem);
        _showAddedFeedback(context, newItem.name);
      }
    }
  }

  void _showVariantPicker(
    BuildContext context,
    WidgetRef ref,
    MenuItem item, {
    MenuItemVariant? initialVariant,
  }) {
    // This is a bit of a hack since ProductGrid holds the _showVariantPicker logic.
    // Ideally it should be moved to a shared location.
    // For now, I'll just show the same sheet as in ProductGrid.
    // I need to make sure the ProductGrid logic is accessible.
    // Actually, I can just copy the showModalBottomSheet logic from product_grid.dart

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          VariantPickerSheet(item: item, initialVariant: initialVariant),
    );
  }

  void _showAddedFeedback(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name ditambahkan ke keranjang'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        onSubmitted: (v) => _processBarcode(v),
        decoration: InputDecoration(
          hintText: 'Cari produk...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                ),
              IconButton(
                tooltip: _isScanMode ? 'Tutup Scanner' : 'Scan Barcode',
                icon: Icon(
                  _isScanMode
                      ? Icons.grid_view_rounded
                      : Icons.qr_code_scanner_rounded,
                  color: const Color(0xFFF98B35),
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isScanMode = !_isScanMode;
                  });
                },
              ),
            ],
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: InputBorder.none,
        ),
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  void _showDraftOrders(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DraftOrdersSheet(),
    );
  }

  void _showIncomingOrders(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IncomingOrdersSheet(),
    );
  }
}

// ── Floating Cart Bar ─────────────────────────────────────────

class _CartFloatingBar extends StatelessWidget {
  const _CartFloatingBar({required this.cart, required this.onTap});
  final CartState cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = _CurrencyHelper.format;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Dark navy/black
          borderRadius: BorderRadius.circular(32), // Pill shape
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF98B35), // Orange
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${cart.totalItemCount}',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL PEMBAYARAN',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatter(cart.grandTotal),
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ── Category Chips ────────────────────────────────────────────

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({
    required this.selectedCategoryId,
    required this.onSelected,
  });
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);

    return SizedBox(
      height: 38,
      child: categoriesAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (categories) {
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('SEMUA'),
                  selected: selectedCategoryId == null,
                  onSelected: (_) => onSelected(null),
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: Colors.white,
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selectedCategoryId == null
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: selectedCategoryId == null
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                  showCheckmark: false,
                ),
              ),
              ...categories.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat.name.toUpperCase()),
                    selected: selectedCategoryId == cat.id,
                    onSelected: (_) => onSelected(
                      selectedCategoryId == cat.id ? null : cat.id,
                    ),
                    selectedColor: const Color(0xFF0F172A),
                    backgroundColor: Colors.white,
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selectedCategoryId == cat.id
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: selectedCategoryId == cat.id
                          ? Colors.transparent
                          : const Color(0xFFE2E8F0),
                    ),
                    showCheckmark: false,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

// ── Action Chip Button ────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Currency Helper ───────────────────────────────────────────

class _CurrencyHelper {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(double value) => _currency.format(value);
}
class _TieredPricingToggleChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final featureGate = ref.watch(featureGateProvider);
    final isTieredAllowed = featureGate.isEnabled('tiered_pricing');
    final isActive = cart.useTieredPricing && isTieredAllowed;

    return Material(
      color: isActive ? const Color(0xFF16A34A) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!isTieredAllowed) {
            showDialog(
              context: context,
              builder: (context) => const ProFeatureDialog(
                featureName: 'Harga Bertingkat',
                description:
                    'Berikan harga grosir otomatis saat pelanggan beli lebih banyak. Fitur ini membantu meningkatkan volume penjualan Anda.',
              ),
            );
            return;
          }
          ref.read(cartProvider.notifier).toggleTieredPricing(!cart.useTieredPricing);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                !isTieredAllowed ? Icons.lock_rounded : Icons.sell_rounded,
                size: 18,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'PROMO',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _IncomingOrdersActionChip extends ConsumerWidget {
  const _IncomingOrdersActionChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(confirmedOrdersProvider);
    final count = incomingAsync.valueOrNull?.length ?? 0;
    final hasActive = count > 0;

    return Material(
      color: hasActive ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasActive
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 18,
                color: hasActive
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'Pesanan${count > 0 ? ' ($count)' : ''}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: hasActive
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

