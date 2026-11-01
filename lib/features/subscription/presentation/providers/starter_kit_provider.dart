import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/subscription/domain/starter_kit_model.dart';

final starterKitsProvider = FutureProvider<List<StarterKit>>((ref) async {
  try {
    final response = await SupabaseService.client
        .from('retail_starter_kits')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .timeout(const Duration(seconds: 8));

    if (response.isNotEmpty) {
      return response
          .map((item) => StarterKit.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
  } catch (_) {
    // Fallback to static starter kits if offline or table is empty
  }

  return StarterKit.defaultKits;
});

