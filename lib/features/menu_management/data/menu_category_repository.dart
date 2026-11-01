import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import '../domain/menu_category_models.dart';

class MenuCategoryRepository {
  MenuCategoryRepository(this._client);

  final SupabaseClient _client;
  static const String _tableName = 'menu_categories';

  Future<List<MenuCatalogCategory>> getCategories(String businessId) async {
    // 1. Cek offline lebih dulu: jika sedang offline dan ada data di SQLite, return dalam 0ms!
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final localCats = await LocalDatabaseService.instance.getMenuCategories(businessId);
        if (localCats.isNotEmpty) {
          debugPrint('[CategoryRepo] Offline mode: loaded ${localCats.length} categories from SQLite in 0ms');
          return localCats;
        }
      }
    } catch (_) {}

    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('business_id', businessId)
          .order('visual_index', ascending: true)
          .timeout(const Duration(seconds: 15));

      final categories = (response as List<dynamic>)
          .map((json) => MenuCatalogCategory.fromJson(json as Map<String, dynamic>))
          .toList();

      unawaited(LocalDatabaseService.instance.saveMenuCategories(businessId, categories));
      return categories;
    } catch (e) {
      debugPrint('[CategoryRepo] Online categories fetch failed ($e), falling back to local SQLite.');
      final localCats = await LocalDatabaseService.instance.getMenuCategories(businessId);
      return localCats;
    }
  }

  Future<void> upsertCategory(MenuCatalogCategory category) async {
    await _client.from(_tableName).upsert(category.toJson());
  }

  Future<void> deleteCategory(String id) async {
    await _client.from(_tableName).delete().eq('id', id);
  }

  Future<void> reorderCategories(List<MenuCatalogCategory> categories) async {
    final updates = categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      return category.copyWith(visualIndex: index).toJson();
    }).toList();

    await _client.from(_tableName).upsert(updates);
  }
}

final menuCategoryRepositoryProvider = Provider<MenuCategoryRepository>((ref) {
  return MenuCategoryRepository(SupabaseService.client);
});

final menuCategoriesProvider =
    AsyncNotifierProvider<MenuCategoryNotifier, List<MenuCatalogCategory>>(() {
  return MenuCategoryNotifier();
});

class MenuCategoryNotifier extends AsyncNotifier<List<MenuCatalogCategory>> {
  @override
  Future<List<MenuCatalogCategory>> build() async {
    // Watch bootstrap state to get current business ID
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;

    if (businessId == null) {
      return [];
    }

    return ref.watch(menuCategoryRepositoryProvider).getCategories(businessId);
  }

  String? get _businessId => ref.read(homeBootstrapProvider).value?.business?.id;

  Future<void> upsertCategory(MenuCatalogCategory category) async {
    final businessId = _businessId;
    if (businessId == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(menuCategoryRepositoryProvider).upsertCategory(category);
        return await ref.read(menuCategoryRepositoryProvider).getCategories(businessId);
      } catch (e, stack) {
        debugPrint('Error upserting category: $e');
        debugPrint('Stack trace: $stack');
        rethrow;
      }
    });
  }

  Future<void> deleteCategory(String id) async {
    final businessId = _businessId;
    if (businessId == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(menuCategoryRepositoryProvider).deleteCategory(id);
        return await ref.read(menuCategoryRepositoryProvider).getCategories(businessId);
      } catch (e, stack) {
        debugPrint('Error deleting category: $e');
        debugPrint('Stack trace: $stack');
        rethrow;
      }
    });
  }

  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    final businessId = _businessId;
    if (businessId == null) return;

    final categories = state.value;
    if (categories == null) return;

    final newList = List<MenuCatalogCategory>.from(categories);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(menuCategoryRepositoryProvider).reorderCategories(newList);
        return await ref.read(menuCategoryRepositoryProvider).getCategories(businessId);
      } catch (e, stack) {
        debugPrint('Error reordering categories: $e');
        debugPrint('Stack trace: $stack');
        rethrow;
      }
    });
  }
}
