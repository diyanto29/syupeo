import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockHistoryScreen extends ConsumerWidget {
  const StockHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletId = ref.watch(homeBootstrapProvider).value?.currentOutlet?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Stok'),
      ),
      body: SafeArea(
        child: outletId == null
            ? const Center(child: Text('Outlet belum dipilih'))
            : _StockHistoryList(outletId: outletId),
      ),
    );
  }
}

class _StockHistoryList extends ConsumerWidget {
  const _StockHistoryList({required this.outletId});

  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(allInventoryMovementsProvider(outletId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return movementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (movements) {
        if (movements.isEmpty) {
          return const Center(child: Text('Belum ada riwayat pergerakan stok.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: movements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = movements[index];
            final m = data['movement'] as InventoryMovement;
            final itemName = data['itemName'] as String;
            final isAddition = m.quantityDelta > 0;
            
            return Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isAddition ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAddition ? Icons.add_rounded : Icons.remove_rounded,
                    color: isAddition ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  itemName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.movementLabel),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(m.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                    if (m.note != null && m.note!.isNotEmpty)
                      Text('Catatan: ${m.note}', style: theme.textTheme.bodySmall),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isAddition ? "+" : ""}${m.quantityDelta}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isAddition ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    Text('Saldo: ${m.quantityAfter}', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Provider for all movements in an outlet
final allInventoryMovementsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, outletId) async {
  return _getAllMovements(ref, outletId);
});

Future<List<Map<String, dynamic>>> _getAllMovements(Ref ref, String outletId) async {
  final response = await Supabase.instance.client
      .from('inventory_movements')
      .select('*, menu_item:menu_items(name)')
      .eq('outlet_id', outletId)
      .order('created_at', ascending: false)
      .limit(50);
  
  return (response as List).map((json) {
    final movement = InventoryMovement.fromJson(json);
    final itemName = json['menu_item']?['name'] ?? movement.menuItemId;
    return {
      'movement': movement,
      'itemName': itemName,
    };
  }).toList();
}
