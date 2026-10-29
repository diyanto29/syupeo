import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import '../domain/inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient _client;

  // --- Suppliers ---

  Future<List<Supplier>> getSuppliers(String businessId) async {
    final response = await _client
        .from('suppliers')
        .select()
        .eq('business_id', businessId)
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> upsertSupplier(Supplier supplier) async {
    final data = supplier.toJson();
    if (supplier.id.isEmpty) {
      data.remove('id');
    }

    // Remove null created_at to let DB use default value
    if (data['created_at'] == null) {
      data.remove('created_at');
    }

    final response = await _client
        .from('suppliers')
        .upsert(data)
        .select()
        .single();

    return Supplier.fromJson(response);
  }

  Future<void> deleteSupplier(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }

  // --- Purchase Orders ---

  Future<List<PurchaseOrder>> getPurchaseOrders(
    String businessId, {
    String? outletId,
  }) async {
    var query = _client
        .from('purchase_orders')
        .select('''
          *, 
          supplier:suppliers(*), 
          items:purchase_order_items(*, menu_item:menu_items(name, unit))
        ''')
        .eq('business_id', businessId);

    if (outletId != null) {
      query = query.eq('outlet_id', outletId);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).map((json) {
      final data = Map<String, dynamic>.from(json as Map);
      if (data['items'] != null) {
        data['items'] = (data['items'] as List).map((item) {
          final itemData = Map<String, dynamic>.from(item as Map);
          final menuItem = itemData['menu_item'] as Map<String, dynamic>?;
          if (menuItem != null) {
            itemData['item_name'] = menuItem['name'];
            itemData['item_unit'] = menuItem['unit'];
          }
          return itemData;
        }).toList();
      }
      return PurchaseOrder.fromJson(data);
    }).toList();
  }

  Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final response = await _client
        .from('purchase_orders')
        .select('''
          *, 
          supplier:suppliers(*), 
          items:purchase_order_items(*, menu_item:menu_items(name, unit))
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    final data = Map<String, dynamic>.from(response as Map);
    if (data['items'] != null) {
      data['items'] = (data['items'] as List).map((item) {
        final itemData = Map<String, dynamic>.from(item as Map);
        final menuItem = itemData['menu_item'] as Map<String, dynamic>?;
        if (menuItem != null) {
          itemData['item_name'] = menuItem['name'];
          itemData['item_unit'] = menuItem['unit'];
        }
        return itemData;
      }).toList();
    }

    return PurchaseOrder.fromJson(data);
  }

  Future<PurchaseOrder> createPurchaseOrder(
    PurchaseOrder po,
    List<PurchaseOrderItem> items,
  ) async {
    // 1. Insert PO
    final poData = po.toJson();
    if (po.id.isEmpty) poData.remove('id');
    if (poData['created_at'] == null) poData.remove('created_at');

    // Remove relational fields that don't exist in the table columns
    poData.remove('items');
    poData.remove('supplier');

    final poResponse = await _client
        .from('purchase_orders')
        .insert(poData)
        .select()
        .single();

    final createdPo = PurchaseOrder.fromJson(poResponse);

    // 2. Insert Items
    final itemsData = items.map((i) {
      final itemJson = i.copyWith(poId: createdPo.id).toJson();
      if (i.id.isEmpty) itemJson.remove('id');
      if (itemJson['created_at'] == null) itemJson.remove('created_at');

      // Remove UI-only fields
      itemJson.remove('item_name');
      itemJson.remove('item_unit');

      return itemJson;
    }).toList();

    await _client.from('purchase_order_items').insert(itemsData);

    return createdPo;
  }

  Future<void> updatePurchaseOrderStatus(
    String poId,
    PurchaseOrderStatus status,
  ) async {
    await _client
        .from('purchase_orders')
        .update({'status': status.name})
        .eq('id', poId);
  }

  Future<void> receivePurchaseOrder({
    required String poId,
    required List<Map<String, dynamic>>
    receivedItems, // List of {item_id, received_qty}
  }) async {
    await _client.rpc(
      'receive_purchase_order',
      params: {'target_po_id': poId, 'received_items': receivedItems},
    );
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(SupabaseService.client);
});

final purchaseOrderListProvider =
    AsyncNotifierProvider<PurchaseOrderListNotifier, List<PurchaseOrder>>(() {
      return PurchaseOrderListNotifier();
    });

class PurchaseOrderListNotifier extends AsyncNotifier<List<PurchaseOrder>> {
  @override
  Future<List<PurchaseOrder>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;
    final outletId = bootstrap?.currentOutlet?.id;

    if (businessId == null) return [];

    return ref
        .read(inventoryRepositoryProvider)
        .getPurchaseOrders(businessId, outletId: outletId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
