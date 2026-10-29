import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:dpos/features/inventory/data/inventory_repository.dart';
import 'package:dpos/features/inventory/data/inventory_report_service.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/core/services/excel_export_service.dart';
import 'package:dpos/features/inventory/presentation/providers/inventory_dashboard_provider.dart';
import 'package:dpos/features/inventory/presentation/views/supplier_list_screen.dart';

class InventoryDashboardView extends ConsumerWidget {
  const InventoryDashboardView({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardDataAsync = ref.watch(inventoryDashboardDataProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 768;
    final isDesktop = screenWidth >= 1080;

    return dashboardDataAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Gagal memuat data inventaris: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.refresh(inventoryDashboardDataProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (data) => SingleChildScrollView(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: isTablet ? (isDesktop ? 28 : 20) : 16,
              vertical: isTablet ? 24 : 16,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InventoryHeader(),
            const SizedBox(height: 20),
            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Metrics + Actions Grid
                  Expanded(
                    flex: isDesktop ? 14 : 13,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _QuickStats(data: data, isTablet: true),
                        const SizedBox(height: 24),
                        _InventoryMenuGrid(isTablet: true, screenWidth: screenWidth),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right Pane: Low Stock Alerts & Summary
                  Expanded(
                    flex: isDesktop ? 9 : 10,
                    child: _LowStockAlerts(data: data, isTablet: true),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickStats(data: data, isTablet: false),
                  const SizedBox(height: 20),
                  _InventoryMenuGrid(isTablet: false, screenWidth: screenWidth),
                  const SizedBox(height: 24),
                  _LowStockAlerts(data: data, isTablet: false),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header Bar ─────────────────────────────────────────────────────────────

class _InventoryHeader extends ConsumerWidget {
  const _InventoryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 500;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventaris & Gudang',
                style: GoogleFonts.manrope(
                  fontSize: isCompact ? 20 : 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kelola stok produk, bahan baku, audit opname, dan supplier.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ActionIconButton(
          onPressed: () => _exportToExcel(context, ref),
          icon: Icons.grid_on_rounded,
          label: isCompact ? '' : 'Excel',
          iconColor: const Color(0xFF059669),
          tooltip: 'Ekspor ke Excel',
        ),
        const SizedBox(width: 8),
        _ActionIconButton(
          onPressed: () => _generateAndShowReport(context, ref),
          icon: Icons.description_outlined,
          label: isCompact ? '' : 'Laporan',
          iconColor: const Color(0xFFEA580C),
          tooltip: 'Cetak Laporan PDF',
        ),
      ],
    );
  }

  Future<void> _exportToExcel(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final business = ref.read(homeBootstrapProvider).value?.business;
      final stockItems = ref.read(menuItemsProvider).value ?? [];
      if (business == null) throw Exception('Data bisnis tidak ditemukan');

      await ExcelExportService.exportInventory(
        context,
        items: stockItems,
        businessName: business.name,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor data ke Excel: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _generateAndShowReport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final business = ref.read(homeBootstrapProvider).value?.business;
      final stockItems = ref.read(menuItemsProvider).value ?? [];
      final pos = ref.read(purchaseOrderListProvider).value ?? [];
      final suppliers = ref.read(supplierListProvider).value ?? [];

      if (business == null) throw Exception('Data bisnis tidak ditemukan');

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Preview Laporan Inventaris'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: PdfPreview(
              build: (format) => InventoryReportService.generateInventoryPdf(
                businessName: business.name,
                stockItems: stockItems,
                recentPOs: pos,
                suppliers: suppliers,
              ),
              allowSharing: true,
              allowPrinting: true,
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName:
                  'Laporan_Inventaris_${DateTime.now().millisecondsSinceEpoch}.pdf',
            ),
          ),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal membuat laporan: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.iconColor,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isIconOnly = label.isEmpty;

    Widget button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isIconOnly ? 10 : 14,
          vertical: 9,
        ),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? const Color(0xFF475569)),
          if (!isIconOnly) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

// ── Metric Stats Cards ─────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.data, required this.isTablet});
  final InventoryDashboardData data;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatBox(
        label: 'Katalog Produk',
        sublabel: 'Produk terlacak',
        value: data.totalProducts.toString(),
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
        onTap: () => context.pushNamed(RouteNames.productCatalogDashboard),
      ),
      _StatBox(
        label: 'Bahan Baku',
        sublabel: 'Dapur & bar (FnB)',
        value: data.totalIngredients.toString(),
        icon: Icons.egg_outlined,
        color: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
        onTap: () => context.pushNamed(RouteNames.ingredientList),
      ),
      _StatBox(
        label: 'Total Qty Fisik',
        sublabel: 'Unit stok tersedia',
        value: data.totalQty.toString(),
        icon: Icons.layers_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
      ),
      _StatBox(
        label: 'PO Menunggu',
        sublabel: 'Pesanan supplier',
        value: data.pendingPO.toString(),
        icon: Icons.assignment_outlined,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        onTap: () => context.pushNamed(RouteNames.purchaseOrderList),
      ),
    ];

    if (isTablet) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    // Mobile: 2x2 Clean Grid with fixed mainAxisExtent = 112 (No Overflow!)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 112,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  final String label;
  final String sublabel;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

// ── Quick Action Grid ──────────────────────────────────────────────────────

class _MenuActionItem {
  const _MenuActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.routeName,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String routeName;
  final String? badge;
}

class _InventoryMenuGrid extends StatelessWidget {
  const _InventoryMenuGrid({required this.isTablet, required this.screenWidth});
  final bool isTablet;
  final double screenWidth;

  static const _actions = [
    _MenuActionItem(
      title: 'Stok Opname',
      subtitle: 'Lembar hitung fisik & selisih',
      icon: Icons.checklist_rtl_rounded,
      color: Color(0xFF4F46E5),
      bgColor: Color(0xFFEEF2FF),
      routeName: RouteNames.stockOpnameSheet,
      badge: 'Audit',
    ),
    _MenuActionItem(
      title: 'Purchase Order',
      subtitle: 'Pesanan pembelian supplier',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFFD97706),
      bgColor: Color(0xFFFFFBEB),
      routeName: RouteNames.purchaseOrderList,
      badge: 'PO',
    ),
    _MenuActionItem(
      title: 'Penyesuaian Stok',
      subtitle: 'Koreksi manual, rusak & susut',
      icon: Icons.tune_rounded,
      color: Color(0xFF0284C7),
      bgColor: Color(0xFFF0F9FF),
      routeName: RouteNames.stockAdjustment,
    ),
    _MenuActionItem(
      title: 'Riwayat Stok',
      subtitle: 'Log mutasi keluar & masuk',
      icon: Icons.history_rounded,
      color: Color(0xFF7C3AED),
      bgColor: Color(0xFFF5F3FF),
      routeName: RouteNames.stockHistory,
    ),
    _MenuActionItem(
      title: 'Bahan Baku',
      subtitle: 'Stok bumbu, cup & sirup',
      icon: Icons.egg_outlined,
      color: Color(0xFFDB2777),
      bgColor: Color(0xFFFDF2F8),
      routeName: RouteNames.ingredientList,
      badge: 'FnB',
    ),
    _MenuActionItem(
      title: 'Resep Menu & HPP',
      subtitle: 'BOM resep & kalkulasi porsi',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFE11D48),
      bgColor: Color(0xFFFFF1F2),
      routeName: RouteNames.recipeManagement,
      badge: 'BOM',
    ),
    _MenuActionItem(
      title: 'Daftar Supplier',
      subtitle: 'Vendor & rekanan pemasok',
      icon: Icons.business_outlined,
      color: Color(0xFF059669),
      bgColor: Color(0xFFECFDF5),
      routeName: RouteNames.supplierList,
    ),
    _MenuActionItem(
      title: 'Katalog Produk',
      subtitle: 'Daftar barang & harga POS',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF2563EB),
      bgColor: Color(0xFFEFF6FF),
      routeName: RouteNames.productCatalogDashboard,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 6),
            Text(
              'AKSI & ALAT INVENTARIS',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 2 : 1,
            mainAxisExtent: isTablet ? 78 : 68,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = _actions[index];
            return _InventoryActionCard(
              item: item,
              isTablet: isTablet,
            );
          },
        ),
      ],
    );
  }
}

