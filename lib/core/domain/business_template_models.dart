class BusinessTypeTemplate {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String? iconName;
  final List<String> defaultEnabledFeatures;
  final Map<String, String>
  featuresConfig; // { 'feat': 'off' | 'free' | 'pro' }
  final Map<String, dynamic>
  limitsConfig; // { 'free': { 'max_tx': 100 }, 'pro': { 'max_tx': 1000 } }
  final Map<String, String> roleLabels; // { 'waiter': 'Marketer' }
  final int maxTransactions; // Legacy/Default
  final int maxProducts;
  final int maxOutlets;
  final bool showAds;

  const BusinessTypeTemplate({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.iconName,
    required this.defaultEnabledFeatures,
    this.featuresConfig = const {},
    this.limitsConfig = const {'free': {}, 'pro': {}},
    this.roleLabels = const {},
    this.maxTransactions = 100,
    this.maxProducts = 50,
    this.maxOutlets = 1,
    this.showAds = true,
  });

  factory BusinessTypeTemplate.fromMap(Map<String, dynamic> map) {
    final configRaw = map['features_config'];
    final Map<String, String> config = {};
    if (configRaw is Map) {
      configRaw.forEach((key, value) {
        config[key.toString()] = value.toString();
      });
    }

    final limitsRaw = map['limits_config'] as Map<String, dynamic>? ?? {};

    final roleLabelsRaw = map['role_labels'];
    final Map<String, String> roleLabels = {};
    if (roleLabelsRaw is Map) {
      roleLabelsRaw.forEach((key, value) {
        roleLabels[key.toString()] = value.toString();
      });
    }

    return BusinessTypeTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      description: map['description'] as String?,
      iconName: map['icon_name'] as String?,
      defaultEnabledFeatures:
          (map['default_enabled_features'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      featuresConfig: config,
      limitsConfig: limitsRaw,
      roleLabels: roleLabels,
      maxTransactions: map['max_transactions'] as int? ?? 100,
      maxProducts: map['max_products'] as int? ?? 50,
      maxOutlets: map['max_outlets'] as int? ?? 1,
      showAds: map['show_ads'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'icon_name': iconName,
      'default_enabled_features': defaultEnabledFeatures,
      'features_config': featuresConfig,
      'limits_config': limitsConfig,
      'role_labels': roleLabels,
      'max_transactions': maxTransactions,
      'max_products': maxProducts,
      'max_outlets': maxOutlets,
      'show_ads': showAds,
    };
  }

  BusinessTypeTemplate copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? iconName,
    List<String>? defaultEnabledFeatures,
    Map<String, String>? featuresConfig,
    Map<String, dynamic>? limitsConfig,
    Map<String, String>? roleLabels,
    int? maxTransactions,
    int? maxProducts,
    int? maxOutlets,
    bool? showAds,
  }) {
    return BusinessTypeTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      defaultEnabledFeatures:
          defaultEnabledFeatures ?? this.defaultEnabledFeatures,
      featuresConfig: featuresConfig ?? this.featuresConfig,
      limitsConfig: limitsConfig ?? this.limitsConfig,
      roleLabels: roleLabels ?? this.roleLabels,
      maxTransactions: maxTransactions ?? this.maxTransactions,
      maxProducts: maxProducts ?? this.maxProducts,
      maxOutlets: maxOutlets ?? this.maxOutlets,
      showAds: showAds ?? this.showAds,
    );
  }
}
