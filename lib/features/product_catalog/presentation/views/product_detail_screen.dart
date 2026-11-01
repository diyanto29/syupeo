import 'dart:math' as math;

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'product_dashboard_components.dart';

final productDetailProvider = FutureProvider.autoDispose
    .family<MenuItem?, String>((ref, productId) {
      return ref.watch(menuRepositoryProvider).getMenuItemById(productId);
    });

final productLatestStockMovementProvider = FutureProvider.autoDispose
    .family<InventoryMovement?, String>((ref, productId) async {
      final outletId = ref
          .watch(homeBootstrapProvider)
          .value
          ?.currentOutlet
          ?.id;
      if (outletId == null) {
        return null;
      }
      return ref
          .watch(menuRepositoryProvider)
          .getLatestInventoryMovement(productId, outletId: outletId);
    });

final _stockMovementDateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String? productId;

  Future<void> _openEditProduct(
    BuildContext context,
    MenuItem item, {
    required bool canManageProducts,
  }) async {
    if (!canManageProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya Owner dan Admin yang bisa mengubah produk.'),
        ),
      );
      return;
    }

    final updated = await context.pushNamed<bool>(
      RouteNames.addProduct,
      extra: item,
    );
    if (!context.mounted || updated != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawProductId = productId?.trim();
    final isTablet = MediaQuery.sizeOf(context).width >= 720;
    final canManageProducts = ref.watch(canManageCatalogProvider);

    if (rawProductId == null || rawProductId.isEmpty) {
      return _ProductDetailScaffold(
        child: ProductDashboardEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Produk tidak ditemukan',
          detail: 'ID produk belum dikirim ke halaman detail.',
          actionLabel: 'Kembali',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final itemAsync = ref.watch(productDetailProvider(rawProductId));
    final latestStockMovementAsync = ref.watch(
      productLatestStockMovementProvider(rawProductId),
    );

    return itemAsync.when(
      loading: () => _ProductDetailScaffold(
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _ProductDetailScaffold(
        child: ProductDashboardEmptyState(
          icon: Icons.wifi_tethering_error_rounded,
          title: 'Gagal memuat detail produk',
          detail: '$error',
          actionLabel: 'Coba Lagi',
          onAction: () {
            ref.invalidate(productDetailProvider(rawProductId));
            ref.invalidate(productLatestStockMovementProvider(rawProductId));
          },
        ),
      ),
      data: (item) {
        if (item == null) {
          return _ProductDetailScaffold(
            child: ProductDashboardEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Produk tidak ditemukan',
              detail: 'Produk mungkin sudah dihapus atau belum tersedia.',
              actionLabel: 'Kembali',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }

        return _ProductDetailScaffold(
          actions: canManageProducts
              ? [
                  Padding(
                    padding: EdgeInsets.only(right: isTablet ? 24 : 8),
                    child: isTablet
                        ? FilledButton.icon(
                            onPressed: () => _openEditProduct(
                              context,
                              item,
                              canManageProducts: canManageProducts,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit Product'),
                          )
                        : TextButton(
                            onPressed: () => _openEditProduct(
                              context,
                              item,
                              canManageProducts: canManageProducts,
                            ),
                            child: const Text('Edit'),
                          ),
                  ),
                ]
              : null,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productDetailProvider(rawProductId));
              ref.invalidate(productLatestStockMovementProvider(rawProductId));
              await ref.read(productDetailProvider(rawProductId).future);
            },
            child: isTablet
                ? _ProductDetailTabletBody(
                    item: item,
                    latestStockMovementAsync: latestStockMovementAsync,
                    onEdit: canManageProducts
                        ? () => _openEditProduct(
                            context,
                            item,
                            canManageProducts: canManageProducts,
                          )
                        : null,
                  )
                : _ProductDetailMobileBody(
                    item: item,
                    latestStockMovementAsync: latestStockMovementAsync,
                    onEdit: canManageProducts
                        ? () => _openEditProduct(
                            context,
                            item,
                            canManageProducts: canManageProducts,
                          )
                        : null,
                  ),
          ),
        );
      },
    );
  }
}

/// Reusable Product Detail Panel for desktop split-view
class ProductDetailPanel extends ConsumerWidget {
  const ProductDetailPanel({
    super.key,
    required this.item,
    this.onClose,
    this.onEdit,
    this.onDelete,
  });

  final MenuItem item;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final latestStockMovementAsync = ref.watch(
      productLatestStockMovementProvider(item.id),
    );

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _hasValue(item.barcode)
                            ? 'Barcode: ${item.barcode}'
                            : _hasValue(item.sku)
                                ? 'SKU: ${item.sku}'
                                : item.categoryName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Produk',
                    onPressed: onEdit,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: scheme.error),
                    tooltip: 'Hapus Produk',
                    onPressed: onDelete,
                  ),
                if (onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Tutup Detail',
                    onPressed: onClose,
                  ),
                ],
              ],
            ),
          ),

          // Scrollable Body Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _DetailHeroImage(
                  item: item,
                  height: 200,
                  borderRadius: 18,
                ),
                const SizedBox(height: 16),
                _DetailCard(
                  padding: const EdgeInsets.all(18),
                  child: _ProductOverviewCard(item: item),
                ),
                const SizedBox(height: 14),
                _DetailCard(
                  padding: const EdgeInsets.all(18),
                  child: _PricingSummaryCard(item: item),
                ),
                if (item.tieredPrices.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DetailCard(
                    padding: const EdgeInsets.all(18),
                    child: _TieredPriceInfoCard(item: item),
                  ),
                ],
                const SizedBox(height: 14),
                _DetailCard(
                  padding: const EdgeInsets.all(18),
                  child: _InventorySummaryCard(
                    item: item,
                    latestStockMovementAsync: latestStockMovementAsync,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Bottom Action: Edit button
          if (onEdit != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF002147).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit Produk Lengkap',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductDetailScaffold extends StatelessWidget {
  const _ProductDetailScaffold({required this.child, this.actions});

  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: const Text('Detail Produk'),
              badge: const AppTabletBadge(label: 'Syupeo'),
              actions: actions,
            )
          : AppBar(
              title: const Text('Detail Produk'),
              centerTitle: false,
              actions: actions,
            ),
      body: child,
    );
  }
}

