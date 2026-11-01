import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/discount_management/data/discount_repository.dart';
import 'package:dpos/features/discount_management/data/promo_repository.dart';
import 'package:dpos/features/discount_management/domain/discount_models.dart';
import 'package:dpos/features/discount_management/domain/promo_models.dart';
import 'package:dpos/features/discount_management/presentation/views/discount_editor_page.dart';
import 'package:dpos/features/discount_management/presentation/widgets/promo_editor_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PromoTypeFilter {
  all,
  bxgy,
  tebusMurah,
  regularDiscount,
}

class DiscountManagementScreen extends ConsumerStatefulWidget {
  const DiscountManagementScreen({super.key});

  @override
  ConsumerState<DiscountManagementScreen> createState() =>
      _DiscountManagementScreenState();
}

class _DiscountManagementScreenState
    extends ConsumerState<DiscountManagementScreen> {
  final _searchController = TextEditingController();
  PromoTypeFilter _selectedFilter = PromoTypeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── NAVIGATION TO FULL PAGES (NOT BOTTOM SHEETS) ──────────────────────────

  Future<void> _openDiscountEditor({DiscountDefinition? initialDiscount}) async {
    if (!ref.read(canManageCatalogProvider)) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiscountEditorPage(initialDiscount: initialDiscount),
      ),
    );

    if (!mounted || changed != true) return;
    final actionLabel = initialDiscount == null ? 'ditambahkan' : 'diperbarui';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Diskon berhasil $actionLabel.')),
    );
  }

  Future<void> _openBxgyEditor({BuyXGetYPromo? initialPromo}) async {
    if (!ref.read(canManageCatalogProvider)) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BuyXGetYEditorPage(initialPromo: initialPromo),
      ),
    );

    if (!mounted || changed != true) return;
    final actionLabel = initialPromo == null ? 'ditambahkan' : 'diperbarui';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Promo Beli X Gratis Y berhasil $actionLabel.')),
    );
  }

  Future<void> _openTebusMurahEditor({TebusMurahPromo? initialPromo}) async {
    if (!ref.read(canManageCatalogProvider)) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TebusMurahEditorPage(initialPromo: initialPromo),
      ),
    );

    if (!mounted || changed != true) return;
    final actionLabel = initialPromo == null ? 'ditambahkan' : 'diperbarui';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Promo Tebus Murah berhasil $actionLabel.')),
    );
  }

  // ── QUICK ADD PICKER MODAL ────────────────────────────────────────────────

  void _showAddPromoPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih Jenis Penawaran',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih skema promo yang ingin kamu buat untuk toko:',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 20),
                _buildPickerOption(
                  ctx: ctx,
                  title: 'Beli X Gratis Y (BXGY)',
                  desc: 'Beli produk tertentu gratis produk sama atau beda menu.',
                  icon: Icons.card_giftcard_rounded,
                  color: const Color(0xFFE11D48),
                  bgColor: const Color(0xFFFFF1F2),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openBxgyEditor();
                  },
                ),
                const SizedBox(height: 12),
                _buildPickerOption(
                  ctx: ctx,
                  title: 'Tebus Murah (Add-on / PWP)',
                  desc: 'Harga miring setelah min. belanja atau beli menu pemicu.',
                  icon: Icons.shopping_bag_outlined,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEEF2FF),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openTebusMurahEditor();
                  },
                ),
                const SizedBox(height: 12),
                _buildPickerOption(
                  ctx: ctx,
                  title: 'Diskon & Potongan Harga',
                  desc: 'Potongan persen (%), nominal (Rp), atau voucher belanja.',
                  icon: Icons.local_offer_outlined,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openDiscountEditor();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required BuildContext ctx,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  // ── DELETION HELPERS ──────────────────────────────────────────────────────

  Future<void> _deleteDiscount(DiscountDefinition discount) async {
    if (!ref.read(canManageCatalogProvider)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Diskon'),
        content: Text('Diskon "${discount.name}" akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ref.read(discountsProvider.notifier).deleteDiscount(discount.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diskon "${discount.name}" dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus diskon: $e')),
        );
      }
    }
  }

  Future<void> _deleteBxgyPromo(BuyXGetYPromo promo) async {
    if (!ref.read(canManageCatalogProvider)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Promo Beli X Gratis Y'),
        content: Text('Promo "${promo.name}" akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ref.read(buyXGetYPromosProvider.notifier).deletePromo(promo.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promo "${promo.name}" dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus promo: $e')),
        );
      }
    }
  }

  Future<void> _deleteTebusMurahPromo(TebusMurahPromo promo) async {
    if (!ref.read(canManageCatalogProvider)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Promo Tebus Murah'),
        content: Text('Promo "${promo.name}" akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ref.read(tebusMurahPromosProvider.notifier).deletePromo(promo.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promo "${promo.name}" dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus promo: $e')),
        );
      }
    }
  }

  // ── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 760;
    final canManage = ref.watch(canManageCatalogProvider);

    final discountsAsync = ref.watch(discountsProvider);
    final bxgyAsync = ref.watch(buyXGetYPromosProvider);
    final tebusAsync = ref.watch(tebusMurahPromosProvider);

    final discounts = discountsAsync.value ?? const <DiscountDefinition>[];
    final bxgyPromos = bxgyAsync.value ?? const <BuyXGetYPromo>[];
    final tebusPromos = tebusAsync.value ?? const <TebusMurahPromo>[];

    final activeBxgyCount = bxgyPromos.where((p) => p.isCurrentlyActive()).length;
    final activeTebusCount = tebusPromos.where((p) => p.isCurrentlyActive()).length;
    final activeDiscountCount = discounts.where((d) => d.isAvailableNow).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: const Text('Program Promo & Diskon'),
              badge: const AppTabletBadge(label: 'Syupeo'),
              actions: [
                IconButton(
                  tooltip: 'Segarkan data',
                  onPressed: () {
                    ref.read(discountsProvider.notifier).refresh();
                    ref.read(buyXGetYPromosProvider.notifier).refresh();
                    ref.read(tebusMurahPromosProvider.notifier).refresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : AppBar(
              title: const Text('Program Promo & Diskon'),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Segarkan data',
                  onPressed: () {
                    ref.read(discountsProvider.notifier).refresh();
                    ref.read(buyXGetYPromosProvider.notifier).refresh();
                    ref.read(tebusMurahPromosProvider.notifier).refresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(discountsProvider.notifier).refresh(),
              ref.read(buyXGetYPromosProvider.notifier).refresh(),
              ref.read(tebusMurahPromosProvider.notifier).refresh(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 16,
              16,
              isTablet ? 24 : 16,
              100, // extra bottom padding for floating action button
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SECTION: PROGRAM PROMO & DISKON (3 SKEMA)
                _buildSectionHeader(
                  title: 'Program Promo & Diskon',
                  subtitle: 'Tingkatkan penjualan dengan skema penawaran menarik',
                  badgeText: '3 Skema',
                ),
                const SizedBox(height: 14),

                // CARD 1: BELI X GRATIS Y (BXGY) - Red/Rose Gradient
                _buildSchemeCard(
                  title: 'Beli X Gratis Y (BXGY)',
                  badgeLabel: activeBxgyCount > 0 ? 'Aktif' : 'Tersedia',
                  badgeColor: activeBxgyCount > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  badgeTextColor: activeBxgyCount > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                  description:
                      'Berikan produk bonus gratis untuk pembelian jumlah tertentu (misal: Beli 2 Es Kopi Gratis 1 Menu Pilihan).',
                  actionLabel: 'Atur Promo BXGY',
                  actionIcon: Icons.card_giftcard_rounded,
                  tagLabel: activeBxgyCount > 0 ? '$activeBxgyCount Promo Aktif' : 'Rekomendasi Menu Siap',
                  gradientColors: const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                  borderColor: const Color(0xFFFECDD3),
                  accentColor: const Color(0xFFE11D48),
                  iconBgColor: const Color(0xFFFFE4E8),
                  icon: Icons.card_giftcard_rounded,
                  onTap: () => _openBxgyEditor(),
                ),
                const SizedBox(height: 12),

                // CARD 2: TEBUS MURAH (PWP) - Indigo/Blue Gradient
                _buildSchemeCard(
                  title: 'Tebus Murah (Add-on Special)',
                  badgeLabel: 'Populer',
                  badgeColor: const Color(0xFFEEF2FF),
                  badgeTextColor: const Color(0xFF4338CA),
                  description:
                      'Tawarkan produk pelengkap dengan harga miring setelah pelanggan mencapai minimal belanja atau pesan paket.',
                  actionLabel: 'Buat Skema Tebus Murah',
                  actionIcon: Icons.tune_rounded,
                  tagLabel: activeTebusCount > 0 ? '$activeTebusCount Promo Aktif' : 'Min. Belanja Fleksibel',
                  gradientColors: const [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  borderColor: const Color(0xFFC7D2FE),
                  accentColor: const Color(0xFF2563EB),
                  iconBgColor: const Color(0xFFDBEAFE),
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => _openTebusMurahEditor(),
                ),
                const SizedBox(height: 12),

                // CARD 3: DISKON & POTONGAN HARGA - Warm Amber Gradient
                _buildSchemeCard(
                  title: 'Diskon & Potongan Harga',
                  badgeLabel: 'Standar',
                  badgeColor: const Color(0xFFFEF3C7),
                  badgeTextColor: const Color(0xFFB45309),
                  description:
                      'Kelola diskon persentase (%), nominal langsung (Rp), atau voucher potongan per menu dan transaksi kasir.',
                  actionLabel: 'Kelola Diskon Aktif',
                  actionIcon: Icons.percent_rounded,
                  tagLabel: activeDiscountCount > 0 ? '$activeDiscountCount Diskon Aktif' : 'Voucher / % / Rp',
                  gradientColors: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  borderColor: const Color(0xFFFDE68A),
                  accentColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFED7AA),
                  icon: Icons.local_offer_outlined,
                  onTap: () => _openDiscountEditor(),
                ),
                const SizedBox(height: 28),

                // 2. SECTION: DAFTAR PROMO & DISKON TERDAFTAR
                _buildSectionHeader(
                  title: 'Daftar Promo Terdaftar',
                  subtitle: 'Pantau status, ubah aturan, atau nonaktifkan promo tokomu',
                ),
                const SizedBox(height: 14),

                // SEARCH BAR
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama promo atau kupon...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // FILTER PILLS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Semua (${discounts.length + bxgyPromos.length + tebusPromos.length})',
                        filter: PromoTypeFilter.all,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Beli X Gratis Y (${bxgyPromos.length})',
                        filter: PromoTypeFilter.bxgy,
                        activeColor: const Color(0xFFE11D48),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Tebus Murah (${tebusPromos.length})',
                        filter: PromoTypeFilter.tebusMurah,
                        activeColor: const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Diskon Reguler (${discounts.length})',
                        filter: PromoTypeFilter.regularDiscount,
                        activeColor: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // UNIFIED PROMO & DISCOUNT LIST
                _buildUnifiedList(
                  discounts: discounts,
                  bxgyPromos: bxgyPromos,
                  tebusPromos: tebusPromos,
                  canManage: canManage,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: canManage
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _showAddPromoPicker,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Tambah Produk / Promo Baru',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── HEADER BUILDER ────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    String? badgeText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
      ],
    );
  }

  // ── GRADIENT SCHEME CARDS (AS IN USER SCREENSHOT) ─────────────────────────

  Widget _buildSchemeCard({
    required String title,
    required String badgeLabel,
    required Color badgeColor,
    required Color badgeTextColor,
    required String description,
    required String actionLabel,
    required IconData actionIcon,
    required String tagLabel,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color accentColor,
    required Color iconBgColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + Badge + Chevron
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            // Description Text
            Text(
              description,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            // Bottom Action Row
            Row(
              children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(actionIcon, size: 15, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        actionLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    tagLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── FILTER CHIPS ──────────────────────────────────────────────────────────

  Widget _buildFilterChip({
    required String label,
    required PromoTypeFilter filter,
    Color activeColor = const Color(0xFF0F172A),
  }) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ── UNIFIED LIST (ALL SCHEMES IN ONE PLACE) ───────────────────────────────

  Widget _buildUnifiedList({
    required List<DiscountDefinition> discounts,
    required List<BuyXGetYPromo> bxgyPromos,
    required List<TebusMurahPromo> tebusPromos,
    required bool canManage,
  }) {
    final query = _searchController.text.trim().toLowerCase();

    final filteredDiscounts = discounts.where((d) {
      if (_selectedFilter != PromoTypeFilter.all &&
          _selectedFilter != PromoTypeFilter.regularDiscount) {
        return false;
      }
      if (query.isEmpty) return true;
      return d.name.toLowerCase().contains(query) ||
          (d.code?.toLowerCase().contains(query) ?? false);
    }).toList();

    final filteredBxgy = bxgyPromos.where((p) {
      if (_selectedFilter != PromoTypeFilter.all &&
          _selectedFilter != PromoTypeFilter.bxgy) {
        return false;
      }
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query);
    }).toList();

    final filteredTebus = tebusPromos.where((p) {
      if (_selectedFilter != PromoTypeFilter.all &&
          _selectedFilter != PromoTypeFilter.tebusMurah) {
        return false;
      }
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query);
    }).toList();

    final totalItems =
        filteredDiscounts.length + filteredBxgy.length + filteredTebus.length;

    if (totalItems == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Belum ada promo yang sesuai',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              query.isNotEmpty
                  ? 'Tidak ada hasil untuk "$query"'
                  : 'Pilih salah satu skema di atas untuk membuat penawaran toko pertamamu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 1. BXGY ITEMS
        for (final promo in filteredBxgy)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBxgyItemCard(promo, canManage),
          ),

        // 2. TEBUS MURAH ITEMS
        for (final promo in filteredTebus)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTebusItemCard(promo, canManage),
          ),

        // 3. REGULAR DISCOUNT ITEMS
        for (final discount in filteredDiscounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDiscountItemCard(discount, canManage),
          ),
      ],
    );
  }

  // ── ITEM CARDS ────────────────────────────────────────────────────────────

  Widget _buildBxgyItemCard(BuyXGetYPromo promo, bool canManage) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: const Text(
                    'BELI X GRATIS Y',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  promo.mode.label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: promo.isActive,
                  activeColor: const Color(0xFFE11D48),
                  onChanged: canManage
                      ? (val) => ref
                          .read(buyXGetYPromosProvider.notifier)
                          .toggleStatus(promo.id, val)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              promo.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              promo.mode == BuyXGetYMode.sameProduct
                  ? 'Beli ${promo.minBuyQty}x ${promo.triggerItemName ?? "Produk"}, Gratis ${promo.rewardQty}x produk yang sama'
                  : 'Beli ${promo.minBuyQty}x ${promo.triggerItemName ?? "Produk"}, Gratis ${promo.rewardQty}x ${promo.rewardItemName ?? "Produk"}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                _buildTagChip(promo.isMultipleAllowed ? 'Berlaku Kelipatan' : '1x / Nota'),
                _buildTagChip('Maks. ${promo.maxRewardPerTransaction} Gratis'),
              ],
            ),
            if (canManage) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openBxgyEditor(initialPromo: promo),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _deleteBxgyPromo(promo),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTebusItemCard(TebusMurahPromo promo, bool canManage) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Text(
                    'TEBUS MURAH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  promo.mode.label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: promo.isActive,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: canManage
                      ? (val) => ref
                          .read(tebusMurahPromosProvider.notifier)
                          .toggleStatus(promo.id, val)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              promo.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              promo.mode == TebusMurahMode.minSpend
                  ? 'Min. Belanja ${RupiahInputHelper.format(promo.minSpendAmount ?? 0)} ➔ Tebus ${promo.rewardItemName ?? "Produk"} hanya ${RupiahInputHelper.format(promo.specialPrice)}'
                  : 'Beli ${promo.triggerItemName ?? "Menu"} ➔ Tebus ${promo.rewardItemName ?? "Produk"} hanya ${RupiahInputHelper.format(promo.specialPrice)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                _buildTagChip('Maks. ${promo.maxQtyPerTransaction} pcs / Nota'),
                if (promo.quotaLimit != null)
                  _buildTagChip('Kuota: ${promo.currentUsageCount}/${promo.quotaLimit}'),
              ],
            ),
            if (canManage) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openTebusMurahEditor(initialPromo: promo),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _deleteTebusMurahPromo(promo),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountItemCard(DiscountDefinition discount, bool canManage) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    discount.type == DiscountType.percentage
                        ? 'POTONGAN ${discount.percentageValue?.toStringAsFixed(0)}%'
                        : 'DISKON NOMINAL',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
                if (discount.code != null && discount.code!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      discount.code!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Switch.adaptive(
                  value: discount.isActive,
                  activeColor: const Color(0xFFD97706),
                  onChanged: canManage
                      ? (val) async {
                          final updated = discount.copyWith(isActive: val);
                          await ref
                              .read(discountsProvider.notifier)
                              .upsertDiscount(updated);
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              discount.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              discount.type == DiscountType.percentage
                  ? 'Potongan ${discount.percentageValue?.toStringAsFixed(0)}%${discount.maxDiscountAmount != null ? " (Maks. ${RupiahInputHelper.format(discount.maxDiscountAmount!)})" : ""}'
                  : 'Potongan langsung ${RupiahInputHelper.format(discount.amountValue ?? 0)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (discount.description != null && discount.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                discount.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                _buildTagChip(discount.isAvailableNow ? 'Sedang Aktif' : 'Tidak Aktif'),
                if (discount.startsAt != null)
                  _buildTagChip('Mulai: ${discount.startsAt!.day}/${discount.startsAt!.month}/${discount.startsAt!.year}'),
              ],
            ),
            if (canManage) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openDiscountEditor(initialDiscount: discount),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _deleteDiscount(discount),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    );
  }
}
