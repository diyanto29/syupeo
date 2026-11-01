import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/features/auth/domain/auth_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/subscription/domain/starter_kit_model.dart';
import 'package:dpos/features/subscription/domain/wholesale_item_model.dart';
import 'package:dpos/features/subscription/presentation/providers/fulfillment_orders_provider.dart';
import 'package:dpos/features/subscription/presentation/providers/starter_kit_provider.dart';
import 'package:dpos/features/subscription/presentation/providers/wholesale_catalog_provider.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class RestockCatalogScreen extends ConsumerStatefulWidget {
  const RestockCatalogScreen({super.key});

  @override
  ConsumerState<RestockCatalogScreen> createState() =>
      _RestockCatalogScreenState();
}

class _RestockCatalogScreenState extends ConsumerState<RestockCatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _wholesaleScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> _cart = {}; // itemId -> qty
  final Map<String, WholesaleItem> _cartItems = {}; // itemId -> WholesaleItem
  bool _isSubmitting = false;

  static const String _csWhatsApp = '6285624277920';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _wholesaleScrollController.addListener(_onWholesaleScroll);
  }

  void _onWholesaleScroll() {
    if (!_wholesaleScrollController.hasClients) return;
    final maxScroll = _wholesaleScrollController.position.maxScrollExtent;
    final currentScroll = _wholesaleScrollController.position.pixels;
    if (currentScroll >= maxScroll - 250) {
      ref.read(wholesaleCatalogProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wholesaleScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalCartItems =>
      _cart.values.fold(0, (sum, qty) => sum + qty);

  int get _totalCartPrice {
    int total = 0;
    _cart.forEach((itemId, qty) {
      final item = _cartItems[itemId];
      if (item != null) {
        total += item.wholesalePrice * qty;
      }
    });
    return total;
  }

  void _setItemQuantity(WholesaleItem item, int qty) {
    setState(() {
      if (qty <= 0) {
        _cart.remove(item.id);
        _cartItems.remove(item.id);
      } else {
        _cart[item.id] = qty;
        _cartItems[item.id] = item;
      }
    });
  }

  Future<void> _orderStarterKitDirect(StarterKit kit) async {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final business = bootstrap?.business;
    final outlet = bootstrap?.currentOutlet;
    final profile = bootstrap?.profile;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: Color(0xFF0070FC)),
            const SizedBox(width: 8),
            const Text('Pesan Restok Paket'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan memesan paket:',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              kit.name,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              _currencyFormat.format(kit.price),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0070FC),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tujuan Pengiriman Toko:',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${outlet?.name ?? business?.name ?? 'Toko Anda'} • ${outlet?.address ?? business?.address ?? 'Alamat toko'}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0070FC),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi Pesan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _submitRestockOrder(
      orderName: kit.name,
      totalPrice: kit.price,
      notes: 'Pemesanan Paket Restok: ${kit.name}',
      business: business,
      outlet: outlet,
      profile: profile,
    );
  }

  Future<void> _checkoutWholesaleCart() async {
    if (_cart.isEmpty) return;

    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final business = bootstrap?.business;
    final outlet = bootstrap?.currentOutlet;
    final profile = bootstrap?.profile;

    final itemsSummary = _cart.entries.map((e) {
      final item = _cartItems[e.key];
      final name = item?.name ?? 'Item ${e.key}';
      final unit = item?.unit ?? 'pcs';
      return '$name (${e.value} $unit)';
    }).join(', ');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF0070FC)),
            const SizedBox(width: 8),
            const Text('Konfirmasi Kulakan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Item: $_totalCartItems barang',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
            ),
            Text(
              _currencyFormat.format(_totalCartPrice),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0070FC),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  itemsSummary,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0070FC),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim Order ke Gudang'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final cartItemsList = _cart.entries.map((e) {
      final item = _cartItems[e.key];
      return {
        'catalog_id': e.key,
        'name': item?.name ?? 'Produk Kulakan',
        'category': item?.category ?? 'Sembako',
        'barcode': item?.barcode,
        'price': item?.suggestedRetailPrice ?? 0,
        'cost_price': item?.wholesalePrice ?? 0,
        'quantity': e.value,
        'unit': item?.unit ?? 'Pcs',
      };
    }).toList();

    final notesPayload = jsonEncode({
      'summary': itemsSummary,
      'type': 'wholesale_items',
      'items': cartItemsList,
    });

    await _submitRestockOrder(
      orderName: 'Kulakan Satuan ($_totalCartItems item)',
      totalPrice: _totalCartPrice,
      notes: notesPayload,
      business: business,
      outlet: outlet,
      profile: profile,
    );

    setState(() {
      _cart.clear();
      _cartItems.clear();
    });
  }

  Future<void> _submitRestockOrder({
    required String orderName,
    required int totalPrice,
    required String notes,
    Business? business,
    Outlet? outlet,
    AppProfile? profile,
  }) async {
    setState(() => _isSubmitting = true);
    final orderCode =
        'RST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final recipientName =
        outlet?.name ?? business?.name ?? profile?.fullName ?? 'Toko Mitra';
    final recipientPhone =
        outlet?.phone ?? business?.phone ?? profile?.phone ?? '';
    final shippingAddress =
        outlet?.address ?? business?.address ?? 'Alamat toko mitra';
    final shippingCity = outlet?.address?.split(',').lastOrNull?.trim() ?? 'Indramayu';

    try {
      await SupabaseService.client.from('package_fulfillment_orders').insert({
        'order_code': orderCode,
        'kit_name': orderName,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'shipping_address': shippingAddress,
        'shipping_city': shippingCity,
        'fulfillment_mode': 'agent_direct',
        'status': 'pending_dispatch',
        'notes': notes,
      });

      ref.invalidate(fulfillmentOrdersProvider);

      if (!mounted) return;

      // Sukses: Buka WhatsApp otomatis untuk info konfirmasi
      final waMsg =
          'Halo Admin Gudang Syupeo! Saya baru saja membuat order restok toko:\n'
          '• No. Order: $orderCode\n'
          '• Paket/Barang: $orderName\n'
          '• Total: ${_currencyFormat.format(totalPrice)}\n'
          '• Toko: $recipientName ($recipientPhone)\n'
          '• Alamat: $shippingAddress\n\n'
          'Mohon diproses untuk pengiriman barang ke toko saya. Terima kasih!';

      final waUri = Uri.parse(
        'https://wa.me/$_csWhatsApp?text=${Uri.encodeComponent(waMsg)}',
      );

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              const Text('Pesanan Diterima!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesanan restok Anda dengan kode $orderCode berhasil dibuat dan telah masuk ke sistem Gudang Syupeo.',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Tim Gudang akan segera menyiapkan pesanan dan mengirimkannya ke toko Anda.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(ownerSelectedMenuProvider.notifier).state =
                    OwnerMenu.starterKitOrder;
              },
              child: const Text('Lihat Status Kirim'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (await canLaunchUrl(waUri)) {
                  await launchUrl(waUri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Chat Admin WA'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat pesanan restok: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final starterKitsAsync = ref.watch(starterKitsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Katalog Restok & Kulakan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Pasokan barang resmi dari Gudang Syupeo',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0070FC),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0070FC),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Paket Starter Kit (@ Rp 200rb)'),
            Tab(text: 'Kulakan Satuan (Pilih Satu-Satu)'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Starter Kits Bundling
              starterKitsAsync.when(
                data: (kits) => _buildStarterKitsTab(kits),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildStarterKitsTab(StarterKit.defaultKits),
              ),

              // TAB 2: Custom Wholesale Items
              _buildWholesaleItemsTab(),
            ],
          ),

          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _tabController.index == 1 && _cart.isNotEmpty
          ? _buildWholesaleBottomBar()
          : null,
    );
  }

  Widget _buildStarterKitsTab(List<StarterKit> kits) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: kits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final kit = kits[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (kit.badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              kit.badge!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          kit.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (kit.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            kit.description!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(kit.price),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0070FC),
                        ),
                      ),
                      Text(
                        'per paket siap display',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Text(
                'Isi Stok & Fasilitas:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              ...kit.itemsIncluded.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0070FC),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _orderStarterKitDirect(kit),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(
                    'Pesan Paket Ini',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWholesaleItemsTab() {
    final state = ref.watch(wholesaleCatalogProvider);

    return Column(
      children: [
        // Search & Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(wholesaleCatalogProvider.notifier).setSearchQuery(val);
                },
                decoration: InputDecoration(
                  hintText: 'Cari produk kulakan dari database (nama, barcode, brand)...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0070FC)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(wholesaleCatalogProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: state.categories.map((cat) {
                    final isSel = state.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(cat),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? const Color(0xFF0070FC) : const Color(0xFF475569),
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFEFF6FF),
                        side: BorderSide(
                          color: isSel ? const Color(0xFF0070FC) : const Color(0xFFE2E8F0),
                        ),
                        onSelected: (_) {
                          ref.read(wholesaleCatalogProvider.notifier).setCategory(cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Items List with Lazy Loading & Pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF0070FC),
            onRefresh: () => ref.read(wholesaleCatalogProvider.notifier).refresh(),
            child: _buildWholesaleContent(state),
          ),
        ),
      ],
    );
  }

  Widget _buildWholesaleContent(WholesaleCatalogState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0070FC)),
            SizedBox(height: 12),
            Text(
              'Memuat katalog produk kulakan dari database...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 12),
              Text(
                'Gagal Memuat Produk',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0070FC)),
                onPressed: () => ref.read(wholesaleCatalogProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Produk Tidak Ditemukan',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.searchQuery.isNotEmpty
                    ? 'Tidak ada produk yang cocok dengan pencarian "${state.searchQuery}".'
                    : 'Belum ada produk kulakan di kategori ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  ref.read(wholesaleCatalogProvider.notifier).setSearchQuery('');
                  ref.read(wholesaleCatalogProvider.notifier).setCategory('Semua');
                },
                child: const Text('Reset Filter & Kategori'),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = state.items.length;
    final hasMore = state.hasMore;

    return ListView.separated(
      controller: _wholesaleScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: totalCount + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= totalCount) {
          // Bottom Lazy Loading Indicator
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0070FC),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Memuat produk berikutnya...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        final item = state.items[index];
        final qty = _cart[item.id] ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: qty > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
              width: qty > 0 ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(item.icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _currencyFormat.format(item.wholesalePrice),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0070FC),
                          ),
                        ),
                        Text(
                          ' / ${item.unit}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        if (item.brand != null && item.brand!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.brand!,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saran Jual: ${_currencyFormat.format(item.suggestedRetailPrice)} (Untung ${_currencyFormat.format(item.profit)})',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    if (item.wholesaleUnit != null && item.conversionRatio != null && item.conversionRatio! > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tersedia juga per ${item.wholesaleUnit} (isi ${item.conversionRatio})',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Stepper Counter
              Row(
                children: [
                  if (qty > 0) ...[
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: const Color(0xFFEF4444),
                      onPressed: () => _setItemQuantity(item, qty - 1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$qty',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded),
                    color: const Color(0xFF0070FC),
                    onPressed: () => _setItemQuantity(item, qty + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWholesaleBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_totalCartItems Barang Dipilih',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(_totalCartPrice),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0070FC),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0070FC),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _checkoutWholesaleCart,
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
              label: Text(
                'Pesan Kulakan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
