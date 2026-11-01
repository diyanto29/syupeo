import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/discount_management/data/promo_repository.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/state/product_view_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/subscription/domain/fulfillment_order_model.dart';
import 'package:dpos/features/subscription/presentation/controllers/fulfillment_controller.dart';
import 'package:dpos/features/subscription/presentation/providers/fulfillment_orders_provider.dart';
import 'package:dpos/features/subscription/presentation/views/starter_kit_orders_sheet.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key, this.searchQuery = '', this.categoryId});
  final String searchQuery;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(menuItemsProvider);
    final viewMode = ref.watch(productViewModeProvider);
    final fulfillmentOrders = ref.watch(fulfillmentOrdersProvider).valueOrNull ?? [];
    final inTransitOrder = fulfillmentOrders.cast<FulfillmentOrder?>().firstWhere(
      (o) => o != null && (o.status == 'in_transit' || o.status == 'packing' || o.status == 'pending_dispatch'),
      orElse: () => null,
    );

    return itemsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (items) {
        // 1. Jika toko belum memiliki produk: cek apakah ada paket starter kit yang sedang dikirim
        if (items.isEmpty) {
          if (inTransitOrder != null) {
            return _PackageInTransitView(order: inTransitOrder);
          }
          return const _EmptyCatalogRestockView();
        }

        // 2. Jika seluruh produk stoknya habis:
        final allOutOfStock = items.every((i) => i.stockQuantity <= 0);
        if (allOutOfStock && searchQuery.isEmpty && categoryId == null) {
          return const _EmptyCatalogRestockView(isOutOfStock: true);
        }

        var filtered = items.where((i) => i.isSellable).toList();
        if (categoryId != null) {
          filtered = filtered.where((i) => i.categoryId == categoryId).toList();
        }
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where(
                (i) =>
                    i.name.toLowerCase().contains(q) ||
                    (i.barcode?.toLowerCase().contains(q) ?? false) ||
                    (i.sku?.toLowerCase().contains(q) ?? false),
              )
              .toList();
        }

        if (filtered.isEmpty) {
          final trimmedQuery = searchQuery.trim();
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  trimmedQuery.isNotEmpty
                      ? 'Tidak ada produk untuk "$trimmedQuery"'
                      : 'Tidak ada produk di kategori ini',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                if (trimmedQuery.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Produk otomatis disuplai melalui Paket Usaha & Kulakan',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // ── LIST VIEW MODE ──────────────────────────────────
        if (viewMode.isList) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ProductListItem(item: filtered[index]),
                    childCount: filtered.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        }

        // ── GRID VIEW MODE ──────────────────────────────────
        final screenWidth = MediaQuery.sizeOf(context).width;
        final crossAxisCount = screenWidth >= 1200
            ? 5
            : screenWidth >= 850
            ? 4
            : screenWidth >= 550
            ? 3
            : 2;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: crossAxisCount >= 4
                      ? 0.78
                      : crossAxisCount >= 3
                      ? 0.76
                      : 0.74,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ProductCard(item: filtered[index]),
                  childCount: filtered.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
      loading: () => viewMode.isList
          ? const ProductListSkeleton()
          : const ProductGridSkeleton(),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

/// Helper untuk menambahkan item ke cart atau membuka modal varian/grosir
Future<void> handleProductSelection(
  BuildContext context,
  WidgetRef ref,
  MenuItem item,
) async {
  final hasVariants = item.variants.isNotEmpty;
  if (hasVariants) {
    showVariantPickerModal(context, ref, item);
  } else {
    final cart = ref.read(cartProvider);
    if (cart.useTieredPricing) {
      final existing = cart.items
          .whereType<TransactionItem>()
          .cast<TransactionItem?>()
          .firstWhere(
            (i) => i?.menuItemId == item.id && i?.variantId == null,
            orElse: () => null,
          );
      final newQty = (existing?.quantity ?? 0) + 1;
      final newTier = item.getApplicableTier(newQty);
      final oldTier = item.getApplicableTier(existing?.quantity ?? 0);

      if (newTier != null && newTier != oldTier) {
        final confirmed = await _showTierConfirmation(
          context,
          item.name,
          newTier,
        );
        if (!confirmed) {
          ref.read(cartProvider.notifier).addItem(item, forceNormalPrice: true);
          return;
        }
      }
    }
    ref.read(cartProvider.notifier).addItem(item);
  }
}

void showVariantPickerModal(
  BuildContext context,
  WidgetRef ref,
  MenuItem item,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => VariantPickerSheet(item: item),
  );
}

