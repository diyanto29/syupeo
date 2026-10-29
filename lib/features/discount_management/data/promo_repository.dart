import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/promo_models.dart';

class PromoRepository {
  PromoRepository(this._client);

  final SupabaseClient _client;

  // ── BUY X GET Y ─────────────────────────────────────────────────────────────

  static const _bxgySelect = '''
    *,
    trigger_item:menu_items!buy_x_get_y_promos_trigger_menu_item_id_fkey(name),
    reward_item:menu_items!buy_x_get_y_promos_reward_menu_item_id_fkey(name)
  ''';

  Future<List<BuyXGetYPromo>> getBuyXGetYPromos(String businessId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        return const [];
      }
    } catch (_) {}

    try {
      final response = await _client
          .from('buy_x_get_y_promos')
          .select(_bxgySelect)
          .eq('business_id', businessId)
          .order('is_active', ascending: false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 2));

      return (response as List<dynamic>)
          .map((json) => BuyXGetYPromo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  Future<void> upsertBuyXGetYPromo(BuyXGetYPromo promo) async {
    await _client.from('buy_x_get_y_promos').upsert(promo.toJson());
  }

  Future<void> deleteBuyXGetYPromo(String id) async {
    await _client.from('buy_x_get_y_promos').delete().eq('id', id);
  }

  Future<void> toggleBuyXGetYPromoStatus(String id, bool isActive) async {
    await _client
        .from('buy_x_get_y_promos')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  // ── TEBUS MURAH ────────────────────────────────────────────────────────────

  static const _tebusSelect = '''
    *,
    trigger_item:menu_items!tebus_murah_promos_trigger_menu_item_id_fkey(name),
    reward_item:menu_items!tebus_murah_promos_reward_menu_item_id_fkey(name, price)
  ''';

  Future<List<TebusMurahPromo>> getTebusMurahPromos(String businessId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        return const [];
      }
    } catch (_) {}

    try {
      final response = await _client
          .from('tebus_murah_promos')
          .select(_tebusSelect)
          .eq('business_id', businessId)
          .order('is_active', ascending: false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 2));

      return (response as List<dynamic>)
          .map((json) => TebusMurahPromo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  Future<void> upsertTebusMurahPromo(TebusMurahPromo promo) async {
    await _client.from('tebus_murah_promos').upsert(promo.toJson());
  }

  Future<void> upsertTebusMurahPromos(List<TebusMurahPromo> promos) async {
    if (promos.isEmpty) return;
    await _client.from('tebus_murah_promos').upsert(promos.map((p) => p.toJson()).toList());
  }

  Future<void> deleteTebusMurahPromo(String id) async {
    await _client.from('tebus_murah_promos').delete().eq('id', id);
  }

  Future<void> toggleTebusMurahPromoStatus(String id, bool isActive) async {
    await _client
        .from('tebus_murah_promos')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  return PromoRepository(SupabaseService.client);
});

// ── Notifiers & Providers ───────────────────────────────────────────────────

final buyXGetYPromosProvider =
    AsyncNotifierProvider<BuyXGetYNotifier, List<BuyXGetYPromo>>(() {
  return BuyXGetYNotifier();
});

class BuyXGetYNotifier extends AsyncNotifier<List<BuyXGetYPromo>> {
  @override
  Future<List<BuyXGetYPromo>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final businessId = bootstrap?.business?.id;
    if (businessId == null) return [];
    return ref.watch(promoRepositoryProvider).getBuyXGetYPromos(businessId);
  }

  String? get _businessId => ref.read(homeBootstrapProvider).valueOrNull?.business?.id;

  Future<void> refresh() async {
    final businessId = _businessId;
    if (businessId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(promoRepositoryProvider).getBuyXGetYPromos(businessId),
    );
  }

  Future<void> upsertPromo(BuyXGetYPromo promo) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.upsertBuyXGetYPromo(promo);
    await refresh();
  }

  Future<void> deletePromo(String id) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.deleteBuyXGetYPromo(id);
    await refresh();
  }

  Future<void> toggleStatus(String id, bool isActive) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.toggleBuyXGetYPromoStatus(id, isActive);
    await refresh();
  }
}

final tebusMurahPromosProvider =
    AsyncNotifierProvider<TebusMurahNotifier, List<TebusMurahPromo>>(() {
  return TebusMurahNotifier();
});

class TebusMurahNotifier extends AsyncNotifier<List<TebusMurahPromo>> {
  @override
  Future<List<TebusMurahPromo>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final businessId = bootstrap?.business?.id;
    if (businessId == null) return [];
    return ref.watch(promoRepositoryProvider).getTebusMurahPromos(businessId);
  }

  String? get _businessId => ref.read(homeBootstrapProvider).valueOrNull?.business?.id;

  Future<void> refresh() async {
    final businessId = _businessId;
    if (businessId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(promoRepositoryProvider).getTebusMurahPromos(businessId),
    );
  }

  Future<void> upsertPromo(TebusMurahPromo promo) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.upsertTebusMurahPromo(promo);
    await refresh();
  }

  Future<void> upsertPromos(List<TebusMurahPromo> promos) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.upsertTebusMurahPromos(promos);
    await refresh();
  }

  Future<void> deletePromo(String id) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.deleteTebusMurahPromo(id);
    await refresh();
  }

  Future<void> toggleStatus(String id, bool isActive) async {
    final repo = ref.read(promoRepositoryProvider);
    await repo.toggleTebusMurahPromoStatus(id, isActive);
    await refresh();
  }
}
