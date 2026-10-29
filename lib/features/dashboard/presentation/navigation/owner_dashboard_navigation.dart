import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/core/providers/feature_gate_provider.dart';

enum MenuSection {
  operasional('OPERASIONAL'),
  resto('RESTO & MEJA'),
  catalogReports('KATALOG & LAPORAN'),
  settingsStore('PENGATURAN TOKO');

  final String label;
  const MenuSection(this.label);
}

enum OwnerMenu {
  home(
    title: 'Beranda',
    icon: Icons.home_rounded,
    subtitle: 'Ringkasan utama',
    section: MenuSection.operasional,
    isCore: true,
  ),
  transaction(
    title: 'Transaksi',
    icon: Icons.point_of_sale_rounded,
    subtitle: 'Buat & kelola order',
    section: MenuSection.operasional,
    featureKey: 'transaction',
  ),
  orderManagement(
    title: 'Pesanan & Draft',
    icon: Icons.assignment_rounded,
    subtitle: 'Pesanan masuk & draft',
    section: MenuSection.operasional,
    featureKey: 'order_mgmt',
  ),
  checkoutVoid(
    title: 'Riwayat Transaksi',
    icon: Icons.history_rounded,
    subtitle: 'Lihat detail & cetak ulang',
    section: MenuSection.operasional,
    isCore: true,
  ),
  customerDebt(
    title: 'Buku Kasbon & Pelanggan',
    icon: Icons.menu_book_rounded,
    subtitle: 'Piutang & tagihan pelanggan',
    section: MenuSection.operasional,
    featureKey: 'customer_debt',
  ),
  cashFlow(
    title: 'Arus Kas & Shift',
    icon: Icons.account_balance_wallet_rounded,
    subtitle: 'Kas laci & mutasi kasir',
    section: MenuSection.operasional,
    featureKey: 'cash_flow',
  ),
  tableSession(
    title: 'Sesi Meja',
    icon: Icons.table_restaurant_rounded,
    subtitle: 'Ringkasan alur waiter',
    section: MenuSection.resto,
    featureKey: 'table_mgmt',
  ),
  tableTracker(
    title: 'Table Tracker',
    icon: Icons.grid_view_rounded,
    subtitle: 'Pantau meja aktif waiter',
    section: MenuSection.resto,
    featureKey: 'table_mgmt',
  ),
  waiterOrders(
    title: 'Orderan',
    icon: Icons.receipt_long_rounded,
    subtitle: 'Order waiter aktif',
    section: MenuSection.resto,
    featureKey: 'table_mgmt',
  ),
  waiterHistory(
    title: 'Riwayat Transaksi',
    icon: Icons.history_toggle_off_rounded,
    subtitle: 'Histori order waiter',
    section: MenuSection.resto,
    featureKey: 'table_mgmt',
  ),
  kitchenQueue(
    title: 'Antrian Dapur',
    icon: Icons.grid_view_rounded,
    subtitle: 'Antrian dapur',
    section: MenuSection.resto,
    featureKey: 'kitchen_kds',
  ),
  qrSelfOrder(
    title: 'QR Self-Order',
    icon: Icons.qr_code_scanner_rounded,
    subtitle: 'Generate QR Meja',
    section: MenuSection.resto,
    featureKey: 'qr_order',
  ),
  menuManagement(
    title: 'Produk & Diskon',
    icon: Icons.inventory_2_rounded,
    subtitle: 'Kelola Produk & Diskon',
    section: MenuSection.catalogReports,
    featureKey: 'menu_mgmt',
  ),
  inventory(
    title: 'Inventori / Stok',
    icon: Icons.inventory_2_rounded,
    subtitle: 'Stok & supplier',
    section: MenuSection.catalogReports,
    featureKey: 'inventory',
  ),
  reports(
    title: 'Laporan',
    icon: Icons.bar_chart_rounded,
    subtitle: 'Analitik bisnis',
    section: MenuSection.catalogReports,
    featureKey: 'reports',
  ),
  aiAssistant(
    title: 'Asisten AI Mangga POS',
    icon: Icons.auto_awesome_rounded,
    subtitle: 'Konsultasi bisnis & analitik',
    section: MenuSection.catalogReports,
    isCore: true,
  ),
  staff(
    title: 'Manajemen Staf',
    icon: Icons.assignment_ind_rounded,
    subtitle: 'Role & akses',
    section: MenuSection.settingsStore,
    isCore: true,
  ),
  outletManagement(
    title: 'Manajemen Outlet',
    icon: Icons.store_mall_directory_rounded,
    subtitle: 'Status & jaringan outlet',
    section: MenuSection.settingsStore,
    isCore: true,
  ),
  businessProfile(
    title: 'Profil Bisnis',
    icon: Icons.storefront_rounded,
    subtitle: 'Profil bisnis',
    section: MenuSection.settingsStore,
    isCore: true,
  ),
  settings(
    title: 'Pengaturan',
    icon: Icons.settings_rounded,
    subtitle: 'Konfigurasi sistem',
    section: MenuSection.settingsStore,
    isCore: true,
  ),
  printerSettings(
    title: 'Pengaturan Printer',
    icon: Icons.print_rounded,
    subtitle: 'Koneksi printer thermal',
    section: MenuSection.settingsStore,
    isCore: true,
  ),
  subscription(
    title: 'Paket Langganan',
    icon: Icons.workspace_premium_rounded,
    subtitle: 'Upgrade ke Pro',
    section: MenuSection.settingsStore,
    featureKey: 'subscription',
  ),
  support(
    title: 'Help & Support',
    icon: Icons.help_rounded,
    subtitle: 'Bantuan & status',
    section: MenuSection.settingsStore,
    isCore: true,
  );

