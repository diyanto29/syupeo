import 'dart:async';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/transaction/data/transaction_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/state/cart_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

final _timeFormat = DateFormat('HH:mm', 'id_ID');
final _dateFormat = DateFormat('dd MMM, HH:mm', 'id_ID');

/// Provider daftar order dapur aktif untuk outlet saat ini.
final kitchenOrdersProvider =
    FutureProvider.autoDispose<List<TransactionOrder>>((ref) async {
      final bootstrap = ref.watch(homeBootstrapProvider).value;
      final outletId = bootstrap?.currentOutlet?.id;
      if (outletId == null) {
        return const [];
      }

      // Ambil transaksi terbaru (hingga 150 transaksi aktif)
      final orders = await ref
          .read(transactionRepositoryProvider)
          .getOrders(outletId, limit: 150);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Filter: Hanya tampilkan pesanan yang relevan untuk dapur (tidak batal/refund, dan memiliki item)
      // Jangan tampilkan transaksi masa lalu dari berminggu-minggu lalu yang sudah lunas/selesai
      final kitchenOrders = orders.where((order) {
        if (order.status == TransactionStatus.void_ ||
            order.status == TransactionStatus.refunded) {
          return false;
        }
        if (order.items.isEmpty) return false;

        final orderTime = order.createdAt ?? now;
        final isToday = orderTime.isAfter(todayStart);

        // Pesanan yang sudah selesai (served) hanya ditampilkan jika dibuat hari ini (tab 'Selesai Hari Ini')
        if (order.kitchenStatus == KitchenStatus.served) {
          return isToday;
        }

        // Pesanan aktif (pending/cooking/ready) yang dibuat hari ini atau dalam 24 jam terakhir
        final isRecentActive =
            orderTime.isAfter(now.subtract(const Duration(hours: 24)));
        return isToday || isRecentActive;
      }).toList();

      // Urutkan: Order yang paling lama menunggu (created_at paling awal) di depan
      kitchenOrders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return aTime.compareTo(bTime);
      });

      return kitchenOrders;
    });

/// Tab filter status dapur
enum KitchenTabFilter {
  activeAll('Semua Aktif'),
  pending('Menunggu'),
  cooking('Sedang Dimasak'),
  ready('Siap Saji'),
  served('Selesai');

  final String label;
  const KitchenTabFilter(this.label);
}