class _ProductDetailTabletBody extends StatelessWidget {
  const _ProductDetailTabletBody({
    required this.item,
    required this.onEdit,
    required this.latestStockMovementAsync,
  });

  final MenuItem item;
  final VoidCallback? onEdit;
  final AsyncValue<InventoryMovement?> latestStockMovementAsync;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 40 + bottomPadding),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 8,
                      child: Column(
                        children: [
                          _DetailHeroImage(
                            item: item,
                            height: 360,
                            borderRadius: 28,
                          ),
                          const SizedBox(height: 16),
                          _DetailCard(
                            padding: const EdgeInsets.all(28),
                            child: _ProductOverviewCard(item: item),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _DetailCard(
                            padding: const EdgeInsets.all(24),
                            child: _PricingSummaryCard(item: item),
                          ),
                          if (item.tieredPrices.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DetailCard(
                              padding: const EdgeInsets.all(24),
                              child: _TieredPriceInfoCard(item: item),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _DetailCard(
                            padding: const EdgeInsets.all(24),
                            child: _InventorySummaryCard(
                              item: item,
                              latestStockMovementAsync:
                                  latestStockMovementAsync,
                            ),
                          ),
                          if (onEdit != null) ...[
                            const SizedBox(height: 16),
                            _ActionCard(onEdit: onEdit!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailCard(
                  padding: const EdgeInsets.all(24),
                  child: _ProductVariantsTable(item: item, onEdit: onEdit),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductDetailMobileBody extends StatelessWidget {
  const _ProductDetailMobileBody({
    required this.item,
    required this.onEdit,
    required this.latestStockMovementAsync,
  });

  final MenuItem item;
  final VoidCallback? onEdit;
  final AsyncValue<InventoryMovement?> latestStockMovementAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _DetailHeroImage(item: item, height: 270, borderRadius: 0),
            Positioned(
              left: 16,
              right: 16,
              bottom: -42,
              child: _DetailCard(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                borderRadius: 26,
                child: _MobileIntroCard(item: item),
              ),
            ),
          ],
        ),
        const SizedBox(height: 58),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Inventory Summary',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF548CE0),
                  value: _inventoryPrimaryValue(item),
                  label: _inventoryPrimaryLabel(item),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _MiniStatCard(
                  icon: item.isSellable
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  iconColor: _statusColor(item),
                  value: _statusText(item),
                  label: 'Stock Status',
                  emphasizeText: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StockAuditNotice(
            latestStockMovementAsync: latestStockMovementAsync,
          ),
        ),
        if (item.tieredPrices.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DetailCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 22,
              child: _TieredPriceInfoCard(item: item),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DetailCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            child: _PriceBreakdownCard(item: item),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DetailCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            child: _ProductInfoCard(item: item),
          ),
        ),
        if (onEdit != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ActionCard(onEdit: onEdit!),
          ),
        ],
        const SizedBox(height: 60),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class _DetailHeroImage extends StatelessWidget {
  const _DetailHeroImage({
    required this.item,
    required this.height,
    required this.borderRadius,
  });

  final MenuItem item;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;
    final imageWidget = hasImage
        ? CachedNetworkImage(
            imageUrl: item.imageUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 600,
            placeholder: (context, url) => Container(
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: scheme.primary,
              ),
            ),
            errorWidget: (_, __, ___) => _DetailImageFallback(item: item),
          )
        : _DetailImageFallback(item: item);

    final content = Stack(
      children: [
        Positioned.fill(child: imageWidget),
        Positioned(
          left: 16,
          top: 16,
          child: _SoftPill(
            label: item.categoryName,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF9A5700),
          ),
        ),
      ],
    );

    if (borderRadius == 0) {
      return SizedBox(height: height, width: double.infinity, child: content);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(height: height, width: double.infinity, child: content),
    );
  }
}

class _DetailImageFallback extends StatelessWidget {
  const _DetailImageFallback({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.secondary.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _fallbackIcon(item.categoryVisualIndex),
          size: 64,
          color: scheme.primary.withValues(alpha: 0.82),
        ),
      ),
    );
  }

  IconData _fallbackIcon(int? visualIndex) {
    switch ((visualIndex ?? 0) % 5) {
      case 0:
        return Icons.inventory_2_rounded;
      case 1:
        return Icons.local_drink_rounded;
      case 2:
        return Icons.fastfood_rounded;
      case 3:
        return Icons.cake_rounded;
      case 4:
        return Icons.restaurant_rounded;
    }
    return Icons.inventory_2_rounded;
  }
}

