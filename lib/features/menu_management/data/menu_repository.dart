import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dpos/core/supabase/supabase_service.dart';

import '../domain/menu_models.dart';

class MenuRepository {
  MenuRepository(this._client);

  final SupabaseClient _client;
  static const String _tableName = 'menu_items';
  static const String _imageBucketName = 'menu-item-images';
  static const String _selectFields =
      '*, menu_category:menu_categories!menu_items_category_id_fkey(*), menu_item_variants(*), menu_item_tiered_prices(*)';

  Future<List<MenuItem>> getMenuItems(String businessId) async {
    // 1. Cek offline lebih dulu: jika sedang offline dan ada cache SQLite, return dalam 0ms!
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final cached = await LocalDatabaseService.instance.getMenuItems(businessId);
        if (cached.isNotEmpty) {
          debugPrint('[MenuRepo] Offline mode: loaded ${cached.length} items from SQLite in 0ms');
          return cached;
        }
      }
    } catch (_) {}

    try {
      final response = await _client
          .from(_tableName)
          .select(_selectFields)
          .eq('business_id', businessId)
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 15));

      final items = (response as List<dynamic>)
          .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache to local SQLite for offline use
      unawaited(LocalDatabaseService.instance.saveMenuItems(items));
      return items;
    } catch (e) {
      debugPrint('[MenuRepo] Network fetch with relations failed ($e), attempting fallback query...');
      try {
        final fallbackResponse = await _client
            .from(_tableName)
            .select('*')
            .eq('business_id', businessId)
            .order('name', ascending: true)
            .timeout(const Duration(seconds: 10));

        final items = (fallbackResponse as List<dynamic>)
            .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
            .toList();

        unawaited(LocalDatabaseService.instance.saveMenuItems(items));
        return items;
      } catch (e2) {
        debugPrint('[MenuRepo] Fallback query also failed: $e2');
      }

      debugPrint('[MenuRepo] Falling back to local SQLite cache.');
      final cached = await LocalDatabaseService.instance.getMenuItems(businessId);
      if (cached.isNotEmpty) {
        return cached;
      }
      return const [];
    }
  }

  Future<MenuItemsPage> getMenuItemsPage(
    String businessId, {
    int limit = 20,
    int offset = 0,
    String searchQuery = '',
    String? categoryId,
  }) async {
    final trimmedSearch = searchQuery.trim();

    try {
      var query = _client
          .from(_tableName)
          .select(_selectFields)
          .eq('business_id', businessId);

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }

      if (trimmedSearch.isNotEmpty) {
        query = query.or(_buildSearchFilter(trimmedSearch));
      }

      final response = await query
          .order('updated_at', ascending: false)
          .order('name', ascending: true)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);

      final items = (response.data as List<dynamic>)
          .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
          .toList();
      final nextOffset = offset + items.length;
      final total = response.count;
      final hasMore = nextOffset < total;

      // Cache page items to SQLite in background
      unawaited(LocalDatabaseService.instance.saveMenuItems(items));

      return MenuItemsPage(
        items: items,
        totalCount: total,
        nextOffset: nextOffset,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('[MenuRepo] getMenuItemsPage online failed ($e), falling back to SQLite');
      final allCached = await LocalDatabaseService.instance.getMenuItems(businessId);
      var filtered = allCached;
      if (categoryId != null && categoryId.isNotEmpty) {
        filtered = filtered.where((item) => item.categoryId == categoryId).toList();
      }
      if (trimmedSearch.isNotEmpty) {
        final queryLower = trimmedSearch.toLowerCase();
        filtered = filtered.where((item) {
          return item.name.toLowerCase().contains(queryLower) ||
              (item.barcode?.toLowerCase().contains(queryLower) ?? false) ||
              (item.sku?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }
      final paged = filtered.skip(offset).take(limit).toList();
      final nextOffset = offset + paged.length;
      return MenuItemsPage(
        items: paged,
        totalCount: filtered.length,
        nextOffset: nextOffset,
        hasMore: nextOffset < filtered.length,
      );
    }
  }

  Future<MenuItem?> getMenuItemById(String id) async {
    final response = await _client
        .from(_tableName)
        .select(_selectFields)
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return MenuItem.fromJson(response);
  }

  Future<void> upsertMenuItem(
    MenuItem item, {
    String? outletId,
    MenuItem? previousItem,
    String? inventoryNote,
  }) async {
    final persistedStockQuantity = _resolvePersistedStockQuantity(
      item,
      previousItem,
    );

    // 1. Upsert the main item with valid table columns only (mencegah error PGRST204)
    await _client
        .from(_tableName)
        .upsert(item.copyWith(stockQuantity: persistedStockQuantity).toDatabaseJson());

    // 2. Sync variants so removed rows do not linger after editing.
    await _client
        .from('menu_item_variants')
        .delete()
        .eq('menu_item_id', item.id);

    if (item.variants.isNotEmpty) {
      final variantsJson = item.variants.map((v) {
        final data = v.toDatabaseJson();
        data['menu_item_id'] = item.id;
        final bizId = (data['business_id'] as String?)?.trim();
        if (bizId == null || bizId.isEmpty) {
          data['business_id'] = item.businessId;
        }
        return data;
      }).toList();
      await _client.from('menu_item_variants').upsert(variantsJson);
    }

    // 3. Sync tiered prices
    await _client
        .from('menu_item_tiered_prices')
        .delete()
        .eq('menu_item_id', item.id);

    if (item.tieredPrices.isNotEmpty) {
      final tieredPricesJson = item.tieredPrices.map((t) => {
        ...t.toJson(),
        'menu_item_id': item.id,
        'business_id': item.businessId,
      }).toList();
      await _client.from('menu_item_tiered_prices').upsert(tieredPricesJson);
    }

    // 4. Sync package items (safe try-catch if table does not exist)
    try {
      await _client
          .from('menu_package_items')
          .delete()
          .eq('package_menu_item_id', item.id);

      if (item.isPackage && item.packageItems.isNotEmpty) {
        final packageItemsJson = item.packageItems.map((p) => {
          'package_menu_item_id': item.id,
          'component_menu_item_id': p.componentMenuItemId,
          'quantity': p.quantity,
        }).toList();
        await _client.from('menu_package_items').insert(packageItemsJson);
      }
    } catch (_) {
      // Table may not exist yet in database
    }

    if (outletId != null && _shouldSyncTrackedStock(item, previousItem)) {
      await adjustMenuItemStock(
        menuItemId: item.id,
        outletId: outletId,
        newQuantity: item.stockQuantity,
        note: inventoryNote,
      );
    }
  }

  Future<void> deleteMenuItem(String id, {String? imageUrl}) async {
    final objectPath = imageUrl == null
        ? null
        : extractProductImageObjectPath(imageUrl);

    if (objectPath != null) {
      await deleteProductImage(objectPath);
    }

    await _client.from(_tableName).delete().eq('id', id);
  }

  Future<void> toggleVariantStock(String variantId, bool currentStatus) async {
    await _client
        .from('menu_item_variants')
        .update({'stock_available': !currentStatus})
        .eq('id', variantId);
  }

  Future<void> adjustMenuItemStock({
    required String menuItemId,
    required String outletId,
    required num newQuantity,
    String? note,
    String referenceType = 'manual_adjustment',
  }) async {
    // 1. Update stock in local SQLite immediately
    await LocalDatabaseService.instance.updateLocalStock(menuItemId, newQuantity);

    // 2. Try calling server RPC if online
    try {
      await _client.rpc(
        'adjust_menu_item_stock',
        params: {
          'target_menu_item_id': menuItemId,
          'target_outlet_id': outletId,
          'target_new_quantity': newQuantity,
          'target_note': note,
          'target_reference_type': referenceType,
        },
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[MenuRepo] Remote adjust_menu_item_stock failed ($e) - attempting direct table update.');
      try {
        await _client.from('menu_items').update({
          'stock_quantity': newQuantity,
          'stock_available': newQuantity > 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', menuItemId);
      } catch (e2) {
        debugPrint('[MenuRepo] Direct stock update also failed ($e2) - stock updated locally.');
      }
    }
  }

  Future<List<InventoryMovement>> getInventoryMovements(
    String menuItemId, {
    required String outletId,
    int limit = 10,
  }) async {
    final response = await _client
        .from('inventory_movements')
        .select()
        .eq('menu_item_id', menuItemId)
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) => InventoryMovement.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryMovement?> getLatestInventoryMovement(
    String menuItemId, {
    required String outletId,
  }) async {
    final movements = await getInventoryMovements(
      menuItemId,
      outletId: outletId,
      limit: 1,
    );
    return movements.isEmpty ? null : movements.first;
  }

  Future<UploadedMenuItemImage> uploadProductImage({
    required String businessId,
    required String menuItemId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final sanitizedBusinessId = businessId.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9-]'),
      '_',
    );
    final extension = _extractFileExtension(fileName, contentType);
    final objectPath =
        '$sanitizedBusinessId/$menuItemId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final resolvedContentType =
        lookupMimeType(fileName, headerBytes: bytes) ?? contentType;

    await _client.storage
        .from(_imageBucketName)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: resolvedContentType,
          ),
        );

    return UploadedMenuItemImage(
      objectPath: objectPath,
      publicUrl: _client.storage
          .from(_imageBucketName)
          .getPublicUrl(objectPath),
    );
  }

  Future<void> deleteProductImage(String objectPath) {
    return _client.storage.from(_imageBucketName).remove([objectPath]);
  }

  String? extractProductImageObjectPath(String publicUrl) {
    final normalized = publicUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }

    const markers = ['/storage/v1/object/public/', '/storage/v1/object/sign/'];

    String? objectPath;
    for (final marker in markers) {
      final markerWithBucket = '$marker$_imageBucketName/';
      final markerIndex = normalized.indexOf(markerWithBucket);
      if (markerIndex == -1) {
        continue;
      }

      objectPath = normalized.substring(markerIndex + markerWithBucket.length);
      break;
    }

    if (objectPath == null || objectPath.isEmpty) {
      return null;
    }

    final cleanPath = objectPath.split('?').first;
    return cleanPath.isEmpty ? null : Uri.decodeComponent(cleanPath);
  }

  String _extractFileExtension(String fileName, String contentType) {
    final normalizedFileName = fileName.toLowerCase().trim();
    final dotIndex = normalizedFileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < normalizedFileName.length - 1) {
      return normalizedFileName.substring(dotIndex + 1);
    }

    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
        return 'bmp';
      case 'image/tiff':
        return 'tiff';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  String _buildSearchFilter(String query) {
    final escaped = _escapeFilterValue(query);
    final pattern = '%$escaped%';
    return [
      'name.ilike.$pattern',
      'barcode.ilike.$pattern',
      'sku.ilike.$pattern',
      'description.ilike.$pattern',
    ].join(',');
  }

  String _escapeFilterValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  num _resolvePersistedStockQuantity(MenuItem item, MenuItem? previousItem) {
    if (!item.trackStockQuantity) {
      return previousItem?.stockQuantity ?? 0;
    }

    if (previousItem == null) {
      return 0;
    }

    if (!previousItem.trackStockQuantity) {
      return 0;
    }

    if (item.stockQuantity != previousItem.stockQuantity) {
      return previousItem.stockQuantity;
    }

    return item.stockQuantity;
  }

  bool _shouldSyncTrackedStock(MenuItem item, MenuItem? previousItem) {
    if (!item.trackStockQuantity) {
      return false;
    }

    if (previousItem == null) {
      return item.stockQuantity > 0;
    }

    if (!previousItem.trackStockQuantity) {
      return item.stockQuantity > 0;
    }

    return item.stockQuantity != previousItem.stockQuantity;
  }
}

