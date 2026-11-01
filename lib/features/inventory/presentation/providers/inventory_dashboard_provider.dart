import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/inventory/data/inventory_repository.dart';
import 'package:dpos/features/inventory/domain/inventory_models.dart';
import 'package:dpos/features/inventory/data/ingredient_repository.dart';

class LowStockEntry {
  const LowStockEntry({
    required this.name,
    required this.currentStock,
    required this.minStock,
    required this.unit,
    required this.isIngredient,
    this.id,
  });

  final String name;
  final double currentStock;
  final double minStock;
  final String unit;
  final bool isIngredient;
  final String? id;

  double get ratio {
    if (minStock <= 0) return currentStock <= 0 ? 0.0 : 1.0;
    return (currentStock / (minStock * 2)).clamp(0.0, 1.0);
  }
}

class InventoryDashboardData {
  const InventoryDashboardData({
    required this.totalProducts,
    required this.pendingPO,
    required this.lowStockItems,
    required this.totalQty,
    this.totalIngredients = 0,
    this.lowStockEntries = const [],
  });

  final int totalProducts;
  final int totalIngredients;
  final int pendingPO;
  final List<MenuItem> lowStockItems;
  final List<LowStockEntry> lowStockEntries;
  final int totalQty;
}

final inventoryDashboardDataProvider =
    Provider<AsyncValue<InventoryDashboardData>>((ref) {
      final menuItemsAsync = ref.watch(menuItemsProvider);
      final purchaseOrdersAsync = ref.watch(purchaseOrderListProvider);
      final ingredientsAsync = ref.watch(ingredientListProvider);

      return menuItemsAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (items) {
          return purchaseOrdersAsync.when(
            loading: () => const AsyncValue.loading(),
            error: (e, st) => AsyncValue.error(e, st),
            data: (pos) {
              final ingredients = ingredientsAsync.valueOrNull ?? [];
              final totalProducts = items
                  .where((i) => i.trackStockQuantity)
                  .length;
              final totalIngredients = ingredients.length;
              final productQty = items
                  .where((i) => i.trackStockQuantity)
                  .fold<double>(0.0, (sum, i) => sum + i.stockQuantity)
                  .round();
              final ingredientQty = ingredients
                  .fold<double>(0.0, (sum, i) => sum + i.currentStock)
                  .round();
              final totalQty = productQty + ingredientQty;
              final pendingPO = pos
                  .where((p) => p.status == PurchaseOrderStatus.pending)
                  .length;
              final lowStockItems = items
                  .where((i) => i.trackStockQuantity && i.stockQuantity <= 10)
                  .toList()
                ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

              final List<LowStockEntry> lowStockEntries = [];
              for (final p in lowStockItems) {
                lowStockEntries.add(LowStockEntry(
                  name: p.name,
                  currentStock: p.stockQuantity.toDouble(),
                  minStock: 10.0,
                  unit: p.displayUnit.isNotEmpty ? p.displayUnit : 'pcs',
                  isIngredient: false,
                  id: p.id,
                ));
              }
              for (final ing in ingredients) {
                if (ing.currentStock <= ing.minStockAlert ||
                    (ing.minStockAlert <= 0 && ing.currentStock <= 5)) {
                  lowStockEntries.add(LowStockEntry(
                    name: ing.name,
                    currentStock: ing.currentStock,
                    minStock: ing.minStockAlert > 0 ? ing.minStockAlert : 5.0,
                    unit: ing.baseUnit,
                    isIngredient: true,
                    id: ing.id,
                  ));
                }
              }
              lowStockEntries.sort((a, b) => a.ratio.compareTo(b.ratio));

              return AsyncValue.data(
                InventoryDashboardData(
                  totalProducts: totalProducts,
                  totalIngredients: totalIngredients,
                  pendingPO: pendingPO,
                  lowStockItems: lowStockItems,
                  lowStockEntries: lowStockEntries,
                  totalQty: totalQty,
                ),
              );
            },
          );
        },
      );
    });

