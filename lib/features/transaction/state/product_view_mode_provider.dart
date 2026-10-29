import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opsi tampilan daftar produk di kasir / transaksi (Grid vs List).
enum ProductViewMode {
  grid,
  list;

  bool get isGrid => this == ProductViewMode.grid;
  bool get isList => this == ProductViewMode.list;
}

class ProductViewModeNotifier extends StateNotifier<ProductViewMode> {
  ProductViewModeNotifier() : super(ProductViewMode.grid) {
    _loadFromPrefs();
  }

  static const _prefKey = 'pos_product_catalog_view_mode';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'list') {
        state = ProductViewMode.list;
      } else if (saved == 'grid') {
        state = ProductViewMode.grid;
      }
    } catch (_) {
      // Abaikan jika preferensi belum ada
    }
  }

  Future<void> setMode(ProductViewMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setMode(state == ProductViewMode.grid ? ProductViewMode.list : ProductViewMode.grid);
  }
}

final productViewModeProvider =
    StateNotifierProvider<ProductViewModeNotifier, ProductViewMode>((ref) {
  return ProductViewModeNotifier();
});
