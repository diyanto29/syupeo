import 'dart:async';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/transaction/data/invoice_service.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/settings/data/qris_settings_repository.dart';
import 'package:dpos/core/services/ad_interstitial_service.dart';
import 'package:dpos/core/services/payment_notification_models.dart';
import 'package:dpos/core/services/payment_notification_service.dart';
import 'package:dpos/core/widgets/bluetooth_prompt_sheet.dart';
import 'package:dpos/features/customer_debt/data/customer_debt_repository.dart';
import 'package:dpos/features/customer_debt/domain/customer_debt_models.dart';
import 'package:dpos/features/customer_debt/presentation/widgets/customer_picker_sheet.dart';
import 'package:dpos/features/customer_debt/state/customer_debt_providers.dart';
import 'package:dpos/features/transaction/presentation/widgets/qris_display_modal.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Full-page payment screen.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _paidController = TextEditingController();
  final _refController = TextEditingController();
  TransactionOrder? _completedOrder;
  bool _isPrinting = false;
  final List<DetectedPaymentEvent> _detectedPayments = [];
  StreamSubscription<DetectedPaymentEvent>? _paymentStreamSub;
  DateTime? _debtDueDate;

  @override
  void initState() {
    super.initState();
    _debtDueDate = DateTime.now().add(const Duration(days: 7));
    AdInterstitialService.loadAd();
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

  void _applyDetectedPayment(DetectedPaymentEvent event, {bool autoCheckout = false}) {
    final cartNotifier = ref.read(cartProvider.notifier);
    final methods = ref.read(paymentMethodsProvider).valueOrNull ?? [];

    // Hapus dari antrean karena sudah digunakan untuk pembayaran ini
    ref.read(paymentNotificationProvider.notifier).markAsUsed(event.id);
    setState(() {
      _detectedPayments.removeWhere((p) => p.id == event.id);
    });

    // Pilih metode yang cocok (qris / transfer / e-wallet)
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
    _paidController.text = _currency.format(event.amount);
    final senderLabel = event.sender != null && event.sender!.isNotEmpty
        ? ' (Pengirim: ${event.sender})'
        : '';
    _refController.text = '${event.appName}$senderLabel: ${event.rawTitle ?? "Transfer"}';

    if (autoCheckout) {
      _doCheckout();
    }
  }

  @override
  void dispose() {
    _paymentStreamSub?.cancel();
    _paidController.dispose();
    _refController.dispose();
    if (_completedOrder != null) {
      ref.read(cartProvider.notifier).clearCart();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final qrisSettings =
        ref.watch(qrisSettingsProvider).valueOrNull ?? const QrisSettings();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (_completedOrder != null) {
      return _buildCompletedPage(context, ref, scheme, theme);
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pembayaran',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Grand total card ───────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 20,
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF12343B), Color(0xFF2B4E6F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF12343B,
                            ).withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Tagihan',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currency.format(cart.grandTotal),
                            style: GoogleFonts.manrope(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (cart.discountTotal > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Hemat ${_currency.format(cart.discountTotal)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.greenAccent.shade200,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_detectedPayments.isNotEmpty) ...[
                      _buildDetectedPaymentsSection(
                        context,
                        cart.grandTotal,
                        scheme,
                        theme,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Pelanggan Transaksi ───────────────────────────
                    _buildCustomerSelector(context, ref, cart, scheme, theme),
                    const SizedBox(height: 20),

                    // ── Payment methods ───────────────────────
                    Text(
                      'Metode Bayar',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    methodsAsync.when(
                      data: (methods) {
                        final allMethods = [
                          ...methods,
                          if (!methods.any((m) => m.type == 'debt'))
                            const PaymentMethodOption(
                              id: 'debt_builtin',
                              code: 'debt',
                              name: 'Kasbon / Tempo',
                              type: 'debt',
                              isActive: true,
                              sortOrder: 99,
                              requiresReference: false,
                              allowsChange: false,
                            ),
                        ];

                        return Column(
                          children: allMethods.map((method) {
                            final selected =
                                cart.selectedPaymentMethod?.id == method.id ||
                                (method.type == 'debt' && cart.selectedPaymentMethod?.type == 'debt');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: selected
                                  ? scheme.primary.withValues(alpha: 0.1)
                                  : scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  ref
                                      .read(cartProvider.notifier)
                                      .selectPaymentMethod(method);
                                  if (method.allowsChange) {
                                    _paidController.clear();
                                  } else {
                                    final formatted = RupiahInputHelper.format(cart.grandTotal);
                                    _paidController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(offset: formatted.length),
                                    );
                                    ref
                                        .read(cartProvider.notifier)
                                        .setPaidAmount(cart.grandTotal);
                                  }
                                  if (method.type == 'qris') {
                                    _showQrisModal(context, cart.grandTotal);
                                  } else if (method.type == 'debt') {
                                    if (cart.customerName == null || cart.customerName!.isEmpty) {
                                      final selectedCustomer = await CustomerPickerSheet.show(context);
                                      if (selectedCustomer != null) {
                                        ref.read(cartProvider.notifier).setCustomerInfo(
                                              id: selectedCustomer.id,
                                              name: selectedCustomer.name,
                                              phone: selectedCustomer.phone,
                                            );
                                      }
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? scheme.primary.withValues(
                                                  alpha: 0.15,
                                                )
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconForType(method.type),
                                          size: 22,
                                          color: selected
                                              ? scheme.primary
                                              : scheme.outline,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              method.name,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            if (method.type == 'debt')
                                              Text(
                                                'Catat piutang ke Buku Kasbon pelanggan',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: const Color(0xFFB45309),
                                                  fontSize: 11,
                                                ),
                                              )
                                            else if (method.accountLabel != null)
                                              Text(
                                                method.accountLabel!,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: scheme.outline,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (selected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: method.type == 'debt' ? const Color(0xFFD97706) : scheme.primary,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (e, _) => Text('Error: $e'),
                    ),

                    const SizedBox(height: 16),

                    // ── QRIS Action Banner (jika QRIS dipilih) ──
                    if (cart.selectedPaymentMethod?.type == 'qris') ...[
                      _buildQrisActionBanner(context, cart.grandTotal, qrisSettings),
                      const SizedBox(height: 16),
                    ],

                    // ── Kasbon Action Banner (jika Kasbon dipilih) ──
                    if (cart.selectedPaymentMethod?.type == 'debt') ...[
                      _buildDebtActionBanner(context, ref, cart, scheme, theme),
                      const SizedBox(height: 16),
                    ],

                    // ── Paid amount (cash) ─────────────────────
                    if (cart.selectedPaymentMethod?.allowsChange == true) ...[
                      Text(
                        'Jumlah Bayar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _paidController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [
                          RupiahTextInputFormatter(),
                        ],
                        onChanged: (v) {
                          final amount = RupiahInputHelper.parseToDouble(v);
                          ref.read(cartProvider.notifier).setPaidAmount(amount);
                        },
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          hintText: '0',
                          filled: true,
                          fillColor: scheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: const Text(
                                'Uang Pas',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                final formatted = RupiahInputHelper.format(cart.grandTotal);
                                _paidController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(offset: formatted.length),
                                );
                                ref
                                    .read(cartProvider.notifier)
                                    .setPaidAmount(cart.grandTotal);
                              },
                            ),
                          ),
                        ),
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (cart.changeAmount > 0)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.currency_exchange_rounded,
                                color: Colors.green.shade700,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Kembalian',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const Spacer(),
                              Text(
                                _currency.format(cart.changeAmount),
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],

                    // ── Reference number ──────────────────────
                    if (cart.selectedPaymentMethod?.requiresReference ==
                        true) ...[
                      Text(
                        'No. Referensi',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _refController,
                        onChanged: (v) => ref
                            .read(cartProvider.notifier)
                            .setReferenceNumber(v),
                        decoration: InputDecoration(
                          hintText: 'Nomor approval / referensi',
                          filled: true,
                          fillColor: scheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (cart.error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cart.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),

            // ── Bottom Checkout Button ────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF002147).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canCheckout(cart) && !cart.isSaving
                      ? () => _doCheckout()
                      : null,
                  icon: cart.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          cart.selectedPaymentMethod?.type == 'debt'
                              ? Icons.assignment_turned_in_rounded
                              : Icons.check_circle_rounded,
                        ),
                  label: Text(
                    cart.isSaving
                        ? 'Memproses...'
                        : (cart.selectedPaymentMethod?.type == 'debt'
                            ? 'Catat Transaksi Kasbon'
                            : 'Proses Pembayaran'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: cart.selectedPaymentMethod?.type == 'debt'
                        ? const Color(0xFFD97706)
                        : null,
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Completed page (after checkout success) ─────────────────

  Widget _buildCompletedPage(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final order = _completedOrder!;
    final isDebt = order.payments.any((p) => p.methodType == 'debt');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(cartProvider.notifier).clearCart();
        context.go(RoutesPath.dashboard);
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Selesai & Transaksi Baru',
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              context.go(RoutesPath.dashboard);
            },
          ),
        ),
        body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDebt ? const Color(0xFFFEF3C7) : Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDebt ? Icons.menu_book_rounded : Icons.check_circle_rounded,
                    size: 72,
                    color: isDebt ? const Color(0xFFD97706) : Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isDebt ? 'Kasbon Berhasil Dicatat!' : 'Pembayaran Berhasil!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isDebt && order.customerName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Piutang atas nama ${order.customerName} telah ditambahkan ke Buku Kasbon.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.invoiceNumber,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Total
                Text(
                  _currency.format(order.grandTotal),
                  style: GoogleFonts.manrope(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),

                if (order.changeAmount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.currency_exchange_rounded,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('Kembalian: ', style: theme.textTheme.bodyMedium),
                        Text(
                          _currency.format(order.changeAmount),
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Auto-print status
                if (_isPrinting) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mencetak struk...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 36),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.print_rounded,
                        label: 'Cetak Struk',
                        onTap: () => _printReceipt(context, ref, order),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.soup_kitchen_rounded,
                        label: 'Tiket Dapur',
                        onTap: () => _printKitchenReceipt(context, ref, order),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isDebt && order.customerPhone != null && order.customerPhone!.isNotEmpty)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat_rounded,
                          label: 'Nota WA',
                          onTap: () => _sendDebtWhatsApp(context, ref, order),
                        ),
                      )
                    else
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.share_rounded,
                          label: 'Kirim Invoice',
                          onTap: () => _shareInvoice(context, ref, order),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clearCart();
                      context.go(RoutesPath.dashboard);
                    },
                    icon: const Icon(Icons.add_circle_rounded),
                    label: const Text('Transaksi Baru'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // ── Helpers ─────────────────────────────────────────────────

  bool _canCheckout(CartState cart) {
    if (cart.error != null) return false;
    if (cart.selectedPaymentMethod == null) return false;
    if (cart.selectedPaymentMethod!.type == 'debt') {
      if (cart.customerName == null || cart.customerName!.trim().isEmpty) {
        return false;
      }
      return true;
    }
    if (cart.selectedPaymentMethod!.allowsChange &&
        cart.effectivePaidAmount < cart.grandTotal) {
      return false;
    }
    return true;
  }

  Future<void> _doCheckout() async {
    final business = ref.read(homeBootstrapProvider).valueOrNull?.business;
    if (business == null) return;

    final cart = ref.read(cartProvider);
    final isDebt = cart.selectedPaymentMethod?.type == 'debt';
    final savedCustomerId = cart.customerId;
    final savedCustomerName = cart.customerName;
    final savedCustomerPhone = cart.customerPhone;

    // Pengecekan Limit Transaksi Bulanan
    setState(() => ref.read(cartProvider.notifier).setIsSaving(true));
    try {
      final count = await ref
          .read(transactionRepositoryProvider)
          .countMonthlyTransactions(business.id);
      final featureGate = ref.read(featureGateProvider);
      final maxTransactions = featureGate.getLimit('max_transactions');

      if (count >= maxTransactions) {
        if (!mounted) return;
        setState(() => ref.read(cartProvider.notifier).setIsSaving(false));
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limit Transaksi Tercapai'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  'Batas transaksi bulanan untuk paket Anda adalah $maxTransactions. '
                  'Upgrade ke paket Pro untuk mendapatkan kuota transaksi tak terbatas.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pushNamed(RouteNames.businessAccountManagement);
                },
                child: const Text('Upgrade Sekarang'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error checking transaction limit: $e');
    }

    final order = await ref.read(cartProvider.notifier).checkout();
    if (order != null && mounted) {
      if (isDebt) {
        try {
          String? resolvedCustomerId = savedCustomerId;
          if (resolvedCustomerId == null || resolvedCustomerId.isEmpty) {
            final customers = ref.read(customersProvider).valueOrNull ?? [];
            final matched = customers.where(
              (c) => (savedCustomerPhone != null && savedCustomerPhone.isNotEmpty && c.phone == savedCustomerPhone) ||
                     c.name.toLowerCase() == savedCustomerName?.toLowerCase(),
            ).firstOrNull;
            if (matched != null) {
              resolvedCustomerId = matched.id;
            } else {
              final newC = await ref.read(customerDebtRepositoryProvider).createCustomer(
                businessId: business.id,
                name: savedCustomerName ?? 'Pelanggan',
                phone: savedCustomerPhone ?? '0',
              );
              resolvedCustomerId = newC.id;
            }
          }

          await ref.read(customerDebtRepositoryProvider).createDebt(
            businessId: business.id,
            outletId: order.outletId,
            customerId: resolvedCustomerId,
            orderId: order.id,
            invoiceNumber: order.invoiceNumber,
            totalAmount: order.grandTotal,
            dueDate: _debtDueDate,
            notes: order.notes,
          );
          ref.invalidate(customerDebtsProvider);
          ref.invalidate(customersProvider);
        } catch (e) {
          debugPrint('Error creating customer debt record: $e');
        }
      }

      ref.read(cartProvider.notifier).clearCart();
      setState(() => _completedOrder = order);
      AdInterstitialService.showAd();
      _autoPrintReceipt(order);
    } else if (mounted) {
      setState(() => ref.read(cartProvider.notifier).setIsSaving(false));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyelesaikan pembayaran: ${ref.read(cartProvider).error ?? "Periksa keranjang"}',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Automatically print receipt once after successful checkout.
  Future<void> _autoPrintReceipt(TransactionOrder order) async {
    if (!mounted) return;
    setState(() => _isPrinting = true);

    try {
      final success = await ref
          .read(receiptServiceProvider)
          .printReceipt(order);
      if (!mounted) return;
      setState(() => _isPrinting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✓ Struk berhasil dicetak'
                : '✗ Gagal mencetak. Periksa koneksi printer.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Auto-print error: $e');
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    TransactionOrder order,
  ) async {
    final printerService = ref.read(thermalPrinterServiceProvider);
    final isBtEnabled = await printerService.bluetoothEnabled;
    if (!isBtEnabled && context.mounted) {
      final action = await BluetoothPromptSheet.show(
        context,
        type: BluetoothPromptType.enableBluetooth,
      );
      if (action == BluetoothPromptAction.primaryAction) {
        await printerService.requestEnableBluetooth();
        await Future.delayed(const Duration(seconds: 1));
      } else if (action == BluetoothPromptAction.openSettings) {
        await printerService.openBluetoothSettings();
        return;
      } else {
        return;
      }
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Mencetak struk...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final success = await ref.read(receiptServiceProvider).printReceipt(order);

    if (!context.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Struk berhasil dicetak'
              : '✗ Gagal mencetak. Periksa printer.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _printKitchenReceipt(
    BuildContext context,
    WidgetRef ref,
    TransactionOrder order,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Mencetak tiket dapur...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final success =
        await ref.read(receiptServiceProvider).printKitchenReceipt(order);

    if (!context.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Tiket dapur berhasil dicetak'
              : '✗ Gagal mencetak tiket dapur. Periksa printer.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareInvoice(
    BuildContext context,
    WidgetRef ref,
    TransactionOrder order,
  ) {
    final invoiceText = ref
        .read(invoiceServiceProvider)
        .generateInvoiceText(order);
    Clipboard.setData(ClipboardData(text: invoiceText));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '✓ Invoice disalin ke clipboard. Tempel di WhatsApp/chat.',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _sendDebtWhatsApp(
    BuildContext context,
    WidgetRef ref,
    TransactionOrder order,
  ) async {
    final phone = order.customerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp pelanggan tidak tersedia.')),
      );
      return;
    }

    final businessName = ref.read(homeBootstrapProvider).valueOrNull?.business?.name ?? 'Toko';
    final repo = ref.read(customerDebtRepositoryProvider);

    final dummyDebt = CustomerDebt(
      id: order.id,
      businessId: order.businessId,
      outletId: order.outletId,
      customerId: '',
      customerName: order.customerName ?? 'Pelanggan',
      customerPhone: phone,
      invoiceNumber: order.invoiceNumber,
      totalAmount: order.grandTotal,
      remainingAmount: order.grandTotal,
      dueDate: _debtDueDate,
      status: DebtStatus.unpaid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repo.sendWhatsAppReminder(
      debt: dummyDebt,
      businessName: businessName,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membuka WhatsApp untuk mengirim rincian kasbon...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCustomerSelector(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final hasCustomer = cart.customerName != null && cart.customerName!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pelanggan Transaksi',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasCustomer)
              TextButton(
                onPressed: () async {
                  final selected = await CustomerPickerSheet.show(context);
                  if (selected != null) {
                    ref.read(cartProvider.notifier).setCustomerInfo(
                          id: selected.id,
                          name: selected.name,
                          phone: selected.phone,
                        );
                  }
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Ganti Pelanggan', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasCustomer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cart.customerName!,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      if (cart.customerPhone != null && cart.customerPhone!.isNotEmpty)
                        Text(
                          cart.customerPhone!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Lepas Pelanggan',
                  onPressed: () {
                    ref.read(cartProvider.notifier).clearCustomerInfo();
                  },
                ),
              ],
            ),
          )
        else
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final selected = await CustomerPickerSheet.show(context);
                if (selected != null) {
                  ref.read(cartProvider.notifier).setCustomerInfo(
                        id: selected.id,
                        name: selected.name,
                        phone: selected.phone,
                      );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_add_outlined, size: 20, color: scheme.outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pilih Pelanggan / Kontak Toko',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: scheme.outline),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDebtActionBanner(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    Customer? matchedCustomer;
    if (cart.customerId != null && cart.customerId!.isNotEmpty) {
      matchedCustomer = customers.where((c) => c.id == cart.customerId).firstOrNull;
    } else if (cart.customerPhone != null && cart.customerPhone!.isNotEmpty) {
      matchedCustomer = customers.where((c) => c.phone == cart.customerPhone).firstOrNull;
    } else if (cart.customerName != null && cart.customerName!.isNotEmpty) {
      matchedCustomer = customers.where((c) => c.name.toLowerCase() == cart.customerName!.toLowerCase()).firstOrNull;
    }

    final hasOverLimit = matchedCustomer != null &&
        matchedCustomer.creditLimit > 0 &&
        (matchedCustomer.currentDebt + cart.grandTotal) > matchedCustomer.creditLimit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pencatatan Piutang Kasbon',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'Pesanan akan dicatat di Buku Kasbon atas nama pelanggan.',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Peringatan jika belum pilih pelanggan
          if (cart.customerName == null || cart.customerName!.trim().isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kasbon wajib mencantumkan nama pelanggan.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selected = await CustomerPickerSheet.show(context);
                      if (selected != null) {
                        ref.read(cartProvider.notifier).setCustomerInfo(
                              id: selected.id,
                              name: selected.name,
                              phone: selected.phone,
                            );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Pilih', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Info Plafon & Hutang Berjalan
          if (matchedCustomer != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plafon Kasbon',
                        style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                      ),
                      Text(
                        matchedCustomer.creditLimit > 0 ? _currency.format(matchedCustomer.creditLimit) : 'Tanpa Batas',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Hutang Berjalan',
                        style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _currency.format(matchedCustomer.currentDebt),
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasOverLimit) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peringatan: Total belanja kasbon (${_currency.format(cart.grandTotal)}) ditambah hutang saat ini melebihi plafon pelanggan (${_currency.format(matchedCustomer.creditLimit)}).',
                        style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF991B1B), fontWeight: FontWeight.w700, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],

          // Pilih Jatuh Tempo
          Text(
            'Jatuh Tempo (Janji Bayar):',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dueChip('7 Hari', 7),
                const SizedBox(width: 6),
                _dueChip('14 Hari', 14),
                const SizedBox(width: 6),
                _dueChip('30 Hari', 30),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF92400E)),
                  label: Text(
                    _debtDueDate != null
                        ? DateFormat('d MMM yyyy', 'id_ID').format(_debtDueDate!)
                        : 'Pilih Tanggal',
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _debtDueDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _debtDueDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dueChip(String label, int days) {
    final targetDate = DateTime.now().add(Duration(days: days));
    final isSelected = _debtDueDate != null &&
        _debtDueDate!.year == targetDate.year &&
        _debtDueDate!.month == targetDate.month &&
        _debtDueDate!.day == targetDate.day;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF92400E),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFD97706),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
      ),
      onSelected: (_) {
        setState(() => _debtDueDate = targetDate);
      },
    );
  }

  Widget _buildQrisActionBanner(
      BuildContext context, double totalAmount, QrisSettings qrisSettings) {
    final hasImage = qrisSettings.hasQrisImage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QRIS Toko',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                Text(
                  hasImage
                      ? 'Tampilkan kode QR untuk discan pelanggan'
                      : 'Belum ada QRIS. Ketuk Atur untuk mengunggah.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: const Color(0xFF1E40AF),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              if (hasImage) {
                _showQrisModal(context, totalAmount);
              } else {
                context.pushNamed(RouteNames.qrisSettings);
              }
            },
            icon: Icon(
              hasImage ? Icons.visibility_rounded : Icons.settings_rounded,
              size: 16,
            ),
            label: Text(hasImage ? 'Buka QR' : 'Atur'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
      List<PaymentMethodOption> methods =
          ref.read(paymentMethodsProvider).valueOrNull ?? [];
      if (methods.isEmpty) {
        try {
          methods = await ref.read(paymentMethodsProvider.future);
        } catch (_) {}
      }

      final qrisMethod = methods.firstWhere(
        (m) => m.type == 'qris',
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
      ref.read(cartProvider.notifier).selectPaymentMethod(qrisMethod);
      ref.read(cartProvider.notifier).setPaidAmount(totalAmount);
      await _doCheckout();
    }
  }

  Widget _buildDetectedPaymentsSection(
    BuildContext context,
    double grandTotal,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    // Urutkan: yang cocok persis ditaruh paling atas, baru sisanya berdasarkan waktu terbaru
    final sorted = List<DetectedPaymentEvent>.from(_detectedPayments)
      ..sort((a, b) {
        final aExact = (a.amount - grandTotal).abs() < 1;
        final bExact = (b.amount - grandTotal).abs() < 1;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 18,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Text(
                  'Uang Masuk Terdeteksi (${sorted.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
            if (sorted.length > 1)
              TextButton(
                onPressed: () {
                  setState(() {
                    for (final event in _detectedPayments) {
                      ref
                          .read(paymentNotificationProvider.notifier)
                          .dismissPayment(event.id);
                    }
                    _detectedPayments.clear();
                  });
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  foregroundColor: scheme.outline,
                ),
                child: const Text('Hapus Semua', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...sorted.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDetectedPaymentCard(
                context,
                event,
                grandTotal,
                scheme,
                theme,
              ),
            )),
      ],
    );
  }

  Widget _buildDetectedPaymentCard(
    BuildContext context,
    DetectedPaymentEvent event,
    double grandTotal,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final isExactMatch = (event.amount - grandTotal).abs() < 1;
    final isSufficient = event.amount >= grandTotal;
    final elapsedSec = DateTime.now().difference(event.timestamp).inSeconds;
    final timeStr = elapsedSec < 60
        ? 'Baru saja'
        : '${(elapsedSec / 60).floor()} menit lalu';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExactMatch
            ? const Color(0xFFECFDF5)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExactMatch
              ? const Color(0xFF10B981)
              : const Color(0xFF3B82F6),
          width: isExactMatch ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExactMatch ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                .withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isExactMatch ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExactMatch ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                  color: isExactMatch ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                  size: 18,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isExactMatch
                                ? const Color(0xFF065F46)
                                : const Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isExactMatch
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isExactMatch
                                ? 'COCOK PAS'
                                : (isSufficient ? 'LEBIH' : 'KURANG'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isExactMatch
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isExactMatch
                                ? const Color(0xFF047857)
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (event.sender != null && event.sender!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: isExactMatch
                                ? const Color(0xFF047857)
                                : const Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Pengirim: ${event.sender}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isExactMatch
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      isExactMatch
                          ? 'Nominal pas dengan tagihan kasir saat ini'
                          : isSufficient
                              ? 'Nominal lebih dari tagihan kasir'
                              : 'Nominal kurang dari total tagihan',
                      style: TextStyle(
                        fontSize: 11,
                        color: isExactMatch
                            ? const Color(0xFF047857)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => _dismissPayment(event),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nominal Masuk',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    Text(
                      _currency.format(event.amount),
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _applyDetectedPayment(event),
                  style: FilledButton.styleFrom(
                    backgroundColor: isExactMatch
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Gunakan', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'cash' => Icons.payments_rounded,
      'card' => Icons.credit_card_rounded,
      'qris' => Icons.qr_code_rounded,
      'bank_transfer' => Icons.account_balance_rounded,
      'e_wallet' => Icons.account_balance_wallet_rounded,
      'debt' => Icons.menu_book_rounded,
      _ => Icons.payment_rounded,
    };
  }
}

// ── Action Button ────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
