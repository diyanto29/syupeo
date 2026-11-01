import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/subscription/presentation/views/starter_kit_orders_sheet.dart';

class PendingStoreActivationBanner extends ConsumerStatefulWidget {
  const PendingStoreActivationBanner({super.key});

  @override
  ConsumerState<PendingStoreActivationBanner> createState() =>
      _PendingStoreActivationBannerState();
}

class _PendingStoreActivationBannerState
    extends ConsumerState<PendingStoreActivationBanner> {
  static const String _csPhone = '6285624277920';
  Timer? _pollTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Auto-poll setiap 5 detik untuk mendeteksi aktivasi dari Admin Web
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final business = ref.read(homeBootstrapProvider).valueOrNull?.business;
        if (business != null && business.isPendingActivation) {
          ref.invalidate(homeBootstrapProvider);
        } else {
          _pollTimer?.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatusNow() async {
    if (_isChecking) return;
    HapticFeedback.lightImpact();
    setState(() => _isChecking = true);
    ref.invalidate(homeBootstrapProvider);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final business = bootstrap?.business;

    // Hanya tampilkan jika status toko adalah pending
    if (business == null || !business.isPendingActivation) {
      _pollTimer?.cancel();
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Soft Warm Amber
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            'MENUNGGU AKTIVASI ADMIN',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _checkStatusNow,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isChecking
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFD97706),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 13,
                                        color: Color(0xFF92400E),
                                      ),
                                const SizedBox(width: 4),
                                Text(
                                  'Cek Status',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toko Anda Sedang Menunggu Aktivasi',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pesanan paket usaha Anda telah terdaftar. Hubungi WhatsApp Admin untuk konfirmasi pembayaran agar akun kasir Anda segera diaktivasi.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final message =
                        'Halo Admin Syupeo, saya ingin konfirmasi pembayaran pesanan paket usaha untuk toko "${business.name}" agar akun dapat segera diaktivasi. Terima kasih!';
                    final uri = Uri.parse(
                      'https://wa.me/$_csPhone?text=${Uri.encodeComponent(message)}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                  label: Text(
                    'Chat Admin WA',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF78350F),
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => StarterKitOrdersSheet.show(context),
                  icon: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: Text(
                    'Lihat Riwayat & Status',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
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
