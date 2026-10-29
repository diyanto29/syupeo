import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dpos/core/services/payment_gateway_background_helper.dart';
import 'package:dpos/core/services/payment_notification_models.dart';
import 'package:dpos/core/services/payment_notification_service.dart';
import 'package:dpos/core/services/soundbox_tts_service.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';

class PaymentNotificationSettingsScreen extends ConsumerStatefulWidget {
  const PaymentNotificationSettingsScreen({super.key});

  @override
  ConsumerState<PaymentNotificationSettingsScreen> createState() =>
      _PaymentNotificationSettingsScreenState();
}

class _PaymentNotificationSettingsScreenState
    extends ConsumerState<PaymentNotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _isLoadingPermission = true;
  bool _isIgnoringBattery = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isLoadingPermission = true);
    final granted =
        await ref.read(paymentNotificationProvider.notifier).checkPermission();
    final ignoringBattery =
        await PaymentGatewayBackgroundHelper.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
        _isIgnoringBattery = ignoringBattery;
        _isLoadingPermission = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    await ref.read(paymentNotificationProvider.notifier).requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(paymentNotificationProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? const AppTabletHeader(
              title: Text('Deteksi Pembayaran & Virtual Soundbox'),
              badge: AppTabletBadge(label: 'Mangga POS'),
            )
          : AppBar(
              title: Text(
                'Deteksi Pembayaran & Soundbox',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: settingsAsync.when(
        data: (settings) => _buildContent(context, settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Terjadi kesalahan: $err')),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, NotificationPaymentSettings settings) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needsNotificationAccess =
        settings.role != DevicePaymentRole.cashierOnly;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Info Banner Virtual Soundbox ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.volume_up_rounded, color: scheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Virtual Soundbox & Cloud Relay',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HP Owner (yang memiliki GoBiz/Livin) dapat bertindak sebagai Gateway. Sinyal pembayaran otomatis diteruskan ke HP Kasir di toko secara realtime (< 1 detik) disertai suara pengumuman Soundbox resmi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Master Switch ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: settings.isEnabled
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: settings.isEnabled ? Colors.white : scheme.outline,
                size: 24,
              ),
            ),
            title: Text(
              'Aktifkan Fitur Pembayaran Otomatis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              settings.isEnabled
                  ? 'Sistem pembayaran otomatis & relay aktif'
                  : 'Fitur deteksi pembayaran dinonaktifkan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
            value: settings.isEnabled,
            onChanged: (val) async {
              if (val && needsNotificationAccess && !_hasPermission) {
                await _requestPermission();
              }
              ref.read(paymentNotificationProvider.notifier).setEnabled(val);
            },
          ),
        ),

        const SizedBox(height: 24),

        if (settings.isEnabled) ...[
          // ── Pilihan Peran Perangkat ──────────────────────────────
          Text(
            'Peran Perangkat Ini (Device Role)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildRoleOption(
                  context: context,
                  role: DevicePaymentRole.cashierOnly,
                  currentRole: settings.role,
                  title: 'Mode Kasir (Penerima & Soundbox)',
                  subtitle:
                      'Perangkat kasir di outlet. Menerima notifikasi dari HP Owner secara realtime dan memutar suara Soundbox.',
                  icon: Icons.point_of_sale_rounded,
                  isTop: true,
                  isBottom: false,
                ),
                const Divider(height: 1),
                _buildRoleOption(
                  context: context,
                  role: DevicePaymentRole.gatewayOwner,
                  currentRole: settings.role,
                  title: 'Mode Hook Gateway (HP Owner / Bos)',
                  subtitle:
                      'Perangkat tempat GoBiz / Livin / Bank terpasang. Membaca notifikasi di HP ini lalu me-relay ke HP kasir.',
                  icon: Icons.hub_rounded,
                  isTop: false,
                  isBottom: false,
                ),
                const Divider(height: 1),
                _buildRoleOption(
                  context: context,
                  role: DevicePaymentRole.both,
                  currentRole: settings.role,
                  title: 'Mode Mandiri (Kasir & Merchant Bersama)',
                  subtitle:
                      'Untuk toko yang aplikasi kasir dan e-wallet-nya ada di HP yang sama.',
                  icon: Icons.phonelink_setup_rounded,
                  isTop: false,
                  isBottom: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (settings.role != DevicePaymentRole.cashierOnly) ...[
            // ── Background Gateway 24/7 Settings ───────────────────
            Text(
              'Layanan Latar Belakang 24/7 (HP Owner)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tetap Aktif di Latar Belakang (Foreground Service)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Menampilkan ikon status bar agar sistem Android tidak membekukan atau mematikan layanan Mangga POS saat HP di-minimize atau layar mati.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings.isForegroundServiceEnabled,
                    onChanged: (val) {
                      ref
                          .read(paymentNotificationProvider.notifier)
                          .toggleForegroundService(val);
                    },
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Optimasi Baterai Android',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isIgnoringBattery
                                  ? '✓ Bebas Batasan (Aplikasi tidak akan dibekukan oleh sistem)'
                                  : '⚠️ Dibatasi sistem. Izinkan "Tanpa Batas" agar relay 24 jam lancar.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _isIgnoringBattery
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isIgnoringBattery)
                        FilledButton.tonal(
                          onPressed: () async {
                            await PaymentGatewayBackgroundHelper
                                .requestIgnoreBatteryOptimizations();
                            await _checkPermission();
                          },
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Buka Izin', style: TextStyle(fontSize: 12)),
                        )
                      else
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],

          const SizedBox(height: 24),

          // ── Virtual Soundbox (TTS) Settings ──────────────────────
          Text(
            'Virtual Soundbox (Suara Pengumuman)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Suarakan Pengumuman (TTS)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Ucapkan "Pembayaran QRIS sebesar ... telah diterima" saat dana masuk.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.enableTtsSoundbox,
                  onChanged: (val) {
                    ref
                        .read(paymentNotificationProvider.notifier)
                        .setEnableTtsSoundbox(val);
                  },
                ),
                if (settings.enableTtsSoundbox) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kecepatan Bicara',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        settings.ttsSpeechRate <= 0.42
                            ? 'Pelan / Tenang'
                            : (settings.ttsSpeechRate <= 0.52
                                ? 'Standar Soundbox'
                                : 'Cepat'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.ttsSpeechRate.clamp(0.35, 0.70),
                    min: 0.35,
                    max: 0.70,
                    divisions: 7,
                    label: '${(settings.ttsSpeechRate * 2).toStringAsFixed(1)}x',
                    onChanged: (val) {
                      ref
                          .read(paymentNotificationProvider.notifier)
                          .setTtsSpeechRate(val);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      side: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.volume_up_rounded, size: 20),
                    label: const Text('Tes Suara Virtual Soundbox'),
                    onPressed: () {
                      ref.read(soundboxTtsServiceProvider).speakPayment(
                            appName: 'Livin\' Merchant',
                            amount: 25000,
                            sender: 'Budi Santoso',
                            speechRate: settings.ttsSpeechRate,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Memutar contoh suara Soundbox...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Izin Notifikasi Android (Hanya jika butuh hook lokal) ─
          if (needsNotificationAccess) ...[
            if (!_isLoadingPermission && !_hasPermission) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Izin Notifikasi HP Ini Belum Aktif',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Agar perangkat ini dapat membaca notifikasi GoBiz / Livin dan meneruskannya ke kasir, berikan izin akses notifikasi di pengaturan Android.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.touch_app_rounded, size: 18),
                        label: const Text('Buka Pengaturan & Berikan Izin'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Pilih E-Wallet & Bank yang Dipantau ────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aplikasi Bank & E-Wallet Dipantau',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.outline,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final allSelected = settings.enabledPackageNames.length ==
                        PaymentAppCatalog.allApps.length;
                    final notifier =
                        ref.read(paymentNotificationProvider.notifier);
                    if (allSelected) {
                      notifier.updateSettings(
                        settings.copyWith(enabledPackageNames: <String>{}),
                      );
                    } else {
                      notifier.updateSettings(
                        settings.copyWith(
                          enabledPackageNames: PaymentAppCatalog.allApps
                              .map((e) => e.packageName)
                              .toSet(),
                        ),
                      );
                    }
                  },
                  child: Text(
                    settings.enabledPackageNames.length ==
                            PaymentAppCatalog.allApps.length
                        ? 'Batal Semua'
                        : 'Pilih Semua',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: PaymentAppCatalog.allApps.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final app = PaymentAppCatalog.allApps[index];
                  final isChecked =
                      settings.enabledPackageNames.contains(app.packageName);

                  return CheckboxListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? scheme.primary.withValues(alpha: 0.12)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getAppIcon(app.id),
                        color: isChecked ? scheme.primary : scheme.outline,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      app.name,
                      style: TextStyle(
                        fontWeight:
                            isChecked ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      app.packageName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    value: isChecked,
                    onChanged: (val) {
                      ref
                          .read(paymentNotificationProvider.notifier)
                          .togglePackage(app.packageName, val ?? false);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            // Status Info untuk Mode Kasir Only
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded,
                      color: Color(0xFF16A34A)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Perangkat ini siap menerima notifikasi pembayaran otomatis dari HP Owner melalui cloud realtime.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ],
    );
  }

  Widget _buildRoleOption({
    required BuildContext context,
    required DevicePaymentRole role,
    required DevicePaymentRole currentRole,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isTop,
    required bool isBottom,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = currentRole == role;

    return InkWell(
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(16) : Radius.zero,
        bottom: isBottom ? const Radius.circular(16) : Radius.zero,
      ),
      onTap: () {
        ref.read(paymentNotificationProvider.notifier).setRole(role);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.15)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? scheme.primary : scheme.outline,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? scheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.outline,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<DevicePaymentRole>(
              value: role,
              groupValue: currentRole,
              onChanged: (val) {
                if (val != null) {
                  ref.read(paymentNotificationProvider.notifier).setRole(val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAppIcon(String appId) {
    switch (appId) {
      case 'gobiz':
      case 'gopay':
      case 'dana':
      case 'shopeepay':
      case 'ovo':
      case 'grab_merchant':
        return Icons.account_balance_wallet_rounded;
      case 'livin_usaha':
      case 'livin':
      case 'bca_merchant':
      case 'bca':
      case 'brimo':
      case 'bni':
      case 'seabank':
      default:
        return Icons.account_balance_rounded;
    }
  }
}