class UploadedMenuItemImage {
  const UploadedMenuItemImage({
    required this.objectPath,
    required this.publicUrl,
  });

  final String objectPath;
  final String publicUrl;
}

class MenuItemsPage {
  const MenuItemsPage({
    required this.items,
    required this.totalCount,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<MenuItem> items;
  final int totalCount;
  final int nextOffset;
  final bool hasMore;
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(SupabaseService.client);
});

final menuItemsProvider = AsyncNotifierProvider<MenuNotifier, List<MenuItem>>(
  () {
    return MenuNotifier();
  },
);

class MenuNotifier extends AsyncNotifier<List<MenuItem>> {
  @override
  Future<List<MenuItem>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;

    if (businessId == null) {
      return [];
    }

    return ref.watch(menuRepositoryProvider).getMenuItems(businessId);
  }

  String? get _businessId =>
      ref.read(homeBootstrapProvider).value?.business?.id;

  String? get _currentOutletId =>
      ref.read(homeBootstrapProvider).value?.currentOutlet?.id;

  Future<void> toggleStock(String id) async {
    final businessId = _businessId;
    if (businessId == null) return;

    final currentState = state.value;
    if (currentState == null) return;

    final index = currentState.indexWhere((item) => item.id == id);
    if (index != -1) {
      final updatedItem = currentState[index].copyWith(
        stockAvailable: !currentState[index].stockAvailable,
      );

      final updatedList = List<MenuItem>.from(currentState);
      updatedList[index] = updatedItem;
      // Optimistic update: UI changes immediately in 0 ms
      state = AsyncValue.data(updatedList);

      try {
        await ref.read(menuRepositoryProvider).upsertMenuItem(updatedItem);
      } catch (e, stack) {
        // Revert on failure
        state = AsyncValue.data(currentState);
        debugPrint('Error toggling stock: $e');
        debugPrint('Stack trace: $stack');
        rethrow;
      }
    }
  }

