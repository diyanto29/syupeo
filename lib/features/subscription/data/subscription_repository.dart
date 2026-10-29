import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/core/domain/subscription_models.dart';

class SubscriptionRepository {
  final SupabaseClient _client;

  SubscriptionRepository(this._client);

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .order('price_monthly', ascending: true);
    
    return (response as List)
        .map((e) => SubscriptionPlan.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(SupabaseService.client);
});

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  return ref.watch(subscriptionRepositoryProvider).getPlans();
});
