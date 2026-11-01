import 'package:dpos/core/providers/analytics_outlet_filter_provider.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_path.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';
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
        // ── Search bar & Outlet Filter ──────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    _debouncer.run(() {
                      setState(() => _searchQuery = v);
                      ref.read(orderHistoryProvider.notifier).search(v);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari nomor invoice...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: InputBorder.none,
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
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const AnalyticsOutletFilterSelector(compact: true),
          ],
        ),
        const SizedBox(height: 10),

        // ── Filter Status Pills ─────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterPill(
                label: 'Semua Status',
                isSelected: _selectedStatus == null,
                onTap: () => setState(() => _selectedStatus = null),
              ),
              ...TransactionStatus.values.map(
                (status) => _buildFilterPill(
                  label: status == TransactionStatus.paid
                      ? 'Lunas'
                      : (status == TransactionStatus.confirmed
                          ? 'Pesanan Masuk'
                          : (status == TransactionStatus.draft
                              ? 'Draft'
                              : (status == TransactionStatus.void_
                                  ? 'Dibatalkan'
                                  : status.label))),
                  isSelected: _selectedStatus == status,
                  onTap: () {
                    setState(() {
                      _selectedStatus =
                          _selectedStatus == status ? null : status;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── List of Transactions ────────────────────────────────
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              final filteredOrders = _applyFilters(orders);

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 44,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty || _selectedStatus != null
                            ? 'Tidak ada transaksi dengan filter ini'
                            : 'Belum ada transaksi tercatat',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
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
                              orderCount: group.orders.length,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
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
                                },
                                childCount: group.orders.length,
                              ),
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
                                    color: Color(0xFF0070FC),
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
            loading: () => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: const [
                GeneralCardSkeleton(),
                GeneralCardSkeleton(),
                GeneralCardSkeleton(),
                GeneralCardSkeleton(),
              ],
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gagal memuat transaksi: $e',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFFDC2626),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: widget.padding.horizontal == 0
              ? const EdgeInsets.fromLTRB(16, 12, 16, 0)
              : widget.padding,
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
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0070FC) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0070FC)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0070FC).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, TransactionOrder? order) {
    if (order == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0070FC).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: Color(0xFF0070FC),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Detail Transaksi',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih salah satu transaksi pada daftar di samping untuk melihat rincian nota, mencetak struk, atau melakukan retur.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
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
      final date = order.createdAt != null
          ? _dateOnly(order.createdAt!)
          : DateTime(1970);
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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _OrderDateGroup {
  _OrderDateGroup({required this.date, required this.orders});
  final DateTime date;
  final List<TransactionOrder> orders;
}

// ── Sticky Date Header ──────────────────────────────────────────

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({
    required this.title,
    required this.orderCount,
  });

  final String title;
  final int orderCount;

  @override
  double get minExtent => 36;

  @override
  double get maxExtent => 36;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$orderCount transaksi',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.orderCount != orderCount;
  }
}

// ── Order History Tile (Syupeo Design System & Web Aligned) ─────

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
    final (badgeBg, badgeText, badgeBorder, badgeLabel, badgeIcon) =
        _getStatusBadgeStyle(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF0070FC) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF0070FC).withValues(alpha: 0.12)
                : const Color(0x06000000),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Soft blue receipt icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0070FC).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 22,
                    color: Color(0xFF0070FC),
                  ),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              order.invoiceNumber,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.payments.any((p) => p.methodType == 'debt')) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                'Kasbon',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${order.totalItemCount} item',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.createdAt != null
                                ? DateFormat('dd MMM, HH:mm')
                                    .format(order.createdAt!)
                                : '-',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (outletName != null && outletName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 12,
                                color: Color(0xFF0070FC),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                outletName!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF0070FC),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (order.cashierName != null &&
                          order.cashierName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Kasir: ${order.cashierName!}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Trailing: Amount + Status Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currency.format(order.grandTotal),
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 11, color: badgeText),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: badgeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.status == TransactionStatus.confirmed ||
                        order.status == TransactionStatus.draft) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 28,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.payments_rounded, size: 14),
                          label: Text(
                            'Bayar',
                            style: GoogleFonts.inter(
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
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Color, String, IconData) _getStatusBadgeStyle(
      TransactionStatus status) {
    return switch (status) {
      TransactionStatus.paid => (
          const Color(0xFFECFDF5),
          const Color(0xFF047857),
          const Color(0xFFA7F3D0),
          'Lunas',
          Icons.check_circle_rounded,
        ),
      TransactionStatus.confirmed => (
          const Color(0xFFEFF6FF),
          const Color(0xFF1D4ED8),
          const Color(0xFFBFDBFE),
          'Belum Bayar',
          Icons.schedule_rounded,
        ),
      TransactionStatus.draft => (
          const Color(0xFFFFFBEB),
          const Color(0xFFB45309),
          const Color(0xFFFDE68A),
          'Draft',
          Icons.edit_note_rounded,
        ),
      TransactionStatus.partialPaid => (
          const Color(0xFFFFF7ED),
          const Color(0xFFC2410C),
          const Color(0xFFFED7AA),
          'Sebagian',
          Icons.hourglass_bottom_rounded,
        ),
      TransactionStatus.void_ => (
          const Color(0xFFFFF1F2),
          const Color(0xFFBE123C),
          const Color(0xFFFECDD3),
          'Batal',
          Icons.cancel_outlined,
        ),
      TransactionStatus.refunded => (
          const Color(0xFFFAF5FF),
          const Color(0xFF6B21A8),
          const Color(0xFFE9D5FF),
          'Refund',
          Icons.replay_rounded,
        ),
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