  Future<void> toggleVariantStock(String itemId, String variantId) async {
    final businessId = _businessId;
    if (businessId == null) return;

    final currentState = state.value;
    if (currentState == null) return;

    final itemIndex = currentState.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;

    final item = currentState[itemIndex];
    final variantIndex = item.variants.indexWhere((v) => v.id == variantId);
    if (variantIndex == -1) return;

    final variant = item.variants[variantIndex];
    final updatedVariants = List<MenuItemVariant>.from(item.variants);
    updatedVariants[variantIndex] = variant.copyWith(
      stockAvailable: !variant.stockAvailable,
    );
    final updatedItem = item.copyWith(variants: updatedVariants);
    final updatedList = List<MenuItem>.from(currentState);
    updatedList[itemIndex] = updatedItem;

    // Optimistic update: UI changes immediately in 0 ms
    state = AsyncValue.data(updatedList);

    try {
      await ref
          .read(menuRepositoryProvider)
          .toggleVariantStock(variantId, variant.stockAvailable);
    } catch (e, stack) {
      // Revert on failure
      state = AsyncValue.data(currentState);
      debugPrint('Error toggling variant stock: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> upsertItem(
    MenuItem item, {
    MenuItem? previousItem,
    String? inventoryNote,
  }) async {
    final businessId = _businessId;
    if (businessId == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(menuRepositoryProvider)
            .upsertMenuItem(
              item,
              outletId: _currentOutletId,
              previousItem: previousItem,
              inventoryNote: inventoryNote,
            );
        return await ref.read(menuRepositoryProvider).getMenuItems(businessId);
      } catch (e, stack) {
        debugPrint('Error upserting menu item: $e');
        debugPrint('Stack trace: $stack');
        rethrow;
      }
    });
  }

  Future<void> deleteItem(String id, {String? imageUrl}) async {
    final businessId = _businessId;
    if (businessId == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(menuRepositoryProvider)
            .deleteMenuItem(id, imageUrl: imageUrl);
        return await ref.read(menuRepositoryProvider).getMenuItems(businessId);
      } catch (e, stack) {
        debugPrint('Error deleting menu item: $e');
        debugPrint('Stack trace: $stack');
        rethrow;
      }
    });
  }
}
