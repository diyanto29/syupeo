import 'dart:developer';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/inventory_repository.dart';
import '../../domain/inventory_models.dart';
import 'supplier_list_screen.dart';

class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState
    extends ConsumerState<CreatePurchaseOrderScreen> {
  Supplier? selectedSupplier;
  final List<PurchaseOrderItem> items = [];
  final notesController = TextEditingController();
  final poNumberController = TextEditingController();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    poNumberController.text =
        'PO-${now.year}${now.month}${now.day}-${now.millisecondsSinceEpoch.toString().substring(9)}';
  }

  void _addItem(MenuItem menuItem) {
    setState(() {
      final existingIndex = items.indexWhere(
        (i) => i.menuItemId == menuItem.id,
      );
      if (existingIndex != -1) {
        items[existingIndex] = items[existingIndex].copyWith(
          quantity: items[existingIndex].quantity + 1,
        );
      } else {
        items.add(
          PurchaseOrderItem(
            id: const Uuid().v4(),
            poId: '', // Set by repository
            menuItemId: menuItem.id,
            quantity: 1,
            costPrice: menuItem.recipeCost,
            itemName: menuItem.name,
            itemUnit: menuItem.displayUnit,
          ),
        );
      }
    });
  }

  double get totalAmount =>
      items.fold(0, (sum, item) => sum + (item.quantity * item.costPrice));

  Future<void> _savePO() async {
    if (selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih supplier terlebih dahulu')),
      );
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal satu barang')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final bootstrap = ref.read(homeBootstrapProvider).value;
      final businessId = bootstrap?.business?.id;
      final outletId = bootstrap?.currentOutlet?.id;

      if (businessId == null || outletId == null) {
        throw Exception('Data bisnis/outlet tidak ditemukan');
      }

      final po = PurchaseOrder(
        id: '',
        businessId: businessId,
        outletId: outletId,
        supplierId: selectedSupplier!.id,
        poNumber: poNumberController.text,
        status: PurchaseOrderStatus.pending, // Auto set to pending for now
        totalAmount: totalAmount,
        notes: notesController.text,
      );

      await ref
          .read(inventoryRepositoryProvider)
          .createPurchaseOrder(po, items);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      log(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat PO: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Purchase Order')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PO Number & Supplier
                    Card(
                      elevation: 0,
                      color: scheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: poNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Nomor PO',
                              ),
                            ),
                            const SizedBox(height: 16),
                            suppliersAsync.when(
                              loading: () => const CircularProgressIndicator(),
                              error: (e, _) =>
                                  Text('Error loading suppliers: $e'),
                              data: (suppliers) =>
                                  DropdownButtonFormField<Supplier>(
                                    value: selectedSupplier,
                                    decoration: const InputDecoration(
                                      labelText: 'Supplier',
                                    ),
                                    items: suppliers
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => selectedSupplier = val),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Item Selection Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Item Pesanan',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showItemPicker(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tambah Produk'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Items List
                    if (items.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Belum ada item yang dipilih',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      )
                    else
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return _ItemRow(
                          item: item,
                          onDelete: () => setState(() => items.removeAt(idx)),
                          onQtyChanged: (val) => setState(
                            () =>
                                items[idx] = items[idx].copyWith(quantity: val),
                          ),
                          onPriceChanged: (val) => setState(
                            () => items[idx] = items[idx].copyWith(
                              costPrice: val,
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Estimasi',
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          'Rp ${totalAmount.toInt()}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF8A00),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: isSaving ? null : _savePO,
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Simpan & Kirim PO'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ItemPickerSheet(
        onSelected: (item) {
          _addItem(item);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onDelete,
    required this.onQtyChanged,
    required this.onPriceChanged,
  });

  final PurchaseOrderItem item;
  final VoidCallback onDelete;
  final Function(int) onQtyChanged;
  final Function(double) onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName ?? 'Unknown Item',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Unit: ${item.itemUnit ?? '-'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.costPrice.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'Harga Satuan',
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => onPriceChanged(double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => onQtyChanged(int.tryParse(v) ?? 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemPickerSheet extends ConsumerWidget {
  const _ItemPickerSheet({required this.onSelected});

  final Function(MenuItem) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuItemsAsync = ref.watch(menuItemsProvider);

    return Column(
      children: [
        AppBar(
          title: const Text('Pilih Produk'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        Expanded(
          child: menuItemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (!item.trackStockQuantity) return const SizedBox.shrink();
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.categoryName} • Rp ${item.recipeCost.toInt()}',
                  ),
                  onTap: () => onSelected(item),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
