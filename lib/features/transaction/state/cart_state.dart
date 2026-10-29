import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/features/discount_management/data/promo_repository.dart';
import 'package:dpos/features/discount_management/domain/discount_models.dart';
import 'package:dpos/features/discount_management/domain/promo_models.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/services/offline_sync_service.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/transaction_repository.dart';
import '../domain/transaction_models.dart';
import 'package:dpos/features/kitchen/presentation/kitchen_queue_screen.dart';

const _uuid = Uuid();

/// State model for the active cart / transaction in progress.
class CartState {
  const CartState({
    this.orderId,
    this.invoiceNumber,
    this.orderSource,
    this.status,
    this.waiterId,
    this.waiterName,
    required this.items,
    required this.discounts,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.tableNumber,
    this.diningOption = DiningOption.dineIn,
    this.notes,
    this.selectedPaymentMethod,
    this.referenceNumber,
    this.paidAmount,
    this.isSaving = false,
    this.useTieredPricing = true,
    this.error,
    this.isTaxEnabled = false,
    this.taxName = 'PB1',
    this.taxRate = 10.0,
    this.isTaxInclusive = false,
    this.kitchenStatus,
  });

  final KitchenStatus? kitchenStatus;

  final String? orderId;
  final String? invoiceNumber;
  final OrderSource? orderSource;
  final TransactionStatus? status;
  final String? waiterId;
  final String? waiterName;
  final List<TransactionItem> items;
  final List<TransactionDiscount> discounts;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int? tableNumber;
  final DiningOption diningOption;
  final String? notes;
  final PaymentMethodOption? selectedPaymentMethod;
  final String? referenceNumber;
  final double? paidAmount;
  final bool isSaving;
  final bool useTieredPricing;
  final String? error;
  final bool isTaxEnabled;
  final String taxName;
  final double taxRate;
  final bool isTaxInclusive;

  /// Subtotal sebelum diskon keseluruhan (sudah termasuk diskon per item).
  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  /// Total diskon item-level.
  double get itemDiscountTotal =>
      items.fold(0, (sum, item) => sum + item.discountApplied);

  /// Total diskon order-level.
  double get orderDiscountTotal {
    double total = 0;
    for (final disc in discounts) {
      if (disc.type == DiscountType.percentage) {
        var applied = subtotal * (disc.percentageValue ?? 0) / 100;
        if (disc.maxDiscountAmount != null && disc.maxDiscountAmount! > 0) {
          applied = applied.clamp(0, disc.maxDiscountAmount!);
        }
        total += applied;
      } else {
        total += disc.amountValue ?? 0;
      }
    }
    return total.clamp(0, subtotal);
  }

  /// Total semua diskon (item + order level).
  double get discountTotal => itemDiscountTotal + orderDiscountTotal;

  /// Jumlah yang dikenakan pajak (setelah diskon order).
  double get taxableAmount =>
      (subtotal - orderDiscountTotal).clamp(0, double.infinity);

  /// Nilai pajak (PB1/PPN/dsb).
  double get taxAmount {
    if (!isTaxEnabled || taxRate <= 0 || taxableAmount <= 0) return 0.0;
    if (isTaxInclusive) {
      // Inklusif: harga jual sudah mengandung pajak
      // Pajak = Nilai Jual - (Nilai Jual / (1 + tarif/100))
      return (taxableAmount - (taxableAmount / (1 + (taxRate / 100))))
          .roundToDouble();
    } else {
      // Eksklusif: pajak ditambahkan di atas subtotal
      return (taxableAmount * (taxRate / 100)).roundToDouble();
    }
  }

  /// Grand Total yang harus dibayar customer.
  double get grandTotal {
    if (!isTaxEnabled || isTaxInclusive) {
      return taxableAmount;
    }
    return (taxableAmount + taxAmount).clamp(0, double.infinity);
  }

  double get effectivePaidAmount => paidAmount ?? 0;

  double get changeAmount =>
      (effectivePaidAmount - grandTotal).clamp(0, double.infinity);