class _ProductOverviewCard extends StatelessWidget {
  const _ProductOverviewCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = item.description.trim().isEmpty
        ? 'Belum ada deskripsi produk. Kamu bisa tambahkan detail bahan, rasa, atau catatan jual lewat form edit produk.'
        : item.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_hasValue(item.sku))
              _MetaChip(icon: Icons.sell_outlined, text: 'SKU ${item.sku}'),
            if (_hasValue(item.barcode))
              _MetaChip(
                icon: Icons.qr_code_rounded,
                text: 'Barcode ${item.barcode}',
              ),
            _MetaChip(
              icon: Icons.straighten_rounded,
              text: item.displayUnit.toUpperCase(),
            ),
            _MetaChip(icon: Icons.category_outlined, text: item.categoryName),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Product Description',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: scheme.onSurface.withValues(alpha: 0.74),
          ),
        ),
      ],
    );
  }
}

class _MobileIntroCard extends StatelessWidget {
  const _MobileIntroCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = item.description.trim().isEmpty
        ? 'Belum ada deskripsi produk. Kamu bisa melengkapinya dari halaman edit product.'
        : item.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SoftPill(
          label: item.categoryName.toUpperCase(),
          backgroundColor: const Color(0xFFE8F0FF),
          foregroundColor: const Color(0xFF5B6E95),
        ),
        const SizedBox(height: 12),
        Text(
          item.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _priceRangeLabel(item),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF548CE0),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 14),
        Divider(color: scheme.outline.withValues(alpha: 0.16)),
        const SizedBox(height: 14),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.75,
            color: scheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _PricingSummaryCard extends StatelessWidget {
  const _PricingSummaryCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minPrice = _minPrice(item);
    final marginText = _marginPercentLabel(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionEyebrow(
          icon: Icons.payments_outlined,
          label: 'Pricing & Sales',
          color: const Color(0xFF9A5700),
        ),
        const SizedBox(height: 14),
        Text(
          'Selling Price Range',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _priceRangeLabel(item),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF548CE0),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Divider(color: scheme.outline.withValues(alpha: 0.14)),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Base Cost (Harga Modal)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.recipeCost > 0
                        ? RupiahInputHelper.formatWithPrefix(item.recipeCost)
                        : 'Belum diisi',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF425B96),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (marginText != null)
              _SoftPill(
                label: marginText,
                backgroundColor: const Color(0xFFE6EEFF),
                foregroundColor: const Color(0xFF5675B5),
              ),
          ],
        ),
        if (item.recipeCost > 0 && minPrice > 0) ...[
          const SizedBox(height: 14),
          Text(
            'Margin dihitung dari harga jual terendah agar tetap realistis saat produk punya beberapa varian.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.58),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({
    required this.item,
    required this.latestStockMovementAsync,
  });

  final MenuItem item;
  final AsyncValue<InventoryMovement?> latestStockMovementAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionEyebrow(
              icon: Icons.inventory_2_outlined,
              label: 'Inventory Summary',
              color: Color(0xFF9A5700),
            ),
            const Spacer(),
            _SoftPill(
              label: _statusText(item).toUpperCase(),
              backgroundColor: _statusColor(item).withValues(alpha: 0.12),
              foregroundColor: _statusColor(item),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                _inventoryPrimaryValue(item),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: item.trackStockQuantity ? 40 : 28,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _inventoryPrimaryLabel(item),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          icon: Icons.straighten_rounded,
          title: 'Unit Penjualan',
          value: item.displayUnit.toUpperCase(),
        ),
        const SizedBox(height: 10),
        _InfoPanel(
          icon: Icons.layers_outlined,
          title: 'Variants',
          value: item.variants.isEmpty
              ? 'Produk tunggal'
              : '${_activeVariantCount(item)} dari ${item.variants.length} varian aktif',
        ),
        const SizedBox(height: 10),
        _InfoPanel(
          icon: Icons.sync_alt_rounded,
          title: 'Stock Tracking',
          value: item.trackStockQuantity
              ? 'Aktif, stok tersimpan di level produk'
              : 'Belum aktif',
        ),
        const SizedBox(height: 10),
        _InfoPanel(
          icon: Icons.history_toggle_off_rounded,
          title: 'Update Stok Terakhir',
          value: _latestStockMovementText(latestStockMovementAsync),
        ),
      ],
    );
  }
}

