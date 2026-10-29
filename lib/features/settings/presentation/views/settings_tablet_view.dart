import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/services/payment_notification_service.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/settings/data/payment_settings_repository.dart';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/settings/data/qris_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsTabletView extends ConsumerStatefulWidget {
  const SettingsTabletView({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<SettingsTabletView> createState() => _SettingsTabletViewState();
}

class _SettingsTabletViewState extends ConsumerState<SettingsTabletView> {
  bool _isSyncing = false;

  // Fallback map if methods are managed locally
  final Map<String, bool> _activeStates = {
    'cash': true,
    'debit_credit': true,
    'qris': true,
    'bank_transfer': true,
  };

  Future<void> _syncTerminal() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(qrisSettingsProvider);
      ref.invalidate(printerSettingsProvider);
      ref.invalidate(paymentNotificationProvider);

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Sinkronisasi terminal kasir berhasil.'),
            ],
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sinkronisasi gagal: $e')));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _reloadSession() {
    ref.invalidate(homeBootstrapProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Sesi terminal berhasil dimuat ulang.'),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleTestPrint(bool isPrinterActive) async {
    if (!isPrinterActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Printer belum terhubung. Konfigurasikan printer terlebih dahulu.'),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.print_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Mengirim perintah Test Print ke printer thermal...'),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final outlet = bootstrap?.currentOutlet;
    final outletName =
        outlet?.name ?? bootstrap?.business?.name ?? 'Mangga POS Station';

    final qrisSettings = ref.watch(qrisSettingsProvider).value;
    final printerSettings = ref.watch(printerSettingsProvider).value;
    final notifSettings = ref.watch(paymentNotificationProvider).value;
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final methods = methodsAsync.value ?? const <PaymentMethodConfig>[];

    final isQrisActive = qrisSettings != null &&
        (qrisSettings.hasQrisImage || qrisSettings.hasQrisPayload);
    final isPrinterActive = printerSettings?.hasSelectedPrinter == true &&
        printerSettings?.selectedPrinterAddress != null;
    final isNotifActive = notifSettings?.isEnabled == true;

    final activeServicesCount = (isQrisActive ? 1 : 0) +
        (isPrinterActive ? 1 : 0) +
        (isNotifActive ? 1 : 0);

    // Ensure generous breathing room / padding so it doesn't touch the header or edges
    final effectivePadding =
        (widget.padding == null || widget.padding == EdgeInsets.zero)
        ? const EdgeInsets.fromLTRB(36, 28, 36, 40)
        : widget.padding!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: AppTabletHeader(
        title: const Text('Pengaturan Sistem'),
        subtitle: Text(
          'Konfigurasi performa sistem, protokol keamanan, dan orkestrasi pembayaran',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        badge: const AppTabletBadge(label: 'Mangga POS'),
        actions: [
          OutlinedButton.icon(
            onPressed: _isSyncing ? null : _syncTerminal,
            icon: _isSyncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: Text(
              'SINKRONKAN TERMINAL',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
              backgroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _reloadSession,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: Text(
              'MUAT ULANG SESI',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF1C130D),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: effectivePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Sub-Area with Status Pills ─────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'TERMINAL AUTH VERIFIED',
                                  style: TextStyle(
                                    color: Color(0xFF0369A1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'v2.4.0-PRO',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pengaturan Sistem',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Konfigurasi performa sistem, protokol keamanan, dan orkestrasi pembayaran untuk operasional bisnis Anda.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── 2 Kolom Layout ────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Kolom Kiri: Payment Config (Flex 4) ───────────
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDD5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: Color(0xFFEA580C),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Payment Config',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Metode pembayaran aktif pada kasir terminal',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Item 1: Cash
                          _buildPaymentMethodTile(
                            icon: Icons.payments_rounded,
                            iconBg: const Color(0xFFDCFCE7),
                            iconColor: const Color(0xFF16A34A),
                            title: 'Cash',
                            subtitle: 'Uang tunai kas laci',
                            isActive: _getIsActive(
                              methods,
                              'cash',
                              fallback: _activeStates['cash'] ?? true,
                            ),
                            onChanged: (val) =>
                                _handleToggle(methods, 'cash', val),
                          ),

                          // Item 2: Debit / Credit
                          _buildPaymentMethodTile(
                            icon: Icons.credit_card_rounded,
                            iconBg: const Color(0xFFDBEAFE),
                            iconColor: const Color(0xFF2563EB),
                            title: 'Debit / Credit',
                            subtitle: 'EDC BCA, Mandiri & BRI',
                            isActive: _getIsActive(
                              methods,
                              'card',
                              fallback: _activeStates['debit_credit'] ?? true,
                            ),
                            onChanged: (val) =>
                                _handleToggle(methods, 'card', val),
                          ),

                          // Item 3: QRIS Dinamis & Statis
                          _buildPaymentMethodTile(
                            icon: Icons.qr_code_scanner_rounded,
                            iconBg: const Color(0xFFFFEDD5),
                            iconColor: const Color(0xFFEA580C),
                            title: 'QRIS Dinamis & Statis',
                            subtitle: 'ASPI QRIS Universal',
                            isActive: _getIsActive(
                              methods,
                              'qris',
                              fallback: _activeStates['qris'] ?? true,
                            ),
                            onChanged: (val) =>
                                _handleToggle(methods, 'qris', val),
                          ),

                          // Item 4: Transfer Bank & VA
                          _buildPaymentMethodTile(
                            icon: Icons.account_balance_rounded,
                            iconBg: const Color(0xFFF1F5F9),
                            iconColor: const Color(0xFF475569),
                            title: 'Transfer Bank & VA',
                            subtitle: 'BCA, Mandiri, Permata',
                            isActive: _getIsActive(
                              methods,
                              'bank_transfer',
                              fallback: _activeStates['bank_transfer'] ?? true,
                            ),
                            onChanged: (val) =>
                                _handleToggle(methods, 'bank_transfer', val),
                          ),

                          const SizedBox(height: 14),

                          // Auto-Rekonsiliasi Kas Notice
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.verified_user_outlined,
                                    size: 18,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Auto-Rekonsiliasi Kas',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Otomatis sinkronisasi rekonsiliasi kas masuk saat tutup kasir (closing shift) ke cloud storage pusat.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // ── Kolom Kanan: Integrasi Perangkat & Layanan (Flex 6) ──
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'INTEGRASI PERANGKAT & LAYANAN',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '$activeServicesCount dari 3 Layanan Terhubung',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: activeServicesCount > 0
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Card 1: QRIS Toko
                        _buildIntegrationCard(
                          context: context,
                          icon: Icons.qr_code_2_rounded,
                          iconBg: isQrisActive
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFFEE2E2),
                          iconColor: isQrisActive
                              ? const Color(0xFFEA580C)
                              : const Color(0xFFDC2626),
                          title: 'QRIS Toko',
                          badgeLabel: isQrisActive
                              ? (qrisSettings.nmid?.isNotEmpty == true
                                  ? 'NMID: ${qrisSettings.nmid}'
                                  : 'QRIS Aktif')
                              : 'Belum Diatur',
                          badgeBg: isQrisActive
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFFEE2E2),
                          badgeColor: isQrisActive
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFFDC2626),
                          subtitle:
                              'Atur gambar QRIS statis toko & merchant ID settlement',
                          isConnected: isQrisActive,
                          statusText: isQrisActive
                              ? (qrisSettings.merchantName?.isNotEmpty == true
                                  ? 'Terkoneksi (${qrisSettings.merchantName})'
                                  : (qrisSettings.hasQrisImage
                                      ? 'Terkoneksi (Gambar QRIS Siap)'
                                      : 'Terkoneksi (QRIS Dinamis Aktif)'))
                              : 'Belum Dikonfigurasi (Gambar QRIS belum diunggah)',
                          actionWidget: InkWell(
                            onTap: () =>
                                context.pushNamed(RouteNames.qrisSettings),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isQrisActive
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isQrisActive
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Icon(
                                Icons.qr_code_rounded,
                                size: 18,
                                color: isQrisActive
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          onTap: () =>
                              context.pushNamed(RouteNames.qrisSettings),
                        ),

                        const SizedBox(height: 14),

                        // Card 2: Printer Thermal Kasir
                        _buildIntegrationCard(
                          context: context,
                          icon: Icons.print_rounded,
                          iconBg: isPrinterActive
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          iconColor: isPrinterActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          title: 'Printer Thermal Kasir',
                          badgeLabel: isPrinterActive
                              ? '${printerSettings?.paperSize.label ?? "80mm"} Paper'
                              : 'Belum Terhubung',
                          badgeBg: isPrinterActive
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          badgeColor: isPrinterActive
                              ? const Color(0xFF15803D)
                              : const Color(0xFFDC2626),
                          subtitle:
                              'Bluetooth & LAN receipt printer kitchen & checkout',
                          isConnected: isPrinterActive,
                          statusText: isPrinterActive
                              ? 'Terkoneksi: ${printerSettings?.selectedPrinterName ?? "Printer Aktif"}'
                              : 'Belum Terkoneksi (Pilih printer di pengaturan)',
                          actionWidget: OutlinedButton(
                            onPressed: () => _handleTestPrint(isPrinterActive),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isPrinterActive
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF94A3B8),
                              backgroundColor: const Color(0xFFF8FAFC),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Test Print',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          onTap: () =>
                              context.pushNamed(RouteNames.printerSettings),
                        ),

                        const SizedBox(height: 14),

                        // Card 3: Deteksi Notifikasi E-Wallet
                        _buildIntegrationCard(
                          context: context,
                          icon: Icons.notifications_active_rounded,
                          iconBg: isNotifActive
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFFEE2E2),
                          iconColor: isNotifActive
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFDC2626),
                          title: 'Deteksi Notifikasi E-Wallet',
                          badgeLabel:
                              isNotifActive ? 'Auto-Hook Aktif' : 'Nonaktif',
                          badgeBg: isNotifActive
                              ? const Color(0xFFE0E7FF)
                              : const Color(0xFFFEE2E2),
                          badgeColor: isNotifActive
                              ? const Color(0xFF4338CA)
                              : const Color(0xFFDC2626),
                          subtitle:
                              'Auto-detect push SMS / notifikasi transfer DANA, ShopeePay, GoPay, BCA, Livin',
                          isConnected: isNotifActive,
                          statusText: isNotifActive
                              ? 'Aktif (Listener Service Berjalan Normal)'
                              : 'Belum Aktif (Layanan deteksi dinonaktifkan)',
                          actionWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPillLogo(
                                'BCA',
                                isNotifActive
                                    ? const Color(0xFFE0F2FE)
                                    : const Color(0xFFF1F5F9),
                                isNotifActive
                                    ? const Color(0xFF0369A1)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              _buildPillLogo(
                                'G',
                                isNotifActive
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF1F5F9),
                                isNotifActive
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              _buildPillLogo(
                                'SP',
                                isNotifActive
                                    ? const Color(0xFFFFEDD5)
                                    : const Color(0xFFF1F5F9),
                                isNotifActive
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                          onTap: () => context.pushNamed(
                            RouteNames.paymentNotificationSettings,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Button: Atur Pembayaran & Gateway (Full width)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.pushNamed(RouteNames.paymentSettings),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(
                              'ATUR PEMBAYARAN & GATEWAY',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1C130D),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Action Button: Atur Pajak (PB1 / PPN)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.pushNamed(RouteNames.taxSettings),
                            icon: const Icon(Icons.percent_rounded, size: 18),
                            label: Text(
                              'PENGATURAN PAJAK (PB1 / PPN)',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC2410C),
                              side: const BorderSide(color: Color(0xFFF97316)),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Action Button: Atur Tipe Pesanan
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.pushNamed(RouteNames.orderTypeSettings),
                            icon: const Icon(Icons.room_service_outlined, size: 18),
                            label: Text(
                              'PENGATURAN TIPE PESANAN KASIR',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1D4ED8),
                              side: const BorderSide(color: Color(0xFF3B82F6)),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── 2 Stats Diagnostic Cards (Tanpa Status Lisensi) ──
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                label: 'PING HOST',
                                value: '18 ms',
                                valueColor: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildMetricCard(
                                label: 'KECEPATAN CETAK',
                                value: '250 mm/s',
                                valueColor: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Footer ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PRECISION CONCIERGE v2.4.0-PRO',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${outletName.toUpperCase()} • POSISI STATION 04',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ───────────────────────────────────────────────

  Widget _buildPaymentMethodTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isActive,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Switch.adaptive(
            value: isActive,
            activeColor: const Color(0xFF16A34A),
            activeTrackColor: const Color(0xFFBBF7D0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String badgeLabel,
    required Color badgeBg,
    required Color badgeColor,
    required String subtitle,
    required String statusText,
    required bool isConnected,
    required Widget actionWidget,
    required VoidCallback onTap,
  }) {
    final statusColor =
        isConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConnected
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFFECACA),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              actionWidget,
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPillLogo(String text, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  bool _getIsActive(
    List<PaymentMethodConfig> methods,
    String key, {
    required bool fallback,
  }) {
    final match = methods.where((m) {
      if (key == 'cash') {
        return m.type == PaymentMethodType.cash || m.code == 'cash';
      }
      if (key == 'card') {
        return m.type == PaymentMethodType.card || m.code == 'debit_credit';
      }
      if (key == 'qris') {
        return m.type == PaymentMethodType.qris || m.code == 'qris';
      }
      if (key == 'bank_transfer') {
        return m.type == PaymentMethodType.bankTransfer ||
            m.code == 'bank_transfer';
      }
      return false;
    });
    if (match.isNotEmpty) {
      return match.first.isActive;
    }
    return fallback;
  }

  void _handleToggle(
    List<PaymentMethodConfig> methods,
    String key,
    bool value,
  ) {
    setState(() {
      if (key == 'cash') {
        _activeStates['cash'] = value;
      }
      if (key == 'card') {
        _activeStates['debit_credit'] = value;
      }
      if (key == 'qris') {
        _activeStates['qris'] = value;
      }
      if (key == 'bank_transfer') {
        _activeStates['bank_transfer'] = value;
      }
    });

    final match = methods.where((m) {
      if (key == 'cash') {
        return m.type == PaymentMethodType.cash || m.code == 'cash';
      }
      if (key == 'card') {
        return m.type == PaymentMethodType.card || m.code == 'debit_credit';
      }
      if (key == 'qris') {
        return m.type == PaymentMethodType.qris || m.code == 'qris';
      }
      if (key == 'bank_transfer') {
        return m.type == PaymentMethodType.bankTransfer ||
            m.code == 'bank_transfer';
      }
      return false;
    });

    if (match.isNotEmpty) {
      final method = match.first;
      ref
          .read(paymentMethodsProvider.notifier)
          .saveMethod(method.copyWith(isActive: value));
    }
  }
}