// ── GRID ITEM VIEW ──────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVariants = item.variants.isNotEmpty;
    final bxgyPromos = ref.watch(buyXGetYPromosProvider).valueOrNull ?? [];
    final hasBxgyPromo = bxgyPromos.any(
      (p) => p.isCurrentlyActive() && p.triggerMenuItemId == item.id,
    );

    final cartItems = ref.watch(cartProvider.select((c) => c.items));
    final inCartQty = cartItems
        .where((i) => i.menuItemId == item.id)
        .fold<int>(0, (sum, i) => sum + i.quantity);
    final isInCart = inCartQty > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInCart
              ? const Color(0xFFF98B35).withValues(alpha: 0.45)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isInCart ? 0.06 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            HapticFeedback.lightImpact();
            await handleProductSelection(context, ref, item);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image or icon placeholder
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child:
                              item.imageUrl != null &&
                                  item.imageUrl!.trim().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 260,
                                    memCacheHeight: 260,
                                    placeholder: (context, url) => Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.fastfood_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 36,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.fastfood_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 36,
                                ),
                        ),
                        if (isInCart)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF98B35),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${inCartQty}x',
                                style: GoogleFonts.manrope(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item.categoryName.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (item.isPackage && item.packageSummary.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          item.packageSummary,
                          style: GoogleFonts.manrope(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _currency.format(item.price),
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFF98B35),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (hasBxgyPromo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFECDD3),
                                ),
                              ),
                              child: Text(
                                'BOGO',
                                style: GoogleFonts.manrope(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE11D48),
                                ),
                              ),
                            )
                          else if (item.isPackage)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PAKET',
                                style: GoogleFonts.manrope(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF4338CA),
                                ),
                              ),
                            )
                          else if (hasVariants)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.variants.length} VAR',
                                style: GoogleFonts.manrope(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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

// ── LIST ITEM VIEW ──────────────────────────────────────────────

class _ProductListItem extends ConsumerWidget {
  const _ProductListItem({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVariants = item.variants.isNotEmpty;
    final bxgyPromos = ref.watch(buyXGetYPromosProvider).valueOrNull ?? [];
    final hasBxgyPromo = bxgyPromos.any(
      (p) => p.isCurrentlyActive() && p.triggerMenuItemId == item.id,
    );

    final cartItems = ref.watch(cartProvider.select((c) => c.items));
    final inCartQty = cartItems
        .where((i) => i.menuItemId == item.id)
        .fold<int>(0, (sum, i) => sum + i.quantity);

    final isInCart = inCartQty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInCart
              ? const Color(0xFFF98B35).withValues(alpha: 0.45)
              : const Color(0xFFF1F5F9),
          width: isInCart ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isInCart ? 0.04 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            HapticFeedback.lightImpact();
            await handleProductSelection(context, ref, item);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Thumbnail
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child:
                            item.imageUrl != null &&
                                item.imageUrl!.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                memCacheWidth: 160,
                                memCacheHeight: 160,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.fastfood_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 26,
                                ),
                              )
                            : const Icon(
                                Icons.fastfood_rounded,
                                color: Color(0xFF94A3B8),
                                size: 26,
                              ),
                      ),
                    ),
                    if (isInCart)
                      Positioned(
                        top: -5,
                        left: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF98B35),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFF98B35,
                                ).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$inCartQty',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.categoryName.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.barcode != null &&
                              item.barcode!.isNotEmpty) ...[
                            Text(
                              ' • ${item.barcode}',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (item.trackStockQuantity) ...[
                            Text(
                              ' • Stok: ${item.formattedStock}',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: item.stockQuantity > 5
                                    ? const Color(0xFF16A34A)
                                    : item.stockQuantity > 0
                                    ? const Color(0xFFEAB308)
                                    : const Color(0xFFEF4444),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      if (hasBxgyPromo ||
                          item.isPackage ||
                          hasVariants ||
                          item.tieredPrices.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (hasBxgyPromo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFECDD3),
                                  ),
                                ),
                                child: Text(
                                  'BOGO',
                                  style: GoogleFonts.manrope(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE11D48),
                                  ),
                                ),
                              ),
                            if (item.isPackage)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PAKET',
                                  style: GoogleFonts.manrope(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4338CA),
                                  ),
                                ),
                              ),
                            if (hasVariants)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.variants.length} VARIAN',
                                  style: GoogleFonts.manrope(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            if (item.tieredPrices.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBBF7D0),
                                  ),
                                ),
                                child: Text(
                                  'GROSIR',
                                  style: GoogleFonts.manrope(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trailing Price & Action Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currency.format(item.price),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF98B35),
                      ),
                    ),
                    const SizedBox(height: 6),
                    hasVariants
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'PILIH',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isInCart
                                  ? const Color(0xFFF98B35)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isInCart
                                              ? const Color(0xFFF98B35)
                                              : const Color(0xFF0F172A))
                                          .withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VariantPickerSheet extends ConsumerStatefulWidget {
  const VariantPickerSheet({
    super.key,
    required this.item,
    this.initialVariant,
  });
  final MenuItem item;
  final MenuItemVariant? initialVariant;

  @override
  ConsumerState<VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends ConsumerState<VariantPickerSheet> {
  MenuItemVariant? _selectedVariant;
  bool _isOriginalSelected = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialVariant != null) {
      _selectedVariant = widget.initialVariant;
      _isOriginalSelected = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'PILIH VARIAN',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF98B35),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              widget.item.name,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Silahkan pilih salah satu varian di bawah ini',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Original Option
            Builder(
              builder: (context) {
                final cartItems = ref.watch(cartProvider).items;
                double alreadyAllocated = 0.0;
                for (final ci in cartItems) {
                  if (ci.menuItemId == widget.item.id) {
                    final v = widget.item.variants
                        .cast<MenuItemVariant?>()
                        .firstWhere(
                          (varObj) => varObj?.id == ci.variantId,
                          orElse: () => null,
                        );
                    alreadyAllocated += ci.quantity * (v?.multiplier ?? 1.0);
                  }
                }
                final remainingStock = widget.item.trackStockQuantity
                    ? (widget.item.stockQuantity - alreadyAllocated)
                    : 9999.0;
                final originalQuota = widget.item.trackStockQuantity
                    ? remainingStock.floor()
                    : 9999;
                final isAvailable =
                    !widget.item.trackStockQuantity || originalQuota > 0;
                final statusLabel = widget.item.trackStockQuantity
                    ? (isAvailable
                        ? 'SISA $originalQuota KUOTA (1 ${widget.item.displayUnit})'
                        : 'HABIS (Stok sisa ${remainingStock > 0 ? (remainingStock % 1 == 0 ? remainingStock.toInt() : remainingStock.toStringAsFixed(2)) : 0} ${widget.item.displayUnit})')
                    : 'TERSEDIA';

                return _buildVariantOption(
                  name: 'ORIGINAL (1 ${widget.item.displayUnit.toUpperCase()})',
                  price: widget.item.price,
                  isSelected: _isOriginalSelected,
                  isAvailable: isAvailable,
                  statusLabel: statusLabel,
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            _isOriginalSelected = true;
                            _selectedVariant = null;
                          });
                          _addToCartAndClose(null);
                        }
                      : null,
                );
              },
            ),
            // Variants dengan kalkulasi kuota pecahan dinamis (Opsi 1)
            ...widget.item.variants.map((v) {
              final cartItems = ref.watch(cartProvider).items;
              double alreadyAllocated = 0.0;
              for (final ci in cartItems) {
                if (ci.menuItemId == widget.item.id) {
                  final matched = widget.item.variants
                      .cast<MenuItemVariant?>()
                      .firstWhere(
                        (varObj) => varObj?.id == ci.variantId,
                        orElse: () => null,
                      );
                  alreadyAllocated += ci.quantity * (matched?.multiplier ?? 1.0);
                }
              }
              final remainingStock = widget.item.trackStockQuantity
                  ? (widget.item.stockQuantity - alreadyAllocated)
                  : 9999.0;
              final quota = widget.item.trackStockQuantity
                  ? v.calculateAvailableQuota(remainingStock)
                  : 9999;
              final isAvailable = !widget.item.trackStockQuantity || quota > 0;
              final isSelected = _selectedVariant?.id == v.id;
              final statusLabel = widget.item.trackStockQuantity
                  ? (isAvailable
                      ? 'SISA $quota KUOTA (${v.multiplier} ${widget.item.displayUnit})'
                      : 'HABIS (Butuh ${v.multiplier} ${widget.item.displayUnit}, sisa ${remainingStock > 0 ? (remainingStock % 1 == 0 ? remainingStock.toInt() : remainingStock.toStringAsFixed(2)) : 0})')
                  : 'TERSEDIA';

              return _buildVariantOption(
                name: v.name.toUpperCase(),
                price: v.price,
                isSelected: isSelected,
                isAvailable: isAvailable,
                statusLabel: statusLabel,
                onTap: isAvailable
                    ? () {
                        setState(() {
                          _isOriginalSelected = false;
                          _selectedVariant = v;
                        });
                        _addToCartAndClose(v);
                      }
                    : null,
              );
            }),
            const SizedBox(height: 16),
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                'Batalkan',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantOption({
    required String name,
    required double price,
    required bool isSelected,
    required VoidCallback? onTap,
    bool isAvailable = true,
    String statusLabel = 'TERSEDIA',
  }) {
    final bgColor = !isAvailable
        ? const Color(0xFFF1F5F9)
        : (isSelected ? const Color(0xFFFCF8F5) : const Color(0xFFF8FAFC));
    final borderColor = !isAvailable
        ? const Color(0xFFCBD5E1)
        : (isSelected ? const Color(0xFF8B6B5D) : const Color(0xFFE2E8F0));
    final iconBgColor = !isAvailable
        ? const Color(0xFFE2E8F0)
        : (isSelected ? const Color(0xFF8B6B5D) : Colors.white);
    final iconColor = !isAvailable
        ? Colors.grey.shade400
        : (isSelected ? Colors.white : Colors.grey.shade600);
    final titleColor = !isAvailable
        ? const Color(0xFF94A3B8)
        : (isSelected ? const Color(0xFF8B6B5D) : const Color(0xFF1E293B));
    final priceBgColor = !isAvailable
        ? const Color(0xFFE2E8F0)
        : (isSelected ? const Color(0xFF8B6B5D) : Colors.white);
    final priceColor = !isAvailable
        ? const Color(0xFF94A3B8)
        : (isSelected ? Colors.white : const Color(0xFF0F172A));

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected || !isAvailable
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Icon(
                  !isAvailable
                      ? Icons.block_rounded
                      : (isSelected ? Icons.check_rounded : Icons.coffee_rounded),
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: !isAvailable
                            ? Colors.red.shade400
                            : Colors.blueGrey.shade400,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              // Price Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: priceBgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected || !isAvailable
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  _currency.format(price),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: priceColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCartAndClose(MenuItemVariant? variant) async {
    final cart = ref.read(cartProvider);
    if (cart.useTieredPricing) {
      final existing = cart.items
          .whereType<TransactionItem>()
          .cast<TransactionItem?>()
          .firstWhere(
            (i) =>
                i?.menuItemId == widget.item.id && i?.variantId == variant?.id,
            orElse: () => null,
          );
      final newQty = (existing?.quantity ?? 0) + 1;
      final newTier = widget.item.getApplicableTier(newQty);
      final oldTier = widget.item.getApplicableTier(existing?.quantity ?? 0);

      if (newTier != null && newTier != oldTier) {
        final confirmed = await _showTierConfirmation(
          context,
          variant != null
              ? '${widget.item.name} (${variant.name})'
              : widget.item.name,
          newTier,
        );
        if (!confirmed) {
          ref
              .read(cartProvider.notifier)
              .addItem(widget.item, variant: variant, forceNormalPrice: true);
          // Slight delay to show the selected state animation before closing
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
          return;
        }
      }
    }

    ref.read(cartProvider.notifier).addItem(widget.item, variant: variant);

    // Slight delay to show the selected state animation before closing
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }
}

Future<bool> _showTierConfirmation(
  BuildContext context,
  String productName,
  TieredPrice tier,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF98B35)),
              const SizedBox(width: 12),
              const Text('Gunakan Harga Grosir?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jumlah pembelian $productName telah mencapai batas minimal ${tier.minQuantity} unit.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Harga Baru:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _currency.format(tier.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Tetap Harga Normal',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Ya, Terapkan'),
            ),
          ],
        ),
      ) ??
      false;
}

