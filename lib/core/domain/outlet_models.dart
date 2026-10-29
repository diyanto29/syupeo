class Outlet {
  static const _unset = Object();

  const Outlet({
    required this.id,
    required this.businessId,
    required this.name,
    this.code,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.geofenceRadius = 5000,
    this.isGeofenceActive = true,
    required this.timezone,
    required this.isActive,
    this.taxEnabled = false,
    this.taxName = 'PB1',
    this.taxRate = 10.0,
    this.isTaxInclusive = false,
  });

  final String id;
  final String businessId;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadius;
  final bool isGeofenceActive;
  final String timezone;
  final bool isActive;
  final bool taxEnabled;
  final String taxName;
  final double taxRate;
  final bool isTaxInclusive;

  factory Outlet.fromMap(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadius: (json['geofence_radius'] as num?)?.toInt() ?? 5000,
      isGeofenceActive: (json['is_geofence_active'] as bool?) ?? true,
      timezone: (json['timezone'] as String?) ?? 'Asia/Jakarta',
      isActive: (json['is_active'] as bool?) ?? true,
      taxEnabled: (json['tax_enabled'] as bool?) ?? false,
      taxName: (json['tax_name'] as String?) ?? 'PB1',
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 10.0,
      isTaxInclusive: (json['is_tax_inclusive'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius': geofenceRadius,
      'is_geofence_active': isGeofenceActive,
      'timezone': timezone,
      'is_active': isActive,
      'tax_enabled': taxEnabled,
      'tax_name': taxName,
      'tax_rate': taxRate,
      'is_tax_inclusive': isTaxInclusive,
    };
  }

  Outlet copyWith({
    String? name,
    Object? code = _unset,
    Object? address = _unset,
    Object? phone = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? geofenceRadius = _unset,
    bool? isGeofenceActive,
    String? timezone,
    bool? isActive,
    bool? taxEnabled,
    String? taxName,
    double? taxRate,
    bool? isTaxInclusive,
  }) {
    return Outlet(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      code: identical(code, _unset) ? this.code : code as String?,
      address: identical(address, _unset) ? this.address : address as String?,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      latitude: identical(latitude, _unset) ? this.latitude : latitude as double?,
      longitude: identical(longitude, _unset) ? this.longitude : longitude as double?,
      geofenceRadius: identical(geofenceRadius, _unset)
          ? this.geofenceRadius
          : geofenceRadius as int?,
      isGeofenceActive: isGeofenceActive ?? this.isGeofenceActive,
      timezone: timezone ?? this.timezone,
      isActive: isActive ?? this.isActive,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxName: taxName ?? this.taxName,
      taxRate: taxRate ?? this.taxRate,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
    );
  }
}
