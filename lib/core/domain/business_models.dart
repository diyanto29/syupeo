import 'app_enums.dart';
import 'subscription_models.dart';

class Business {
  static const _unset = Object();

  const Business({
    required this.id,
    required this.ownerUserId,
    required this.name,
    this.slug,
    this.legalName,
    this.phone,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
    this.geofenceRadius = 5000,
    this.isGeofenceActive = true,
    required this.currencyCode,
    required this.timezone,
    this.planId,
    this.subscriptionStatus,
    this.subscriptionEndAt,
    this.plan,
    this.businessType,
    this.enabledFeatures = const [],
    this.featuresConfig = const {},
    this.limitsConfig = const {'free': {}, 'pro': {}},
    this.status = 'active',
    this.roleLabels = const {},
    this.isFeatureGateEnabled = true,
    this.maxTransactions,
    this.maxProducts,
    this.maxOutlets,
    this.showAds,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String? slug;
  final String? legalName;
  final String? phone;
  final String? email;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadius;
  final bool isGeofenceActive;
  final String currencyCode;
  final String timezone;
  final String? planId;
  final String? subscriptionStatus;
  final DateTime? subscriptionEndAt;
  final SubscriptionPlan? plan; // Data hasil join
  final String? businessType;
  final String status;
  final List<String> enabledFeatures;
  final Map<String, String> featuresConfig; // { 'feat': 'off' | 'free' | 'pro' }
  final Map<String, dynamic> limitsConfig; // { 'free': { 'max_tx': 100 }, 'pro': { 'max_tx': 1000 } }
  final Map<String, String> roleLabels; // { 'waiter': 'Marketer' }
  final bool isFeatureGateEnabled;
  final int? maxTransactions;
  final int? maxProducts;
  final int? maxOutlets;
  final bool? showAds;
  final DateTime? updatedAt;

  bool get isPro =>
      plan != null && (plan!.code == 'pro' || plan!.code == 'enterprise');

  bool get isTrial => subscriptionStatus == 'trial';

  bool get isTrialActive {
    if (!isTrial) return false;
    if (subscriptionEndAt == null) return true;
    return DateTime.now().isBefore(subscriptionEndAt!);
  }

  bool get isLifetime =>
      (isPro || isTrial) && subscriptionEndAt == null;

  bool get isExpired =>
      subscriptionEndAt != null && DateTime.now().isAfter(subscriptionEndAt!);

  int? get remainingDays {
    if (subscriptionEndAt == null) return null;
    final diffMicros =
        subscriptionEndAt!.difference(DateTime.now()).inMicroseconds;
    if (diffMicros <= 0) return 0;
    // Pembulatan ke atas (ceil) agar sinkron dengan Web Admin:
    // Contoh: masa aktif 6 hari 23 jam dihitung 7 hari
    return (diffMicros / Duration.microsecondsPerDay).ceil();
  }

  String get subscriptionPlanDisplay {
    if (isTrial) {
      if (isLifetime) return 'Trial Pro (Selamanya)';
      if (isExpired) return 'Trial Pro (Kedaluwarsa)';
      final days = remainingDays ?? 0;
      return 'Trial Pro ($days hari)';
    }

    if (!isPro) return 'Free';
    if (isLifetime) return 'Pro Lifetime';
    if (isExpired) return 'Pro (Kedaluwarsa)';
    final days = remainingDays ?? 0;
    return 'Pro ($days hari)';
  }

  factory Business.fromMap(Map<String, dynamic> json) {
    // Handle featuresConfig mapping
    final configRaw = json['features_config'];
    final Map<String, String> config = {};
    if (configRaw is Map) {
      configRaw.forEach((key, value) {
        config[key.toString()] = value.toString();
      });
    }

    final limitsRaw = json['limits_config'] as Map<String, dynamic>? ?? {};

    final roleLabelsRaw = json['role_labels'];
    final Map<String, String> roleLabels = {};
    if (roleLabelsRaw is Map) {
      roleLabelsRaw.forEach((key, value) {
        roleLabels[key.toString()] = value.toString();
      });
    }

    return Business(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      legalName: json['legal_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadius: (json['geofence_radius'] as num?)?.toInt() ?? 5000,
      isGeofenceActive: (json['is_geofence_active'] as bool?) ?? true,
      currencyCode: (json['currency_code'] as String?) ?? 'IDR',
      timezone: (json['timezone'] as String?) ?? 'Asia/Jakarta',
      planId: json['plan_id'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      subscriptionEndAt: json['subscription_end_at'] == null
          ? null
          : DateTime.tryParse(json['subscription_end_at'] as String),
      plan: _parsePlan(json['subscription_plans']),
      businessType: json['business_type'] as String?,
      status: (json['status'] as String?) ?? 'active',
      enabledFeatures: (json['enabled_features'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      featuresConfig: config,
      limitsConfig: limitsRaw,
      roleLabels: roleLabels,
      isFeatureGateEnabled: json['is_feature_gate_enabled'] as bool? ?? true,
      maxTransactions: json['max_transactions'] as int?,
      maxProducts: json['max_products'] as int?,
      maxOutlets: json['max_outlets'] as int?,
      showAds: json['show_ads'] as bool?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'] as String),
    );
  }

  static SubscriptionPlan? _parsePlan(dynamic data) {
    if (data == null) return null;
    if (data is List && data.isNotEmpty) {
      return SubscriptionPlan.fromMap(Map<String, dynamic>.from(data.first as Map));
    }
    if (data is Map) {
      return SubscriptionPlan.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_user_id': ownerUserId,
      'name': name,
      'slug': slug,
      'legal_name': legalName,
      'phone': phone,
      'email': email,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius': geofenceRadius,
      'is_geofence_active': isGeofenceActive,
      'currency_code': currencyCode,
      'timezone': timezone,
      'plan_id': planId,
      'subscription_status': subscriptionStatus,
      'subscription_end_at': subscriptionEndAt?.toIso8601String(),
      'business_type': businessType,
      'status': status,
      'enabled_features': enabledFeatures,
      'features_config': featuresConfig,
      'limits_config': limitsConfig,
      'role_labels': roleLabels,
      'is_feature_gate_enabled': isFeatureGateEnabled,
      'max_transactions': maxTransactions,
      'max_products': maxProducts,
      'max_outlets': maxOutlets,
      'show_ads': showAds,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Business copyWith({
    String? name,
    Object? slug = _unset,
    Object? legalName = _unset,
    Object? phone = _unset,
    Object? email = _unset,
    Object? address = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? geofenceRadius = _unset,
    bool? isGeofenceActive,
    String? currencyCode,
    String? timezone,
    SubscriptionPlan? plan,
    String? businessType,
    List<String>? enabledFeatures,
    Map<String, String>? featuresConfig,
    Map<String, dynamic>? limitsConfig,
    Map<String, String>? roleLabels,
    bool? isFeatureGateEnabled,
    Object? maxTransactions = _unset,
    Object? maxProducts = _unset,
    Object? maxOutlets = _unset,
    Object? showAds = _unset,
    DateTime? updatedAt,
  }) {
    return Business(
      id: id,
      ownerUserId: ownerUserId,
      name: name ?? this.name,
      slug: identical(slug, _unset) ? this.slug : slug as String?,
      legalName: identical(legalName, _unset)
          ? this.legalName
          : legalName as String?,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      address: identical(address, _unset) ? this.address : address as String?,
      latitude: identical(latitude, _unset) ? this.latitude : latitude as double?,
      longitude: identical(longitude, _unset) ? this.longitude : longitude as double?,
      geofenceRadius: identical(geofenceRadius, _unset)
          ? this.geofenceRadius
          : geofenceRadius as int?,
      isGeofenceActive: isGeofenceActive ?? this.isGeofenceActive,
      currencyCode: currencyCode ?? this.currencyCode,
      timezone: timezone ?? this.timezone,
      plan: plan ?? this.plan,
      businessType: businessType ?? this.businessType,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
      featuresConfig: featuresConfig ?? this.featuresConfig,
      limitsConfig: limitsConfig ?? this.limitsConfig,
      roleLabels: roleLabels ?? this.roleLabels,
      isFeatureGateEnabled: isFeatureGateEnabled ?? this.isFeatureGateEnabled,
      maxTransactions: identical(maxTransactions, _unset)
          ? this.maxTransactions
          : maxTransactions as int?,
      maxProducts: identical(maxProducts, _unset)
          ? this.maxProducts
          : maxProducts as int?,
      maxOutlets: identical(maxOutlets, _unset)
          ? this.maxOutlets
          : maxOutlets as int?,
      showAds: identical(showAds, _unset) ? this.showAds : showAds as bool?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get businessTypeLabel {
    switch (businessType) {
      case 'fnb':
        return 'Food & Beverage';
      case 'retail':
        return 'Retail';
      case 'service':
        return 'Service & Professional';
      case 'general':
        return 'General Business';
      default:
        return businessType?.toUpperCase() ?? 'Not Set';
    }
  }

  bool get isFnb => businessType == 'fnb' || businessType == 'general';
  bool get isPendingActivation => status == 'pending';
  bool get isActive => status == 'active';
}

class BusinessMember {
  const BusinessMember({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.role,
    required this.status,
  });

  final String id;
  final String businessId;
  final String userId;
  final AppRole role;
  final String status;

  factory BusinessMember.fromMap(Map<String, dynamic> json) {
    return BusinessMember(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      userId: json['user_id'] as String,
      role: AppRole.fromValue(json['role'] as String?),
      status: (json['status'] as String?) ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'role': role.name,
      'status': status,
    };
  }
}
