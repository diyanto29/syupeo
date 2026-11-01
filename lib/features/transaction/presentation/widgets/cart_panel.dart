import 'dart:async';
import 'package:flutter/services.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/services/payment_notification_models.dart';
import 'package:dpos/core/services/payment_notification_service.dart';
import 'package:dpos/core/widgets/pro_feature_dialog.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/discount_management/data/discount_repository.dart';
import 'package:dpos/features/discount_management/domain/discount_models.dart';
import 'package:dpos/features/discount_management/domain/promo_models.dart';
import 'package:dpos/features/discount_management/data/promo_repository.dart';
import 'package:dpos/features/settings/data/qris_settings_repository.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/presentation/widgets/qris_display_modal.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:dpos/features/settings/data/order_type_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/customer_debt/presentation/widgets/customer_picker_sheet.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key, this.onClose, this.compact = false});
  final VoidCallback? onClose;
  final bool compact;

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final List<DetectedPaymentEvent> _detectedPayments = [];
  StreamSubscription<DetectedPaymentEvent>? _paymentStreamSub;
  bool _isProcessingAutoConfirm = false;

  @override
  void initState() {
    super.initState();
    _loadInitialDetectedPayments();
    _initPaymentListener();
  }

  void _loadInitialDetectedPayments() {
    final notifier = ref.read(paymentNotificationProvider.notifier);
    final queue = notifier.recentQueue;
    if (queue.isNotEmpty) {
      _detectedPayments.addAll(queue);
    }
  }

  void _initPaymentListener() {
    final notifier = ref.read(paymentNotificationProvider.notifier);
    _paymentStreamSub = notifier.paymentEvents.listen((event) {
      if (!mounted) return;
      final cart = ref.read(cartProvider);
      final settings = ref.read(paymentNotificationProvider).valueOrNull;

      setState(() {
        _detectedPayments.removeWhere((p) => p.id == event.id);
        _detectedPayments.insert(0, event);
      });

      // Jangan proses jika cart kosong atau sedang checkout
      if (cart.isEmpty || _isProcessingAutoConfirm) return;

      // Cek apakah dialog/screen pembayaran lain yang sedang aktif di atas
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrentRoute) return;

      // Jika nominal persis sama dan mode auto-confirm aktif, serta hanya ada 1 yang cocok persis
      final exactMatches = _detectedPayments.where(
        (p) => (p.amount - cart.grandTotal).abs() < 1,
      );
      if (settings?.autoConfirmExactMatch == true &&
          (event.amount - cart.grandTotal).abs() < 1 &&
          exactMatches.length == 1) {
        _applyDetectedPayment(event, autoCheckout: true);
      }
    });
  }

  void _dismissPayment(DetectedPaymentEvent event) {
    ref.read(paymentNotificationProvider.notifier).dismissPayment(event.id);
    setState(() {
      _detectedPayments.removeWhere((p) => p.id == event.id);
    });
  }

  void _applyDetectedPayment(
    DetectedPaymentEvent event, {
    bool autoCheckout = false,
  }) {
    if (_isProcessingAutoConfirm) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final cartNotifier = ref.read(cartProvider.notifier);
    final methods = ref.read(paymentMethodsProvider).valueOrNull ?? [];

    ref.read(paymentNotificationProvider.notifier).markAsUsed(event.id);
    setState(() {
      _detectedPayments.removeWhere((p) => p.id == event.id);
    });

    final matchedMethod = methods.firstWhere(
      (m) =>
          m.type == 'qris' ||
          m.type == 'transfer' ||
          m.type == 'bank_transfer' ||
          m.name.toLowerCase().contains(event.appName.toLowerCase()),
      orElse: () => methods.isNotEmpty ? methods.first : methods.first,
    );

    if (methods.isNotEmpty) {
      cartNotifier.selectPaymentMethod(matchedMethod);
    }
    cartNotifier.setPaidAmount(event.amount);

    if (autoCheckout) {
      _doCheckout(detectedEvent: event);
    }
  }

  @override
  void dispose() {
    _paymentStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final onClose = widget.onClose;
    final cart = ref.watch(cartProvider);
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final role = bootstrap?.effectiveRole ?? AppRole.owner;
    final isWaiter = role == AppRole.waiter;
    final isFnb = bootstrap?.business?.isFnb ?? false;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Eagerly watch promo providers so active promotions are immediately loaded
    final bxgyPromos = ref.watch(buyXGetYPromosProvider).valueOrNull;
    final tebusPromos = ref.watch(tebusMurahPromosProvider).valueOrNull;

    final eligibleBxgyPromos = ref
        .read(cartProvider.notifier)
        .getEligibleBxgyOffers(customPromos: bxgyPromos);
    final eligibleTebusPromos = ref
        .read(cartProvider.notifier)
        .getEligibleTebusMurahPromos(customPromos: tebusPromos);

    if (cart.isEmpty) {
      return _EmptyCart(onClose: onClose, compact: compact);
    }

    return Column(
      children: [
        // Header
        Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(14, 10, 6, 4)
              : const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 5 : 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F2),
                  borderRadius: BorderRadius.circular(compact ? 9 : 12),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: compact ? 18 : 22,
                  color: const Color(0xFF8B6B5D),
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Text(
                  'Keranjang',
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 16 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: compact ? 20 : 24,
                  color: const Color(0xFFF43F5E),
                ),
                onPressed: () => _confirmClear(context, ref),
                tooltip: 'Kosongkan',
                visualDensity: compact
                    ? const VisualDensity(horizontal: -3, vertical: -3)
                    : null,
                constraints: compact
                    ? const BoxConstraints.tightFor(width: 32, height: 32)
                    : null,
                padding: compact ? EdgeInsets.zero : null,
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: compact ? 20 : 24,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: onClose,
                  visualDensity: compact
                      ? const VisualDensity(horizontal: -3, vertical: -3)
                      : null,
                  constraints: compact
                      ? const BoxConstraints.tightFor(width: 32, height: 32)
                      : null,
                  padding: compact ? EdgeInsets.zero : null,
                ),
            ],
          ),
        ),

        if (isFnb)
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 16,
              0,
              compact ? 10 : 16,
              compact ? 6 : 8,
            ),
            child: _buildDiningOptionBar(context, ref, cart, compact),
          ),

        if (eligibleBxgyPromos.isNotEmpty)
          _BxgyOfferBanner(promos: eligibleBxgyPromos, compact: compact),

        if (eligibleTebusPromos.isNotEmpty)
          _TebusMurahOfferBanner(promos: eligibleTebusPromos, compact: compact),

        // Items
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 8,
            ),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return _CartItemTile(item: item, compact: compact);
            },
          ),
        ),

        // Summary + Actions
        Container(
          padding: EdgeInsets.all(compact ? 14 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(compact ? 20 : 32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Applied discounts
              if (cart.discounts.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: compact ? 10 : 16),
                  child: Column(
                    children: cart.discounts
                        .map(
                          (disc) => Container(
                            margin: EdgeInsets.only(bottom: compact ? 4 : 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 16,
                              vertical: compact ? 8 : 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(
                                compact ? 12 : 16,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_offer_rounded,
                                  size: compact ? 14 : 18,
                                  color: const Color(0xFF10B981),
                                ),
                                SizedBox(width: compact ? 8 : 12),
                                Expanded(
                                  child: Text(
                                    disc.name.toUpperCase(),
                                    style: GoogleFonts.manrope(
                                      fontSize: compact ? 11 : 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '-${_currency.format(disc.appliedAmount)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: compact ? 12 : 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                SizedBox(width: compact ? 6 : 12),
                                GestureDetector(
                                  onTap: () => ref
                                      .read(cartProvider.notifier)
                                      .removeDiscount(disc.id),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: compact ? 14 : 18,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

              _SummaryRow(
                label: 'SUBTOTAL',
                value: cart.subtotal,
                compact: compact,
              ),
              if (cart.itemDiscountTotal > 0)
                _SummaryRow(
                  label: 'DISKON ITEM',
                  value: -cart.itemDiscountTotal,
                  isDiscount: true,
                  compact: compact,
                ),
              if (cart.orderDiscountTotal > 0)
                _SummaryRow(
                  label: 'DISKON ORDER',
                  value: -cart.orderDiscountTotal,
                  isDiscount: true,
                  compact: compact,
                ),
              if (cart.isTaxEnabled && cart.taxAmount > 0)
                _SummaryRow(
                  label: cart.isTaxInclusive
                      ? 'TERMASUK ${cart.taxName.toUpperCase()} (${cart.taxRate.toStringAsFixed(cart.taxRate % 1 == 0 ? 0 : 1)}%)'
                      : 'PAJAK ${cart.taxName.toUpperCase()} (${cart.taxRate.toStringAsFixed(cart.taxRate % 1 == 0 ? 0 : 1)}%)',
                  value: cart.taxAmount,
                  compact: compact,
                ),

              SizedBox(height: compact ? 10 : 16),
              Row(
                children: [
                  Text(
                    'TOTAL',
                    style: GoogleFonts.manrope(
                      fontSize: compact ? 15 : 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _currency.format(cart.grandTotal),
                    style: GoogleFonts.manrope(
                      fontSize: compact ? 22 : 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF98B35),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 24),

              // Customer Selection Row
              _buildCustomerRow(context, ref, cart, compact),
              SizedBox(height: compact ? 8 : 12),

              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: _SecondaryActionButton(
                      icon: Icons.local_offer_outlined,
                      label: 'Diskon',
                      onTap: () => _showDiscountPicker(context, ref),
                      compact: compact,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: _SecondaryActionButton(
                      icon: Icons.save_outlined,
                      label: cart.status == TransactionStatus.confirmed
                          ? 'Perbarui'
                          : 'Simpan',
                      onTap: cart.isSaving
                          ? null
                          : () => _saveDraft(context, ref),
                      compact: compact,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),

              // if (!isWaiter) ...[
              //   Padding(
              //     padding: EdgeInsets.only(bottom: compact ? 8 : 10),
              //     child: SizedBox(
              //       width: double.infinity,
              //       height: compact ? 38 : 44,
              //       child: OutlinedButton.icon(
              //         onPressed: cart.isSaving || _isProcessingAutoConfirm
              //             ? null
              //             : () => _sendToKitchen(context, ref),
              //         icon: const Icon(
              //           Icons.soup_kitchen_rounded,
              //           size: 18,
              //           color: Color(0xFF005ECC),
              //         ),
              //         label: Text(
              //           'Kirim ke Dapur (KOT)',
              //           style: GoogleFonts.manrope(
              //             fontSize: compact ? 12.5 : 14,
              //             fontWeight: FontWeight.w700,
              //             color: const Color(0xFF005ECC),
              //           ),
              //         ),
              //         style: OutlinedButton.styleFrom(
              //           side: const BorderSide(
              //             color: Color(0xFFFDBA74),
              //             width: 1.2,
              //           ),
              //           backgroundColor: const Color(0xFFFFF7ED),
              //           shape: RoundedRectangleBorder(
              //             borderRadius: BorderRadius.circular(compact ? 14 : 18),
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),
              // ],
              if (isWaiter)
                _WaiterOrderSummaryCard(
                  cart: cart,
                  compact: compact,
                  onTap: () => _editWaiterOrderInfo(context, ref, cart),
                ),

              if (isWaiter) SizedBox(height: compact ? 8 : 12),

              // Notifikasi Pembayaran Terdeteksi (QRIS / Transfer Masuk)
              if (!isWaiter && _detectedPayments.isNotEmpty) ...[
                _buildDetectedPaymentsBanner(
                  context,
                  cart.grandTotal,
                  scheme,
                  theme,
                ),
                SizedBox(height: compact ? 6 : 8),
              ],

              // Tombol Pembayaran QRIS Dinamis (Langsung dari Cart)
              if (!isWaiter) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: compact ? 44 : 52,
                    child: ElevatedButton.icon(
                      onPressed: cart.isSaving || _isProcessingAutoConfirm
                          ? null
                          : () => _showQrisModal(context, cart.grandTotal),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: Text(
                        'QRIS Dinamis Otomatis',
                        style: GoogleFonts.manrope(
                          fontSize: compact ? 13.5 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            compact ? 16 : 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Primary action button (Bayar Lainnya / Kirim Pesanan)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cart.isSaving || _isProcessingAutoConfirm
                      ? null
                      : () => isWaiter
                            ? _submitWaiterOrder(context, ref)
                            : _showPayment(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWaiter
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, compact ? 44 : 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(compact ? 16 : 24),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isWaiter
                            ? Icons.send_rounded
                            : Icons.credit_card_rounded,
                        size: compact ? 18 : 22,
                      ),
                      SizedBox(width: compact ? 8 : 12),
                      Text(
                        isWaiter ? 'Kirim Pesanan' : 'Metode Bayar Lainnya',
                        style: GoogleFonts.manrope(
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: compact ? 18 : 22,
                      ),
                    ],
                  ),
                ),
              ),

              if (cart.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  cart.error!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetectedPaymentsBanner(
    BuildContext context,
    double grandTotal,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final sorted = List<DetectedPaymentEvent>.from(_detectedPayments)
      ..sort((a, b) {
        final aExact = (a.amount - grandTotal).abs() < 1;
        final bExact = (b.amount - grandTotal).abs() < 1;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });

    final event = sorted.first;
    final isExact = (event.amount - grandTotal).abs() < 1;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isExact ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExact ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  (isExact ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExact
                  ? Icons.check_circle_rounded
                  : Icons.notifications_active_rounded,
              size: 16,
              color: isExact
                  ? const Color(0xFF047857)
                  : const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.appName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isExact
                            ? const Color(0xFF065F46)
                            : const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currency.format(event.amount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isExact
                            ? const Color(0xFF047857)
                            : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
                if (event.sender != null && event.sender!.isNotEmpty)
                  Text(
                    'Pengirim: ${event.sender}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF475569),
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _applyDetectedPayment(event, autoCheckout: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isExact
                  ? const Color(0xFF059669)
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Gunakan',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => _dismissPayment(event),
          ),
        ],
      ),
    );
  }

  Future<void> _doCheckout({
    DetectedPaymentEvent? detectedEvent,
    String? paymentMethodType,
  }) async {
    final business = ref.read(homeBootstrapProvider).valueOrNull?.business;
    if (business == null) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    setState(() => _isProcessingAutoConfirm = true);
    ref.read(cartProvider.notifier).setIsSaving(true);

    try {
      final count = await ref
          .read(transactionRepositoryProvider)
          .countMonthlyTransactions(business.id);
      final featureGate = ref.read(featureGateProvider);
      final maxTransactions = featureGate.getLimit('max_transactions');

      if (count >= maxTransactions) {
        if (!mounted) return;
        setState(() => _isProcessingAutoConfirm = false);
        ref.read(cartProvider.notifier).setIsSaving(false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limit Transaksi Tercapai'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Text(
              'Batas transaksi bulanan untuk paket Anda adalah $maxTransactions. '
              'Upgrade ke paket Pro untuk kuota transaksi tak terbatas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error checking transaction limit in cart: $e');
    }

    List<PaymentMethodOption> methods =
        ref.read(paymentMethodsProvider).valueOrNull ?? [];
    if (methods.isEmpty) {
      try {
        methods = await ref.read(paymentMethodsProvider.future);
      } catch (_) {}
    }

    final targetType =
        paymentMethodType ?? (detectedEvent != null ? 'qris' : null);
    final matchedMethod = methods.firstWhere(
      (m) =>
          (targetType != null && m.type == targetType) ||
          m.type == 'qris' ||
          m.type == 'cash',
      orElse: () => methods.isNotEmpty
          ? methods.first
          : const PaymentMethodOption(
              id: 'qris_default',
              code: 'qris',
              name: 'QRIS',
              type: 'qris',
              isActive: true,
              sortOrder: 1,
              requiresReference: false,
              allowsChange: false,
            ),
    );
    ref.read(cartProvider.notifier).selectPaymentMethod(matchedMethod);
    final paidAmt = detectedEvent?.amount ?? cart.grandTotal;
    ref.read(cartProvider.notifier).setPaidAmount(paidAmt);

    final order = await ref.read(cartProvider.notifier).checkout();

    if (!mounted) return;
    setState(() => _isProcessingAutoConfirm = false);

    if (order != null) {
      ref.read(cartProvider.notifier).clearCart();
      HapticFeedback.mediumImpact();

      // Cetak struk otomatis jika printer terhubung
      _autoPrintReceipt(order);

      // Tampilkan popup sukses
      _showSuccessDialog(order, detectedEvent);
    } else {
      ref.read(cartProvider.notifier).setIsSaving(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyelesaikan pesanan: ${ref.read(cartProvider).error ?? "Periksa keranjang"}',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _autoPrintReceipt(TransactionOrder order) async {
    try {
      await ref.read(receiptServiceProvider).printReceipt(order);
    } catch (e) {
      debugPrint('Print error in cart: $e');
    }
  }

  Future<void> _showQrisModal(BuildContext context, double totalAmount) async {
    final settings =
        ref.read(qrisSettingsProvider).valueOrNull ?? const QrisSettings();
    final completed = await QrisDisplayModal.show(
      context,
      settings: settings,
      totalAmount: totalAmount,
      onConfigurePressed: () => context.pushNamed(RouteNames.qrisSettings),
    );

    if (completed == true && mounted) {
      _doCheckout(paymentMethodType: 'qris');
    }
  }

  void _showSuccessDialog(
    TransactionOrder order,
    DetectedPaymentEvent? detectedEvent,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF059669),
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Berhasil!',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.invoiceNumber,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Text(
                    _currency.format(order.grandTotal),
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (detectedEvent != null) ...[
                    Text(
                      'Otomatis Dikonfirmasi (${detectedEvent.appName})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                    if (detectedEvent.sender != null &&
                        detectedEvent.sender!.isNotEmpty)
                      Text(
                        'Pengirim: ${detectedEvent.sender}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ] else ...[
                    const Text(
                      'Metode: QRIS Dinamis',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(receiptServiceProvider).printReceipt(order);
            },
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Cetak Struk'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Transaksi Baru'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        widget.onClose?.call();
      }
    });
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: const Text('Semua item akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }

  void _showDiscountPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _DiscountPickerSheet(),
    );
  }

  Future<void> _saveDraft(BuildContext context, WidgetRef ref) async {
    final order = await ref.read(cartProvider.notifier).saveDraft();
    if (order != null && context.mounted) {
      final savedMessage = order.status == TransactionStatus.confirmed
          ? 'Pesanan ${order.invoiceNumber} diperbarui'
          : 'Draft ${order.invoiceNumber} tersimpan';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedMessage),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      ref.read(cartProvider.notifier).clearCart();
      widget.onClose?.call();
    }
  }

  Future<void> _submitWaiterOrder(BuildContext context, WidgetRef ref) async {
    final order = await ref.read(cartProvider.notifier).submitWaiterOrder();
    if (order != null && context.mounted) {
      final tableLabel = order.tableNumber != null
          ? ' untuk meja ${order.tableNumber}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pesanan ${order.invoiceNumber}$tableLabel masuk ke daftar pesanan.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      ref.read(cartProvider.notifier).clearCart();
      widget.onClose?.call();
    }
  }

  void _showPayment(BuildContext context, WidgetRef ref) {
    context.push(RoutesPath.transactionPayment);
  }

  Widget _buildDiningOptionBar(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    bool compact,
  ) {
    final orderTypes = ref.watch(activeOrderTypesProvider);
    final effectiveOrderTypes = orderTypes.isNotEmpty
        ? orderTypes
        : OrderTypeConfig.defaultListForOutlet('');

    if (effectiveOrderTypes.length <= 2) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: effectiveOrderTypes.map((ot) {
            final option = DiningOption.fromDb(ot.code);
            final isSelected = cart.diningOption == option;
            return Expanded(
              child: _buildDiningOptionItem(
                context,
                ref,
                cart,
                ot,
                option,
                isSelected,
                compact,
              ),
            );
          }).toList(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: effectiveOrderTypes.map((ot) {
            final option = DiningOption.fromDb(ot.code);
            final isSelected = cart.diningOption == option;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildDiningOptionItem(
                context,
                ref,
                cart,
                ot,
                option,
                isSelected,
                compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDiningOptionItem(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    OrderTypeConfig ot,
    DiningOption option,
    bool isSelected,
    bool compact,
  ) {
    final requiresTable = ot.requiresTable;
    final primaryColor = requiresTable
        ? const Color(0xFF1D4ED8)
        : (ot.code == 'take_away'
              ? const Color(0xFFC2410C)
              : const Color(0xFF0F766E));

    return InkWell(
      onTap: () {
        ref.read(cartProvider.notifier).setDiningOption(option);
        if (requiresTable && cart.tableNumber == null) {
          _showTablePicker(context, ref, cart);
        }
      },
      borderRadius: BorderRadius.circular(compact ? 9 : 11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(compact ? 9 : 11),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ot.emoji, style: TextStyle(fontSize: compact ? 12 : 14)),
            const SizedBox(width: 5),
            Text(
              isSelected && requiresTable && cart.tableNumber != null
                  ? '${ot.name} • M${cart.tableNumber}'
                  : ot.name,
              style: GoogleFonts.manrope(
                fontSize: compact ? 10.5 : 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? primaryColor : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected && requiresTable) ...[
              const SizedBox(width: 3),
              InkWell(
                onTap: () => _showTablePicker(context, ref, cart),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: compact ? 13 : 15,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showTablePicker(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    final controller = TextEditingController(
      text: cart.tableNumber?.toString() ?? '',
    );
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.table_restaurant_rounded,
              color: Color(0xFF1D4ED8),
            ),
            const SizedBox(width: 10),
            Text(
              'Nomor Meja',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan nomor meja untuk pesanan Dine In ini:',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Contoh: 1, 2, 12...',
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1),
            child: const Text('Tanpa Meja'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (result == -1) {
        ref.read(cartProvider.notifier).setTableNumber(null);
      } else {
        ref.read(cartProvider.notifier).setTableNumber(result);
      }
    }
  }

  Widget _buildCustomerRow(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    bool compact,
  ) {
    final hasCustomer =
        cart.customerName != null && cart.customerName!.trim().isNotEmpty;

    if (hasCustomer) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_rounded,
              size: 16,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final selected = await CustomerPickerSheet.show(context);
                  if (selected != null) {
                    ref
                        .read(cartProvider.notifier)
                        .setCustomerInfo(
                          id: selected.id,
                          name: selected.name,
                          phone: selected.phone,
                        );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.customerName!,
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF15803D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cart.customerPhone != null &&
                        cart.customerPhone!.isNotEmpty)
                      Text(
                        cart.customerPhone!,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Lepas Pelanggan',
              onPressed: () {
                ref.read(cartProvider.notifier).clearCustomerInfo();
              },
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final selected = await CustomerPickerSheet.show(context);
        if (selected != null) {
          ref
              .read(cartProvider.notifier)
              .setCustomerInfo(
                id: selected.id,
                name: selected.name,
                phone: selected.phone,
              );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add_outlined,
              size: 16,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              '+ Hubungkan Pelanggan / Kasbon',
              style: GoogleFonts.manrope(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editWaiterOrderInfo(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _WaiterOrderInfoSheet(cart: cart),
    );
  }
}

class _WaiterOrderInfoSheet extends ConsumerStatefulWidget {
  const _WaiterOrderInfoSheet({required this.cart});
  final CartState cart;

  @override
  ConsumerState<_WaiterOrderInfoSheet> createState() =>
      _WaiterOrderInfoSheetState();
}

class _WaiterOrderInfoSheetState extends ConsumerState<_WaiterOrderInfoSheet> {
  late final TextEditingController _customerController;
  late final TextEditingController _tableController;
  late final TextEditingController _notesController;
  late DiningOption _diningOption;

  @override
  void initState() {
    super.initState();
    _diningOption = widget.cart.diningOption;
    _customerController = TextEditingController(
      text: widget.cart.customerName ?? '',
    );
    _tableController = TextEditingController(
      text: widget.cart.tableNumber?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.cart.notes ?? '');
  }

  @override
  void dispose() {
    _customerController.dispose();
    _tableController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Detail Pesanan Waiter',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lengkapi meja, nama pelanggan, atau catatan sebelum order dikirim ke kasir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Dining Option Selector
            Builder(
              builder: (context) {
                final orderTypes = ref.watch(activeOrderTypesProvider);
                final effectiveOrderTypes = orderTypes.isNotEmpty
                    ? orderTypes
                    : OrderTypeConfig.defaultListForOutlet('');

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: effectiveOrderTypes.map((ot) {
                      final option = DiningOption.fromDb(ot.code);
                      final isSelected = _diningOption == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Text(
                            ot.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          label: Text(ot.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _diningOption = option);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            if (_diningOption == DiningOption.dineIn) ...[
              TextField(
                controller: _tableController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nomor Meja',
                  hintText: 'Contoh: 12',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _customerController,
              decoration: InputDecoration(
                labelText: 'Nama Pelanggan',
                hintText: 'Opsional (ketik nama atau pilih kontak)',
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.contacts_rounded,
                    color: Color(0xFF10B981),
                  ),
                  tooltip: 'Pilih dari Kontak Pelanggan',
                  onPressed: () async {
                    final selected = await CustomerPickerSheet.show(context);
                    if (selected != null) {
                      _customerController.text = selected.name;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Catatan Order',
                hintText: 'Opsional, mis. tanpa sambal / alergi kacang',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final tableValue = _tableController.text.trim();
                  ref
                      .read(cartProvider.notifier)
                      .setDiningOption(_diningOption);
                  ref
                      .read(cartProvider.notifier)
                      .setTableNumber(
                        _diningOption == DiningOption.takeAway ||
                                tableValue.isEmpty
                            ? null
                            : int.tryParse(tableValue),
                      );
                  ref
                      .read(cartProvider.notifier)
                      .setCustomerInfo(name: _customerController.text.trim());
                  ref
                      .read(cartProvider.notifier)
                      .setNotes(_notesController.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Simpan Detail'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaiterOrderSummaryCard extends StatelessWidget {
  const _WaiterOrderSummaryCard({
    required this.cart,
    required this.compact,
    required this.onTap,
  });

  final CartState cart;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tableLabel = cart.diningOption == DiningOption.takeAway
        ? 'Take Away (Bungkus)'
        : (cart.tableNumber != null
              ? 'Meja ${cart.tableNumber}'
              : 'Meja belum diisi');
    final customerLabel = (cart.customerName ?? '').trim().isNotEmpty
        ? cart.customerName!.trim()
        : 'Pelanggan belum diisi';
    final notesLabel = (cart.notes ?? '').trim().isNotEmpty
        ? cart.notes!.trim()
        : 'Belum ada catatan tambahan';

    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(compact ? 18 : 22),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 12 : 14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: compact ? 18 : 20,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail pesanan waiter',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tableLabel • $customerLabel',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notesLabel,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF1D4ED8),
                size: compact ? 20 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cart Item Tile ────────────────────────────────────────────

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item, required this.compact});
  final TransactionItem item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      margin: EdgeInsets.only(
        bottom: compact ? 8 : 16,
        left: compact ? 1 : 4,
        right: compact ? 1 : 4,
      ),
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: compact ? 10 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image/Icon
              Container(
                width: compact ? 42 : 64,
                height: compact ? 42 : 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F2),
                  borderRadius: BorderRadius.circular(compact ? 12 : 16),
                ),
                child: Icon(
                  Icons.fastfood_rounded,
                  color: const Color(0xFF8B6B5D),
                  size: compact ? 22 : 32,
                ),
              ),
              SizedBox(width: compact ? 10 : 16),
              // Name and Variant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 1 : 4),
                    Text(
                      item.variantName?.toUpperCase() ??
                          (item.isPackage ? 'MENU PAKET' : 'ORIGINAL'),
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w700,
                        color: item.isPackage
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.isPackage &&
                        item.packageComponents.isNotEmpty) ...[
                      SizedBox(height: compact ? 2 : 4),
                      for (final comp in item.packageComponents)
                        Text(
                          '+ $comp',
                          style: GoogleFonts.manrope(
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                    ],
                    if (item.promoTag != null) ...[
                      SizedBox(height: compact ? 3 : 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.isTebusMurah
                              ? Colors.teal.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.promoTag!,
                          style: GoogleFonts.manrope(
                            fontSize: compact ? 8 : 10,
                            fontWeight: FontWeight.w800,
                            color: item.isTebusMurah
                                ? Colors.teal.shade800
                                : Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.hasDiscount)
                    Text(
                      _currency.format(item.rawSubtotal),
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 10 : 12,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  Text(
                    _currency.format(
                      item.hasDiscount ? item.subtotal : item.unitPrice,
                    ),
                    style: GoogleFonts.manrope(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      color: item.hasDiscount
                          ? const Color(0xFFE11D48)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Applied Discount Badge
          if (item.hasDiscount) ...[
            SizedBox(height: compact ? 8 : 12),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 5 : 8,
              ),
              decoration: BoxDecoration(
                color: item.promoTag == '[BOGO - GRATIS]'
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(compact ? 8 : 12),
                border: item.promoTag == '[BOGO - GRATIS]'
                    ? Border.all(color: const Color(0xFFFECDD3))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.promoTag == '[BOGO - GRATIS]'
                        ? Icons.card_giftcard_rounded
                        : Icons.local_offer_rounded,
                    size: compact ? 11 : 14,
                    color: item.promoTag == '[BOGO - GRATIS]'
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF10B981),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  Flexible(
                    child: Text(
                      '${item.discountName?.toUpperCase()} (-${_currency.format(item.discountApplied)})',
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w800,
                        color: item.promoTag == '[BOGO - GRATIS]'
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF10B981),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  GestureDetector(
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .removeItemDiscount(item.id),
                    child: Icon(
                      Icons.close_rounded,
                      size: compact ? 11 : 14,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Note Field
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            SizedBox(height: compact ? 5 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 5 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(compact ? 8 : 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: compact ? 12 : 16,
                    color: const Color(0xFF94A3B8),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  Flexible(
                    child: Text(
                      item.notes!,
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: compact ? 8 : 16),
          Row(
            children: [
              // Quantity controls
              _QuantityControl(
                quantity: item.quantity,
                compact: compact,
                onChanged: (q) async {
                  if (cart.useTieredPricing && q > item.quantity) {
                    final menuItems =
                        ref.read(menuItemsProvider).valueOrNull ?? [];
                    final menuItem = menuItems.cast<MenuItem?>().firstWhere(
                      (m) => m?.id == item.menuItemId,
                      orElse: () => null,
                    );

                    if (menuItem != null) {
                      final newTier = menuItem.getApplicableTier(q);
                      final oldTier = menuItem.getApplicableTier(item.quantity);

                      if (newTier != null && newTier != oldTier) {
                        final confirmed = await _showTierConfirmation(
                          context,
                          menuItem.name,
                          newTier,
                        );
                        if (!confirmed) {
                          ref
                              .read(cartProvider.notifier)
                              .updateItemQuantity(
                                item.id,
                                q,
                                forceNormalPrice: true,
                              );
                          return;
                        }
                      }
                    }
                  }
                  ref
                      .read(cartProvider.notifier)
                      .updateItemQuantity(item.id, q);
                },
              ),
              const Spacer(),
              // Action buttons
              _CircularItemAction(
                icon: Icons.local_offer_outlined,
                isActive: item.hasDiscount,
                activeColor: const Color(0xFF10B981),
                onTap: () => _showItemDiscountPicker(context, ref, item),
                compact: compact,
              ),
              SizedBox(width: compact ? 4 : 6),
              _CircularItemAction(
                icon: Icons.sticky_note_2_outlined,
                isActive: item.notes != null && item.notes!.isNotEmpty,
                activeColor: const Color(0xFFF97316),
                onTap: () => _editNotes(context, ref, item),
                compact: compact,
              ),
              SizedBox(width: compact ? 4 : 6),
              _CircularItemAction(
                icon: Icons.price_change_outlined,
                isActive: item.forceBasePrice,
                activeColor: const Color(0xFF3B82F6),
                onTap: () => _editPrice(context, ref, item),
                compact: compact,
              ),
              SizedBox(width: compact ? 4 : 6),
              _CircularItemAction(
                icon: Icons.delete_outline_rounded,
                isActive: false,
                activeColor: const Color(0xFFF43F5E),
                onTap: () =>
                    ref.read(cartProvider.notifier).removeItem(item.id),
                iconColor: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showItemDiscountPicker(
    BuildContext context,
    WidgetRef ref,
    TransactionItem item,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _ItemDiscountPickerSheet(itemId: item.id, itemName: item.displayName),
    );
  }

  void _editNotes(BuildContext context, WidgetRef ref, TransactionItem item) {
    showDialog(
      context: context,
      builder: (_) => _ItemNotesDialog(
        initialNotes: item.notes ?? '',
        onSave: (notes) {
          ref.read(cartProvider.notifier).updateItemNotes(item.id, notes);
        },
      ),
    );
  }

  void _editPrice(BuildContext context, WidgetRef ref, TransactionItem item) {
    final featureGate = ref.read(featureGateProvider);
    final isEditablePriceAllowed = featureGate.isEnabled('editable_price');

    if (!isEditablePriceAllowed) {
      showDialog(
        context: context,
        builder: (context) => const ProFeatureDialog(
          featureName: 'Bisa Edit Harga Jual (Nego)',
          description:
              'Sesuaikan harga jual item secara langsung di kasir untuk transaksi tawar-menawar atau kebutuhan nego khusus.',
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _ItemPriceDialog(
        itemName: item.displayName,
        initialPrice: item.unitPrice,
        onSave: (price) {
          ref.read(cartProvider.notifier).updateItemPrice(item.id, price);
        },
      ),
    );
  }
}

class _ItemNotesDialog extends StatefulWidget {
  const _ItemNotesDialog({required this.initialNotes, required this.onSave});
  final String initialNotes;
  final ValueChanged<String> onSave;

  @override
  State<_ItemNotesDialog> createState() => _ItemNotesDialogState();
}

class _ItemNotesDialogState extends State<_ItemNotesDialog> {
  late final TextEditingController _controller;

  static const _quickTags = [
    '🥡 Bungkus',
    '🍽️ Makan di Sini',
    '🌶️ Pedas',
    '🥦 Tidak Pedas',
    '🧊 Kurang Es',
    '🚫 Tanpa Bawang',
    '🥣 Kuah Pisah',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    final cleanTag = tag.trim();
    final current = _controller.text.trim();
    if (current.contains(cleanTag)) {
      final parts = current
          .split(RegExp(r',\s*'))
          .where((p) => p.trim() != cleanTag && p.trim().isNotEmpty)
          .toList();
      _controller.text = parts.join(', ');
    } else {
      if (current.isEmpty) {
        _controller.text = cleanTag;
      } else {
        _controller.text = '$current, $cleanTag';
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Catatan Item'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Contoh: Bungkus, pedas level 3...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              autofocus: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              'Pilihan Cepat:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickTags.map((tag) {
                final isSelected = _controller.text.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (_) => _toggleTag(tag),
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_controller.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _ItemPriceDialog extends StatefulWidget {
  const _ItemPriceDialog({
    required this.itemName,
    required this.initialPrice,
    required this.onSave,
  });
  final String itemName;
  final double initialPrice;
  final ValueChanged<double> onSave;

  @override
  State<_ItemPriceDialog> createState() => _ItemPriceDialogState();
}

class _ItemPriceDialogState extends State<_ItemPriceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final priceStr = RupiahInputHelper.format(widget.initialPrice);
    _controller = TextEditingController(text: priceStr);
    _controller.selection = TextSelection.collapsed(offset: priceStr.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Harga - ${widget.itemName}'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          prefixText: 'Rp ',
          labelText: 'Harga Baru',
          hintText: 'Masukkan harga jual nego',
        ),
        keyboardType: TextInputType.number,
        inputFormatters: const [RupiahTextInputFormatter()],
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final newPrice = RupiahInputHelper.parseToDouble(_controller.text);
            if (newPrice >= 0) {
              widget.onSave(newPrice);
              Navigator.pop(context);
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

// ── Quantity Control ──────────────────────────────────────────

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.onChanged,
    required this.compact,
  });
  final int quantity;
  final ValueChanged<int> onChanged;
  final bool compact;

  void _showManualQuantityDialog(BuildContext context) {
    final controller = TextEditingController(text: '$quantity')
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: '$quantity'.length,
      );

    showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Ubah Jumlah (Qty)',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (val) {
                  final newQ = int.tryParse(val.trim());
                  if (newQ != null && newQ >= 0) {
                    Navigator.pop(ctx, newQ);
                  }
                },
              ),
              const SizedBox(height: 14),
              // Preset chips (+5, +10, +20, +50, +100)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [5, 10, 20, 50, 100].map((addAmount) {
                  return ActionChip(
                    label: Text('+$addAmount'),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onPressed: () {
                      final curr = int.tryParse(controller.text) ?? 0;
                      controller.text = '${curr + addAmount}';
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: () {
                final newQ = int.tryParse(controller.text.trim());
                if (newQ != null && newQ >= 0) {
                  Navigator.pop(ctx, newQ);
                }
              },
              child: Text(
                'Simpan',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    ).then((result) {
      if (result != null) {
        onChanged(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyButton(
            icon: Icons.remove_rounded,
            onTap: () => onChanged(quantity - 1),
            compact: compact,
          ),
          Tooltip(
            message: 'Klik untuk ubah jumlah manual',
            child: InkWell(
              onTap: () => _showManualQuantityDialog(context),
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 12,
                  vertical: compact ? 4 : 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$quantity',
                      style: GoogleFonts.manrope(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      size: compact ? 11 : 13,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            onTap: () => onChanged(quantity + 1),
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.compact,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 6 : 8),
          child: Icon(
            icon,
            size: compact ? 14 : 16,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _CircularItemAction extends StatelessWidget {
  const _CircularItemAction({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.compact,
    this.iconColor,
  });
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final bool compact;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 36.0;
    return Material(
      color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 8 : 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: compact ? 15 : 18,
            color: isActive
                ? activeColor
                : (iconColor ?? const Color(0xFF94A3B8)),
          ),
        ),
      ),
    );
  }
}

// ── Summary Row ──────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isDiscount = false,
    this.compact = false,
  });
  final String label;
  final double value;
  final bool isDiscount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
              color: isDiscount
                  ? const Color(0xFF10B981)
                  : const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            isDiscount
                ? '-${_currency.format(value.abs())}'
                : _currency.format(value),
            style: GoogleFonts.manrope(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              color: isDiscount
                  ? const Color(0xFF10B981)
                  : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small Action Button ──────────────────────────────────────

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: compact ? 16 : 20),
      label: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF1E293B),
        minimumSize: Size(0, compact ? 42 : 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
        elevation: 0,
      ),
    );
  }
}

// ── Empty Cart ───────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({this.onClose, this.compact = false});
  final VoidCallback? onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (onClose != null)
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ),
        const Spacer(),
        Icon(
          Icons.shopping_cart_outlined,
          size: compact ? 56 : 64,
          color: scheme.outline.withValues(alpha: 0.4),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          'Keranjang kosong',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: scheme.outline,
            fontSize: compact ? 18 : null,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          'Pilih produk untuk memulai transaksi',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.outline,
            fontSize: compact ? 11 : null,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

// ── Discount Picker ──────────────────────────────────────────

class _DiscountPickerSheet extends ConsumerWidget {
  const _DiscountPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountsAsync = ref.watch(discountsProvider);
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diskon Keseluruhan Transaksi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Diskon ini berlaku untuk total transaksi',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            discountsAsync.when(
              data: (discounts) {
                final active = discounts
                    .where((d) => d.isAvailableNow)
                    .toList();
                if (active.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Tidak ada diskon aktif',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return Column(
                  children: active.map((disc) {
                    final alreadyAdded = cart.discounts.any(
                      (d) => d.discountId == disc.id,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: alreadyAdded
                            ? scheme.primary.withValues(alpha: 0.08)
                            : scheme.surfaceContainerLow,
                        leading: Icon(
                          Icons.local_offer_rounded,
                          color: alreadyAdded ? scheme.primary : scheme.outline,
                        ),
                        title: Text(disc.name),
                        subtitle: Text(
                          disc.type == DiscountType.percentage
                              ? '${disc.percentageValue?.toStringAsFixed(0)}%${disc.usesMaxDiscount ? ' (maks ${_currency.format(disc.maxDiscountAmount!)})' : ''}'
                              : _currency.format(disc.amountValue ?? 0),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: alreadyAdded
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: scheme.primary,
                              )
                            : null,
                        onTap: alreadyAdded
                            ? null
                            : () {
                                ref
                                    .read(cartProvider.notifier)
                                    .addDiscount(disc);
                                Navigator.pop(context);
                              },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Item Discount Picker ───────────────────────────────────

class _ItemDiscountPickerSheet extends ConsumerWidget {
  const _ItemDiscountPickerSheet({
    required this.itemId,
    required this.itemName,
  });
  final String itemId;
  final String itemName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountsAsync = ref.watch(discountsProvider);
    final cart = ref.watch(cartProvider);
    final currentItem = cart.items.where((i) => i.id == itemId).firstOrNull;
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diskon Item',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih diskon untuk: $itemName',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Option to remove discount if already applied
            if (currentItem?.hasDiscount == true) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: scheme.errorContainer.withValues(alpha: 0.3),
                  leading: Icon(
                    Icons.remove_circle_rounded,
                    color: scheme.error,
                  ),
                  title: const Text('Hapus Diskon'),
                  subtitle: Text(
                    'Diskon saat ini: ${currentItem!.discountName}',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () {
                    ref.read(cartProvider.notifier).removeItemDiscount(itemId);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
            discountsAsync.when(
              data: (discounts) {
                final active = discounts
                    .where((d) => d.isAvailableNow)
                    .toList();
                if (active.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Tidak ada diskon aktif',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return Column(
                  children: active.map((disc) {
                    final isApplied = currentItem?.discountId == disc.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: isApplied
                            ? Colors.green.shade50
                            : scheme.surfaceContainerLow,
                        leading: Icon(
                          Icons.local_offer_rounded,
                          color: isApplied
                              ? Colors.green.shade700
                              : scheme.outline,
                        ),
                        title: Text(disc.name),
                        subtitle: Text(
                          disc.type == DiscountType.percentage
                              ? '${disc.percentageValue?.toStringAsFixed(0)}%${disc.usesMaxDiscount ? ' (maks ${_currency.format(disc.maxDiscountAmount!)})' : ''}'
                              : _currency.format(disc.amountValue ?? 0),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: isApplied
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green.shade700,
                              )
                            : null,
                        onTap: isApplied
                            ? null
                            : () {
                                ref
                                    .read(cartProvider.notifier)
                                    .addItemDiscount(itemId, disc);
                                Navigator.pop(context);
                              },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Future<bool> _showTierConfirmation(
  BuildContext context,
  String productName,
  TieredPrice tier,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF98B35)),
              const SizedBox(width: 12),
              const Text('Gunakan Harga Grosir?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jumlah pembelian $productName telah mencapai batas minimal ${tier.minQuantity} unit.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Harga Baru:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _currency.format(tier.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Tetap Harga Normal',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Ya, Terapkan'),
            ),
          ],
        ),
      ) ??
      false;
}

// ── Beli X Gratis Y Offer Banner ───────────────────────────────────

class _BxgyOfferBanner extends StatelessWidget {
  const _BxgyOfferBanner({required this.promos, required this.compact});

  final List<BuyXGetYPromo> promos;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final promo = promos.first;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 4 : 6,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bonus Beli X Gratis Y Tersedia!',
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  promo.mode == BuyXGetYMode.sameProduct
                      ? '${promo.name} ➔ Ambil ${promo.rewardQty}x GRATIS'
                      : '${promo.name} ➔ Ambil ${promo.rewardQty}x ${promo.rewardItemName ?? "Hadiah"} GRATIS',
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Consumer(
            builder: (context, ref, _) {
              return FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFE11D48),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: compact ? 6 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  ref.read(cartProvider.notifier).claimBxgyReward(promo);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Hadiah gratis "${promo.name}" ditambahkan ke keranjang!',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  'Klaim',
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Tebus Murah Offer Banner & Sheet ──────────────────────────────

class _TebusMurahOfferBanner extends StatelessWidget {
  const _TebusMurahOfferBanner({required this.promos, required this.compact});

  final List<TebusMurahPromo> promos;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 4 : 8,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pelanggan Berhak Tebus Murah!',
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${promos.length} penawaran spesial tersedia',
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => _TebusMurahOfferSheet(promos: promos),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F766E),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 6 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Tawarkan',
              style: GoogleFonts.manrope(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TebusMurahOfferSheet extends ConsumerWidget {
  const _TebusMurahOfferSheet({required this.promos});
  final List<TebusMurahPromo> promos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMenuItems = ref.watch(menuItemsProvider).valueOrNull ?? [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.loyalty_rounded,
                    color: Color(0xFF0F766E),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penawaran Tebus Murah',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Tawarkan produk khusus ini ke pembeli',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: promos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final promo = promos[index];
                  final rewardItem = allMenuItems.cast<MenuItem?>().firstWhere(
                    (m) => m?.id == promo.rewardMenuItemId,
                    orElse: () => null,
                  );

                  final normalPrice =
                      promo.rewardItemPrice ?? rewardItem?.price ?? 0;
                  final discountValue = (normalPrice - promo.specialPrice)
                      .clamp(0.0, double.infinity);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'HEMAT ${_currency.format(discountValue)}',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              promo.mode.label,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          promo.rewardItemName ??
                              rewardItem?.name ??
                              'Produk Tebus',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          promo.name,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (normalPrice > 0)
                                  Text(
                                    _currency.format(normalPrice),
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  _currency.format(promo.specialPrice),
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: rewardItem == null
                                  ? null
                                  : () {
                                      ref
                                          .read(cartProvider.notifier)
                                          .claimTebusMurah(promo, rewardItem);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${rewardItem.name} berhasil ditebus seharga ${_currency.format(promo.specialPrice)}!',
                                          ),
                                          backgroundColor: const Color(
                                            0xFF0F766E,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Klaim Tebus Murah'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
        ),
      ),
    );
  }
}
