import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/subscription/domain/fulfillment_order_model.dart';

final fulfillmentOrdersProvider =
    FutureProvider.autoDispose<List<FulfillmentOrder>>((ref) async {
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final businessPhone = bootstrap?.business?.phone?.trim() ?? '';
  final userPhone = bootstrap?.profile?.phone?.trim() ?? '';

  final client = SupabaseService.client;

  // Cari berdasarkan nomor telepon penerima dengan berbagai format
  final rawPhones = [
    if (businessPhone.isNotEmpty) businessPhone,
    if (userPhone.isNotEmpty) userPhone,
  ];

  final searchPhones = <String>{};
  for (final p in rawPhones) {
    searchPhones.add(p);
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) {
      searchPhones.add(digits);
      searchPhones.add('+$digits');
      searchPhones.add('0${digits.substring(2)}');
    } else if (digits.startsWith('0')) {
      searchPhones.add(digits);
      searchPhones.add('62${digits.substring(1)}');
      searchPhones.add('+62${digits.substring(1)}');
    }
  }

  if (searchPhones.isEmpty) {
    // Jika nomor belum tersimpan, ambil 5 order terbaru toko
    final response = await client
        .from('package_fulfillment_orders')
        .select()
        .order('created_at', ascending: false)
        .limit(5);

    return (response as List)
        .map((e) => FulfillmentOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // Filter or phone
  final orFilter = searchPhones.map((p) => 'recipient_phone.eq.$p').join(',');
  final response = await client
      .from('package_fulfillment_orders')
      .select()
      .or(orFilter)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => FulfillmentOrder.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});

