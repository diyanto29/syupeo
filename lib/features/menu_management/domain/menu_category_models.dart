class MenuCatalogCategory {
  const MenuCatalogCategory({
    required this.id,
    required this.name,
    required this.visualIndex,
    required this.businessId,
    this.isVisibleInAllOutlets = true,
    this.visibleOutletIds = const [],
  });

  final String id;
  final String name;
  final int visualIndex;
  final String businessId;
  final bool isVisibleInAllOutlets;
  final List<String> visibleOutletIds;

  MenuCatalogCategory copyWith({
    String? id,
    String? name,
    int? visualIndex,
    String? businessId,
    bool? isVisibleInAllOutlets,
    List<String>? visibleOutletIds,
  }) {
    return MenuCatalogCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      visualIndex: visualIndex ?? this.visualIndex,
      businessId: businessId ?? this.businessId,
      isVisibleInAllOutlets:
          isVisibleInAllOutlets ?? this.isVisibleInAllOutlets,
      visibleOutletIds: visibleOutletIds ?? this.visibleOutletIds,
    );
  }

  factory MenuCatalogCategory.fromJson(Map<String, dynamic> json) {
    return MenuCatalogCategory(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Kategori',
      visualIndex: (json['visual_index'] as num?)?.toInt() ?? 0,
      businessId: (json['business_id'] as String?) ?? '',
      isVisibleInAllOutlets: json['is_visible_in_all_outlets'] as bool? ?? true,
      visibleOutletIds: (json['visible_outlet_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'visual_index': visualIndex,
      'business_id': businessId,
      'is_visible_in_all_outlets': isVisibleInAllOutlets,
      'visible_outlet_ids': visibleOutletIds,
    };
  }
}
