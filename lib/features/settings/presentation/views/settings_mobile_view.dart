import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/settings/data/payment_settings_repository.dart';

class SettingsMobileView extends ConsumerWidget {
  const SettingsMobileView({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;

    return Material(
      color: tokens?.baseSurface ?? scheme.surface,
      child: ListView(
        padding: padding ?? const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // _buildSectionHeader(context, 'Kebijakan Sesi QR'),
          // _SettingsItem(
          //   icon: Icons.timer_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Masa Aktif QR Meja',
          //   subtitle: 'QR Expiry',
          //   trailing: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     decoration: BoxDecoration(
          //       color: Colors.orange.withOpacity(0.1),
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Text(
          //       '60 Menit',
          //       style: theme.textTheme.labelSmall?.copyWith(
          //         color: Colors.orange,
          //         fontWeight: FontWeight.bold,
          //       ),
          //     ),
          //   ),
          // ),
          // _SettingsItem(
          //   icon: Icons.fact_check_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Validasi Pesanan',
          //   subtitle: 'Manual waiter validation',
          //   trailing: Switch(
          //     value: true,
          //     onChanged: (val) {},
          //     activeColor: Colors.orange,
          //   ),
          // ),
          // _SettingsItem(
          //   icon: Icons.location_on_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Keamanan Sesi',
          //   subtitle: 'Location-based check-in',
          //   trailing: Switch(value: false, onChanged: (val) {}),
          // ),
          // const SizedBox(height: 24),
          // if (isDiyanto) ...[
          //   _buildSectionHeader(context, 'Admin & Feature Control'),
          //   _SettingsItem(
          //     icon: Icons.auto_awesome_motion_rounded,
          //     iconColor: Colors.purple,
          //     title: 'Kelola Template Bisnis',
          //     subtitle: 'Atur modul, batasan, dan template bisnis',
          //     showArrow: true,
          //     onTap: () => context.pushNamed(RouteNames.businessTemplateManagement),
          //   ),
          //   _SettingsItem(
          //     icon: Icons.people_alt_rounded,
          //     iconColor: Colors.blue,
          //     title: 'Manajemen Akun Bisnis',
          //     subtitle: 'Daftar semua bisnis dan ganti tipe bisnis',
          //     showArrow: true,
          //     onTap: () => context.pushNamed(RouteNames.businessAccountManagement),
          //   ),
          //   const SizedBox(height: 16),
          // ],
          _buildSectionHeader(context, 'Konfigurasi Pembayaran'),
          _SettingsItem(
            icon: Icons.payments_outlined,
            iconColor: Colors.orange,
            title: 'Metode Pembayaran',
            subtitle: _paymentMethodsSubtitle(paymentMethodsAsync),
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.paymentSettings),
          ),
          _SettingsItem(
            icon: Icons.qr_code_2_rounded,
            iconColor: Colors.orange,
            title: 'QRIS Toko',
            subtitle: 'Upload gambar QRIS statis toko untuk kasir',
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.qrisSettings),
          ),
          _SettingsItem(
            icon: Icons.print_outlined,
            iconColor: Colors.orange,
            title: 'Pengaturan Printer',
            subtitle: 'Bluetooth thermal printer',
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.printerSettings),
          ),
          _SettingsItem(
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.teal,
            title: 'Deteksi Notifikasi E-Wallet',
            subtitle: 'Auto-detect DANA, ShopeePay, GoPay, BCA, Livin',
            showArrow: true,
            onTap: () =>
                context.pushNamed(RouteNames.paymentNotificationSettings),
          ),
          _SettingsItem(
            icon: Icons.percent_rounded,
            iconColor: Colors.deepOrange,
            title: 'Pajak Transaksi (PB1 / PPN)',
            subtitle: bootstrap?.currentOutlet?.taxEnabled == true
                ? 'Aktif: ${bootstrap!.currentOutlet!.taxName} ${bootstrap.currentOutlet!.taxRate.toInt()}% (${bootstrap.currentOutlet!.isTaxInclusive ? "Inklusif" : "Eksklusif"})'
                : 'Nonaktif • Ketuk untuk mengatur tarif & nama pajak',
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.taxSettings),
          ),
          _SettingsItem(
            icon: Icons.room_service_outlined,
            iconColor: Colors.indigo,
            title: 'Tipe Pesanan Kasir',
            subtitle: 'Atur Dine In, Take Away, GoFood, GrabFood, Delivery, dll.',
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.orderTypeSettings),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Bantuan & Dukungan'),
          _SettingsItem(
            icon: Icons.help_outline_rounded,
            iconColor: Colors.orange,
            title: 'Help & Support',
            subtitle: 'Buku panduan 17 bab & kontak developer',
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.helpSupport),
          ),
          _SettingsItem(
            icon: Icons.workspace_premium_outlined,
            iconColor: Colors.amber,
            title: 'Paket & Langganan',
            subtitle: 'Cek masa aktif dan upgrade paket Pro',
            showArrow: true,
            onTap: () => context.pushNamed(RouteNames.subscription),
          ),
          // _SettingsItem(
          //   icon: Icons.point_of_sale_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Alur Penutupan Kasir',
          //   subtitle: 'Closing Flow',
          //   trailing: FilledButton(
          //     onPressed: () {},
          //     style: FilledButton.styleFrom(
          //       backgroundColor: const Color(0xFF371A00),
          //       padding: const EdgeInsets.symmetric(horizontal: 12),
          //       minimumSize: const Size(0, 32),
          //     ),
          //     child: const Text('Atur Shift'),
          //   ),
          // ),
          // const SizedBox(height: 24),
          // _buildSectionHeader(context, 'Aturan Notifikasi'),
          // _SettingsItem(
          //   icon: Icons.notifications_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Panggilan Pelayan',
          //   trailing: Switch(
          //     value: true,
          //     onChanged: (val) {},
          //     activeColor: Colors.orange,
          //   ),
          // ),
          // _SettingsItem(
          //   icon: Icons.restaurant_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Pesanan Siap Saji',
          //   trailing: Switch(
          //     value: true,
          //     onChanged: (val) {},
          //     activeColor: Colors.orange,
          //   ),
          // ),
          // _SettingsItem(
          //   icon: Icons.inventory_2_outlined,
          //   iconColor: Icons.orange,
          //   title: 'Peringatan Stok Habis',
          //   trailing: Switch(value: false, onChanged: (val) {}),
          // ),
          // _SettingsItem(
          //   icon: Icons.warning_amber_outlined,
          //   iconColor: Colors.orange,
          //   title: 'Monitoring Pesanan Lambat',
          //   trailing: Switch(
          //     value: true,
          //     onChanged: (val) {},
          //     activeColor: Colors.orange,
          //   ),
          // ),
          const SizedBox(height: 24),
          // const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'SYUPEO',
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface.withOpacity(0.2),
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'MUDAHKAN.ONLINE • INDRAMAYU',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.3),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  String _paymentMethodsSubtitle(
    AsyncValue<List<PaymentMethodConfig>> methodsAsync,
  ) {
    if (methodsAsync.isLoading && methodsAsync.valueOrNull == null) {
      return 'Memuat metode...';
    }

    if (methodsAsync.hasError && methodsAsync.valueOrNull == null) {
      return 'Standar (Tunai, QRIS, Transfer)';
    }

    final methods = methodsAsync.valueOrNull ?? const <PaymentMethodConfig>[];
    final activeMethods = methods.where((method) => method.isActive).toList();
    if (activeMethods.isEmpty) {
      return 'Belum ada metode aktif';
    }

    final labels = activeMethods
        .take(3)
        .map((method) => method.name)
        .join(', ');
    return '${activeMethods.length} Aktif ($labels)';
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.showArrow = false,
    this.onTap,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool showArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? scheme.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurface.withOpacity(0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
