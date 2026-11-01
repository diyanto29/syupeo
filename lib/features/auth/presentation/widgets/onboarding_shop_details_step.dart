import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/services/wilayah_service.dart';

/// ── WIDGET LANGKAH 1: PROFIL & IDENTITAS TOKO RITEL ──
class OnboardingShopDetailsStep extends StatelessWidget {
  const OnboardingShopDetailsStep({
    super.key,
    required this.formKey,
    required this.businessNameController,
    required this.ownerNameController,
    required this.phoneController,
    required this.detailAddressController,
    required this.wilayahSelection,
    required this.onPickWilayah,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadius,
    required this.isGeofenceActive,
    required this.onPickGeofenceLocation,
    required this.onNextStep,
    required this.onSkip,
    required this.cleanDisplayPhone,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController businessNameController;
  final TextEditingController ownerNameController;
  final TextEditingController phoneController;
  final TextEditingController detailAddressController;
  final WilayahSelection? wilayahSelection;
  final VoidCallback onPickWilayah;
  final double? latitude;
  final double? longitude;
  final int geofenceRadius;
  final bool isGeofenceActive;
  final VoidCallback onPickGeofenceLocation;
  final VoidCallback onNextStep;
  final VoidCallback onSkip;
  final String Function(String) cleanDisplayPhone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEADER CARD ───────────────────────────────────────────
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'Langkah 1 dari 2 • Setup Toko',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Siapkan Toko Ritel Anda',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Masukkan identitas toko dan standarisasi lokasi untuk jaringan pasokan & kulakan Syupeo.',
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

            // ── FORM INPUTS ───────────────────────────────────────────
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
                  Text(
                    'Nama Toko Ritel *',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: businessNameController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Toko Berkah Mandiri',
                      prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama toko wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Nama Pemilik Toko',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: ownerNameController,
                    decoration: const InputDecoration(
                      hintText: 'Nama lengkap Anda',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Nomor WhatsApp Aktif *',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    onChanged: (val) {
                      final cleaned = cleanDisplayPhone(val);
                      if (cleaned != val) {
                        phoneController.value = TextEditingValue(
                          text: cleaned,
                          selection: TextSelection.collapsed(
                            offset: cleaned.length,
                          ),
                        );
                      }
                    },
                    validator: (val) {
                      final clean = val?.trim() ?? '';
                      if (clean.isEmpty) {
                        return 'Nomor WhatsApp wajib diisi';
                      }
                      if (!clean.startsWith('8')) {
                        return 'Nomor harus diawali angka 8 (contoh: 812xxxx)';
                      }
                      if (clean.length < 9) {
                        return 'Nomor WhatsApp minimal 9 digit (setelah +62)';
                      }
                      if (clean.length > 13) {
                        return 'Nomor WhatsApp maksimal 13 digit';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '81234567890',
                      prefixIcon: Container(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇮🇩', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              '+62',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 20,
                              width: 1,
                              color: AppTheme.border,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 1. Wilayah Administratif (wilayah.id) ──
                  Row(
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Wilayah Administratif (wilayah.id)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onPickWilayah,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: wilayahSelection != null
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: wilayahSelection != null
                              ? AppTheme.success
                              : AppTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            wilayahSelection != null
                                ? Icons.check_circle_rounded
                                : Icons.location_city_rounded,
                            size: 18,
                            color: wilayahSelection != null
                                ? AppTheme.success
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              wilayahSelection != null
                                  ? wilayahSelection!.formattedText
                                  : 'Pilih Provinsi, Kota, Kecamatan...',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: wilayahSelection != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: wilayahSelection != null
                                    ? AppTheme.text
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Google Places & Geofencing ──
                  Row(
                    children: [
                      const Icon(
                        Icons.pin_drop_outlined,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Titik Maps & Geofencing Kasir (Google Places)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onPickGeofenceLocation,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: latitude != null
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: latitude != null
                              ? AppTheme.primary
                              : AppTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            latitude != null
                                ? Icons.my_location_rounded
                                : Icons.add_location_alt_outlined,
                            size: 18,
                            color: latitude != null
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latitude != null
                                      ? 'Titik Terkunci (${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)})'
                                      : 'Kunci Titik Lokasi Google Maps & Radius Geofence',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: latitude != null
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: latitude != null
                                        ? AppTheme.text
                                        : AppTheme.textMuted,
                                  ),
                                ),
                                if (latitude != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Radius Geofence: $geofenceRadius meter • Status: ${isGeofenceActive ? "Aktif" : "Non-aktif"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Detail Alamat / Jalan / Patokan Toko',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: detailAddressController,
                    decoration: const InputDecoration(
                      hintText:
                          'Contoh: Jl. Merdeka No. 12 RT 02/05, Depan Masjid',
                      prefixIcon: Icon(Icons.home_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── TOMBOL LANJUT KE LANGKAH 2 ────────────────────────────
            FilledButton(
              onPressed: onNextStep,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pilih Paket Usaha Syupeo',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── TOMBOL LEWATI (LANGSUNG DASHBOARD) ────────────────────
            Center(
              child: TextButton(
                onPressed: onSkip,
                child: Text(
                  'Lewati dulu, saya ingin langsung eksplor dashboard kasir →',
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
      ),
    );
  }
}

