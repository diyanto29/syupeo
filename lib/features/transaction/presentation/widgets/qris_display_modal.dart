import 'dart:async';
import 'dart:io';
import 'package:dpos/core/services/payment_notification_models.dart';
import 'package:dpos/core/services/payment_notification_service.dart';
import 'package:dpos/core/services/qris_dynamic_generator.dart';
import 'package:dpos/features/settings/data/qris_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrisDisplayModal extends ConsumerStatefulWidget {
  const QrisDisplayModal({
    super.key,
    required this.settings,
    required this.totalAmount,
    this.onConfigurePressed,
  });

  final QrisSettings settings;
  final double totalAmount;
  final VoidCallback? onConfigurePressed;

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Menampilkan popup QRIS ke pelanggan di layar kasir
  static Future<bool?> show(
    BuildContext context, {
    required QrisSettings settings,
    required double totalAmount,
    VoidCallback? onConfigurePressed,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              color: Theme.of(context).cardColor,
              child: QrisDisplayModal(
                settings: settings,
                totalAmount: totalAmount,
                onConfigurePressed: onConfigurePressed,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<QrisDisplayModal> createState() => _QrisDisplayModalState();
}

class _QrisDisplayModalState extends ConsumerState<QrisDisplayModal> {
  bool _showStaticImage = false;
  StreamSubscription<DetectedPaymentEvent>? _paymentSub;
  DetectedPaymentEvent? _detectedEvent;

  @override
  void initState() {
    super.initState();
    _listenToPaymentNotification();
  }

  void _listenToPaymentNotification() {
    final notifier = ref.read(paymentNotificationProvider.notifier);

    // 1. Cek antrean lokal di memori
    final queue = notifier.recentQueue;
    for (final ev in queue) {
      if ((ev.amount - widget.totalAmount).abs() < 1) {
        _onPaymentReceived(ev);
        return;
      }
    }

    // 2. Cek juga cloud database Supabase (jika pelanggan sudah transfer sebelum kasir buka QR)
    notifier.checkExistingUnconsumedPayment(widget.totalAmount).then((ev) {
      if (ev != null && mounted) {
        _onPaymentReceived(ev);
      }
    });

    // 3. Dengarkan event masuk secara realtime
    _paymentSub = notifier.paymentEvents.listen((event) {
      if (!mounted) return;
      if ((event.amount - widget.totalAmount).abs() < 1) {
        _onPaymentReceived(event);
      }
    });
  }

  void _onPaymentReceived(DetectedPaymentEvent event) {
    setState(() {
      _detectedEvent = event;
    });
    HapticFeedback.heavyImpact();
    ref.read(paymentNotificationProvider.notifier).markAsUsed(event.id);

    // Otomatis tutup dialog sukses dan konfirmasi pembayaran setelah 850ms
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _paymentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = widget.settings;
    final totalAmount = widget.totalAmount;
    final hasImage = settings.hasQrisImage;
    final hasPayload = settings.hasQrisPayload;

    // Hitung string QRIS dinamis jika payload tersedia dan fitur dinamis aktif
    final canUseDynamic = hasPayload && settings.enableDynamicQris && totalAmount > 0;
    final dynamicPayload = canUseDynamic
        ? QrisDynamicGenerator.generateDynamicQris(
            rawQris: settings.qrisPayload!,
            amount: totalAmount,
          )
        : settings.qrisPayload;

    final isRenderingDynamic = canUseDynamic && !_showStaticImage;
    final hasAnyQr = isRenderingDynamic || hasImage;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Close button & Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRenderingDynamic
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: isRenderingDynamic
                          ? const Color(0xFF059669)
                          : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QRIS Pembayaran',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (isRenderingDynamic)
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'QRIS Dinamis Otomatis',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: 'Tutup',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Total Tagihan Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isRenderingDynamic
                  ? const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Total Tagihan Kasir',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  QrisDisplayModal._currency.format(totalAmount),
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                if (settings.merchantName != null &&
                    settings.merchantName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    settings.merchantName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.amber.shade300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Notification Detected Banner (Auto Confirm status)
          if (_detectedEvent != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF047857),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PEMBAYARAN DITERIMA!',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_detectedEvent!.appName}: ${QrisDisplayModal._currency.format(_detectedEvent!.amount)}'
                    '${_detectedEvent!.sender != null ? "\nDari: ${_detectedEvent!.sender}" : ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF047857),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Menyelesaikan transaksi otomatis...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // QR Display (Dinamis via QrImageView ATAU Statis via Image.file)
          if (isRenderingDynamic && dynamicPayload != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _detectedEvent != null ? const Color(0xFF059669) : const Color(0xFF10B981),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: dynamicPayload,
                    version: QrVersions.auto,
                    size: 230,
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      'Nominal ${QrisDisplayModal._currency.format(totalAmount)} terkunci otomatis',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pelanggan scan langsung bayar tanpa perlu mengetik nominal lagi!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF047857),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasImage) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(() => _showStaticImage = true),
                icon: const Icon(Icons.image_outlined, size: 15),
                label: const Text(
                  'Tampilkan Foto QRIS Asli Toko',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ] else if (hasImage) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(settings.imagePath!),
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 240,
                      height: 240,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Text(
                          'Gambar QRIS tidak dapat dimuat',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan menggunakan GoPay, OVO, DANA, BCA, Livin, ShopeePay, dll',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (canUseDynamic && _showStaticImage) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(() => _showStaticImage = false),
                icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF059669)),
                label: const Text(
                  'Kembali ke QRIS Dinamis (Auto Nominal)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ] else ...[
            // Placeholder if not uploaded yet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFD97706),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'QRIS Toko Belum Diatur',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unggah atau scan kode QRIS toko Anda di menu Pengaturan agar kode QR dinamis muncul di sini.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF78350F),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      widget.onConfigurePressed?.call();
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Atur QRIS Toko Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons (Bisa Konfirmasi Manual kapan saja)
          if (hasAnyQr && _detectedEvent == null) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  'Konfirmasi Manual (Sudah Bayar)',
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Otomatis deteksi aktif, atau tekan tombol di atas untuk manual',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF047857),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Tutup',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
