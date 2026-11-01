import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/core/widgets/barcode_scanner_sheet.dart';
import 'package:dpos/features/subscription/domain/fulfillment_order_model.dart';
import 'package:dpos/features/subscription/presentation/controllers/fulfillment_controller.dart';

/// Item rincian barang untuk keperluan audit & cross-check fisik penerimaan
class AuditManifestItem {
  final String id;
  final String name;
  final num quantity;
  final String unit;
  final String category;
  final String? barcode;
  final double? price;
  bool isChecked;
  DateTime? checkedAt;

  AuditManifestItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.barcode,
    this.price,
    this.isChecked = false,
    this.checkedAt,
  });

  AuditManifestItem copyWith({
    bool? isChecked,
    DateTime? checkedAt,
  }) {
    return AuditManifestItem(
      id: id,
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      barcode: barcode,
      price: price,
      isChecked: isChecked ?? this.isChecked,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}

enum _AuditFilterMode {
  all,
  unverified,
  verified,
}

/// Halaman Audit & Cross-Check Penerimaan Barang Fisik dari Gudang/Kurir
/// Sebelum dimasukkan ke stok produk katalog kasir POS.
class DeliveryAuditScreen extends ConsumerStatefulWidget {
  const DeliveryAuditScreen({
    super.key,
    required this.order,
  });

  final FulfillmentOrder order;

  @override
  ConsumerState<DeliveryAuditScreen> createState() => _DeliveryAuditScreenState();
}

class _DeliveryAuditScreenState extends ConsumerState<DeliveryAuditScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AuditManifestItem> _items = [];
  _AuditFilterMode _currentFilter = _AuditFilterMode.all;
  String _searchQuery = '';
  bool _isConverting = false;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initAuditItems();
    _fetchLiveKitItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Sinkronisasi item fisik dinamis langsung dari retail_starter_kit_items jika paket usaha
  Future<void> _fetchLiveKitItems() async {
    final hasWholesaleNotes = widget.order.notes != null &&
        (widget.order.notes!.trim().startsWith('{') ||
            widget.order.notes!.contains('"wholesale_items"') ||
            widget.order.notes!.contains('"items"'));
    if (hasWholesaleNotes) return; // Jika kulakan satuan, gunakan items dari notes

    try {
      String? kitId = widget.order.starterKitId;
      if (kitId == null && widget.order.kitName.isNotEmpty) {
        final kitRes = await SupabaseService.client
            .from('retail_starter_kits')
            .select('id')
            .ilike('name', '%${widget.order.kitName}%')
            .limit(1)
            .maybeSingle();
        kitId = kitRes?['id'] as String?;
      }

      if (kitId != null) {
        final itemsRes = await SupabaseService.client
            .from('retail_starter_kit_items')
            .select('*')
            .eq('starter_kit_id', kitId);

        if (itemsRes.isNotEmpty) {
          final liveItems = <AuditManifestItem>[];
          for (int i = 0; i < itemsRes.length; i++) {
            final m = itemsRes[i];
            liveItems.add(
              AuditManifestItem(
                id: (m['id'] ?? 'kit_item_$i').toString(),
                name: (m['product_name'] ?? 'Item $i').toString(),
                quantity: (m['quantity'] as num?)?.round() ?? 1,
                unit: (m['unit'] ?? 'Pcs').toString(),
                category: (m['category'] ?? 'Sembako').toString(),
                barcode: m['barcode']?.toString(),
                price: (m['unit_selling_price'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          }

          if (mounted && liveItems.isNotEmpty) {
            setState(() {
              _items = liveItems;
            });
            debugPrint('[DeliveryAuditScreen] Loaded ${liveItems.length} live items from retail_starter_kit_items for kit $kitId');
          }
        }
      }
    } catch (e) {
      debugPrint('[DeliveryAuditScreen] Note fetching live kit items: $e');
    }
  }

  /// Ekstraksi item dari order (notes JSON kulakan satuan atau template paket usaha)
  void _initAuditItems() {
    final list = <AuditManifestItem>[];

    // 1. Ekstrak dari JSON notes jika kulakan satuan
    if (widget.order.notes != null) {
      try {
        final trimmed = widget.order.notes!.trim();
        if (trimmed.startsWith('{') ||
            trimmed.contains('"wholesale_items"') ||
            trimmed.contains('"items"')) {
          final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
          if (parsed['items'] is List) {
            final rawItems = parsed['items'] as List<dynamic>;
            for (int i = 0; i < rawItems.length; i++) {
              final m = rawItems[i] as Map<String, dynamic>;
              list.add(
                AuditManifestItem(
                  id: (m['catalog_id'] ?? 'item_$i').toString(),
                  name: (m['name'] ?? m['product_name'] ?? 'Item Restok $i').toString(),
                  quantity: (m['quantity'] as num?) ?? 1,
                  unit: (m['unit'] ?? 'Pcs').toString(),
                  category: (m['category'] ?? 'Kulakan Satuan').toString(),
                  barcode: m['barcode']?.toString() ?? m['sku']?.toString(),
                  price: (m['price'] as num?)?.toDouble(),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[DeliveryAuditScreen] Error parsing notes: $e');
      }
    }

    // 2. Fallback berdasarkan paket starter kit jika bukan kulakan satuan
    if (list.isEmpty) {
      final nameLower = widget.order.kitName.toLowerCase();
      if (nameLower.contains('toko pemula') || nameLower.contains('paket 01')) {
        list.addAll([
          AuditManifestItem(id: 'brs_01', name: 'Beras Premium 2 kg', quantity: 1, unit: 'Bks', category: 'Sembako', barcode: 'BRS-PRM-2K', price: 32000),
          AuditManifestItem(id: 'myk_01', name: 'Minyak Goreng 1 Liter', quantity: 1, unit: 'Pcs', category: 'Sembako', barcode: 'MYK-GRG-1L', price: 16000),
          AuditManifestItem(id: 'gla_01', name: 'Gula Pasir Kristal 1 kg', quantity: 1, unit: 'Bks', category: 'Sembako', barcode: 'GLA-PSR-1K', price: 17500),
          AuditManifestItem(id: 'tpg_01', name: 'Tepung Terigu 1 kg', quantity: 1, unit: 'Bks', category: 'Sembako', barcode: 'TPG-TRG-1K', price: 12500),
          AuditManifestItem(id: 'mie_01', name: 'Mi Instan Pilihan (Indomie/Sedaap)', quantity: 5, unit: 'Pcs', category: 'Makanan Cepat Saji', barcode: 'MI-INST-5P', price: 3500),
          AuditManifestItem(id: 'kpi_01', name: 'Kopi Sachet Pilihan (10 pcs)', quantity: 10, unit: 'Sachet', category: 'Minuman', barcode: 'KPI-SCH-10', price: 2000),
          AuditManifestItem(id: 'teh_01', name: 'Teh Celup Kotak Pilihan', quantity: 1, unit: 'Kotak', category: 'Minuman', barcode: 'TEH-CLP-01', price: 7000),
          AuditManifestItem(id: 'sbn_01', name: 'Sabun Mandi Batang (2 pcs)', quantity: 2, unit: 'Pcs', category: 'Perawatan Tubuh', barcode: 'SBN-MND-02', price: 4500),
          AuditManifestItem(id: 'cpr_01', name: 'Sabun Cuci Piring Cair 400ml', quantity: 1, unit: 'Pcs', category: 'Kebutuhan Rumah', barcode: 'SBN-CPR-01', price: 8500),
          AuditManifestItem(id: 'dtr_01', name: 'Deterjen Pakaian Bersih 800g', quantity: 1, unit: 'Bks', category: 'Kebutuhan Rumah', barcode: 'DTR-PKN-01', price: 19000),
          AuditManifestItem(id: 'pst_01', name: 'Pasta Gigi Keluarga 120g', quantity: 1, unit: 'Pcs', category: 'Perawatan Tubuh', barcode: 'PST-GGI-01', price: 11000),
          AuditManifestItem(id: 'kcp_01', name: 'Kecap Manis Botol 135ml', quantity: 1, unit: 'Botol', category: 'Bumbu Dapur', barcode: 'KCP-MNS-01', price: 9000),
          AuditManifestItem(id: 'tsu_01', name: 'Tisu Wajah & Perlengkapan Toko', quantity: 1, unit: 'Paket', category: 'Perlengkapan Toko', barcode: 'TSU-KMS-01', price: 15000),
        ]);
      } else if (nameLower.contains('gen z') || nameLower.contains('paket 02')) {
        list.addAll([
          AuditManifestItem(id: 'acc_01', name: 'Phone Charm Kekinian Trendi', quantity: 5, unit: 'Pcs', category: 'Aksesoris HP', barcode: 'ACC-PHC-05', price: 15000),
          AuditManifestItem(id: 'acc_02', name: 'Pop Socket Karakter Viral', quantity: 3, unit: 'Pcs', category: 'Aksesoris HP', barcode: 'ACC-PSK-03', price: 10000),
          AuditManifestItem(id: 'acc_03', name: 'Pelindung Kabel Spiral', quantity: 5, unit: 'Pcs', category: 'Aksesoris HP', barcode: 'ACC-KBL-05', price: 5000),
          AuditManifestItem(id: 'fsh_01', name: 'Scrunchie Rambut Satin Estetik', quantity: 5, unit: 'Pcs', category: 'Fashion', barcode: 'ACC-SCR-05', price: 8000),
          AuditManifestItem(id: 'fsh_02', name: 'Jepit Rambut Korea Doff', quantity: 4, unit: 'Pcs', category: 'Fashion', barcode: 'ACC-JPT-04', price: 9000),
          AuditManifestItem(id: 'mrc_01', name: 'Gantungan Kunci Karakter Akrilik', quantity: 5, unit: 'Pcs', category: 'Merchandise', barcode: 'ACC-GCI-05', price: 12000),
          AuditManifestItem(id: 'stk_01', name: 'Sticker Pack Hologram Vinyl', quantity: 10, unit: 'Pack', category: 'Stationery', barcode: 'STK-HLG-10', price: 6000),
          AuditManifestItem(id: 'fsh_03', name: 'Kaos Kaki Korea Stylish', quantity: 3, unit: 'Pasang', category: 'Fashion', barcode: 'FSH-KSK-03', price: 12000),
          AuditManifestItem(id: 'bag_01', name: 'Mini Canvas Tote Bag Estetik', quantity: 2, unit: 'Pcs', category: 'Fashion', barcode: 'BAG-MIN-02', price: 25000),
          AuditManifestItem(id: 'pch_01', name: 'Mini Makeup Pouch Velvet', quantity: 2, unit: 'Pcs', category: 'Fashion', barcode: 'PCH-VEL-02', price: 18000),
        ]);
      } else if (nameLower.contains('makarizo') || nameLower.contains('beauty') || nameLower.contains('paket 03')) {
        list.addAll([
          AuditManifestItem(id: 'mkz_01', name: 'Makarizo Hair Energy Creambath 500g', quantity: 2, unit: 'Jar', category: 'Perawatan Rambut', barcode: 'MKZ-CRB-500', price: 42000),
          AuditManifestItem(id: 'mkz_02', name: 'Makarizo Scentsations Spray 100ml', quantity: 4, unit: 'Botol', category: 'Perawatan Rambut', barcode: 'MKZ-SCT-100', price: 24000),
          AuditManifestItem(id: 'mkz_03', name: 'Makarizo Fibertherapy Shampoo 170ml', quantity: 3, unit: 'Botol', category: 'Perawatan Rambut', barcode: 'MKZ-SMP-170', price: 28000),
          AuditManifestItem(id: 'mkz_04', name: 'Makarizo Hair Recovery Serum 50ml', quantity: 2, unit: 'Botol', category: 'Perawatan Rambut', barcode: 'MKZ-SRM-050', price: 55000),
          AuditManifestItem(id: 'mkz_05', name: 'Makarizo Straightening Kit 120ml', quantity: 2, unit: 'Set', category: 'Perawatan Rambut', barcode: 'MKZ-STR-120', price: 48000),
          AuditManifestItem(id: 'mkz_06', name: 'Alat Sisir Salon & Display Stand', quantity: 1, unit: 'Set', category: 'Display Toko', barcode: 'MKZ-DSP-001', price: 25000),
        ]);
      } else {
        list.add(
          AuditManifestItem(
            id: 'general_pkg',
            name: widget.order.kitName,
            quantity: 1,
            unit: 'Paket',
            category: 'Paket Lengkap Retail',
            barcode: widget.order.orderCode,
          ),
        );
      }
    }

    _items = list;
  }

  int get _verifiedCount => _items.where((i) => i.isChecked).length;
  bool get _isAllVerified => _items.isNotEmpty && _verifiedCount == _items.length;

  List<AuditManifestItem> get _filteredItems {
    return _items.where((item) {
      // 1. Filter status
      if (_currentFilter == _AuditFilterMode.unverified && item.isChecked) {
        return false;
      }
      if (_currentFilter == _AuditFilterMode.verified && !item.isChecked) {
        return false;
      }

      // 2. Pencarian teks
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = item.name.toLowerCase().contains(q);
        final matchCat = item.category.toLowerCase().contains(q);
        final matchBar = item.barcode?.toLowerCase().contains(q) ?? false;
        return matchName || matchCat || matchBar;
      }

      return true;
    }).toList();
  }

  void _toggleItem(int indexInFiltered) {
    HapticFeedback.lightImpact();
    final target = _filteredItems[indexInFiltered];
    final realIndex = _items.indexWhere((i) => i.id == target.id);
    if (realIndex != -1) {
      setState(() {
        _items[realIndex].isChecked = !_items[realIndex].isChecked;
        _items[realIndex].checkedAt = _items[realIndex].isChecked ? DateTime.now() : null;
      });
    }
  }

  void _toggleCheckAll() {
    HapticFeedback.mediumImpact();
    final willCheckAll = !_isAllVerified;
    setState(() {
      for (final it in _items) {
        it.isChecked = willCheckAll;
        it.checkedAt = willCheckAll ? DateTime.now() : null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willCheckAll
              ? '✓ Semua ${_items.length} barang berhasil dicentang sesuai!'
              : 'Centang semua barang dibatalkan.',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Buka barcode scanner kamera untuk mencocokkan kemasan fisik barang
  Future<void> _openBarcodeScanner() async {
    HapticFeedback.lightImpact();
    final scannedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BarcodeScannerSheet(
        title: 'Scan Barcode Fisik Barang',
        subtitle: 'Arahkan kamera ke barcode kemasan barang kiriman untuk verifikasi otomatis',
      ),
    );

    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) return;
    final code = scannedCode.trim();

    // Cari item yang cocok dengan barcode atau nama
    final matchedIndex = _items.indexWhere((it) {
      if (it.barcode != null && it.barcode!.trim().equalsIgnoreCase(code)) {
        return true;
      }
      if (it.barcode != null && it.barcode!.toLowerCase().contains(code.toLowerCase())) {
        return true;
      }
      return it.name.toLowerCase().contains(code.toLowerCase());
    });

    if (matchedIndex != -1) {
      HapticFeedback.mediumImpact();
      final item = _items[matchedIndex];
      setState(() {
        _items[matchedIndex].isChecked = true;
        _items[matchedIndex].checkedAt = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✓ "${item.name}" terverifikasi via Scan Barcode!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Barcode "$code" tidak ditemukan pada manifes kiriman ini!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Eksekusi konversi ke produk kasir POS setelah audit selesai
  Future<void> _handleConfirmAndConvert() async {
    HapticFeedback.mediumImpact();

    // Jika masih ada barang yang belum dicentang, minta konfirmasi
    if (!_isAllVerified) {
      final unverifiedCount = _items.length - _verifiedCount;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 10),
              Text(
                'Ada Barang Belum Dicek',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            'Masih ada $unverifiedCount barang yang belum dicentang. Apakah Anda yakin ingin menyelesaikan audit dan memasukkan stok ke katalog kasir POS sekarang?',
            style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: const Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cek Kembali',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0070FC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Ya, Lanjutkan Konversi',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }
    if (!mounted) return;

    setState(() => _isConverting = true);

    try {
      // Siapkan payload item yang diverifikasi
      final selectedItems = _items.where((i) => i.isChecked).toList();
      final targetItems = selectedItems.isNotEmpty ? selectedItems : _items;

      final payload = targetItems.map((it) => {
        'name': it.name,
        'quantity': it.quantity.round(),
        'unit': it.unit,
        'category': it.category,
        'barcode': it.barcode,
        'price': (it.price != null && it.price! > 0) ? it.price!.round() : 0,
        'cost_price': (it.price != null && it.price! > 0) ? (it.price! * 0.85).round() : 0,
      }).toList();

      // Jalankan proses update delivered & konversi stok di database
      await FulfillmentController.convertAuditItemsToProducts(
        context: context,
        ref: ref,
        order: widget.order,
        itemsToConvert: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Selesai & Stok Bertambah! 🎉',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${payload.length} produk kiriman berhasil dimasukkan ke katalog kasir POS.',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Gagal menyelesaikan audit: $err'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _items.isEmpty ? 0.0 : (_verifiedCount / _items.length);
    final isComplete = _isAllVerified;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit & Cross-Check Barang',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${widget.order.orderCode} • ${widget.order.kitName}',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          // Tombol Scan Barcode di AppBar
          IconButton(
            tooltip: 'Scan Barcode Produk',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0070FC)),
            onPressed: _openBarcodeScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. Top Inspection Header Card ────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.fact_check_outlined,
                          size: 16,
                          color: Color(0xFF0070FC),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'STATUS VERIFIKASI FISIK:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_verifiedCount / ${_items.length} Barang Sesuai',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isComplete ? const Color(0xFF16A34A) : const Color(0xFF0070FC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Smooth Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? const Color(0xFF16A34A) : const Color(0xFF0070FC),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Action Bar: Check All Button + Quick Scan Button
                Row(
                  children: [
                    // Check All
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isComplete ? const Color(0xFF64748B) : const Color(0xFF0070FC),
                          side: BorderSide(
                            color: isComplete ? const Color(0xFFCBD5E1) : const Color(0xFF93C5FD),
                          ),
                          backgroundColor: isComplete ? const Color(0xFFF8FAFC) : const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        onPressed: _toggleCheckAll,
                        icon: Icon(
                          isComplete ? Icons.remove_done_rounded : Icons.checklist_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isComplete ? 'Batalkan Semua' : 'Centang Semua (${_items.length})',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Scan Barcode
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0070FC),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      ),
                      onPressed: _openBarcodeScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: Text(
                        'Scan Barcode',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 2. Search & Filter Bar ───────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: const Color(0xFFF1F5F9),
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Cari nama barang, kategori, atau barcode...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filter Chips
                Row(
                  children: [
                    _buildFilterChip(
                      label: 'Semua (${_items.length})',
                      mode: _AuditFilterMode.all,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'Belum Dicek (${_items.length - _verifiedCount})',
                      mode: _AuditFilterMode.unverified,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'Sesuai ($_verifiedCount)',
                      mode: _AuditFilterMode.verified,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 3. List of Items (Interactive Checklist) ─────────────
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_off_rounded,
                              size: 36,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak Ada Barang yang Cocok',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coba ubah kata kunci pencarian atau ubah filter status audit.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildAuditItemTile(item, index);
                    },
                  ),
          ),
        ],
      ),

      // ── 4. Bottom Convert to Products Bar ────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Verifikasi:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$_verifiedCount dari ${_items.length} Barang',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isComplete ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  if (isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            '100% Lengkap',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isComplete ? const Color(0xFF16A34A) : const Color(0xFF0070FC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isConverting ? null : _handleConfirmAndConvert,
                  icon: _isConverting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.inventory_2_rounded, size: 18),
                  label: Text(
                    _isConverting
                        ? 'Memproses Stok ke Kasir...'
                        : 'Selesai Audit & Masukkan ke Stok Kasir',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required _AuditFilterMode mode,
  }) {
    final isSelected = _currentFilter == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentFilter = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0070FC) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0070FC) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditItemTile(AuditManifestItem item, int indexInFiltered) {
    return Container(
      decoration: BoxDecoration(
        color: item.isChecked ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isChecked ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: item.isChecked ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _toggleItem(indexInFiltered),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Checkbox Touch Target (Fitts's Law)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.isChecked ? const Color(0xFF16A34A) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isChecked ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: item.isChecked
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),

                // Info Barang
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: item.isChecked ? const Color(0xFF14532D) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              'SKU: ${item.barcode}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Badge Kuantitas & Subtotal
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isChecked ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isChecked ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Text(
                        '${item.quantity} ${item.unit}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: item.isChecked ? const Color(0xFF15803D) : const Color(0xFF0070FC),
                        ),
                      ),
                    ),
                    if (item.price != null && item.price! > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        _currency.format(item.price! * item.quantity),
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
            ),
          ),
        ),
      ),
    );
  }
}

extension _StringExt on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
