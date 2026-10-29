import 'dart:async';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_category_models.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'product_dashboard_mobile.dart';
import 'product_dashboard_tablet.dart';
import 'product_dashboard_view_props.dart';

class ProductDashboardScreen extends ConsumerStatefulWidget {
  const ProductDashboardScreen({super.key});

  @override
  ConsumerState<ProductDashboardScreen> createState() =>
      _ProductDashboardScreenState();
}

class _ProductDashboardScreenState
    extends ConsumerState<ProductDashboardScreen> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MenuItem> _items = [];

  Timer? _searchDebounce;
  Object? _error;
  String? _selectedCategoryId;
  String _searchQuery = '';
  String? _activeBusinessId;
  String? _pendingBusinessId;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isLoadMoreError = false;
  int _nextOffset = 0;
  int _requestVersion = 0;
  int _totalCount = 0;
  MenuItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleBusinessSync(String? businessId) {
    if (businessId == null ||
        businessId == _activeBusinessId ||
        businessId == _pendingBusinessId) {
      return;
    }

    _pendingBusinessId = businessId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingBusinessId = null;
      if (!mounted) {
        return;
      }

      _activeBusinessId = businessId;
      _selectedCategoryId = null;
      _loadProducts(reset: true);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadProducts();
    }
  }

  void _handleSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }

      final nextQuery = value.trim();
      if (nextQuery == _searchQuery) {
        return;
      }

      _searchQuery = nextQuery;
      _scrollToTop();
      _loadProducts(reset: true);
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) {
      return;
    }

    _searchController.clear();
    _handleSearchChanged('');
  }

  void _selectCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) {
      return;
    }

    setState(() => _selectedCategoryId = categoryId);
    _scrollToTop();
    _loadProducts(reset: true);
  }

  Future<void> _refreshProducts() {
    return _loadProducts(reset: true);
  }

  Future<void> _openAddProductForm() async {
    if (!ref.read(canManageCatalogProvider)) {
      _showProductAccessDenied();
      return;
    }

    final created = await context.pushNamed<bool>(RouteNames.addProduct);
    if (!mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produk baru berhasil disimpan.')),
    );
    await _loadProducts(reset: true);
  }

  Future<void> _openProductDetails(MenuItem item) async {
    final updated = await context.pushNamed<bool>(
      RouteNames.productDetail,
      extra: item.id,
    );
    if (!mounted || updated != true) {
      return;
    }

    await _loadProducts(reset: true);
  }

  Future<void> _editProduct(MenuItem item) async {
    if (!ref.read(canManageCatalogProvider)) {
      _showProductAccessDenied();
      return;
    }

    final updated = await context.pushNamed<bool>(
      RouteNames.addProduct,
      extra: item,
    );
    if (!mounted || updated != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perubahan produk berhasil disimpan.')),
    );
    await _loadProducts(reset: true);
  }

  Future<void> _deleteProduct(MenuItem item) async {
    if (!ref.read(canManageCatalogProvider)) {
      _showProductAccessDenied();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text(
          'Produk "${item.name}" akan dihapus permanen. Gambar produk juga akan ikut dihapus dari storage. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(menuRepositoryProvider)
          .deleteMenuItem(item.id, imageUrl: item.imageUrl);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk "${item.name}" berhasil dihapus.')),
      );
      await _loadProducts(reset: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus produk: $error')));
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    final businessId = _activeBusinessId;
    if (businessId == null) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
      return;
    }

    if (!reset && (_isInitialLoading || _isLoadingMore || !_hasMore)) {
      return;
    }

    final requestVersion = ++_requestVersion;
    final startingOffset = reset ? 0 : _nextOffset;

    setState(() {
      _error = null;
      _isLoadMoreError = false;
      if (reset) {
        _isInitialLoading = true;
        _items.clear();
        _hasMore = true;
        _nextOffset = 0;
        _totalCount = 0;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final page = await ref
          .read(menuRepositoryProvider)
          .getMenuItemsPage(
            businessId,
            limit: _pageSize,
            offset: startingOffset,
            searchQuery: _searchQuery,
            categoryId: _selectedCategoryId,
          );

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          final existingIds = _items.map((item) => item.id).toSet();
          _items.addAll(
            page.items.where((item) => !existingIds.contains(item.id)),
          );
        }

        _nextOffset = page.nextOffset;
        _hasMore = page.hasMore;
        _totalCount = page.totalCount;
        if (_selectedItem != null) {
          _selectedItem =
              _items.where((item) => item.id == _selectedItem!.id).firstOrNull;
        }
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _error = error;
        _isLoadMoreError = !reset && _items.isNotEmpty;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _showProductAccessDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hanya Owner dan Admin yang bisa mengubah produk.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(homeBootstrapProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final businessId = bootstrapAsync.value?.business?.id;
    final canManageProducts = ref.watch(canManageCatalogProvider);
    final categories = categoriesAsync.value ?? const <MenuCatalogCategory>[];
    final effectiveError =
        _error ?? (bootstrapAsync.hasError ? bootstrapAsync.error : null);

    _scheduleBusinessSync(businessId);
    if (!bootstrapAsync.isLoading && businessId == null && _isInitialLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _isInitialLoading = false);
      });
    }

    final sharedProps = ProductDashboardViewProps(
      searchController: _searchController,
      scrollController: _scrollController,
      items: List<MenuItem>.unmodifiable(_items),
      categories: categories,
      isBootstrapLoading: bootstrapAsync.isLoading,
      categoriesLoading: categoriesAsync.isLoading && categories.isEmpty,
      categoryError: categoriesAsync.hasError ? categoriesAsync.error : null,
      selectedCategoryId: _selectedCategoryId,
      activeSearchQuery: _searchQuery,
      isInitialLoading: _isInitialLoading,
      isLoadingMore: _isLoadingMore,
      hasMore: _hasMore,
      hasLoadMoreError: _isLoadMoreError,
      totalCount: _totalCount,
      error: effectiveError,
      canManageProducts: canManageProducts,
      onSearchChanged: _handleSearchChanged,
      onClearSearch: _clearSearch,
      onSelectCategory: _selectCategory,
      onRetry: _refreshProducts,
      onRefresh: _refreshProducts,
      onLoadMore: _loadProducts,
      onAddProduct: _openAddProductForm,
      onOpenProduct: _openProductDetails,
      onDeleteProduct: _deleteProduct,
      selectedItem: _selectedItem,
      onSelectItem: (item) => setState(() => _selectedItem = item),
      onEditProduct: _editProduct,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return ProductDashboardTablet(props: sharedProps);
        }

        return ProductDashboardMobile(props: sharedProps);
      },
    );
  }
}
