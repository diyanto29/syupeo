import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'widgets/table_qr_generator_dialog.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _shortDate = DateFormat('dd MMM, HH:mm', 'id_ID');
final _longDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
final _groupDate = DateFormat('EEEE, dd MMM yyyy', 'id_ID');

final waiterScopedOrdersProvider =
    FutureProvider.autoDispose<List<TransactionOrder>>((ref) async {
      final bootstrap = ref.watch(homeBootstrapProvider).value;
      final outletId = bootstrap?.currentOutlet?.id;
      if (outletId == null) {
        return const [];
      }

      final userId = bootstrap?.profile?.id;
      if (userId == null || userId.isEmpty) {
        return const [];
      }

      return ref
          .read(transactionRepositoryProvider)
          .getOrders(
            outletId,
            orderSource: OrderSource.waiter,
            waiterId: userId,
            limit: 300,
          );
    });

class WaiterSessionOverviewScreen extends ConsumerWidget {
  const WaiterSessionOverviewScreen({
    super.key,
    this.padding = EdgeInsets.zero,
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final ordersAsync = ref.watch(waiterScopedOrdersProvider);

    return Padding(
      padding: padding,
      child: Column(
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
            'Workspace waiter yang dipisah per halaman supaya pantau meja, orderan, dan histori lebih rapi.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final activeOrders = orders.where(_isUnfinishedOrder).toList();
                final activeTables = _groupOrdersByTable(activeOrders);
                final paidToday = orders.where((order) {
                  final paidAt = order.paidAt;
                  if (paidAt == null ||
                      order.status != TransactionStatus.paid) {
                    return false;
                  }
                  return _isSameDay(paidAt, DateTime.now());
                }).length;
                final unassignedTables = activeOrders
                    .where((order) => order.tableNumber == null)
                    .length;

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(waiterScopedOrdersProvider);
                    await ref.read(waiterScopedOrdersProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryCard(
                            label: 'Meja Aktif',
                            value: '${activeTables.length}',
                            caption:
                                'Meja dengan order waiter yang belum selesai',
                            icon: Icons.table_restaurant_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                          _SummaryCard(
                            label: 'Order Aktif',
                            value: '${activeOrders.length}',
                            caption: 'Draft, confirmed, dan partial payment',
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                          _SummaryCard(
                            label: 'Selesai Hari Ini',
                            value: '$paidToday',
                            caption: 'Order waiter yang sudah lunas hari ini',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF0F766E),
                          ),
                          _SummaryCard(
                            label: 'Belum Ada Meja',
                            value: '$unassignedTables',
                            caption: 'Order aktif yang masih perlu nomor meja',
                            icon: Icons.pin_drop_rounded,
                            color: const Color(0xFFD97706),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _QuickSectionCard(
                        title: 'Navigasi Waiter',
                        subtitle:
                            'Buka halaman yang paling sesuai dengan pekerjaan kamu saat ini.',
                        children: [
                          _QuickLinkTile(
                            icon: Icons.grid_view_rounded,
                            color: const Color(0xFF2563EB),
                            title: 'Table Tracker',
                            subtitle:
                                'Pantau meja aktif waiter dan lanjutkan order yang masih berjalan.',
                            onTap: () => _selectMenu(
                              ref,
                              OwnerMenu.tableTracker,
                              bootstrap,
                            ),
                          ),
                          _QuickLinkTile(
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFF7C3AED),
                            title: 'Orderan',
                            subtitle:
                                'Lihat semua order waiter yang belum selesai dalam satu daftar.',
                            onTap: () => _selectMenu(
                              ref,
                              OwnerMenu.waiterOrders,
                              bootstrap,
                            ),
                          ),
                          _QuickLinkTile(
                            icon: Icons.history_toggle_off_rounded,
                            color: const Color(0xFF0F766E),
                            title: 'Riwayat Transaksi',
                            subtitle:
                                'Cek histori order waiter, baik yang selesai maupun yang belum selesai.',
                            onTap: () => _selectMenu(
                              ref,
                              OwnerMenu.waiterHistory,
                              bootstrap,
                            ),
                          ),
                          _QuickLinkTile(
                            icon: Icons.point_of_sale_rounded,
                            color: const Color(0xFF1D4ED8),
                            title: 'Buat Order Baru',
                            subtitle:
                                'Masuk ke transaksi untuk membuat pesanan baru dari meja customer.',
                            onTap: () => _selectMenu(
                              ref,
                              OwnerMenu.transaction,
                              bootstrap,
                            ),
                          ),
                          _QuickLinkTile(
                            icon: Icons.qr_code_scanner_rounded,
                            color: const Color(0xFFF98B35),
                            title: 'QR Self-Order',
                            subtitle:
                                'Generate QR Code meja agar pelanggan bisa pesan mandiri.',
                            onTap: () {
                              final outlet = bootstrap?.currentOutlet;
                              if (outlet == null) return;
                              showDialog(
                                context: context,
                                builder: (context) => TableQrGeneratorDialog(
                                  outletId: outlet.id,
                                  outletName: outlet.name,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _QuickSectionCard(
                        title: 'Ringkasan Cepat',
                        subtitle:
                            'Order terbaru waiter yang butuh perhatian paling dekat.',
                        children: [
                          if (activeOrders.isEmpty)
                            const _InlineEmptyState(
                              icon: Icons.inbox_rounded,
                              title: 'Belum ada order aktif',
                              message:
                                  'Order waiter yang belum selesai akan muncul di sini agar mudah dipantau.',
                            )
                          else
                            ...activeOrders
                                .take(3)
                                .map(
                                  (order) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _WaiterOrderTile(
                                      order: order,
                                      accentColor: _statusColor(order.status),
                                      actionLabel: 'Lanjutkan',
                                      onActionTap: () =>
                                          _openOrderInTransaction(
                                            context,
                                            ref,
                                            order,
                                          ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: 'Gagal memuat sesi waiter: $error',
                onRetry: () => ref.invalidate(waiterScopedOrdersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaiterTableTrackerScreen extends ConsumerWidget {
  const WaiterTableTrackerScreen({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordersAsync = ref.watch(waiterScopedOrdersProvider);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Table Tracker',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fokus ke meja aktif waiter supaya order yang belum selesai tidak tercecer.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final activeTables = _groupOrdersByTable(
                  orders.where(_isUnfinishedOrder).toList(),
                );
                final noTableOrders =
                    orders
                        .where(
                          (order) =>
                              _isUnfinishedOrder(order) &&
                              order.tableNumber == null,
                        )
                        .toList()
                      ..sort(_sortByRecentDesc);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(waiterScopedOrdersProvider);
                    await ref.read(waiterScopedOrdersProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (noTableOrders.isNotEmpty) ...[
                        const _SectionHeader(
                          title: 'Butuh Nomor Meja',
                          subtitle:
                              'Lengkapi order berikut dengan nomor meja agar mudah dilacak.',
                        ),
                        const SizedBox(height: 10),
                        ...noTableOrders.map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WaiterOrderTile(
                              order: order,
                              accentColor: const Color(0xFFD97706),
                              actionLabel: 'Lengkapi',
                              onActionTap: () =>
                                  _openOrderInTransaction(context, ref, order),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      const _SectionHeader(
                        title: 'Meja Aktif',
                        subtitle:
                            'Daftar meja waiter yang masih punya order berjalan.',
                      ),
                      const SizedBox(height: 10),
                      if (activeTables.isEmpty)
                        const _InlineEmptyState(
                          icon: Icons.table_bar_rounded,
                          title: 'Belum ada meja aktif',
                          message:
                              'Saat order waiter punya nomor meja dan belum selesai, meja tersebut akan muncul di sini.',
                        )
                      else
                        ...activeTables.map(
                          (table) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WaiterTableCard(
                              table: table,
                              onOpenOrder: () => _openOrderInTransaction(
                                context,
                                ref,
                                table.latestOrder,
                              ),
                              onViewDetail: () => context.push(
                                RoutesPath.transactionDetail,
                                extra: table.latestOrder,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: 'Gagal memuat table tracker: $error',
                onRetry: () => ref.invalidate(waiterScopedOrdersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaiterOrdersScreen extends ConsumerStatefulWidget {
  const WaiterOrdersScreen({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  ConsumerState<WaiterOrdersScreen> createState() => _WaiterOrdersScreenState();
}

class _WaiterOrdersScreenState extends ConsumerState<WaiterOrdersScreen> {
  String _searchQuery = '';
  TransactionStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordersAsync = ref.watch(waiterScopedOrdersProvider);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orderan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Semua order waiter yang belum selesai, dipisah dari histori lunas.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Cari invoice / pelanggan / meja...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Semua Aktif'),
                    selected: _selectedStatus == null,
                    onSelected: (_) => setState(() => _selectedStatus = null),
                    selectedColor: scheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                ...[
                  TransactionStatus.draft,
                  TransactionStatus.confirmed,
                  TransactionStatus.partialPaid,
                ].map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status.label),
                      selected: _selectedStatus == status,
                      onSelected: (_) => setState(() {
                        _selectedStatus = _selectedStatus == status
                            ? null
                            : status;
                      }),
                      selectedColor: scheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filteredOrders =
                    orders
                        .where(_isUnfinishedOrder)
                        .where(_matchesSearch)
                        .where(_matchesStatus)
                        .toList()
                      ..sort(_sortByRecentDesc);

                if (filteredOrders.isEmpty) {
                  return const _InlineEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Belum ada order aktif',
                    message:
                        'Order waiter yang masih berjalan akan muncul di halaman ini.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(waiterScopedOrdersProvider);
                    await ref.read(waiterScopedOrdersProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WaiterOrderTile(
                          order: order,
                          accentColor: _statusColor(order.status),
                          actionLabel: 'Buka Order',
                          onActionTap: () =>
                              _openOrderInTransaction(context, ref, order),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: 'Gagal memuat orderan waiter: $error',
                onRetry: () => ref.invalidate(waiterScopedOrdersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(TransactionOrder order) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final query = _searchQuery.toLowerCase();
    final tableLabel = order.tableNumber?.toString() ?? '';
    return order.invoiceNumber.toLowerCase().contains(query) ||
        (order.customerName?.toLowerCase().contains(query) ?? false) ||
        tableLabel.contains(query);
  }

  bool _matchesStatus(TransactionOrder order) {
    if (_selectedStatus == null) {
      return true;
    }
    return order.status == _selectedStatus;
  }
}

class WaiterTransactionHistoryScreen extends ConsumerStatefulWidget {
  const WaiterTransactionHistoryScreen({
    super.key,
    this.padding = EdgeInsets.zero,
  });

  final EdgeInsets padding;

  @override
  ConsumerState<WaiterTransactionHistoryScreen> createState() =>
      _WaiterTransactionHistoryScreenState();
}

class _WaiterTransactionHistoryScreenState
    extends ConsumerState<WaiterTransactionHistoryScreen> {
  String _searchQuery = '';
  TransactionStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordersAsync = ref.watch(waiterScopedOrdersProvider);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat Transaksi',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Semua histori order waiter, baik yang selesai maupun yang belum selesai.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Cari invoice / pelanggan / meja...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Semua Status'),
                    selected: _selectedStatus == null,
                    onSelected: (_) => setState(() => _selectedStatus = null),
                    selectedColor: scheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                ...TransactionStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status.label),
                      selected: _selectedStatus == status,
                      onSelected: (_) => setState(() {
                        _selectedStatus = _selectedStatus == status
                            ? null
                            : status;
                      }),
                      selectedColor: scheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filteredOrders =
                    orders.where(_matchesSearch).where(_matchesStatus).toList()
                      ..sort(_sortByRecentDesc);

                if (filteredOrders.isEmpty) {
                  return const _InlineEmptyState(
                    icon: Icons.history_rounded,
                    title: 'Belum ada histori',
                    message:
                        'Setelah waiter membuat order, semua status order akan terekam di halaman ini.',
                  );
                }

                final groupedOrders = _groupOrdersByDate(filteredOrders);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(waiterScopedOrdersProvider);
                    await ref.read(waiterScopedOrdersProvider.future);
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      ...groupedOrders.expand(
                        (group) => [
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
                                return _HistoryTile(
                                  order: order,
                                  onTap: () => context.push(
                                    RoutesPath.transactionDetail,
                                    extra: order,
                                  ),
                                );
                              }, childCount: group.orders.length),
                            ),
                          ),
                        ],
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: 'Gagal memuat riwayat waiter: $error',
                onRetry: () => ref.invalidate(waiterScopedOrdersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(TransactionOrder order) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final query = _searchQuery.toLowerCase();
    final tableLabel = order.tableNumber?.toString() ?? '';
    return order.invoiceNumber.toLowerCase().contains(query) ||
        (order.customerName?.toLowerCase().contains(query) ?? false) ||
        tableLabel.contains(query);
  }

  bool _matchesStatus(TransactionOrder order) {
    if (_selectedStatus == null) {
      return true;
    }
    return order.status == _selectedStatus;
  }
}

void _selectMenu(WidgetRef ref, OwnerMenu menu, OwnerBootstrap? bootstrap) {
  OwnerDashboardNavigation.selectMenu(ref, menu, bootstrap: bootstrap);
}

Future<void> _openOrderInTransaction(
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

bool _isUnfinishedOrder(TransactionOrder order) {
  return !order.status.isFinalized;
}

int _sortByRecentDesc(TransactionOrder a, TransactionOrder b) {
  final aDate = a.updatedAt ?? a.createdAt ?? a.paidAt ?? DateTime(2000);
  final bDate = b.updatedAt ?? b.createdAt ?? b.paidAt ?? DateTime(2000);
  return bDate.compareTo(aDate);
}

List<_WaiterTableGroup> _groupOrdersByTable(List<TransactionOrder> orders) {
  final grouped = <int, List<TransactionOrder>>{};
  for (final order in orders) {
    final tableNumber = order.tableNumber;
    if (tableNumber == null) {
      continue;
    }
    grouped.putIfAbsent(tableNumber, () => []).add(order);
  }

  return grouped.entries.map((entry) {
    final tableOrders = [...entry.value]..sort(_sortByRecentDesc);
    return _WaiterTableGroup(
      tableNumber: entry.key,
      latestOrder: tableOrders.first,
      totalOrders: tableOrders.length,
      totalItems: tableOrders.fold<int>(
        0,
        (sum, order) => sum + order.totalItemCount,
      ),
      totalValue: tableOrders.fold<double>(
        0,
        (sum, order) => sum + order.grandTotal,
      ),
      pendingCount: tableOrders
          .where((order) => order.status == TransactionStatus.confirmed)
          .length,
    );
  }).toList()..sort((a, b) => _sortByRecentDesc(a.latestOrder, b.latestOrder));
}

List<_OrderDateGroup> _groupOrdersByDate(List<TransactionOrder> orders) {
  final grouped = <DateTime, List<TransactionOrder>>{};
  for (final order in orders) {
    final rawDate = order.createdAt ?? order.updatedAt ?? order.paidAt;
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
  final value = _groupDate.format(date);
  return value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Color _statusColor(TransactionStatus status) {
  return switch (status) {
    TransactionStatus.draft => const Color(0xFFD97706),
    TransactionStatus.confirmed => const Color(0xFF2563EB),
    TransactionStatus.partialPaid => const Color(0xFF005ECC),
    TransactionStatus.paid => const Color(0xFF0F766E),
    TransactionStatus.void_ => const Color(0xFFB91C1C),
    TransactionStatus.refunded => const Color(0xFF7C3AED),
  };
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 240),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSectionCard extends StatelessWidget {
  const _QuickSectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaiterOrderTile extends StatelessWidget {
  const _WaiterOrderTile({
    required this.order,
    required this.accentColor,
    required this.actionLabel,
    required this.onActionTap,
  });

  final TransactionOrder order;
  final Color accentColor;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final customerLabel = order.customerName?.trim().isNotEmpty == true
        ? order.customerName!.trim()
        : 'Tanpa nama customer';
    final tableLabel = order.tableNumber != null
        ? 'Meja ${order.tableNumber}'
        : 'Meja belum diisi';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
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
                      Text(
                        order.invoiceNumber,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$customerLabel • $tableLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.totalItemCount} item • ${_currency.format(order.grandTotal)} • ${_longDate.format(order.updatedAt ?? order.createdAt ?? DateTime.now())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                      if (order.notes != null && order.notes!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              order.notes!.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.status.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push(
                      RoutesPath.transactionDetail,
                      extra: order,
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Detail'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onActionTap,
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(actionLabel),
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

class _WaiterTableCard extends StatelessWidget {
  const _WaiterTableCard({
    required this.table,
    required this.onOpenOrder,
    required this.onViewDetail,
  });

  final _WaiterTableGroup table;
  final VoidCallback onOpenOrder;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final latestOrder = table.latestOrder;
    final accentColor = table.pendingCount > 0
        ? const Color(0xFF2563EB)
        : _statusColor(latestOrder.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '${table.tableNumber}',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meja ${table.tableNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${table.totalOrders} order • ${table.totalItems} item',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TagPill(
                            label: latestOrder.status.label,
                            color: accentColor,
                          ),
                          if (table.pendingCount > 0)
                            _TagPill(
                              label: '${table.pendingCount} menunggu proses',
                              color: const Color(0xFFD97706),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  _currency.format(table.totalValue),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Invoice terakhir ${latestOrder.invoiceNumber} • ${_shortDate.format(latestOrder.updatedAt ?? latestOrder.createdAt ?? DateTime.now())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onViewDetail,
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Detail'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenOrder,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Buka Order'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
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
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.order, required this.onTap});

  final TransactionOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final statusColor = _statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
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
                    Text(
                      order.invoiceNumber,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.totalItemCount} item • ${order.tableNumber != null ? 'Meja ${order.tableNumber}' : 'Tanpa meja'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    if (order.customerName != null &&
                        order.customerName!.trim().isNotEmpty)
                      Text(
                        order.customerName!,
                        style: theme.textTheme.bodySmall?.copyWith(
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
                  const SizedBox(height: 4),
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
                      order.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
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
              height: 1.4,
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

class _OrderDateGroup {
  const _OrderDateGroup({required this.date, required this.orders});

  final DateTime date;
  final List<TransactionOrder> orders;
}

class _WaiterTableGroup {
  const _WaiterTableGroup({
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
