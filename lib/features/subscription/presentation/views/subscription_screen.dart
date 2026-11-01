import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';
import 'package:dpos/core/widgets/syupeo_starter_kit_carousel.dart';
import 'package:dpos/features/subscription/domain/starter_kit_model.dart';
import 'package:dpos/features/subscription/presentation/providers/starter_kit_provider.dart';
import 'package:dpos/features/subscription/presentation/views/starter_kit_orders_sheet.dart';

enum _KitViewMode {
  carousel('Tampilan Swipe', Icons.view_carousel_rounded),
  list('Daftar Lengkap', Icons.grid_view_rounded);

  final String label;
  final IconData icon;
  const _KitViewMode(this.label, this.icon);
}

/// ── HALAMAN PAKET USAHA SYUPEO (CLOSED-LOOP SUPPLY CHAIN) ──
/// Menggantikan sistem lisensi SaaS lama dengan katalog paket usaha fisik:
/// 1. Bebas biaya langganan / lisensi software kasir (100% Gratis Seumur Hidup).
/// 2. Menampilkan 4 paket starter kit resmi (@ Rp 200rb) dengan stok fisik barang siap display.
/// 3. Dukungan dua mode tampilan: Parallaks Carousel (seperti onboarding) & Grid/List cards.
/// 4. Akses cepat ke Riwayat Pesanan & Pengiriman Paket (Tracking & Audit Screen).
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  _KitViewMode _viewMode = _KitViewMode.carousel;
  StarterKit? _selectedKit;

  Future<void> _orderViaWhatsApp(StarterKit kit) async {
    HapticFeedback.mediumImpact();
    const phone = '6285624277920';

    final bootstrap = ref.read(homeBootstrapProvider).value;
    final business = bootstrap?.business;
    final outlet = bootstrap?.currentOutlet;

    final formattedPrice = _currencyFormat.format(kit.price);
    final discount = kit.originalPrice != null && kit.originalPrice! > kit.price
        ? _currencyFormat.format(kit.originalPrice! - kit.price)
        : null;

    final message = 'Halo Admin Syupeo, saya ingin pesan Paket Usaha untuk toko saya:\n\n'
        '📦 *Paket:* ${kit.name}\n'
        '🏷️ *Harga Promo:* $formattedPrice ${discount != null ? "(Hemat $discount)" : ""}\n'
        '🏪 *Nama Toko:* ${business?.name ?? "Toko Saya"}\n'
        '🆔 *ID Toko:* ${business?.id ?? "-"}\n'
        '📍 *Alamat Pengiriman:* ${outlet?.address ?? business?.address ?? "-"}\n\n'
        'Mohon info nomor rekening pembayaran dan proses pengiriman dari gudang regional terdekat. Terima kasih!';

    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp. Silakan hubungi 0856-2427-7920.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starterKitsAsync = ref.watch(starterKitsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Paket Usaha',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          // Tombol Buka Riwayat Pesanan Paket
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              StarterKitOrdersSheet.show(context);
            },
            icon: const Icon(
              Icons.local_shipping_rounded,
              size: 18,
              color: Color(0xFF0070FC),
            ),
            label: Text(
              'Riwayat Pesanan',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0070FC),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. HERO BANNER: CLOSED-LOOP SUPPLY CHAIN ──────────────
                  _buildHeroHeader(context),
                  const SizedBox(height: 16),

                  // ── 2. VIEW TOGGLE BAR ─────────────────────────────────────
                  _buildViewSwitcher(),
                  const SizedBox(height: 16),

                  // ── 3. LIST / CAROUSEL PAKET USAHA ────────────────────────
                  starterKitsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: StarterKitCardSkeleton(),
                    ),
                    error: (_, __) => _buildKitsContent(StarterKit.defaultKits),
                    data: (kits) => _buildKitsContent(kits),
                  ),
                  const SizedBox(height: 24),

                  // ── 4. EDUKASI ALUR PASOKAN GUDANG REGIONAL ────────────────
                  _buildSupplyChainGuarantees(theme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Hero Header dengan Akses Cepat Riwayat Pesanan ─────────────────────
  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0070FC).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: const Color(0xFF0070FC).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 13,
                      color: Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SUPPLY CHAIN RESMI SYUPEO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF93C5FD),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Promo @ Rp 200rb',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFDE68A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Katalog Paket Usaha Siap Jual',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Setiap paket sudah mencakup stok fisik barang siap display, aplikasi kasir Syupeo 100% GRATIS seumur hidup, QRIS toko resmi, dan jaminan restok dari gudang regional terdekat.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Baris Tombol Aksi Cepat
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    StarterKitOrdersSheet.show(context);
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 16),
                  label: Text(
                    'Riwayat & Status Kirim',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0070FC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  const phone = '6285624277920';
                  final url = 'https://wa.me/$phone?text=${Uri.encodeComponent('Halo Admin Syupeo, saya ingin konsultasi mengenai pilihan paket usaha retail untuk toko saya.')}';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: Text(
                  'Tanya Admin',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ── Switcher Mode Carousel vs List ───────────────────────────────────────
  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: _KitViewMode.values.map((mode) {
          final isSelected = _viewMode == mode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () {
                if (_viewMode != mode) {
                  HapticFeedback.selectionClick();
                  setState(() => _viewMode = mode);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mode.icon,
                      size: 16,
                      color: isSelected
                          ? const Color(0xFF0070FC)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ── Switcher Konten (Carousel vs List) ────────────────────────────────────
  Widget _buildKitsContent(List<StarterKit> kits) {
    if (kits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Belum ada data paket usaha tersedia.',
            style: GoogleFonts.inter(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    if (_viewMode == _KitViewMode.carousel) {
      return SyupeoStarterKitCarousel(
        kits: kits,
        selectedKitId: _selectedKit?.id,
        onSelectKit: (kit) {
          setState(() => _selectedKit = kit);
        },
        ctaButtonText: 'Pesan Paket Ini via WhatsApp',
        isActionWhatsApp: true,
        onCtaPressed: (kit) => _orderViaWhatsApp(kit),
      );
    }

    // Tampilan Mode List / Grid Responsif
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 490,
            ),
            itemCount: kits.length,
            itemBuilder: (context, index) => _buildPackageCard(kits[index]),
          );
        }

        return Column(
          children: kits.map((kit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPackageCard(kit),
            );
          }).toList(),
        );
      },
    );
  }

  /// ── Kartu Paket Detail Mode List/Grid ─────────────────────────────────────
  Widget _buildPackageCard(StarterKit kit) {
    final discount = kit.originalPrice != null && kit.originalPrice! > kit.price
        ? kit.originalPrice! - kit.price
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: kit.isPopular ? const Color(0xFF0070FC) : const Color(0xFFE2E8F0),
          width: kit.isPopular ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge Notch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kit.isPopular
                  ? const Color(0xFF0070FC)
                  : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg - 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kit.badge ?? 'PAKET RESMI SYUPEO',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kit.isPopular ? Colors.white : const Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (kit.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'BEST SELLER',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Paket
                Text(
                  kit.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (kit.suitableFor != null && kit.suitableFor!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          kit.suitableFor!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Harga
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _currencyFormat.format(kit.price),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0070FC),
                      ),
                    ),
                    if (kit.originalPrice != null && kit.originalPrice! > kit.price) ...[
                      const SizedBox(width: 8),
                      Text(
                        _currencyFormat.format(kit.originalPrice),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    if (discount != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Hemat ${_currencyFormat.format(discount)}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Deskripsi
                if (kit.description != null && kit.description!.isNotEmpty)
                  Text(
                    kit.description!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Kelengkapan Item
                Text(
                  'Item & Fasilitas Termasuk (${kit.itemsIncluded.length} item):',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                ...kit.itemsIncluded.take(5).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF1E293B),
                              height: 1.35,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (kit.itemsIncluded.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+ ${kit.itemsIncluded.length - 5} item pelengkap lainnya',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0070FC),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                // Tombol Pesan via WhatsApp
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _orderViaWhatsApp(kit),
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: Text(
                      'Pesan Paket via WhatsApp',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070FC),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  /// ── Edukasi Ekosistem Supply Chain Syupeo ─────────────────────────────────
  Widget _buildSupplyChainGuarantees(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: Color(0xFF0070FC),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaminan Kemitraan Toko Syupeo',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Bagaimana paket usaha bekerja langsung di kasir Anda',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuaranteeStep(
            number: '1',
            title: 'Pilih & Pesan Paket Usaha',
            description:
                'Tentukan paket awal sesuai segmen pasar konsumen Anda (Sembako, Aksesori Gen Z, Produk Kecantikan, atau Air Galon).',
          ),
          const SizedBox(height: 12),
          _buildGuaranteeStep(
            number: '2',
            title: 'Pengemasan & Kirim dari Gudang Regional',
            description:
                'Gudang regional Syupeo mengemas stok fisik barang dan mengirimkan langsung ke alamat toko Anda lengkap dengan surat jalan dan nomor resi pengiriman.',
          ),
          const SizedBox(height: 12),
          _buildGuaranteeStep(
            number: '3',
            title: 'Audit & Cross-Check Barang di Kasir',
            description:
                'Saat paket sampai di toko, kasir melakukan verifikasi fisik via halaman audit. Sekali konfirmasi, seluruh barang otomatis terkonversi menjadi master produk siap jual.',
          ),
          const SizedBox(height: 12),
          _buildGuaranteeStep(
            number: '4',
            title: 'Aplikasi Kasir POS 100% Gratis & Restok Rutin',
            description:
                'Seluruh fitur aplikasi kasir, QRIS kasir, dan analitik laporan bisnis tersedia gratis seumur hidup tanpa biaya langganan software. Toko dapat pesan restok berkala melalui menu Restok Gudang.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0070FC).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0070FC),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
