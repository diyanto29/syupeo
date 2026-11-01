import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/subscription/domain/wholesale_item_model.dart';

class WholesaleCatalogState {
  final List<WholesaleItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final String searchQuery;
  final String selectedCategory;
  final List<String> categories;
  final int page;

  const WholesaleCatalogState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCategory = 'Semua',
    this.categories = const [
      'Semua',
      'SEMBAKO',
      'MAKANAN INSTAN',
      'MINUMAN',
      'AIR MINERAL',
      'BEAUTY & PERAWATAN',
      'AKSESORI GEN Z',
      'KEBUTUHAN RUMAH',
    ],
    this.page = 0,
  });

  WholesaleCatalogState copyWith({
    List<WholesaleItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    String? searchQuery,
    String? selectedCategory,
    List<String>? categories,
    int? page,
  }) {
    return WholesaleCatalogState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      categories: categories ?? this.categories,
      page: page ?? this.page,
    );
  }
}

class WholesaleCatalogNotifier extends StateNotifier<WholesaleCatalogState> {
  WholesaleCatalogNotifier() : super(const WholesaleCatalogState()) {
    init();
  }

  static const int pageSize = 20;
  Timer? _debounceTimer;

  Future<void> init() async {
    await fetchCategories();
    await loadInitial();
  }

  /// Ambil daftar kategori unik dari master_catalog
  Future<void> fetchCategories() async {
    try {
      final res = await SupabaseService.client
          .from('master_catalog')
          .select('category')
          .not('category', 'is', null)
          .limit(200);

      final catSet = <String>{};
      for (final row in res as List<dynamic>) {
        final cat = (row['category'] as String?)?.trim();
        if (cat != null && cat.isNotEmpty) {
          catSet.add(cat);
        }
      }

      if (catSet.isNotEmpty) {
        final sorted = catSet.toList()..sort();
        state = state.copyWith(categories: ['Semua', ...sorted]);
      }
    } catch (e) {
      debugPrint('[WholesaleCatalog] fetchCategories note: $e');
    }
  }

  /// Load halaman pertama (Page 0)
  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null, page: 0);

    try {
      final items = await _fetchFromDatabase(
        offset: 0,
        limit: pageSize,
        query: state.searchQuery,
        category: state.selectedCategory,
      );

      state = state.copyWith(
        items: items,
        isLoading: false,
        isLoadingMore: false,
        hasMore: items.length >= pageSize,
        page: 1,
      );
    } catch (e) {
      debugPrint('[WholesaleCatalog] loadInitial error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat katalog kulakan: $e',
      );
    }
  }

  /// Lazy loading halaman berikutnya saat pengguna scroll mendekati bawah
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final offset = state.page * pageSize;
      final newItems = await _fetchFromDatabase(
        offset: offset,
        limit: pageSize,
        query: state.searchQuery,
        category: state.selectedCategory,
      );

      final existingIds = state.items.map((i) => i.id).toSet();
      final deduplicated = newItems.where((i) => !existingIds.contains(i.id)).toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        isLoadingMore: false,
        hasMore: newItems.length >= pageSize,
        page: state.page + 1,
      );
    } catch (e) {
      debugPrint('[WholesaleCatalog] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Ubah pencarian dengan debounce 400ms
  void setSearchQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (state.searchQuery != query) {
        state = state.copyWith(searchQuery: query);
        loadInitial();
      }
    });
  }

  /// Ubah filter kategori
  void setCategory(String category) {
    if (state.selectedCategory != category) {
      state = state.copyWith(selectedCategory: category);
      loadInitial();
    }
  }

  /// Refresh manual
  Future<void> refresh() async {
    await fetchCategories();
    await loadInitial();
  }

  /// Query ke tabel master_catalog di Supabase
  Future<List<WholesaleItem>> _fetchFromDatabase({
    required int offset,
    required int limit,
    required String query,
    required String category,
  }) async {
    final client = SupabaseService.client;
    var builder = client.from('master_catalog').select('*');

    // Filter Kategori
    if (category != 'Semua') {
      builder = builder.ilike('category', '%${category.trim()}%');
    }

    // Filter Pencarian (nama, barcode, brand)
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = _escapeFilterValue(trimmedQuery);
      final pattern = '%$escaped%';
      builder = builder.or(
        'name.ilike.$pattern,barcode.ilike.$pattern,brand.ilike.$pattern,category.ilike.$pattern',
      );
    }

    final response = await builder
        .order('name', ascending: true)
        .range(offset, offset + limit - 1);

    final rows = response as List<dynamic>;
    return rows.map((r) => WholesaleItem.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  String _escapeFilterValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final wholesaleCatalogProvider =
    StateNotifierProvider.autoDispose<WholesaleCatalogNotifier, WholesaleCatalogState>((ref) {
  return WholesaleCatalogNotifier();
});

