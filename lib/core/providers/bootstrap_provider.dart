import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/core/domain/bootstrap_models.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final client = SupabaseService.client;
  String? currentId = client.auth.currentUser?.id;
  yield currentId;

  while (true) {
    try {
      await for (final event in client.auth.onAuthStateChange) {
        final newId = event.session?.user.id;
        if (newId != currentId) {
          currentId = newId;
          yield currentId;
        }
      }
      return;
    } catch (error, stackTrace) {
      if (!SupabaseService.isLikelyTransientNetworkError(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      debugPrint('[supabase.auth] transient auth stream error ignored: $error');
      await Future<void>.delayed(const Duration(seconds: 1));
      final recheckedId = client.auth.currentUser?.id;
      if (recheckedId != currentId) {
        currentId = recheckedId;
        yield currentId;
      }
    }
  }
});

final businessRealtimeProvider = StreamProvider<void>((ref) {
  final userId = ref.watch(authUserIdProvider).value;
  if (userId == null) return Stream.value(null);

  // Dengerin perubahan bisnis di mana user ini adalah owner-nya
  return SupabaseService.client
      .from('businesses')
      .stream(primaryKey: ['id'])
      .eq('owner_user_id', userId)
      .handleError((error) {
        debugPrint('[businessRealtimeProvider] Realtime stream error ignored: $error');
      })
      .map((_) {});
});

final homeBootstrapProvider = FutureProvider<OwnerBootstrap>((ref) async {
  ref.watch(authUserIdProvider);
  
  // Dengerin perubahan dari stream realtime HANYA jika ada event data valid.
  // Jangan gunakan ref.watch(businessRealtimeProvider) karena saat offline/disconnect,
  // stream akan error dan menyebabkan reload loop berulang kali (loading spinner tiba-tiba).
  ref.listen(businessRealtimeProvider, (prev, next) {
    if (next.hasValue && !next.isLoading && !next.hasError) {
      debugPrint('[homeBootstrapProvider] Realtime business change detected, refreshing...');
      ref.invalidateSelf();
    }
  });

  return ref.read(authRepositoryProvider).loadBootstrap();
});

final canManageCatalogProvider = Provider<bool>((ref) {
  return ref.watch(homeBootstrapProvider).value?.canManageCatalog ?? false;
});
