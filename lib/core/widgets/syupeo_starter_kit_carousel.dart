import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/features/subscription/domain/starter_kit_model.dart';

/// ── CAROUSEL PAKET USAHA SYUPEO DENGAN ANIMASI PARALAKS ──
/// Terinspirasi dari layout modern pricing cards (referensi Crextio):
/// - Desain kartu kontras tinggi: Kartu aktif di tengah bertema Dark Obsidian (#18181B)
///   dengan aksen emas/kuning, sedangkan kartu lainnya bertema Light (#FFFFFF).
/// - Efek animasi paralaks + scale halus saat di-swipe ke kiri/kanan.
/// - Menampilkan SELURUH item dalam paket tanpa pemotongan (+ 3 item lainnya).
/// - Top-right notch badge eksklusif ("FAVORIT KELUARGA", "TREN VIRAL", dll.).
/// - Indikator dot navigasi interaktif di bagian bawah.
class SyupeoStarterKitCarousel extends StatefulWidget {
  const SyupeoStarterKitCarousel({
    super.key,
    required this.kits,
    this.selectedKitId,
    required this.onSelectKit,
    this.ctaButtonText = 'Pilih Paket Ini',
    this.onCtaPressed,
    this.isActionWhatsApp = false,
  });

  final List<StarterKit> kits;
  final String? selectedKitId;
  final ValueChanged<StarterKit> onSelectKit;
  final String ctaButtonText;
  final void Function(StarterKit kit)? onCtaPressed;
  final bool isActionWhatsApp;

  @override
  State<SyupeoStarterKitCarousel> createState() =>
      _SyupeoStarterKitCarouselState();
}

class _SyupeoStarterKitCarouselState extends State<SyupeoStarterKitCarousel> {
  late final PageController _pageController;
  double _currentPage = 0.0;
  int _activePageIndex = 0;

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    int initialIndex = 0;
    if (widget.selectedKitId != null) {
      final found = widget.kits.indexWhere((k) => k.id == widget.selectedKitId);
      if (found != -1) initialIndex = found;
    } else {
      // Default to popular kit if available
      final popularIdx = widget.kits.indexWhere((k) => k.isPopular);
      if (popularIdx != -1) initialIndex = popularIdx;
    }

    _activePageIndex = initialIndex;
    _currentPage = initialIndex.toDouble();

