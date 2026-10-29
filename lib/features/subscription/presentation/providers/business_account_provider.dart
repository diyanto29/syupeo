import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/core/domain/business_models.dart';

final allBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return repository.fetchAllBusinesses();
});

class BusinessAccountNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  final Ref _ref;

  BusinessAccountNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> updateTemplate({
    required String businessId,
    required String templateCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateBusinessTemplateAdmin(
        businessId: businessId,
        templateCode: templateCode,
      );
      // Refresh list secara paksa dan tunggu selesai
      final _ = await _ref.refresh(allBusinessesProvider.future);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final businessAccountActionProvider = StateNotifierProvider<BusinessAccountNotifier, AsyncValue<void>>((ref) {
  return BusinessAccountNotifier(ref.read(authRepositoryProvider), ref);
});
