// Core domain models are now in lib/core/domain/
// Re-exported here for backward compatibility during migration.
export 'package:dpos/core/domain/app_enums.dart';
export 'package:dpos/core/domain/business_models.dart';
export 'package:dpos/core/domain/outlet_models.dart';
export 'package:dpos/core/domain/staff_models.dart';
export 'package:dpos/core/domain/bootstrap_models.dart';

import 'package:dpos/core/domain/app_enums.dart';

class AppProfile {
  static const _unset = Object();

  const AppProfile({
    required this.id,
    this.email,
    this.phone,
    this.staffCode,
    this.fullName,
    this.avatarUrl,
    required this.defaultRole,
    required this.isActive,
    required this.onboardingCompleted,
  });

  final String id;
  final String? email;
  final String? phone;
  final String? staffCode;
  final String? fullName;
  final String? avatarUrl;
  final AppRole defaultRole;
  final bool isActive;
  final bool onboardingCompleted;

  factory AppProfile.fromMap(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      staffCode: json['staff_code'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      defaultRole: AppRole.fromValue(json['default_role'] as String?),
      isActive: (json['is_active'] as bool?) ?? true,
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'staff_code': staffCode,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'default_role': defaultRole.name,
      'is_active': isActive,
      'onboarding_completed': onboardingCompleted,
    };
  }

  AppProfile copyWith({
    Object? email = _unset,
    Object? phone = _unset,
    Object? staffCode = _unset,
    Object? fullName = _unset,
    Object? avatarUrl = _unset,
    AppRole? defaultRole,
    bool? isActive,
    bool? onboardingCompleted,
  }) {
    return AppProfile(
      id: id,
      email: identical(email, _unset) ? this.email : email as String?,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      staffCode: identical(staffCode, _unset)
          ? this.staffCode
          : staffCode as String?,
      fullName: identical(fullName, _unset)
          ? this.fullName
          : fullName as String?,
      avatarUrl: identical(avatarUrl, _unset)
          ? this.avatarUrl
          : avatarUrl as String?,
      defaultRole: defaultRole ?? this.defaultRole,
      isActive: isActive ?? this.isActive,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