class _StockAuditNotice extends StatelessWidget {
  const _StockAuditNotice({required this.latestStockMovementAsync});

  final AsyncValue<InventoryMovement?> latestStockMovementAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFFB86800),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat stok terbaru',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7A4500),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _latestStockMovementText(latestStockMovementAsync),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1EA7E1),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221EA7E1),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Product',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update stock, price, photo, dan variant dari form edit.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductVariantsTable extends StatelessWidget {
  const _ProductVariantsTable({required this.item, required this.onEdit});

  final MenuItem item;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = _variantRows(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.layers_outlined,
                color: Color(0xFFCC6E14),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Product Variants',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
            if (onEdit != null) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Variants'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              const _TableHeaderRow(),
              const SizedBox(height: 8),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    color: scheme.outline.withValues(alpha: 0.08),
                    height: 1,
                  ),
                _VariantTableRow(row: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = _variantRows(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varian Produk',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(color: scheme.outline.withValues(alpha: 0.08), height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rows[i].name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (rows[i].identifier.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        rows[i].identifier,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.56),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rows[i].priceLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rows[i].availabilityLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: rows[i].isAvailable
                          ? const Color(0xFF14804A)
                          : scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProductInfoCard extends StatelessWidget {
  const _ProductInfoCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Info',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _InfoLine(label: 'Category', value: item.categoryName),
        _InfoLine(label: 'Unit', value: item.displayUnit.toUpperCase()),
        _InfoLine(
          label: 'Base Cost',
          value: item.recipeCost > 0
              ? RupiahInputHelper.formatWithPrefix(item.recipeCost)
              : 'Belum diisi',
          isLast: !_hasValue(item.sku) && !_hasValue(item.barcode),
        ),
        if (_hasValue(item.sku))
          _InfoLine(
            label: 'SKU',
            value: item.sku!,
            isLast: !_hasValue(item.barcode),
          ),
        if (_hasValue(item.barcode))
          _InfoLine(label: 'Barcode', value: item.barcode!, isLast: true),
        if (!_hasValue(item.sku) && !_hasValue(item.barcode))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'SKU dan barcode belum diisi untuk produk ini.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
      ],
    );
  }
}

