import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/discount_models.dart';
import '../widgets/discount_editor_sheet.dart';

class DiscountEditorPage extends StatelessWidget {
  const DiscountEditorPage({super.key, this.initialDiscount});

  final DiscountDefinition? initialDiscount;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final isEdit = initialDiscount != null;
    final pageTitle = isEdit
        ? 'Edit Diskon Potongan Harga'
        : 'Tambah Diskon Potongan Harga';
    final pageSubtitle = isEdit
        ? 'Perbarui parameter potongan harga nominal atau persentase transaksi'
        : 'Konfigurasi diskon nominal atau persentase untuk transaksi penjualan';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: Text(pageTitle),
              subtitle: Text(
                pageSubtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              badge: const AppTabletBadge(label: 'Mangga POS'),
            )
          : AppBar(title: Text(pageTitle), centerTitle: false),
      body: SafeArea(
        child: DiscountEditorSheet(
          initialDiscount: initialDiscount,
          isPage: true,
        ),
      ),
    );
  }
}
