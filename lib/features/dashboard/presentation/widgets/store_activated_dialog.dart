import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/features/subscription/presentation/views/starter_kit_orders_sheet.dart';

class StoreActivatedDialog extends StatelessWidget {
  final Business business;
  final VoidCallback? onStartSelling;
  final VoidCallback? onCheckShipping;

  const StoreActivatedDialog({
    super.key,
    required this.business,
    this.onStartSelling,
    this.onCheckShipping,
  });

  static Future<void> show(
    BuildContext context,
    Business business, {
    VoidCallback? onStartSelling,
    VoidCallback? onCheckShipping,
  }) {
    HapticFeedback.heavyImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StoreActivatedDialog(
        business: business,
        onStartSelling: onStartSelling,
        onCheckShipping: onCheckShipping,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A059669),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.store_rounded,
                    color: Color(0xFF059669),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF047857),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AKUN TELAH DIKONFIRMASI ADMIN',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF065F46),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                'Selamat! Toko Anda Siap 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Akun toko "${business.name}" telah diaktifkan oleh Admin Syupeo. Seluruh fitur kasir POS, katalog produk, dan transaksi kini aktif sepenuhnya.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Store Card Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      label: 'Nama Toko',
                      value: business.name,
                      isBold: true,
                    ),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildRow(
                      label: 'Status Toko',
                      value: 'Aktif Penuh',
                      valueColor: const Color(0xFF059669),
                      isBold: true,
                    ),
                    if (business.address != null && business.address!.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildRow(
                        label: 'Alamat',
                        value: business.address!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    onStartSelling?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Mulai Berjualan Sekarang',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    if (onCheckShipping != null) {
                      onCheckShipping!.call();
                    } else {
                      StarterKitOrdersSheet.show(context);
                    }
                  },
                  icon: const Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                  label: Text(
                    'Cek Pengiriman Paket Usaha',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