class _InventoryActionCard extends StatelessWidget {
  const _InventoryActionCard({
    required this.item,
    required this.isTablet,
  });

  final _MenuActionItem item;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed(item.routeName),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: item.bgColor,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: item.color.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                item.badge!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: item.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Low Stock Alerts & Summary ─────────────────────────────────────────────

class _LowStockAlerts extends StatelessWidget {
  const _LowStockAlerts({required this.data, required this.isTablet});
  final InventoryDashboardData data;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final hasLowStock = data.lowStockEntries.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hasLowStock
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasLowStock
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: hasLowStock
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Stok Menipis',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: hasLowStock
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasLowStock ? '${data.lowStockEntries.length}' : 'Aman',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    context.pushNamed(RouteNames.productCatalogDashboard),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Katalog',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content
          if (!hasLowStock)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 32,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Semua Stok Aman',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Tidak ada produk atau bahan baku yang menipis.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.lowStockEntries.length > 4
                  ? 4
                  : data.lowStockEntries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = data.lowStockEntries[index];
                return _LowStockEntryCard(entry: entry);
              },
            ),

          const SizedBox(height: 14),

          // Action shortcuts
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.pushNamed(RouteNames.createPurchaseOrder),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text(
                    'Buat PO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      context.pushNamed(RouteNames.stockOpnameSheet),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                  label: const Text(
                    'Opname',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockEntryCard extends StatelessWidget {
  const _LowStockEntryCard({required this.entry});
  final LowStockEntry entry;

  @override
  Widget build(BuildContext context) {
    final isCritical = entry.currentStock <= 0;
    final alertColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFEA580C);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: entry.isIngredient
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  entry.isIngredient ? 'Bahan' : 'Produk',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: entry.isIngredient
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${entry.currentStock.toStringAsFixed(entry.currentStock % 1 == 0 ? 0 : 1)} ${entry.unit}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: alertColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: entry.ratio,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(alertColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCritical
                ? 'Habis! Segera lakukan pemesanan.'
                : 'Min. ${entry.minStock.toStringAsFixed(0)} ${entry.unit}',
            style: TextStyle(
              fontSize: 10,
              color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
              fontWeight: isCritical ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