class _TieredPriceInfoCard extends StatelessWidget {
  const _TieredPriceInfoCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sortedTiers = List<TieredPrice>.from(item.tieredPrices)
      ..sort((a, b) => a.minQuantity.compareTo(b.minQuantity));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow(
          icon: Icons.sell_rounded,
          label: 'Harga Bertingkat',
          color: Color(0xFF14804A),
        ),
        const SizedBox(height: 14),
        Text(
          'Dapatkan harga lebih murah dengan pembelian jumlah minimal tertentu.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.64),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < sortedTiers.length; i++) ...[
          if (i > 0)
            Divider(color: scheme.outline.withValues(alpha: 0.08), height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Min. ${sortedTiers[i].minQuantity} ${item.displayUnit}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF1B5E20),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                RupiahInputHelper.formatWithPrefix(sortedTiers[i].price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF14804A),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.emphasizeText = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool emphasizeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DetailCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 34),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: emphasizeText ? 16 : 18,
              color: emphasizeText ? iconColor : null,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4D8C3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF5A6B92), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.08),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE8E1DA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2A1F17),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.black.withValues(alpha: 0.56),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );

    return Row(
      children: [
        Expanded(flex: 4, child: Text('VARIANT NAME', style: style)),
        Expanded(flex: 4, child: Text('SKU / BARCODE', style: style)),
        Expanded(flex: 2, child: Text('SALES PRICE', style: style)),
        Expanded(flex: 2, child: Text('STATUS', style: style)),
      ],
    );
  }
}

class _VariantTableRow extends StatelessWidget {
  const _VariantTableRow({required this.row});

  final _VariantRowData row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    row.shortCode,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFD56A00),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.primaryCode,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (row.secondaryCode != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.secondaryCode!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.priceLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFC56A00),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.availabilityLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: row.isAvailable
                    ? const Color(0xFF14804A)
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantRowData {
  const _VariantRowData({
    required this.name,
    required this.priceLabel,
    required this.primaryCode,
    required this.secondaryCode,
    required this.identifier,
    required this.availabilityLabel,
    required this.isAvailable,
    required this.shortCode,
  });

  final String name;
  final String priceLabel;
  final String primaryCode;
  final String? secondaryCode;
  final String identifier;
  final String availabilityLabel;
  final bool isAvailable;
  final String shortCode;
}

List<_VariantRowData> _variantRows(MenuItem item) {
  if (item.variants.isEmpty) {
    final primaryCode = _coalesce(item.sku, item.barcode, fallback: '-');
    final secondaryCode = _hasValue(item.sku) && _hasValue(item.barcode)
        ? item.barcode
        : null;

    return [
      _VariantRowData(
        name: item.name,
        priceLabel: RupiahInputHelper.formatWithPrefix(item.price),
        primaryCode: primaryCode,
        secondaryCode: secondaryCode,
        identifier: secondaryCode == null
            ? primaryCode
            : '$primaryCode  $secondaryCode',
        availabilityLabel: item.isSellable ? 'Active' : 'Inactive',
        isAvailable: item.isSellable,
        shortCode: _shortCode(item.name),
      ),
    ];
  }

  return item.variants.map((variant) {
    final primaryCode = _coalesce(variant.sku, variant.barcode, fallback: '-');
    final secondaryCode = _hasValue(variant.sku) && _hasValue(variant.barcode)
        ? variant.barcode
        : null;
    final availability = variant.stockAvailable && item.stockAvailable;

    return _VariantRowData(
      name: variant.name,
      priceLabel: RupiahInputHelper.formatWithPrefix(variant.price),
      primaryCode: primaryCode,
      secondaryCode: secondaryCode,
      identifier: secondaryCode == null
          ? primaryCode
          : '$primaryCode  $secondaryCode',
      availabilityLabel: availability ? 'Active' : 'Inactive',
      isAvailable: availability,
      shortCode: _shortCode(variant.name),
    );
  }).toList();
}

