import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/domain/subscription_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/subscription/data/subscription_repository.dart';

class _ProDuration {
  final String label;
  final String code;
  final int months;
  final bool isLifetime;
  final num price;
  final double? originalPrice;
  final String subtitle;
  final String? badge;

  const _ProDuration({
    required this.label,
    required this.code,
    required this.months,
    this.isLifetime = false,
    required this.price,
    this.originalPrice,
    required this.subtitle,
    this.badge,
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  int? get discountPercentage {
    if (!hasDiscount) return null;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }
}

List<_ProDuration> _buildProDurationOptions(SubscriptionPlan? proPlan) {
  if (proPlan != null) {
    final activeTiers = proPlan.getActiveProTiers();
    if (activeTiers.isNotEmpty) {
      return activeTiers
          .map(
            (t) => _ProDuration(
              label: t.label,
              code: t.code,
              months: t.months,
              isLifetime: t.isLifetime,
              price: t.price,
              originalPrice: t.originalPrice,
              subtitle: t.subtitle,
              badge: t.badge,
            ),
          )
          .toList();
    }
  }

  // Fallback default jika data paket belum termuat dari server
  return const [
    _ProDuration(
      label: '1 Bulan',
      code: '1_month',
      months: 1,
      price: 49000.0,
      subtitle: '/bulan',
    ),
  ];
}

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? selectedPlanCode;
  int selectedDurationIndex = 4; // Default to Lifetime (paling menarik)

  Future<void> _launchWhatsApp({
    required String businessName,
    required String businessId,
    required String durationLabel,
    required num price,
  }) async {
    const phone = '6285624277920';
    final formattedPrice = currencyFormat.format(price);
    final message =
        'Halo Admin Mangga POS, saya ingin upgrade ke Paket Pro ($durationLabel - $formattedPrice) untuk bisnis $businessName (ID: $businessId). Mohon info langkah aktivasi selanjutnya. Terima kasih!';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final business = bootstrap?.business;
    final currentPlanCode = business?.plan?.code ?? 'free';

    final businessName = business?.name ?? 'Bisnis Saya';
    final businessId = business?.id ?? '-';
    final isCurrentlyPro = business?.isPro ?? false;
    final isTrial = business?.isTrialActive ?? false;
    final isLifetime = business?.isLifetime ?? false;
    final isExpired = business?.isExpired ?? false;
    final remainingDays = business?.remainingDays;

    selectedPlanCode ??= currentPlanCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Paket & Langganan'),
        centerTitle: false,
      ),
      body: plansAsync.when(
        data: (allPlans) {
          final plans = allPlans
              .where((p) => p.code == 'free' || p.code == 'pro')
              .toList();

          final freePlan = plans.firstWhere(
            (p) => p.code == 'free',
            orElse: () => plans.isNotEmpty ? plans.first : const SubscriptionPlan(
              id: 'free',
              name: 'Free Plan',
              code: 'free',
              maxTransactionsMonth: 150,
              maxProducts: 50,
              maxOutlets: 1,
              features: {},
              priceMonthly: 0,
            ),
          );
          final proPlan = plans.firstWhere(
            (p) => p.code == 'pro',
            orElse: () => plans.isNotEmpty ? plans.last : const SubscriptionPlan(
              id: 'pro',
              name: 'Pro Plan',
              code: 'pro',
              maxTransactionsMonth: 999999,
              maxProducts: 999999,
              maxOutlets: 5,
              features: {},
              priceMonthly: 49000,
            ),
          );

          final selectedPlan = plans.firstWhere(
            (p) => p.code == selectedPlanCode,
            orElse: () => freePlan,
          );

          final proDurationOptions = _buildProDurationOptions(proPlan);
          final safeDurationIndex = selectedDurationIndex.clamp(0, proDurationOptions.length - 1);
          final selectedDuration = proDurationOptions[safeDurationIndex];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // ── Current Status Banner (jika Pro, Trial, atau Expired) ──
                      if (isCurrentlyPro || isTrial || isExpired) ...[
                        _CurrentSubscriptionBanner(
                          isLifetime: isLifetime,
                          isTrial: isTrial,
                          isExpired: isExpired,
                          remainingDays: remainingDays,
                          endDate: business?.subscriptionEndAt,
                          showAds: business?.showAds,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Toggle Free / Pro Only
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: plans
                              .map(
                                (plan) => _PlanToggleButton(
                                  label: plan.name.split(' ').first,
                                  isActive: selectedPlanCode == plan.code,
                                  isHot: plan.code == 'pro',
                                  onTap: () => setState(
                                    () => selectedPlanCode = plan.code,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Duration Selector (Khusus untuk Paket Pro)
                      if (selectedPlanCode == 'pro') ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Pilih Durasi Paket Pro:',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              proDurationOptions.length,
                              (index) {
                                final opt = proDurationOptions[index];
                                final isSelected =
                                    safeDurationIndex == index;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(
                                      opt.badge != null
                                          ? '${opt.label} (${opt.badge})'
                                          : opt.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFFFF7A00),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFFFF7A00)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          selectedDurationIndex = index;
                                        });
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Display selected plan card
                      _PriceCard(
                        title: selectedPlanCode == 'pro'
                            ? (selectedDuration.isLifetime
                                ? 'Paket Pro Lifetime'
                                : 'Paket Pro ${selectedDuration.label}')
                            : selectedPlan.name,
                        price: selectedPlanCode == 'free'
                            ? 'Gratis'
                            : currencyFormat.format(selectedDuration.price),
                        originalPrice: (selectedPlanCode == 'pro' &&
                                selectedDuration.hasDiscount)
                            ? currencyFormat.format(selectedDuration.originalPrice!)
                            : null,
                        discountBadge: (selectedPlanCode == 'pro' &&
                                selectedDuration.discountPercentage != null)
                            ? 'HEMAT ${selectedDuration.discountPercentage}%'
                            : null,
                        subtitle: selectedPlanCode == 'free'
                            ? ''
                            : selectedDuration.subtitle,
                        description: selectedPlanCode == 'free'
                            ? 'Solusi kasir esensial untuk memulai bisnis Anda tanpa biaya langganan selamanya.'
                            : (selectedDuration.isLifetime
                                ? 'Sekali bayar aktif selamanya! Nikmati fitur dapur pintar, multi-outlet, dan laporan lengkap tanpa biaya bulanan.'
                                : 'Luncurkan efisiensi maksimal dengan fitur dapur pintar dan sistem pemesanan mandiri.'),
                        features: selectedPlanCode == 'free'
                            ? [
                                'Dashboard Penjualan Dasar',
                                'Riwayat Transaksi & Cetak Struk',
                                'Manajemen Staf & Hak Akses',
                                'Katalog Produk & Retail POS',
                                'Manajemen Diskon & Voucher',
                                'Refund & Pembatalan Transaksi',
                                'Notifikasi Pesanan Masuk (App)',
                                'Maks. ${selectedPlan.maxProducts} Produk',
                              ]
                            : [
                                'SEMUA FITUR PAKET FREE',
                                'Arus Kas & Manajemen Shift Kasir',
                                'Cetak Bluetooth Thermal Printer',
                                'Notifikasi Push Real-time ke HP',
                                'Kitchen Display System (KDS)',
                                'Self-Ordering QR Meja Resto',
                                'Manajemen Stok & Inventori',
                                'Harga Bertingkat (Grosir/Member)',
                                'Multi-Outlet Cabang Bisnis',
                                'Ekspor Laporan PDF/Excel/CSV',
                                'Bebas Iklan Selamanya',
                              ],
                        isPopular: selectedPlanCode == 'pro',
                        isCurrent: selectedPlanCode == currentPlanCode &&
                            !isExpired &&
                            (selectedPlanCode == 'free' ||
                                (isLifetime == selectedDuration.isLifetime)),
                        buttonText: selectedPlanCode == 'free'
                            ? (currentPlanCode == 'free'
                                ? 'Paket Aktif Saat Ini'
                                : 'Paket Free')
                            : (isCurrentlyPro
                                ? 'Perpanjang (${selectedDuration.label})'
                                : 'Upgrade (${selectedDuration.label})'),
                        onUpgrade: () => _launchWhatsApp(
                          businessName: businessName,
                          businessId: businessId,
                          durationLabel: selectedDuration.label,
                          price: selectedDuration.price,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Full Comparison Table
                      Row(
                        children: [
                          const Icon(
                            Icons.compare_arrows_rounded,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Perbandingan Fitur Lengkap',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ComparisonTable(freePlan: freePlan, proPlan: proPlan),

                      const SizedBox(height: 40),
                      _ElevateBanner(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat paket: $err')),
      ),
    );
  }
}

// ── Banner Status Langganan Saat Ini ─────────────────────────
class _CurrentSubscriptionBanner extends StatelessWidget {
  final bool isLifetime;
  final bool isTrial;
  final bool isExpired;
  final int? remainingDays;
  final DateTime? endDate;
  final bool? showAds;

  const _CurrentSubscriptionBanner({
    required this.isLifetime,
    this.isTrial = false,
    required this.isExpired,
    this.remainingDays,
    this.endDate,
    this.showAds,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

    if (isExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF87171)),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masa Aktif Paket Telah Berakhir',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF991B1B),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Perpanjang paket sekarang untuk mengaktifkan kembali fitur Pro Anda.',
                    style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isTrial) {
      final isAdFree = showAds == false;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLifetime
                        ? 'Masa Uji Coba Pro Aktif (Selamanya)'
                        : 'Masa Uji Coba Pro (Sisa ${remainingDays ?? 0} Hari)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF312E81),
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isAdFree
                        ? 'Fitur Pro terbuka penuh tanpa iklan untuk toko Anda.'
                        : 'Fitur Pro aktif. Upgrade ke Pro Berbayar untuk menghilangkan iklan secara permanen.',
                    style: const TextStyle(
                      color: Color(0xFF4338CA),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isLifetime) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 28)),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paket Pro Lifetime Aktif',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bisnis Anda aktif seumur hidup tanpa batas waktu.',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Pro berjangka
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paket Pro Aktif (Sisa ${remainingDays ?? 0} Hari)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                    fontSize: 14,
                  ),
                ),
                if (endDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Berlaku hingga ${dateFormat.format(endDate!)}',
                    style: const TextStyle(color: Color(0xFF15803D), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tombol Switch Plan ─────────────────────────────────────────
class _PlanToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isHot;
  final VoidCallback onTap;

  const _PlanToggleButton({
    required this.label,
    required this.isActive,
    this.isHot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
            if (isHot) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'HOT',
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Kartu Harga ───────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  final String title;
  final String price;
  final String? originalPrice;
  final String? discountBadge;
  final String subtitle;
  final String description;
  final List<String> features;
  final bool isPopular;
  final bool isCurrent;
  final String buttonText;
  final VoidCallback onUpgrade;

  const _PriceCard({
    required this.title,
    required this.price,
    this.originalPrice,
    this.discountBadge,
    required this.subtitle,
    required this.description,
    required this.features,
    this.isPopular = false,
    this.isCurrent = false,
    this.buttonText = 'Pilih Paket',
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isPopular
              ? const Color(0xFFFF7A00).withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? const Color(0xFFFF7A00).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPopular
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPopular
                      ? Icons.workspace_premium_rounded
                      : Icons.storefront_rounded,
                  color: isPopular
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (originalPrice != null && originalPrice!.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  originalPrice!,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: const Color(0xFFEF4444),
                    decorationThickness: 2,
                  ),
                ),
                if (discountBadge != null && discountBadge!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      discountBadge!,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
          ],
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            alignment: WrapAlignment.start,
            spacing: 6,
            runSpacing: 2,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  price,
                  style: GoogleFonts.manrope(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF15803D),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isCurrent ? null : onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    buttonText,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tabel Perbandingan ────────────────────────────────────────
class _ComparisonTable extends StatelessWidget {
  final SubscriptionPlan freePlan;
  final SubscriptionPlan proPlan;

  const _ComparisonTable({required this.freePlan, required this.proPlan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _ComparisonRow(
            title: 'Cetak Printer Bluetooth',
            subtitle: 'Struk kasir thermal 58mm/80mm',
            isFreeEnabled: true,
            isProEnabled: true,
          ),
          _ComparisonRow(
            title: 'Arus Kas & Shift Kasir',
            subtitle: 'Kontrol kas laci, kas operasional, & selisih shift',
            isFreeEnabled: freePlan.isFeatureEnabled('cash_flow'),
            isProEnabled: proPlan.isFeatureEnabled('cash_flow') || true,
          ),
          _ComparisonRow(
            title: 'Kitchen Display (KDS)',
            subtitle: 'Layar pesanan dapur real-time',
            isFreeEnabled: freePlan.isFeatureEnabled('kds'),
            isProEnabled: proPlan.isFeatureEnabled('kds'),
          ),
          _ComparisonRow(
            title: 'Self-Ordering QR Meja',
            subtitle: 'Pelanggan pesan mandiri via scan QR',
            isFreeEnabled: freePlan.isFeatureEnabled('qr_ordering'),
            isProEnabled: proPlan.isFeatureEnabled('qr_ordering'),
          ),
          _ComparisonRow(
            title: 'Stok & Inventori Bahan',
            subtitle: 'Audit stok otomatis saat transaksi',
            isFreeEnabled: freePlan.isFeatureEnabled('inventory_management'),
            isProEnabled: proPlan.isFeatureEnabled('inventory_management'),
          ),
          _ComparisonRow(
            title: 'Harga Grosir & Member',
            subtitle: 'Tiered pricing per kategori pembeli',
            isFreeEnabled: freePlan.isFeatureEnabled('tiered_pricing'),
            isProEnabled: proPlan.isFeatureEnabled('tiered_pricing'),
          ),
          _ComparisonRow(
            title: 'Ekspor Laporan Lengkap',
            subtitle: 'Download rekap penjualan ke Excel & PDF',
            isFreeEnabled: freePlan.isFeatureEnabled('advanced_reports'),
            isProEnabled: proPlan.isFeatureEnabled('advanced_reports'),
          ),
          _ComparisonRow(
            title: 'Batas Produk & Cabang',
            subtitle: 'Kapasitas menu dan outlet toko',
            freeLabel: '${freePlan.maxProducts} Menu • 1 Cabang',
            proLabel: 'Unlimited Menu • Multi-Cabang',
            isFreeEnabled: true,
            isProEnabled: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? freeLabel;
  final String? proLabel;
  final bool isFreeEnabled;
  final bool isProEnabled;

  const _ComparisonRow({
    required this.title,
    required this.subtitle,
    this.freeLabel,
    this.proLabel,
    required this.isFreeEnabled,
    required this.isProEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF1E293B),
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
          _StatusIcon(isEnabled: isFreeEnabled, label: freeLabel, isPro: false),
          const SizedBox(width: 20),
          _StatusIcon(isEnabled: isProEnabled, label: proLabel, isPro: true),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isEnabled;
  final String? label;
  final bool isPro;

  const _StatusIcon({required this.isEnabled, this.label, required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isEnabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isEnabled
              ? (isPro ? const Color(0xFFFF7A00) : const Color(0xFF15803D))
              : const Color(0xFFCBD5E1),
          size: 18,
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label!,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isPro
                    ? const Color(0xFFFF7A00)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }
}

class _ElevateBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mangga POS Pro', style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            'Tingkatkan skala bisnis kasir Anda ke level berikutnya.',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
