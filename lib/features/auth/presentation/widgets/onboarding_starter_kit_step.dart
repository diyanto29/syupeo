import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';
import 'package:dpos/core/widgets/syupeo_starter_kit_carousel.dart';
import 'package:dpos/features/subscription/domain/starter_kit_model.dart';
import 'package:dpos/features/subscription/presentation/providers/starter_kit_provider.dart';

/// ── WIDGET LANGKAH 2: PILIH PAKET USAHA (STARTER KITS) ──
class OnboardingStarterKitStep extends ConsumerWidget {
  const OnboardingStarterKitStep({
    super.key,
    required this.selectedKit,
    required this.onSelectKit,
    required this.onSubmitWithKit,
    required this.onSkip,
  });

  final StarterKit? selectedKit;
  final ValueChanged<StarterKit> onSelectKit;
  final VoidCallback onSubmitWithKit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starterKitsAsync = ref.watch(starterKitsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── HEADER INFO & PROMO BADGE ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        'Langkah 2 dari 2 • Paket Kemitraan',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        'Harga Promo @ Rp 200rb',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pilih Paket Usaha Awal Anda',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Setiap paket sudah termasuk stok fisik barang siap display, aplikasi kasir Syupeo gratis, dan katalog QRIS siap transaksi.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── PARALLAX CAROUSEL STARTER KITS ────────────────────────
          starterKitsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: StarterKitCardSkeleton(),
            ),
            error: (_, __) => SyupeoStarterKitCarousel(
              kits: StarterKit.defaultKits,
              selectedKitId: selectedKit?.id,
              onSelectKit: onSelectKit,
              ctaButtonText: 'Pesan Toko via WhatsApp',
              onCtaPressed: (kit) {
                onSelectKit(kit);
                onSubmitWithKit();
              },
            ),
            data: (kits) => SyupeoStarterKitCarousel(
              kits: kits,
              selectedKitId: selectedKit?.id,
              onSelectKit: onSelectKit,
              ctaButtonText: 'Pesan Toko via WhatsApp',
              onCtaPressed: (kit) {
                onSelectKit(kit);
                onSubmitWithKit();
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── TOMBOL LEWATI (LANGSUNG DASHBOARD) ────────────────────
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                'Lewati dulu, saya ingin melihat dashboard kasir →',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

