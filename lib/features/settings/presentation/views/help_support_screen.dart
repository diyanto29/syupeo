import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';
import 'package:dpos/features/subscription/presentation/views/subscription_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: false,
      ),
      body: const SafeArea(
        child: HelpSupportView(),
      ),
    );
  }
}

class HelpSupportView extends ConsumerWidget {
  const HelpSupportView({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  static const String developerName = 'Diyanto';
  static const String developerRole = 'Software Engineer';
  static const String developerPhone = '+6285624277920';
  static const String developerWaPhone = '6285624277920';
  static const String developerEmail = 'diyanto2911@gmail.com';
  static const String documentationUrl = 'https://pos.mudahkan.online/panduan';
  static const String websiteUrl = 'https://pos.mudahkan.online/';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchWhatsApp(String message) async {
    final url =
        'https://wa.me/$developerWaPhone?text=${Uri.encodeComponent(message)}';
    await _launchUrl(url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final business = bootstrap?.business;

    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // ── 1. Hero Card ─────────────────────────────────────────────
        _buildHeroCard(context),

        const SizedBox(height: 18),

        // ── 2. Status Akun & Masa Aktif ──────────────────────────────
        if (business != null) ...[
          _buildSubscriptionStatusCard(context, ref, business),
          const SizedBox(height: 18),
        ],

        // ── 3. Buku Panduan Lengkap Card ─────────────────────────────
        _buildGuideCard(context),

        const SizedBox(height: 18),

        // ── 4. Developer & Technical Support Card ───────────────────
        _buildDeveloperCard(context, business),

        const SizedBox(height: 18),

        // ── 5. Quick FAQ Section ─────────────────────────────────────
        _buildFaqSection(context),

        const SizedBox(height: 24),

        // ── 6. Footer Info ───────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Text(
                'MANGGA POS v1.0.0',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Platform Kasir & Menu Digital by Mudahkan.online',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hero Card ─────────────────────────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7A00).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'PUSAT BANTUAN RESMI',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF9E40),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pusat Bantuan & Panduan',
                        style: GoogleFonts.manrope(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pelajari panduan penggunaan atau hubungi developer langsung untuk konsultasi sistem.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
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
    );
  }

  // ── Status Akun & Masa Aktif Card ─────────────────────────────────────────
  Widget _buildSubscriptionStatusCard(
    BuildContext context,
    WidgetRef ref,
    Business business,
  ) {
    final dateFormat = DateFormat('d MMMM yyyy', 'id_ID');
    final isPro = business.isPro;
    final isLifetime = business.isLifetime;
    final isExpired = business.isExpired;
    final remainingDays = business.remainingDays;

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (isLifetime) {
      badgeBg = const Color(0xFFFFFBEB);
      badgeBorder = const Color(0xFFFDE68A);
      badgeText = const Color(0xFFB45309);
      statusTitle = '👑 Paket Pro Lifetime';
      statusSubtitle = 'Masa Aktif: Selamanya (Aktif Permanen)';
      statusIcon = Icons.workspace_premium_rounded;
    } else if (isPro && !isExpired) {
      badgeBg = const Color(0xFFECFDF5);
      badgeBorder = const Color(0xFFA7F3D0);
      badgeText = const Color(0xFF047857);
      statusTitle = '✨ Paket Pro Aktif';
      final endStr = business.subscriptionEndAt != null
          ? dateFormat.format(business.subscriptionEndAt!)
          : '-';
      statusSubtitle = 'Sisa Masa Aktif: $remainingDays Hari (s/d $endStr)';
      statusIcon = Icons.verified_rounded;
    } else if (isExpired) {
      badgeBg = const Color(0xFFFEF2F2);
      badgeBorder = const Color(0xFFFECACA);
      badgeText = const Color(0xFFB91C1C);
      statusTitle = '⚠️ Paket Pro Kedaluwarsa';
      final endStr = business.subscriptionEndAt != null
          ? dateFormat.format(business.subscriptionEndAt!)
          : '-';
      statusSubtitle = 'Berakhir pada: $endStr (Perpanjang sekarang)';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeBorder = const Color(0xFFE2E8F0);
      badgeText = const Color(0xFF475569);
      statusTitle = '🌱 Paket Free (Gratis)';
      statusSubtitle = 'Maksimal 50 produk & 150 transaksi/bln';
      statusIcon = Icons.storefront_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STATUS & MASA AKTIF',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: badgeText),
                    const SizedBox(width: 5),
                    Text(
                      isPro
                          ? (isLifetime ? 'LIFETIME' : 'PRO')
                          : (isExpired ? 'EXPIRED' : 'FREE'),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            statusTitle,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusSubtitle,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to Subscription Screen
                ref.read(ownerSelectedMenuProvider.notifier).state =
                    OwnerMenu.subscription;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(
                isPro && !isExpired
                    ? 'Lihat Detail Paket & Langganan'
                    : 'Upgrade ke Paket Pro ⚡',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPro && !isExpired
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Buku Panduan Card ─────────────────────────────────────────────────────
  Widget _buildGuideCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFFFF7A00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUKU PANDUAN ONLINE (18 BAB)',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF7A00),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Tutorial Lengkap Penggunaan',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Panduan langkah demi langkah penggunaan fitur Mangga POS lengkap beserta gambar dan tutorial:',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip('1. Setup & Login Google'),
              _buildFeatureChip('2. Master Katalog 32k Ritel ⚡'),
              _buildFeatureChip('3. Buku Kasbon & Tempo 📖'),
              _buildFeatureChip('4. Diskon Kategori & Promo'),
              _buildFeatureChip('5. Printer Bluetooth Thermal'),
              _buildFeatureChip('6. QRIS Statis Merchant'),
              _buildFeatureChip('7. Resep & Inventori'),
              _buildFeatureChip('8. Menu Digital QR Meja'),
              _buildFeatureChip('9. Ekspor Laporan Excel'),
              _buildFeatureChip('10. Panduan Windows & Printer USB 🖥️'),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _launchUrl(documentationUrl),
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: Text(
                'Buka Buku Panduan Online ↗',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  // ── Developer Card ─────────────────────────────────────────────────────────
  Widget _buildDeveloperCard(BuildContext context, Business? business) {
    final businessName = business?.name ?? 'Toko Saya';
    final businessId = business?.id ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KONTAK DEVELOPER RESMI',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Informasi & Kontak Pengembang',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Developer Profile Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFFF7A00),
                  child: Text(
                    'D',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        developerName,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        developerRole,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF7A00),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mudahkan.online • Indramayu, Jawa Barat',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Direct Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final msg =
                          'Halo Mas $developerName, saya ingin berkonsultasi seputar aplikasi Mangga POS untuk bisnis "$businessName" (ID: $businessId).';
                      _launchWhatsApp(msg);
                    },
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(
                      'WhatsApp Dev',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchUrl('tel:$developerPhone'),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(
                      'Telepon',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Phone & Email details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      developerPhone,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                Text(
                  'WhatsApp Aktif',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FAQ Section ────────────────────────────────────────────────────────────
  Widget _buildFaqSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              'TANYA JAWAB CEPAT (FAQ)',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildFaqTile(
            question: 'Bagaimana cara scan Master Katalog 32.000+ produk?',
            answer:
                'Pada menu Produk atau Kasir, tekan tombol scanner kamera atau gunakan scanner fisik. Ketika barcode produk kelontong/minimarket terdeteksi, nama, kategori, dan estimasi harga otomatis terisi tanpa perlu mengetik manual.',
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildFaqTile(
            question: 'Bagaimana cara menyambungkan printer bluetooth?',
            answer:
                'Buka menu Pengaturan -> Pengaturan Printer. Hidupkan Bluetooth di perangkat Anda, tekan "Pindai Perangkat", lalu pilih printer thermal Anda (tersedia ukuran 58mm atau 80mm).',
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildFaqTile(
            question: 'Bagaimana jika masa aktif Pro berakhir?',
            answer:
                'Akun Anda otomatis kembali ke mode Paket Free tanpa ada data produk atau riwayat transaksi yang hilang. Anda bisa memperpanjang paket Pro kapan saja untuk kembali menikmati fitur tanpa batas.',
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildFaqTile(
            question: 'Apakah data toko tersimpan aman di Cloud?',
            answer:
                'Ya, seluruh data produk, stok, transaksi, dan riwayat kasir tersimpan aman di Cloud Supabase secara real-time. Jika Anda berganti HP atau tablet, cukup login dengan akun Google yang sama dan seluruh data akan langsung sinkron.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Text(
          question,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        children: [
          Text(
            answer,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
