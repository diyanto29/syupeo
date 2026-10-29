import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';

import 'product_dashboard_components.dart';
import 'product_dashboard_view_props.dart';

class ProductDashboardMobile extends StatelessWidget {
  const ProductDashboardMobile({super.key, required this.props});

  final ProductDashboardViewProps props;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Manajemen Produk & Diskon'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => props.onRefresh(),
            icon: Icon(Icons.refresh_rounded, color: scheme.primary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: props.searchController,
              onChanged: props.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search or scan...',
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
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildCategoryChip(
                  context,
                  'Semua Produk',
                  isActive: props.selectedCategoryId == null,
                  onTap: () => props.onSelectCategory(null),
                ),
                for (final category in props.categories) ...[
                  const SizedBox(width: 8),
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (props.categoryError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                'Kategori belum berhasil dimuat: ${props.categoryError}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              _buildSummaryText(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.66),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _buildContent(theme, scheme)),
        ],
      ),
      floatingActionButton: props.canManageProducts
          ? FloatingActionButton(
              onPressed: () => props.onAddProduct(),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme scheme) {
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
      child: ListView.separated(
        controller: props.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: props.items.length + 1,
        separatorBuilder: (_, index) => index == props.items.length - 1
            ? const SizedBox(height: 18)
            : const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == props.items.length) {
            return ProductDashboardPaginationFooter(
              loadedCount: props.items.length,
              totalCount: props.totalCount,
              isLoadingMore: props.isLoadingMore,
              hasMore: props.hasMore,
              hasLoadMoreError: props.hasLoadMoreError,
              onLoadMore: () => props.onLoadMore(),
            );
          }

          return _buildProductCard(context, props.items[index]);
        },
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
      color: isActive ? scheme.primary : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isActive ? scheme.onPrimary : scheme.secondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, MenuItem item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = item.isSellable
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => props.onOpenProduct(item),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductCatalogThumbnail(
                item: item,
                width: 64,
                height: 64,
                borderRadius: 12,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.categoryName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.secondary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          formatProductDashboardPrice(item),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.variants.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.variants.length} VARIAN',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.secondary,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.stockStatusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    item.isSellable
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 18,
                    color: statusColor,
                  ),

                  const SizedBox(height: 6),
                  Text(
                    item.displayUnit.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  if (props.canManageProducts) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => props.onDeleteProduct(item),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 24,
                        color: scheme.error,
                      ),
                    ),
                  ],
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
      return 'Memuat produk...';
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
      return 'Produk belum bisa ditampilkan penuh karena data kategori sedang bermasalah.';
    }

    return 'Tambah produk baru, lalu gunakan search dan category untuk menyaring katalog.';
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
