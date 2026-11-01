import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/subscription/domain/fulfillment_order_model.dart';
import 'package:dpos/features/subscription/presentation/controllers/fulfillment_controller.dart';
import 'package:dpos/features/subscription/presentation/providers/fulfillment_orders_provider.dart';
import 'package:dpos/features/subscription/presentation/providers/starter_kit_provider.dart';
import 'package:dpos/features/subscription/presentation/views/delivery_audit_screen.dart';

enum PackageFilter {
  all,
  processing,
  inTransit,
  delivered,
  cancelled,
}

class StarterKitOrdersSheet extends ConsumerStatefulWidget {
  const StarterKitOrdersSheet({
    super.key,
    this.isEmbedded = false,
  });

  final bool isEmbedded;

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StarterKitOrdersSheet(),
    );
  }

  @override
  ConsumerState<StarterKitOrdersSheet> createState() =>
      _StarterKitOrdersSheetState();
}

class _StarterKitOrdersSheetState extends ConsumerState<StarterKitOrdersSheet> {
  PackageFilter _selectedFilter = PackageFilter.all;
  FulfillmentOrder? _selectedOrder;

  void _navigateToRestockCatalog() {
    if (!widget.isEmbedded) {
      Navigator.of(context).pop();
    }
    ref.read(ownerSelectedMenuProvider.notifier).state =
        OwnerMenu.restockCatalog;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(fulfillmentOrdersProvider);
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return PopScope(
      canPop: _selectedOrder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedOrder != null) {
          setState(() => _selectedOrder = null);
        }
      },
      child: Container(
        constraints: widget.isEmbedded
            ? null
            : BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.90,
              ),
        decoration: BoxDecoration(
          color: widget.isEmbedded ? const Color(0xFFF8FAFC) : AppTheme.surface,
          borderRadius: widget.isEmbedded
              ? null
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ordersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat riwayat: $err',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.danger),
              ),
            ),
          ),
          data: (orders) {
            // Sinkronkan selectedOrder jika datanya diperbarui
            final effectiveSelected = _selectedOrder != null
                ? orders.where((o) => o.id == _selectedOrder!.id).firstOrNull ??
                    _selectedOrder
                : null;

            final isWideScreen = MediaQuery.sizeOf(context).width > 800;

            if (isWideScreen && widget.isEmbedded) {
              // Layout Tablet / Desktop: Master-Detail Side-by-Side
              return Row(
                children: [
                  SizedBox(
                    width: 380,
                    child: _buildListView(orders, currency, effectiveSelected),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: effectiveSelected != null
                        ? _OrderDetailView(
                            order: effectiveSelected,
                            currency: currency,
                            isEmbedded: widget.isEmbedded,
                            isWideScreen: true,
                            onBack: () => setState(() => _selectedOrder = null),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.touch_app_outlined,
                                  size: 48,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Pilih pesanan di sebelah kiri',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              );
            }

            // Layout Mobile / Standard: List -> Detail drill-down
            if (effectiveSelected != null) {
              return _OrderDetailView(
                order: effectiveSelected,
                currency: currency,
                isEmbedded: widget.isEmbedded,
                isWideScreen: false,
                onBack: () => setState(() => _selectedOrder = null),
              );
            }

            return _buildListView(orders, currency, null);
          },
        ),
      ),
    );
  }

  Widget _buildListView(
    List<FulfillmentOrder> orders,
    NumberFormat currency,
    FulfillmentOrder? selectedOrder,
  ) {
    if (orders.isEmpty) {
      return Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Pesanan Paket Usaha',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pesanan paket kemitraan awal atau pasokan restok barang toko Anda akan tercatat di sini beserta status pelacakan kurir realtime.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _navigateToRestockCatalog,
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: Text(
                        'Pesan Paket Usaha Sekarang',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Hitung jumlah order per status
    final countAll = orders.length;
    final countProcessing =
        orders.where((o) => o.isPending || o.isPacking).length;
    final countInTransit = orders.where((o) => o.isInTransit).length;
    final countDelivered = orders.where((o) => o.isDelivered).length;
    final countCancelled =
        orders.where((o) => o.status == 'cancelled').length;

    // Filter daftar pesanan
    List<FulfillmentOrder> filteredOrders;
    switch (_selectedFilter) {
      case PackageFilter.all:
        filteredOrders = orders;
        break;
      case PackageFilter.processing:
        filteredOrders =
            orders.where((o) => o.isPending || o.isPacking).toList();
        break;
      case PackageFilter.inTransit:
        filteredOrders = orders.where((o) => o.isInTransit).toList();
        break;
      case PackageFilter.delivered:
        filteredOrders = orders.where((o) => o.isDelivered).toList();
        break;
      case PackageFilter.cancelled:
        filteredOrders =
            orders.where((o) => o.status == 'cancelled').toList();
        break;
    }

    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Horizontal Filter Tabs
        Container(
          height: 40,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterPill(
                label: 'Semua',
                count: countAll,
                isSelected: _selectedFilter == PackageFilter.all,
                onTap: () => setState(() => _selectedFilter = PackageFilter.all),
              ),
              _buildFilterPill(
                label: 'Diproses',
                count: countProcessing,
                isSelected: _selectedFilter == PackageFilter.processing,
                onTap: () =>
                    setState(() => _selectedFilter = PackageFilter.processing),
              ),
              _buildFilterPill(
                label: 'Pengiriman',
                count: countInTransit,
                isSelected: _selectedFilter == PackageFilter.inTransit,
                onTap: () =>
                    setState(() => _selectedFilter = PackageFilter.inTransit),
              ),
              _buildFilterPill(
                label: 'Selesai',
                count: countDelivered,
                isSelected: _selectedFilter == PackageFilter.delivered,
                onTap: () =>
                    setState(() => _selectedFilter = PackageFilter.delivered),
              ),
              if (countCancelled > 0 ||
                  _selectedFilter == PackageFilter.cancelled)
                _buildFilterPill(
                  label: 'Dibatalkan',
                  count: countCancelled,
                  isSelected: _selectedFilter == PackageFilter.cancelled,
                  onTap: () =>
                      setState(() => _selectedFilter = PackageFilter.cancelled),
                ),
            ],
          ),
        ),

        // List Compact Order Tiles
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.filter_list_off_rounded,
                            size: 34,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak Ada Pesanan di Tab Ini',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tidak ditemukan pesanan dengan status "${_filterName(_selectedFilter)}".',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(
                                  color: Color(0xFFBFDBFE),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => setState(
                                () => _selectedFilter = PackageFilter.all,
                              ),
                              child: Text(
                                'Lihat Semua',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _navigateToRestockCatalog,
                              icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 14,
                              ),
                              label: Text(
                                'Pesan Baru',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async =>
                      ref.refresh(fulfillmentOrdersProvider),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        ..._groupOrdersByDate(filteredOrders).map(
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
                                padding: const EdgeInsets.only(bottom: 6),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final order = group.orders[index];
                                      final isSelected =
                                          selectedOrder?.id == order.id;
                                      return _FulfillmentOrderTile(
                                        order: order,
                                        currency: currency,
                                        isSelected: isSelected,
                                        onTap: () {
                                          setState(
                                              () => _selectedOrder = order);
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
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 20),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        if (!widget.isEmbedded)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            widget.isEmbedded ? 16 : 4,
            16,
            12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Pembelian Paket Usaha',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pilih pesanan untuk melihat detail pelacakan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _navigateToRestockCatalog,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                label: Text(
                  '+ Pesan Baru',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Status',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.refresh(fulfillmentOrdersProvider),
              ),
              if (!widget.isEmbedded)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0070FC) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0070FC)
                  : const Color(0xFFE2E8F0),
              width: 1,
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
                      color: Color(0x05000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _filterName(PackageFilter filter) {
    switch (filter) {
      case PackageFilter.all:
        return 'Semua';
      case PackageFilter.processing:
        return 'Diproses';
      case PackageFilter.inTransit:
        return 'Pengiriman';
      case PackageFilter.delivered:
        return 'Selesai';
      case PackageFilter.cancelled:
        return 'Dibatalkan';
    }
  }

  List<_OrderDateGroup> _groupOrdersByDate(List<FulfillmentOrder> orders) {
    final Map<DateTime, List<FulfillmentOrder>> groups = {};
    for (final order in orders) {
      final date = _dateOnly(order.createdAt);
      groups.putIfAbsent(date, () => []).add(order);
    }

    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedDates
        .map((d) => _OrderDateGroup(date: d, orders: groups[d]!))
        .toList();
  }

  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(date, today)) return 'Hari Ini';
    if (_isSameDay(date, yesterday)) return 'Kemarin';
    return _capitalize(DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date));
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
  final List<FulfillmentOrder> orders;
}

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
            '$orderCount pesanan',
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

