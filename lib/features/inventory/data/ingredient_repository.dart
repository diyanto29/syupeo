import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/inventory/domain/ingredient_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

class IngredientRepository {
  IngredientRepository(this._client);
  final SupabaseClient _client;

  /// Fetch all active ingredients for a business
  Future<List<Ingredient>> getIngredients(String businessId, {String? category}) async {
    var query = _client
        .from('inventory_ingredients')
        .select('*')
        .eq('business_id', businessId)
        .eq('is_active', true);

    if (category != null && category.isNotEmpty && category != 'Semua') {
      query = query.eq('category', category);
    }

    final response = await query.order('name', ascending: true);
    return (response as List<dynamic>)
        .map((json) => Ingredient.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create or update an ingredient
  Future<Ingredient> saveIngredient(Ingredient ingredient) async {
    final payload = ingredient.toJson();
    if (ingredient.id.isEmpty) {
      payload.remove('id');
    }
    final response = await _client
        .from('inventory_ingredients')
        .upsert(payload)
        .select()
        .single();
    return Ingredient.fromJson(response);
  }

  /// Soft delete an ingredient
  Future<void> deleteIngredient(String id) async {
    await _client
        .from('inventory_ingredients')
        .update({'is_active': false})
        .eq('id', id);
  }

  /// Adjust stock manually or opname
  Future<void> adjustStock({
    required String ingredientId,
    required String businessId,
    String? outletId,
    required double newStock,
    required String note,
    String movementType = 'adjustment',
  }) async {
    // 1. Get current stock
    final current = await _client
        .from('inventory_ingredients')
        .select('current_stock')
        .eq('id', ingredientId)
        .single();
    final currentStock = (current['current_stock'] as num?)?.toDouble() ?? 0.0;
    final delta = newStock - currentStock;
    if (delta == 0) return;

    // 2. Update ingredient current_stock
    await _client
        .from('inventory_ingredients')
        .update({'current_stock': newStock, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', ingredientId);

    // 3. Record in ingredient_movements
    await _client.from('ingredient_movements').insert({
      'business_id': businessId,
      'outlet_id': outletId,
      'ingredient_id': ingredientId,
      'movement_type': movementType,
      'quantity_delta': delta,
      'balance_after': newStock,
      'note': note,
      'performed_by': _client.auth.currentUser?.id,
    });
  }

  /// Fetch recipes for a specific menu item (optionally filtered by variant)
  Future<List<MenuItemRecipe>> getRecipesForMenuItem(String menuItemId, {String? variantId}) async {
    var query = _client
        .from('menu_item_recipes')
        .select('*, inventory_ingredients(*)')
        .eq('menu_item_id', menuItemId);

    if (variantId != null && variantId.isNotEmpty) {
      query = query.or('variant_id.eq.$variantId,variant_id.is.null');
    }

    final response = await query;

    return (response as List<dynamic>)
        .map((json) => MenuItemRecipe.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Save / Replace all recipes for a menu item (or a specific variant) and update menu_items.recipe_cost
  Future<void> saveRecipesForMenuItem({
    required String businessId,
    required String menuItemId,
    String? variantId,
    required List<MenuItemRecipe> recipes,
  }) async {
    // 1. Delete old recipes for this specific variant (or default recipes if variantId is null)
    var deleteQuery = _client
        .from('menu_item_recipes')
        .delete()
        .eq('menu_item_id', menuItemId);

    if (variantId != null && variantId.isNotEmpty) {
      deleteQuery = deleteQuery.eq('variant_id', variantId);
    } else {
      deleteQuery = deleteQuery.filter('variant_id', 'is', 'null');
    }
    await deleteQuery;

    // 2. Insert new recipes
    double calculatedTotalHpp = 0.0;
    if (recipes.isNotEmpty) {
      final payload = recipes.map((r) {
        final map = r.toJson();
        if (r.id.isEmpty) map.remove('id');
        calculatedTotalHpp += r.subtotalCost;
        return map;
      }).toList();
      await _client.from('menu_item_recipes').insert(payload);
    }

    // 3. Update recipe_cost on menu_items directly if default recipe
    if (variantId == null || variantId.isEmpty) {
      await _client.from('menu_items').update({
        'recipe_cost': calculatedTotalHpp,
      }).eq('id', menuItemId);
    }
  }

  /// Auto-deduct raw ingredients when an order with recipes is completed
  Future<void> deductIngredientsForOrder({
    required List<TransactionItem> items,
    required String businessId,
    String? outletId,
    required String orderId,
  }) async {
    for (final item in items) {
      final menuItemId = item.menuItemId;
      if (menuItemId == null || menuItemId.isEmpty) continue;

      // Find if this menu item has recipes
      final recipes = await getRecipesForMenuItem(menuItemId);
      if (recipes.isEmpty) continue;

      for (final recipe in recipes) {
        final totalNeeded = recipe.quantityRequired * item.quantity;
        // Fetch current stock
        final ingData = await _client
            .from('inventory_ingredients')
            .select('current_stock')
            .eq('id', recipe.ingredientId)
            .maybeSingle();
        if (ingData == null) continue;

        final currentStock = (ingData['current_stock'] as num?)?.toDouble() ?? 0.0;
        final newStock = currentStock - totalNeeded;

        // Update ingredient stock
        await _client.from('inventory_ingredients').update({
          'current_stock': newStock,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', recipe.ingredientId);

        // Record movement
        await _client.from('ingredient_movements').insert({
          'business_id': businessId,
          'outlet_id': outletId,
          'ingredient_id': recipe.ingredientId,
          'movement_type': 'out_recipe_deduction',
          'quantity_delta': -totalNeeded,
          'balance_after': newStock,
          'note': 'Pemakaian resep menu: ${item.name} (x${item.quantity})',
          'reference_id': orderId,
          'performed_by': _client.auth.currentUser?.id,
        });
      }
    }
  }

  /// Fetch ingredient stock movements / history
  Future<List<IngredientMovement>> getIngredientMovements({
    required String businessId,
    String? ingredientId,
    int limit = 50,
  }) async {
    var query = _client
        .from('ingredient_movements')
        .select('*, inventory_ingredients(*)')
        .eq('business_id', businessId);

    if (ingredientId != null && ingredientId.isNotEmpty) {
      query = query.eq('ingredient_id', ingredientId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) => IngredientMovement.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  return IngredientRepository(SupabaseService.client);
});

final ingredientListProvider = FutureProvider.autoDispose<List<Ingredient>>((ref) async {
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final businessId = bootstrap?.business?.id;
  if (businessId == null) return [];
  return ref.read(ingredientRepositoryProvider).getIngredients(businessId);
});

final menuItemRecipesProvider = FutureProvider.family.autoDispose<List<MenuItemRecipe>, String>(
  (ref, menuItemId) async {
    if (menuItemId.isEmpty) return [];
    return ref.read(ingredientRepositoryProvider).getRecipesForMenuItem(menuItemId);
  },
);
