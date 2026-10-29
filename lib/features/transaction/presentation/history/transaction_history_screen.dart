import 'package:dpos/core/providers/analytics_outlet_filter_provider.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/presentation/history/transaction_detail_screen.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
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
final _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
final _groupDateFormat = DateFormat('EEEE, dd MMM yyyy', 'id_ID');

/// Full-page Transaction History screen.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String _searchQuery = '';
  TransactionStatus? _selectedStatus;
  TransactionOrder? _selectedOrder;
  final _searchController = TextEditingController();
  final _debouncer = _Debouncer(milliseconds: 500);
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250) {
      ref.read(orderHistoryProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderHistoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final showOutletBadge = (bootstrap?.outlets.length ?? 0) > 1;
    final outletMap = {for (final o in bootstrap?.outlets ?? []) o.id: o.name};
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 850;

    TransactionOrder? effectiveSelectedOrder = _selectedOrder;
    if (effectiveSelectedOrder != null && ordersAsync.hasValue) {
      final orders = ordersAsync.value;
      if (orders != null) {
        final match =
            orders.where((o) => o.id == effectiveSelectedOrder!.id).firstOrNull;
        if (match != null) {
          effectiveSelectedOrder = match;
        }
      }
    }

    final mainList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar & Outlet Filter
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _debouncer.run(() {
                    setState(() => _searchQuery = v);
                    ref.read(orderHistoryProvider.notifier).search(v);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari no. invoice...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            ref.read(orderHistoryProvider.notifier).refresh();
                          },
                        )
                      : null,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            const AnalyticsOutletFilterSelector(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Semua Status'),
                  selected: _selectedStatus == null,
                  onSelected: (_) => setState(() => _selectedStatus = null),
                  selectedColor: scheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: scheme.primary,
                ),
              ),
              ...TransactionStatus.values.map(
                (status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status.label),
                    selected: _selectedStatus == status,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatus = _selectedStatus == status
                            ? null
                            : status;
                      });
                    },
                    selectedColor: scheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              final filteredOrders = _applyFilters(orders);

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 56,
                        color: scheme.outline.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty || _selectedStatus != null
                            ? 'Tidak ada transaksi dengan filter ini'
                            : 'Belum ada transaksi',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final groupedOrders = _groupOrdersByDate(filteredOrders);

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(orderHistoryProvider.notifier).refresh(),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    ...groupedOrders.map(
                      (group) => SliverMainAxisGroup(
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _DateHeaderDelegate(
                              title: _formatDayHeader(group.date),
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              chipColor: scheme.surfaceContainerHighest,
                              textColor: scheme.onSurfaceVariant,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 10),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final order = group.orders[index];
                                final isSelected = isDesktop &&
                                    effectiveSelectedOrder?.id == order.id;
                                return _OrderHistoryTile(
                                  order: order,
                                  isSelected: isSelected,
                                  outletName: showOutletBadge
                                      ? outletMap[order.outletId]
                                      : null,
                                  onTap: () {
                                    if (isDesktop) {
                                      setState(() {
                                        _selectedOrder = order;
                                      });
                                    } else {
                                      context.push(
                                        RoutesPath.transactionDetail,
                                        extra: order,
                                      );
                                    }
                                  },
                                );
                              }, childCount: group.orders.length),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final notifier =
                              ref.watch(orderHistoryProvider.notifier);
                          if (notifier.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 24);
                        },
                      ),
                    ),
                  ],
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
                    onPressed: () =>
                        ref.read(orderHistoryProvider.notifier).refresh(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
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
                Expanded(
                  flex: 5,
                  child: mainList,
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: (screenWidth * 0.42).clamp(390.0, 480.0),
                  child: _buildSidePanel(
                    context,
                    effectiveSelectedOrder,
                  ),
                ),
              ],
            )
          : mainList,
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
                Icons.receipt_long_outlined,
                size: 44,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Detail Transaksi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih salah satu transaksi pada daftar di samping untuk melihat rincian struk, mencetak ulang, atau melakukan retur/void.',
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
      child: TransactionDetailView(
        key: ValueKey(order.id),
        order: order,
        isSidePanel: true,
        onClose: () => setState(() => _selectedOrder = null),
        onOrderUpdated: () {
          ref.read(orderHistoryProvider.notifier).refresh();
        },
      ),
    );
  }

  List<TransactionOrder> _applyFilters(List<TransactionOrder> orders) {
    return orders.where((order) {
      if (_selectedStatus != null && order.status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_OrderDateGroup> _groupOrdersByDate(List<TransactionOrder> orders) {
    final grouped = <DateTime, List<TransactionOrder>>{};
    for (final order in orders) {
      final rawDate = order.createdAt ?? order.paidAt ?? order.updatedAt;
      final date = _dateOnly(rawDate ?? DateTime.now());
      grouped.putIfAbsent(date, () => []).add(order);
    }

    return grouped.entries
        .map((entry) => _OrderDateGroup(date: entry.key, orders: entry.value))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String _formatDayHeader(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(date, today)) return 'Hari Ini';
    if (_isSameDay(date, yesterday)) return 'Kemarin';
    return _capitalize(_groupDateFormat.format(date));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _OrderDateGroup {
  const _OrderDateGroup({required this.date, required this.orders});
  final DateTime date;
  final List<TransactionOrder> orders;
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({
    required this.title,
    required this.backgroundColor,
    required this.chipColor,
    required this.textColor,
  });

  final String title;
  final Color backgroundColor;
  final Color chipColor;
  final Color textColor;

  @override
  double get minExtent => 42;

  @override
  double get maxExtent => 42;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.chipColor != chipColor ||
        oldDelegate.textColor != textColor;
  }
}

// ── Order History Tile ──────────────────────────────────────────

class _OrderHistoryTile extends ConsumerWidget {
  const _OrderHistoryTile({
    required this.order,
    required this.onTap,
    this.outletName,
    this.isSelected = false,
  });
  final TransactionOrder order;
  final VoidCallback onTap;
  final String? outletName;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final statusColor = _statusColor(order.status);

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
          child: Row(
            children: [
              // Source icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  order.orderSource.icon,
                  size: 22,
                  color: statusColor,
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
                          order.invoiceNumber,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected ? scheme.primary : null,
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
                      '${order.totalItemCount} item • ${order.createdAt != null ? _dateFormat.format(order.createdAt!) : '-'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    if (outletName != null && outletName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              outletName!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (order.cashierName != null &&
                        order.cashierName!.isNotEmpty)
                      Text(
                        'Kasir: ${order.cashierName!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    if (order.waiterName != null &&
                        order.waiterName!.isNotEmpty)
                      Text(
                        'Waiter: ${order.waiterName!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    if (order.tableNumber != null)
                      Text(
                        'Meja: ${order.tableNumber!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    if (order.customerName != null &&
                        order.customerName!.isNotEmpty)
                      Text(
                        'Pelanggan: ${order.customerName!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency.format(order.grandTotal),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (order.payments.any((p) => p.methodType == 'debt')) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                size: 10,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Kasbon',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status == TransactionStatus.confirmed
                              ? 'Belum Bayar'
                              : order.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.status == TransactionStatus.confirmed ||
                      order.status == TransactionStatus.draft) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 14),
                        label: const Text(
                          'Bayar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          ref.read(cartProvider.notifier).loadOrder(order);
                          context.push(RoutesPath.transactionPayment);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.chevron_right_rounded,
                size: isSelected ? 16 : 20,
                color: isSelected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.paid => Colors.green.shade700,
      TransactionStatus.draft => Colors.amber.shade700,
      TransactionStatus.confirmed => Colors.blue.shade700,
      TransactionStatus.partialPaid => Colors.orange.shade700,
      TransactionStatus.void_ => Colors.red.shade700,
      TransactionStatus.refunded => Colors.purple.shade700,
    };
  }
}

// ── Simple debouncer ────────────────────────────────────────────

class _Debouncer {
  _Debouncer({required this.milliseconds});
  final int milliseconds;
  VoidCallback? _action;
  bool _disposed = false;

  void run(VoidCallback action) {
    _action = action;
    Future.delayed(Duration(milliseconds: milliseconds), () {
      if (!_disposed) _action?.call();
    });
  }

  void dispose() => _disposed = true;
}
