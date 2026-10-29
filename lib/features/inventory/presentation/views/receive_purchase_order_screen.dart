import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import '../../data/inventory_repository.dart';
import '../../domain/inventory_models.dart';

class ReceivePurchaseOrderScreen extends ConsumerStatefulWidget {
  const ReceivePurchaseOrderScreen({super.key, required this.po});

  final PurchaseOrder po;

  @override
  ConsumerState<ReceivePurchaseOrderScreen> createState() =>
      _ReceivePurchaseOrderScreenState();
}

class _ReceivePurchaseOrderScreenState
    extends ConsumerState<ReceivePurchaseOrderScreen> {
  late Map<String, int> receivedQuantities;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    receivedQuantities = {
      for (var item in widget.po.items)
        item.menuItemId: item.quantity - item.receivedQuantity,
    };
  }

  Future<void> _confirmReceive() async {
    setState(() => isSaving = true);

    try {
      log('Current receivedQuantities: $receivedQuantities');
      final itemsToReceive = receivedQuantities.entries
          .where((e) => e.value > 0)
          .map((e) => {'item_id': e.key, 'received_qty': e.value})
          .toList();

      if (itemsToReceive.isEmpty) {
        throw Exception(
          'Jumlah barang yang diterima harus lebih besar dari 0.',
        );
      }

      await ref
          .read(inventoryRepositoryProvider)
          .receivePurchaseOrder(
            poId: widget.po.id,
            receivedItems: itemsToReceive,
          );

      if (!mounted) return;
      ref.read(purchaseOrderListProvider.notifier).refresh();
      // Invalidate menuItemsProvider to refresh stock on dashboard
      ref.invalidate(menuItemsProvider);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      log(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal konfirmasi: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Terima Barang')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _POInfo(po: widget.po),
                  const SizedBox(height: 24),
                  Text(
                    'Daftar Barang',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.po.items.map((item) {
                    return _ReceiveItemRow(
                      item: item,
                      initialQty: receivedQuantities[item.menuItemId] ?? 0,
                      onQtyChanged: (val) => setState(
                        () => receivedQuantities[item.menuItemId] = val,
                      ),
                    );
                  }),
                ],
              ),
            ),
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
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: isSaving ? null : _confirmReceive,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Konfirmasi Terima Barang'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _POInfo extends StatelessWidget {
  const _POInfo({required this.po});

  final PurchaseOrder po;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                po.poNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _StatusBadge(status: po.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, size: 18),
              const SizedBox(width: 8),
              Text(po.supplier?.name ?? 'Tanpa Supplier'),
            ],
          ),
          if (po.notes != null && po.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text('Catatan:', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(po.notes!),
          ],
        ],
      ),
    );
  }
}

class _ReceiveItemRow extends StatelessWidget {
  const _ReceiveItemRow({
    required this.item,
    required this.initialQty,
    required this.onQtyChanged,
  });

  final PurchaseOrderItem item;
  final int initialQty;
  final Function(int) onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName ?? 'Unknown Item',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Pesanan: ${item.quantity} ${item.itemUnit ?? ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (item.receivedQuantity > 0)
              Text(
                'Sudah diterima sebelumnya: ${item.receivedQuantity}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
              ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Jumlah Diterima Sekarang')),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: initialQty.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => onQtyChanged(int.tryParse(v) ?? 0),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PurchaseOrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color color = status == PurchaseOrderStatus.pending
        ? Colors.orange
        : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
