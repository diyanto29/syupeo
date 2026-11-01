import 'package:flutter/material.dart';
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

class SyupeoStarterKitsShowcase extends ConsumerWidget {
  const SyupeoStarterKitsShowcase({super.key});

  static const String _marketingPhone = '6285624277920';

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> _orderViaWhatsApp(
    BuildContext context,
    WidgetRef ref,
    StarterKit kit,
  ) async {
    final bootstrap = ref.read(homeBootstrapProvider).valueOrNull;
    final businessName = bootstrap?.business?.name ?? 'Toko Saya';
    final ownerName = bootstrap?.profile?.fullName ?? 'Mitra Syupeo';

    final message =
        'Halo Tim Marketing Syupeo! Saya pemilik *$businessName* (Owner: $ownerName) ingin memesan *${kit.name}* (${_currencyFormat.format(kit.price)}) untuk mengisi etalase kasir saya. Mohon info pembayaran & pengiriman barangnya. Terima kasih!';

    final uri = Uri.parse(
      'https://wa.me/$_marketingPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka WhatsApp: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starterKitsAsync = ref.watch(starterKitsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icons/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Etalase Kasir Belum Memiliki Produk',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih salah satu Paket Usaha Syupeo di bawah ini untuk langsung mengisi kasir dengan produk fisik siap jual, barcode resmi, dan mengaktifkan transaksi.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manual Product Notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Fitur tambah produk manual dinonaktifkan. Seluruh katalog & stok dipasok resmi oleh Syupeo.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textBody,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title Section
              Row(
                children: [
                  Text(
                    'Pilihan Paket Usaha Resmi Syupeo',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'Promo @ Rp 200.000',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Carousel Cards dengan Animasi Paralaks
              starterKitsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: StarterKitCardSkeleton(),
                ),
                error: (_, __) => SyupeoStarterKitCarousel(
                  kits: StarterKit.defaultKits,
                  onSelectKit: (_) {},
                  isActionWhatsApp: true,
                  onCtaPressed: (kit) => _orderViaWhatsApp(context, ref, kit),
                ),
                data: (kits) => SyupeoStarterKitCarousel(
                  kits: kits,
                  onSelectKit: (_) {},
                  isActionWhatsApp: true,
                  onCtaPressed: (kit) => _orderViaWhatsApp(context, ref, kit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