class KitchenQueueScreen extends ConsumerStatefulWidget {
  const KitchenQueueScreen({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  ConsumerState<KitchenQueueScreen> createState() => _KitchenQueueScreenState();
}

class _KitchenQueueScreenState extends ConsumerState<KitchenQueueScreen> {
  KitchenTabFilter _activeTab = KitchenTabFilter.activeAll;
  String _searchQuery = '';
  DiningOption? _diningFilter;
  bool _autoRefreshEnabled = true;

  // Optimistic UI state overrides agar perubahan status langsung responsif seketika
  final Map<String, KitchenStatus> _localStatusOverrides = {};

  Timer? _liveClockTimer;
  Timer? _autoRefreshTimer;
  DateTime _lastRefreshedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Live ticker setiap detik untuk menghitung elapsed time (SLA) secara real-time
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Auto-refresh data setiap 15 detik jika diaktifkan
    _startAutoRefreshTimer();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _autoRefreshEnabled) {
        _refreshData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData({bool silent = false}) async {
    ref.invalidate(kitchenOrdersProvider);
    await ref.read(kitchenOrdersProvider.future);
    if (mounted) {
      setState(() {
        _lastRefreshedAt = DateTime.now();
      });
      if (!silent) {
        toastification.show(
          context: context,
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          title: const Text('Data Dapur Diperbarui'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _updateKitchenStatus(
    TransactionOrder order,
    KitchenStatus newStatus,
  ) async {
    HapticFeedback.mediumImpact();
    final prevStatus = _localStatusOverrides[order.id] ?? order.kitchenStatus;

    // 1. Optimistic Update (respons instan seketika di layar)
    setState(() {
      _localStatusOverrides[order.id] = newStatus;
    });

    final statusTitle = switch (newStatus) {
      KitchenStatus.cooking => 'Mulai memasak ${order.invoiceNumber}! 🔥',
      KitchenStatus.ready =>
        '${order.tableNumber != null ? "Meja ${order.tableNumber}" : "Pesanan"} Siap Saji! 🛎️',
      KitchenStatus.served => 'Pesanan ${order.invoiceNumber} Selesai Diantar! ✅',
      KitchenStatus.pending => 'Kembali ke Antrean Menunggu ⏳',
    };

    if (newStatus == KitchenStatus.ready) {
      SystemSound.play(SystemSoundType.click);
    }

    if (mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: Text(statusTitle),
        autoCloseDuration: const Duration(seconds: 2),
      );
    }

    // 2. Kirim update ke server Supabase
    try {
      await ref
          .read(transactionRepositoryProvider)
          .updateKitchenStatus(order.id, newStatus);

      await _refreshData(silent: true);
      if (mounted) {
        setState(() {
          _localStatusOverrides.remove(order.id);
        });
      }
    } catch (e) {
      // Revert status jika gagal di server
      if (mounted) {
        setState(() {
          _localStatusOverrides[order.id] = prevStatus;
        });
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Gagal Memperbarui Status Dapur'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final ordersAsync = ref.watch(kitchenOrdersProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 768;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HEADER: TITLE & CONTROLS ─────────────────────────────────
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Icon(
                    Icons.soup_kitchen_rounded,
                    color: Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Antrian Dapur (KDS)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFEDD5)),
                            ),
                            child: Text(
                              bootstrap?.currentOutlet?.name ?? 'Kitchen',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pantau SLA & kelola antrean real-time • Update ${_timeFormat.format(_lastRefreshedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildAutoRefreshButton(),
                const SizedBox(width: 8),
                _buildRefreshIconButton(),
              ],
            )
          else
            // Compact mobile control strip (No overflow, clean and spacious)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.soup_kitchen_rounded,
                        color: Color(0xFFEA580C),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          bootstrap?.currentOutlet?.name ?? 'Kitchen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _timeFormat.format(_lastRefreshedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                _buildAutoRefreshButton(compact: true),
                const SizedBox(width: 4),
                _buildRefreshIconButton(compact: true),
              ],
            ),

          SizedBox(height: isTablet ? 14 : 10),

          // ─── ORDERS CONTENT ───────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFEA580C)),
                    SizedBox(height: 12),
                    Text(
                      'Memuat antrean dapur...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Gagal memuat antrean: $err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _refreshData(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (allOrders) {
                // Terapkan override optimistik lokal jika ada agar UI merespons instan
                final resolvedOrders = allOrders.map((o) {
                  final override = _localStatusOverrides[o.id];
                  return override != null ? o.copyWith(kitchenStatus: override) : o;
                }).toList();

                // Kalkulasi data statistik
                final pendingList = resolvedOrders
                    .where((o) => o.kitchenStatus == KitchenStatus.pending)
                    .toList();
                final cookingList = resolvedOrders
                    .where((o) => o.kitchenStatus == KitchenStatus.cooking)
                    .toList();
                final readyList = resolvedOrders
                    .where((o) => o.kitchenStatus == KitchenStatus.ready)
                    .toList();
                final servedList = resolvedOrders
                    .where((o) => o.kitchenStatus == KitchenStatus.served)
                    .toList();
                final activeList = resolvedOrders
                    .where((o) => o.kitchenStatus != KitchenStatus.served)
                    .toList();

                // Filter berdasarkan tab
                List<TransactionOrder> filteredList = switch (_activeTab) {
                  KitchenTabFilter.activeAll => activeList,
                  KitchenTabFilter.pending => pendingList,
                  KitchenTabFilter.cooking => cookingList,
                  KitchenTabFilter.ready => readyList,
                  KitchenTabFilter.served => servedList,
                };

                // Filter search
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filteredList = filteredList.where((o) {
                    final matchInvoice = o.invoiceNumber.toLowerCase().contains(q);
                    final matchCustomer = (o.customerName ?? '').toLowerCase().contains(q);
                    final matchTable = (o.tableNumber?.toString() ?? '').contains(q);
                    final matchItems = o.items.any((item) => item.name.toLowerCase().contains(q));
                    return matchInvoice || matchCustomer || matchTable || matchItems;
                  }).toList();
                }

                // Filter tipe konsumsi
                if (_diningFilter != null) {
                  filteredList = filteredList
                      .where((o) => o.diningOption == _diningFilter)
                      .toList();
                }

                return Column(
                  children: [
                    // ─── KPI METRICS PULSE ─────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: isTablet
                              ? _buildMetricCard(
                                  label: 'Menunggu',
                                  count: pendingList.length,
                                  icon: Icons.hourglass_top_rounded,
                                  color: const Color(0xFF64748B),
                                  bgColor: const Color(0xFFF8FAFC),
                                  borderColor: const Color(0xFFE2E8F0),
                                  isActive: _activeTab == KitchenTabFilter.pending,
                                  onTap: () => setState(() => _activeTab = KitchenTabFilter.pending),
                                )
                              : _buildCompactMetricCard(
                                  label: 'Menunggu',
                                  count: pendingList.length,
                                  icon: Icons.hourglass_top_rounded,
                                  color: const Color(0xFF64748B),
                                  bgColor: const Color(0xFFF8FAFC),
                                  borderColor: const Color(0xFFE2E8F0),
                                  isActive: _activeTab == KitchenTabFilter.pending,
                                  onTap: () => setState(() => _activeTab = KitchenTabFilter.pending),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: isTablet
                              ? _buildMetricCard(
                                  label: 'Dimasak',
                                  count: cookingList.length,
                                  icon: Icons.local_fire_department_rounded,
                                  color: const Color(0xFFEA580C),
                                  bgColor: const Color(0xFFFFF7ED),
                                  borderColor: const Color(0xFFFFEDD5),
                                  isActive: _activeTab == KitchenTabFilter.cooking,
                                  onTap: () => setState(() => _activeTab = KitchenTabFilter.cooking),
                                )
                              : _buildCompactMetricCard(
                                  label: 'Dimasak',
                                  count: cookingList.length,
                                  icon: Icons.local_fire_department_rounded,
                                  color: const Color(0xFFEA580C),
                                  bgColor: const Color(0xFFFFF7ED),
                                  borderColor: const Color(0xFFFFEDD5),
                                  isActive: _activeTab == KitchenTabFilter.cooking,
                                  onTap: () => setState(() => _activeTab = KitchenTabFilter.cooking),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: isTablet
                              ? _buildMetricCard(
                                  label: 'Siap Saji',
                                  count: readyList.length,
                                  icon: Icons.room_service_rounded,
                                  color: const Color(0xFF059669),
                                  bgColor: const Color(0xFFECFDF5),
                                  borderColor: const Color(0xFFA7F3D0),
                                  isActive: _activeTab == KitchenTabFilter.ready,
                                  onTap: () => setState(() => _activeTab = KitchenTabFilter.ready),
                                )
                              : _buildCompactMetricCard(
                                  label: 'Siap Saji',
                                  count: readyList.length,
                                  icon: Icons.room_service_rounded,
                                  color: const Color(0xFF059669),
                                  bgColor: const Color(0xFFECFDF5),
                                  borderColor: const Color(0xFFA7F3D0),
                                  isActive: _activeTab == KitchenTabFilter.ready,
                                  onTap: () => setState(() => _activeTab = KitchenTabFilter.ready),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─── FILTER TABS & SEARCH BAR ──────────────────────
                    Row(
                      children: [
                        // Search Box
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Cari meja, invoice, menu...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Dining Option Filter Dropdown
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DiningOption?>(
                              value: _diningFilter,
                              hint: const Text(
                                'Semua Tipe',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Semua Tipe', style: TextStyle(fontSize: 12)),
                                ),
                                ...DiningOption.values.map(
                                  (opt) => DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt.label, style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                              onChanged: (val) => setState(() => _diningFilter = val),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Filter Status Tabs
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStatusTabChip(
                            label: 'Semua Aktif',
                            count: activeList.length,
                            isSelected: _activeTab == KitchenTabFilter.activeAll,
                            onTap: () => setState(() => _activeTab = KitchenTabFilter.activeAll),
                          ),
                          _buildStatusTabChip(
                            label: 'Menunggu',
                            count: pendingList.length,
                            isSelected: _activeTab == KitchenTabFilter.pending,
                            onTap: () => setState(() => _activeTab = KitchenTabFilter.pending),
                          ),
                          _buildStatusTabChip(
                            label: 'Sedang Dimasak',
                            count: cookingList.length,
                            isSelected: _activeTab == KitchenTabFilter.cooking,
                            onTap: () => setState(() => _activeTab = KitchenTabFilter.cooking),
                          ),
                          _buildStatusTabChip(
                            label: 'Siap Saji',
                            count: readyList.length,
                            isSelected: _activeTab == KitchenTabFilter.ready,
                            onTap: () => setState(() => _activeTab = KitchenTabFilter.ready),
                          ),
                          _buildStatusTabChip(
                            label: 'Selesai Hari Ini',
                            count: servedList.length,
                            isSelected: _activeTab == KitchenTabFilter.served,
                            onTap: () => setState(() => _activeTab = KitchenTabFilter.served),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── TICKETS GRID / LIST ───────────────────────────
                    Expanded(
                      child: filteredList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.done_all_rounded,
                                      color: Color(0xFF10B981),
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _activeTab == KitchenTabFilter.served
                                        ? 'Belum ada pesanan selesai'
                                        : 'Semua Pesanan Bersih! 🎉',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _activeTab == KitchenTabFilter.served
                                        ? 'Pesanan yang telah diantar akan tersimpan di sini.'
                                        : 'Tidak ada antrean pesanan yang menunggu saat ini.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : isTablet
                              ? GridView.builder(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: width >= 1280
                                        ? 4
                                        : (width >= 960 ? 3 : 2),
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: width >= 1280
                                        ? 0.88
                                        : (width >= 960 ? 0.94 : 1.05),
                                  ),
                                  itemCount: filteredList.length,
                                  itemBuilder: (context, index) {
                                    final order = filteredList[index];
                                    return _buildKitchenTicketCard(order, isGrid: true);
                                  },
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: filteredList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final order = filteredList[index];
                                    return _buildKitchenTicketCard(order, isGrid: false);
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── WIDGET: AUTO-REFRESH BUTTON ─────────────────────────────────────
  Widget _buildAutoRefreshButton({bool compact = false}) {
    return InkWell(
      onTap: () {
        setState(() {
          _autoRefreshEnabled = !_autoRefreshEnabled;
          if (_autoRefreshEnabled) {
            _startAutoRefreshTimer();
          } else {
            _autoRefreshTimer?.cancel();
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: _autoRefreshEnabled
              ? const Color(0xFFECFDF5)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _autoRefreshEnabled
                ? const Color(0xFFA7F3D0)
                : const Color(0xFFE2E8F0),
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
                color: _autoRefreshEnabled
                    ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              _autoRefreshEnabled ? (compact ? 'Auto' : 'Auto (15s)') : 'Off',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: _autoRefreshEnabled
                    ? const Color(0xFF047857)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── WIDGET: REFRESH ICON BUTTON ─────────────────────────────────────
  Widget _buildRefreshIconButton({bool compact = false}) {
    return IconButton(
      tooltip: 'Refresh Pesanan',
      padding: compact ? const EdgeInsets.all(6) : const EdgeInsets.all(8),
      constraints: compact ? const BoxConstraints() : null,
      icon: Icon(
        Icons.refresh_rounded,
        size: compact ? 20 : 22,
        color: const Color(0xFF0F172A),
      ),
      onPressed: () => _refreshData(silent: false),
    );
  }

  // ─── WIDGET: COMPACT METRIC CARD (MOBILE) ─────────────────────────────
  Widget _buildCompactMetricCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : borderColor,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── WIDGET: STAT CARD (TABLET) ──────────────────────────────────────
  Widget _buildMetricCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : borderColor,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count Tiket',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── WIDGET: STATUS TAB CHIP ──────────────────────────────────────────
  Widget _buildStatusTabChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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

  // ─── WIDGET: KITCHEN TICKET CARD ──────────────────────────────────────
  Widget _buildKitchenTicketCard(TransactionOrder order, {bool isGrid = false}) {
    final now = DateTime.now();
    final createdAt = order.createdAt ?? now;
    final elapsed = now.difference(createdAt);
    final elapsedMinutes = elapsed.inMinutes;
    final elapsedSeconds = elapsed.inSeconds % 60;

    // SLA Color Indicator
    // < 10 mins: Normal (Green)
    // 10 - 20 mins: Warning (Amber)
    // > 20 mins: Overdue / Urgent (Red)
    final isUrgent = elapsedMinutes >= 20;
    final isWarning = elapsedMinutes >= 10 && elapsedMinutes < 20;

    final slaBgColor = isUrgent
        ? const Color(0xFFFEF2F2)
        : (isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));
    final slaTextColor = isUrgent
        ? const Color(0xFFDC2626)
        : (isWarning ? const Color(0xFFD97706) : const Color(0xFF059669));
    final slaBorderColor = isUrgent
        ? const Color(0xFFFECACA)
        : (isWarning ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0));

    final isServed = order.kitchenStatus == KitchenStatus.served;

    final String timerText;
    if (elapsedMinutes >= 1440) {
      final days = elapsedMinutes ~/ 1440;
      final hours = (elapsedMinutes % 1440) ~/ 60;
      timerText = '${days}h ${hours}j';
    } else if (elapsedMinutes >= 60) {
      final hours = elapsedMinutes ~/ 60;
      final mins = elapsedMinutes % 60;
      timerText = '${hours}j ${mins}m';
    } else {
      timerText =
          '${elapsedMinutes.toString().padLeft(2, '0')}:${elapsedSeconds.toString().padLeft(2, '0')}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUrgent && !isServed
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
          width: isUrgent && !isServed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: isGrid ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // ── TICKET HEADER ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: order.kitchenStatus == KitchenStatus.cooking
                  ? const Color(0xFFFFF7ED)
                  : (order.kitchenStatus == KitchenStatus.ready
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                // Table / Order Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.diningOption == DiningOption.takeAway
                            ? Icons.shopping_bag_outlined
                            : (order.diningOption == DiningOption.delivery
                                ? Icons.delivery_dining_rounded
                                : Icons.table_restaurant_rounded),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.tableNumber != null
                            ? 'MEJA ${order.tableNumber}'
                            : order.diningOption.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Invoice & Source
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.invoiceNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '${order.orderSource.label} • ${_timeFormat.format(createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Live SLA Timer Badge
                if (!isServed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: slaBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: slaBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUrgent ? Icons.warning_rounded : Icons.timer_outlined,
                          size: 13,
                          color: slaTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timerText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: slaTextColor,
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),

                const SizedBox(width: 4),

                // Payment Status Badge (Lunas / Belum Bayar)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status == TransactionStatus.paid
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: order.status == TransactionStatus.paid
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    order.status == TransactionStatus.paid ? 'Lunas' : 'Belum Bayar',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: order.status == TransactionStatus.paid
                          ? const Color(0xFF059669)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── TICKET ITEMS LIST ──
          if (isGrid)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: order.items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 12,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, idx) => _buildItemRow(order.items[idx]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < order.items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 12,
                        color: Color(0xFFF1F5F9),
                      ),
                    _buildItemRow(order.items[i]),
                  ],
                ],
              ),
            ),

          // ── ORDER LEVEL NOTES (IF ANY) ──
          if (order.notes != null && order.notes!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Catatan: ${order.notes}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── TICKET FOOTER & ACTION BUTTONS ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                // Option menu / Print KOT button
                IconButton(
                  tooltip: 'Cetak Tiket Dapur',
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () => _printKitchenTicket(order),
                ),
                const SizedBox(width: 4),

                // Main Status Action Buttons
                Expanded(
                  child: Builder(
                    builder: (context) {
                      switch (order.kitchenStatus) {
                        case KitchenStatus.pending:
                          return ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Mulai Masak',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () => _updateKitchenStatus(
                              order,
                              KitchenStatus.cooking,
                            ),
                          );

                        case KitchenStatus.cooking:
                          return Row(
                            children: [
                              // Tombol Undo
                              IconButton(
                                tooltip: 'Kembalikan ke Antrean',
                                icon: const Icon(
                                  Icons.undo_rounded,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: () => _updateKitchenStatus(
                                  order,
                                  KitchenStatus.pending,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(
                                    Icons.room_service_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Siap Saji 🛎️',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  onPressed: () => _updateKitchenStatus(
                                    order,
                                    KitchenStatus.ready,
                                  ),
                                ),
                              ),
                            ],
                          );

                        case KitchenStatus.ready:
                          return Row(
                            children: [
                              IconButton(
                                tooltip: 'Kembalikan ke Dimasak',
                                icon: const Icon(
                                  Icons.undo_rounded,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: () => _updateKitchenStatus(
                                  order,
                                  KitchenStatus.cooking,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Selesai Diantar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  onPressed: () => _updateKitchenStatus(
                                    order,
                                    KitchenStatus.served,
                                  ),
                                ),
                              ),
                            ],
                          );

                        case KitchenStatus.served:
                          if (order.status == TransactionStatus.confirmed ||
                              order.status == TransactionStatus.draft) {
                            return Row(
                              children: [
                                IconButton(
                                  tooltip: 'Kembalikan ke Siap Saji',
                                  icon: const Icon(
                                    Icons.undo_rounded,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () => _updateKitchenStatus(
                                    order,
                                    KitchenStatus.ready,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                      Icons.payments_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Bayar di Kasir',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    onPressed: () {
                                      ref.read(cartProvider.notifier).loadOrder(order);
                                      OwnerDashboardNavigation.selectMenu(
                                        ref,
                                        OwnerMenu.transaction,
                                        bootstrap: ref.read(homeBootstrapProvider).value,
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Pesanan ${order.invoiceNumber} dimuat ke Kasir untuk pembayaran'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.undo_rounded, size: 14),
                            label: const Text(
                              'Kembalikan ke Siap Saji',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => _updateKitchenStatus(
                              order,
                              KitchenStatus.ready,
                            ),
                          );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── WIDGET: ITEM ROW ─────────────────────────────────────────────────
  Widget _buildItemRow(TransactionItem item) {
    final hasNotes = item.notes != null && item.notes!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '${item.quantity}x',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Menu Name & Variant
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (item.variantName != null &&
                      item.variantName!.isNotEmpty)
                    Text(
                      item.variantName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        // Item Specific Request Notes (Highlighted)
        if (hasNotes)
          Container(
            margin: const EdgeInsets.only(top: 6, left: 34),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 14,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── PRINT KITCHEN ORDER TICKET (KOT) ─────────────────────────────────
  Future<void> _printKitchenTicket(TransactionOrder order) async {
    final printerService = ref.read(thermalPrinterServiceProvider);
    final printerSettings = await ref.read(printerSettingsProvider.future);

    if (!printerSettings.hasSelectedPrinter && !printerSettings.hasSelectedWindowsPrinter) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.warning,
          style: ToastificationStyle.flat,
          title: const Text('Printer Belum Terhubung'),
          description: const Text(
            'Silakan atur printer di menu Pengaturan -> Pengaturan Printer.',
          ),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return;
    }

    try {
      final isConnected = await printerService.autoConnect(settings: printerSettings);
      if (!isConnected) {
        throw Exception('Printer thermal tidak dapat dijangkau via Bluetooth.');
      }

      // Format teks Kitchen Ticket sederhana
      final buffer = StringBuffer();
      buffer.writeln('================================');
      buffer.writeln('       TIKET DAPUR (KDS)        ');
      buffer.writeln('================================');
      if (order.tableNumber != null) {
        buffer.writeln('MEJA: MEJA ${order.tableNumber}');
      } else {
        buffer.writeln('TIPE: ${order.diningOption.label.toUpperCase()}');
      }
      buffer.writeln('INVOICE: ${order.invoiceNumber}');
      buffer.writeln('JAM: ${_dateFormat.format(order.createdAt ?? DateTime.now())}');
      buffer.writeln('SUMBER: ${order.orderSource.label}');
      buffer.writeln('--------------------------------');
      for (final item in order.items) {
        buffer.writeln('${item.quantity}x ${item.name}');
        if (item.variantName != null && item.variantName!.isNotEmpty) {
          buffer.writeln('   (${item.variantName})');
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          buffer.writeln('   *NOTE: ${item.notes}*');
        }
      }
      buffer.writeln('--------------------------------');
      if (order.notes != null && order.notes!.isNotEmpty) {
        buffer.writeln('CATATAN ORDER: ${order.notes}');
      }
      buffer.writeln('================================\n\n');

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: const Text('Tiket Dapur Dicetak'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Gagal Mencetak Tiket'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }
}
