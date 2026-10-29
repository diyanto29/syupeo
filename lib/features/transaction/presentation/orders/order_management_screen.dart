import 'dart:async';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:dpos/features/transaction/presentation/widgets/void_order_dialog.dart';
import 'package:dpos/features/transaction/presentation/history/transaction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateFormat = DateFormat('dd MMM, HH:mm', 'id_ID');

/// Full-page order management screen with tabs for incoming orders and drafts.
class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  ConsumerState<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends ConsumerState<OrderManagementScreen> {
  TransactionOrder? _selectedOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 850;

    // Keep selected order synchronized with latest stream/data
    final confirmedOrders = ref.watch(confirmedOrdersProvider).value ?? [];
    final draftOrders = ref.watch(draftOrdersProvider).value ?? [];
    final allOrders = [...confirmedOrders, ...draftOrders];
    TransactionOrder? effectiveSelectedOrder = _selectedOrder;
    if (effectiveSelectedOrder != null) {
      final match = allOrders.where((o) => o.id == effectiveSelectedOrder!.id).firstOrNull;
      if (match != null) {
        effectiveSelectedOrder = match;
      }
    }

    final mainTabs = DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pesanan & Draft',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: theme.textTheme.bodySmall,
            tabs: const [
              Tab(text: 'Pesanan Masuk'),
              Tab(text: 'Draft / Tersimpan'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _IncomingOrdersTab(
                  isDesktop: isDesktop,
                  selectedOrder: effectiveSelectedOrder,
                  onSelectOrder: (order) => setState(() => _selectedOrder = order),
                ),
                _DraftOrdersTab(
                  isDesktop: isDesktop,
                  selectedOrder: effectiveSelectedOrder,
                  onSelectOrder: (order) => setState(() => _selectedOrder = order),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: widget.padding,
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: mainTabs,
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: (screenWidth * 0.42).clamp(390.0, 480.0),
                  child: _buildSidePanel(context, effectiveSelectedOrder),
                ),
              ],
            )
          : mainTabs,
    );
  }

  Widget _buildSidePanel(BuildContext context, TransactionOrder? order) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (order == null) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 44,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Detail Pesanan & Draft',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih salah satu pesanan masuk atau draft pada daftar untuk melihat rincian item, mencetak tiket, atau memproses pembayaran.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: TransactionDetailView(
              key: ValueKey(order.id),
              order: order,
              isSidePanel: true,
              onClose: () => setState(() => _selectedOrder = null),
              onOrderUpdated: () {
                ref.read(confirmedOrdersProvider.notifier).refresh();
                ref.read(draftOrdersProvider.notifier).refresh();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(cartProvider.notifier).loadOrder(order);
                  OwnerDashboardNavigation.selectMenu(
                    ref,
                    OwnerMenu.transaction,
                    bootstrap: ref.read(homeBootstrapProvider).value,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Pesanan ${order.invoiceNumber} dimuat ke kasir'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                },
                icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                label: Text(
                  order.status == TransactionStatus.draft
                      ? 'Buka di Kasir'
                      : 'Proses Pembayaran di Kasir',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incoming Orders Tab ─────────────────────────────────────────

class _IncomingOrdersTab extends ConsumerStatefulWidget {
  const _IncomingOrdersTab({
    this.isDesktop = false,
    this.selectedOrder,
    this.onSelectOrder,
  });

  final bool isDesktop;
  final TransactionOrder? selectedOrder;
  final ValueChanged<TransactionOrder>? onSelectOrder;

  @override
  ConsumerState<_IncomingOrdersTab> createState() => _IncomingOrdersTabState();
}

class _IncomingOrdersTabState extends ConsumerState<_IncomingOrdersTab> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto refresh incoming orders every 15s as a fail-safe
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        ref.read(confirmedOrdersProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(confirmedOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_rounded,
            message: 'Tidak ada pesanan masuk',
            subMessage: 'Pesanan dari QR Code atau Waiter akan muncul di sini.',
            onRefresh: () => ref.read(confirmedOrdersProvider.notifier).refresh(),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(confirmedOrdersProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isSelected = widget.isDesktop && widget.selectedOrder?.id == order.id;
              return _OrderTile(
                order: order,
                isSelected: isSelected,
                trailingWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Load to cart (process payment)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ref.read(cartProvider.notifier).loadOrder(order);
                        // Switch to Kasir/Transaksi view using dashboard navigation
                        // This handles tablet view correctly (side-by-side)
                        OwnerDashboardNavigation.selectMenu(
                          ref,
                          OwnerMenu.transaction,
                          bootstrap: ref.read(homeBootstrapProvider).value,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Pesanan ${order.invoiceNumber} dimuat ke kasir'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: const Text('Proses'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined,
                          size: 20, color: Theme.of(context).colorScheme.error),
                      onPressed: () => _showCancelDialog(context, ref, order),
                      tooltip: 'Batalkan',
                    ),
                  ],
                ),
                onTap: () {
                  if (widget.isDesktop) {
                    widget.onSelectOrder?.call(order);
                  } else {
                    context.push(RoutesPath.transactionDetail, extra: order);
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $e'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => ref.read(confirmedOrdersProvider.notifier).refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, TransactionOrder order) {
    showVoidOrderDialog(
      context,
      order,
      onSuccess: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✓ Pesanan berhasil dibatalkan'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
    );
  }
}

// ── Draft Orders Tab ────────────────────────────────────────────

class _DraftOrdersTab extends ConsumerWidget {
  const _DraftOrdersTab({
    this.isDesktop = false,
    this.selectedOrder,
    this.onSelectOrder,
  });

  final bool isDesktop;
  final TransactionOrder? selectedOrder;
  final ValueChanged<TransactionOrder>? onSelectOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftOrdersProvider);

    return draftsAsync.when(
      data: (drafts) {
        if (drafts.isEmpty) {
          return _EmptyState(
            icon: Icons.drafts_rounded,
            message: 'Tidak ada draft',
            subMessage: 'Transaksi yang disimpan sebelum bayar akan muncul di sini.',
            onRefresh: () => ref.read(draftOrdersProvider.notifier).refresh(),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(draftOrdersProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final isSelected = isDesktop && selectedOrder?.id == draft.id;
              return _OrderTile(
                order: draft,
                isSelected: isSelected,
                trailingWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Load to POS (so user can add more products)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ref.read(cartProvider.notifier).loadOrder(draft);
                        // Switch to Kasir/Transaksi view
                        ref.read(ownerSelectedMenuProvider.notifier).state =
                            OwnerMenu.transaction;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Draft ${draft.invoiceNumber} dimuat ke kasir'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Buka'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Void/Cancel instead of Delete
                    IconButton(
                      icon: Icon(Icons.cancel_outlined,
                          size: 20, color: Theme.of(context).colorScheme.error),
                      onPressed: () => _showCancelDialog(context, ref, draft),
                      tooltip: 'Batalkan',
                    ),
                  ],
                ),
                onTap: () {
                  if (isDesktop) {
                    onSelectOrder?.call(draft);
                  } else {
                    context.push(RoutesPath.transactionDetail, extra: draft);
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $e'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => ref.read(draftOrdersProvider.notifier).refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, TransactionOrder order) {
    showVoidOrderDialog(
      context,
      order,
      onSuccess: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✓ Pesanan berhasil dibatalkan'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
    );
  }
}

// ── Shared Order Tile ───────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.trailingWidget,
    this.onTap,
    this.isSelected = false,
  });

  final TransactionOrder order;
  final Widget trailingWidget;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final sourceColor = _sourceColor(order.orderSource);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Source icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(order.orderSource.icon, size: 22, color: sourceColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              order.invoiceNumber,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected ? scheme.primary : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sourceColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.orderSource.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: sourceColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: switch (order.diningOption) {
                                  DiningOption.takeAway => const Color(0xFFFFF7ED),
                                  DiningOption.delivery => const Color(0xFFF5F3FF),
                                  DiningOption.goFood => const Color(0xFFECFDF5),
                                  DiningOption.grabFood => const Color(0xFFF0FDF4),
                                  DiningOption.shopeeFood => const Color(0xFFFFF7ED),
                                  DiningOption.custom => const Color(0xFFF8FAFC),
                                  DiningOption.dineIn => const Color(0xFFEFF6FF),
                                },
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: switch (order.diningOption) {
                                    DiningOption.takeAway => const Color(0xFFFDBA74),
                                    DiningOption.delivery => const Color(0xFFC4B5FD),
                                    DiningOption.goFood => const Color(0xFF6EE7B7),
                                    DiningOption.grabFood => const Color(0xFF86EFAC),
                                    DiningOption.shopeeFood => const Color(0xFFFDBA74),
                                    DiningOption.custom => const Color(0xFFCBD5E1),
                                    DiningOption.dineIn => const Color(0xFFBFDBFE),
                                  },
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                switch (order.diningOption) {
                                  DiningOption.takeAway => '🥡 Take Away',
                                  DiningOption.delivery => '🚚 Delivery',
                                  DiningOption.goFood => '🛵 GoFood',
                                  DiningOption.grabFood => '🛵 GrabFood',
                                  DiningOption.shopeeFood => '🛵 ShopeeFood',
                                  DiningOption.custom => '📦 Custom',
                                  DiningOption.dineIn => (order.tableNumber != null ? '🍽️ Meja ${order.tableNumber}' : '🍽️ Dine In'),
                                },
                                style: TextStyle(
                                  color: switch (order.diningOption) {
                                    DiningOption.takeAway => const Color(0xFFC2410C),
                                    DiningOption.delivery => const Color(0xFF6D28D9),
                                    DiningOption.goFood => const Color(0xFF047857),
                                    DiningOption.grabFood => const Color(0xFF15803D),
                                    DiningOption.shopeeFood => const Color(0xFFC2410C),
                                    DiningOption.custom => const Color(0xFF475569),
                                    DiningOption.dineIn => const Color(0xFF1D4ED8),
                                  },
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Aktif',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.totalItemCount} item • ${order.createdAt != null ? _dateFormat.format(order.createdAt!) : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                        ),
                        if (order.customerName != null && order.customerName!.isNotEmpty)
                          Text(order.customerName!,
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                        if (order.tableNumber != null)
                          Text('Meja ${order.tableNumber}',
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                      ],
                    ),
                  ),
                  Text(_currency.format(order.grandTotal),
                      style: GoogleFonts.manrope(
                          fontSize: 15, fontWeight: FontWeight.w800, color: scheme.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [trailingWidget],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _sourceColor(OrderSource source) {
    return switch (source) {
      OrderSource.pos => Colors.blueGrey.shade700,
      OrderSource.qrSelfOrder => Colors.teal.shade700,
      OrderSource.waiter => Colors.indigo.shade700,
      OrderSource.online => Colors.purple.shade700,
    };
  }
}

// ── Empty State ─────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.subMessage,
    this.onRefresh,
  });

  final IconData icon;
  final String message;
  final String? subMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: scheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(message,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
          if (subMessage != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(subMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
            ),
          ],
          if (onRefresh != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ],
      ),
    );
  }
}
