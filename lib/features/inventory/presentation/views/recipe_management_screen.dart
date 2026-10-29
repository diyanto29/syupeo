import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/inventory/domain/ingredient_models.dart';
import 'package:dpos/features/inventory/data/ingredient_repository.dart';

class RecipeManagementScreen extends ConsumerStatefulWidget {
  const RecipeManagementScreen({super.key, this.initialMenuItem});

  final MenuItem? initialMenuItem;

  @override
  ConsumerState<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends ConsumerState<RecipeManagementScreen> {
  MenuItem? _selectedMenuItem;
  String? _selectedVariantId;
  final List<MenuItemRecipe> _recipeItems = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMenuItem = widget.initialMenuItem;
    if (_selectedMenuItem != null) {
      _loadRecipesForMenuItem(_selectedMenuItem!.id);
    }
  }

  Future<void> _loadRecipesForMenuItem(String menuItemId, {String? variantId}) async {
    setState(() => _isLoading = true);
    try {
      final recipes = await ref.read(ingredientRepositoryProvider).getRecipesForMenuItem(menuItemId, variantId: variantId);
      if (mounted) {
        setState(() {
          _recipeItems.clear();
          if (variantId != null && variantId.isNotEmpty) {
            final varRecipes = recipes.where((r) => r.variantId == variantId).toList();
            if (varRecipes.isNotEmpty) {
              _recipeItems.addAll(varRecipes);
            } else {
              // Salin bahan dari resep default jika varian belum punya resep khusus
              _recipeItems.addAll(
                recipes.where((r) => r.variantId == null).map((r) => r.copyWith(variantId: variantId)),
              );
            }
          } else {
            _recipeItems.addAll(recipes.where((r) => r.variantId == null));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat resep: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalHpp {
    double sum = 0.0;
    for (final r in _recipeItems) {
      sum += r.subtotalCost;
    }
    return sum;
  }

  double get _sellingPrice => _selectedMenuItem?.price ?? 0.0;
  double get _grossProfit => _sellingPrice - _totalHpp;
  double get _foodCostPercentage => _sellingPrice > 0 ? (_totalHpp / _sellingPrice) * 100 : 0.0;
  double get _marginPercentage => _sellingPrice > 0 ? (_grossProfit / _sellingPrice) * 100 : 0.0;

  void _showAddIngredientPickerSheet(List<Ingredient> allIngredients) {
    if (allIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada bahan baku. Tambah bahan baku terlebih dahulu di menu Bahan Baku.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Bahan Baku',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: allIngredients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ing = allIngredients[index];
                    final alreadyAdded = _recipeItems.any((r) => r.ingredientId == ing.id);

                    return ListTile(
                      title: Text(ing.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${ing.category ?? "-"} • Biaya: ${RupiahInputHelper.formatWithPrefix(ing.costPerBaseUnit)} / ${ing.baseUnit}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                      trailing: alreadyAdded
                          ? const Chip(label: Text('Sudah Ada', style: TextStyle(fontSize: 11)))
                          : IconButton.filledTonal(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _promptQuantityDialog(ing);
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _promptQuantityDialog(Ingredient ingredient, {MenuItemRecipe? existing}) {
    final qtyController = TextEditingController(
      text: existing != null ? existing.quantityRequired.toStringAsFixed(1) : '10',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Takaran Resep',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ingredient.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
            Text(
              'Biaya per ${ingredient.baseUnit}: ${RupiahInputHelper.formatWithPrefix(ingredient.costPerBaseUnit)}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Jumlah Takaran (${ingredient.baseUnit})',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                suffixText: ingredient.baseUnit,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0.0;
              if (qty <= 0) return;
              Navigator.pop(ctx);

              setState(() {
                if (existing != null) {
                  final idx = _recipeItems.indexWhere((r) => r.ingredientId == ingredient.id);
                  if (idx != -1) {
                    _recipeItems[idx] = existing.copyWith(quantityRequired: qty);
                  }
                } else {
                  final businessId = ref.read(homeBootstrapProvider).value?.business?.id ?? '';
                  _recipeItems.add(
                    MenuItemRecipe(
                      id: '',
                      businessId: businessId,
                      menuItemId: _selectedMenuItem?.id ?? '',
                      variantId: _selectedVariantId,
                      ingredientId: ingredient.id,
                      quantityRequired: qty,
                      unit: ingredient.baseUnit,
                      ingredient: ingredient,
                    ),
                  );
                }
              });
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7A00)),
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveRecipe() async {
    if (_selectedMenuItem == null) return;

    final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(ingredientRepositoryProvider).saveRecipesForMenuItem(
        businessId: businessId,
        menuItemId: _selectedMenuItem!.id,
        variantId: _selectedVariantId,
        recipes: _recipeItems,
      );

      ref.invalidate(menuItemsProvider);
      ref.invalidate(menuItemRecipesProvider(_selectedMenuItem!.id));

      if (mounted) {
        final variantLabel = _selectedVariantId != null ? ' (Varian Khusus)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resep untuk ${_selectedMenuItem!.name}$variantLabel berhasil disimpan!'),
            backgroundColor: const Color(0xFFFF7A00),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan resep: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final ingredientsAsync = ref.watch(ingredientListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Resep & HPP Menu (BOM)',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: _selectedMenuItem == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total HPP Resep',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          Text(
                            RupiahInputHelper.formatWithPrefix(_totalHpp),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _handleSaveRecipe,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Resep'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menu Item Selector
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PILIH PRODUK / MENU',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  menuItemsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Gagal memuat menu: $e'),
                    data: (menuItems) {
                      return DropdownButtonFormField<MenuItem>(
                        value: _selectedMenuItem != null
                            ? menuItems.cast<MenuItem?>().firstWhere(
                                  (m) => m?.id == _selectedMenuItem?.id,
                                  orElse: () => null,
                                )
                            : null,
                        hint: const Text('Pilih item menu untuk atur resep'),
                        isExpanded: true,
                        items: menuItems.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Row(
                              children: [
                                Text(item.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text(
                                  RupiahInputHelper.formatWithPrefix(item.price),
                                  style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (item) {
                          if (item != null) {
                            setState(() {
                              _selectedMenuItem = item;
                              _selectedVariantId = null;
                            });
                            _loadRecipesForMenuItem(item.id);
                          }
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      );
                    },
                  ),
                  if (_selectedMenuItem != null && _selectedMenuItem!.variants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'PILIH VARIAN RESEP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Resep Dasar (Default)'),
                            selected: _selectedVariantId == null,
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedVariantId == null ? Colors.white : const Color(0xFF475569),
                            ),
                            onSelected: (_) {
                              setState(() => _selectedVariantId = null);
                              _loadRecipesForMenuItem(_selectedMenuItem!.id, variantId: null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._selectedMenuItem!.variants.map((v) {
                            final isSelected = _selectedVariantId == v.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Varian: ${v.name}'),
                                selected: isSelected,
                                selectedColor: const Color(0xFFFF7A00),
                                labelStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedVariantId = v.id);
                                  _loadRecipesForMenuItem(_selectedMenuItem!.id, variantId: v.id);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_selectedMenuItem != null) ...[
              const SizedBox(height: 12),

              // Profitability & Margin Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Harga Jual Menu', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                RupiahInputHelper.formatWithPrefix(_sellingPrice),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('HPP Resep', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                RupiahInputHelper.formatWithPrefix(_totalHpp),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Margin Laba', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '${_marginPercentage.toStringAsFixed(1)}%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _marginPercentage >= 60 ? Colors.amberAccent : Colors.orangeAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Food Cost Percentage: ${_foodCostPercentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              _foodCostPercentage <= 35 ? '✨ Sangat Sehat (<35%)' : '⚠️ Evaluasi Harga (>35%)',
                              style: GoogleFonts.plusJakartaSans(
                                color: _foodCostPercentage <= 35 ? Colors.greenAccent : Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Ingredients List in Recipe
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KOMPONEN RESEP (${_recipeItems.length} BAHAN)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1.1,
                      ),
                    ),
                    ingredientsAsync.maybeWhen(
                      data: (allIngredients) => TextButton.icon(
                        onPressed: () => _showAddIngredientPickerSheet(allIngredients),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tambah Bahan'),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (_recipeItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Menu ini belum memiliki resep bahan baku.',
                          style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        ingredientsAsync.maybeWhen(
                          data: (allIngredients) => ElevatedButton.icon(
                            onPressed: () => _showAddIngredientPickerSheet(allIngredients),
                            icon: const Icon(Icons.add),
                            label: const Text('Pilih Bahan Baku'),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recipeItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _recipeItems[index];
                    final ing = item.ingredient;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.cookie_outlined, color: Colors.amber.shade800, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ing?.name ?? 'Bahan Baku',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantityRequired} ${item.unit} • Biaya: ${RupiahInputHelper.formatWithPrefix(item.subtotalCost)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (ing != null)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                              onPressed: () => _promptQuantityDialog(ing, existing: item),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _recipeItems.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}
