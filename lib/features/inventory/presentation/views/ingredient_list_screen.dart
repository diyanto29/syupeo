import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/inventory/domain/ingredient_models.dart';
import 'package:dpos/features/inventory/data/ingredient_repository.dart';
import 'package:dpos/features/inventory/presentation/views/add_edit_ingredient_sheet.dart';

class IngredientListScreen extends ConsumerStatefulWidget {
  const IngredientListScreen({super.key});

  @override
  ConsumerState<IngredientListScreen> createState() => _IngredientListScreenState();
}

class _IngredientListScreenState extends ConsumerState<IngredientListScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAdjustStockDialog(Ingredient item) {
    final stockController = TextEditingController(text: item.currentStock.toStringAsFixed(1));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.tune_rounded, color: Colors.blue.shade700, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sesuaikan Stok',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Text(
              'Stok saat ini: ${item.currentStock.toStringAsFixed(1)} ${item.baseUnit}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Stok Fisik Baru (${item.baseUnit})',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: stockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Alasan / Catatan Opname',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Misal: Koreksi opname akhir shift',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final newStock = double.tryParse(stockController.text);
              if (newStock == null) return;
              final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
              final outletId = ref.read(homeBootstrapProvider).value?.currentOutlet?.id;
              if (businessId == null) return;

              Navigator.pop(ctx);
              await ref.read(ingredientRepositoryProvider).adjustStock(
                ingredientId: item.id,
                businessId: businessId,
                outletId: outletId,
                newStock: newStock,
                note: noteController.text.trim().isEmpty ? 'Penyesuaian stok manual' : noteController.text.trim(),
              );
              ref.invalidate(ingredientListProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stok bahan baku berhasil disesuaikan!')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0070FC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Bahan Baku Dapur & Bar',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(ingredientListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddEditIngredientSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Tambah Bahan',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF0070FC),
      ),
      body: ingredientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Gagal memuat bahan baku: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ingredientListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (ingredients) {
          // Filter by search & category
          final query = _searchController.text.trim().toLowerCase();
          final filtered = ingredients.where((item) {
            final matchesQuery = query.isEmpty ||
                item.name.toLowerCase().contains(query) ||
                (item.sku != null && item.sku!.toLowerCase().contains(query));
            final matchesCat = _selectedCategory == 'Semua' || item.category == _selectedCategory;
            return matchesQuery && matchesCat;
          }).toList();

          // Categories
          final allCats = <String>{'Semua'};
          for (final i in ingredients) {
            if (i.category != null && i.category!.isNotEmpty) {
              allCats.add(i.category!);
            }
          }

          return Column(
            children: [
              // Search & Filter header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari nama bahan baku, SKU...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: allCats.map((cat) {
                          final isSelected = cat == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0070FC).withValues(alpha: 0.15),
                              labelStyle: GoogleFonts.plusJakartaSans(
                                color: isSelected ? const Color(0xFF0070FC) : const Color(0xFF64748B),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Stats
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Menampilkan ${filtered.length} dari ${ingredients.length} bahan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // List of Ingredients
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              ingredients.isEmpty
                                  ? 'Belum ada bahan baku terdaftar.'
                                  : 'Tidak ada bahan yang cocok dengan pencarian.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            if (ingredients.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => AddEditIngredientSheet.show(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Bahan Pertama'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isOutOfStock = item.isOutOfStock;
                          final isLow = item.isLowStock;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isOutOfStock
                                    ? Colors.red.shade200
                                    : isLow
                                        ? Colors.orange.shade200
                                        : const Color(0xFFF1F5F9),
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.shade50
                                            : isLow
                                                ? Colors.orange.shade50
                                                : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_rounded,
                                        color: isOutOfStock
                                            ? Colors.red.shade700
                                            : isLow
                                                ? Colors.orange.shade700
                                                : Colors.green.shade700,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (item.category != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    item.category!,
                                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade700),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              if (item.sku != null && item.sku!.isNotEmpty)
                                                Text(
                                                  item.sku!,
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Stock Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.shade50
                                            : isLow
                                                ? Colors.amber.shade50
                                                : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isOutOfStock
                                              ? Colors.red.shade200
                                              : isLow
                                                  ? Colors.amber.shade300
                                                  : Colors.green.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        isOutOfStock
                                            ? 'HABIS'
                                            : isLow
                                                ? 'MENIPIS'
                                                : 'AMAN',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isOutOfStock
                                              ? Colors.red.shade800
                                              : isLow
                                                  ? Colors.amber.shade900
                                                  : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Sisa Stok', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.currentStock.toStringAsFixed(1)} ${item.baseUnit}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isOutOfStock
                                                ? Colors.red.shade700
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Harga per ${item.baseUnit}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          RupiahInputHelper.formatWithPrefix(item.costPerBaseUnit),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton.filledTonal(
                                          onPressed: () => _showAdjustStockDialog(item),
                                          icon: const Icon(Icons.tune_rounded, size: 18),
                                          tooltip: 'Opname Stok',
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton.filledTonal(
                                          onPressed: () => AddEditIngredientSheet.show(context, ingredient: item),
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          tooltip: 'Edit Bahan',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
