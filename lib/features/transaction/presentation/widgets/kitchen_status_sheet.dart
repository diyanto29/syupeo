import 'dart:async';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/kitchen/presentation/kitchen_queue_screen.dart';
import 'package:dpos/features/transaction/data/receipt_service.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class KitchenStatusSheet extends ConsumerStatefulWidget {
  const KitchenStatusSheet({super.key});

  @override
  ConsumerState<KitchenStatusSheet> createState() => _KitchenStatusSheetState();
}

class _KitchenStatusSheetState extends ConsumerState<KitchenStatusSheet> {
  Timer? _ticker;
  KitchenStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatElapsed(DateTime? createdAt) {
    if (createdAt == null) return '0 mnt lalu';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} dtk lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    return '${diff.inHours} jam ${diff.inMinutes % 60} mnt lalu';
  }

  Color _getSlaColor(DateTime? createdAt) {
    if (createdAt == null) return const Color(0xFF64748B);
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes >= 20) return const Color(0xFFDC2626); // Merah bahaya (>20 mnt)
    if (minutes >= 10) return const Color(0xFFEA580C); // Oranye peringatan (>10 mnt)
    return const Color(0xFF16A34A); // Hijau aman (<10 mnt)
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(kitchenOrdersProvider);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: const Icon(
                      Icons.soup_kitchen_rounded,
                      color: Color(0xFFEA580C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monitor Dapur (KDS)',
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Pantau dan cetak tiket pesanan dapur secara real-time',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Segarkan',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => ref.invalidate(kitchenOrdersProvider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Filter Tabs & Full KDS button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ordersAsync.maybeWhen(
                data: (allOrders) {
                  final pendingCount = allOrders
                      .where((o) => o.kitchenStatus == KitchenStatus.pending)
                      .length;
                  final cookingCount = allOrders
                      .where((o) => o.kitchenStatus == KitchenStatus.cooking)
                      .length;
                  final readyCount = allOrders
                      .where((o) => o.kitchenStatus == KitchenStatus.ready)
                      .length;

                  return Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'Semua (${allOrders.length})',
                                isSelected: _selectedFilter == null,
                                onTap: () => setState(() => _selectedFilter = null),
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label: 'Menunggu ($pendingCount)',
                                color: const Color(0xFFEA580C),
                                isSelected: _selectedFilter == KitchenStatus.pending,
                                onTap: () => setState(
                                  () => _selectedFilter = KitchenStatus.pending,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label: 'Dimasak ($cookingCount)',
                                color: const Color(0xFF2563EB),
                                isSelected: _selectedFilter == KitchenStatus.cooking,
                                onTap: () => setState(
                                  () => _selectedFilter = KitchenStatus.cooking,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label: 'Siap Saji ($readyCount)',
                                color: const Color(0xFF16A34A),
                                isSelected: _selectedFilter == KitchenStatus.ready,
                                onTap: () => setState(
                                  () => _selectedFilter = KitchenStatus.ready,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(ownerSelectedMenuProvider.notifier).state =
                              OwnerMenu.kitchenQueue;
                        },
                        icon: const Icon(Icons.fullscreen_rounded, size: 18),
                        label: Text(
                          'KDS Penuh',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),

            const Divider(height: 20),

            // Content List
            Flexible(
              child: ordersAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Gagal memuat pesanan dapur: $err'),
                  ),
                ),
                data: (allOrders) {
                  final filtered = _selectedFilter == null
                      ? allOrders
                      : allOrders
                          .where((o) => o.kitchenStatus == _selectedFilter)
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Dapur Bersih & Tidak Ada Antrian',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pesanan baru dari kasir atau QR akan otomatis muncul di sini.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return _buildKitchenOrderCard(context, order);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color color = const Color(0xFF0F172A),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildKitchenOrderCard(BuildContext context, TransactionOrder order) {
    final status = order.kitchenStatus;
    final slaColor = _getSlaColor(order.createdAt);
    final elapsedStr = _formatElapsed(order.createdAt);

    final statusLabel = switch (status) {
      KitchenStatus.pending => 'Menunggu',
      KitchenStatus.cooking => 'Sedang Dimasak',
      KitchenStatus.ready => 'Siap Saji',
      KitchenStatus.served => 'Selesai',
    };

    final statusBg = switch (status) {
      KitchenStatus.pending => const Color(0xFFFFF7ED),
      KitchenStatus.cooking => const Color(0xFFEFF6FF),
      KitchenStatus.ready => const Color(0xFFF0FDF4),
      KitchenStatus.served => const Color(0xFFF8FAFC),
    };

    final statusFg = switch (status) {
      KitchenStatus.pending => const Color(0xFFEA580C),
      KitchenStatus.cooking => const Color(0xFF2563EB),
      KitchenStatus.ready => const Color(0xFF16A34A),
      KitchenStatus.served => const Color(0xFF64748B),
    };

    final diningText = order.diningOption == DiningOption.dineIn
        ? (order.tableNumber != null ? 'Meja ${order.tableNumber}' : 'Dine In')
        : 'Take Away';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == KitchenStatus.cooking
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFE2E8F0),
          width: status == KitchenStatus.cooking ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    diningText,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  order.invoiceNumber,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusFg.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // SLA & Waiter info
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: slaColor),
                const SizedBox(width: 4),
                Text(
                  elapsedStr,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: slaColor,
                  ),
                ),
                if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${order.customerName}',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),

            const Divider(height: 16),

            // Items List
            ...order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          if (item.notes != null && item.notes!.trim().isNotEmpty)
                            Text(
                              '* ${item.notes} *',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  'Catatan: ${order.notes}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Actions (Print ticket + update status)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(receiptServiceProvider).printKitchenReceipt(order);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mencetak tiket dapur untuk ${order.invoiceNumber}...',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: Text(
                    'Cetak Tiket',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Spacer(),
                _buildQuickStatusAction(order),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusAction(TransactionOrder order) {
    final status = order.kitchenStatus;

    if (status == KitchenStatus.pending) {
      return FilledButton.icon(
        onPressed: () => _updateStatus(order, KitchenStatus.cooking),
        icon: const Icon(Icons.soup_kitchen_rounded, size: 15),
        label: Text(
          'Mulai Masak',
          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    if (status == KitchenStatus.cooking) {
      return FilledButton.icon(
        onPressed: () => _updateStatus(order, KitchenStatus.ready),
        icon: const Icon(Icons.check_circle_rounded, size: 15),
        label: Text(
          'Siap Saji',
          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    if (status == KitchenStatus.ready) {
      return FilledButton.icon(
        onPressed: () => _updateStatus(order, KitchenStatus.served),
        icon: const Icon(Icons.done_all_rounded, size: 15),
        label: Text(
          'Selesai',
          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color(0xFF475569),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _updateStatus(TransactionOrder order, KitchenStatus newStatus) async {
    try {
      await ref
          .read(transactionRepositoryProvider)
          .updateKitchenStatus(order.id, newStatus);
      ref.invalidate(kitchenOrdersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