    _pageController = PageController(
      initialPage: initialIndex,
      viewportFraction: 0.86,
    );

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
          final rounded = _currentPage.round();
          if (rounded != _activePageIndex && rounded >= 0 && rounded < widget.kits.length) {
            _activePageIndex = rounded;
            widget.onSelectKit(widget.kits[_activePageIndex]);
          }
        });
      }
    });

    // Notify initial selection after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.kits.isNotEmpty) {
        widget.onSelectKit(widget.kits[_activePageIndex]);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SyupeoStarterKitCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedKitId != null &&
        widget.selectedKitId != oldWidget.selectedKitId) {
      final idx = widget.kits.indexWhere((k) => k.id == widget.selectedKitId);
      if (idx != -1 && idx != _activePageIndex && _pageController.hasClients) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kits.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;

    // Viewport fraction disesuaikan agar card samping mengintip (peek) dengan rapi
    final effectiveViewport = isTablet ? 0.60 : 0.86;
    if (_pageController.viewportFraction != effectiveViewport) {
      // Re-create controller if viewport fraction changed between mobile/tablet
      // but retain current page
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── PARALLAX CAROUSEL ──────────────────────────────────────────
        SizedBox(
          height: 610,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.kits.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final kit = widget.kits[index];
              final diff = index - _currentPage;
              final absDiff = diff.abs().clamp(0.0, 1.0);

              // Animasi Scale & Translate Y untuk kedalaman 3D
              final scale = 1.0 - (absDiff * 0.08);
              final translateY = absDiff * 14.0;
              // Animasi pergeseran isi kartu (Paralaks horizontal)
              final parallaxOffset = diff * 22.0;

              // Kartu yang paling dekat ke pusat menjadi Dark Obsidian Hero Card
              final isHero = absDiff < 0.45;
              final isExplicitlySelected = widget.selectedKitId == kit.id;

              return Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: _StarterKitCard(
                    kit: kit,
                    isHero: isHero,
                    isSelected: isExplicitlySelected,
                    currencyFormat: _currencyFormat,
                    parallaxOffset: parallaxOffset,
                    ctaButtonText: widget.ctaButtonText,
                    isActionWhatsApp: widget.isActionWhatsApp,
                    onTapCard: () {
                      HapticFeedback.lightImpact();
                      if (_pageController.hasClients && _activePageIndex != index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                      widget.onSelectKit(kit);
                    },
                    onCtaPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.onSelectKit(kit);
                      if (widget.onCtaPressed != null) {
                        widget.onCtaPressed!(kit);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),

        // ── NAVIGATION CONTROLS & DOTS ─────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tombol Panah Kiri
            IconButton(
              onPressed: _activePageIndex > 0
                  ? () {
                      HapticFeedback.selectionClick();
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              color: _activePageIndex > 0 ? AppTheme.text : AppTheme.border,
              tooltip: 'Paket Sebelumnya',
            ),
            const SizedBox(width: 8),

            // Animated Dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.kits.length, (dotIndex) {
                final isCurrent = dotIndex == _activePageIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _pageController.animateToPage(
                      dotIndex,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primary
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),

            // Tombol Panah Kanan
            IconButton(
              onPressed: _activePageIndex < widget.kits.length - 1
                  ? () {
                      HapticFeedback.selectionClick();
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              color: _activePageIndex < widget.kits.length - 1
                  ? AppTheme.text
                  : AppTheme.border,
              tooltip: 'Paket Berikutnya',
            ),
          ],
        ),
      ],
    );
  }
}

/// ── INDIVIDUAL CARD COMPONENT ──────────────────────────────────────────────
class _StarterKitCard extends StatelessWidget {
  const _StarterKitCard({
    required this.kit,
    required this.isHero,
    required this.isSelected,
    required this.currencyFormat,
    required this.parallaxOffset,
    required this.ctaButtonText,
    required this.isActionWhatsApp,
    required this.onTapCard,
    required this.onCtaPressed,
  });

  final StarterKit kit;
  final bool isHero;
  final bool isSelected;
  final NumberFormat currencyFormat;
  final double parallaxOffset;
  final String ctaButtonText;
  final bool isActionWhatsApp;
  final VoidCallback onTapCard;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    // ── PALET WARNA RESMI SYUPEO DESIGN SYSTEM ──
    // Kartu Fokus/Aktif: Putih bersih dengan Radiant Blue Glow & Aksen #0070FC
    // Kartu Samping: Putih netral dengan border halus #E2E8F0
    final bgColor = Colors.white;
    final textColor = const Color(0xFF0F172A);
    final textMutedColor = const Color(0xFF64748B);
    final borderColor = isHero || isSelected
        ? AppTheme.primary
        : const Color(0xFFE2E8F0);
    final checkBgColor = const Color(0xFF10B981); // Emerald Green resmi Syupeo
    final dividerColor = const Color(0xFFF1F5F9);

    return GestureDetector(
      onTap: onTapCard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: borderColor,
            width: isHero || isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isHero || isSelected
                  ? const Color(0x2E0070FC) // Radiant blue glow
                  : const Color(0x0A000000),
              blurRadius: isHero || isSelected ? 22 : 8,
              offset: Offset(0, isHero || isSelected ? 8 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // ── KONTEN UTAMA KARTU ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header: Judul Paket
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            kit.name,
                            style: GoogleFonts.manrope(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Beri ruang untuk notch badge di kanan atas
                        const SizedBox(width: 84),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Harga Besar & Coretan Diskon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Coretan harga asli
                        if (kit.originalPrice != null) ...[
                          Text(
                            currencyFormat.format(kit.originalPrice),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textMutedColor,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: textMutedColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Harga resmi aktif (Syupeo Primary Blue)
                        Text(
                          currencyFormat.format(kit.price),
                          style: GoogleFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ paket fisik',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textMutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 3. Deskripsi Singkat Paket
                    if (kit.description != null) ...[
                      Text(
                        kit.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textMutedColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                    ],

                    Divider(height: 1, thickness: 1, color: dividerColor),
                    const SizedBox(height: 12),

                    // 4. DAFTAR LENGKAP FITUR & ITEM DALAM PAKET (TANPA PEMOTONGAN)
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(parallaxOffset * 0.4, 0),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Header list fitur
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'STOK & FASILITAS TERMASUK:',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),

                            // Loop SEMUA item dalam kit.itemsIncluded
                            ...kit.itemsIncluded.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 17,
                                      height: 17,
                                      decoration: BoxDecoration(
                                        color: checkBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF334155),
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Tambahan benefit standar Syupeo (selalu aktif)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 17,
                                    height: 17,
                                    decoration: BoxDecoration(
                                      color: checkBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Pengiriman Langsung dari Hub Gudang Syupeo',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF334155),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 5. TOMBOL AKSI UTAMA DI DALAM KARTU
                    _buildCardCtaButton(),
                  ],
                ),
              ),

              // ── TOP-RIGHT NOTCH BADGE (TAB POJOK KANAN ATAS) ──────────
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: kit.isPopular || isHero
                        ? const Color(0xFFFEF3C7) // Warm Amber Badge
                        : const Color(0xFFEFF6FF), // Soft Blue Badge
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(26),
                      bottomLeft: Radius.circular(16),
                      topLeft: Radius.circular(0),
                      bottomRight: Radius.circular(0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (kit.isPopular || isHero)
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFF92400E),
                        ),
                      if (kit.isPopular || isHero) const SizedBox(width: 4),
                      Text(
                        kit.badge ?? (kit.isPopular ? 'POPULER ⭐' : 'PAKET RESMI'),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: kit.isPopular || isHero
                              ? const Color(0xFF92400E)
                              : AppTheme.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardCtaButton() {
    if (isHero || isSelected) {
      // Focused / Selected Card CTA: Solid Syupeo Primary Blue
      return FilledButton(
        onPressed: onCtaPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActionWhatsApp || ctaButtonText.toLowerCase().contains('whatsapp')) ...[
              const Icon(Icons.chat_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              isActionWhatsApp ? 'Pesan via WhatsApp' : ctaButtonText,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    // Side Cards CTA: Soft Outline / Tonal Button
    return OutlinedButton(
      onPressed: onCtaPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF334155),
        side: const BorderSide(
          color: Color(0xFFCBD5E1),
          width: 1.2,
        ),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isActionWhatsApp || ctaButtonText.toLowerCase().contains('whatsapp')) ...[
            const Icon(Icons.chat_rounded, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            isActionWhatsApp ? 'Pesan via WhatsApp' : ctaButtonText,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

