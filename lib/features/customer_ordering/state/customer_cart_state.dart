import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dpos/features/customer_ordering/data/customer_ordering_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

const _uuid = Uuid();

class CustomerCartState {
  const CustomerCartState({
    required this.items,
    this.isSaving = false,
    this.error,
    this.orderId,
  });

  final List<TransactionItem> items;
  final bool isSaving;
  final String? error;
  final String? orderId;

  double get subtotal => items.fold(0, (sum, item) => sum + item.rawSubtotal);
  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CustomerCartState copyWith({
    List<TransactionItem>? items,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? orderId,
  }) {
    return CustomerCartState(
      items: items ?? this.items,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      orderId: orderId ?? this.orderId,
    );
  }
}

class CustomerCartNotifier extends AutoDisposeNotifier<CustomerCartState> {
  @override
  CustomerCartState build() {
    return const CustomerCartState(items: []);
  }

  void addItem(MenuItem menuItem, {MenuItemVariant? variant}) {
    final items = [...state.items];
    final price = variant?.price ?? menuItem.price;
    final existingIndex = items.indexWhere(
      (item) => item.menuItemId == menuItem.id && item.variantId == variant?.id,
    );

    if (existingIndex >= 0) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + 1,
      );
    } else {
      items.add(
        TransactionItem(
          id: _uuid.v4(),
          menuItemId: menuItem.id,
          variantId: variant?.id,
          name: menuItem.name,
          variantName: variant?.name,
          quantity: 1,
          unitPrice: price,
        ),
      );
    }
    state = state.copyWith(items: items, clearError: true);
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      state = state.copyWith(
        items: state.items.where((i) => i.id != itemId).toList(),
      );
      return;
    }
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == itemId ? i.copyWith(quantity: quantity) : i)
          .toList(),
    );
  }

  Future<bool> submitOrder({
    required String outletId,
    required String tableId,
    String? customerName,
  }) async {
    if (state.isEmpty) return false;
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final repo = ref.read(customerOrderingRepositoryProvider);
      final orderId = await repo.submitSelfOrder(
        outletId: outletId,
        tableId: tableId,
        tableNumber: int.tryParse(tableId),
        customerName: customerName,
        items: state.items,
      );
      state = state.copyWith(isSaving: false, orderId: orderId);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  void clear() {
    state = const CustomerCartState(items: []);
  }
}

final customerCartProvider =
    NotifierProvider.autoDispose<CustomerCartNotifier, CustomerCartState>(
      CustomerCartNotifier.new,
    );
