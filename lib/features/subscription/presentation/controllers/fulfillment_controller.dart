import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/local_database_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/subscription/domain/fulfillment_order_model.dart';
import 'package:dpos/features/subscription/presentation/providers/fulfillment_orders_provider.dart';

class FulfillmentController {
  static const String csPhone = '6285624277920';

  /// Helper untuk membersihkan dan memformat nomor HP ke format WhatsApp (awalan 62)
  static String formatPhoneForWhatsApp(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) return digits;
    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    return digits;
  }

  /// Membuka WhatsApp untuk menghubungi driver / kurir yang sedang mengantar
  static Future<void> contactDriverWhatsApp({
    required BuildContext context,
    required FulfillmentOrder order,
  }) async {
    HapticFeedback.lightImpact();
    final phone = order.driverPhone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor kontak kurir tidak tersedia.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetPhone = formatPhoneForWhatsApp(phone);
    final resiText = (order.trackingNumber != null && order.trackingNumber!.trim().isNotEmpty)
        ? '\n• No. Resi: ${order.trackingNumber!.trim()}'
        : '';
    final driverGreeting = (order.driverName != null && order.driverName!.trim().isNotEmpty)
        ? 'Halo Mas/Mbak ${order.driverName}'
        : 'Halo Driver Kurir';

    final message = '$driverGreeting,\n'
        'Saya pemilik toko "${order.recipientName}". Ingin konfirmasi posisi pengiriman paket starter kit Syupeo:\n'
        '• No. Pesanan: ${order.orderCode}'
        '$resiText\n'
        '• Alamat Toko: ${order.shippingAddress}, ${order.shippingCity}\n\n'
        'Kira-kira paket tiba pukul berapa ya? Terima kasih banyak!';

    final uri = Uri.parse(
      'https://wa.me/$targetPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp. Pastikan WhatsApp terpasang.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[contactDriverWhatsApp] Error: $e');
    }
  }

  /// Membuka WhatsApp untuk konfirmasi pesanan / pembayaran ke Admin CS Syupeo
  static Future<void> contactAdminWhatsApp({
    required BuildContext context,
    required FulfillmentOrder order,
  }) async {
    HapticFeedback.lightImpact();
    String message;
    if (order.isPending) {
      message = 'Halo Admin Syupeo, saya ingin konfirmasi pembayaran untuk pesanan paket usaha toko saya:\n'
          '• No. Pesanan: ${order.orderCode}\n'
          '• Paket: ${order.kitName}\n'
          '• Penerima: ${order.recipientName}\n'
          '• Alamat: ${order.shippingAddress}, ${order.shippingCity}\n\n'
          'Mohon informasi nomor rekening dan panduan konfirmasi pembayarannya. Terima kasih!';
    } else if (order.isPacking) {
      message = 'Halo Admin Syupeo, saya ingin menanyakan status pengemasan paket usaha toko saya:\n'
          '• No. Pesanan: ${order.orderCode}\n'
          '• Paket: ${order.kitName}\n'
          '• Penerima: ${order.recipientName}\n\n'
          'Kapan perkiraan paket diserahkan ke kurir pengiriman? Terima kasih!';
    } else if (order.isInTransit) {
      final resiInfo = (order.trackingNumber != null && order.trackingNumber!.trim().isNotEmpty)
          ? '\n• No. Resi: ${order.trackingNumber!.trim()}'
          : '';
      final driverInfo = (order.driverName != null && order.driverName!.trim().isNotEmpty)
          ? '\n• Kurir: ${order.driverName} (${order.driverPhone ?? "-"})'
          : '';
      message = 'Halo Admin Syupeo, saya ingin konfirmasi pengiriman paket usaha toko saya:\n'
          '• No. Pesanan: ${order.orderCode}\n'
          '• Paket: ${order.kitName}'
          '$resiInfo'
          '$driverInfo\n'
          '• Penerima: ${order.recipientName}\n\n'
          'Mohon pantauan pengiriman kurir ke toko saya. Terima kasih!';
    } else {
      message = 'Halo Admin Syupeo, paket usaha (${order.orderCode} - ${order.kitName}) untuk toko "${order.recipientName}" telah diterima dengan baik. Terima kasih atas pelayanannya!';
    }

    final uri = Uri.parse(
      'https://wa.me/$csPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp. Pastikan WhatsApp terpasang.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[contactAdminWhatsApp] Error: $e');
    }
  }

  /// Mengkonversi item-item hasil audit fisik langsung ke menu_items toko
  /// dan memperbarui cache SQLite lokal kasir secara instan
  static Future<bool> convertAuditItemsToProducts({
    required BuildContext context,
    required WidgetRef ref,
    required FulfillmentOrder order,
    required List<Map<String, dynamic>> itemsToConvert,
  }) async {
    // 1. Dapatkan businessId secara fail-proof
    String? businessId = ref.read(homeBootstrapProvider).valueOrNull?.business?.id;
    if (businessId == null) {
      try {
        final bootstrap = await ref.read(homeBootstrapProvider.future).timeout(const Duration(seconds: 4));
        businessId = bootstrap.business?.id;
      } catch (_) {}
    }

    if (businessId == null) {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        final bRes = await SupabaseService.client
            .from('businesses')
            .select('id')
            .eq('owner_user_id', user.id)
            .maybeSingle();
        businessId = bRes?['id'] as String?;
      }
    }

    if (businessId == null && order.recipientPhone.isNotEmpty) {
      final cleanPhone = order.recipientPhone.replaceAll(RegExp(r'\D'), '');
      final bRes = await SupabaseService.client
          .from('businesses')
          .select('id')
          .or('phone.eq.${order.recipientPhone},phone.eq.$cleanPhone')
          .maybeSingle();
      businessId = bRes?['id'] as String?;
    }

    if (businessId == null) {
      final bRes = await SupabaseService.client
          .from('businesses')
          .select('id')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      businessId = bRes?['id'] as String?;
    }

    if (businessId == null) {
      throw Exception('ID Toko (businessId) tidak dapat ditemukan. Silakan pastikan akun toko aktif.');
    }

    debugPrint('[convertAuditItems] Mulai konversi ${itemsToConvert.length} barang untuk businessId: $businessId');

    // 2. Loop setiap item dari itemsToConvert
    final categoryMap = <String, String>{};
    int visualIdx = 0;

    for (final it in itemsToConvert) {
      final name = (it['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;

      final categoryName = (it['category'] as String?)?.trim() ?? 'Sembako';
      final price = (it['price'] as num?)?.round() ?? 0;
      final costPrice = (it['cost_price'] as num?)?.round() ?? 0;
      final qty = (it['quantity'] as num?)?.round() ?? 1;
      final unit = (it['unit'] as String?)?.trim() ?? 'Pcs';
      final barcode = (it['barcode'] as String?)?.trim();

      // Dapatkan atau buat kategori
      if (!categoryMap.containsKey(categoryName)) {
        final catRes = await SupabaseService.client
            .from('menu_categories')
            .select('id')
            .eq('business_id', businessId)
            .ilike('name', categoryName)
            .maybeSingle();

        if (catRes != null) {
          categoryMap[categoryName] = catRes['id'] as String;
        } else {
          final insertedCat = await SupabaseService.client
              .from('menu_categories')
              .insert({
                'business_id': businessId,
                'name': categoryName,
                'visual_index': visualIdx++,
              })
              .select('id')
              .single();
          categoryMap[categoryName] = insertedCat['id'] as String;
        }
      }

      final categoryId = categoryMap[categoryName]!;

      // Cek apakah item sudah ada di menu_items toko
      Map<String, dynamic>? existing;
      if (barcode != null && barcode.isNotEmpty) {
        existing = await SupabaseService.client
            .from('menu_items')
            .select('id, stock_quantity')
            .eq('business_id', businessId)
            .eq('barcode', barcode)
            .maybeSingle();
      }

      existing ??= await SupabaseService.client
          .from('menu_items')
          .select('id, stock_quantity')
          .eq('business_id', businessId)
          .ilike('name', name)
          .maybeSingle();

      if (existing != null) {
        // A. SUDAH ADA: TAMBAHKAN STOK FISIK
        final currentStock = (existing['stock_quantity'] as num?)?.round() ?? 0;
        final updatedStock = currentStock + qty;

        await SupabaseService.client.from('menu_items').update({
          'category_id': categoryId,
          'stock_quantity': updatedStock,
          'stock_available': true,
          'track_stock_quantity': true,
          if (price > 0) 'price': price,
          if (costPrice > 0) 'cost_price': costPrice,
          if (costPrice > 0) 'recipe_cost': costPrice,
        }).eq('id', existing['id'] as String);

        debugPrint('[convertAuditItems] Stok produk $name bertambah: $currentStock + $qty = $updatedStock');
      } else {
        // B. BELUM ADA: BUAT PRODUK BARU
        await SupabaseService.client.from('menu_items').insert({
          'business_id': businessId,
          'category_id': categoryId,
          'name': name,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
          'price': price > 0 ? price : 10000,
          'cost_price': costPrice,
          'recipe_cost': costPrice,
          'stock_quantity': qty,
          'unit': unit,
          'stock_available': true,
          'track_stock_quantity': true,
        });

        debugPrint('[convertAuditItems] Produk baru berhasil dibuat: $name (stok: $qty)');
      }
    }

    // 3. Update status order menjadi delivered & set toko aktif
    await SupabaseService.client
        .from('package_fulfillment_orders')
        .update({
          'status': 'delivered',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', order.id);

    await SupabaseService.client
        .from('businesses')
        .update({'status': 'active'})
        .eq('id', businessId);

    // 4. Sinkronkan langsung data terbaru ke SQLite lokal kasir
    try {
      final updatedMenuItems = await ref.read(menuRepositoryProvider).getMenuItems(businessId);
      await LocalDatabaseService.instance.saveMenuItems(updatedMenuItems);
      debugPrint('[convertAuditItems] Sukses menyimpan ${updatedMenuItems.length} produk ke local SQLite cache!');
    } catch (e) {
      debugPrint('[convertAuditItems] Catatan sinkronisasi SQLite: $e');
    }

    // 5. Invalidate Provider Riverpod
    ref.invalidate(menuItemsProvider);
    ref.invalidate(fulfillmentOrdersProvider);
    ref.invalidate(homeBootstrapProvider);

    return true;
  }

  /// Dialog konfirmasi penerimaan barang dan eksekusi status delivered
  static Future<void> confirmDelivery({
    required BuildContext context,
    required WidgetRef ref,
    required FulfillmentOrder order,
    VoidCallback? onSuccess,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Konfirmasi Barang Tiba?',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan fisik paket starter kit telah tiba di toko dan diterima dengan baik:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderCode,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.kitName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  if (order.driverName != null && order.driverName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Kurir: ${order.driverName}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0070FC)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Setelah dikonfirmasi, seluruh stok produk starter kit akan langsung aktif di kasir POS dan toko siap bertransaksi.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF0070FC),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Periksa Nanti',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(ctx).pop(true);
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(
              'Ya, Barang Diterima',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Tampilkan Loading Indicator dengan konteks jelas (Anti-AI-Slop standard)
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mengaktifkan starter kit toko...',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final bizId = ref.read(homeBootstrapProvider).valueOrNull?.business?.id;

      // 1. Coba panggil RPC confirm_starter_kit_delivery jika tersedia di DB
      bool rpcSuccess = false;
      try {
        await SupabaseService.client.rpc('confirm_starter_kit_delivery', params: {
          'p_order_id': order.id,
          if (bizId != null) 'p_business_id': bizId,
        });
        rpcSuccess = true;
      } catch (e) {
        debugPrint('[confirmDelivery] RPC confirm_starter_kit_delivery fallback: $e');
      }

      // 2. Jika RPC belum terpasang atau ada kendala, lakukan direct update
      if (!rpcSuccess) {
        await SupabaseService.client
            .from('package_fulfillment_orders')
            .update({
              'status': 'delivered',
              'delivered_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', order.id);

        if (bizId != null) {
          await SupabaseService.client
              .from('businesses')
              .update({'status': 'active'})
              .eq('id', bizId);

          String? kitId = order.starterKitId;
          if (kitId == null) {
            final kitRes = await SupabaseService.client
                .from('retail_starter_kits')
                .select('id')
                .eq('is_active', true)
                .order('sort_order', ascending: true)
                .limit(1)
                .maybeSingle();
            kitId = kitRes?['id'] as String?;
          }

          if (kitId != null) {
            try {
              await SupabaseService.client.rpc('apply_starter_kit_to_business', params: {
                'p_business_id': bizId,
                'p_starter_kit_id': kitId,
              });
            } catch (e) {
              debugPrint('[confirmDelivery] apply_starter_kit_to_business note: $e');
            }
          }
        }
      }

      // 3. Failsafe & Kulakan: Tambahkan stok atau buat produk baru
      if (bizId != null) {
        if (order.notes != null && order.notes!.isNotEmpty) {
          await _applyWholesaleItemsIfPresent(bizId, order.notes!);
        }

        try {
          final itemsRes = await SupabaseService.client
              .from('menu_items')
              .select('id')
              .eq('business_id', bizId)
              .limit(1);

          if ((itemsRes as List).isEmpty) {
            debugPrint('[confirmDelivery] menu_items is empty! Running direct client-side seeding...');
            await seedStarterKitDirectly(bizId, order.kitName);
          }
        } catch (e) {
          debugPrint('[confirmDelivery] direct seed check note: $e');
        }
      }

      // Refresh seluruh provider terkait
      ref.invalidate(fulfillmentOrdersProvider);
      ref.invalidate(homeBootstrapProvider);
      ref.invalidate(menuItemsProvider);

      // Force instant network fetch to populate local SQLite cache
      if (bizId != null) {
        try {
          await ref.read(menuRepositoryProvider).getMenuItems(bizId);
        } catch (_) {}
      }

      if (context.mounted) {
        // Tutup dialog loading
        Navigator.of(context, rootNavigator: true).pop();

        // Tampilkan Banner Sukses
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barang Berhasil Diterima! 🎉',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Produk starter kit kini aktif penuh di kasir POS toko Anda.',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        onSuccess?.call();
      }
    } catch (err) {
      debugPrint('[confirmDelivery] Fatal Error: $err');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal konfirmasi barang diterima: $err'),
          ),
        );
      }
    }
  }

  /// Tombol Sinkronisasi Manual Produk jika etalase toko masih kosong
  static Future<void> syncStarterKitProducts({
    required BuildContext context,
    required WidgetRef ref,
    String? kitName,
  }) async {
    final bizId = ref.read(homeBootstrapProvider).valueOrNull?.business?.id;
    if (bizId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Toko belum teridentifikasi.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    try {
      await seedStarterKitDirectly(bizId, kitName ?? 'Paket 01 — Toko Pemula');
      ref.invalidate(menuItemsProvider);
      ref.invalidate(homeBootstrapProvider);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('Produk starter kit berhasil disinkronkan ke kasir! 🎉'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Gagal menyinkronkan produk: $e'),
          ),
        );
      }
    }
  }

  /// Menyalin produk retail riil langsung dari client ke menu_items lengkap dengan kategori masing-masing
  static Future<void> seedStarterKitDirectly(String businessId, String kitName) async {
    try {
      final lower = kitName.toLowerCase();
      List<Map<String, dynamic>> products;

      if (lower.contains('gen z')) {
        products = [
          {'name': 'Phone Charm Manik Viral', 'category': 'Aksesori Gen Z', 'price': 12000, 'cost_price': 6500, 'stock_quantity': 6, 'unit': 'Pcs'},
          {'name': 'Pop Socket Karakter 3D Hologram', 'category': 'Aksesori Gen Z', 'price': 10000, 'cost_price': 4500, 'stock_quantity': 6, 'unit': 'Pcs'},
          {'name': 'Scrunchie Ikat Rambut Silk Korea', 'category': 'Aksesori Gen Z', 'price': 7000, 'cost_price': 3000, 'stock_quantity': 8, 'unit': 'Pcs'},
          {'name': 'Pelindung Kabel Handphone Spiral', 'category': 'Aksesori Gen Z', 'price': 5000, 'cost_price': 2500, 'stock_quantity': 8, 'unit': 'Pcs'},
          {'name': 'Gantungan Kunci Estetik Akrilik', 'category': 'Aksesori Gen Z', 'price': 8000, 'cost_price': 4000, 'stock_quantity': 6, 'unit': 'Pcs'},
          {'name': 'Kaos Kaki Korea Stylish', 'category': 'Aksesori Gen Z', 'price': 12000, 'cost_price': 6000, 'stock_quantity': 5, 'unit': 'Pasang'},
          {'name': 'Mini Pouch Cantik Serbaguna', 'category': 'Aksesori Gen Z', 'price': 15000, 'cost_price': 8000, 'stock_quantity': 4, 'unit': 'Pcs'},
        ];
      } else if (lower.contains('beauty') || lower.contains('makarizo')) {
        products = [
          {'name': 'Makarizo Hair Energy Creambath Aloe 60g', 'category': 'Beauty & Perawatan', 'price': 16000, 'cost_price': 12500, 'stock_quantity': 5, 'unit': 'Pouch'},
          {'name': 'Makarizo Advisor Hair Recovery Serum 8ml', 'category': 'Beauty & Perawatan', 'price': 11000, 'cost_price': 8000, 'stock_quantity': 6, 'unit': 'Tube'},
          {'name': 'Makarizo Hair Energy Creambath Kiwi 60g', 'category': 'Beauty & Perawatan', 'price': 16000, 'cost_price': 12500, 'stock_quantity': 4, 'unit': 'Pouch'},
          {'name': 'Makarizo Hair Energy Creambath Royal Jelly 60g', 'category': 'Beauty & Perawatan', 'price': 16000, 'cost_price': 12500, 'stock_quantity': 4, 'unit': 'Pouch'},
        ];
      } else if (lower.contains('mineral') || lower.contains('vica')) {
        products = [
          {'name': 'Air Mineral VICA 600 mL (Tutup Kuning)', 'category': 'Air Mineral', 'price': 5000, 'cost_price': 3500, 'stock_quantity': 24, 'unit': 'Botol'},
          {'name': 'Air Minum Galon Nestlé Pure Life 19L', 'category': 'Air Mineral', 'price': 26000, 'cost_price': 22000, 'stock_quantity': 2, 'unit': 'Galon'},
          {'name': 'Air Mineral VICA 330 mL Mini Botol', 'category': 'Air Mineral', 'price': 3500, 'cost_price': 2500, 'stock_quantity': 24, 'unit': 'Botol'},
        ];
      } else {
        // Default Paket 01: Sembako & Kebutuhan Harian
        products = [
          {'name': 'Beras Premium Syupeo 2 kg', 'category': 'Sembako', 'price': 32000, 'cost_price': 28000, 'stock_quantity': 2, 'unit': 'Sak'},
          {'name': 'Minyak Goreng Sawit 1 Liter', 'category': 'Sembako', 'price': 17000, 'cost_price': 14500, 'stock_quantity': 3, 'unit': 'Pouch'},
          {'name': 'Gula Pasir Kristal 1 kg', 'category': 'Sembako', 'price': 16500, 'cost_price': 14000, 'stock_quantity': 2, 'unit': 'Bks'},
          {'name': 'Tepung Terigu Serbaguna 1 kg', 'category': 'Sembako', 'price': 12500, 'cost_price': 10500, 'stock_quantity': 2, 'unit': 'Bks'},
          {'name': 'Indomie Mi Goreng Spesial 85g', 'category': 'Makanan Instan', 'price': 3500, 'cost_price': 2800, 'stock_quantity': 10, 'unit': 'Pcs'},
          {'name': 'Kopi Kapal Api Spesial Mix (Renceng)', 'category': 'Minuman', 'price': 14000, 'cost_price': 11500, 'stock_quantity': 2, 'unit': 'Renceng'},
          {'name': 'Teh Celup Pilihan (Dus isi 25)', 'category': 'Minuman', 'price': 7500, 'cost_price': 5500, 'stock_quantity': 2, 'unit': 'Kotak'},
          {'name': 'Sabun Mandi Keluarga (Pack isi 4)', 'category': 'Kebutuhan Rumah', 'price': 15000, 'cost_price': 12000, 'stock_quantity': 2, 'unit': 'Pack'},
          {'name': 'Sabun Cuci Piring Cair 400ml', 'category': 'Kebutuhan Rumah', 'price': 6500, 'cost_price': 4500, 'stock_quantity': 2, 'unit': 'Pouch'},
          {'name': 'Deterjen Pakaian Bersih 800g', 'category': 'Kebutuhan Rumah', 'price': 19000, 'cost_price': 15000, 'stock_quantity': 2, 'unit': 'Bks'},
          {'name': 'Pasta Gigi Herbal 120g', 'category': 'Kebutuhan Rumah', 'price': 11500, 'cost_price': 8500, 'stock_quantity': 2, 'unit': 'Tube'},
          {'name': 'Kecap Manis Botol Sedap', 'category': 'Sembako', 'price': 10000, 'cost_price': 7500, 'stock_quantity': 2, 'unit': 'Botol'},
        ];
      }

      // 1. Buat kategori unik untuk setiap jenis produk
      final categoryMap = <String, String>{};
      final uniqueCatNames = products.map((p) => p['category'] as String).toSet();

      int visualIndex = 0;
      for (final catName in uniqueCatNames) {
        final catRes = await SupabaseService.client
            .from('menu_categories')
            .select('id')
            .eq('business_id', businessId)
            .ilike('name', catName)
            .maybeSingle();

        if (catRes != null) {
          categoryMap[catName] = catRes['id'] as String;
        } else {
          final insertedCat = await SupabaseService.client
              .from('menu_categories')
              .insert({
                'business_id': businessId,
                'name': catName,
                'visual_index': visualIndex++,
              })
              .select('id')
              .single();
          categoryMap[catName] = insertedCat['id'] as String;
        }
      }

      // 2. Insert atau sinkronkan produk dengan category_id yang tepat
      for (final p in products) {
        final catName = p['category'] as String;
        final categoryId = categoryMap[catName] ?? categoryMap.values.first;

        // Cek jika produk sudah ada (case-insensitive & toleran variasi nama)
        final pName = p['name'] as String;
        final keyword = pName.split(' ').take(2).join(' '); // Misal "Beras Premium", "Minyak Goreng"
        
        var existing = await SupabaseService.client
            .from('menu_items')
            .select('id, stock_quantity')
            .eq('business_id', businessId)
            .ilike('name', pName)
            .maybeSingle();

        if (existing == null && keyword.length >= 5) {
          existing = await SupabaseService.client
              .from('menu_items')
              .select('id, stock_quantity')
              .eq('business_id', businessId)
              .ilike('name', '%$keyword%')
              .maybeSingle();
        }

        if (existing == null) {
          await SupabaseService.client.from('menu_items').insert({
            'business_id': businessId,
            'category_id': categoryId,
            'name': p['name'],
            'price': (p['price'] as num).round(),
            'cost_price': (p['cost_price'] as num).round(),
            'recipe_cost': (p['cost_price'] as num).round(),
            'stock_quantity': (p['stock_quantity'] as num).round(),
            'unit': (p['unit'] as String?) ?? 'Pcs',
            'stock_available': true,
            'track_stock_quantity': true,
          });
        } else {
          // TAMBAHKAN stok yang baru dibeli ke stok yang sudah ada di toko
          final currentStock =
              (existing['stock_quantity'] as num?)?.round() ?? 0;
          final addQty = (p['stock_quantity'] as num).round();
          await SupabaseService.client.from('menu_items').update({
            'category_id': categoryId,
            'stock_quantity': currentStock + addQty,
            'unit': (p['unit'] as String?) ?? 'Pcs',
            'stock_available': true,
            'track_stock_quantity': true,
          }).eq('id', existing['id'] as String);
        }
      }

      // 3. Fallback: Pastikan SEMUA produk di bisnis ini memiliki category_id yang valid
      final defaultCatId = categoryMap['Sembako'] ?? categoryMap.values.first;
      await SupabaseService.client
          .from('menu_items')
          .update({'category_id': defaultCatId})
          .eq('business_id', businessId)
          .isFilter('category_id', null);

      debugPrint('[seedStarterKitDirectly] Successfully mapped ${products.length} products to their specific categories!');
    } catch (e) {
      debugPrint('[seedStarterKitDirectly] Error: $e');
      rethrow;
    }
  }

  /// Memproses item kulakan satuan saat pesanan dikonfirmasi sampai di toko:
  /// - Jika barang SUDAH ADA: Stoknya ditambahkan (currentStock + quantity).
  /// - Jika barang BELUM ADA: Otomatis dibuatkan produk baru di menu_items.
  static Future<void> _applyWholesaleItemsIfPresent(
    String businessId,
    String notes,
  ) async {
    try {
      if (!notes.trim().startsWith('{')) return;
      final decoded = jsonDecode(notes);
      if (decoded is! Map || decoded['items'] is! List) return;

      final items = decoded['items'] as List;
      if (items.isEmpty) return;

      final categoryMap = <String, String>{};
      int visualIndex = 0;

      for (final raw in items) {
        if (raw is! Map) continue;
        final name = (raw['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;

        final categoryName =
            (raw['category'] as String?)?.trim() ?? 'Sembako';
        final price = (raw['price'] as num?)?.round() ?? 0;
        final costPrice = (raw['cost_price'] as num?)?.round() ?? 0;
        final qty = (raw['quantity'] as num?)?.round() ?? 1;
        final unit = (raw['unit'] as String?)?.trim() ?? 'Pcs';
        final barcode = (raw['barcode'] as String?)?.trim();

        // 1. Dapatkan atau buat kategori jika belum ada
        if (!categoryMap.containsKey(categoryName)) {
          final catRes = await SupabaseService.client
              .from('menu_categories')
              .select('id')
              .eq('business_id', businessId)
              .ilike('name', categoryName)
              .maybeSingle();

          if (catRes != null) {
            categoryMap[categoryName] = catRes['id'] as String;
          } else {
            final insertedCat = await SupabaseService.client
                .from('menu_categories')
                .insert({
                  'business_id': businessId,
                  'name': categoryName,
                  'visual_index': visualIndex++,
                })
                .select('id')
                .single();
            categoryMap[categoryName] = insertedCat['id'] as String;
          }
        }

        final categoryId = categoryMap[categoryName]!;

        // 2. Cek apakah barang SUDAH ADA di toko (berdasarkan barcode atau nama)
        Map<String, dynamic>? existing;
        if (barcode != null && barcode.isNotEmpty) {
          existing = await SupabaseService.client
              .from('menu_items')
              .select('id, stock_quantity')
              .eq('business_id', businessId)
              .eq('barcode', barcode)
              .maybeSingle();
        }

        existing ??= await SupabaseService.client
            .from('menu_items')
            .select('id, stock_quantity')
            .eq('business_id', businessId)
            .ilike('name', name)
            .maybeSingle();

        if (existing != null) {
          // A. BARANG SUDAH ADA: TAMBAHKAN STOK (TIDAK MEMBUAT DUPLIKAT)
          final currentStock =
              (existing['stock_quantity'] as num?)?.round() ?? 0;
          final updatedStock = currentStock + qty;

          await SupabaseService.client.from('menu_items').update({
            'category_id': categoryId,
            'stock_quantity': updatedStock,
            'stock_available': true,
            'track_stock_quantity': true,
            if (costPrice > 0) 'cost_price': costPrice,
            if (costPrice > 0) 'recipe_cost': costPrice,
          }).eq('id', existing['id'] as String);

          debugPrint(
              '[_applyWholesaleItems] Updated existing product $name: stock $currentStock + $qty = $updatedStock');
        } else {
          // B. BARANG BELUM PERNAH ADA: BUATKAN PRODUK BARU
          await SupabaseService.client.from('menu_items').insert({
            'business_id': businessId,
            'category_id': categoryId,
            'name': name,
            if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
            'price': price,
            'cost_price': costPrice,
            'recipe_cost': costPrice,
            'stock_quantity': qty,
            'unit': unit,
            'stock_available': true,
            'track_stock_quantity': true,
          });

          debugPrint(
              '[_applyWholesaleItems] Inserted new product $name with stock $qty');
        }
      }
    } catch (e) {
      debugPrint('[_applyWholesaleItemsIfPresent] Note: $e');
    }
  }
}

