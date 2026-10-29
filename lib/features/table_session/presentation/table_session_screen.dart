import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/presentation/history/transaction_detail_screen.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);


final tableSessionOrdersProvider =
    FutureProvider.autoDispose<List<TransactionOrder>>((ref) async {
      final bootstrap = ref.watch(homeBootstrapProvider).value;
      final outletId = bootstrap?.currentOutlet?.id;
      if (outletId == null) {
        return const [];
      }

      return ref
          .read(transactionRepositoryProvider)
          .getOrders(outletId, limit: 200);
    });

class TableSessionScreen extends ConsumerStatefulWidget {
  const TableSessionScreen({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  ConsumerState<TableSessionScreen> createState() => _TableSessionScreenState();
}

class _TableSessionScreenState extends ConsumerState<TableSessionScreen> {
  TransactionOrder? _selectedOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final role = bootstrap?.effectiveRole ?? AppRole.owner;
    final ordersAsync = ref.watch(tableSessionOrdersProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;

    final trackerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sesi Meja',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pantau meja aktif, follow-up order waiter, dan validasi pesanan QR customer.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              final activeOrders = orders.where(_isActiveTableOrder).toList()
                ..sort(_sortByRecentDesc);
              final activeTables = _buildActiveTables(activeOrders);
              final waiterRequests =
                  orders
                      .where(
                        (order) =>
                            order.status == TransactionStatus.confirmed &&
                            order.orderSource == OrderSource.waiter,
                      )
                      .toList()
                    ..sort(_sortByRecentDesc);
              final customerValidations =
                  orders
                      .where(
                        (order) =>
                            order.status == TransactionStatus.confirmed &&
                            order.orderSource == OrderSource.qrSelfOrder,
                      )
                      .toList()
                    ..sort(_sortByRecentDesc);
              final untaggedActiveOrders = orders
                  .where(
                    (order) =>
                        order.tableNumber == null &&
                        !order.status.isFinalized &&
                        (order.status == TransactionStatus.draft ||
                            order.status == TransactionStatus.confirmed),
                  )
                  .toList();

              // Auto-sync selected order with newest order state from provider
              if (_selectedOrder != null) {
                final match = orders
                    .where((o) => o.id == _selectedOrder!.id)
                    .firstOrNull;
                if (match != null && match != _selectedOrder) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedOrder = match);
                  });
                }
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(tableSessionOrdersProvider);
                  await ref.read(tableSessionOrdersProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          _SummaryCard(
                            label: 'Meja Aktif',
                            value: '${activeTables.length}',
                            caption: 'Meja dengan order berjalan',
                            color: const Color(0xFF2563EB),
                            icon: Icons.table_restaurant_rounded,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            label: 'Request Waiter',
                            value: '${waiterRequests.length}',
                            caption: 'Menunggu follow-up',
                            color: const Color(0xFF7C3AED),
                            icon: Icons.room_service_rounded,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            label: 'Validasi QR',
                            value: '${customerValidations.length}',
                            caption: 'Order customer mandiri',
                            color: const Color(0xFF0F766E),
                            icon: Icons.qr_code_rounded,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            label: 'Tanpa Meja',
                            value: '${untaggedActiveOrders.length}',
                            caption: 'Order belum di-tag',
                            color: const Color(0xFFD97706),
                            icon: Icons.pin_drop_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Live Table Tracker',
                      subtitle:
                          'Ringkasan meja yang masih punya order berjalan atau menunggu validasi.',
                      actionLabel: activeTables.isNotEmpty
                          ? 'Ke Transaksi'
                          : null,
                      onActionTap: activeTables.isNotEmpty
                          ? () => OwnerDashboardNavigation.selectMenu(
                              ref,
                              OwnerMenu.transaction,
                              bootstrap: bootstrap,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (activeTables.isEmpty)
                      const _InlineEmptyState(
                        icon: Icons.table_bar_rounded,
                        title: 'Belum ada meja aktif',
                        message:
                            'Order dengan nomor meja akan muncul di sini setelah disimpan oleh waiter atau kasir.',
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 800
                              ? 3
                              : (constraints.maxWidth > 500 ? 2 : 1);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 260,
                                ),
                            itemCount: activeTables.length,
                            itemBuilder: (context, index) {
                              final session = activeTables[index];
                              final isSelected = isDesktop &&
                                  _selectedOrder?.id == session.latestOrder.id;

                              return _TableSessionCard(
                                session: session,
                                isSelected: isSelected,
                                onTap: isDesktop
                                    ? () => setState(
                                        () => _selectedOrder = session.latestOrder)
                                    : null,
                                onOpenOrder: () => _openOrderInTransaction(
                                  context,
                                  ref,
                                  session.latestOrder,
                                ),
                                onViewDetail: () {
                                  if (isDesktop) {
                                    setState(
                                      () => _selectedOrder = session.latestOrder,
                                    );
                                  } else {
                                    context.push(
                                      RoutesPath.transactionDetail,
                                      extra: session.latestOrder,
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: role == AppRole.waiter
                          ? 'Order Waiter Aktif'
                          : 'Request Waiter',
                      subtitle: role == AppRole.waiter
                          ? 'Pesanan waiter yang masih menunggu proses kasir atau validasi tim.'
                          : 'Order yang dibuat waiter dan butuh tindak lanjut cepat.',
                    ),
                    const SizedBox(height: 10),
                    if (waiterRequests.isEmpty)
                      const _InlineEmptyState(
                        icon: Icons.notifications_active_rounded,
                        title: 'Belum ada request waiter',
                        message:
                            'Pesanan dari waiter dengan status dikonfirmasi akan muncul di sini.',
                      )
                    else
                      ...waiterRequests.take(8).map((order) {
                        final isSelected =
                            isDesktop && _selectedOrder?.id == order.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActionOrderCard(
                            order: order,
                            isSelected: isSelected,
                            onTap: isDesktop
                                ? () => setState(() => _selectedOrder = order)
                                : null,
                            accentColor: const Color(0xFF7C3AED),
                            badgeLabel: 'Waiter',
                            description: _buildWaiterDescription(order),
                            primaryLabel: 'Buka Order',
                            onPrimaryTap: () => _openOrderInTransaction(
                              context,
                              ref,
                              order,
                            ),
                            onSecondaryTap: () {
                              if (isDesktop) {
                                setState(() => _selectedOrder = order);
                              } else {
                                context.push(
                                  RoutesPath.transactionDetail,
                                  extra: order,
                                );
                              }
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Order Validation',
                      subtitle:
                          'Validasi pesanan QR customer sebelum diproses lebih jauh di kasir.',
                      actionLabel:
                          customerValidations.isNotEmpty &&
                              role != AppRole.waiter
                          ? 'Pesanan Masuk'
                          : null,
                      onActionTap:
                          customerValidations.isNotEmpty &&
                              role != AppRole.waiter
                          ? () => OwnerDashboardNavigation.selectMenu(
                              ref,
                              OwnerMenu.orderManagement,
                              bootstrap: bootstrap,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (customerValidations.isEmpty)
                      const _InlineEmptyState(
                        icon: Icons.fact_check_rounded,
                        title: 'Belum ada order customer',
                        message:
                            'Order QR mandiri yang masih confirmed akan tampil di sini untuk dicek meja dan catatannya.',
                      )
                    else
                      ...customerValidations.take(8).map((order) {
                        final isSelected =
                            isDesktop && _selectedOrder?.id == order.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActionOrderCard(
                            order: order,
                            isSelected: isSelected,
                            onTap: isDesktop
                                ? () => setState(() => _selectedOrder = order)
                                : null,
                            accentColor: const Color(0xFF0F766E),
                            badgeLabel: 'QR Customer',
                            description: _buildQrDescription(order),
                            primaryLabel: 'Validasi',
                            onPrimaryTap: () => _openOrderInTransaction(
                              context,
                              ref,
                              order,
                            ),
                            onSecondaryTap: () {
                              if (isDesktop) {
                                setState(() => _selectedOrder = order);
                              } else {
                                context.push(
                                  RoutesPath.transactionDetail,
                                  extra: order,
                                );
                              }
                            },
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: 'Gagal memuat sesi meja: $error',
              onRetry: () => ref.invalidate(tableSessionOrdersProvider),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: widget.padding,
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: trackerContent),
                const SizedBox(width: 20),
                SizedBox(
                  width: 420,
                  child: _buildSidePanel(context, ref, scheme, theme),
                ),
              ],
            )
          : trackerContent,
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    if (_selectedOrder == null) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.table_restaurant_rounded,
                size: 48,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Detail Meja & Pesanan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih salah satu meja aktif atau pesanan waiter di samping untuk melihat rincian item, status pesanan dapur, dan memproses pembayaran.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final order = _selectedOrder!;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
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
                ref.invalidate(tableSessionOrdersProvider);
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
                  _openOrderInTransaction(context, ref, order);
                },
                icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                label: const Text('Proses Pembayaran di Kasir'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openOrderInTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionOrder order,
  ) async {
    ref.read(cartProvider.notifier).loadOrder(order);
    OwnerDashboardNavigation.selectMenu(
      ref,
      OwnerMenu.transaction,
      bootstrap: ref.read(homeBootstrapProvider).value,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order ${order.invoiceNumber} dimuat ke transaksi'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

bool _isActiveTableOrder(TransactionOrder order) {
  return order.tableNumber != null &&
      !order.status.isFinalized &&
      (order.status == TransactionStatus.draft ||
          order.status == TransactionStatus.confirmed ||
          order.status == TransactionStatus.partialPaid);
}

int _sortByRecentDesc(TransactionOrder a, TransactionOrder b) {
  final aDate = a.updatedAt ?? a.createdAt ?? a.paidAt ?? DateTime(2000);
  final bDate = b.updatedAt ?? b.createdAt ?? b.paidAt ?? DateTime(2000);
  return bDate.compareTo(aDate);
}

List<_TableSessionViewModel> _buildActiveTables(List<TransactionOrder> orders) {
  final grouped = <int, List<TransactionOrder>>{};
  for (final order in orders) {
    final tableNumber = order.tableNumber;
    if (tableNumber == null) {
      continue;
    }
    grouped.putIfAbsent(tableNumber, () => []).add(order);
  }

  final sessions = grouped.entries.map((entry) {
    final tableOrders = [...entry.value]..sort(_sortByRecentDesc);
    final latestOrder = tableOrders.first;
    final totalValue = tableOrders.fold<double>(
      0,
      (sum, order) => sum + order.grandTotal,
    );
    final totalItems = tableOrders.fold<int>(
      0,
      (sum, order) => sum + order.totalItemCount,
    );
    final pendingCount = tableOrders
        .where((order) => order.status == TransactionStatus.confirmed)
        .length;

    return _TableSessionViewModel(
      tableNumber: entry.key,
      latestOrder: latestOrder,
      totalOrders: tableOrders.length,
      totalItems: totalItems,
      totalValue: totalValue,
      pendingCount: pendingCount,
    );
  }).toList()..sort((a, b) => _sortByRecentDesc(a.latestOrder, b.latestOrder));

  return sessions;
}

String _buildWaiterDescription(TransactionOrder order) {
  final parts = <String>[];
  if (order.tableNumber != null) {
    parts.add('Meja ${order.tableNumber}');
  }
  if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
    parts.add(order.customerName!.trim());
  }
  if (order.notes != null && order.notes!.trim().isNotEmpty) {
    parts.add(order.notes!.trim());
  }
  if (parts.isEmpty) {
    parts.add('Belum ada catatan tambahan dari waiter.');
  }
  return parts.join(' • ');
}

String _buildQrDescription(TransactionOrder order) {
  final parts = <String>[];
  if (order.tableNumber != null) {
    parts.add('Meja ${order.tableNumber}');
  }
  if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
    parts.add(order.customerName!.trim());
  }
  if (order.notes != null && order.notes!.trim().isNotEmpty) {
    parts.add('Catatan: ${order.notes!.trim()}');
  }
  if (parts.isEmpty) {
    parts.add('Cek meja dan item order sebelum diproses.');
  }
  return parts.join(' • ');
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final concierge = theme.extension<ConciergeThemeTokens>();

    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: concierge?.raisedSurface ?? Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (concierge?.tintedShadow ?? Colors.black).withValues(
              alpha: 0.04,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
      ],
    );
  }
}

class _TableSessionCard extends StatelessWidget {
  const _TableSessionCard({
    required this.session,
    required this.onOpenOrder,
    required this.onViewDetail,
    this.isSelected = false,
    this.onTap,
  });

  final _TableSessionViewModel session;
  final VoidCallback onOpenOrder;
  final VoidCallback onViewDetail;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final concierge = theme.extension<ConciergeThemeTokens>();
    final latestOrder = session.latestOrder;
    final accentColor = session.pendingCount > 0
        ? const Color(0xFFD97706)
        : _sourceColor(latestOrder.orderSource);
    final customerLabel = latestOrder.customerName?.trim().isNotEmpty == true
        ? latestOrder.customerName!.trim()
        : 'Pelanggan';

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFEFF6FF)
            : (concierge?.raisedSurface ?? Colors.white),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : accentColor.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                : (concierge?.tintedShadow ?? Colors.black).withValues(
                    alpha: 0.04,
                  ),
            blurRadius: isSelected ? 22 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor.withValues(alpha: 0.9),
                                    accentColor.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${session.tableNumber}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Meja ${session.tableNumber}',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
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
                                            color: const Color(0xFF2563EB),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Aktif',
                                            style: GoogleFonts.manrope(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  _PillLabel(
                                    label: session.pendingCount > 0
                                        ? '${session.pendingCount} Validasi'
                                        : latestOrder.status.label,
                                    color: accentColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    const SizedBox(height: 16),
                    Text(
                      customerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.totalOrders} Order • ${session.totalItems} Item',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currency.format(session.totalValue),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onViewDetail,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Detail',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.outline,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: scheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: onOpenOrder,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Buka Order',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _ActionOrderCard extends StatelessWidget {
  const _ActionOrderCard({
    required this.order,
    required this.accentColor,
    required this.badgeLabel,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    this.isSelected = false,
    this.onTap,
  });

  final TransactionOrder order;
  final Color accentColor;
  final String badgeLabel;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : accentColor.withValues(alpha: 0.12),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          order.orderSource.icon,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  order.invoiceNumber,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                _PillLabel(label: badgeLabel, color: accentColor),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Aktif',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.totalItemCount} item • ${_currency.format(order.grandTotal)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        order.status.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onSecondaryTap,
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          label: const Text('Detail'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onPrimaryTap,
                          style: FilledButton.styleFrom(backgroundColor: accentColor),
                          icon: const Icon(
                            Icons.playlist_add_check_rounded,
                            size: 18,
                          ),
                          label: Text(primaryLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: scheme.outline.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
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
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _sourceColor(OrderSource source) {
  return switch (source) {
    OrderSource.pos => const Color(0xFF334155),
    OrderSource.qrSelfOrder => const Color(0xFF0F766E),
    OrderSource.waiter => const Color(0xFF4C1D95),
    OrderSource.online => const Color(0xFF7C2D12),
  };
}

class _TableSessionViewModel {
  const _TableSessionViewModel({
    required this.tableNumber,
    required this.latestOrder,
    required this.totalOrders,
    required this.totalItems,
    required this.totalValue,
    required this.pendingCount,
  });

  final int tableNumber;
  final TransactionOrder latestOrder;
  final int totalOrders;
  final int totalItems;
  final double totalValue;
  final int pendingCount;
}