class _PackageInTransitView extends ConsumerWidget {
  const _PackageInTransitView({required this.order});
  final FulfillmentOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Color(0xFF0070FC),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  'PAKET STARTER KIT DALAM PENGIRIMAN 🚚',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Barang Fisik Sedang Menuju Toko',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stok barang display awal toko Anda sedang diproses oleh Gudang Syupeo. Setelah barang fisik diterima & dikonfirmasi, kasir akan langsung terisi produk untuk siap bertransaksi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'No. Pesanan: ${order.orderCode}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        Text(
                          order.statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: order.statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (order.trackingNumber != null &&
                        order.trackingNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No. Resi: ${order.trackingNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0070FC),
                        ),
                      ),
                    ],
                    if (order.driverName != null &&
                        order.driverName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kurir / Ekspedisi: ${order.driverName}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Tombol Konfirmasi Barang Diterima
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => FulfillmentController.confirmDelivery(
                    context: context,
                    ref: ref,
                    order: order,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    'Konfirmasi Barang Telah Tiba',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (order.driverPhone != null && order.driverPhone!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF15803D),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      backgroundColor: const Color(0xFFF0FDF4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => FulfillmentController.contactDriverWhatsApp(
                      context: context,
                      order: order,
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: Text(
                      'Hubungi Driver (${order.driverName ?? "Kurir"}) via WA',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0070FC),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => StarterKitOrdersSheet.show(context),
                  icon: const Icon(Icons.track_changes_rounded, size: 18),
                  label: Text(
                    'Cek Detail Status Pengiriman',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    ref.read(ownerSelectedMenuProvider.notifier).state =
                        OwnerMenu.restockCatalog;
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                  label: Text(
                    'Lihat Katalog Kulakan / Restok Toko',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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

class _EmptyCatalogRestockView extends ConsumerWidget {
  const _EmptyCatalogRestockView({this.isOutOfStock = false});
  final bool isOutOfStock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOutOfStock
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
                  color: isOutOfStock
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0070FC),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isOutOfStock ? 'Stok Barang Habis' : 'Etalase Kasir Belum Terisi',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOutOfStock
                    ? 'Seluruh stok barang toko saat ini kosong. Lakukan restok barang dari Gudang Syupeo agar kasir dapat memproses transaksi.'
                    : 'Belum ada produk siap jual di etalase kasir. Silakan lakukan kulakan / restok dari pasokan Gudang Syupeo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              if (!isOutOfStock) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      FulfillmentController.syncStarterKitProducts(
                        context: context,
                        ref: ref,
                      );
                    },
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      'Muat Produk Paket Usaha Sekarang',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: isOutOfStock
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0070FC),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ref.read(ownerSelectedMenuProvider.notifier).state =
                              OwnerMenu.restockCatalog;
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: Text(
                          'Restok & Kulakan Sekarang',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0070FC),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ref.read(ownerSelectedMenuProvider.notifier).state =
                              OwnerMenu.restockCatalog;
                        },
                        icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                        label: Text(
                          'Lihat Katalog Kulakan / Restok',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
