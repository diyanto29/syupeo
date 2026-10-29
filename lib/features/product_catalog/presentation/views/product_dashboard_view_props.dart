import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';

class ProductDashboardViewProps {
  const ProductDashboardViewProps({
    required this.searchController,
    required this.scrollController,
    required this.items,
    required this.categories,
    required this.isBootstrapLoading,
    required this.categoriesLoading,
    required this.categoryError,
    required this.selectedCategoryId,
    required this.activeSearchQuery,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasLoadMoreError,
    required this.totalCount,
    required this.error,
    required this.canManageProducts,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectCategory,
    required this.onRetry,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onAddProduct,
    required this.onOpenProduct,
    required this.onDeleteProduct,
    this.selectedItem,
    this.onSelectItem,
    this.onEditProduct,
  });

  final TextEditingController searchController;
  final ScrollController scrollController;
  final List<MenuItem> items;
  final List<MenuCatalogCategory> categories;
  final bool isBootstrapLoading;
  final bool categoriesLoading;
  final Object? categoryError;
  final String? selectedCategoryId;
  final String activeSearchQuery;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasLoadMoreError;
  final int totalCount;
  final Object? error;
  final bool canManageProducts;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onSelectCategory;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;
  final Future<void> Function({bool reset}) onLoadMore;
  final Future<void> Function() onAddProduct;
  final ValueChanged<MenuItem> onOpenProduct;
  final Future<void> Function(MenuItem item) onDeleteProduct;
  final MenuItem? selectedItem;
  final ValueChanged<MenuItem?>? onSelectItem;
  final Future<void> Function(MenuItem item)? onEditProduct;
}