// ─────────────────────────────────────────────────────────────
// COMPACT ORDER TILE (Mirip _OrderHistoryTile pada Riwayat Transaksi)
// ─────────────────────────────────────────────────────────────

class _FulfillmentOrderTile extends ConsumerWidget {
  const _FulfillmentOrderTile({
    required this.order,
    required this.currency,
    required this.onTap,
    this.isSelected = false,
  });

  final FulfillmentOrder order;
  final NumberFormat currency;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final starterKits = ref.watch(starterKitsProvider).value ?? [];
    final matchedKit = starterKits
        .where((k) => k.id == order.starterKitId || k.name == order.kitName)
        .firstOrNull;
    final packagePrice = matchedKit?.price ?? 200000;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF0070FC)
              : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF0070FC).withValues(alpha: 0.12)
                : const Color(0x06000000),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon Box / Truck
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: order.statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: order.statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    order.isDelivered
                        ? Icons.inventory_2_rounded
                        : (order.isInTransit
                            ? Icons.local_shipping_rounded
                            : (order.isPacking
                                ? Icons.all_inbox_rounded
                                : Icons.hourglass_top_rounded)),
                    color: order.statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Info Utama: Order Code, Kit Name, Date, Kurir
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.orderCode,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              order.kitName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            dateFormat.format(order.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          if (order.driverName != null &&
                              order.driverName!.trim().isNotEmpty) ...[
                            Text(
                              ' • ${order.driverName}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Cuplikan Barang yang Dibeli
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: Color(0xFF0070FC),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _getItemsSummary(order),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Status Badge Compact + Item Count Pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: order.statusBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: order.statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: order.statusColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  order.statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: order.statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              _getItemCountBadge(order),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0070FC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Harga & Icon Panah
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(packagePrice),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0070FC),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getItemsSummary(FulfillmentOrder order) {
    if (order.notes != null) {
      try {
        final trimmed = order.notes!.trim();
        if (trimmed.startsWith('{') || trimmed.contains('"wholesale_items"') || trimmed.contains('"items"')) {
          final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
          if (parsed['summary'] != null && parsed['summary'].toString().isNotEmpty) {
            return parsed['summary'].toString();
          }
          if (parsed['items'] is List) {
            final items = parsed['items'] as List<dynamic>;
            return items.map((it) => "${it['name'] ?? it['product_name']} (${it['quantity']})").join(', ');
          }
        }
      } catch (_) {}
    }

    final nameLower = order.kitName.toLowerCase();
    if (nameLower.contains('toko pemula') || nameLower.contains('paket 01')) {
      return 'Beras 2kg, Minyak 1L, Gula 1kg, Terigu 1kg, Mi Instan, Kopi, Sabun, Deterjen...';
    } else if (nameLower.contains('gen z') || nameLower.contains('paket 02')) {
      return 'Phone Charm, Pop Socket, Pelindung Kabel, Scrunchie, Gantungan Kunci...';
    } else if (nameLower.contains('makarizo') || nameLower.contains('paket 03')) {
      return 'Creambath, Scentsations Spray, Shampoo, Serum, Straightening Kit...';
    }
    return 'Paket Usaha Siap Buka Toko POS';
  }

  String _getItemCountBadge(FulfillmentOrder order) {
    if (order.notes != null) {
      try {
        final trimmed = order.notes!.trim();
        if (trimmed.startsWith('{') || trimmed.contains('"wholesale_items"') || trimmed.contains('"items"')) {
          final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
          if (parsed['items'] is List) {
            final count = (parsed['items'] as List).length;
            return '$count Barang';
          }
        }
      } catch (_) {}
    }

    final nameLower = order.kitName.toLowerCase();
    if (nameLower.contains('toko pemula') || nameLower.contains('paket 01')) {
      return '13 Barang';
    } else if (nameLower.contains('gen z') || nameLower.contains('paket 02')) {
      return '10 Barang';
    } else if (nameLower.contains('makarizo') || nameLower.contains('paket 03')) {
      return '6 Barang';
    }
    return '1 Paket';
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL VIEW (Mirip TransactionDetailScreen pada Riwayat Transaksi)
// ─────────────────────────────────────────────────────────────

class _OrderDetailView extends ConsumerWidget {
  const _OrderDetailView({
    required this.order,
    required this.currency,
    required this.isEmbedded,
    required this.isWideScreen,
    required this.onBack,
  });

  final FulfillmentOrder order;
  final NumberFormat currency;
  final bool isEmbedded;
  final bool isWideScreen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
    final starterKits = ref.watch(starterKitsProvider).value ?? [];
    final matchedKit = starterKits
        .where((k) => k.id == order.starterKitId || k.name == order.kitName)
        .firstOrNull;
    final packagePrice = matchedKit?.price ?? 200000;

    return Material(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // ── Header Detail ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                if (!isWideScreen)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                    ),
                    tooltip: 'Kembali ke Daftar',
                    onPressed: onBack,
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0070FC).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Color(0xFF0070FC),
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Pengiriman Paket',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        order.orderCode,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: order.statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: order.statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: order.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Detail Content ──────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Ringkasan Paket & Harga
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.card_giftcard_rounded,
                              color: AppTheme.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.kitName,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  currency.format(packagePrice),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dipesan pada: ${dateFormat.format(order.createdAt)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Timeline Status Alur Pengiriman
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.alt_route_rounded,
                            size: 18,
                            color: Color(0xFF0070FC),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status Alur Pengiriman',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTimeline(order),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Resi & Info Kurir Pengiriman
                if ((order.trackingNumber != null &&
                        order.trackingNumber!.trim().isNotEmpty) ||
                    (order.driverName != null &&
                        order.driverName!.trim().isNotEmpty)) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_shipping_rounded,
                              size: 18,
                              color: Color(0xFF0070FC),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Informasi Pengiriman Kurir',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                        if (order.trackingNumber != null &&
                            order.trackingNumber!.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NO. RESI / AWB:',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    order.trackingNumber!.trim(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: const Color(0xFF0070FC),
                                    ),
                                  ),
                                ],
                              ),
                              Builder(
                                builder: (ctx) => InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(
                                        text: order.trackingNumber!.trim()));
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'No. Resi disalin ke clipboard!'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF93C5FD)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.copy_rounded,
                                            size: 13, color: Color(0xFF0070FC)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Salin Resi',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0070FC),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.driverName != null &&
                            order.driverName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Kurir / Ekspedisi: ',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              Text(
                                order.driverName!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              if (order.driverPhone != null &&
                                  order.driverPhone!.trim().isNotEmpty) ...[
                                Text(
                                  ' (${order.driverPhone})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Alamat Pengiriman
                if (order.shippingAddress.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alamat Tujuan Pengiriman',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.shippingAddress}, ${order.shippingCity}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Rincian Barang yang Dikirimkan
                _buildItemsManifestCard(context),
                const SizedBox(height: 16),

                // 6. Tombol Aksi Lengkap
                _buildActionButtons(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsManifestCard(BuildContext context) {
    final items = _getManifestItems();
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Color(0xFF0070FC),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rincian Barang yang Dikirim',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${items.length} Barang',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0070FC),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
              height: 16,
              thickness: 0.5,
              color: Color(0xFFF8FAFC),
            ),
            itemBuilder: (context, idx) {
              final it = items[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        if (it.category != null && it.category!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            it.category!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${it.quantity} ${it.unit}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (it.price != null && it.price! > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          currency.format(it.price! * it.quantity),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<_ManifestItemDisplay> _getManifestItems() {
    // 1. Cek notes JSON untuk kulakan satuan
    if (order.notes != null) {
      try {
        final trimmed = order.notes!.trim();
        if (trimmed.startsWith('{') ||
            trimmed.contains('"wholesale_items"') ||
            trimmed.contains('"items"')) {
          final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
          if (parsed['items'] is List) {
            final list = parsed['items'] as List<dynamic>;
            return list.map((it) {
              final m = it as Map<String, dynamic>;
              return _ManifestItemDisplay(
                name: (m['name'] ?? m['product_name'] ?? 'Item Restok').toString(),
                quantity: (m['quantity'] as num?) ?? 1,
                unit: (m['unit'] ?? 'Pcs').toString(),
                category: (m['category'] ?? 'Kulakan Satuan').toString(),
                price: (m['price'] as num?)?.toDouble(),
              );
            }).toList();
          }
        }
      } catch (_) {}
    }

    // 2. Fallback berdasarkan nama paket usaha
    final kitNameLower = order.kitName.toLowerCase();
    if (kitNameLower.contains('toko pemula') || kitNameLower.contains('paket 01')) {
      return const [
        _ManifestItemDisplay(name: 'Beras Premium 2 kg', quantity: 1, unit: 'Bks', category: 'Sembako'),
        _ManifestItemDisplay(name: 'Minyak Goreng 1 Liter', quantity: 1, unit: 'Pcs', category: 'Sembako'),
        _ManifestItemDisplay(name: 'Gula Pasir Kristal 1 kg', quantity: 1, unit: 'Bks', category: 'Sembako'),
        _ManifestItemDisplay(name: 'Tepung Terigu 1 kg', quantity: 1, unit: 'Bks', category: 'Sembako'),
        _ManifestItemDisplay(name: 'Mi Instan Pilihan (Indomie/Sedaap)', quantity: 5, unit: 'Pcs', category: 'Makanan'),
        _ManifestItemDisplay(name: 'Kopi Sachet Pilihan', quantity: 10, unit: 'Sachet', category: 'Minuman'),
        _ManifestItemDisplay(name: 'Teh Celup Kotak', quantity: 1, unit: 'Kotak', category: 'Minuman'),
        _ManifestItemDisplay(name: 'Sabun Mandi Batang', quantity: 2, unit: 'Pcs', category: 'Perawatan Tubuh'),
        _ManifestItemDisplay(name: 'Sabun Cuci Piring Cair 400ml', quantity: 1, unit: 'Pcs', category: 'Kebutuhan Rumah'),
        _ManifestItemDisplay(name: 'Deterjen Pakaian Bersih 800g', quantity: 1, unit: 'Bks', category: 'Kebutuhan Rumah'),
        _ManifestItemDisplay(name: 'Pasta Gigi Keluarga 120g', quantity: 1, unit: 'Pcs', category: 'Perawatan Tubuh'),
        _ManifestItemDisplay(name: 'Kecap Manis Botol 135ml', quantity: 1, unit: 'Botol', category: 'Bumbu Dapur'),
        _ManifestItemDisplay(name: 'Tisu Wajah & Kemasan Syupeo Store', quantity: 1, unit: 'Paket', category: 'Perlengkapan Toko'),
      ];
    } else if (kitNameLower.contains('gen z') || kitNameLower.contains('paket 02')) {
      return const [
        _ManifestItemDisplay(name: 'Phone Charm Kekinian Trendi', quantity: 5, unit: 'Pcs', category: 'Aksesoris HP'),
        _ManifestItemDisplay(name: 'Pop Socket Karakter Viral', quantity: 3, unit: 'Pcs', category: 'Aksesoris HP'),
        _ManifestItemDisplay(name: 'Pelindung Kabel Handphone Spiral', quantity: 5, unit: 'Pcs', category: 'Aksesoris HP'),
        _ManifestItemDisplay(name: 'Scrunchie Rambut Satin Estetik', quantity: 5, unit: 'Pcs', category: 'Fashion'),
        _ManifestItemDisplay(name: 'Jepit Rambut Korea Doff', quantity: 4, unit: 'Pcs', category: 'Fashion'),
        _ManifestItemDisplay(name: 'Gantungan Kunci Karakter Akrilik', quantity: 5, unit: 'Pcs', category: 'Merchandise'),
        _ManifestItemDisplay(name: 'Sticker Pack Hologram Vinyl', quantity: 10, unit: 'Pack', category: 'Stationery'),
        _ManifestItemDisplay(name: 'Kaos Kaki Korea Stylish', quantity: 3, unit: 'Pasang', category: 'Fashion'),
        _ManifestItemDisplay(name: 'Mini Canvas Tote Bag Estetik', quantity: 2, unit: 'Pcs', category: 'Fashion'),
        _ManifestItemDisplay(name: 'Mini Makeup Pouch Velvet', quantity: 2, unit: 'Pcs', category: 'Fashion'),
      ];
    } else if (kitNameLower.contains('makarizo') ||
        kitNameLower.contains('beauty') ||
        kitNameLower.contains('paket 03')) {
      return const [
        _ManifestItemDisplay(name: 'Makarizo Hair Energy Creambath 500g', quantity: 2, unit: 'Jar', category: 'Perawatan Rambut'),
        _ManifestItemDisplay(name: 'Makarizo Hair Energy Scentsations Spray 100ml', quantity: 4, unit: 'Botol', category: 'Perawatan Rambut'),
        _ManifestItemDisplay(name: 'Makarizo Fibertherapy Conditioning Shampoo 170ml', quantity: 3, unit: 'Botol', category: 'Perawatan Rambut'),
        _ManifestItemDisplay(name: 'Makarizo Advisor Hair Recovery Serum 50ml', quantity: 2, unit: 'Botol', category: 'Perawatan Rambut'),
        _ManifestItemDisplay(name: 'Makarizo Easy Straight Straightening Kit 120ml', quantity: 2, unit: 'Set', category: 'Perawatan Rambut'),
        _ManifestItemDisplay(name: 'Alat Sisir Salon & Display Stand', quantity: 1, unit: 'Set', category: 'Display Toko'),
      ];
    }

    return [
      _ManifestItemDisplay(
        name: order.kitName,
        quantity: 1,
        unit: 'Paket Usaha',
        category: 'Paket Lengkap',
      ),
    ];
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    if (order.isInTransit) {
      return Column(
        children: [
          // 1. Primary Action: Buka Halaman Audit & Cross-Check Barang
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryAuditScreen(order: order),
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_rounded, size: 18),
              label: Text(
                'Audit & Konfirmasi Barang Diterima',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Hubungi Kurir via WhatsApp jika nomor driver tersedia
          if (order.driverPhone != null &&
              order.driverPhone!.trim().isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF15803D),
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                  backgroundColor: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => FulfillmentController.contactDriverWhatsApp(
                  context: context,
                  order: order,
                ),
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: Text(
                  'Hubungi Kurir (${order.driverName ?? "Driver"}) via WA',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 3. Konfirmasi Pesanan via WA Admin
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0070FC),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => FulfillmentController.contactAdminWhatsApp(
                context: context,
                order: order,
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 16),
              label: Text(
                'Konfirmasi Pesanan via WA Admin',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (order.isDelivered) {
      return Column(
        children: [
          // Banner Sukses Diterima
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barang Fisik Telah Diterima',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF166534),
                        ),
                      ),
                      Text(
                        'Katalog kasir POS Anda telah terisi produk dan siap bertransaksi.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0070FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                if (!isEmbedded) {
                  Navigator.of(context).pop();
                }
                ref.read(ownerSelectedMenuProvider.notifier).state =
                    OwnerMenu.home;
              },
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: Text(
                'Buka Kasir POS Sekarang',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tombol Audit / Cek Stok Masuk
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                backgroundColor: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryAuditScreen(order: order),
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_rounded, size: 16),
              label: Text(
                'Audit Ulang / Cek Stok Masuk',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0070FC),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                backgroundColor: const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: () {
                if (!isEmbedded) {
                  Navigator.of(context).pop();
                }
                ref.read(ownerSelectedMenuProvider.notifier).state =
                    OwnerMenu.restockCatalog;
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
              label: Text(
                'Pesan Lagi / Kulakan Restok',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => FulfillmentController.contactAdminWhatsApp(
                context: context,
                order: order,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
              label: Text(
                'Bantuan Syupeo via WhatsApp',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (order.isPacking) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0070FC),
            side: const BorderSide(color: Color(0xFF93C5FD)),
            backgroundColor: const Color(0xFFEFF6FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: () => FulfillmentController.contactAdminWhatsApp(
            context: context,
            order: order,
          ),
          icon: const Icon(Icons.inventory_2_outlined, size: 16),
          label: Text(
            'Tanya Status Pengemasan via WhatsApp',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else {
      // Menunggu Konfirmasi & Pembayaran
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF16A34A),
            side: const BorderSide(color: Color(0xFF86EFAC)),
            backgroundColor: const Color(0xFFF0FDF4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: () => FulfillmentController.contactAdminWhatsApp(
            context: context,
            order: order,
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: Text(
            'Konfirmasi Pembayaran via WhatsApp',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTimeline(FulfillmentOrder order) {
    final steps = [
      _TimelineStep(
        title: 'Pesanan Dibuat',
        subtitle: 'Menunggu konfirmasi admin',
        isCompleted: true,
        isActive: order.isPending,
      ),
      _TimelineStep(
        title: 'Dikemas di Hub',
        subtitle: 'Akun aktif & disiapkan',
        isCompleted: order.isPacking || order.isInTransit || order.isDelivered,
        isActive: order.isPacking,
      ),
      _TimelineStep(
        title: 'Pengiriman Kurir',
        subtitle: order.driverName != null
            ? 'Driver: ${order.driverName}'
            : 'Menuju lokasi toko',
        isCompleted: order.isInTransit || order.isDelivered,
        isActive: order.isInTransit,
      ),
      _TimelineStep(
        title: 'Toko Siap Buka',
        subtitle: 'Barang diterima',
        isCompleted: order.isDelivered,
        isActive: order.isDelivered,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final isLast = idx == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.isCompleted
                          ? (order.isDelivered
                              ? const Color(0xFF10B981)
                              : (step.isActive
                                  ? const Color(0xFF0070FC)
                                  : const Color(0xFF10B981)))
                          : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: step.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 24,
                      color: step.isCompleted
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: step.isActive || step.isCompleted
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: step.isActive || step.isCompleted
                              ? AppTheme.text
                              : AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        step.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
  });
}

class _ManifestItemDisplay {
  final String name;
  final num quantity;
  final String unit;
  final String? category;
  final double? price;

  const _ManifestItemDisplay({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category,
    this.price,
  });
}
