import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/product_catalog/domain/master_catalog_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasterCatalogRepository {
  MasterCatalogRepository(this._client);

  final SupabaseClient _client;
  static const String _tableName = 'master_catalog';

  Future<MasterCatalogSearchPage> searchSamples(
    String query, {
    int limit = 20,
    int generalOffset = 0,
  }) async {
    final trimmedQuery = query.trim();
    MasterCatalogItem? exactBarcodeMatch;

    if (trimmedQuery.isNotEmpty && generalOffset == 0) {
      final exactResponse = await _client
          .from(_tableName)
          .select()
          .eq('barcode', trimmedQuery)
          .limit(1);
      final exactRows = exactResponse as List<dynamic>;
      if (exactRows.isNotEmpty) {
        exactBarcodeMatch = MasterCatalogItem.fromJson(
          exactRows.first as Map<String, dynamic>,
        );
      }
    }

    final generalTakeCount = limit - (exactBarcodeMatch != null ? 1 : 0);
    final generalResponse = trimmedQuery.isEmpty
        ? await _client
              .from(_tableName)
              .select()
              .order('name', ascending: true)
              .range(generalOffset, generalOffset + generalTakeCount)
        : await _client
              .from(_tableName)
              .select()
              .or(_buildSearchFilter(trimmedQuery))
              .order('name', ascending: true)
              .range(generalOffset, generalOffset + generalTakeCount);

    final generalItems = (generalResponse as List<dynamic>)
        .map((json) => MasterCatalogItem.fromJson(json as Map<String, dynamic>))
        .where((item) => item.id != exactBarcodeMatch?.id)
        .toList();

    final consumedGeneralCount = generalItems.length > generalTakeCount
        ? generalTakeCount
        : generalItems.length;

    return MasterCatalogSearchPage(
      items: [
        if (exactBarcodeMatch != null) exactBarcodeMatch,
        ...generalItems.take(consumedGeneralCount),
      ],
      hasMore: generalItems.length > consumedGeneralCount,
      nextGeneralOffset: generalOffset + consumedGeneralCount,
      exactBarcodeMatched: exactBarcodeMatch != null,
    );
  }

  String _buildSearchFilter(String query) {
    final escaped = _escapeFilterValue(query);
    final pattern = '%$escaped%';
    return [
      'barcode.ilike.$pattern',
      'name.ilike.$pattern',
      'brand.ilike.$pattern',
      'category.ilike.$pattern',
    ].join(',');
  }

  String _escapeFilterValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }
}

class MasterCatalogSearchPage {
  const MasterCatalogSearchPage({
    required this.items,
    required this.hasMore,
    required this.nextGeneralOffset,
    required this.exactBarcodeMatched,
  });

  final List<MasterCatalogItem> items;
  final bool hasMore;
  final int nextGeneralOffset;
  final bool exactBarcodeMatched;
}

final masterCatalogRepositoryProvider = Provider<MasterCatalogRepository>((
  ref,
) {
  return MasterCatalogRepository(SupabaseService.client);
});
