import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dpos/features/customer_ordering/data/customer_ordering_repository.dart';
import 'package:dpos/features/customer_ordering/state/customer_cart_state.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
const _desktopCustomerShellBreakpoint = 560.0;
const _customerShellWidth = 430.0;

enum _CustomerOrderSection { menu, history }

class CustomerOrderScreen extends ConsumerStatefulWidget {
  const CustomerOrderScreen({
    super.key,
    required this.outletId,
    required this.tableId,
  });

  final String outletId;
  final String tableId;

  @override
  ConsumerState<CustomerOrderScreen> createState() =>
      _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends ConsumerState<CustomerOrderScreen> {
  String? _selectedCategoryId;
  final _searchController = TextEditingController();
  _CustomerOrderSection _selectedSection = _CustomerOrderSection.menu;

  CustomerOrderHistoryArgs get _historyArgs =>
      (outletId: widget.outletId, tableId: widget.tableId);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outletAsync = ref.watch(customerOutletProvider(widget.outletId));

    final content = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(outletAsync.valueOrNull),
      body: outletAsync.when(
        data: (outlet) {
          if (outlet == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Outlet dengan ID ${widget.outletId} tidak ditemukan'),
                ],
              ),
            );
          }
          return _buildContent(context, outlet);
        },
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat informasi outlet...'),
            ],
          ),
        ),
        error: (e, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SelectableText(
              'Gagal memuat outlet: $e\n\nID: ${widget.outletId}',
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selectedSection == _CustomerOrderSection.menu
          ? _buildBottomBar()
          : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _desktopCustomerShellBreakpoint) {
          return content;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFE2E8F0),
          body: SafeArea(
            minimum: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, shellConstraints) {
                return Center(
                  child: Container(
                    width: _customerShellWidth,
                    height: shellConstraints.maxHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, Outlet outlet) {
    return _selectedSection == _CustomerOrderSection.menu
        ? _buildMenuContent(context, outlet)
        : _buildHistoryContent(context, outlet);
  }

  Widget _buildMenuContent(BuildContext context, Outlet outlet) {
    final menuAsync = ref.watch(customerMenuProvider(outlet.businessId));
    final historyAsync = ref.watch(customerOrderHistoryProvider(_historyArgs));

    return CustomScrollView(
      slivers: [
        _buildAppBar(outlet),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, Selamat Datang! 👋',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mau pesan apa hari ini?',
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSearchBar(),
                _SharedQrCartSummary(
                  historyAsync: historyAsync,
                  onOpenHistory: () {
                    _switchSection(_CustomerOrderSection.history);
                    _refreshHistory();
                  },
                ),
              ],
            ),
          ),
        ),
        menuAsync.when(
          data: (items) {
            final categories = _extractCategories(items);
            return SliverMainAxisGroup(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryHeaderDelegate(
                    categories: categories,
                    selectedId: _selectedCategoryId,
                    onSelect: (id) => setState(() => _selectedCategoryId = id),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: _buildProductGrid(items),
                ),
              ],
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              SliverFillRemaining(child: Center(child: Text('Error: $e'))),
        ),
      ],
    );
  }

  Widget _buildHistoryContent(BuildContext context, Outlet outlet) {
    final historyAsync = ref.watch(customerOrderHistoryProvider(_historyArgs));

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(outlet),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riwayat Pesanan',
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice aktif dari QR ini akan tampil di sini dan bisa dilihat bareng.',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh riwayat',
                    onPressed: _refreshHistory,
                    icon: const Icon(Icons.refresh_rounded),
                    color: const Color(0xFF1E293B),
                  ),
                ],
              ),
            ),
          ),
          historyAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 72,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada riwayat pesanan',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Setelah kamu kirim order, statusnya akan tampil di sini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _switchSection(_CustomerOrderSection.menu),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.restaurant_menu_rounded),
                            label: const Text('Mulai Pesan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final order = orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CustomerHistoryCard(order: order),
                    );
                  }, childCount: orders.length),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 72,
                        color: Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Riwayat gagal dimuat',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$e',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Outlet outlet) {
    final isHistory = _selectedSection == _CustomerOrderSection.history;
    final headline = isHistory ? 'Riwayat Pesanan' : outlet.name;
    final subtitle = isHistory
        ? '${outlet.name} • Meja ${widget.tableId}'
        : 'Meja ${widget.tableId}';

    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: 70,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            Builder(
              builder: (context) {
                return IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(Outlet? outlet) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outlet?.name ?? 'Customer Web',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meja ${widget.tableId}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _CustomerDrawerItem(
              title: 'Menu',
              subtitle: 'Lihat dan pilih makanan',
              icon: Icons.restaurant_menu_rounded,
              selected: _selectedSection == _CustomerOrderSection.menu,
              onTap: () {
                Navigator.pop(context);
                _switchSection(_CustomerOrderSection.menu);
              },
            ),
            _CustomerDrawerItem(
              title: 'Riwayat Pesanan',
              subtitle: 'Cek status order yang sudah dikirim',
              icon: Icons.receipt_long_rounded,
              selected: _selectedSection == _CustomerOrderSection.history,
              onTap: () {
                Navigator.pop(context);
                _switchSection(_CustomerOrderSection.history);
                _refreshHistory();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Gunakan drawer ini untuk pindah antara menu dan riwayat pesanan.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Cari menu favoritmu...',
          hintStyle: GoogleFonts.manrope(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF64748B),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<MenuItem> items) {
    var filtered = items;
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((i) => i.categoryId == _selectedCategoryId)
          .toList();
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((i) => i.name.toLowerCase().contains(query))
          .toList();
    }

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 16),
              Text(
                'Menu tidak ditemukan',
                style: GoogleFonts.manrope(color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _ProductCard(item: filtered[index]),
        childCount: filtered.length,
      ),
    );
  }

  Widget _buildBottomBar() {
    final cart = ref.watch(customerCartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _showCartSheet(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF98B35),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${cart.totalCount}',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Lihat Pesanan',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _currency.format(cart.subtotal),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCartSheet() {
    final useDesktopShell =
        MediaQuery.sizeOf(context).width >= _desktopCustomerShellBreakpoint;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sheet = _CartBottomSheet(
          outletId: widget.outletId,
          tableId: widget.tableId,
          onSubmitted: _handleOrderSubmitted,
        );
        if (!useDesktopShell) {
          return sheet;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _customerShellWidth),
              child: sheet,
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleOrderSubmitted(BuildContext sheetContext) async {
    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    ref.read(customerCartProvider.notifier).clear();
    await showOrderHistory();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pesanan berhasil dikirim. Statusnya sekarang ada di Riwayat Pesanan.',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, String>> _extractCategories(List<MenuItem> items) {
    final categoriesMap = <String, String>{};
    for (final item in items) {
      if (item.category != null) {
        categoriesMap[item.category!.id] = item.category!.name;
      }
    }
    return categoriesMap.entries
        .map((e) => {'id': e.key, 'name': e.key == '' ? 'Semua' : e.value})
        .toList();
  }

  void _switchSection(_CustomerOrderSection section) {
    if (_selectedSection == section) {
      return;
    }
    setState(() => _selectedSection = section);
  }

  Future<void> _refreshHistory() async {
    final provider = customerOrderHistoryProvider(_historyArgs);
    ref.invalidate(provider);
    await ref.read(provider.future);
  }

  Future<void> showOrderHistory() async {
    if (_selectedSection != _CustomerOrderSection.history) {
      setState(() => _selectedSection = _CustomerOrderSection.history);
    }
    await _refreshHistory();
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Map<String, String>> categories;
  final String? selectedId;
  final Function(String?) onSelect;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final id = isAll ? null : categories[index - 1]['id'];
          final name = isAll ? 'Semua' : categories[index - 1]['name']!;
          final isSelected = selectedId == id;

          return GestureDetector(
            onTap: () => onSelect(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF98B35) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF98B35)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 60;
  @override
  double get minExtent => 60;
  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) =>
      oldDelegate.selectedId != selectedId ||
      oldDelegate.categories != categories;
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                image: item.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(item.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.imageUrl == null
                  ? const Icon(
                      Icons.fastfood_rounded,
                      color: Color(0xFFCBD5E1),
                      size: 40,
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(item.price),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF98B35),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(customerCartProvider.notifier).addItem(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.name} ditambahkan'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tambah',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBottomSheet extends ConsumerWidget {
  const _CartBottomSheet({
    required this.outletId,
    required this.tableId,
    required this.onSubmitted,
  });

  final String outletId;
  final String tableId;
  final Future<void> Function(BuildContext context) onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(customerCartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Pesanan Saya',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(customerCartProvider.notifier).clear(),
                child: Text(
                  'Hapus Semua',
                  style: GoogleFonts.manrope(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            _currency.format(item.unitPrice),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _QtyBtn(
                          icon: Icons.remove,
                          onTap: () => ref
                              .read(customerCartProvider.notifier)
                              .updateQuantity(item.id, item.quantity - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${item.quantity}',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _QtyBtn(
                          icon: Icons.add,
                          onTap: () => ref
                              .read(customerCartProvider.notifier)
                              .updateQuantity(item.id, item.quantity + 1),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                _currency.format(cart.subtotal),
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cart.isSaving ? null : () => _submit(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: cart.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Pesan Sekarang',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context);
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !context.mounted) {
      return;
    }

    final outletAsync = ref.read(customerOutletProvider(outletId));
    final outlet = outletAsync.value;
    if (outlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outlet belum siap. Coba lagi sebentar.')),
      );
      return;
    }

    final success = await ref
        .read(customerCartProvider.notifier)
        .submitOrder(
          outletId: outlet.id,
          tableId: tableId,
          customerName: trimmedName,
        );

    if (success) {
      if (context.mounted) {
        await onSubmitted(context);
      }
    } else {
      if (context.mounted) {
        final error = ref.read(customerCartProvider).error;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memesan: $error')));
      }
    }
  }

  Future<String?> _showNameDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Data Pemesan',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Masukkan nama Anda'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
      ),
    );
  }
}

class _CustomerDrawerItem extends StatelessWidget {
  const _CustomerDrawerItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected ? const Color(0xFFFFEDD5) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(
            icon,
            color: selected ? const Color(0xFFF97316) : const Color(0xFF475569),
          ),
          title: Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedQrCartSummary extends StatelessWidget {
  const _SharedQrCartSummary({
    required this.historyAsync,
    required this.onOpenHistory,
  });

  final AsyncValue<List<TransactionOrder>> historyAsync;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return historyAsync.maybeWhen(
      data: (orders) {
        final activeOrder = _findActiveSharedOrder(orders);
        if (activeOrder == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFFEDD5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: Color(0xFFF97316),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cart QR bersama',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF9A3412),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activeOrder.invoiceNumber} • ${activeOrder.totalItemCount} item • ${_currency.format(activeOrder.grandTotal)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7C2D12),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onOpenHistory,
                  child: Text(
                    'Lihat',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  TransactionOrder? _findActiveSharedOrder(List<TransactionOrder> orders) {
    for (final order in orders) {
      if (order.orderSource == OrderSource.qrSelfOrder &&
          order.status == TransactionStatus.confirmed &&
          order.paidAt == null) {
        return order;
      }
    }
    return null;
  }
}

class _CustomerHistoryCard extends StatelessWidget {
  const _CustomerHistoryCard({required this.order});

  final TransactionOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(order.status);
    final isActiveSharedOrder =
        order.orderSource == OrderSource.qrSelfOrder &&
        order.status == TransactionStatus.confirmed &&
        order.paidAt == null;
    final itemPreview = isActiveSharedOrder
        ? order.items
        : order.items.take(3).toList();
    final extraItemCount = isActiveSharedOrder
        ? 0
        : order.items.length - itemPreview.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.invoiceNumber,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatOrderMeta(order),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status.label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (order.customerName != null && order.customerName!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Atas nama ${order.customerName}',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...itemPreview.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}x',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.displayName,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (extraItemCount > 0)
                  Text(
                    '+$extraItemCount item lainnya',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currency.format(order.grandTotal),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                isActiveSharedOrder
                    ? 'Invoice aktif QR ini'
                    : _statusDescription(order.status),
                textAlign: TextAlign.right,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.draft => const Color(0xFF9333EA),
      TransactionStatus.confirmed => const Color(0xFF2563EB),
      TransactionStatus.paid => const Color(0xFF15803D),
      TransactionStatus.partialPaid => const Color(0xFFD97706),
      TransactionStatus.void_ => const Color(0xFFDC2626),
      TransactionStatus.refunded => const Color(0xFF475569),
    };
  }

  static String _statusDescription(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.draft => 'Masih draft',
      TransactionStatus.confirmed => 'Menunggu diproses outlet',
      TransactionStatus.paid => 'Pesanan sudah selesai dibayar',
      TransactionStatus.partialPaid => 'Sebagian pembayaran sudah masuk',
      TransactionStatus.void_ => 'Pesanan dibatalkan',
      TransactionStatus.refunded => 'Pesanan direfund',
    };
  }

  static String _formatOrderMeta(TransactionOrder order) {
    final parts = <String>[];
    if (order.createdAt != null) {
      parts.add(
        DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.createdAt!),
      );
    }
    if (order.tableNumber != null) {
      parts.add('Meja ${order.tableNumber}');
    }
    parts.add('${order.totalItemCount} item');
    return parts.join(' • ');
  }
}
