import 'dart:math' as math;

import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

String formatProductDashboardPrice(MenuItem item) {
  final prices = item.variants.isEmpty
      ? <double>[item.price]
      : item.variants.map((variant) => variant.price).toList();
  final minPrice = prices.reduce(math.min);
  final maxPrice = prices.reduce(math.max);

  if ((maxPrice - minPrice).abs() < 0.001) {
    return RupiahInputHelper.formatWithPrefix(minPrice);
  }

  return '${RupiahInputHelper.formatWithPrefix(minPrice)} - ${RupiahInputHelper.formatWithPrefix(maxPrice)}';
}

class ProductCatalogThumbnail extends StatelessWidget {
  const ProductCatalogThumbnail({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final MenuItem item;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: scheme.surfaceContainerHighest,
        child: item.imageUrl != null && item.imageUrl!.trim().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                memCacheHeight: 200,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _FallbackThumb(item: item),
              )
            : _FallbackThumb(item: item),
      ),
    );
  }
}

class ProductDashboardEmptyState extends StatelessWidget {
  const ProductDashboardEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.68),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProductDashboardPaginationFooter extends StatelessWidget {
  const ProductDashboardPaginationFooter({
    super.key,
    required this.loadedCount,
    required this.totalCount,
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasLoadMoreError,
    required this.onLoadMore,
  });

  final int loadedCount;
  final int totalCount;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasLoadMoreError;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (loadedCount == 0 && totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
      child: Column(
        children: [
          Text(
            'Menampilkan $loadedCount dari $totalCount produk',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 10),
          if (isLoadingMore)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else if (hasLoadMoreError)
            OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Muat Lagi'),
            )
          else if (hasMore)
            OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load More'),
            )
          else
            Text(
              'Semua produk sudah ditampilkan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.56),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Icon(
        _categoryIconForVisualIndex(item.categoryVisualIndex),
        color: scheme.primary.withValues(alpha: 0.82),
        size: 28,
      ),
    );
  }

  IconData _categoryIconForVisualIndex(int? visualIndex) {
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