  bool get isEmpty => items.isEmpty;

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    String? orderId,
    String? invoiceNumber,
    OrderSource? orderSource,
    bool clearOrderSource = false,
    TransactionStatus? status,
    bool clearStatus = false,
    String? waiterId,
    bool clearWaiterId = false,
    String? waiterName,
    bool clearWaiterName = false,
    List<TransactionItem>? items,
    List<TransactionDiscount>? discounts,
    String? customerId,
    bool clearCustomerId = false,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    bool clearCustomer = false,
    int? tableNumber,
    bool clearTableNumber = false,
    DiningOption? diningOption,
    String? notes,
    PaymentMethodOption? selectedPaymentMethod,
    bool clearPaymentMethod = false,
    String? referenceNumber,
    bool clearReferenceNumber = false,
    double? paidAmount,
    bool clearPaidAmount = false,
    bool? isSaving,
    bool? useTieredPricing,
    String? error,
    bool clearError = false,
    bool? isTaxEnabled,
    String? taxName,
    double? taxRate,
    bool? isTaxInclusive,
    KitchenStatus? kitchenStatus,
    bool clearKitchenStatus = false,
  }) {
    return CartState(
      orderId: orderId ?? this.orderId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      orderSource: clearOrderSource ? null : (orderSource ?? this.orderSource),
      status: clearStatus ? null : (status ?? this.status),
      waiterId: clearWaiterId ? null : (waiterId ?? this.waiterId),
      waiterName: clearWaiterName ? null : (waiterName ?? this.waiterName),
      items: items ?? this.items,
      discounts: discounts ?? this.discounts,
      customerId: clearCustomer || clearCustomerId
          ? null
          : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      customerPhone: clearCustomer ? null : (customerPhone ?? this.customerPhone),
      customerEmail: clearCustomer ? null : (customerEmail ?? this.customerEmail),
      tableNumber: clearTableNumber ? null : (tableNumber ?? this.tableNumber),
      diningOption: diningOption ?? this.diningOption,
      notes: notes ?? this.notes,
      selectedPaymentMethod: clearPaymentMethod
          ? null
          : (selectedPaymentMethod ?? this.selectedPaymentMethod),
      referenceNumber: clearReferenceNumber
          ? null
          : (referenceNumber ?? this.referenceNumber),
      paidAmount: clearPaidAmount ? null : (paidAmount ?? this.paidAmount),
      isSaving: isSaving ?? this.isSaving,
      useTieredPricing: useTieredPricing ?? this.useTieredPricing,
      error: clearError ? null : (error ?? this.error),
      isTaxEnabled: isTaxEnabled ?? this.isTaxEnabled,
      taxName: taxName ?? this.taxName,
      taxRate: taxRate ?? this.taxRate,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      kitchenStatus: clearKitchenStatus
          ? null
          : (kitchenStatus ?? this.kitchenStatus),
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    // Gunakan ref.listen atau ref.read agar perubahan featureGate/bootstrap tidak mereset cart items
    final featureGate = ref.read(featureGateProvider);
    final isTieredAllowed = featureGate.isEnabled('tiered_pricing');
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final currentOutlet = bootstrap?.currentOutlet;
    final isTaxEnabled = currentOutlet?.taxEnabled ?? false;
    final taxName = currentOutlet?.taxName ?? 'PB1';
    final taxRate = currentOutlet?.taxRate ?? 10.0;
    final isTaxInclusive = currentOutlet?.isTaxInclusive ?? false;

    ref.listen(homeBootstrapProvider, (previous, next) {
      final nextOutlet = next.valueOrNull?.currentOutlet;
      if (nextOutlet != null) {
        if (state.isTaxEnabled != nextOutlet.taxEnabled ||
            state.taxName != nextOutlet.taxName ||
            state.taxRate != nextOutlet.taxRate ||
            state.isTaxInclusive != nextOutlet.isTaxInclusive) {
          state = state.copyWith(
            isTaxEnabled: nextOutlet.taxEnabled,
            taxName: nextOutlet.taxName,
            taxRate: nextOutlet.taxRate,
            isTaxInclusive: nextOutlet.isTaxInclusive,
          );
        }
      }
    });

    ref.listen(featureGateProvider, (previous, next) {
      final allowed = next.isEnabled('tiered_pricing');
      if (state.useTieredPricing != allowed) {
        state = state.copyWith(useTieredPricing: allowed);
        _recalculateAllPrices();
      }
    });

    // Eagerly listen to BXGY promo updates to recalculate discounts in active cart
    ref.listen(buyXGetYPromosProvider, (previous, next) {
      final promos = next.valueOrNull;
      if (promos != null && state.items.isNotEmpty) {
        state = state.copyWith(items: _evaluateBxgy(state.items, customPromos: promos));
      }
    });

    return CartState(
      items: [],
      discounts: [],
      useTieredPricing: isTieredAllowed,
      isTaxEnabled: isTaxEnabled,
      taxName: taxName,
      taxRate: taxRate,
      isTaxInclusive: isTaxInclusive,
    );
  }

  void toggleTieredPricing(bool value) {
    final featureGate = ref.read(featureGateProvider);
    if (value && !featureGate.isEnabled('tiered_pricing')) {
      // Fitur terkunci, jangan izinkan aktifkan
      state = state.copyWith(
        error: 'Fitur Harga Bertingkat hanya tersedia di paket Pro.',
      );
      return;
    }

    state = state.copyWith(useTieredPricing: value);
    _recalculateAllPrices();
  }

  void _recalculateAllPrices() {
    final menuItems = ref.read(menuItemsProvider).valueOrNull ?? [];
    final updatedItems = state.items.map((item) {
      final menuItem = menuItems.cast<MenuItem?>().firstWhere(
        (m) => m?.id == item.menuItemId,
        orElse: () => null,
      );

      if (menuItem == null) return item;

      // If the item was previously forced to base price, respect it unless global toggle changed
      // Actually, if we are in this method, we are re-syncing with global setting.
      // But if the user manually said NO to a tier, we should keep it until they change qty again?
      // For simplicity, _recalculateAllPrices will follow the global toggle strictly.

      double? basePrice;
      if (item.variantId != null) {
        final variant = menuItem.variants.cast<MenuItemVariant?>().firstWhere(
          (v) => v?.id == item.variantId,
          orElse: () => null,
        );
        basePrice = variant?.price ?? item.unitPrice;
      } else {
        basePrice = menuItem.price;
      }

      final newPrice = state.useTieredPricing
          ? menuItem.resolvePrice(item.quantity, basePrice: basePrice)
          : basePrice;

      return item.copyWith(unitPrice: newPrice).recalculateDiscount();
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  // ── Item Management ─────────────────────────────────────────

  void addItem(
    MenuItem menuItem, {
    MenuItemVariant? variant,
    bool forceNormalPrice = false,
  }) {
    final items = [...state.items];
    final price = variant?.price ?? menuItem.price;
    final existingIndex = items.indexWhere(
      (item) => item.menuItemId == menuItem.id && item.variantId == variant?.id,
    );

    // 1. Stock check for package components
    if (menuItem.isPackage && menuItem.packageItems.isNotEmpty) {
      final allMenuItems = ref.read(menuItemsProvider).valueOrNull ?? [];
      final currentQty = existingIndex >= 0 ? items[existingIndex].quantity : 0;
      final targetQty = currentQty + 1;
      for (final pkgComp in menuItem.packageItems) {
        final compItem = allMenuItems.cast<MenuItem?>().firstWhere(
              (m) => m?.id == pkgComp.componentMenuItemId,
              orElse: () => null,
            );
        if (compItem != null && compItem.trackStockQuantity) {
          final neededStock = pkgComp.quantity * targetQty;
          if (compItem.stockQuantity < neededStock) {
            state = state.copyWith(
              error:
                  'Stok komponen ${compItem.name} tidak cukup (${compItem.stockQuantity}) untuk ${targetQty}x ${menuItem.name}',
            );
            return;
          }
        }
      }
    } else if (menuItem.trackStockQuantity) {
      final currentQty = existingIndex >= 0 ? items[existingIndex].quantity : 0;
      if (currentQty >= menuItem.stockQuantity) {
        state = state.copyWith(
          error: 'Stok untuk ${menuItem.name} tidak mencukupi (Tersedia: ${menuItem.stockQuantity})',
        );
        return;
      }
    }

    if (existingIndex >= 0) {
      final newQty = items[existingIndex].quantity + 1;
      final resolvedPrice = (state.useTieredPricing && !forceNormalPrice)
          ? menuItem.resolvePrice(newQty, basePrice: price)
          : price;

      items[existingIndex] = items[existingIndex]
          .copyWith(
            quantity: newQty,
            unitPrice: resolvedPrice,
            forceBasePrice:
                forceNormalPrice || items[existingIndex].forceBasePrice,
          )
          .recalculateDiscount();
    } else {
      final resolvedPrice = (state.useTieredPricing && !forceNormalPrice)
          ? menuItem.resolvePrice(1, basePrice: price)
          : price;
      items.add(
        TransactionItem(
          id: _uuid.v4(),
          menuItemId: menuItem.id,
          variantId: variant?.id,
          name: menuItem.name,
          variantName: variant?.name,
          quantity: 1,
          unitPrice: resolvedPrice,
          costPrice: menuItem.recipeCost,
          forceBasePrice: forceNormalPrice,
          isPackage: menuItem.isPackage,
          packageComponents: menuItem.packageItems
              .map((p) => '${p.quantity}x ${p.componentName ?? "Item"}')
              .toList(),
        ),
      );
    }

    final evaluatedItems = _evaluateBxgy(items);
    state = state.copyWith(items: evaluatedItems, clearError: true);
  }

  void removeItem(String itemId) {
    final remaining = state.items.where((item) => item.id != itemId).toList();
    final evaluatedItems = _evaluateBxgy(remaining);
    state = state.copyWith(items: evaluatedItems, clearError: true);
  }

  void updateItemQuantity(
    String itemId,
    int quantity, {
    bool forceNormalPrice = false,
  }) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final menuItems = ref.read(menuItemsProvider).valueOrNull ?? [];
    final item = state.items.firstWhere((i) => i.id == itemId);
    final menuItem = menuItems.cast<MenuItem?>().firstWhere(
          (m) => m?.id == item.menuItemId,
          orElse: () => null,
        );

    if (menuItem != null) {
      if (menuItem.isPackage && menuItem.packageItems.isNotEmpty) {
        for (final pkgComp in menuItem.packageItems) {
          final compItem = menuItems.cast<MenuItem?>().firstWhere(
                (m) => m?.id == pkgComp.componentMenuItemId,
                orElse: () => null,
              );
          if (compItem != null && compItem.trackStockQuantity) {
            final neededStock = pkgComp.quantity * quantity;
            if (compItem.stockQuantity < neededStock) {
              state = state.copyWith(
                error:
                    'Stok komponen ${compItem.name} tidak cukup (${compItem.stockQuantity}) untuk ${quantity}x ${menuItem.name}',
              );
              return;
            }
          }
        }
      } else if (menuItem.trackStockQuantity) {
        if (quantity > menuItem.stockQuantity) {
          state = state.copyWith(
            error: 'Stok untuk ${menuItem.name} tidak mencukupi (Tersedia: ${menuItem.stockQuantity})',
          );
          return;
        }
      }
    }

    final updatedItems = state.items.map((item) {
      if (item.id != itemId) return item;

      final menuItem = menuItems.cast<MenuItem?>().firstWhere(
        (m) => m?.id == item.menuItemId,
        orElse: () => null,
      );

      double newPrice = item.unitPrice;
      if (menuItem != null) {
        double? basePrice;
        if (item.variantId != null) {
          final variant = menuItem.variants
              .cast<MenuItemVariant?>()
              .firstWhere((v) => v?.id == item.variantId, orElse: () => null);
          basePrice = variant?.price ?? item.unitPrice;
        } else {
          basePrice = menuItem.price;
        }

        newPrice = (state.useTieredPricing && !forceNormalPrice)
            ? menuItem.resolvePrice(quantity, basePrice: basePrice)
            : basePrice;
      }

      return item
          .copyWith(
            quantity: quantity,
            unitPrice: newPrice,
            forceBasePrice: forceNormalPrice,
          )
          .recalculateDiscount();
    }).toList();

    final evaluatedItems = _evaluateBxgy(updatedItems);
    state = state.copyWith(items: evaluatedItems, clearError: true);
  }

  // ── Promotions Engine (BXGY & Tebus Murah) ─────────────────────

  List<TransactionItem> _evaluateBxgy(
    List<TransactionItem> inputItems, {
    List<BuyXGetYPromo>? customPromos,
  }) {
    var items = inputItems.map((i) {
      if (i.promoTag == '[BOGO - GRATIS]') {
        return i.copyWith(clearDiscount: true, clearPromoTag: true);
      }
      return i;
    }).toList();

    final promos = customPromos ?? ref.read(buyXGetYPromosProvider).valueOrNull ?? [];
    final activePromos = promos.where((p) => p.isCurrentlyActive()).toList();
    if (activePromos.isEmpty) return items;

    for (final promo in activePromos) {
      final triggerQty = items
          .where((i) => i.menuItemId == promo.triggerMenuItemId && !i.isTebusMurah)
          .fold<int>(0, (sum, i) => sum + i.quantity);

      if (triggerQty < promo.minBuyQty) continue;

      if (promo.mode == BuyXGetYMode.sameProduct) {
        final rewardUnits = promo.calculateRewardUnits(triggerQty);
        if (rewardUnits <= 0) continue;

        final idx = items.indexWhere(
          (i) => i.menuItemId == promo.triggerMenuItemId && !i.isTebusMurah,
        );
        if (idx >= 0) {
          final item = items[idx];
          final discountAmount =
              (rewardUnits * item.unitPrice).clamp(0.0, item.rawSubtotal);
          items[idx] = item.copyWith(
            clearDiscountId: true,
            discountName: 'BOGO: ${promo.name}',
            discountApplied: discountAmount,
            promoTag: '[BOGO - GRATIS]',
          );
        }
      } else if (promo.mode == BuyXGetYMode.crossProduct &&
          promo.rewardMenuItemId != null) {
        final rewardQty = items
            .where((i) => i.menuItemId == promo.rewardMenuItemId && !i.isTebusMurah)
            .fold<int>(0, (sum, i) => sum + i.quantity);
        final rewardUnits = promo.calculateRewardUnits(triggerQty);
        if (rewardUnits <= 0 || rewardQty <= 0) continue;

        final idx = items.indexWhere(
          (i) => i.menuItemId == promo.rewardMenuItemId && !i.isTebusMurah,
        );
        if (idx >= 0) {
          final item = items[idx];
          final unitsToFree = rewardUnits.clamp(0, item.quantity);
          final discountAmount =
              (unitsToFree * item.unitPrice).clamp(0.0, item.rawSubtotal);
          items[idx] = item.copyWith(
            clearDiscountId: true,
            discountName: 'BOGO: ${promo.name}',
            discountApplied: discountAmount,
            promoTag: '[BOGO - GRATIS]',
          );
        }
      }
    }

    return items;
  }

  List<BuyXGetYPromo> getEligibleBxgyOffers({List<BuyXGetYPromo>? customPromos}) {
    final promos = customPromos ?? ref.read(buyXGetYPromosProvider).valueOrNull ?? [];
    if (promos.isEmpty) return [];

    return promos.where((p) {
      if (!p.isCurrentlyActive()) return false;
      final triggerQty = state.items
          .where((i) => i.menuItemId == p.triggerMenuItemId && !i.isTebusMurah)
          .fold<int>(0, (sum, i) => sum + i.quantity);

      if (p.mode == BuyXGetYMode.sameProduct) {
        final pending = p.pendingRewardUnits(triggerQty);
        return pending > 0;
      } else {
        final rewardQty = state.items
            .where((i) => i.menuItemId == p.rewardMenuItemId && !i.isTebusMurah)
            .fold<int>(0, (sum, i) => sum + i.quantity);
        final pending =
            p.pendingRewardUnits(triggerQty, rewardQtyInCart: rewardQty);
        return pending > 0;
      }
    }).toList();
  }

  void claimBxgyReward(BuyXGetYPromo promo) {
    final items = [...state.items];
    if (promo.mode == BuyXGetYMode.sameProduct) {
      final idx = items.indexWhere(
        (i) => i.menuItemId == promo.triggerMenuItemId && !i.isTebusMurah,
      );
      if (idx >= 0) {
        final existingItem = items[idx];
        final newQty = existingItem.quantity + promo.rewardQty;
        items[idx] = existingItem.copyWith(quantity: newQty);
      }
    } else if (promo.mode == BuyXGetYMode.crossProduct &&
        promo.rewardMenuItemId != null) {
      final allMenuItems = ref.read(menuItemsProvider).valueOrNull ?? [];
      final rewardMenuItem = allMenuItems.cast<MenuItem?>().firstWhere(
            (m) => m?.id == promo.rewardMenuItemId,
            orElse: () => null,
          );
      if (rewardMenuItem != null) {
        final existingRewardIdx = items.indexWhere(
          (i) => i.menuItemId == rewardMenuItem.id && !i.isTebusMurah,
        );
        if (existingRewardIdx >= 0) {
          final existing = items[existingRewardIdx];
          items[existingRewardIdx] = existing.copyWith(
            quantity: existing.quantity + promo.rewardQty,
          );
        } else {
          items.add(
            TransactionItem(
              id: _uuid.v4(),
              menuItemId: rewardMenuItem.id,
              name: rewardMenuItem.name,
              quantity: promo.rewardQty,
              unitPrice: rewardMenuItem.price,
              costPrice: rewardMenuItem.recipeCost,
              promoTag: '[BOGO - GRATIS]',
            ),
          );
        }
      }
    }

    final evaluatedItems = _evaluateBxgy(items);
    state = state.copyWith(items: evaluatedItems, clearError: true);
  }

  List<TebusMurahPromo> getEligibleTebusMurahPromos({List<TebusMurahPromo>? customPromos}) {
    final promos = customPromos ?? ref.read(tebusMurahPromosProvider).valueOrNull ?? [];
    if (promos.isEmpty) return [];

    final cleanSubtotal = state.items
        .where((i) => !i.isTebusMurah)
        .fold<double>(0, (sum, i) => sum + i.subtotal);

    final cartMenuItemIds = state.items
        .where((i) => !i.isTebusMurah && i.menuItemId != null)
        .map((i) => i.menuItemId!)
        .toList();

    final claimedPromoIds = state.items
        .where((i) => i.isTebusMurah && i.tebusMurahPromoId != null)
        .map((i) => i.tebusMurahPromoId!)
        .toSet();

    final claimedPromoNames = promos
        .where((p) => claimedPromoIds.contains(p.id))
        .map((p) => p.name.trim().toLowerCase())
        .toSet();

    return promos.where((p) {
      if (!p.isCurrentlyActive()) return false;
      if (claimedPromoIds.contains(p.id)) return false;
      if (claimedPromoNames.contains(p.name.trim().toLowerCase())) return false;
      return p.isEligible(
        cleanSubtotal: cleanSubtotal,
        cartMenuItemIds: cartMenuItemIds,
      );
    }).toList();
  }

  void claimTebusMurah(TebusMurahPromo promo, MenuItem rewardItem) {
    final items = [...state.items];
    items.add(
      TransactionItem(
        id: _uuid.v4(),
        menuItemId: rewardItem.id,
        name: rewardItem.name,
        quantity: 1,
        unitPrice: promo.specialPrice,
        costPrice: rewardItem.recipeCost,
        isTebusMurah: true,
        tebusMurahPromoId: promo.id,
        promoTag: '[TEBUS MURAH]',
      ),
    );
    final evaluatedItems = _evaluateBxgy(items);
    state = state.copyWith(items: evaluatedItems, clearError: true);
  }

  void updateItemNotes(String itemId, String notes) {
    state = state.copyWith(
      items: state.items
          .map((item) => item.id == itemId ? item.copyWith(notes: notes) : item)
          .toList(),
    );
  }

  void updateItemPrice(String itemId, double price) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id != itemId) return item;
        return item
            .copyWith(unitPrice: price, forceBasePrice: true)
            .recalculateDiscount();
      }).toList(),
      clearError: true,
    );
  }

  // ── Discount Management ─────────────────────────────────────

  void addDiscount(DiscountDefinition definition) {
    // Prevent duplicate discounts
    final alreadyAdded = state.discounts.any(
      (d) => d.discountId == definition.id,
    );
    if (alreadyAdded) return;

    final discount = TransactionDiscount.fromDefinition(
      definition,
      state.subtotal,
    );

    state = state.copyWith(
      discounts: [
        ...state.discounts,
        TransactionDiscount(
          id: _uuid.v4(),
          discountId: discount.discountId,
          name: discount.name,
          type: discount.type,
          percentageValue: discount.percentageValue,
          amountValue: discount.amountValue,
          maxDiscountAmount: discount.maxDiscountAmount,
          appliedAmount: discount.appliedAmount,
        ),
      ],
      clearError: true,
    );
  }

  void removeDiscount(String discountItemId) {
    state = state.copyWith(
      discounts: state.discounts.where((d) => d.id != discountItemId).toList(),
      clearError: true,
    );
  }

  // ── Item-Level Discount ─────────────────────────────────────

  void addItemDiscount(String itemId, DiscountDefinition definition) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id != itemId) return item;

        double applied;
        if (definition.type == DiscountType.percentage) {
          applied = item.rawSubtotal * (definition.percentageValue ?? 0) / 100;
          if (definition.maxDiscountAmount != null &&
              definition.maxDiscountAmount! > 0) {
            applied = applied.clamp(0, definition.maxDiscountAmount!);
          }
        } else {
          applied = definition.amountValue ?? 0;
        }
        applied = applied.clamp(0, item.rawSubtotal);

        return item.copyWith(
          discountId: definition.id,
          discountName: definition.name,
          discountType: definition.type,
          discountPercentage: definition.percentageValue,
          discountAmount: definition.amountValue,
          discountApplied: applied,
        );
      }).toList(),
      clearError: true,
    );
  }

  void removeItemDiscount(String itemId) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id != itemId) return item;
        return item.copyWith(clearDiscount: true);
      }).toList(),
      clearError: true,
    );
  }

  // ── Customer / Table Info ───────────────────────────────────

  void setCustomerInfo({String? id, String? name, String? phone, String? email}) {
    state = state.copyWith(
      customerId: id,
      customerName: name,
      customerPhone: phone,
      customerEmail: email,
    );
  }

  void clearCustomerInfo() {
    state = state.copyWith(clearCustomer: true);
  }

  void setTableNumber(int? number) {
    state = state.copyWith(
      tableNumber: number,
      clearTableNumber: number == null,
    );
  }

  void setDiningOption(DiningOption option) {
    state = state.copyWith(
      diningOption: option,
      clearTableNumber: option == DiningOption.takeAway,
    );
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  // ── Payment ─────────────────────────────────────────────────

  void selectPaymentMethod(PaymentMethodOption? method) {
    state = state.copyWith(
      selectedPaymentMethod: method,
      clearPaymentMethod: method == null,
      clearReferenceNumber: true,
    );
  }

  void setReferenceNumber(String? ref) {
    state = state.copyWith(
      referenceNumber: ref,
      clearReferenceNumber: ref == null,
    );
  }

  void setPaidAmount(double? amount) {
    state = state.copyWith(paidAmount: amount, clearPaidAmount: amount == null);
  }

  // ── Save / Checkout ─────────────────────────────────────────

  /// Save as draft (belum bayar).
  Future<TransactionOrder?> saveDraft() async {
    if (state.isEmpty) return null;
    return _saveOrder(
      state.status == TransactionStatus.confirmed
          ? TransactionStatus.confirmed
          : TransactionStatus.draft,
    );
  }

  /// Submit waiter order ke daftar pesanan masuk.
  Future<TransactionOrder?> submitWaiterOrder() async {
    if (state.isEmpty) return null;
    return _saveOrder(
      TransactionStatus.confirmed,
      forcedOrderSource: OrderSource.waiter,
    );
  }

  /// Kirim pesanan ke dapur langsung dari POS kasir (status: confirmed, kitchen: pending).
  Future<TransactionOrder?> sendOrderToKitchen() async {
    if (state.isEmpty) return null;
    return _saveOrder(
      TransactionStatus.confirmed,
      forcedOrderSource: OrderSource.pos,
    );
  }

  /// Complete payment and save as paid.
  Future<TransactionOrder?> checkout() async {
    if (state.isEmpty) return null;
    if (state.selectedPaymentMethod == null) return null;
    if (state.effectivePaidAmount < state.grandTotal) return null;
    return _saveOrder(TransactionStatus.paid);
  }

  Future<TransactionOrder?> _saveOrder(
    TransactionStatus status, {
    OrderSource? forcedOrderSource,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
      final outletId = bootstrap?.currentOutlet?.id;
      final businessId = bootstrap?.business?.id;

      if (outletId == null || businessId == null) {
        state = state.copyWith(
          isSaving: false,
          error: 'Outlet atau bisnis belum dipilih.',
        );
        return null;
      }

      // Generate invoice number if new order
      final orderId = state.orderId ?? _uuid.v4();
      final invoiceNumber =
          state.invoiceNumber ?? await repo.generateInvoiceNumber(outletId);

      final currentUserId = SupabaseService.currentUser?.id;
      final role = bootstrap?.effectiveRole ?? AppRole.owner;
      final resolvedOrderSource =
          state.orderSource ??
          forcedOrderSource ??
          (role == AppRole.waiter ? OrderSource.waiter : OrderSource.pos);
      final resolvedWaiterId =
          state.waiterId ??
          (resolvedOrderSource == OrderSource.waiter && role == AppRole.waiter
              ? currentUserId
              : null);
      final resolvedWaiterName =
          state.waiterName ??
          (resolvedOrderSource == OrderSource.waiter && role == AppRole.waiter
              ? bootstrap?.profile?.fullName
              : null);
      final cashierId = status == TransactionStatus.paid
          ? currentUserId
          : resolvedOrderSource == OrderSource.pos
          ? currentUserId
          : null;
      final cashierName =
          status == TransactionStatus.paid ||
              resolvedOrderSource == OrderSource.pos
          ? bootstrap?.profile?.fullName
          : null;

      // Build payments list
      List<TransactionPayment>? payments;
      if (status == TransactionStatus.paid &&
          state.selectedPaymentMethod != null) {
        // Use grandTotal if user hasn't entered paid amount,
        // ensure amount is always > 0 for the DB constraint.
        final payAmount = state.effectivePaidAmount > 0
            ? state.effectivePaidAmount
            : state.grandTotal;
        if (payAmount > 0) {
          payments = [
            TransactionPayment(
              id: _uuid.v4(),
              paymentMethodId: state.selectedPaymentMethod!.id,
              methodName: state.selectedPaymentMethod!.name,
              methodType: state.selectedPaymentMethod!.type,
              amount: payAmount,
              referenceNumber: state.referenceNumber,
            ),
          ];
        }
      }

      final order = TransactionOrder(
        id: orderId,
        outletId: outletId,
        businessId: businessId,
        invoiceNumber: invoiceNumber,
        customerName: state.customerName,
        customerPhone: state.customerPhone,
        customerEmail: state.customerEmail,
        tableNumber: state.tableNumber,
        diningOption: state.diningOption,
        status: status,
        kitchenStatus: state.kitchenStatus ?? KitchenStatus.pending,
        orderSource: resolvedOrderSource,
        notes: state.notes,
        subtotal: state.subtotal,
        discountTotal: state.discountTotal,
        taxAmount: state.taxAmount,
        grandTotal: state.grandTotal,
        paidAmount: status == TransactionStatus.paid
            ? state.effectivePaidAmount
            : 0,
        changeAmount: status == TransactionStatus.paid ? state.changeAmount : 0,
        cashierId: cashierId,
        cashierName: cashierName,
        waiterId: resolvedWaiterId,
        waiterName: resolvedWaiterName,
        items: state.items,
        discounts: state.discounts,
        payments: payments ?? [],
        paidAt: status == TransactionStatus.paid ? DateTime.now() : null,
      );

      final saved = await repo.saveTransaction(
        order,
        items: state.items,
        discounts: state.discounts,
        payments: payments,
      );

      // Decrement stock for paid transaction
      if (status == TransactionStatus.paid) {
        try {
          final menuRepo = ref.read(menuRepositoryProvider);
          final menuItems = ref.read(menuItemsProvider).valueOrNull ?? [];
          for (final item in state.items) {
            final menuItem = menuItems.cast<MenuItem?>().firstWhere(
                  (m) => m?.id == item.menuItemId,
                  orElse: () => null,
                );
            if (menuItem != null) {
              if (menuItem.isPackage && menuItem.packageItems.isNotEmpty) {
                // Potong stok masing-masing komponen paket!
                for (final pkgItem in menuItem.packageItems) {
                  final comp = menuItems.cast<MenuItem?>().firstWhere(
                        (m) => m?.id == pkgItem.componentMenuItemId,
                        orElse: () => null,
                      );
                  if (comp != null && comp.trackStockQuantity) {
                    final needed = pkgItem.quantity * item.quantity;
                    final newQty = comp.stockQuantity - needed;
                    await menuRepo.adjustMenuItemStock(
                      menuItemId: comp.id,
                      outletId: outletId,
                      newQuantity: newQty >= 0 ? newQty : 0,
                      note:
                          'Penjualan Paket ${menuItem.name} (${item.quantity}x) - Invoice ${saved.invoiceNumber}',
                      referenceType: 'sale',
                    );
                  }
                }
              } else if (menuItem.trackStockQuantity) {
                final newQty = menuItem.stockQuantity - item.quantity;
                await menuRepo.adjustMenuItemStock(
                  menuItemId: menuItem.id,
                  outletId: outletId,
                  newQuantity: newQty >= 0 ? newQty : 0,
                  note: 'Penjualan Invoice ${saved.invoiceNumber}',
                  referenceType: 'sale',
                );
              }
            }
          }
          ref.invalidate(menuItemsProvider);
          ref.invalidate(shiftLiveTotalsProvider);
          ref.invalidate(activeShiftProvider);
        } catch (e, stack) {
          debugPrint('Error updating stock after transaction: $e');
          debugPrint('Stack: $stack');
        }
      }

      state = state.copyWith(
        isSaving: false,
        orderId: saved.id,
        invoiceNumber: saved.invoiceNumber,
        orderSource: saved.orderSource,
        status: saved.status,
        waiterId: saved.waiterId,
        waiterName: saved.waiterName,
      );

      // Refresh order collections used across transaction/admin screens.
      try {
        ref.read(draftOrdersProvider.notifier).refresh();
        ref.read(confirmedOrdersProvider.notifier).refresh();
        ref.read(orderHistoryProvider.notifier).refresh();
        ref.read(pendingSyncCountProvider.notifier).refresh();
        ref.invalidate(kitchenOrdersProvider);
      } catch (_) {}

      return saved;
    } catch (error, stackTrace) {
      debugPrint('Error saving order: $error');
      debugPrint('Stack: $stackTrace');
      state = state.copyWith(isSaving: false, error: 'Gagal menyimpan: $error');
      return null;
    }
  }

  // ── Load existing order into cart ───────────────────────────

  void loadOrder(TransactionOrder order) {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final currentOutlet = bootstrap?.currentOutlet;
    state = CartState(
      orderId: order.id,
      invoiceNumber: order.invoiceNumber,
      orderSource: order.orderSource,
      status: order.status,
      waiterId: order.waiterId,
      waiterName: order.waiterName,
      items: order.items,
      discounts: order.discounts,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerEmail: order.customerEmail,
      tableNumber: order.tableNumber,
      diningOption: order.diningOption,
      notes: order.notes,
      kitchenStatus: order.kitchenStatus,
      useTieredPricing: state.useTieredPricing,
      isTaxEnabled: currentOutlet?.taxEnabled ?? state.isTaxEnabled,
      taxName: currentOutlet?.taxName ?? state.taxName,
      taxRate: currentOutlet?.taxRate ?? state.taxRate,
      isTaxInclusive: currentOutlet?.isTaxInclusive ?? state.isTaxInclusive,
    );
  }

  // ── Clear ───────────────────────────────────────────────────

  void clearCart() {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final currentOutlet = bootstrap?.currentOutlet;
    state = CartState(
      items: const [],
      discounts: const [],
      useTieredPricing: state.useTieredPricing,
      isTaxEnabled: currentOutlet?.taxEnabled ?? state.isTaxEnabled,
      taxName: currentOutlet?.taxName ?? state.taxName,
      taxRate: currentOutlet?.taxRate ?? state.taxRate,
      isTaxInclusive: currentOutlet?.isTaxInclusive ?? state.isTaxInclusive,
    );
  }

  void setIsSaving(bool value) {
    state = state.copyWith(isSaving: value);
  }
}
