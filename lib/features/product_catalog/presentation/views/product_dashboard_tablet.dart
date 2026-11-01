import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';

import 'product_dashboard_components.dart';
import 'product_dashboard_view_props.dart';
import 'product_detail_screen.dart';

class ProductDashboardTablet extends StatelessWidget {
  const ProductDashboardTablet({super.key, required this.props});

  final ProductDashboardViewProps props;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWideDesktop = MediaQuery.sizeOf(context).width >= 900;

    final catalogContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: TextField(
            controller: props.searchController,
            onChanged: props.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search or scan barcode...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: props.searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    onPressed: props.onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                  );
                },
              ),
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              _buildCategoryChip(
                context,
                'Semua Produk',
                isActive: props.selectedCategoryId == null,
                onTap: () => props.onSelectCategory(null),
              ),
              for (final category in props.categories) ...[
                const SizedBox(width: 12),
                _buildCategoryChip(
                  context,
                  category.name,
                  isActive: props.selectedCategoryId == category.id,
                  onTap: () => props.onSelectCategory(category.id),
                ),
              ],
            ],
          ),
        ),
        if (props.categoriesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (props.categoryError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(
              'Kategori belum berhasil dimuat: ${props.categoryError}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Text(
            _buildSummaryText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.66),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: _buildContent(theme, scheme, isWideDesktop: isWideDesktop),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: AppTabletHeader(
        title: const Text('Manajemen Produk & Diskon'),
        badge: const AppTabletBadge(label: 'Syupeo'),
        actions: [
          IconButton(
            onPressed: () => props.onRefresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (props.canManageProducts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => props.onAddProduct(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Produk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isWideDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: catalogContent),
                Container(
                  width: 440,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    border: Border(
                      left: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: _buildSidePanel(context),
                ),
              ],
            )
          : catalogContent,
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedItem = props.selectedItem;

    if (selectedItem == null) {
      return Container(
        color: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Rincian Detail Produk',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih salah satu produk pada katalog di samping untuk melihat rincian harga, modal HPP, margin profit, dan sisa stok fisik.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ProductDetailPanel(
      key: ValueKey(selectedItem.id),
      item: selectedItem,
      onClose: () => props.onSelectItem?.call(null),
      onEdit: props.canManageProducts
          ? () => (props.onEditProduct != null
              ? props.onEditProduct!(selectedItem)
              : props.onOpenProduct(selectedItem))
          : null,
      onDelete: props.canManageProducts
          ? () async {
              await props.onDeleteProduct(selectedItem);
              props.onSelectItem?.call(null);
            }
          : null,
    );
  }

  Widget _buildContent(
    ThemeData theme,
    ColorScheme scheme, {
    required bool isWideDesktop,
  }) {
    if ((props.isBootstrapLoading || props.isInitialLoading) && props.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (props.error != null && props.items.isEmpty) {
      return ProductDashboardEmptyState(
        icon: Icons.wifi_tethering_error_rounded,
        title: 'Gagal memuat produk',
        detail: '${props.error}',
        actionLabel: 'Coba Lagi',
        onAction: () => props.onRetry(),
      );
    }

    if (props.items.isEmpty) {
      return ProductDashboardEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada produk',
        detail: _buildEmptyStateDetail(),
        actionLabel: 'Refresh',
        onAction: () => props.onRefresh(),
      );
    }

    return RefreshIndicator(
      onRefresh: props.onRefresh,
      child: CustomScrollView(
        controller: props.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isWideDesktop ? 320 : 360,
                childAspectRatio: isWideDesktop ? 1.35 : 1.46,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCard(
                  context,
                  props.items[index],
                  isWideDesktop: isWideDesktop,
                ),
                childCount: props.items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ProductDashboardPaginationFooter(
              loadedCount: props.items.length,
              totalCount: props.totalCount,
              isLoadingMore: props.isLoadingMore,
              hasMore: props.hasMore,
              hasLoadMoreError: props.hasLoadMoreError,
              onLoadMore: () => props.onLoadMore(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: isActive ? scheme.primary : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? null
                : Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isActive ? scheme.onPrimary : scheme.secondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    MenuItem item, {
    required bool isWideDesktop,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = isWideDesktop && props.selectedItem?.id == item.id;
    final statusColor = item.isSellable
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Material(
      color: isSelected
          ? scheme.primary.withValues(alpha: 0.05)
          : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          if (isWideDesktop) {
            props.onSelectItem?.call(item);
          } else {
            props.onOpenProduct(item);
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.12),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.shadow.withValues(alpha: 0.03),
                blurRadius: isSelected ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ProductCatalogThumbnail(
                    item: item,
                    width: 64,
                    height: 64,
                    borderRadius: 16,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.categoryName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.secondary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Aktif',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  if (props.canManageProducts)
                    InkWell(
                      onTap: () => props.onDeleteProduct(item),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: scheme.error,
                        size: 24,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatProductDashboardPrice(item),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.variants.isNotEmpty
                          ? scheme.secondaryContainer
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.variants.isNotEmpty
                          ? '${item.variants.length} Variants'
                          : item.displayUnit.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: item.variants.isNotEmpty
                            ? scheme.secondary
                            : scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: scheme.outline.withValues(alpha: 0.1)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.stockStatusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.isSellable
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_outline_rounded,
                      size: 14,
                      color: statusColor,
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

  String _buildSummaryText() {
    if (props.isBootstrapLoading || props.isInitialLoading) {
      return 'Memuat katalog produk...';
    }
    if (props.items.isEmpty) {
      return props.totalCount > 0
          ? '0 dari ${props.totalCount} produk'
          : 'Belum ada produk';
    }
    return '${props.items.length} dari ${props.totalCount} produk';
  }

  String _buildEmptyStateDetail() {
    if (props.activeSearchQuery.isNotEmpty) {
      return 'Tidak ada produk yang cocok dengan kata kunci "${props.activeSearchQuery}".';
    }

    final selectedCategoryName = _selectedCategoryName();
    if (selectedCategoryName != null) {
      return 'Belum ada produk pada kategori $selectedCategoryName.';
    }

    if (props.categoryError != null) {
      return 'Data kategori sedang bermasalah, jadi katalog belum lengkap ditampilkan.';
    }

    return 'Produk akan tampil di sini setelah kamu menambahkan item dari form Add Product.';
  }

  String? _selectedCategoryName() {
    for (final category in props.categories) {
      if (category.id == props.selectedCategoryId) {
        return category.name;
      }
    }
    return null;
  }
}
