import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/discount_models.dart';

class DiscountRepository {
  DiscountRepository(this._client);

  final SupabaseClient _client;
  static const _tableName = 'discounts';

  Future<List<DiscountDefinition>> getDiscounts(String businessId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('business_id', businessId)
          .order('is_active', ascending: false)
          .order('updated_at', ascending: false)
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 2));

      return (response as List<dynamic>)
          .map(
            (json) => DiscountDefinition.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('[DiscountRepo] Fetch discounts failed/offline ($e), returning empty list');
      return const [];
    }
  }

  Future<void> upsertDiscount(DiscountDefinition discount) async {
    await _client.from(_tableName).upsert(discount.toJson());
  }

  Future<void> deleteDiscount(String id) async {
    await _client.from(_tableName).delete().eq('id', id);
  }
}

final discountRepositoryProvider = Provider<DiscountRepository>((ref) {
  return DiscountRepository(SupabaseService.client);
});

final discountsProvider =
    AsyncNotifierProvider<DiscountsNotifier, List<DiscountDefinition>>(() {
      return DiscountsNotifier();
    });

class DiscountsNotifier extends AsyncNotifier<List<DiscountDefinition>> {
  @override
  Future<List<DiscountDefinition>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final businessId = bootstrap?.business?.id;

    if (businessId == null) {
      return [];
    }

    return ref.watch(discountRepositoryProvider).getDiscounts(businessId);
  }

  String? get _businessId =>
      ref.read(homeBootstrapProvider).value?.business?.id;

  Future<void> refresh() async {
    final businessId = _businessId;
    if (businessId == null) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(discountRepositoryProvider).getDiscounts(businessId),
    );
  }

  Future<void> upsertDiscount(DiscountDefinition discount) async {
    final businessId = _businessId;
    if (businessId == null) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(discountRepositoryProvider).upsertDiscount(discount);
        return await ref.read(discountRepositoryProvider).getDiscounts(businessId);
      } catch (error, stackTrace) {
        debugPrint('Error upserting discount: $error');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  }

  Future<void> deleteDiscount(String id) async {
    final businessId = _businessId;
    if (businessId == null) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(discountRepositoryProvider).deleteDiscount(id);
        return await ref.read(discountRepositoryProvider).getDiscounts(businessId);
      } catch (error, stackTrace) {
        debugPrint('Error deleting discount: $error');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  }
}
