# Riverpod State Management Architecture Rule di DPOS

Seluruh manajemen state di aplikasi Flutter **DPOS (Mangga POS)** menggunakan **Flutter Riverpod** (`flutter_riverpod`). Dokumen ini mengatur pola desain, lifecycle provider, dan optimasi rebuild widget.

---

## 1. Aturan Penggunaan `ref.watch` vs `ref.read`

1. **Gunakan `ref.watch` HANYA di Dalam Method `build()` Widget:**
   - `ref.watch(provider)` digunakan untuk mendengarkan perubahan data agar widget merender ulang saat state berubah.
   - Gunakan `.select()` jika widget hanya bergantung pada sebagian kecil properti dari state besar untuk mencegah rebuild yang tidak perlu:
     ```dart
     // Contoh efisien: hanya rebuild jika total keranjang berubah
     final totalAmount = ref.watch(posStoreProvider.select((s) => s.totalAmount));
     ```
2. **Gunakan `ref.read` di Luar `build()` (Event Handlers & Callbacks):**
   - Dalam fungsi callback tombol (`onPressed`, `onTap`), gunakan `ref.read(provider.notifier)` untuk memanggil method aksi:
     ```dart
     onPressed: () {
       ref.read(posStoreProvider.notifier).addToCart(product);
     }
     ```
   - **Larangan Keras:** Dilarang menggunakan `ref.read` di dalam method `build()` widget karena tidak akan merespon perubahan state.

---

## 2. Struktur Provider & State Notifier

Setiap fitur yang membutuhkan state dinamis mendefinisikan StateNotifier dan Provider di folder `presentation/providers/`:

```dart
// 1. Immutable State Class
class ProductCatalogState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  const ProductCatalogState({
    this.products = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  ProductCatalogState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return ProductCatalogState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// 2. StateNotifier Controller
class ProductCatalogNotifier extends StateNotifier<ProductCatalogState> {
  final ProductRepository _repository;

  ProductCatalogNotifier(this._repository) : super(const ProductCatalogState()) {
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repository.getProducts();
      state = state.copyWith(products: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }
}

// 3. Provider Definition
final productCatalogProvider = StateNotifierProvider<ProductCatalogNotifier, ProductCatalogState>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return ProductCatalogNotifier(repo);
});
```

---

## 3. Aturan AutoDispose & Caching

1. **AutoDispose untuk Layar Transien:**
   - Gunakan `.autoDispose` pada provider yang hanya aktif ketika layar tertentu terbuka (misal: formulir tambah produk, filter laporan tanggal, scanner barcode) agar memory dibebaskan saat user keluar dari layar:
     ```dart
     final addProductFormProvider = StateNotifierProvider.autoDispose<...>((ref) => ...);
     ```
2. **Provider Global Tanpa AutoDispose:**
   - Provider keranjang kasir (`posStoreProvider`), autentikasi user (`authProvider`), dan profil bisnis toko (`businessProfileProvider`) tetap hidup selama sesi aplikasi berjalan agar transaksi yang sedang berlangsung tidak hilang.