double _minPrice(MenuItem item) {
  final prices = item.variants.isEmpty
      ? <double>[item.price]
      : item.variants.map((variant) => variant.price).toList();
  return prices.reduce(math.min);
}

double _maxPrice(MenuItem item) {
  final prices = item.variants.isEmpty
      ? <double>[item.price]
      : item.variants.map((variant) => variant.price).toList();
  return prices.reduce(math.max);
}

String _priceRangeLabel(MenuItem item) {
  final minPrice = _minPrice(item);
  final maxPrice = _maxPrice(item);
  if ((maxPrice - minPrice).abs() < 0.001) {
    return RupiahInputHelper.formatWithPrefix(minPrice);
  }
  return '${RupiahInputHelper.formatWithPrefix(minPrice)} - ${RupiahInputHelper.formatWithPrefix(maxPrice)}';
}

int _activeVariantCount(MenuItem item) {
  return item.variants.where((variant) => variant.stockAvailable).length;
}

String? _marginPercentLabel(MenuItem item) {
  final baseCost = item.recipeCost;
  if (baseCost <= 0) return null;

  // Jika produk memiliki varian, hitung margin berdasarkan harga induk atau varian ber-rasio
  double comparePrice = item.price;
  double compareCost = baseCost;

  if (item.variants.isNotEmpty) {
    final bestVariant = item.variants.first;
    if (bestVariant.price > 0) {
      comparePrice = bestVariant.price;
      compareCost = baseCost * bestVariant.multiplier;
    }
  }

  if (comparePrice <= 0 || compareCost <= 0 || compareCost >= comparePrice) {
    return null;
  }

  final margin = ((comparePrice - compareCost) / comparePrice) * 100;
  return '${margin.round()}% Margin';
}

String _latestStockMovementText(
  AsyncValue<InventoryMovement?> latestStockMovementAsync,
) {
  if (latestStockMovementAsync.isLoading &&
      latestStockMovementAsync.valueOrNull == null) {
    return 'Memuat riwayat stok...';
  }

  if (latestStockMovementAsync.hasError &&
      latestStockMovementAsync.valueOrNull == null) {
    return 'Riwayat stok belum tersedia.';
  }

  final movement = latestStockMovementAsync.valueOrNull;
  if (movement == null) {
    return 'Belum ada mutasi stok tercatat.';
  }

  final deltaPrefix = movement.quantityDelta > 0 ? '+' : '';
  final timestamp = _stockMovementDateFormat.format(
    movement.createdAt.toLocal(),
  );
  final suffix = movement.note == null || movement.note!.trim().isEmpty
      ? ''
      : ' • ${movement.note!.trim()}';
  return '${movement.movementLabel} • $timestamp • $deltaPrefix${movement.quantityDelta}$suffix';
}

String _inventoryPrimaryValue(MenuItem item) {
  if (item.trackStockQuantity) {
    return item.formattedStock;
  }
  if (item.variants.isNotEmpty) {
    return '${_activeVariantCount(item)}';
  }
  return item.stockAvailable ? 'Ready' : 'Off';
}

String _inventoryPrimaryLabel(MenuItem item) {
  if (item.trackStockQuantity) {
    return 'Units Total';
  }
  if (item.variants.isNotEmpty) {
    return 'Active Variants';
  }
  return 'Stock Mode';
}

String _statusText(MenuItem item) {
  if (!item.stockAvailable) {
    return 'Nonaktif';
  }
  if (item.isOutOfTrackedStock) {
    return 'Out of Stock';
  }
  return 'In Stock';
}

Color _statusColor(MenuItem item) {
  if (!item.stockAvailable || item.isOutOfTrackedStock) {
    return const Color(0xFFD74343);
  }
  return const Color(0xFF14804A);
}

bool _hasValue(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _coalesce(String? first, String? second, {required String fallback}) {
  if (_hasValue(first)) {
    return first!.trim();
  }
  if (_hasValue(second)) {
    return second!.trim();
  }
  return fallback;
}

String _shortCode(String value) {
  final compact = value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.substring(0, 1).toUpperCase())
      .join();
  if (compact.isNotEmpty) {
    return compact;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'PR';
  }
  return trimmed.substring(0, math.min(2, trimmed.length)).toUpperCase();
}