  const OwnerMenu({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.section,
    this.featureKey,
    this.isCore = false,
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final MenuSection section;
  final String? featureKey;
  final bool isCore;
}

final ownerSelectedMenuProvider = StateProvider<OwnerMenu>(
  (ref) => OwnerMenu.home,
);

final ownerMenuHistoryProvider = StateProvider<List<OwnerMenu>>(
  (ref) => [OwnerMenu.home],
);

class OwnerDashboardNavigation {
  const OwnerDashboardNavigation._();

  static List<OwnerMenu> availableMenusForBootstrap(
    OwnerBootstrap? bootstrap,
    WidgetRef ref,
  ) {
    final role = bootstrap?.membership?.role ?? bootstrap?.profile?.defaultRole;
    final allMenus = availableMenusForRole(role ?? AppRole.owner);

    // Filter menu berdasarkan fitur yang aktif
    final business = bootstrap?.business;
    if (business == null) return allMenus;

    final featureGate = ref.watch(featureGateProvider);
    final isLegacy = business.businessType == null;

    return allMenus.where((menu) {
      // 1. Menu Core selalu tampil (Home, Profile, Settings, dll)
      if (menu.isCore) return true;

      // 2. Jika Super Admin, tampilkan semua fitur
      if (featureGate.isEnabled('admin_bypass')) return true;

      // 3. Cek apakah fitur diizinkan berdasarkan Feature Gate (Template/Plan)
      if (menu.featureKey != null) {
        final config = business.featuresConfig[menu.featureKey];
        // Jika fitur diset 'off' secara eksplisit di template, sembunyikan total dari menu
        if (config == 'off') return false;

        // Untuk fitur yang diset 'pro' (seperti cash_flow, reports):
        // Tetap tampilkan di menu agar user Free melihat badge PRO dan bisa mengklik untuk melihat info upgrade
        if (config == 'pro' || menu == OwnerMenu.cashFlow) {
          return true;
        }

        if (isLegacy) {
          return true;
        }
        return featureGate.isEnabled(menu.featureKey!);
      }

      return true;
    }).toList();
  }

  static OwnerMenu effectiveMenu({
    required OwnerMenu selectedMenu,
    required OwnerBootstrap? bootstrap,
    required WidgetRef ref,
  }) {
    final availableMenus = availableMenusForBootstrap(bootstrap, ref);
    if (availableMenus.contains(selectedMenu)) {
      return selectedMenu;
    }
    return availableMenus.first;
  }

  static void selectMenu(
    WidgetRef ref,
    OwnerMenu menu, {
    OwnerBootstrap? bootstrap,
  }) {
    final effective = effectiveMenu(
      selectedMenu: menu,
      bootstrap: bootstrap,
      ref: ref,
    );

    final history = ref.read(ownerMenuHistoryProvider);
    if (history.isEmpty || history.last != effective) {
      ref
          .read(ownerMenuHistoryProvider.notifier)
          .update((state) => [...state, effective]);
    }

    ref.read(ownerSelectedMenuProvider.notifier).state = effective;
  }

  static void resetMenu(WidgetRef ref) {
    ref.read(ownerSelectedMenuProvider.notifier).state = OwnerMenu.home;
    ref.read(ownerMenuHistoryProvider.notifier).state = [OwnerMenu.home];
  }

  static bool canManageStaff(OwnerBootstrap? bootstrap) {
    final role = bootstrap?.membership?.role ?? bootstrap?.profile?.defaultRole;
    return role == AppRole.owner;
  }
}

List<OwnerMenu> availableMenusForRole(AppRole role) {
  return switch (role) {
    AppRole.owner => const [
      // 1. Operasional Utama Kasir & Penjualan
      OwnerMenu.home,
      OwnerMenu.transaction,
      OwnerMenu.orderManagement,
      OwnerMenu.checkoutVoid,
      OwnerMenu.customerDebt,
      OwnerMenu.cashFlow,

      // 2. Resto & Meja (FnB)
      OwnerMenu.tableSession,
      OwnerMenu.kitchenQueue,
      OwnerMenu.qrSelfOrder,

      // 3. Produk, Stok & Laporan
      OwnerMenu.menuManagement,
      OwnerMenu.inventory,
      OwnerMenu.reports,
      OwnerMenu.aiAssistant,

      // 4. Pengaturan Toko & Akun
      OwnerMenu.staff,
      OwnerMenu.outletManagement,
      OwnerMenu.businessProfile,
      OwnerMenu.settings,
      OwnerMenu.printerSettings,
      OwnerMenu.subscription,
      OwnerMenu.support,
    ],
    AppRole.admin => const [
      // 1. Operasional Utama Kasir & Penjualan
      OwnerMenu.home,
      OwnerMenu.transaction,
      OwnerMenu.orderManagement,
      OwnerMenu.checkoutVoid,
      OwnerMenu.customerDebt,
      OwnerMenu.cashFlow,

      // 2. Resto & Meja (FnB)
      OwnerMenu.tableSession,
      OwnerMenu.kitchenQueue,
      OwnerMenu.qrSelfOrder,

      // 3. Produk, Stok & Laporan
      OwnerMenu.inventory,
      OwnerMenu.reports,
      OwnerMenu.aiAssistant,

      // 4. Pengaturan Toko & Akun
      OwnerMenu.outletManagement,
      OwnerMenu.settings,
      OwnerMenu.printerSettings,
      OwnerMenu.subscription,
      OwnerMenu.support,
    ],
    AppRole.cashier => const [
      // 1. Operasional Utama Kasir
      OwnerMenu.home,
      OwnerMenu.transaction,
      OwnerMenu.orderManagement,
      OwnerMenu.checkoutVoid,
      OwnerMenu.customerDebt,
      OwnerMenu.cashFlow,

      // 2. Stok & Laporan Ringkas
      OwnerMenu.inventory,
      OwnerMenu.reports,
      OwnerMenu.aiAssistant,

      // 3. Pengaturan Toko & Akun
      OwnerMenu.settings,
      OwnerMenu.printerSettings,
      OwnerMenu.subscription,
      OwnerMenu.support,
    ],
    AppRole.waiter => const [
      // 1. Operasional & Meja
      OwnerMenu.transaction,
      OwnerMenu.tableSession,
      OwnerMenu.tableTracker,
      OwnerMenu.waiterOrders,
      OwnerMenu.waiterHistory,
      OwnerMenu.qrSelfOrder,

      // 2. Pengaturan & Bantuan
      OwnerMenu.settings,
      OwnerMenu.printerSettings,
      OwnerMenu.subscription,
      OwnerMenu.support,
    ],
    AppRole.kitchen => const [
      // 1. Operasional Dapur
      OwnerMenu.kitchenQueue,
      OwnerMenu.home,

      // 2. Pengaturan & Bantuan
      OwnerMenu.settings,
      OwnerMenu.printerSettings,
      OwnerMenu.subscription,
      OwnerMenu.support,
    ],
    AppRole.customer => const [OwnerMenu.home, OwnerMenu.support],
  };
}

String roleDisplayLabel(AppRole role, {Business? business}) {
  final customLabel = business?.roleLabels[role.name];
  if (customLabel != null && customLabel.isNotEmpty) {
    return customLabel;
  }

  return switch (role) {
    AppRole.owner => 'Owner',
    AppRole.admin => 'Admin',
    AppRole.cashier => 'Cashier',
    AppRole.waiter => 'Waiter',
    AppRole.kitchen => 'Kitchen',
    AppRole.customer => 'Customer',
  };
}
