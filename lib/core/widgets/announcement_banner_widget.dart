import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart';

final announcementDismissedProvider = StateProvider<bool>((ref) => false);

/// Data model pengumuman dari database Supabase (diatur dari Web Admin)
class SystemAnnouncement {
  final String id;
  final String title;
  final String message;
  final String badgeText;
  final String type; // 'feature', 'info', 'warning', 'promo'
  final String targetCriteria; // 'all', 'missing_location', 'free_plan', 'pro_plan'
  final String actionType; // 'route', 'url'
  final String actionTarget;
  final String actionLabel;
  final String? secondaryActionTarget;
  final String? secondaryActionLabel;
  final bool isActive;

  const SystemAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.badgeText,
    required this.type,
    required this.targetCriteria,
    required this.actionType,
    required this.actionTarget,
    required this.actionLabel,
    this.secondaryActionTarget,
    this.secondaryActionLabel,
    required this.isActive,
  });

  factory SystemAnnouncement.fromJson(Map<String, dynamic> json) {
    return SystemAnnouncement(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Pengumuman',
      message: json['message'] as String? ?? '',
      badgeText: json['badge_text'] as String? ?? 'PENGUMUMAN FITUR BARU',
      type: json['type'] as String? ?? 'feature',
      targetCriteria: json['target_criteria'] as String? ?? 'all',
      actionType: json['action_type'] as String? ?? 'route',
      actionTarget: json['action_target'] as String? ?? 'businessProfileEdit',
      actionLabel: json['action_label'] as String? ?? 'Atur Sekarang',
      secondaryActionTarget: json['secondary_action_target'] as String?,
      secondaryActionLabel: json['secondary_action_label'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Provider untuk mengambil pengumuman aktif dari tabel system_announcements
final activeAnnouncementsProvider =
    FutureProvider.autoDispose<List<SystemAnnouncement>>((ref) async {
  if (!SupabaseService.isConfigured || !SupabaseService.isLoggedIn) {
    return [];
  }

  try {
    final response = await SupabaseService.client
        .from('system_announcements')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => SystemAnnouncement.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('[AnnouncementBanner] Error fetching announcements: $e');
    return [];
  }
});

/// Announcement Banner pintar untuk mengingatkan merchant terhadap fitur baru
/// atau konfigurasi toko yang belum lengkap.
///
/// Banner ini dikontrol langsung secara realtime dari portal Web Admin (`/dashboard/announcements`).
/// Jika kriteria targetnya adalah `missing_location`, maka:
/// - Jika toko SUDAH mengatur koordinat GPS (`latitude != null && longitude != null`),
///   banner ini OTOMATIS TIDAK MUNCUL (`SizedBox.shrink`).
class AnnouncementBannerWidget extends ConsumerWidget {
  const AnnouncementBannerWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDismissed = ref.watch(announcementDismissedProvider);
    if (isDismissed) return const SizedBox.shrink();

    final bootstrap = ref.watch(homeBootstrapProvider).value;
    if (bootstrap == null) return const SizedBox.shrink();

    final business = bootstrap.business;
    final currentOutlet = bootstrap.currentOutlet;

    // Cek status koordinat GPS toko
    final hasBusinessLocation =
        business?.latitude != null && business?.longitude != null;
    final hasOutletLocation =
        currentOutlet?.latitude != null && currentOutlet?.longitude != null;
    final hasLocation = hasBusinessLocation || hasOutletLocation;

    final announcementsAsync = ref.watch(activeAnnouncementsProvider);

    return announcementsAsync.when(
      data: (announcements) {
        // Cari pengumuman yang sesuai dengan kriteria toko
        SystemAnnouncement? matchedAnnouncement;

        for (final item in announcements) {
          if (!item.isActive) continue;

          if (item.targetCriteria == 'missing_location') {
            // Hanya tampil jika toko BELUM punya lokasi
            if (!hasLocation) {
              matchedAnnouncement = item;
              break;
            }
          } else if (item.targetCriteria == 'all') {
            matchedAnnouncement = item;
            break;
          } else if (item.targetCriteria == 'free_plan') {
            if (business?.planId == null || business?.planId == 'free') {
              matchedAnnouncement = item;
              break;
            }
          } else if (item.targetCriteria == 'pro_plan') {
            if (business?.planId != null && business?.planId != 'free') {
              matchedAnnouncement = item;
              break;
            }
          }
        }

        // Jika tidak ada pengumuman dari database yang cocok,
        // cek fallback lokal: jika lokasi belum diset, tampilkan banner default
        if (matchedAnnouncement == null) {
          if (!hasLocation && announcements.isEmpty) {
            return _buildBannerCard(
              context: context,
              ref: ref,
              title: 'Pin Titik Lokasi & Direktori Web Online',
              message:
                  'Toko Anda belum mengatur titik koordinat GPS. Kunci lokasi gerai Anda sekarang agar otomatis tampil di peta web direktori toko aktif dan siap menghitung radius delivery pelanggan.',
              badgeText: 'PENGUMUMAN FITUR BARU',
              actionLabel: 'Atur Lokasi Sekarang',
              actionTarget: 'businessProfileEdit',
              secondaryActionLabel: 'Kelola Outlet',
              secondaryActionTarget: 'outletManagement',
            );
          }
          return const SizedBox.shrink();
        }

        return _buildBannerCard(
          context: context,
          ref: ref,
          title: matchedAnnouncement.title,
          message: matchedAnnouncement.message,
          badgeText: matchedAnnouncement.badgeText,
          actionLabel: matchedAnnouncement.actionLabel,
          actionTarget: matchedAnnouncement.actionTarget,
          actionType: matchedAnnouncement.actionType,
          secondaryActionLabel: matchedAnnouncement.secondaryActionLabel,
          secondaryActionTarget: matchedAnnouncement.secondaryActionTarget,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) {
        // Fallback offline saat error network
        if (!hasLocation) {
          return _buildBannerCard(
            context: context,
            ref: ref,
            title: 'Pin Titik Lokasi & Direktori Web Online',
            message:
                'Toko Anda belum mengatur titik koordinat GPS. Kunci lokasi gerai Anda sekarang agar otomatis tampil di peta web direktori toko aktif.',
            badgeText: 'PENGUMUMAN FITUR BARU',
            actionLabel: 'Atur Lokasi Sekarang',
            actionTarget: 'businessProfileEdit',
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBannerCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String message,
    required String badgeText,
    required String actionLabel,
    required String actionTarget,
    String actionType = 'route',
    String? secondaryActionLabel,
    String? secondaryActionTarget,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF7ED), // Orange 50
            Color(0xFFFFEDD5), // Orange 100
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFDBA74), // Orange 300
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Badge & Tombol Tutup ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.campaign_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      ref.read(announcementDismissedProvider.notifier).state =
                          true;
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.brown.shade400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Body: Icon & Teks Penjelasan ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFED7AA),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        size: 22,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C2D12),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9A3412),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Action Buttons ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      _handleAction(context, ref, actionTarget, actionType);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      actionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (secondaryActionLabel != null &&
                      secondaryActionLabel.isNotEmpty &&
                      secondaryActionTarget != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        _handleAction(
                          context,
                          ref,
                          secondaryActionTarget,
                          'route',
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                        foregroundColor: const Color(0xFF7C2D12),
                        side: const BorderSide(color: Color(0xFFFDBA74)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.storefront_rounded, size: 15),
                      label: Text(
                        secondaryActionLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    String target,
    String actionType,
  ) {
    if (actionType == 'url' || target.startsWith('http')) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Penanganan route internal aplikasi
    switch (target) {
      case 'businessProfileEdit':
        context.pushNamed(RouteNames.businessProfileEdit);
        break;
      case 'outletManagement':
        ref.read(ownerSelectedMenuProvider.notifier).state =
            OwnerMenu.outletManagement;
        break;
      case 'subscription':
        ref.read(ownerSelectedMenuProvider.notifier).state =
            OwnerMenu.subscription;
        break;
      case 'dashboard':
      default:
        ref.read(ownerSelectedMenuProvider.notifier).state = OwnerMenu.home;
        break;
    }
  }
}
